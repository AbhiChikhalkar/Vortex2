//
//  ARManager.swift
//  Navgi
//
import ARKit
import RealityKit

class ARManager: NSObject, ObservableObject {
    @Published var statusText = "Initializing..."
    
    func setupARSession(_ session: ARSession) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        session.run(configuration)
    }
}