import SwiftUI

enum PatternMode: String, CaseIterable {
    case dotGrid = "Dot Grid"
    case particles = "Particles"
}

struct ParametersSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var patternDensity: Double
    @Binding var dotSize: Double
    @Binding var animationSpeed: Double
    @Binding var isPlaying: Bool
    @Binding var selectedPattern: PatternType
    @Binding var isMultiColored: Bool
    @Binding var gradientSpeed: Double
    @Binding var selectedMode: PatternMode
    @Binding var sphereSize: Double

    init(patternDensity: Binding<Double>,
         dotSize: Binding<Double>,
         animationSpeed: Binding<Double>,
         isPlaying: Binding<Bool>,
         selectedPattern: Binding<PatternType>,
         isMultiColored: Binding<Bool>,
         gradientSpeed: Binding<Double>,
         selectedMode: Binding<PatternMode>,
         sphereSize: Binding<Double>)
    {
        _patternDensity = patternDensity
        _dotSize = dotSize
        _animationSpeed = animationSpeed
        _isPlaying = isPlaying
        _selectedPattern = selectedPattern
        _isMultiColored = isMultiColored
        _gradientSpeed = gradientSpeed
        _selectedMode = selectedMode
        _sphereSize = sphereSize
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Pattern Mode Selector
                    Section {
                        Picker("Pattern Mode", selection: $selectedMode) {
                            ForEach(PatternMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if selectedMode == .dotGrid {
                        // Existing Dot Grid Controls
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

                        // Dot Grid Parameters
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
                    } else {
                        // Particle Controls
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Particle Size")
                                    .foregroundColor(.secondary)
                                Slider(value: $dotSize, in: 0.001 ... 0.01)
                                    .tint(.primary)
                            }

                            VStack(alignment: .leading) {
                                Text("Particle Speed")
                                    .foregroundColor(.secondary)
                                Slider(value: $animationSpeed, in: 0.1 ... 2.0)
                                    .tint(.primary)
                            }

                            VStack(alignment: .leading) {
                                Text("Particle Count")
                                    .foregroundColor(.secondary)
                                Slider(value: $patternDensity, in: 500 ... 2000)
                                    .tint(.primary)
                            }

                            VStack(alignment: .leading) {
                                Text("Sphere Size")
                                    .foregroundColor(.secondary)
                                Slider(value: $sphereSize, in: 200 ... 800)
                                    .tint(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Common Controls
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
                }
                .padding(.top)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .font(.title3)
                    }
                }
            }
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
        gradientSpeed: .constant(1.0),
        selectedMode: .constant(.dotGrid),
        sphereSize: .constant(400.0)
    )
}
