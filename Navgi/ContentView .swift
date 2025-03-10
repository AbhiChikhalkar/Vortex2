//
//  ContentView.swift
//  Navgi
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARManager
    @ObservedObject var depthManager: DepthManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView()
        arManager.setupARSession(arView.session)
        arView.session.delegate = depthManager
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var depthManager = DepthManager.shared
    @ObservedObject var arManager = ARManager.shared
    @State private var lastBeepTime = Date()
    
    var body: some View {
        ZStack {
            ARViewContainer(arManager: arManager, depthManager: depthManager)
                .edgesIgnoringSafeArea(.all)
            
            Text(depthManager.statusDescription)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding()
        }
        .onReceive(depthManager.$closestDistance) { _ in
            handleFeedback()
        }
    }
    
    private func handleFeedback() {
        guard depthManager.closestDistance < 5 else { return }
        let proximity = depthManager.proximity
        
        HapticManager.shared.playContinuousHaptic(
            intensity: Float(proximity),
            sharpness: 0.8
        )
        
        let beepInterval = max(0.05, 1.0 - (proximity * 0.95))
        if Date().timeIntervalSince(lastBeepTime) > beepInterval {
            AudioManager.shared.playBeep(
                volume: Float(min(1.0, proximity * 1.5)),
                rate: Float(1.0 + proximity)
            )
            lastBeepTime = Date()
        }
    }
}
