import Foundation

enum AppMode: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .startup:
            if case .startup = rhs {
                return true
            }
        case .booting:
            if case .booting = rhs {
                return true
            }
        case .warmup:
            if case .warmup = rhs {
                return true
            }
        case .listening:
            if case .listening = rhs {
                return true
            }
        case .loading:
            if case .loading = rhs {
                return true
            }
        case .noting:
            if case .noting = rhs {
                return true
            }
        case .replying:
            if case .replying = rhs {
                return true
            }
        case .thinking:
            if case .thinking = rhs {
                return true
            }
        case .waiting:
            if case .waiting = rhs {
                return true
            }
        }
        return false
    }

    case startup, booting, warmup, loading(managers: [AssetManager]), waiting, listening(state: MicState), noting, thinking, replying

    init?(data: Data) {
        let primary: UInt8 = data[0]
        let secondary: UInt8 = data[1]
        switch primary {
        case 1:
            self = .booting
        case 2:
            switch secondary {
            case 1:
                self = .listening(state: .listening(quietPeriods: 0))
            case 2:
                self = .listening(state: .quiet(prefixBuffer: []))
            default:
                return nil
            }
        case 3:
            self = .loading(managers: [])
        case 4:
            self = .noting
        case 5:
            self = .replying
        case 6:
            self = .startup
        case 7:
            self = .thinking
        case 8:
            self = .waiting
        case 9:
            self = .warmup
        default:
            return nil
        }
    }

    var data: Data {
        var data = Data(repeating: 0, count: 2)

        switch self {
        case .booting:
            data[0] = 1
        case let .listening(state):
            data[0] = 2
            switch state {
            case .listening:
                data[1] = 1
            case .quiet:
                data[1] = 2
            }
        case .loading:
            data[0] = 3
        case .noting:
            data[0] = 4
        case .replying:
            data[0] = 5
        case .startup:
            data[0] = 6
        case .thinking:
            data[0] = 7
        case .waiting:
            data[0] = 8
        case .warmup:
            data[0] = 9
        }
        return data
    }

    #if canImport(AppKit)
        func audioFeedback(using speaker: Speaker) {
            switch self {
            case .listening:
                Task {
                    await speaker.playEffect(speaker.startEffect)
                }
            case .noting:
                Task {
                    await speaker.playEffect(speaker.endEffect)
                }
            case .booting, .loading, .replying, .startup, .thinking, .waiting, .warmup:
                break
            }
        }
    #endif

    var showGenie: Bool {
        switch self {
        case .noting, .replying, .thinking:
            true
        case .booting, .listening, .loading, .startup, .waiting, .warmup:
            false
        }
    }

    var showAlwaysOn: Bool {
        switch self {
        case .booting, .loading, .noting, .replying, .startup, .thinking, .warmup:
            false
        case .listening, .waiting:
            true
        }
    }
}