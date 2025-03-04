//
//  ContentView.swift
//  Distance
//
//  Created by Abhishek Chikhalkar on 26/02/25.
//

import SwiftUI
import RealityKit
import ARKit
import CoreHaptics
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject var depthManager = DepthManager()
    @State private var engine: CHHapticEngine?
    @State private var lastHapticTime = Date()
    @State private var lastBeepTime = Date()
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var beepBaseFrequency: Double = 440
    var body: some View {
        ZStack {
            ARViewContainer(depthManager: depthManager)
                .edgesIgnoringSafeArea(.all)
            
            Text(depthManager.statusDescription)
                .foregroundColor(.clear)
                .accessibilityLabel(depthManager.accessibilityDescription)
        }
        .onAppear(perform: prepareHaptics)
        .onReceive(depthManager.$statusUpdate) { _ in
            handleNavigationFeedback()
        }
    }

    func prepareHaptics() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                engine = try CHHapticEngine()
                try engine?.start()
            }
        } catch {
            print("Initialization error: \(error)")
        }
    }
    
    func handleNavigationFeedback() {
        guard depthManager.closestDistance < 20 else { return }
        
        if depthManager.closestDistance < 0.5 {
            provideProximityHapticAndBeep()
        } else {
            speakNavigationInstruction()
            provideHapticGuidance()
        }
    }
    
    private func speakNavigationInstruction() {
        guard depthManager.closestDistance >= 0.5 else { return }
        
        let message: String
        switch depthManager.status {
        case .caution:
            message = String(format: "", depthManager.closestDistance)
        case .stop:
            message = ""
        default:
            message = ""
        }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.4
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
    
    private func provideHapticGuidance() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let currentTime = Date()
        let minInterval = max(0.15, 0.3 - (depthManager.proximity * 0.25))
        
        var events = [CHHapticEvent]()
        let intensity = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: Float(max(0.4, depthManager.proximity * 1.8)))
        
        let sharpness = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 0.8)
        
        switch depthManager.status {
        case .caution:
            events.append(createContinuousEvent(
                intensity: intensity,
                sharpness: sharpness,
                duration: 0.5
            ))
            
        case .stop:
            events.append(createTransientEvent(intensity: 1.0, sharpness: 1.0))
            events.append(createTransientEvent(
                intensity: 1.0,
                sharpness: 1.0,
                timeOffset: 0.2
            ))
            
        default: break
        }
        
        guard !events.isEmpty, currentTime.timeIntervalSince(lastHapticTime) > minInterval else {
            return
        }
        
        playHapticPattern(events: events)
    }
    
    private func provideProximityHapticAndBeep() {
        let currentTime = Date()
        let proximity = depthManager.proximity
        
        // Dynamic beep parameters
        let beepInterval = max(0.05, 1.0 - (proximity * 0.95))
        let volume = Float(min(1.0, proximity * 1.5))
        
        // Haptic feedback
        let hapticIntensity = Float(proximity)
        let hapticSharpness: Float = 0.8
        
        if currentTime.timeIntervalSince(lastHapticTime) > 0.1 {
            let event = createContinuousEvent(
                intensity: CHHapticEventParameter(
                    parameterID: .hapticIntensity,
                    value: hapticIntensity
                ),
                sharpness: CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: hapticSharpness
                ),
                duration: 0.3
            )
            playHapticPattern(events: [event])
        }
        
        // Play beep with dynamic properties
        if currentTime.timeIntervalSince(lastBeepTime) > beepInterval {
            playBeepSound(volume: volume, rate: Float(1.0 + proximity))
            lastBeepTime = currentTime
        }
    }
    
    private func playBeepSound(volume: Float, rate: Float) {
        guard let url = Bundle.main.url(forResource: "beep", withExtension: "wav") else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.enableRate = true
            audioPlayer?.rate = rate
            audioPlayer?.play()
        } catch {
            print("Error playing beep: \(error)")
        }
    }
    
    private func createContinuousEvent(intensity: CHHapticEventParameter,
                                      sharpness: CHHapticEventParameter,
                                      duration: Double) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: duration
        )
    }
    
    private func createTransientEvent(intensity: Float,
                                     sharpness: Float,
                                     timeOffset: Double = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: timeOffset
        )
    }
    
    private func playHapticPattern(events: [CHHapticEvent]) {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
            lastHapticTime = Date()
        } catch {
            print("Haptic error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Depth Manager
class DepthManager: ObservableObject {
    @Published var statusUpdate = UUID()
    @Published var closestDistance: Float = 0.0
    @Published var status: NavigationStatus = .clear
    @Published var proximity: Double = 0.0
    
    enum NavigationStatus: String {
        case clear, caution, stop
    }
    
    var statusDescription: String {
        status.rawValue
    }
    
    var accessibilityDescription: String {
        switch status {
        case .clear: return ""
        case .caution: return ""
        case .stop: return ""
        }
    }
    
    func setupARSession(_ session: ARSession) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.frameSemantics = [.smoothedSceneDepth, .sceneDepth]
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        session.run(configuration)
    }
    
    func processDepth(_ frame: ARFrame) {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
        let depthMap = depthData.depthMap
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let floatData = baseAddress.assumingMemoryBound(to: Float32.self)
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        var minDistance: Float = .greatestFiniteMagnitude
        
        let yRange = max(0, height/2 - 50)...min(height-1, height/2 + 50)
        let xRange = max(0, width/2 - 50)...min(width-1, width/2 + 50)
        
        for y in yRange {
            for x in xRange {
                let index = y * width + x
                let distance = floatData[index]
                if distance > 0 && distance < minDistance {
                    minDistance = distance
                }
            }
        }
        
        DispatchQueue.main.async {
            self.updateStatus(with: minDistance != .greatestFiniteMagnitude ? minDistance : 10.0)
        }
    }
    
    private func updateStatus(with distance: Float) {
        closestDistance = distance
        proximity = Double(max(0, min(1, 1 - (distance / 1.5))))
        
        switch distance {
        case ..<0.3: status = .stop
        case 0.3..<1.0: status = .caution
        default: status = .clear
        }
        
        statusUpdate = UUID()
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var depthManager: DepthManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        depthManager.setupARSession(arView.session)
        arView.session.delegate = context.coordinator
        arView.environment.sceneUnderstanding.options = [.occlusion]
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(depthManager: depthManager)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let depthManager: DepthManager
        
        init(depthManager: DepthManager) {
            self.depthManager = depthManager
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            depthManager.processDepth(frame)
        }
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("AR Session Failed: \(error.localizedDescription)")
        }
        
        func sessionWasInterrupted(_ session: ARSession) {
            print("AR Session Interrupted")
        }
        
        func sessionInterruptionEnded(_ session: ARSession) {
            print("AR Session Resumed")
            session.run(session.configuration!)
        }
    }
}


#Preview {
    ContentView()
}

