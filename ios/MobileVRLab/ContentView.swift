import SwiftUI

@main
struct MobileVRLabApp: App {
    @StateObject private var store = TranscriptStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                OverviewView()
                    .tabItem { Label("Overview", systemImage: "visionpro") }
                TranscriptView()
                    .tabItem { Label("Transcript", systemImage: "text.quote") }
                GuideView()
                    .tabItem { Label("Guide", systemImage: "list.bullet.clipboard") }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .tint(Color(red: 0.72, green: 0.96, blue: 0.42))
        }
    }
}

struct OverviewView: View {
    private let lime = Color(red: 0.72, green: 0.96, blue: 0.42)
    private let cyan = Color(red: 0.45, green: 0.86, blue: 0.88)
    private let orange = Color(red: 1.0, green: 0.57, blue: 0.33)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    sectionLabel("THE SIGNAL", color: orange)
                    Text("What the project prioritizes").font(.title2.bold())
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            stat("60", "Hz head tracking", lime)
                            stat("45", "Hz hands ceiling", cyan)
                        }
                        HStack(spacing: 12) {
                            stat("15", "Hz eye tracking", orange)
                            stat("2:06", "battery test", .primary)
                        }
                    }
                    sectionLabel("THE STORY", color: cyan)
                    Text("Follow the build").font(.title2.bold())
                    VStack(spacing: 12) {
                        ForEach(storyBeats) { beat in
                            StoryCard(beat: beat)
                        }
                    }
                    Text("Read every timestamp in the Transcript tab.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("Mobile VR Lab")
            .toolbarTitleDisplayMode(.large)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("FIELD NOTE 01", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.bold()).foregroundStyle(lime)
                Spacer()
                Text("14:48").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Text("PC VR, reimagined\nfor a phone.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.8)
            Text("A timestamped companion to a mobile tracking experiment using an off-the-shelf VR headset, phone cameras, and a computer-side bridge.")
                .font(.subheadline).foregroundStyle(Color.white.opacity(0.75))
            HStack(spacing: 8) {
                Chip("iPhone 12 Pro")
                Chip("Steam VR")
            }
            Link(destination: URL(string: "https://www.youtube.com/watch?v=SumuUznu8xc")!) {
                Label("Watch source video", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.12, green: 0.28, blue: 0.22), Color(red: 0.08, green: 0.14, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

struct StoryCard: View {
    let beat: StoryBeat
    var color: Color { beat.colorName == "lime" ? .green : beat.colorName == "cyan" ? .cyan : beat.colorName == "orange" ? .orange : .primary }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(beat.timestamp).font(.caption.monospaced().bold()).foregroundStyle(color).frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(beat.title).font(.headline)
                Text(beat.detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

struct Chip: View {
    let value: String
    init(_ value: String) { self.value = value }
    var body: some View { Text(value).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.1), in: Capsule()) }
}

func sectionLabel(_ text: String, color: Color) -> some View {
    Text(text).font(.caption.bold()).tracking(1.4).foregroundStyle(color)
}

struct TranscriptView: View {
    @EnvironmentObject private var store: TranscriptStore
    @State private var query = ""
    private var filtered: [TranscriptLine] {
        guard !query.isEmpty else { return store.lines }
        return store.lines.filter { $0.text.localizedCaseInsensitiveContains(query) || $0.timestamp.contains(query) }
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FULL TRANSCRIPT").font(.caption.bold()).tracking(1.4).foregroundStyle(.green)
                            Text("Every timestamp from the source video").font(.title3.bold())
                            Text("Search the complete transcript below. The source language and wording are preserved.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                        ForEach(filtered) { line in
                            HStack(alignment: .top, spacing: 14) {
                                Text(line.timestamp).font(.caption.monospaced().bold()).foregroundStyle(.green).frame(width: 46, alignment: .leading)
                                Text(line.text).font(.body).foregroundStyle(.primary).textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 5)
                            .id(line.id)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 28)
                }
            }
            .searchable(text: $query, prompt: "Search transcript")
            .navigationTitle("Transcript")
            .toolbarTitleDisplayMode(.large)
        }
    }
}

struct GuideView: View {
    private let cards = [
        ("01", "Head tracking", "Use stable visual-inertial odometry first. The project keeps this at 60 Hz and gives it highest priority so the phone stays responsive.", Color.green),
        ("02", "Hands + depth", "Two-hand tracking is capped around 45 Hz and smoothed on the computer side. Finger curl works; finger spread and perfect joint accuracy are harder.", Color.cyan),
        ("03", "Eye calibration", "A region of interest, red ellipse, green pupil ellipse, and white eye-center point turn pupil movement into normalized VR input. Brightness and headset fit matter.", Color.orange),
        ("04", "Battery reality", "Running cameras and tracking together is a thermal and battery trade-off. One full test lasted a little over two hours, with more data needed.", Color.primary)
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionLabel("BUILD NOTES", color: .orange)
                    Text("A practical reading\nof the experiment").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Use these notes as a compact map before diving into the full transcript.").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(cards, id: \.0) { card in
                        HStack(alignment: .top, spacing: 14) {
                            Text(card.0).font(.caption.monospaced().bold()).foregroundStyle(card.3).frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.1).font(.headline)
                                Text(card.2).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(17)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SCOPE NOTE").font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary)
                        Text("This app is a companion and reading tool; it does not claim to reproduce the original computer-side Steam VR bridge.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 28)
            }
            .navigationTitle("Guide")
            .toolbarTitleDisplayMode(.large)
        }
    }
}
