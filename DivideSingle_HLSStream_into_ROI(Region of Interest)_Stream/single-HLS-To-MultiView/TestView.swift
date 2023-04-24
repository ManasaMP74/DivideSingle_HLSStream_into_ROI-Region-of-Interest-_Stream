//
//  TestView.swift
//  Roposo
//
//  Created by Manasa M P on 28/03/23.
//  Copyright © 2023 Roposo. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import CoreImage

class TestView: UIView {
    var shapeView = UIView()
    let changeShape = UIButton()
    let label = UILabel()
    var player: AVPlayer!
    let roiVideoPlayer = ROIVideoPlayer()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    public init() {
        super.init(frame: .zero)
        backgroundColor = UIColor.green
        backgroundColor = .lightGray
        setupView()
    }
    
    @objc func changeShapeOfView() {
        let index = (Int.random(in: 0...4))%4
        var path = UIBezierPath(roundedRect: shapeView.bounds, cornerRadius: 10)
        switch index {
        case 0: path = createPentagonPath(bounds: shapeView.bounds)
        case 1: path = circlePath(bounds: shapeView.bounds)
        case 2: path = UIBezierPath(roundedRect: shapeView.bounds, cornerRadius: 10)
        case 3: path = UIBezierPath(ovalIn: shapeView.bounds)
        default: break
        }
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        shapeView.layer.mask = maskLayer
    }
    
    func setupView() {
        changeShape.backgroundColor = UIColor.black
        changeShape.setTitle("Change Shape", for: .normal)
        label.text = "Original Video"
        label.translatesAutoresizingMaskIntoConstraints = false
        changeShape.translatesAutoresizingMaskIntoConstraints = false
        changeShape.addTarget(self, action: #selector(changeShapeOfView), for: .touchUpInside)
        addSubview(label)
        addSubview(changeShape)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor,constant: 50),
            label.heightAnchor.constraint(equalToConstant: 40),
            label.widthAnchor.constraint(equalToConstant: 150),
            changeShape.widthAnchor.constraint(equalToConstant: 150),
            changeShape.heightAnchor.constraint(equalToConstant: 40),
            changeShape.topAnchor.constraint(equalTo: label.topAnchor),
            changeShape.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        configureViewROIFile()
    }
    
    func configureViewROIFile() {
        guard
            let path = Bundle.main.path(forResource: "DummyTesting", ofType: "mp4") else { return }
        let videoURL = URL(string: path)!
        
        //playing split views
        let width = 150
        let height = 150
        
        //playing original video
        configureView()
        
        roiVideoPlayer.delegate = self
        roiVideoPlayer.configureView(hlsURL: videoURL) { [weak self] in
            DispatchQueue.main.async {
                self?.createAVPlayerView(for: CGRect(x: 0, y: height+110, width: width*2, height: height), position: .topLeft)
                self?.createAVPlayerView(for: CGRect(x: width+3, y: height+110, width: width, height: height), position: .topRight)
                self?.createAVPlayerView(for: CGRect(x: 0, y: (height*2)+113, width: width, height: height), position: .bottomLeft)
                self?.createAVPlayerView(for: CGRect(x: width+3, y: (height*2)+113, width: width, height: height), position: .bottomRight)
                
            }
        }
    }
    
    func createAVPlayerView(for rect: CGRect, position: HLSStreamDivision.Position? = nil) {
        let template = ConsumptionHLSStreamTemplate.template2
        let size = CGSize(width: rect.size.width, height: rect.size.height)
        let t = template.getCGAffineTransform(for: position, size: size)
        let player = roiVideoPlayer.getROIPlayerLayer(with: size, translation: t)
        let view = UIView(frame: rect)
        view.layer.addSublayer(player)
        // Clip content outside the layer's bounds
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        self.addSubview(view)
    }
    
    func configureView() {
        guard
        let path = Bundle.main.path(forResource: "DummyTesting", ofType: "mp4") else { return }
        let videoURL = URL(fileURLWithPath: path)
        
         // Create an instance of AVAsset
         let asset = AVAsset(url: videoURL)
         
         // Create an instance of AVPlayer
         player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
         
        //playing split views
        let width = 150
        let height = 150

        //playing original video
        createViewAndAVPlayer(with: CGRect(x: 0, y: 100, width: width, height: height), player: player)
        
        
        //Playing video with shape
        shapeView = createViewAndAVPlayer(with: CGRect(x: width+10, y: 100, width: width, height: height), player: player)
        
        /*
         rightBottom = -1, -1
         
         leftBottom = 1, -1
         
         rightTop = -1, 1
         
         leftTop = 1, 1
         */

        //left top split view
        createViewAndAVPlayer(with: CGRect(x: 0, y: height+110, width: width, height: height), player: player, translationPoint: CGPoint(x: 1, y: 1))

        //right top split view
        createViewAndAVPlayer(with: CGRect(x: width+3, y: height+110, width: width, height: height), player: player, translationPoint: CGPoint(x: -1, y: 1))

        //left bottom split view
        createViewAndAVPlayer(with: CGRect(x: 0, y: (height*2)+113, width: width, height: height), player: player, translationPoint: CGPoint(x: 1, y: -1))


        //right bottom split view
        createViewAndAVPlayer(with: CGRect(x: width+3, y: (height*2)+113, width: width, height: height), player: player, translationPoint: CGPoint(x: -1, y: -1))
        
        // Start playing the video
        player.play()
    }
    
    @discardableResult func createViewAndAVPlayer(with frame: CGRect, player: AVPlayer, translationPoint: CGPoint? = nil, shapePath: UIBezierPath? = nil) -> UIView {
        let view1 = UIView(frame: frame)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view1.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.contentsGravity = .resizeAspectFill
        
        if let point = translationPoint {
            let scaleTransform = CGAffineTransform(scaleX: 2, y: 2).concatenating(CGAffineTransform(translationX: point.x*(view1.bounds.width/2), y: point.y*(view1.bounds.height/2)))
            playerLayer.setAffineTransform(scaleTransform)
        }
        
        if let path = shapePath {
            let maskLayer = CAShapeLayer()
            //let path = UIBezierPath(roundedRect: playerLayer.bounds, cornerRadius: 10)
            maskLayer.path = path.cgPath
            view1.layer.mask = maskLayer
        }
        
        view1.layer.addSublayer(playerLayer)
        view1.clipsToBounds = true
        view1.layer.masksToBounds = true // Clip content outside the layer's bounds
        addSubview(view1)
        
        return view1
    }
    
    func circlePath(bounds: CGRect) -> UIBezierPath {
        let size = bounds.size
        let startAngle = CGFloat(-Double.pi / 2)
        // top of circle
        let endAngle = startAngle + 2 * Double.pi * 1
        let radius = min(size.height, size.width) / 2
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: size.width/2, y: size.height/2), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        return circlePath
    }
    
    func createPentagonPath(bounds: CGRect) -> UIBezierPath {
        let size = bounds.size
        let h = size.height * 0.85      // adjust the multiplier to taste

        // calculate the 5 points of the pentagon

        let p1 = bounds.origin
        let p2 = CGPoint(x:p1.x + size.width, y:p1.y)
        let p3 = CGPoint(x:p2.x, y:p2.y + h)
        let p4 = CGPoint(x:size.width/2, y:size.height)
        let p5 = CGPoint(x:p1.x, y:h)

        // create the path
        let path = UIBezierPath()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.addLine(to: p4)

        path.addLine(to: p5)
        path.close()
        return path
    }
}

extension TestView: VideoPlayerStatusDelegate {
    func showVideoLoader() {
        roiVideoPlayer.play()
    }
    
    func hideVideoLoader() {}
    func videoPlaybackFailedShowOfflineCard() {}
    func videoPlayStarted() {
        roiVideoPlayer.play()
    }
    func videoPlaybackFinishedShowOfflineCard() {}
    func videoPlayBackAsset(notificationObj: NSNotification) {}
}
