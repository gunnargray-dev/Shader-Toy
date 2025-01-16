import SwiftUI

struct ContentView: View {
    @State private var patternDensity: Double = 40.0
    @State private var dotSize: Double = 0.15
    @State private var animationSpeed: Double = 0.8
    @State private var isPlaying: Bool = false
    @State private var selectedPattern: PatternType = .verticalWave
    @State private var touchPosition: CGPoint?
    @State private var isShowingSheet = true

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Pattern View
            ShaderPatternView(
                config: ShaderConfig(
                    time: 0,
                    resolution: SIMD2<Float>(0, 0),
                    patternScale: SIMD2<Float>(Float(patternDensity), Float(patternDensity)),
                    colorA: SIMD4<Float>(1, 1, 1, 1),
                    colorB: SIMD4<Float>(0, 0, 0, 1),
                    patternSpeed: Float(animationSpeed),
                    dotSize: Float(dotSize),
                    patternType: selectedPattern.rawValue
                ),
                isPlaying: isPlaying,
                touchPosition: $touchPosition
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingSheet) {
            ParametersSheet(
                patternDensity: $patternDensity,
                dotSize: $dotSize,
                animationSpeed: $animationSpeed,
                isPlaying: $isPlaying,
                selectedPattern: $selectedPattern
            )
            .presentationDetents([.height(60), .fraction(0.45)])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
