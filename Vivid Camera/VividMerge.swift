//
//  VividMerge.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/19/20.
//

import Foundation
import AVKit

public class VividMerge {
    
    var mainUrl: URL? = nil
    var reversedUrl: URL? = nil
    var mergedUrl: URL? = nil
    
    // Private method to reverse a video clip
    /// - Parameters:
    ///   - videoURL: the video to reverse's URL
    ///   - fileName: the name of the generated video
    ///   - success: completion block on success - returns the reversed video URL
    ///   - failure: completion block on failure - returns the error that caused the failure
    public func reverseVideoClip(videoURL: URL, outcome: @escaping (Result<URL, Error>) -> Void) {
        
        mainUrl = videoURL
        
        // An interger property to store the maximum samples in a pass (100 is the optimal number)
        let numberOfSamplesInPass = 100
        
        if !videoURL.absoluteString.contains(".DS_Store") {
            
            let completeMoviePath: URL = URL.createDateUrl()
            let videoAsset = AVURLAsset(url: videoURL)
            var videoSize = CGSize.zero
            
            if FileManager.default.fileExists(atPath: completeMoviePath.path) {
                do {
                    // Delete an old duplicate file
                    try FileManager.default.removeItem(at: completeMoviePath)
                } catch {
                    DispatchQueue.main.async {
                        outcome(.failure(error))
                    }
                }
            }
            
            DispatchQueue.global(qos: .background).async {
                
                let videoTrack = videoAsset.tracks(withMediaType: .video).first
                
                if let firstAssetTrack = videoTrack {
                    videoSize = firstAssetTrack.naturalSize
                }
                
                // Create setting for the pixel buffer
                let sourceBufferAttributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                var writer: AVAssetWriter!
                
                do {
                    let reader = try AVAssetReader(asset: videoAsset)
                    if let assetVideoTrack = videoAsset.tracks(withMediaType: .video).first {
                        let videoCompositionProps = [AVVideoAverageBitRateKey: assetVideoTrack.estimatedDataRate]
                        
                        // Create the basic video settings
                        let videoSettings: [String : Any] = [
                            AVVideoCodecKey  : AVVideoCodecType.h264,
                            AVVideoWidthKey  : videoSize.width,
                            AVVideoHeightKey : videoSize.height,
                            AVVideoCompressionPropertiesKey: videoCompositionProps
                        ]
                        
                        let readerOutput = AVAssetReaderTrackOutput(track: assetVideoTrack, outputSettings: sourceBufferAttributes)
                        readerOutput.supportsRandomAccess = true
                        reader.add(readerOutput)
                        
                        if reader.startReading() {
                            var timesSamples = [CMTime]()
                            
                            while let sample = readerOutput.copyNextSampleBuffer() {
                                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
                                
                                timesSamples.append(presentationTime)
                            }
                            
                            if timesSamples.count > 1 {
                                let totalPasses = Int(ceil(Double(timesSamples.count) / Double(numberOfSamplesInPass)))
                                
                                var passDictionaries = [[String: Any]]()
                                var passStartTime = timesSamples.first!
                                var passTimeEnd = timesSamples.first!
                                let initEventTime = passStartTime
                                var initNewPass = false
                                
                                for (index, time) in timesSamples.enumerated() {
                                    passTimeEnd = time
                                    
                                    if index % numberOfSamplesInPass == 0 {
                                        if index > 0 {
                                            let dictionary = [
                                                "passStartTime": passStartTime,
                                                "passEndTime": passTimeEnd
                                            ]
                                            
                                            passDictionaries.append(dictionary)
                                        }
                                        
                                        initNewPass = true
                                    }
                                    
                                    if initNewPass {
                                        passStartTime = passTimeEnd
                                        initNewPass = false
                                    }
                                }
                                
                                if passDictionaries.count < totalPasses || timesSamples.count % numberOfSamplesInPass == 0 {
                                    let dictionary = [
                                        "passStartTime": passStartTime,
                                        "passEndTime": passTimeEnd
                                    ]
                                    
                                    passDictionaries.append(dictionary)
                                }
                                
                                writer = try AVAssetWriter(outputURL: completeMoviePath, fileType: .mp4)
                                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                                writerInput.expectsMediaDataInRealTime = false
                                writerInput.transform = videoTrack?.preferredTransform ?? CGAffineTransform.identity
                                
                                let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
                                writer.add(writerInput)
                                
                                if writer.startWriting() {
                                    writer.startSession(atSourceTime: initEventTime)
                                    var frameCount = 0
                                    
                                    for dictionary in passDictionaries.reversed() {
                                        if let passStartTime = dictionary["passStartTime"] as? CMTime, let passEndTime = dictionary["passEndTime"] as? CMTime {
                                            let passDuration = CMTimeSubtract(passEndTime, passStartTime)
                                            let timeRange = CMTimeRangeMake(start: passStartTime, duration: passDuration)
                                            
                                            while readerOutput.copyNextSampleBuffer() != nil { }
                                            
                                            readerOutput.reset(forReadingTimeRanges: [NSValue(timeRange: timeRange)])
                                            
                                            var samples = [CMSampleBuffer]()
                                            
                                            while let sample = readerOutput.copyNextSampleBuffer() {
                                                samples.append(sample)
                                            }
                                            
                                            for (index, _) in samples.enumerated() {
                                                let presentationTime = timesSamples[frameCount]
                                                let imageBufferRef = CMSampleBufferGetImageBuffer(samples[samples.count - index - 1])!
                                                
                                                while (!writerInput.isReadyForMoreMediaData) {
                                                    Thread.sleep(forTimeInterval: 0.05)
                                                }
                                                
                                                pixelBufferAdaptor.append(imageBufferRef, withPresentationTime: presentationTime)
                                                
                                                frameCount += 1
                                            }
                                            
                                            samples.removeAll()
                                        }
                                    }
                                    writerInput.markAsFinished()
                                    
                                    
                                    writer.finishWriting(completionHandler: {
                                        
                                        self.reversedUrl = completeMoviePath
                                       
                                        self.mergeMovies(videoURLs: [videoURL, completeMoviePath]) { (result) in
                                            switch result {
                                            case .success(let completedUrl):
                                                self.mergedUrl = completedUrl
                                                DispatchQueue.main.async {
                                                    outcome(.success(completedUrl))
                                                }
                                            case .failure(let error):
                                                DispatchQueue.main.async {
                                                    outcome(.failure(error))
                                                }
                                            }
                                        }
                                    })
                                }
                            } else {
                                DispatchQueue.main.async {
                                    outcome(.failure(NSError(domain: "com.NolanFuchs.Vivid", code: -1, userInfo: [NSLocalizedDescriptionKey: "Time samples are less than 1"])))
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                outcome(.failure(NSError(domain: "com.NolanFuchs.Vivid", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reader unable to start"])))
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        outcome(.failure(error))
                    }
                }
                
            }
        } else {
            DispatchQueue.main.async {
                outcome(.failure(NSError(domain: "com.NolanFuchs.Vivid", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL path contains DS_Store or does not contain the correct extension"])))
            }
        }
    }
    
    // Method to merge multiple videos
    /// - Parameters:
    ///   - videoURLs: the videos to merge URLs
    ///   - fileName: the name of the finished merged video file
    ///   - success: success block - returns the finished video url path
    ///   - failure: failure block - returns the error that caused the failure
    public func mergeMovies(videoURLs: [URL], outcome: @escaping (Result<URL, Error>) -> Void) {
        
        let _videoURLs = videoURLs.filter({ !$0.absoluteString.contains(".DS_Store") })
        
        // Guard against missing URLs
        guard !_videoURLs.isEmpty else {
            DispatchQueue.main.async {
                outcome(.failure(NSError(domain: "com.NolanFuchs.Vivid", code: -1, userInfo: [NSLocalizedDescriptionKey: "videoURLs did not contain valid urls"])))
            }
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            
            var videoAssets: [AVURLAsset] = []
            let completeMoviePath = URL.createDateUrl()
            
            for path in _videoURLs {
                if let _url = URL(string: path.absoluteString) {
                    videoAssets.append(AVURLAsset(url: _url))
                }
            }
            
            // IF a URL exists within the file manager, remove it before proceeding
            if FileManager.default.fileExists(atPath: completeMoviePath.path) {
                do {
                    // Delete an old duplicate file
                    try FileManager.default.removeItem(at: completeMoviePath)
                } catch {
                    DispatchQueue.main.async {
                        outcome(.failure(error))
                    }
                }
            }
            
            let composition = AVMutableComposition()
            
            var maxRenderSize = CGSize.zero
            var currentTime = CMTime.zero
            var renderSize = CGSize.zero
            // Create empty Layer Instructions, that we will be passing to Video Composition and finally to Exporter.
            var instructions = [AVMutableVideoCompositionInstruction]()
            
            // Add audio and video tracks to the composition
            if let videoTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                
                var insertTime = CMTime(seconds: 0, preferredTimescale: 1)
                
                // For each URL add the video and audio tracks and their duration to the composition
                for sourceAsset in videoAssets {
                    
                    do {
                        if let assetVideoTrack = sourceAsset.tracks(withMediaType: .video).first {
                            
                            // Setting the size of the asset track
                            maxRenderSize = assetVideoTrack.naturalSize
                            
                            // Create instruction for a video and append it to array.
                            let instruction = AVMutableComposition.instruction(assetVideoTrack, asset: sourceAsset, time: currentTime, duration: assetVideoTrack.timeRange.duration, maxRenderSize: maxRenderSize)
                            instructions.append(instruction.videoCompositionInstruction)
                            
                            let frameRange = CMTimeRange(start: CMTime(seconds: 0, preferredTimescale: 1), duration: sourceAsset.duration)
                            try videoTrack.insertTimeRange(frameRange, of: assetVideoTrack, at: insertTime)
                            
                            currentTime = CMTimeAdd(currentTime, assetVideoTrack.timeRange.duration)
                            if sourceAsset != videoAssets.last {
                                renderSize = instruction.isPortrait ? CGSize(width: maxRenderSize.height, height: maxRenderSize.width) : CGSize(width: maxRenderSize.width, height: maxRenderSize.height)
                            }
                            
                            videoTrack.preferredTransform = assetVideoTrack.preferredTransform
                        }
                        
                        insertTime = insertTime + sourceAsset.duration
                    } catch {
                        DispatchQueue.main.async {
                            outcome(.failure(error))
                        }
                    }
                }
                
                // Create Video Composition and pass Layer Instructions to it.
                let videoComposition = AVMutableVideoComposition()
                videoComposition.instructions = instructions
                // Do not forget to set frame duration and render size. It will crash if you dont.
                videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 240)
                videoComposition.renderSize = renderSize
    
                // Try to start an export session and set the path and file type
                if let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) {
                    exportSession.outputFileType = .mp4
                    exportSession.shouldOptimizeForNetworkUse = true
                    exportSession.outputURL = completeMoviePath
                    exportSession.videoComposition = videoComposition
                    
                    // Try to export the file and handle the status cases
                    exportSession.exportAsynchronously(completionHandler: {
                        switch exportSession.status {
                        case .failed:
                            if let _error = exportSession.error {
                                DispatchQueue.main.async {
                                    outcome(.failure(_error))
                                }
                            }
                            
                        case .cancelled:
                            if let _error = exportSession.error {
                                DispatchQueue.main.async {
                                    outcome(.failure(_error))
                                }
                            }
                            
                        default:
                            DispatchQueue.main.async {
                                outcome(.success(completeMoviePath))
                            }
                        }
                    })
                } else {
                    DispatchQueue.main.async {
                        outcome(.failure(NSError(domain: "com.NolanFuchs.Vivid", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to initialize an AVAssetExportSession"])))
                    }
                }
            }
        }
    }
    
    
    public func clearUrls() {
        if let mainUrl = mainUrl {
            if FileManager.default.fileExists(atPath: mainUrl.path) {
                do {
                    try FileManager.default.removeItem(at: mainUrl)
                } catch {
                    print("Vivid Merge - Unable to clear main URL")
                }
            }
        }
        if let reversedUrl = reversedUrl {
            if FileManager.default.fileExists(atPath: reversedUrl.path) {
                do {
                    try FileManager.default.removeItem(at: reversedUrl)
                } catch {
                    print("Vivid Merge - Unable to clear reversed URL")
                }
            }
        }
        if let mergedUrl = mergedUrl {
            if FileManager.default.fileExists(atPath: mergedUrl.path) {
                do {
                    try FileManager.default.removeItem(at: mergedUrl)
                } catch {
                    print("Vivid Merge - Unable to clear meerged URL")
                }
            }
        }
        mainUrl = nil
        reversedUrl = nil
        mergedUrl = nil
    }
    
    
}
