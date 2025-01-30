import SwiftUI

struct ContentView: View {
    @State private var isPlaying: Bool = true
    @State private var animationSpeed: Double = 0.8
    @State private var particleSize: Double = 0.003
    @State private var particleCount: Double = 1000
    @State private var sphereSize: Double = 400.0
    @State private var isShowingSheet = false
    @State private var isAudioEnabled = false
    @StateObject private var audioProcessor = AudioProcessor()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Only render ParticleShaderView when not in preview
            if !_isPreview {
                ParticleShaderView(
                    isPlaying: $isPlaying,
                    particleSpeed: animationSpeed,
                    particleSize: particleSize,
                    particleCount: Int(particleCount),
                    sphereSize: sphereSize,
                    isAudioEnabled: $isAudioEnabled
                )
                .environmentObject(audioProcessor)
                .onDisappear {
                    audioProcessor.stopMonitoring()
                }
                .ignoresSafeArea()
            }

            VStack {
                Spacer()

                // Settings button
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

                // Audio toggle
                Toggle("Audio Reactive", isOn: $isAudioEnabled)
                    .padding()
                    .background(Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 0.8))
                    .cornerRadius(10)
                    .padding(.bottom)
                    .onChange(of: isAudioEnabled) { _, newValue in
                        if newValue {
                            audioProcessor.startMonitoring()
                        } else {
                            audioProcessor.stopMonitoring()
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingSheet) {
            ParametersSheet(
                animationSpeed: $animationSpeed,
                isPlaying: $isPlaying,
                particleSize: $particleSize,
                particleCount: $particleCount,
                sphereSize: $sphereSize
            )
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
    }
}

// Helper to detect preview environment
private var _isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

#Preview {
    ContentView()
}
