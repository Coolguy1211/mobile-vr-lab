import Foundation

struct TranscriptLine: Identifiable, Hashable {
    let id = UUID()
    let timestamp: String
    let text: String
}

struct StoryBeat: Identifiable {
    let id = UUID()
    let timestamp: String
    let title: String
    let detail: String
    let colorName: String
}

let storyBeats = [
    StoryBeat(timestamp: "00:01", title: "The premise", detail: "A phone handles head, hand, and eye tracking while a computer renders the VR world.", colorName: "lime"),
    StoryBeat(timestamp: "03:03", title: "Hand tracking", detail: "Smoothing, depth, gestures, and the 1× camera trade-off.", colorName: "cyan"),
    StoryBeat(timestamp: "07:46", title: "Eye tracking", detail: "Calibration, pupil position, FOV, and headset fit constraints.", colorName: "orange"),
    StoryBeat(timestamp: "13:15", title: "Battery + what comes next", detail: "Runtime measurements and ideas for extending hand range.", colorName: "cream")
]
