import Accelerate
import AVFoundation
import Combine
import Foundation

final actor Mic: NSObject {
    enum State: Equatable {
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch lhs {
            case .quiet:
                if case .quiet = rhs {
                    return true
                }
            case .listening:
                if case .listening = rhs {
                    return true
                }
            }
            return false
        }

        case quiet(prefixBuffer: [Float]), listening(quietPeriods: Int)

        var isQuiet: Bool {
            if case .quiet = self {
                return true
            }
            return false
        }
    }

    var state = State.quiet(prefixBuffer: []) {
        didSet {
            switch oldValue {
            case .quiet:
                switch state {
                case .quiet:
                    break

                case .listening:
                    log("Starting to listen")
                    statePublisher.send(.listening(quietPeriods: 0))
                }

            case let .listening(quietPeriods1):
                switch state {
                case .quiet:
                    log("Stopped listening")
                    statePublisher.send(.quiet(prefixBuffer: []))

                case let .listening(quietPeriods2):
                    if quietPeriods1 == 0, quietPeriods2 != 0 {
                        log("Stopped or paused?")
                    } else if quietPeriods1 != 0, quietPeriods2 == 0 {
                        log("Was a pause, still listening")
                    }
                }
            }
        }
    }

    let statePublisher = CurrentValueSubject<State, Never>(.quiet(prefixBuffer: []))

    private let audioEngine = AVAudioEngine()
    private var buffer = [Float]()
    private let SampleRate = 16000

    override init() {
        super.init()

        let input = audioEngine.inputNode

        let inputFormat = input.outputFormat(forBus: 0)
        let incomingSampleRate = AVAudioFrameCount(inputFormat.sampleRate)

        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(SampleRate), channels: 1, interleaved: true)!
        let outputFrames = AVAudioFrameCount(outputFormat.sampleRate)

        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] incomingBuffer, _ in
            guard let self else { return }

            let inNumberFrames = incomingBuffer.frameLength
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrames * inNumberFrames / incomingSampleRate)!

            var error: NSError?
            var reported = AVAudioConverterInputStatus.haveData
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = reported
                reported = .noDataNow
                return incomingBuffer
            }
            assert(status != .error)

            let numSamples = Int(convertedBuffer.frameLength)
            let segmentCopy = [Float](unsafeUninitializedCapacity: numSamples) { buffer, initializedCount in
                _ = memcpy(buffer.baseAddress!, convertedBuffer.floatChannelData![0], numSamples * MemoryLayout<Float>.size)
                initializedCount = numSamples
            }

            var avgValue: Float32 = 0
            vDSP_meamgv(incomingBuffer.floatChannelData![0], 1, &avgValue, vDSP_Length(inNumberFrames))
            let v: Float = if avgValue == 0 {
                -100
            } else {
                20.0 * log10f(avgValue)
            }
            Task {
                await self.append(segment: segmentCopy, energyV: v)
            }
        }

        Task {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    private var remoteMode = false

    func setRemoteMode(_ remote: Bool) {
        remoteMode = remote
    }

    // TODO: detect and advise to turn on voice isolation

    private var micRunning = false

    func start() async throws {
        if micRunning {
            return
        }
        micRunning = true
        buffer.removeAll()
        state = .quiet(prefixBuffer: [])
        if remoteMode {
            log("Mic running (remote mode)")
        } else {
            try audioEngine.start()
            log("Mic running")
        }
    }

    func addToBuffer(_ data: Data) {
        let floatSize = MemoryLayout<Float>.size
        let floatCount = data.count / floatSize
        log("Received \(floatCount) samples from external source")
        let floats = [Float](unsafeUninitializedCapacity: floatCount) { floatBuffer, initializedCount in
            _ = data.copyBytes(to: floatBuffer)
            initializedCount = floatCount
        }
        buffer.append(contentsOf: floats)
    }

    private var lastEnergy: Float = 1000
    #if os(macOS)
        private let voiceSensitivity: Float = 50
    #else
        private let voiceSensitivity: Float = 30
    #endif
    private func append(segment: [Float], energyV: Float) {
        let energy = (0.3 * energyV) + ((1 - 0.3) * lastEnergy)
        print(energy, energyV)

        switch state {
        case let .quiet(prefixBuffer):
            var newBuffer = prefixBuffer + segment
            if newBuffer.count > SampleRate {
                newBuffer.removeFirst(1000)
            }
            // log("Sample energy: \(energy)")
            if lastEnergy < -voiceSensitivity, energy > -voiceSensitivity {
                state = .listening(quietPeriods: 0)
                buffer.append(contentsOf: newBuffer)
            } else {
                state = .quiet(prefixBuffer: newBuffer)
            }
        case let .listening(quietPeriods):
            if energy < -voiceSensitivity {
                let count = quietPeriods + segment.count
                if count > SampleRate * 2 {
                    state = .quiet(prefixBuffer: [])
                } else {
                    state = .listening(quietPeriods: count)
                    buffer.append(contentsOf: segment)
                }
            } else {
                state = .listening(quietPeriods: 0)
                buffer.append(contentsOf: segment)
            }
        }
        lastEnergy = energy
    }

    func stop() async throws -> [Float] {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        micRunning = false

        let ret = buffer
        buffer.removeAll()
        log("Mic stopped, have \(ret.count) samples")
        return ret
    }
}