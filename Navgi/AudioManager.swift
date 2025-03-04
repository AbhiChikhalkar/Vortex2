import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    
    func playBeep(volume: Float, rate: Float) {
        guard let url = Bundle.main.url(forResource: "beep", withExtension: "wav") else {
            print("Beep sound file not found")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.enableRate = true
            audioPlayer?.rate = rate
            audioPlayer?.play()
        } catch {
            print("Audio error: \(error)")
        }
    }
}