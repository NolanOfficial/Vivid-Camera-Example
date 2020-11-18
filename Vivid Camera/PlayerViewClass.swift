//
//  PlayerViewClass.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/18/20.
//

import UIKit
import AVKit

// Class that enables the creation of AVPlayer within an AVKit Layer
public class PlayerViewClass: UIView {
    
    public override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
}
