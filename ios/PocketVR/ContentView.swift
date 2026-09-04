import SwiftUI

@main
struct PocketVRApp: App {
    @StateObject private var tracker = TrackingStore()
    @StateObject private var transcript = TranscriptStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                BridgeView().tabItem { Label("Bridge", systemImage: "dot.radiowaves.left.and.right") }
                StereoView().tabItem { Label("VR View", systemImage: "visionpro") }
                NotesView().tabItem { Label("Notes", systemImage: "text.quote") }
            }
            .environmentObject(tracker).environmentObject(transcript)
            .preferredColorScheme(.dark)
            .tint(Color(red: 0.72, green: 0.96, blue: 0.42))
        }
    }
}

struct BridgeView: View {
    @EnvironmentObject private var tracker: TrackingStore
    @State private var trackingMode = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("LIVE PHONE TRACKING", systemImage: "waveform.path.ecg").font(.caption.bold()).foregroundStyle(.green)
                        Text("PocketVR Bridge").font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Put the phone in a camera-clear VR headset. ARKit supplies head pose; TrueDepth face tracking supplies gaze signals.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading).glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
                    Picker("Tracking mode", selection: $trackingMode) { Text("ARKit head").tag(0); Text("TrueDepth eyes").tag(1) }.pickerStyle(.segmented)
                    Group {
                        if trackingMode == 0 { TrackingPreview(store: tracker) } else { EyeTrackingPreview(store: tracker) }
                    }
                    .frame(height: 235).clipShape(.rect(cornerRadius: 22)).overlay(alignment: .topLeading) { Text(trackingMode == 0 ? "REAR CAMERA • WORLD TRACKING" : "FRONT CAMERA • FACE TRACKING").font(.caption2.bold()).padding(10).background(.black.opacity(0.62), in: Capsule()).padding(12) }
                    HStack(spacing: 12) {
                        TelemetryCard(value: "\(tracker.headFPS)", label: "head Hz", color: .green)
                        TelemetryCard(value: String(format: "%.1f°", tracker.yaw), label: "yaw", color: .cyan)
                        TelemetryCard(value: String(format: "%.2f", tracker.blink), label: "blink", color: .orange)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label("PC POSE LINK", systemImage: "antenna.radiowaves.left.and.right").font(.caption.bold()).foregroundStyle(.orange)
                        Text("Opt-in UDP packets are sent to the Linux bridge. The bridge writes the same pose into the OpenXR layer state file.").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            TextField("PC IP", text: $tracker.serverHost).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                            TextField("Port", text: $tracker.serverPort).textFieldStyle(.roundedBorder).keyboardType(.numberPad).frame(width: 82)
                        }
                        Button(tracker.sending ? "Stop pose stream" : "Start pose stream") { tracker.toggleSending() }.buttonStyle(.glassProminent)
                        Text(tracker.sending ? "Transmitting live pose JSON" : "Stream is off until you press Start").font(.caption).foregroundStyle(tracker.sending ? .green : .secondary)
                    }
                    .padding(18).glassEffect(.regular, in: .rect(cornerRadius: 22))
                    Text("This is a working tracking bridge prototype. A PC must run the PocketVR Linux daemon plus an existing OpenXR runtime; it does not replace the runtime compositor.").font(.caption).foregroundStyle(.secondary)
                }.padding(20).padding(.bottom, 28)
            }.navigationTitle("Bridge").toolbarTitleDisplayMode(.large)
        }
    }
}

struct TelemetryCard: View {
    let value: String; let label: String; let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(value).font(.title3.bold()).foregroundStyle(color); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(14).glassEffect(.regular, in: .rect(cornerRadius: 18)) }
}

struct StereoView: View {
    @EnvironmentObject private var tracker: TrackingStore
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack { Label("STEREO DISPLAY", systemImage: "visionpro").font(.caption.bold()).foregroundStyle(.green); Spacer(); Text(tracker.isRunning ? "TRACKING" : "READY").font(.caption.bold()).foregroundStyle(tracker.isRunning ? .green : .secondary) }.padding(.horizontal, 20)
                GeometryReader { geo in
                    HStack(spacing: 2) { EyePane(offset: -1, tracker: tracker); EyePane(offset: 1, tracker: tracker) }.frame(width: geo.size.width, height: geo.size.height)
                }.clipShape(.rect(cornerRadius: 24)).padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 5) { Text("HEAD POSE").font(.caption.bold()).foregroundStyle(.orange); Text(String(format: "yaw %.1f°   pitch %.1f°   roll %.1f°", tracker.yaw, tracker.pitch, tracker.roll)).font(.system(.subheadline, design: .monospaced)); Text("This stereo test view shifts its reticle from live ARKit pose. Put the device in landscape VR orientation for headset use.").font(.caption).foregroundStyle(.secondary) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).glassEffect(.regular, in: .rect(cornerRadius: 20)).padding(.horizontal, 20)
                Spacer()
            }.padding(.top, 12).navigationTitle("VR View").toolbarTitleDisplayMode(.large)
        }
    }
}

struct EyePane: View {
    let offset: Double; @ObservedObject var tracker: TrackingStore
    var body: some View { Canvas { context, size in
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.025, green: 0.06, blue: 0.07)))
        var grid = Path(); let shift = CGFloat(tracker.yaw * offset * 0.55)
        for x in stride(from: -size.width, through: size.width * 2, by: 28) { grid.move(to: CGPoint(x: x + shift, y: 0)); grid.addLine(to: CGPoint(x: x + shift, y: size.height)) }
        for y in stride(from: 0, through: size.height, by: 28) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
        context.stroke(grid, with: .color(.green.opacity(0.16)), lineWidth: 1)
        let c = CGPoint(x: size.width / 2 + shift, y: size.height / 2 + CGFloat(tracker.pitch * 1.4)); let r: CGFloat = 20
        context.stroke(Path(ellipseIn: CGRect(x: c.x-r, y: c.y-r, width: r*2, height: r*2)), with: .color(.green), lineWidth: 2)
        var cross=Path(); cross.move(to: CGPoint(x:c.x-32,y:c.y)); cross.addLine(to: CGPoint(x:c.x+32,y:c.y)); cross.move(to: CGPoint(x:c.x,y:c.y-32)); cross.addLine(to: CGPoint(x:c.x,y:c.y+32)); context.stroke(cross, with: .color(.white.opacity(0.85)), lineWidth: 1)
    }.overlay(alignment: .bottomLeading) { Text(offset < 0 ? "LEFT" : "RIGHT").font(.caption2.bold()).padding(8).foregroundStyle(.secondary) } }
}

struct NotesView: View {
    @EnvironmentObject private var store: TranscriptStore; @State private var query = ""
    var filtered: [TranscriptLine] { query.isEmpty ? store.lines : store.lines.filter { $0.text.localizedCaseInsensitiveContains(query) || $0.timestamp.contains(query) } }
    var body: some View { NavigationStack { ScrollView { LazyVStack(alignment: .leading, spacing: 12) { VStack(alignment: .leading, spacing: 6) { Text("SOURCE NOTES").font(.caption.bold()).tracking(1.3).foregroundStyle(.green); Text("Full video transcript").font(.title2.bold()); Text("The source transcript is bundled locally so the bridge remains useful offline.").font(.subheadline).foregroundStyle(.secondary) }.padding(.bottom, 8); ForEach(filtered) { line in HStack(alignment: .top, spacing: 12) { Text(line.timestamp).font(.caption.monospaced().bold()).foregroundStyle(.green).frame(width: 44, alignment: .leading); Text(line.text).font(.body); Spacer(minLength: 0) }.padding(.vertical, 3) } }.padding(20).padding(.bottom, 28) }.searchable(text: $query, prompt: "Search transcript").navigationTitle("Notes").toolbarTitleDisplayMode(.large) } }
