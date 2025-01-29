import MetalKit
import SwiftUI

// MARK: - Protocols

protocol SphereGestureHandler {
    func handleTap(at position: CGPoint, in view: MTKView)
}

// MARK: - Types

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var life: Float
}

struct ParticleUniforms {
    var resolution: SIMD2<Float> = .zero
    var time: Float = 0
    var touchPosition: SIMD2<Float> = .zero
    var isTouching: Bool = false
    var particleSpeed: Float = 1.0
    var particleSize: Float = 0.01
    var sphereSize: Float = 400.0
    var bounceStartTime: Float = 0
    var pulseTime: Float = 0
    var isPulsing: Bool = false

    // Add padding to match Metal's alignment
    private var _padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

// MARK: - Custom MTKView

class GestureEnabledMTKView: MTKView {
    var gestureHandler: SphereGestureHandler?

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let position = touch.location(in: self)
        gestureHandler?.handleTap(at: position, in: self)
    }
}

// MARK: - Main View

struct ParticleShaderView: UIViewRepresentable {
    // MARK: Properties

    @Binding var isPlaying: Bool
    var particleSpeed: Double
    var particleSize: Double
    var particleCount: Int
    var sphereSize: Double

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = GestureEnabledMTKView()
        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.device
        mtkView.framebufferOnly = true
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 120 // Target higher frame rate
        mtkView.presentsWithTransaction = false // Reduce presentation overhead

        mtkView.isUserInteractionEnabled = true
        mtkView.gestureHandler = context.coordinator

        return mtkView
    }

    func updateUIView(_: MTKView, context: Context) {
        let coordinator = context.coordinator

        if coordinator.particleCount != particleCount {
            coordinator.particleCount = particleCount
            coordinator.updateParticleCount(newCount: particleCount)
        }

        let uniformsPtr = coordinator.uniforms.contents().bindMemory(to: ParticleUniforms.self, capacity: 1)
        uniformsPtr.pointee.particleSpeed = Float(particleSpeed)
        uniformsPtr.pointee.particleSize = Float(particleSize)
        uniformsPtr.pointee.sphereSize = Float(sphereSize)
    }
}

// MARK: - Coordinator

extension ParticleShaderView {
    class Coordinator: NSObject, MTKViewDelegate, SphereGestureHandler {
        // MARK: Properties

        var parent: ParticleShaderView
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipeline: MTLComputePipelineState
        let renderPipeline: MTLRenderPipelineState
        var particles: MTLBuffer
        let uniforms: MTLBuffer
        let particleCountBuffer: MTLBuffer
        var particleCount: Int
        var bounceStartTime: Float = -1
        private var lastFrameTime: CFTimeInterval = 0
        private let targetFrameRate: Double = 60.0
        private let frameInterval: CFTimeInterval = 1.0 / 60.0

        // MARK: Initialization

        init(_ parent: ParticleShaderView) {
            self.parent = parent
            particleCount = parent.particleCount
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue()
            else {
                fatalError("Metal setup failed")
            }

            self.device = device
            self.commandQueue = commandQueue

            // Create compute pipeline
            let library = device.makeDefaultLibrary()!
            let computeFunction = library.makeFunction(name: "particleCompute")!
            pipeline = try! device.makeComputePipelineState(function: computeFunction)

            // Create render pipeline
            let renderFunction = library.makeFunction(name: "particleFragment")!
            let vertexFunction = library.makeFunction(name: "particleVertex")!
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = renderFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            do {
                renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("Failed to create render pipeline state: \(error)")
            }

            // Initialize particles
            let particleSize = MemoryLayout<Particle>.stride
            particles = device.makeBuffer(length: particleSize * particleCount, options: [])!
            uniforms = device.makeBuffer(length: MemoryLayout<ParticleUniforms>.stride, options: [])!

            // Create particle count buffer
            particleCountBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: [])!
            let countPtr = particleCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
            countPtr.pointee = UInt32(particleCount)

            super.init()
            initializeParticles()
        }

        // MARK: MTKViewDelegate

        func mtkView(_: MTKView, drawableSizeWillChange size: CGSize) {
            let uniformsPtr = uniforms.contents().bindMemory(to: ParticleUniforms.self, capacity: 1)
            uniformsPtr.pointee.resolution = SIMD2<Float>(Float(size.width), Float(size.height))

            // Update particle positions with new center
            let particlesPtr = particles.contents().bindMemory(to: Particle.self, capacity: particleCount)
            let center = SIMD2<Float>(Float(size.width) / 2, Float(size.height) / 2)

            for i in 0 ..< particleCount {
                let n = Float(i)
                let N = Float(particleCount)

                let phi = 2.0 * Float.pi * fmod(n * 0.618034, 1.0)
                let cosTheta = 1.0 - (2.0 * n + 1.0) / N
                let sinTheta = sqrt(1.0 - cosTheta * cosTheta)

                let baseRadius = Float(parent.sphereSize)

                let x = cos(phi) * sinTheta * baseRadius
                let y = sin(phi) * sinTheta * baseRadius
                let z = cosTheta * baseRadius

                let scale = (z + baseRadius * 2) / (baseRadius * 3)
                let pos = center + SIMD2<Float>(x, y) * scale

                particlesPtr[i].position = pos
                particlesPtr[i].velocity = SIMD2<Float>(0, 0)
                particlesPtr[i].life = 0.3 + 0.7 * ((z / baseRadius) * 0.5 + 0.5)
            }
        }

        func draw(in view: MTKView) {
            let currentTime = CACurrentMediaTime()
            let elapsed = currentTime - lastFrameTime

            // Use more precise frame timing
            let targetFrameDuration = 1.0 / 120.0 // Target 120 FPS
            if elapsed < targetFrameDuration {
                return
            }

            guard parent.isPlaying,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let drawable = view.currentDrawable else { return }

            // Use autoreleasepool to reduce memory pressure
            autoreleasepool {
                let uniformsPtr = uniforms.contents().bindMemory(to: ParticleUniforms.self, capacity: 1)
                uniformsPtr.pointee.time += Float(elapsed)
                uniformsPtr.pointee.resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
                uniformsPtr.pointee.particleSpeed = Float(parent.particleSpeed)
                uniformsPtr.pointee.particleSize = Float(parent.particleSize)
                uniformsPtr.pointee.sphereSize = Float(parent.sphereSize)

                // Optimize thread grouping
                let threadsPerThreadgroup = MTLSize(width: 128, height: 1, depth: 1) // Increased for better GPU utilization
                let threadgroups = MTLSize(
                    width: (particleCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                    height: 1,
                    depth: 1
                )

                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    computeEncoder.setComputePipelineState(pipeline)
                    computeEncoder.setBuffer(particles, offset: 0, index: 0)
                    computeEncoder.setBuffer(uniforms, offset: 0, index: 1)
                    computeEncoder.setBuffer(particleCountBuffer, offset: 0, index: 2)

                    if threadgroups.width > 0 {
                        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
                    }
                    computeEncoder.endEncoding()
                }

                // Render pass
                if let renderPassDescriptor = view.currentRenderPassDescriptor {
                    renderPassDescriptor.colorAttachments[0].loadAction = .clear
                    renderPassDescriptor.colorAttachments[0].storeAction = .store
                    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

                    if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                        renderEncoder.setRenderPipelineState(renderPipeline)
                        renderEncoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
                        renderEncoder.setFragmentBuffer(particles, offset: 0, index: 1)
                        renderEncoder.setFragmentBuffer(particleCountBuffer, offset: 0, index: 2)
                        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                        renderEncoder.endEncoding()
                    }
                }
            }

            // Optimize command buffer scheduling
            commandBuffer.present(drawable)
            commandBuffer.commit()

            lastFrameTime = currentTime
        }

        // MARK: Gesture Handling

        func handleTap(at position: CGPoint, in view: MTKView) {
            let uniformsPtr = uniforms.contents().bindMemory(to: ParticleUniforms.self, capacity: 1)

            // Convert tap position to normalized coordinates
            let tapLocation = SIMD2<Float>(
                Float(position.x / view.bounds.width),
                Float(position.y / view.bounds.height)
            )

            // Trigger pulse effect
            uniformsPtr.pointee.pulseTime = uniformsPtr.pointee.time
            uniformsPtr.pointee.isPulsing = true
            uniformsPtr.pointee.touchPosition = tapLocation

            print("Tap handled at: \(tapLocation)")
        }

        // MARK: Private Methods

        private func initializeParticles() {
            let particlesPtr = particles.contents().bindMemory(to: Particle.self, capacity: particleCount)
            // Use default center position initially
            let center = SIMD2<Float>(400, 400) // Default center that will be updated in mtkView(_:drawableSizeWillChange:)

            for i in 0 ..< particleCount {
                let n = Float(i)
                let N = Float(particleCount)

                // Golden ratio angle for uniform sphere distribution
                let phi = 2.0 * Float.pi * fmod(n * 0.618034, 1.0)
                let cosTheta = 1.0 - (2.0 * n + 1.0) / N
                let sinTheta = sqrt(1.0 - cosTheta * cosTheta)

                let baseRadius = Float(parent.sphereSize)

                // Calculate 3D position
                let x = cos(phi) * sinTheta * baseRadius
                let y = sin(phi) * sinTheta * baseRadius
                let z = cosTheta * baseRadius

                // Project to 2D with perspective
                let scale = (z + baseRadius * 2) / (baseRadius * 3)
                let pos = center + SIMD2<Float>(x, y) * scale

                // Initialize with zero velocity for smoother start
                particlesPtr[i] = Particle(
                    position: pos,
                    velocity: SIMD2<Float>(0, 0),
                    life: 0.3 + 0.7 * ((z / baseRadius) * 0.5 + 0.5)
                )
            }
        }

        func updateParticleCount(newCount: Int) {
            // Recreate particle buffer with new size
            let particleSize = MemoryLayout<Particle>.stride
            particles = device.makeBuffer(length: particleSize * newCount, options: [])!

            // Update particle count buffer
            let countPtr = particleCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
            countPtr.pointee = UInt32(newCount)

            // Reinitialize particles with new count
            initializeParticles()
        }
    }
}

// MARK: - Preview

#Preview {
    ParticleShaderView(
        isPlaying: .constant(true),
        particleSpeed: 1.0,
        particleSize: 0.005,
        particleCount: 1000,
        sphereSize: 400.0
    )
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
