//
//  AudioManager.swift
//  Navgi
//
//  Created by Abhishek Chikhalkar on 07/03/25.
//


import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?
    
    func playBeep(volume: Float, rate: Float) {
        guard let url = Bundle.main.url(forResource: "beep", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = volume
            player?.rate = rate
            player?.play()
        } catch {
            print("Audio error: \(error)")
        }
    }
}
