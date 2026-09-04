import Foundation

struct TranscriptLine: Identifiable, Hashable {
    let id = UUID()
    let timestamp: String
    let text: String
}
