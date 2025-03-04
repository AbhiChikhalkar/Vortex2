// DepthManager.swift
import ARKit
import Combine

class DepthManager: NSObject {
    
    // MARK: - Properties
    var onStatusUpdate: (() -> Void)?
    var closestDistance: Float = 0.0
    var status: NavigationStatus = .clear
    var proximity: Double = 0.0
    
    // MARK: - Private Properties
    private var statusUpdate = PassthroughSubject<Void, Never>()
    private var distanceBuffer = [Float]()
    
    // MARK: - Enums
    enum NavigationStatus: String {
        case clear, caution, stop
    }
    
    // MARK: - Computed Properties
    var statusDescription: String {
        status.rawValue
    }
    
    // MARK: - Public Methods
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
    
    // MARK: - Private Methods
    private func updateStatus(with distance: Float) {
        closestDistance = distance
        proximity = Double(max(0, min(1, 1 - (distance / 1.5)))
        
        switch distance {
        case ..<0.3: status = .stop
        case 0.3..<1.0: status = .caution
        default: status = .clear
        }
        
        onStatusUpdate?()
    }
}