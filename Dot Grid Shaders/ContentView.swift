import SwiftUI

struct ContentView: View {
    @State private var patternDensity: Double = 40.0
    @State private var dotSize: Double = 0.15
    @State private var animationSpeed: Double = 0.8
    @State private var isPlaying: Bool = false
    @State private var selectedPattern: PatternType = .verticalWave
    @State private var touchPosition: CGPoint?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
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
                .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
                .onChange(of: selectedPattern) { oldValue, newValue in
                    print("Pattern selection changed - Old: \(oldValue.rawValue), New: \(newValue.rawValue)")
                }

                VStack(spacing: 15) {
                    // Pattern selector
                    Picker("Pattern", selection: $selectedPattern) {
                        ForEach(PatternType.allCases) { pattern in
                            Text(pattern.name).tag(pattern)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

                    HStack {
                        Text("Density")
                            .foregroundColor(.white)
                        Slider(value: $patternDensity, in: 10.0 ... 50.0)
                            .tint(.white)
                    }

                    HStack {
                        Text("Dot Size")
                            .foregroundColor(.white)
                        Slider(value: $dotSize, in: 0.05 ... 0.3)
                            .tint(.white)
                    }

                    HStack {
                        Text("Speed")
                            .foregroundColor(.white)
                        Slider(value: $animationSpeed, in: 0.1 ... 2.0)
                            .tint(.white)
                    }

                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 10)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .padding(.bottom)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
