import Foundation
import ARKit
import SceneKit
import SwiftUI
import Network

@MainActor
final class TrackingStore: ObservableObject {
    @Published var isRunning = false
    @Published var trackingState = "Ready"
    @Published var headFPS = 0
    @Published var yaw = 0.0
    @Published var pitch = 0.0
    @Published var roll = 0.0
    @Published var x = 0.0
    @Published var y = 0.0
    @Published var z = 0.0
    @Published var leftEye = 0.0
    @Published var rightEye = 0.0
    @Published var blink = 0.0
    @Published var sending = false
    @Published var serverHost = "192.168.0.172"
    @Published var serverPort = "9000"
    private var frameClock = Date()
    private var frameCount = 0
    private var transmitter: PoseTransmitter?

    func updateHead(yaw: Double, pitch: Double, roll: Double, x: Double, y: Double, z: Double, state: String) {
        self.yaw = yaw; self.pitch = pitch; self.roll = roll
        self.x = x; self.y = y; self.z = z; trackingState = state
        isRunning = true
        frameCount += 1
        let elapsed = Date().timeIntervalSince(frameClock)
        if elapsed >= 0.5 { headFPS = Int(Double(frameCount) / elapsed); frameCount = 0; frameClock = Date() }
        if sending { transmit() }
    }

    func updateEyes(left: Double, right: Double, blink: Double) {
        leftEye = left; rightEye = right; self.blink = blink
        trackingState = "Face tracking active"; isRunning = true
        if sending { transmit() }
    }

    func toggleSending() {
        if sending { transmitter?.stop(); transmitter = nil; sending = false; return }
        guard let port = UInt16(serverPort), !serverHost.isEmpty else { return }
        let t = PoseTransmitter(); t.start(host: serverHost, port: port); transmitter = t; sending = true; transmit()
    }

    private func transmit() {
        let packet: [String: Any] = [
            "type": "pose", "source": "ios-arkit", "timestamp": Date().timeIntervalSince1970,
            "yaw": yaw, "pitch": pitch, "roll": roll, "x": x, "y": y, "z": z,
            "left_eye": leftEye, "right_eye": rightEye, "blink": blink
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: packet) else { return }
        transmitter?.send(data)
    }
}

final class PoseTransmitter {
    private let queue = DispatchQueue(label: "com.zaiahgaming.pocketvr.udp")
    private var connection: NWConnection?
    func start(host: String, port: UInt16) {
        guard let p = NWEndpoint.Port(rawValue: port) else { return }
        connection = NWConnection(host: NWEndpoint.Host(host), port: p, using: .udp)
        connection?.start(queue: queue)
    }
    func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }
    func stop() { connection?.cancel(); connection = nil }
}

struct TrackingPreview: UIViewRepresentable {
    @ObservedObject var store: TrackingStore
    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.preferredFramesPerSecond = 60
        view.automaticallyUpdatesLighting = true
        let scene = SCNScene()
        let reticle = SCNNode(geometry: SCNSphere(radius: 0.035))
        reticle.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen
        reticle.position = SCNVector3(0, 0, -1.2)
        scene.rootNode.addChildNode(reticle); view.scene = scene
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) { config.frameSemantics = .sceneDepth }
        view.session.delegate = context.coordinator
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        return view
    }
    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) { view.session.pause() }
    final class Coordinator: NSObject, ARSessionDelegate {
        let store: TrackingStore
        init(store: TrackingStore) { self.store = store }
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let e = frame.camera.eulerAngles
            let t = frame.camera.transform
            let state: String
            switch frame.camera.trackingState {
            case .normal: state = "ARKit normal"
            case .limited(let reason): state = "ARKit limited: \(reason)"
            case .notAvailable: state = "ARKit unavailable"
            @unknown default: state = "ARKit unknown"
            }
            Task { @MainActor in
                store.updateHead(yaw: Double(e.y) * 180 / .pi, pitch: Double(e.x) * 180 / .pi, roll: Double(e.z) * 180 / .pi,
                                 x: Double(t.columns.3.x), y: Double(t.columns.3.y), z: Double(t.columns.3.z), state: state)
            }
        }
    }
}

struct EyeTrackingPreview: UIViewRepresentable {
    @ObservedObject var store: TrackingStore
    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero); view.preferredFramesPerSecond = 60
        view.session.delegate = context.coordinator
        guard ARFaceTrackingConfiguration.isSupported else { return view }
        let config = ARFaceTrackingConfiguration(); config.isLightEstimationEnabled = true
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors]); return view
    }
    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) { view.session.pause() }
    final class Coordinator: NSObject, ARSessionDelegate {
        let store: TrackingStore
        init(store: TrackingStore) { self.store = store }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            let b = face.blendShapes
            let left = ((b[.eyeLookInLeft]?.doubleValue ?? 0) - (b[.eyeLookOutLeft]?.doubleValue ?? 0))
            let right = ((b[.eyeLookInRight]?.doubleValue ?? 0) - (b[.eyeLookOutRight]?.doubleValue ?? 0))
            let blink = ((b[.eyeBlinkLeft]?.doubleValue ?? 0) + (b[.eyeBlinkRight]?.doubleValue ?? 0)) / 2
            Task { @MainActor in store.updateEyes(left: left, right: right, blink: blink) }
        }
    }
}
