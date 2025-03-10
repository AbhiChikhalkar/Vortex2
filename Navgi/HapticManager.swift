//
//  HapticManager.swift
//  Navgi
//
//  Created by Abhishek Chikhalkar on 07/03/25.
//

import CoreHaptics

class HapticManager {
    static let shared = HapticManager()
    private var engine: CHHapticEngine?
    
    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine error: \(error)")
        }
    }
    
    // Public method for status-based feedback
    func playPattern(for status: DepthManager.NavigationStatus, proximity: Double) {
        var events = [CHHapticEvent]()
        
        switch status {
        case .caution:
            let intensity = Float(proximity * 1.8)
            events.append(createContinuousEvent(intensity: intensity, duration: 0.5))
        case .stop:
            events.append(createTransientEvent(intensity: 1.0))
            events.append(createTransientEvent(intensity: 1.0, delay: 0.2))
        default:
            break
        }
        
        playPattern(events: events)
    }
    
    func playContinuousHaptic(intensity: Float, sharpness: Float) {
        guard let engine = engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: 0.3
        )
        playPattern(events: [event])
    }
    
    // Private helper to play events
    private func playPattern(events: [CHHapticEvent]) {
        guard let engine = engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            print("Haptic error: \(error)")
        }
    }
    
    private func createContinuousEvent(intensity: Float, duration: Double) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0,
            duration: duration
        )
    }
    
    private func createTransientEvent(intensity: Float, delay: Double = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: delay
        )
    }
}
