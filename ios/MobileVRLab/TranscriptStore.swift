import Foundation
import SwiftUI

@MainActor
final class TranscriptStore: ObservableObject {
    @Published private(set) var lines: [TranscriptLine] = []

    init() {
        guard let url = Bundle.main.url(forResource: "transcript", withExtension: "txt"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return }
        lines = source.split(separator: "\n").compactMap { raw in
            let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return TranscriptLine(timestamp: parts[0], text: parts[1])
        }
    }
}
