import Foundation
import Metal

extension Asset {
    enum Category: Identifiable, Codable {
        case dolphinMixtral, deepSeekCoder, mythoMax, solar, shiningValiant, zephyr3b, whisper

        var format: Template.Format {
            switch self {
            case .shiningValiant: .llamaInst
            case .deepSeekCoder: .instruct
            case .dolphinMixtral: .chatml
            case .mythoMax: .instruct
            case .solar: .instruct
            case .whisper: .instruct
            case .zephyr3b: .zephyr
            }
        }

        private var defaultPrompt: String {
            switch self {
            case .deepSeekCoder: "You are an intelligent and helpful coding assistant."
            case .solar: "You are an intelligent and cheerful chatbot."
            case .dolphinMixtral: "You are an intelligent and cheerful chatbot."
            case .mythoMax: "You are an intelligent and helpful writing assistant."
            case .shiningValiant: "You are an intelligent, helpful AI assistant."
            case .zephyr3b: "You are an intelligent, helpful AI assistant."
            case .whisper: ""
            }
        }

        var useGpuOnThisSystem: Bool {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Failed to get the system's default Metal device.")
            }
            let vramSize = device.recommendedMaxWorkingSetSize / 1_000_000_000
            // log("Checking if current model selection can run on GPU (\(vramSize) GB)")
            return vramSize > vramRequiredToFitInGpu
        }

        var vramRequiredToFitInGpu: Int {
            switch self {
            case .dolphinMixtral: 34
            case .deepSeekCoder: 37
            case .solar: 9
            case .zephyr3b: 5
            case .mythoMax: 12
            case .whisper: 2
            case .shiningValiant: 60
            }
        }

        var sizeDescription: String {
            switch self {
            case .shiningValiant: "48.8 GB"
            case .dolphinMixtral: "32.2 GB"
            case .deepSeekCoder: "35.4 GB"
            case .solar: "7.6 GB"
            case .mythoMax: "10.6 GB"
            case .whisper: "1.1 GB"
            case .zephyr3b: "2.3 GB"
            }
        }

        var aboutText: String {
            switch self {
            case .deepSeekCoder:
                "This no-nonsense model focuses specifically on code-related generation and questions"
            case .dolphinMixtral:
                "The current state of the art, with multifaceted expertise and good conversational ability."
            case .mythoMax:
                "MythoMax is a model designed to be both imaginative and useful for creativity and writing."
            case .solar:
                "One of the highest performing models for chat. A great starting point."
            case .shiningValiant:
                "A large-size model focused on knowledge, enthusiasm, and structured reasoning."
            case .whisper:
                "OpenAI's industry leading speech recognition. Lets you talk directly to the model if you prefer. Ensure you have a good mic and 'voice isolation' is selected from the menubar for best results."
            case .zephyr3b:
                "Compact version of the very powerful Zephyr model, great for systems with constrained storage or processing requirements."
            }
        }

        var maxBatch: UInt32 {
            switch self {
            case .deepSeekCoder: 1024
            case .dolphinMixtral: 1024
            case .mythoMax: 1024
            case .solar: 1024
            case .shiningValiant: 1024
            case .zephyr3b: 1024
            case .whisper: 0
            }
        }

        private var defaultTopK: Int {
            switch self {
            case .deepSeekCoder: 49
            case .dolphinMixtral: 49
            case .mythoMax: 49
            case .solar: 49
            case .shiningValiant: 49
            case .zephyr3b: 49
            case .whisper: 0
            }
        }

        private var defaultTopP: Float {
            switch self {
            case .deepSeekCoder: 0.14
            case .dolphinMixtral: 0.14
            case .mythoMax: 0.14
            case .solar: 0.14
            case .shiningValiant: 0.14
            case .zephyr3b: 0.14
            case .whisper: 0
            }
        }

        private var defaultTemperature: Float {
            switch self {
            case .deepSeekCoder: 0.4
            case .dolphinMixtral: 1.31
            case .mythoMax: 1.31
            case .solar: 1.31
            case .shiningValiant: 0.7
            case .zephyr3b: 0.7
            case .whisper: 0
            }
        }

        private var defaultRepeatPenatly: Float {
            switch self {
            case .deepSeekCoder: 1
            case .dolphinMixtral: 1.17
            case .mythoMax: 1.17
            case .solar: 1.17
            case .shiningValiant: 1.1
            case .zephyr3b: 1.1
            case .whisper: 0
            }
        }

        private var defaultFrequencyPenalty: Float {
            switch self {
            case .deepSeekCoder: 0
            case .dolphinMixtral: 0.1
            case .mythoMax: 0.1
            case .solar: 0.1
            case .shiningValiant: 0.1
            case .zephyr3b: 0.1
            case .whisper: 0
            }
        }

        private var defaultPresentPenalty: Float {
            switch self {
            case .deepSeekCoder: 1
            case .dolphinMixtral: 1.1
            case .mythoMax: 1.1
            case .solar: 1.1
            case .shiningValiant: 1.1
            case .zephyr3b: 1.1
            case .whisper: 0
            }
        }

        var fetchUrl: URL {
            let uri = switch self {
            case .dolphinMixtral:
                "https://huggingface.co/TheBloke/dolphin-2.5-mixtral-8x7b-GGUF/resolve/main/dolphin-2.5-mixtral-8x7b.Q5_K_M.gguf"
            case .deepSeekCoder:
                "https://huggingface.co/TheBloke/deepseek-coder-33B-instruct-GGUF/resolve/main/deepseek-coder-33b-instruct.Q8_0.gguf"
            case .mythoMax:
                "https://huggingface.co/TheBloke/MythoMax-L2-13B-GGUF/resolve/main/mythomax-l2-13b.Q8_0.gguf"
            case .whisper:
                "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin"
            case .solar:
                "https://huggingface.co/jan-hq/Solar-10.7B-SLERP-GGUF/resolve/main/solar-10.7b-slerp.Q5_K_M.gguf"
            case .shiningValiant:
                "https://huggingface.co/TheBloke/ShiningValiant-1.3-GGUF/resolve/main/shiningvaliant-1.2.Q5_K_M.gguf"
            case .zephyr3b:
                "https://huggingface.co/TheBloke/stablelm-zephyr-3b-GGUF/resolve/main/stablelm-zephyr-3b.Q6_K.gguf"
            }
            return URL(string: uri)!
        }

        var displayName: String {
            switch self {
            case .dolphinMixtral: "Dolphin 2.5 (on Mixtral 7b)"
            case .deepSeekCoder: "DeepSeek Coder"
            case .mythoMax: "MythoMax Writing Assistant"
            case .whisper: "Whisper Large v3"
            case .solar: "Pandora Solar"
            case .shiningValiant: "Shining Valiant"
            case .zephyr3b: "Zephyr 3B"
            }
        }

        var id: String {
            switch self {
            case .dolphinMixtral: "43588C6F-FB70-4EDB-9C15-3B75E7C483FA"
            case .deepSeekCoder: "A4A183C7-718C-4E47-B880-F437DAFA9D5C"
            case .mythoMax: "AA4B3287-CA79-466F-8F84-87486D701256"
            case .whisper: "0FCCC65B-BD2B-470C-AFE2-637FABDA95EE"
            case .solar: "FB42FD61-E06E-4AA9-9EFA-DAAC98427904"
            case .shiningValiant: "25C3A6DB-A824-4011-9E8F-330D3B6310C7"
            case .zephyr3b: "CC1BB904-0DE1-4B28-8DC7-2DA94B1491EC"
            }
        }

        var defaultParams: Params {
            Params(topK: defaultTopK,
                   topP: defaultTopP,
                   systemPrompt: defaultPrompt,
                   temperature: defaultTemperature,
                   repeatPenatly: defaultRepeatPenatly,
                   frequencyPenatly: defaultFrequencyPenalty,
                   presentPenatly: defaultPresentPenalty)
        }
    }
}