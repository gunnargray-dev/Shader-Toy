import SwiftUI

struct ContentView: View {
    @State private var patternDensity: Double = 40.0
    @State private var dotSize: Double = 0.15
    @State private var animationSpeed: Double = 0.8
    @State private var isPlaying: Bool = true
    @State private var selectedPattern: PatternType = .verticalWave
    @State private var touchPosition: CGPoint?
    @State private var isShowingSheet = false
    @State private var isMultiColored: Bool = false
    @State private var gradientSpeed: Double = 1.0
    @State private var selectedMode: PatternMode = .dotGrid
    @State private var sphereSize: Double = 400.0

    // Add this to force initial update
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main View based on selected mode
            if selectedMode == .dotGrid {
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
                        patternType: selectedPattern.id,
                        touchPosition: SIMD2<Float>(-1, -1),
                        touchTime: 0,
                        touchEndTime: -1,
                        isMultiColored: isMultiColored ? 1 : 0,
                        gradientSpeed: Float(gradientSpeed),
                        padding: 0
                    ),
                    isPlaying: isPlaying,
                    touchPosition: $touchPosition
                )
                .ignoresSafeArea()
            } else {
                ParticleShaderView(
                    isPlaying: $isPlaying,
                    particleSpeed: animationSpeed,
                    particleSize: selectedMode == .particles ? 0.003 : dotSize,
                    particleCount: Int(selectedMode == .particles ? 1000 : patternDensity),
                    sphereSize: sphereSize
                )
                .ignoresSafeArea()
            }

            // Add a button to show the sheet
            VStack {
                Spacer()
                Button(action: { isShowingSheet = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 0.8))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            print("ContentView: onAppear triggered")
            print("ContentView: Initial patternDensity =", patternDensity)
            patternDensity += 0.001
            print("ContentView: Updated patternDensity =", patternDensity)
            hasAppeared = true
        }
        .sheet(isPresented: $isShowingSheet) {
            ParametersSheet(
                patternDensity: $patternDensity,
                dotSize: $dotSize,
                animationSpeed: $animationSpeed,
                isPlaying: $isPlaying,
                selectedPattern: $selectedPattern,
                isMultiColored: $isMultiColored,
                gradientSpeed: $gradientSpeed,
                selectedMode: $selectedMode,
                sphereSize: $sphereSize
            )
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
