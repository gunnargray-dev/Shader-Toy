import AVFoundation

class AudioProcessor: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let bufferSize: AVAudioFrameCount = 1024
    private let sampleRate: Double = 44100
    private let queue = DispatchQueue(label: "com.app.audioprocessor", qos: .userInitiated)
    private var isShuttingDown = false
    private var hasBeenSetup = false

    @Published var currentDecibels: Float = 0
    @Published var isMonitoring = false

    init() {
        inputNode = audioEngine.inputNode
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        guard !hasBeenSetup else { return }

        queue.sync {
            // No need for do-catch here since we're not throwing errors
            // Request microphone permission first
            let permission = AVAudioApplication.shared.recordPermission

            switch permission {
            case .denied:
                print("Microphone permission denied")
                return

            case .granted:
                continueAudioSetup()

            case .undetermined:
                // Request permission
                let semaphore = DispatchSemaphore(value: 0)
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        self.continueAudioSetup()
                    }
                    semaphore.signal()
                }
                semaphore.wait()

            @unknown default:
                return
            }
        }
    }

    private func continueAudioSetup() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                            mode: .default,
                                                            options: [.mixWithOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            setupAudioProcessing()
            hasBeenSetup = true
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }

    private func setupAudioProcessing() {
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self,
                  !self.isShuttingDown else { return }

            self.queue.async {
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let samples = Array(UnsafeBufferPointer(start: channelData,
                                                        count: Int(buffer.frameLength)))

                // Calculate RMS
                let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

                // Convert to decibels with safety checks
                var db: Float = -160
                if rms > 0 {
                    db = 20 * log10(rms)
                }

                // Normalize and clamp
                db = max(min(db, 0), -60)
                let normalizedDb = (db + 60) / 60

                DispatchQueue.main.async {
                    if !self.isShuttingDown {
                        self.currentDecibels = normalizedDb
                    }
                }
            }
        }
    }

    func startMonitoring() {
        queue.async { [weak self] in
            guard let self = self,
                  !self.isMonitoring,
                  !self.isShuttingDown else { return }

            do {
                if !audioEngine.isRunning {
                    try audioEngine.start()
                    DispatchQueue.main.async {
                        self.isMonitoring = true
                    }
                }
            } catch {
                print("Error starting audio monitoring: \(error)")
                cleanup()
            }
        }
    }

    func stopMonitoring() {
        queue.async { [weak self] in
            guard let self = self,
                  self.isMonitoring else { return }
            cleanup()
        }
    }

    private func cleanup() {
        isShuttingDown = true

        if audioEngine.isRunning {
            audioEngine.stop()
            inputNode.removeTap(onBus: 0)
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error deactivating audio session: \(error)")
        }

        DispatchQueue.main.async { [weak self] in
            self?.isMonitoring = false
            self?.currentDecibels = 0
            self?.isShuttingDown = false
        }
    }

    deinit {
        queue.sync {
            cleanup()
        }
    }
}
