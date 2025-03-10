//
//  DepthManager.swift
//  Navgi
//
//  Created by Abhishek Chikhalkar on 07/03/25.
//


import ARKit

protocol DepthManagerDelegate: AnyObject {
    func didUpdateStatus(_ status: String)
    func handleFeedback(forDistance distance: Float)
}

class DepthManager: NSObject, ARSessionDelegate, ObservableObject {
    static let shared = DepthManager()
    private override init() {}
    
    weak var delegate: DepthManagerDelegate?
    @Published var closestDistance: Float = 0.0
    @Published var proximity: Double = 0.0
    @Published var statusDescription: String = "Clear path"
    
    enum NavigationStatus { case clear, caution, stop }
    private(set) var status: NavigationStatus = .clear
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        processDepth(frame)
    }
    
    private func processDepth(_ frame: ARFrame) {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
        let depthMap = depthData.depthMap
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let floatData = baseAddress.assumingMemoryBound(to: Float32.self)
        
        let (width, height) = (CVPixelBufferGetWidth(depthMap), CVPixelBufferGetHeight(depthMap))
        var minDistance: Float = .greatestFiniteMagnitude
        
        // Sample center region
        for y in (height/2-30)...(height/2+30) {
            for x in (width/2-30)...(width/2+30) {
                let distance = floatData[y * width + x]
                if distance > 0 && distance < minDistance {
                    minDistance = distance
                }
            }
        }
        
        updateStatus(with: minDistance.isFinite ? minDistance : 10.0)
        delegate?.handleFeedback(forDistance: minDistance)
    }
    
    private func updateStatus(with distance: Float) {
        closestDistance = distance
        proximity = Double(max(0, min(1, 1 - (distance / 1.5))))
        
        status = {
            switch distance {
            case ..<0.3: return .stop
            case 0.3..<1.0: return .caution
            default: return .clear
            }
        }()
        
        statusDescription = {
            switch status {
            case .stop: return "STOP! \(String(format: "%.1f", distance))m"
            case .caution: return "Caution: \(String(format: "%.1f", distance))m"
            case .clear: return "Clear path"
            }
        }()
    }
}
