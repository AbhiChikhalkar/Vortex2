// ViewController.swift
import UIKit
import RealityKit
import ARKit
import CoreHaptics
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: - UI Components
    private let arView = ARView()
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private let depthManager = DepthManager()
    private var engine: CHHapticEngine?
    private var lastHapticTime = Date()
    private var lastBeepTime = Date()
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupUI()
        prepareHaptics()
        setupDepthManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    // MARK: - Setup
    private func setupARView() {
        arView.frame = view.bounds
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
    }
    
    private func setupUI() {
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupDepthManager() {
        depthManager.onStatusUpdate = { [weak self] in
            self?.handleNavigationFeedback()
            self?.statusLabel.text = self?.depthManager.statusDescription
        }
    }
    
    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.session.run(configuration)
    }
    
    // MARK: - Haptics & Audio
    private func prepareHaptics() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                engine = try CHHapticEngine()
                try engine?.start()
            }
        } catch {
            print("Initialization error: \(error)")
        }
    }
    
    private func handleNavigationFeedback() {
        guard depthManager.closestDistance < 20 else { return }
        
        if depthManager.closestDistance < 0.5 {
            provideProximityHapticAndBeep()
        }
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
        
        if currentTime.timeIntervalSince(lastBeepTime) > beepInterval {
            playBeepSound(volume: volume, rate: Float(1.0 + proximity))
            lastBeepTime = currentTime
        }
    }
    
    private func playBeepSound(volume: Float, rate: Float) {
        guard let url = Bundle.main.url(forResource: "beep", withExtension: "wav") else {
            print("Beep sound file not found")
            return
        }
        
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

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        depthManager.processDepth(frame)
    }
}