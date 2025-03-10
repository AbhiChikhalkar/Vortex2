//
//  ViewController.swift
//  Navgi
//
//  Created by Abhishek Chikhalkar on 07/03/25.
//

import UIKit
import ARKit
import RealityKit

class ViewController: UIViewController {
    private let arView = ARView()
    private let statusLabel = UILabel()
    private let depthManager = DepthManager.shared
    private let hapticManager = HapticManager.shared
    private let audioManager = AudioManager.shared
    private var lastHapticTime = Date()
    private var lastBeepTime = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupARView()
        setupUI()
        setupManagers()
    }
    
    private func setupARView() {
        arView.removeFromSuperview()
        arView.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable camera feed
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        view.addSubview(arView)
        
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
        
        // Transparent background to show camera feed
        arView.backgroundColor = .clear
    }
    
    private func setupUI() {
        statusLabel.text = "Initializing..."
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 24, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: arView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupManagers() {
        ARManager.shared.setupARSession(arView.session)
        depthManager.delegate = self
        hapticManager.prepare()
    }
}

extension ViewController: DepthManagerDelegate {
    func didUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = status
        }
    }
    
    func handleFeedback(forDistance distance: Float) {
        let currentTime = Date()
        let proximity = depthManager.proximity
        
        if distance < 0.5 {
            handleProximityFeedback(currentTime: currentTime, proximity: proximity)
        } else {
            handleGuidanceFeedback(currentTime: currentTime, proximity: proximity)
        }
    }
    
    private func handleProximityFeedback(currentTime: Date, proximity: Double) {
        if currentTime.timeIntervalSince(lastHapticTime) > 0.1 {
            hapticManager.playContinuousHaptic(intensity: Float(proximity), sharpness: 0.8)
            lastHapticTime = currentTime
        }
        
        let beepInterval = max(0.05, 1.0 - (proximity * 0.95))
        if currentTime.timeIntervalSince(lastBeepTime) > beepInterval {
            audioManager.playBeep(volume: Float(proximity), rate: Float(1.0 + proximity))
            lastBeepTime = currentTime
        }
    }
    
    private func handleGuidanceFeedback(currentTime: Date, proximity: Double) {
        let minInterval = max(0.15, 0.3 - (proximity * 0.25))
        guard currentTime.timeIntervalSince(lastHapticTime) > minInterval else { return }
        hapticManager.playPattern(for: depthManager.status, proximity: proximity)
        lastHapticTime = currentTime
    }
}
