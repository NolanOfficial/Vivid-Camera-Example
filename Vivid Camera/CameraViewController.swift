//
//  CameraViewController.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/14/20.
//

import UIKit
import AVKit

class CameraViewController: VividCameraController, UIGestureRecognizerDelegate, AVCaptureFileOutputRecordingDelegate {
    
    /// Variables Test
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var fpsButton: UIButton!
    @IBOutlet weak var zoomSlider: UISegmentedControl!
    
    @IBOutlet weak var cameraButton: CameraButton!
    
    /// Gesture Recognizers
    @IBOutlet var longPressOutlet: UILongPressGestureRecognizer!
    public var singleTapGesture = UITapGestureRecognizer()
    public var doubleTapGesture = UITapGestureRecognizer()
    
    public var sampleURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        zoomSlider.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .selected)
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            cameraButton.isUserInteractionEnabled = false
        }
        fpsButton.layer.cornerRadius = 10
        fpsButton.clipsToBounds = true
        fpsButton.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        initializeGestures()
    }
    
    // Initializing all UI Gestures
    private func initializeGestures() {
        // Initilaizing Single Tap (Focus)
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.addTarget(self, action: #selector(focus(tap:)))
        view.addGestureRecognizer(singleTapGesture)
        
        // Initializing Double Tap (Camera Switch)
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.addTarget(self, action: #selector(cameraSwitch))
        view.addGestureRecognizer(doubleTapGesture)
        
        // Initializing custom overrides
        singleTapGesture.require(toFail: doubleTapGesture)
    }
    
    @objc
    private func focus(tap: UITapGestureRecognizer) {
        print("Cameera Manageer - Focus tapped")
        focus(with: tap)
    }
    @objc
    private func cameraSwitch() {
        switchCamera()
        if let currentDevice = currentDevice {
            if currentDevice.position == .back {
                if !flashButton.isHidden {
                    zoomSlider.isHidden = false
                }
                fpsButton.setTitle("HD 240", for: .normal)
            } else {
                flashButton.setImage(UIImage(named: "Flash Off"), for: .normal)
                fpsButton.setTitle("HD 120", for: .normal)
                zoomSlider.isHidden = true
            }
        }
        print("Cameera Manageer - Camera switch tapped")
    }

    @IBAction func recordAction(_ sender: Any) {
        longPressOutlet.state = .failed
        singleTapGesture.isEnabled = false
        doubleTapGesture.isEnabled = false
        record(delegate: self, customURL: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.flashButton.setImage(UIImage(named: "Flash Off"), for: .normal)
        }
    }
    
    @IBAction func changeFPS(_ sender: Any) {

    }
    
    @IBAction func torchAction(_ sender: Any) {
        
        switch currentDevice?.isTorchActive {
        case false:
            flashButton.setImage(UIImage(named: "Flash On"), for: .normal)
        default:
            flashButton.setImage(UIImage(named: "Flash Off"), for: .normal)
        }
        toggleFlash()
    }
 
    @IBAction func zoomAction(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            zoom(to: .UltraWide)
        case 1:
            zoom(to: .Wide)
        case 2:
            zoom(to: .Telephoto)
        default:
            print("Camera Example - Zoom seegmnet control error")
        }
    }
    
    @IBAction func holdGesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            singleTapGesture.isEnabled = false
            fadeButtons(buttons: [flashButton, fpsButton], animationSpeed: 0.16)
            if let device = currentDevice {
                if device.position == .back {
                    fadeSiders(sliders: [zoomSlider], animationSpeed: 0.16)
                } else {
                    zoomSlider.alpha = 1
                }
            }
            sender.state = .ended
            singleTapGesture.isEnabled = true
        }
    }
    
    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .began {
            if let currentDevice = currentDevice, currentDevice.position == .back {
                if sender.scale < 1.0 {
                    switch currentZoomType {
                    case .UltraWide:
                        sender.state = .failed
                    case .Wide:
                        zoom(to: .UltraWide)
                        zoomSlider.selectedSegmentIndex = 0
                    case .Telephoto:
                        zoom(to: .Wide)
                        zoomSlider.selectedSegmentIndex = 1
                    }
                } else {
                    switch currentZoomType {
                    case .UltraWide:
                        zoom(to: .Wide)
                        zoomSlider.selectedSegmentIndex = 1
                    case .Wide:
                        zoom(to: .Telephoto)
                        zoomSlider.selectedSegmentIndex = 2
                    case .Telephoto:
                        sender.state = .failed
                    }
                }
            } else {
                sender.state = .failed
            }
        }
    }
    
    
    // Recognizing all gestures simultaneously
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    // Overiding root view touches for faster single and double tap detections
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.245) {
            if self.doubleTapGesture.state != .ended {
                self.doubleTapGesture.state = .failed
            }
        }
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("Camera Manager - Finished recording to videoURL: \(outputFileURL)")
        singleTapGesture.isEnabled = true
        doubleTapGesture.isEnabled = true
        sampleURL = outputFileURL
        self.performSegue(withIdentifier: "goToPreview", sender: nil)
    }
    
    
    // Preparing the url for segue into the preview view
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is PreviewViewController, let vc = segue.destination as? PreviewViewController {
            vc.newSampleURL = sampleURL
            
        }
    }
    
    
    
}

