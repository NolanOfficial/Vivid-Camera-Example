//
//  Extensions.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/15/20.
//

import Foundation
import AVKit

extension URL {
    /**
     Create a temporary URL path with a date format integrated
     
     - returns: The URL that was created
     
     # Notes: #
     1. The date format will be yyyyMMddHHmmssSSS
     */
    internal static func createDateUrl() -> URL {
        if let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmmssSSS"
            let filePath: String = "\(documentDirectory)/viv-\(formatter.string(from: Date())).mp4"
            return URL(fileURLWithPath: filePath)
        }
        return URL(fileURLWithPath: "EmptyFilePath")
    }
}

extension AVMutableComposition {
    
    static func instruction(_ assetTrack: AVAssetTrack, asset: AVAsset, time: CMTime, duration: CMTime, maxRenderSize: CGSize)
    -> (videoCompositionInstruction: AVMutableVideoCompositionInstruction, isPortrait: Bool) {
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
        
        // Find out orientation from preffered transform.
        let assetInfo = orientationFromTransform(assetTrack.preferredTransform)
        
        // Calculate scale ratio according orientation.
        var scaleRatio = maxRenderSize.width / assetTrack.naturalSize.width
        if assetInfo.isPortrait {
            scaleRatio = maxRenderSize.height / assetTrack.naturalSize.height
        }
        
        // Set correct transform.
        var transform = CGAffineTransform(scaleX: scaleRatio, y: scaleRatio)
        transform = assetTrack.preferredTransform.concatenating(transform)
        layerInstruction.setTransform(transform, at: .zero)
        
        // Create Composition Instruction and pass Layer Instruction to it.
        let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
        videoCompositionInstruction.timeRange = CMTimeRangeMake(start: time, duration: duration)
        videoCompositionInstruction.layerInstructions = [layerInstruction]
        
        return (videoCompositionInstruction, assetInfo.isPortrait)
    }
    
    static func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        
        switch [transform.a, transform.b, transform.c, transform.d] {
        case [0.0, 1.0, -1.0, 0.0]:
            assetOrientation = .right
            isPortrait = true
            
        case [0.0, -1.0, 1.0, 0.0]:
            assetOrientation = .left
            isPortrait = true
            
        case [1.0, 0.0, 0.0, 1.0]:
            assetOrientation = .up
            
        case [-1.0, 0.0, 0.0, -1.0]:
            assetOrientation = .down
            
        default:
            break
        }
        
        return (assetOrientation, isPortrait)
    }
    
}
