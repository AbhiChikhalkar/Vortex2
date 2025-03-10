//
//  ARManager.swift
//  Navgi
//
//  Created by Abhishek Chikhalkar on 07/03/25.
//




import ARKit

class ARManager: ObservableObject {
    static let shared = ARManager()
    private init() {}
    
    func setupARSession(_ session: ARSession) {
        let configuration = ARWorldTrackingConfiguration().then {
            $0.sceneReconstruction = [.meshWithClassification]
            $0.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
            
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                $0.frameSemantics.insert(.personSegmentationWithDepth)
            }
        }
        session.run(configuration)
    }
}
