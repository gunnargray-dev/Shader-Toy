import SwiftUI

struct ParametersSheet: View {
    @Binding var patternDensity: Double
    @Binding var dotSize: Double
    @Binding var animationSpeed: Double
    @Binding var isPlaying: Bool
    @Binding var selectedPattern: PatternType
    @Binding var isMultiColored: Bool
    @Binding var gradientSpeed: Double

    init(patternDensity: Binding<Double>,
         dotSize: Binding<Double>,
         animationSpeed: Binding<Double>,
         isPlaying: Binding<Bool>,
         selectedPattern: Binding<PatternType>,
         isMultiColored: Binding<Bool>,
         gradientSpeed: Binding<Double>)
    {
        _patternDensity = patternDensity
        _dotSize = dotSize
        _animationSpeed = animationSpeed
        _isPlaying = isPlaying
        _selectedPattern = selectedPattern
        _isMultiColored = isMultiColored
        _gradientSpeed = gradientSpeed
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Pattern Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pattern")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        CustomSegmentedControl(
                            selection: $selectedPattern,
                            items: PatternType.allCases
                        )
                        .padding(.horizontal)
                    }
                    

                    // Parameters
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Density")
                                .foregroundColor(.secondary)
                            Slider(value: $patternDensity, in: 10 ... 100)
                                .tint(.primary)
                        }
                        

                        VStack(alignment: .leading) {
                            Text("Dot Size")
                                .foregroundColor(.secondary)
                            Slider(value: $dotSize, in: 0.05 ... 0.3)
                                .tint(.primary)
                        }

                        VStack(alignment: .leading) {
                            Text("Speed")
                                .foregroundColor(.secondary)
                            Slider(value: $animationSpeed, in: 0.1 ... 2.0)
                                .tint(.primary)
                        }
                    }
                    .padding(.horizontal)
                    

                    Button(action: {
                        isPlaying.toggle()
                    }) {
                        HStack {
                            Text(isPlaying ? "Pause Animation" : "Play Animation")
                            Spacer()
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        }
                    }
                    .padding(.horizontal)
                    

                    // Color Controls
                    VStack(alignment: .leading, spacing: 20) {
                        Toggle("Multi-Color Mode", isOn: $isMultiColored)
                            .tint(.primary)

                        if isMultiColored {
                            VStack(alignment: .leading) {
                                Text("Gradient Speed")
                                    .foregroundColor(.secondary)
                                Slider(value: $gradientSpeed, in: 0.1 ... 2.0)
                                    .tint(.primary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Color.clear.frame(height: 20)
                }
                .padding(.top)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ParametersSheet(
        patternDensity: .constant(40.0),
        dotSize: .constant(0.15),
        animationSpeed: .constant(0.8),
        isPlaying: .constant(false),
        selectedPattern: .constant(.verticalWave),
        isMultiColored: .constant(false),
        gradientSpeed: .constant(1.0)
    )
}
