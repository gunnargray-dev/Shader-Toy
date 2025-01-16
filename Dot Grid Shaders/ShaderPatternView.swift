import MetalKit
import simd
import SwiftUI

struct ShaderPatternView: UIViewRepresentable {
    var config: ShaderConfig
    var isPlaying: Bool
    @Binding var touchPosition: CGPoint?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TouchableMTKView {
        let mtkView = TouchableMTKView()
        mtkView.delegate = context.coordinator
        mtkView.touchHandler = { position in
            context.coordinator.handleTouch(position)
        }

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        mtkView.device = device
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false // Continuous rendering
        mtkView.isPaused = false // Never pause the display link
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.coordinator.setupMetal(device: device)
        return mtkView
    }

    func updateUIView(_: TouchableMTKView, context: Context) {
        context.coordinator.patternScale = config.patternScale
        context.coordinator.dotSize = config.dotSize
        context.coordinator.patternSpeed = config.patternSpeed
        context.coordinator.patternType = config.patternType
        context.coordinator.isPlaying = isPlaying
        context.coordinator.isMultiColored = config.isMultiColored
        context.coordinator.gradientSpeed = config.gradientSpeed

        // Debug print
        print("Updated view with pattern type: \(config.patternType)")
    }

    class Coordinator: NSObject, MTKViewDelegate {
        let parent: ShaderPatternView
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var currentTime: Float = 0

        // Separate state properties
        var patternScale: SIMD2<Float>
        var dotSize: Float
        var patternSpeed: Float
        var isPlaying: Bool = false
        var resolution = SIMD2<Float>(0, 0)
        var patternType: Int32 = 0
        var touchPosition: CGPoint?
        var touchStartTime: Float = 0
        var touchEndTime: Float = -1
        var lastTouchPosition: CGPoint?
        var isMultiColored: Int32 = 0
        var gradientSpeed: Float = 1.0

        init(_ parent: ShaderPatternView) {
            self.parent = parent
            patternScale = parent.config.patternScale
            dotSize = parent.config.dotSize
            patternSpeed = parent.config.patternSpeed
            super.init()
        }

        func setupMetal(device: MTLDevice) {
            self.device = device
            commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary(),
                  let vertexFunction = library.makeFunction(name: "pattern_vertex"),
                  let fragmentFunction = library.makeFunction(name: "pattern_dots")
            else {
                return
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }

        func mtkView(_: MTKView, drawableSizeWillChange size: CGSize) {
            resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        }

        func handleTouch(_ position: CGPoint?) {
            if let position = position {
                // If this is a new touch or touch at a different position
                if touchPosition == nil {
                    // Start new ripple only on initial touch
                    touchStartTime = currentTime
                    touchEndTime = -1
                    print("New touch detected at: \(position)")
                } else if lastTouchPosition != position {
                    // During drag, update position but don't reset timing
                    print("Touch moved to: \(position)")
                }
                touchPosition = position
                lastTouchPosition = position
            } else {
                touchEndTime = currentTime
                lastTouchPosition = nil
            }
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let pipelineState = pipelineState,
                  let descriptor = view.currentRenderPassDescriptor,
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else {
                return
            }

            if isPlaying {
                currentTime += 1.0 / Float(view.preferredFramesPerSecond)
            }

            // Debug print
            print("Drawing with pattern type: \(patternType)")

            var config = ShaderConfig(
                time: currentTime,
                resolution: resolution,
                patternScale: patternScale,
                colorA: SIMD4<Float>(1, 1, 1, 1),
                colorB: SIMD4<Float>(0, 0, 0, 1),
                patternSpeed: patternSpeed,
                dotSize: dotSize,
                patternType: patternType,
                touchPosition: SIMD2<Float>(-1, -1),
                touchTime: 0,
                touchEndTime: -1,
                isMultiColored: isMultiColored,
                gradientSpeed: gradientSpeed,
                padding: 0
            )

            if let touch = touchPosition {
                config.touchPosition = SIMD2<Float>(
                    Float(touch.x / view.bounds.width),
                    Float(1.0 - touch.y / view.bounds.height)
                )
                config.touchTime = currentTime - touchStartTime
                config.touchEndTime = touchEndTime

                // Clear touch state after animation duration (1.5 seconds)
                if touchEndTime >= 0 && (currentTime - touchStartTime) > 1.5 {
                    touchPosition = nil
                    touchEndTime = -1
                }
            }

            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes(&config, length: MemoryLayout<ShaderConfig>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
