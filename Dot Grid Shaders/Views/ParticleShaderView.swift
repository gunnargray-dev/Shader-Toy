import MetalKit
import SwiftUI

protocol SphereGestureHandler {
    func handleTap(at position: CGPoint, in view: MTKView)
}

struct ParticleShaderView: UIViewRepresentable {
    @Binding var isPlaying: Bool
    var particleSpeed: Double
    var particleSize: Double
    var particleCount: Int
    var sphereSize: Double
    @State private var isBouncing: Bool = false

    class Coordinator: NSObject, MTKViewDelegate, SphereGestureHandler {
        var parent: ParticleShaderView
        var device: MTLDevice
        var commandQueue: MTLCommandQueue
        var pipeline: MTLComputePipelineState
        var renderPipeline: MTLRenderPipelineState
        var particles: MTLBuffer
        var uniforms: MTLBuffer
        var particleCount: Int
        var particleCountBuffer: MTLBuffer
        var bounceStartTime: Float = -1
        private var lastFrameTime: CFTimeInterval = 0
        private let targetFrameRate: Double = 60.0
        private let frameInterval: CFTimeInterval = 1.0 / 60.0

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

        func initializeParticles() {
            let particlesPtr = particles.contents().bindMemory(to: Particle.self, capacity: particleCount)
            // Use a default center position initially
            let center = SIMD2<Float>(400, 400) // This will be updated when the view size changes

            for i in 0 ..< particleCount {
                // Use same golden ratio distribution as in the shader
                let n = Float(i)
                let N = Float(particleCount)

                // Calculate initial spherical position
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

                // Start with zero velocity for smoother start
                particlesPtr[i] = Particle(
                    position: pos,
                    velocity: SIMD2<Float>(0, 0),
                    life: 0.3 + 0.7 * ((z / baseRadius) * 0.5 + 0.5)
                )
            }
        }

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

            // Skip frame if we're ahead of schedule
            if elapsed < frameInterval {
                return
            }

            guard parent.isPlaying,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let drawable = view.currentDrawable else { return }

            // Update uniforms
            let uniformsPtr = uniforms.contents().bindMemory(to: ParticleUniforms.self, capacity: 1)
            uniformsPtr.pointee.time += Float(elapsed)

            // Debug pulse state
            if uniformsPtr.pointee.isPulsing {
                print("DEBUG Draw: isPulsing true, time: \(uniformsPtr.pointee.time), pulseTime: \(uniformsPtr.pointee.pulseTime)")
            }
            uniformsPtr.pointee.resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            uniformsPtr.pointee.particleSpeed = Float(parent.particleSpeed)
            uniformsPtr.pointee.particleSize = Float(parent.particleSize)
            uniformsPtr.pointee.sphereSize = Float(parent.sphereSize)

            // Check and reset pulse state if needed
            if uniformsPtr.pointee.isPulsing {
                let pulseTime = uniformsPtr.pointee.time - uniformsPtr.pointee.pulseTime
                if pulseTime >= 2.0 {
                    uniformsPtr.pointee.isPulsing = false
                }
            }

            // Optimize compute thread grouping
            let threadsPerThreadgroup = MTLSize(
                width: min(pipeline.maxTotalThreadsPerThreadgroup, 64), // Use smaller groups
                height: 1,
                depth: 1
            )
            let threadgroups = MTLSize(
                width: (particleCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: 1,
                depth: 1
            )

            // Compute pass
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
            computeEncoder.setComputePipelineState(pipeline)
            computeEncoder.setBuffer(particles, offset: 0, index: 0)
            computeEncoder.setBuffer(uniforms, offset: 0, index: 1)
            computeEncoder.setBuffer(particleCountBuffer, offset: 0, index: 2)
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()

            // Render pass with optimized settings
            let renderPassDescriptor = view.currentRenderPassDescriptor!
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(renderPipeline)
            renderEncoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
            renderEncoder.setFragmentBuffer(particles, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(particleCountBuffer, offset: 0, index: 2)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()

            lastFrameTime = currentTime
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

        // Add gesture handling
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
    }

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
        mtkView.preferredFramesPerSecond = 60

        // Enable gesture handling
        mtkView.isUserInteractionEnabled = true
        mtkView.gestureHandler = context.coordinator

        return mtkView
    }

    func updateUIView(_: MTKView, context: Context) {
        let coordinator = context.coordinator

        // Update particle count if it changed
        if coordinator.particleCount != particleCount {
            coordinator.particleCount = particleCount
            coordinator.updateParticleCount(newCount: particleCount)
        }

        // Update uniforms
        let uniformsPtr = coordinator.uniforms.contents().bindMemory(to: ParticleUniforms.self, capacity: 1)
        uniformsPtr.pointee.particleSpeed = Float(particleSpeed)
        uniformsPtr.pointee.particleSize = Float(particleSize)
        uniformsPtr.pointee.sphereSize = Float(sphereSize)
    }
}

// Supporting types
struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var life: Float
}

struct ParticleUniforms {
    var resolution: SIMD2<Float>
    var time: Float = 0
    var touchPosition: SIMD2<Float> = .zero
    var isTouching: Bool = false
    var particleSpeed: Float = 1.0
    var particleSize: Float = 0.01
    var sphereSize: Float = 400.0
    var bounceStartTime: Float = -1
    var pulseTime: Float = 0
    var isPulsing: Bool = false
}

class GestureEnabledMTKView: MTKView {
    var gestureHandler: SphereGestureHandler?

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let position = touch.location(in: self)
        gestureHandler?.handleTap(at: position, in: self)
    }
}
