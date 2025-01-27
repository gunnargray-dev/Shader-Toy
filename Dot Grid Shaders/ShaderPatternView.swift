import MetalKit
import simd
import SwiftUI

struct ShaderPatternView: UIViewRepresentable {
    var config: ShaderConfig
    var isPlaying: Bool
    @Binding var touchPosition: CGPoint?

    // Grid configuration
    let gridDensity: Float = 1.0
    let minDensity: Float = 1.0
    let maxDensity: Float = 5.0

    func makeCoordinator() -> Coordinator {
        print("ShaderPatternView: makeCoordinator called")
        let coordinator = Coordinator(self)
        coordinator.updateState(config: config, isPlaying: isPlaying)
        return coordinator
    }

    func makeUIView(context: Context) -> TouchableMTKView {
        print("ShaderPatternView: makeUIView called")
        let mtkView = TouchableMTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // Set resolution before any calculations
        let screenSize = UIScreen.main.bounds.size
        context.coordinator.resolution = SIMD2<Float>(
            Float(screenSize.width),
            Float(screenSize.height)
        )
        print("ShaderPatternView: Setting initial resolution =", context.coordinator.resolution)

        // Setup Metal first
        context.coordinator.setupMetal(device: device)

        // Then configure view
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.drawableSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false

        // Force initial render
        mtkView.draw()

        print("ShaderPatternView: Initial resolution =", context.coordinator.resolution)
        print("ShaderPatternView: Initial patternScale =", context.coordinator.patternScale)
        return mtkView
    }

    func updateUIView(_: TouchableMTKView, context: Context) {
        print("ShaderPatternView: updateUIView called")

        // Guard against zero values
        guard context.coordinator.resolution.y > 0 else {
            print("ShaderPatternView: Invalid resolution")
            return
        }

        let aspectRatio = context.coordinator.resolution.x / context.coordinator.resolution.y
        print("ShaderPatternView: resolution =", context.coordinator.resolution)
        print("ShaderPatternView: aspectRatio =", aspectRatio)

        let density = min(max(gridDensity, minDensity), maxDensity)
        let baseScale = Float(config.patternScale.x) * density

        // Guard against NaN values
        let safeAspectRatio = aspectRatio.isNaN ? 1.0 : aspectRatio

        let gridScale = SIMD2<Float>(
            baseScale * safeAspectRatio,
            baseScale
        )
        print("ShaderPatternView: gridScale =", gridScale)

        context.coordinator.patternScale = gridScale
        context.coordinator.dotSize = Float(config.dotSize)
        context.coordinator.patternSpeed = config.patternSpeed
        context.coordinator.patternType = config.patternType
        context.coordinator.isPlaying = isPlaying
        context.coordinator.isMultiColored = config.isMultiColored
        context.coordinator.gradientSpeed = config.gradientSpeed
    }

    class Coordinator: NSObject, MTKViewDelegate {
        let parent: ShaderPatternView
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var currentTime: Float = 0

        // State properties
        var resolution: SIMD2<Float>
        var patternScale: SIMD2<Float>
        var dotSize: Float
        var patternSpeed: Float
        var patternType: Int32
        var isPlaying: Bool
        var touchPosition: CGPoint?
        var touchStartTime: Float = 0
        var touchEndTime: Float = -1
        var lastTouchPosition: CGPoint?
        var isMultiColored: Int32 = 0
        var gradientSpeed: Float = 1.0

        init(_ parent: ShaderPatternView) {
            self.parent = parent

            // Set initial values
            resolution = SIMD2<Float>(
                Float(UIScreen.main.bounds.width),
                Float(UIScreen.main.bounds.height)
            )

            // Use the same scaling logic as updateUIView
            let aspectRatio = resolution.x / resolution.y
            let safeAspectRatio = aspectRatio.isNaN ? 1.0 : aspectRatio
            let density = min(max(parent.gridDensity, parent.minDensity), parent.maxDensity)
            let baseScale = parent.config.patternScale.x * density

            patternScale = SIMD2<Float>(
                baseScale * safeAspectRatio,
                baseScale
            )

            // Set other properties
            dotSize = parent.config.dotSize
            patternSpeed = parent.config.patternSpeed
            patternType = parent.config.patternType
            isPlaying = parent.isPlaying
            isMultiColored = parent.config.isMultiColored
            gradientSpeed = parent.config.gradientSpeed

            super.init()

            print("Coordinator: init - resolution =", resolution)
            print("Coordinator: init - aspectRatio =", safeAspectRatio)
            print("Coordinator: init - patternScale =", patternScale)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            resolution = SIMD2<Float>(Float(size.width), Float(size.height))
            view.setNeedsDisplay()
        }

        func draw(in view: MTKView) {
            print("Coordinator: draw called")
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let pipelineState = pipelineState,
                  let descriptor = view.currentRenderPassDescriptor,
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else {
                print("Coordinator: draw guard check failed")
                return
            }

            if isPlaying {
                currentTime += 1.0 / Float(view.preferredFramesPerSecond)
            }

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

        func setupMetal(device: MTLDevice) {
            self.device = device
            commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary(),
                  let vertexFunction = library.makeFunction(name: "pattern_vertex"),
                  let fragmentFunction = library.makeFunction(name: "pattern_dots")
            else {
                print("Failed to create Metal functions")
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

        func handleTouch(_ position: CGPoint?) {
            if let position = position {
                // If this is a new touch or touch at a different position
                if touchPosition == nil {
                    // Start new ripple only on initial touch
                    touchStartTime = currentTime
                    touchEndTime = -1
                } else if lastTouchPosition != position {
                    // During drag, update position but don't reset timing
                }
                touchPosition = position
                lastTouchPosition = position
            } else {
                touchEndTime = currentTime
                lastTouchPosition = nil
            }
        }

        func updateState(config: ShaderConfig, isPlaying: Bool) {
            print("Coordinator: updateState called")
            print("Coordinator: config.patternScale =", config.patternScale)
            patternScale = config.patternScale
            dotSize = config.dotSize
            patternSpeed = config.patternSpeed
            patternType = config.patternType
            self.isPlaying = isPlaying
            isMultiColored = config.isMultiColored
            gradientSpeed = config.gradientSpeed
        }

        // ... rest of Coordinator implementation
    }
}
