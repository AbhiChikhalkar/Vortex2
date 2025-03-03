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

struct ContentView: View {
    @State var distance: Float = 0.0
    @State var navigationDirection: String = "clear"
    @State private var engine: CHHapticEngine?
    @State private var lastHapticTime = Date()
    @State private var proximity: Double = 0.0
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack {
            ARViewContainer(distance: $distance, navigationDirection: $navigationDirection, proximity: $proximity)
                .edgesIgnoringSafeArea(.all)
            
            Text(navigationDirection)
                .foregroundColor(.clear)
                .accessibilityLabel(accessibilityMessage)
        }
        .onAppear(perform: prepareHaptics)
        .onChange(of: navigationDirection) { _, newValue in
            handleNavigationFeedback(for: newValue)
        }
    }
    
    private var accessibilityMessage: String {
        if distance == 0 {
            return "Path clear, move forward confidently"
        }
        return "Navigation instruction: \(navigationDirection)"
    }

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine error: \(error)")
        }
    }
    
    func handleNavigationFeedback(for direction: String) {
        guard distance > 0 else { return }
        
        speakNavigationInstruction()
        provideHapticGuidance()
    }
    
    private func speakNavigationInstruction() {
        let message: String
        switch navigationDirection {
        case "turnRight":
            message = "Obstacle on left, turn right"
        case "turnLeft":
            message = "Obstacle on right, turn left"
        case "caution":
            message = String(format: "Caution: obstacle %.1f meters ahead", distance)
        case "stop":
            message = "Immediate obstacle, stop and check surroundings"
        default:
            message = "Path clear, proceed forward"
        }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.4
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
    
    private func provideHapticGuidance() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let currentTime = Date()
        let minInterval = calculateMinInterval()
        
        var events = [CHHapticEvent]()
        let intensity = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: Float(max(0.4, proximity * 1.8))
        )
        
        let sharpness = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 0.8
        )
        
        switch navigationDirection {
        case "turnRight":
            events.append(createTransientEvent(intensity: 1.0, sharpness: 1.0))
            events.append(createContinuousEvent(
                intensity: intensity,
                sharpness: sharpness,
                duration: 0.3
            ))
            
        case "turnLeft":
            events.append(createTransientEvent(intensity: 1.0, sharpness: 1.0))
            events.append(createContinuousEvent(
                intensity: intensity,
                sharpness: sharpness,
                duration: 0.3
            ))
            
        case "caution":
            events.append(createContinuousEvent(
                intensity: intensity,
                sharpness: sharpness,
                duration: 0.5
            ))
            
        case "stop":
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
    
    private func calculateMinInterval() -> TimeInterval {
        max(0.15, 0.3 - (proximity * 0.25))
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

struct ARViewContainer: UIViewRepresentable {
    @Binding var distance: Float
    @Binding var navigationDirection: String
    @Binding var proximity: Double
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        arView.session.delegate = context.coordinator
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            distance: $distance,
            navigationDirection: $navigationDirection,
            proximity: $proximity
        )
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        @Binding var distance: Float
        @Binding var navigationDirection: String
        @Binding var proximity: Double
        private var distanceBuffer = [Float]()
        
        init(distance: Binding<Float>, navigationDirection: Binding<String>, proximity: Binding<Double>) {
            _distance = distance
            _navigationDirection = navigationDirection
            _proximity = proximity
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let raycastQuery = ARRaycastQuery(
                origin: frame.camera.transform.translation,
                direction: frame.camera.transform.forwardVector,
                allowing: .existingPlaneInfinite,
                alignment: .any
            )
            
            let results = session.raycast(raycastQuery)
            
            DispatchQueue.main.async {
                guard let firstResult = results.first else {
                    self.handleNoDetection()
                    return
                }
                
                let cameraTransform = frame.camera.transform
                let targetPosition = firstResult.worldTransform.translation
                let cameraPosition = cameraTransform.translation
                let rawDistance = simd_distance(cameraPosition, targetPosition)
                
                self.distanceBuffer.append(rawDistance)
                self.distanceBuffer = Array(self.distanceBuffer.suffix(10))
                
                let smoothedDistance = self.distanceBuffer.reduce(0, +) / Float(self.distanceBuffer.count)
                self.proximity = Double(max(0, min(1, 1 - (smoothedDistance / 1.5))))
                self.distance = smoothedDistance
                
                let toTarget = targetPosition - cameraPosition
                let cameraForward = normalize(cameraTransform.forwardVector)
                let cameraRight = normalize(cameraTransform.rightVector)
                
                let crossProduct = cross(normalize(toTarget), cameraForward)
                let lateralBias = dot(crossProduct, cameraRight)
                
                let turnThreshold: Float = 0.2
                let stopThreshold: Float = 0.7
                
                if smoothedDistance < 1.5 {
                    if lateralBias > turnThreshold {
                        self.navigationDirection = "turnLeft"
                    } else if lateralBias < -turnThreshold {
                        self.navigationDirection = "turnRight"
                    } else if abs(lateralBias) > stopThreshold {
                        self.navigationDirection = "stop"
                    } else {
                        self.navigationDirection = smoothedDistance < 1.0 ? "caution" : "far"
                    }
                } else {
                    self.navigationDirection = "clear"
                }
            }
        }
        
        private func handleNoDetection() {
            self.distance = 0
            self.proximity = 0
            self.navigationDirection = "clear"
        }
    }
}

// MARK: - SIMD Extensions
extension float4x4 {
    var translation: SIMD3<Float> {
        return columns.3.xyz
    }
    
    var forwardVector: SIMD3<Float> {
        return normalize(-columns.2.xyz)
    }
    
    var rightVector: SIMD3<Float> {
        return normalize(columns.0.xyz)
    }
}

extension simd_float4 {
    var xyz: SIMD3<Float> {
        return SIMD3(x, y, z)
    }
}

#Preview {
    ContentView()
}
