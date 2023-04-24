//
//  ROIPlayer.swift
//  single-HLS-To-MultiView
//
//  Created by Manasa M P on 06/04/23.
//

import Foundation
import AVFoundation
import AVKit
import CoreMedia


enum ConsumptionHLSStreamTemplate: Int {
    case template1
    case template2
    case template3
    case template4
    
    func getCGAffineTransform(for position: HLSStreamDivision.Position? = nil, size: CGSize) -> CGAffineTransform? {
        guard let position = position else { return nil }
        switch self.rawValue {
        case 0:
            return HLSStreamDivision.horizontalDivision.getFrameCGAffineTransform(for: position, size: size)
        case 1:
            if position == .topLeft || position == .topRight {
                return HLSStreamDivision.horizontalDivision.getFrameCGAffineTransform(for: position, size: size)
            } else if position == .bottomLeft || position == .bottomRight {
                return HLSStreamDivision.both.getFrameCGAffineTransform(for: position, size: size)
            }
        case 2:
            if position == .topLeft || position == .topRight {
                return HLSStreamDivision.both.getFrameCGAffineTransform(for: position, size: size)
            } else if position == .bottomLeft || position == .bottomRight {
                return HLSStreamDivision.horizontalDivision.getFrameCGAffineTransform(for: position, size: size)
            }
        case 3: return HLSStreamDivision.both.getFrameCGAffineTransform(for: position, size: size)
        default: return nil
        }
        return nil
    }
}

enum HLSStreamDivision: Int {
    case horizontalDivision
    case verticalDivision
    case both
    
    enum Position: Int {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
}

extension HLSStreamDivision {
    func getFrameCGAffineTransform(for position: HLSStreamDivision.Position, size: CGSize) -> CGAffineTransform {
        let transation = getTranslationTransformOnStreamDivision(with: size, position: position)
        return scaleFactor.concatenating(transation)
    }
    
    var scaleFactor: CGAffineTransform {
        switch self.rawValue {
        case 0: return CGAffineTransform(scaleX: 1, y: 2)
        case 1: return CGAffineTransform(scaleX: 2, y: 1)
        case 2:
            return CGAffineTransform(scaleX: 2, y: 2)
        default: return CGAffineTransform(scaleX: 1, y: 1)
        }
    }
    
    func getTranslationTransformOnStreamDivision(with size: CGSize, position: HLSStreamDivision.Position) -> CGAffineTransform  {
        switch self.rawValue {
        case 0:
            if position == .topLeft || position == .topRight {
                return CGAffineTransform(0, 0, 0, 0, 0, size.height/2)
            }else {
                return CGAffineTransform(translationX: 0, y: -(size.height/2))
            }
        case 1:
            if position == .topLeft || position == .bottomLeft {
                return CGAffineTransform(a: -1, b: 0, c: 0, d: 0, tx: size.width/2, ty: 0)
            }else {
                return CGAffineTransform(a: 1, b: 0, c: 0, d: 0, tx: size.width/2, ty: 0)
            }
        case 2:
            if position == .topLeft {
                return CGAffineTransform(translationX: (size.width/2), y: (size.height/2))
            } else if position == .topRight {
                return CGAffineTransform(translationX: -(size.width/2), y: (size.height/2))
            } else if position == .bottomLeft {
                return CGAffineTransform(translationX: (size.width/2), y: -(size.height/2))
            } else {
                return CGAffineTransform(translationX: -(size.width/2), y: -(size.height/2))
            }
        default:
            return CGAffineTransform(translationX: 0, y: 0)
        }
    }
}



enum PlaybackStatusConstants : String {
    case playbackBufferEmpty = "playbackBufferEmpty"
    case playbackLikelyToKeepUp = "playbackLikelyToKeepUp"
    case playbackBufferFull = "playbackBufferFull"
}

protocol VideoPlayerStatusDelegate: AnyObject {
    func showVideoLoader()
    func hideVideoLoader()
    func videoPlaybackFailedShowOfflineCard()
    func videoPlayStarted()
    func videoPlaybackFinishedShowOfflineCard()
    func videoPlayBackAsset(notificationObj: NSNotification)
}

class ROIVideoPlayer: NSObject {
    weak var delegate: VideoPlayerStatusDelegate?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerItemContext = 0
    var assetReader: AVAssetReader!
    
    override init() {
        super.init()
    }
    
    deinit {
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        playerItem?.removeObserver(self, forKeyPath: PlaybackStatusConstants.playbackBufferEmpty.rawValue)
        playerItem?.removeObserver(self, forKeyPath: PlaybackStatusConstants.playbackLikelyToKeepUp.rawValue)
        playerItem?.removeObserver(self, forKeyPath: PlaybackStatusConstants.playbackBufferFull.rawValue)
        NotificationCenter.default.removeObserver(self)
    }
}

extension ROIVideoPlayer {
    // Pause player
    func pausePlayerPlayback() {
        guard let player = player,
              player.isPlaying else { return }
        player.pause()
    }
    
    //Configure AVPlayer and AVPlayerItem
    func configureView(hlsURL: URL, completion: (() -> Void)?) {
        setupPlayerAudioSpeaker()
        setUpAsset(with: hlsURL) { [weak self] asset in
            self?.setupAVPlayer(with: asset)
            completion?()
        }
        player?.actionAtItemEnd =  .pause
    }
    
    func play() {
        player?.play()
    }
    
    // get AVPlayerLayer embedded with view for each region of interest
    @discardableResult func getROIPlayerLayer(with size: CGSize, translation: CGAffineTransform?) -> AVPlayerLayer {
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.contentsGravity = .resizeAspectFill
        
        
//        let transation = CGAffineTransform(translationX: translationPoint.x*(frame.width/2), y: translationPoint.y*(frame.height/2))
//        var scaleTransform = CGAffineTransform(scaleX: 2, y: 2)
//        scaleTransform = scaleTransform.concatenating(transation)
        //playerLayer.setAffineTransform(scaleTransform)
        
        if let t = translation {
            playerLayer.setAffineTransform(t)
        }
        return playerLayer
    }
    
    // Seek player position
    func seekLastPositionOfPlayer() {
        guard let player = player else { return }
        delegate?.showVideoLoader()
        guard let livePosition = player.currentItem?.seekableTimeRanges.last as? CMTimeRange else {
            return
        }
        let livePositionTimeEnd: CMTime = CMTimeRangeGetEnd(livePosition)
        guard livePositionTimeEnd.value > 0  else { return }
        player.seek(to: livePositionTimeEnd)
    }
}


extension ROIVideoPlayer {
    private func setUpAsset(with url: URL, completion: ((_ asset: AVAsset) -> Void)?) {
        let asset = AVAsset(url: url)
      
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "playable", error: &error)
            switch status {
            case .loaded:
                completion?(asset)
            case .failed:
                break
            case .cancelled:
                break
            case .loading:
                break
            default: break
            }
        }
    }
    
    private func setupAVPlayer(with asset: AVAsset) {
        setupAVPlayerItem(with: asset)
        DispatchQueue.main.async { [weak self] in
            guard let item = self?.playerItem else { return }
            self?.player = AVPlayer(playerItem: item)
        }
    }
    
    
    // MARK: Player Observer Methods
        
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            // Switch over status value
            switch status {
            case .readyToPlay:
                delegate?.videoPlayStarted()
            case .failed:
                delegate?.videoPlaybackFailedShowOfflineCard()
            case .unknown:
                delegate?.videoPlaybackFailedShowOfflineCard()
            @unknown default:
               break
            }
        }
        
        // Switch for buffer and play value
        switch keyPath {
        case PlaybackStatusConstants.playbackBufferEmpty.rawValue:
            break
        case PlaybackStatusConstants.playbackLikelyToKeepUp.rawValue:
            break
            if (player?.currentItem?.isPlaybackLikelyToKeepUp ?? false) {
                break
                delegate?.hideVideoLoader()
            } else {
                break
                delegate?.showVideoLoader()
            }
        case PlaybackStatusConstants.playbackBufferFull.rawValue:
            break
        case .none:
            break
        case .some(_):
            break
        }
    }
    
    private func setupAVPlayerItem(with asset: AVAsset) {
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        playerItem?.addObserver(self, forKeyPath: PlaybackStatusConstants.playbackBufferEmpty.rawValue, options: [.old, .new], context: &playerItemContext)
        playerItem?.addObserver(self, forKeyPath: PlaybackStatusConstants.playbackLikelyToKeepUp.rawValue, options: [.old, .new], context: &playerItemContext)
        playerItem?.addObserver(self, forKeyPath: PlaybackStatusConstants.playbackBufferFull.rawValue, options: [.old, .new], context: &playerItemContext)
        addNotificationObserver()
    }
    
    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying(note:)), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlaybackStalled(note:)), name: .AVPlayerItemPlaybackStalled, object: player?.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidGetAccessLog(note:)), name: .AVPlayerItemNewAccessLogEntry, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(note:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    private func setupPlayerAudioSpeaker() {
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
    }
}

extension ROIVideoPlayer {
    // Finish Player Stream
    @objc private func playerDidFinishPlaying(note: NSNotification){
        delegate?.videoPlaybackFinishedShowOfflineCard()
    }
    
    // Finish Player Stream
    @objc private func playerPlaybackStalled(note: NSNotification){
        delegate?.videoPlaybackFailedShowOfflineCard()
    }
    
    // Stopped Player Stream
    @objc private func playerItemFailedToPlayToEndTime(note: NSNotification){
        delegate?.videoPlaybackFinishedShowOfflineCard()
    }
    
    // Get player asset
    @objc private func playerDidGetAccessLog(note: NSNotification){
        self.delegate?.videoPlayBackAsset(notificationObj: note)
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
