import SwiftUI
import AVFoundation

struct LoopVideo: View {
    let name: String
    var aspectRatio: CGFloat = 720 / 420
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if reduceMotion { Image(name + "-poster").resizable().scaledToFill() }
            else { LoopPlayer(name: name, playing: scenePhase == .active) }
        }.aspectRatio(aspectRatio, contentMode: .fit).clipped()
            .accessibilityHidden(true)
    }
}

private struct LoopPlayer: UIViewRepresentable {
    let name: String
    let playing: Bool
    func makeUIView(context: Context) -> PlayerSurface { PlayerSurface(name: name) }
    func updateUIView(_ view: PlayerSurface, context: Context) { playing ? view.player.play() : view.player.pause() }
    static func dismantleUIView(_ view: PlayerSurface, coordinator: ()) { view.player.pause(); view.player.removeAllItems() }
}

private final class PlayerSurface: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    init(name: String) {
        super.init(frame: .zero)
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        (layer as? AVPlayerLayer)?.player = player
        (layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
    }
    required init?(coder: NSCoder) { fatalError("Use init(name:)") }
}
