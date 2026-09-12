import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var shakePlayer: AVAudioPlayer?
    private var sprayPlayer: AVAudioPlayer?
    
    private init() {}
    
    /// 앱이 시작될 때 사운드 파일을 미리 로드합니다.
    func setupSounds() {
        // shake.mp3 또는 shake.wav 둘 다 지원
        if let url = Bundle.main.url(forResource: "shake", withExtension: "mp3") ?? Bundle.main.url(forResource: "shake", withExtension: "wav") {
            shakePlayer = try? AVAudioPlayer(contentsOf: url)
            shakePlayer?.numberOfLoops = -1 // 무한 반복 (흔드는 동안 계속 재생)
            shakePlayer?.prepareToPlay()
        }
        
        // spray.mp3 또는 spray.wav 둘 다 지원
        if let url = Bundle.main.url(forResource: "spray", withExtension: "mp3") ?? Bundle.main.url(forResource: "spray", withExtension: "wav") {
            sprayPlayer = try? AVAudioPlayer(contentsOf: url)
            sprayPlayer?.numberOfLoops = -1 // 무한 반복 (뿌리는 동안 계속 재생)
            sprayPlayer?.prepareToPlay()
        }
    }
    
    func playShake() {
        guard let player = shakePlayer else { return }
        if !player.isPlaying {
            player.play()
        }
    }
    
    func stopShake() {
        guard let player = shakePlayer else { return }
        if player.isPlaying {
            // 소리를 부드럽게 끄고 싶다면 fade out도 가능하지만, 
            // 찰칵 거리는 구슬 소리이므로 즉시 멈춤
            player.pause()
            player.currentTime = 0
        }
    }
    
    func playSpray() {
        guard let player = sprayPlayer else { return }
        if !player.isPlaying {
            player.play()
        }
    }
    
    func stopSpray() {
        guard let player = sprayPlayer else { return }
        if player.isPlaying {
            player.pause()
            // 다음에 쏠 때 처음부터 나도록 초기화
            player.currentTime = 0
        }
    }
}
