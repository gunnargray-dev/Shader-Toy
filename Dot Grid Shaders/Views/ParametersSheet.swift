import SwiftUI

// MARK: - View

struct ParametersSheet: View {
    // MARK: Properties

    @Environment(\.dismiss) var dismiss
    @Binding var animationSpeed: Double
    @Binding var isPlaying: Bool
    @Binding var particleSize: Double
    @Binding var particleCount: Double
    @Binding var sphereSize: Double

    // MARK: Initialization

    init(animationSpeed: Binding<Double>,
         isPlaying: Binding<Bool>,
         particleSize: Binding<Double>,
         particleCount: Binding<Double>,
         sphereSize: Binding<Double>)
    {
        _animationSpeed = animationSpeed
        _isPlaying = isPlaying
        _particleSize = particleSize
        _particleCount = particleCount
        _sphereSize = sphereSize
    }

    // MARK: Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading) {
                            Text("Particle Size")
                                .foregroundColor(.secondary)
                            Slider(value: $particleSize, in: 0.001 ... 0.01)
                                .tint(.primary)
                        }

                        VStack(alignment: .leading) {
                            Text("Animation Speed")
                                .foregroundColor(.secondary)
                            Slider(value: $animationSpeed, in: 0.1 ... 2.0)
                                .tint(.primary)
                        }

                        VStack(alignment: .leading) {
                            Text("Particle Count")
                                .foregroundColor(.secondary)
                            Slider(value: $particleCount, in: 500 ... 2000)
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

                    Button(action: { isPlaying.toggle() }) {
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
        animationSpeed: .constant(0.8),
        isPlaying: .constant(false),
        particleSize: .constant(0.003),
        particleCount: .constant(1000),
        sphereSize: .constant(400.0)
    )
}
