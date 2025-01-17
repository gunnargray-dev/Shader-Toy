import Foundation
import MetalKit
import simd

struct ShaderConfig {
    var time: Float = 0
    var resolution = SIMD2<Float>(0, 0)
    var patternScale = SIMD2<Float>(40, 40)
    var colorA = SIMD4<Float>(1, 1, 1, 1)
    var colorB = SIMD4<Float>(0, 0, 0, 1)
    var patternSpeed: Float = 0.8
    var dotSize: Float = 0.15
    var patternType: Int32 = 0
    var touchPosition = SIMD2<Float>(-1, -1)
    var touchTime: Float = 0
    var touchEndTime: Float = -1
    var isMultiColored: Int32 = 0
    var gradientSpeed: Float = 1.0
    var padding: Float = 0
    var dotSpacing = SIMD2<Float>(1.0, 1.0)
}

enum PatternType: Int32, CaseIterable, Identifiable {
    case verticalWave = 0
    case circularWave = 1
    case ripple = 2
    case noise = 3

    var id: Int32 { rawValue }

    var name: String {
        switch self {
        case .verticalWave: return "Wave"
        case .circularWave: return "Pulse"
        case .ripple: return "Ripple"
        case .noise: return "Noise"
        }
    }

    var shaderFunctionName: String {
        return "pattern_dots" // Currently using same shader function for all patterns
    }
}
