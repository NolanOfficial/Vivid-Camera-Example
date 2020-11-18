//
//  PreviewViewController.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/18/20.
//

import UIKit
import AVKit
import PhotosUI

class PreviewViewController: UIViewController {
    
    public var newSampleURL: URL?
    public var playerView: PlayerViewClass? = PlayerViewClass()
    var notificationObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerView?.frame = view.frame
        if let playerView = playerView {
            view.insertSubview(playerView, at: 0)
        } else {
            print("Preview Layer Error")
        }

        playVideo(url: newSampleURL!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self.notificationObserver as Any)
        if FileManager.default.fileExists(atPath: newSampleURL!.path) {
            do {
                // Delete an old duplicate file
                try FileManager.default.removeItem(at: newSampleURL!)
                print("URL removed")
            } catch {
                print("Unable to remove URL")
            }
        } else {
            print("URL has already been removed")
        }
        playerView = nil
    }
    
    private func playVideo(url: URL) {
        let player = AVPlayer(url: url)
        playerView?.player = player
        playerView?.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        player.rate = 0.25
        
        // Loops the video once it finishes playing
        self.notificationObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
            player.rate = 0.25
        }
    }
    
    @IBAction func saveVideo(_ sender: Any) {
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let creationRequest = PHAssetCreationRequest.forAsset()
                guard let newURL = self.newSampleURL else { return }
                creationRequest.addResource(with: .video, fileURL: newURL, options: options)
            }, completionHandler: { (success, err) in
                if err != nil {
                    print(err!.localizedDescription)
                } else {
                    print("Succesfully Saved to Photos Library")
                    do {
                        try FileManager.default.removeItem(at: self.newSampleURL!)
                    } catch {
                        print("Unable to remove URL")
                    }
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            })
        }
    }
    
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
