//
//  CameraManager.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/14/20.
//

import UIKit
import AVKit

public enum ZoomType {
    case Telephoto
    case Wide
    case UltraWide
}

open class VividCameraController: UIViewController {
    
    // MARK: Variables
    /// Capture Session
    public var captureSession = AVCaptureSession()
    
    /// Devices
    public var frontFacingDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    public var backFacingDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    public var currentDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    
    /// Preview Layer
    public var previewLayer = AVCaptureVideoPreviewLayer()

    /// Output
    public var videoOutput = AVCaptureMovieFileOutput()

    /// Authentication Manager
    private var authenticationManager = AuthenticationManager()
    
    public var currentZoomType: ZoomType = .Wide
    
    // MARK: View Loading Methods
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // Authenticating permissions for camera usage
        authenticationManager.requestAuthorization(viewController: self)
    
        // If permissions were granted, configure the camera
        if authenticationManager.sessionResult == .success {
            configureCamera()
//            testing()
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        switch self.authenticationManager.sessionResult {
        case .success:
            self.captureSession.startRunning()
            
        case .notAuthorized:
            DispatchQueue.main.async {
                let changePrivacySetting = "VIVID Camera doesn't have permission to use the camera, please change privacy settings"
                let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                let alertController = UIAlertController(title: "VIVID Camera", message: message, preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                        style: .cancel,
                                                        handler: nil))
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                        style: .`default`,
                                                        handler: { _ in
                                                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                      options: [:],
                                                                                      completionHandler: nil)
                                                        }))
                
                self.present(alertController, animated: true, completion: nil)
            }
        case .configurationFailed:
            DispatchQueue.main.async {
                let alertMsg = "Something went wrong. Please try again later."
                let message = NSLocalizedString("VIVID Camera setup failed. Please try again later.", comment: alertMsg)
                let alertController = UIAlertController(title: "VIVID Camera", message: message, preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                        style: .cancel,
                                                        handler: nil))
                
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        if self.authenticationManager.sessionResult == .success {
            self.captureSession.stopRunning()
        }
        super.viewWillDisappear(animated)
    }
    
    public func testing() {
        let backDevices =  AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    
        for device in backDevices.devices {
            for format in device.formats {
                let ranges: [AVFrameRateRange] = format.videoSupportedFrameRateRanges
                let frameRates = ranges[0]
                if frameRates.maxFrameRate == 240 || frameRates.maxFrameRate == 120 {
                    print(device.localizedName, frameRates.maxFrameRate)
                    break
                }
            }
        }
    }
        
    // MARK: Camera Functions
    /**
     Configure the view controller with the current device.
     
     # Notes: #
     1. This function will configure both the back facing and front facing camera.
     2. The back facing camera will be configured at 240 FPS (frames per second).
     3. Inputs and outputs will be configured alongside its corresponding preview layer.
     4. The preview layer will be added at sublayer 0 and take the whole screen.
     5. Once everything is configured, the session will begin running.
     */
    private func configureCamera() {
        
        captureSession.beginConfiguration()
        
        // Setting the current device
        currentDevice = backFacingDevice
        
        guard let currentDevice = currentDevice, let backFacingDevice = backFacingDevice, let frontFacingDevice = frontFacingDevice else {
            authenticationManager.sessionResult = .configurationFailed
            print("Camera Manager - Unable to initialize the current device.")
            return
        }
        
        // Setting and adding the input
        let deviceInput = try? AVCaptureDeviceInput.init(device: currentDevice)
        if let device = deviceInput {
            captureSession.addInput(device)
        } else {
            authenticationManager.sessionResult = .configurationFailed
            print("Camera Manager - Error adding device input.")
        }
    
        // Changing the frame rate of the current device
        switchFormat(device: backFacingDevice, fps: 240)
        switchFormat(device: frontFacingDevice, fps: 120)
        
        // Adding video output
        captureSession.addOutput(videoOutput)
        
        // Creating a connection for video output
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        
        // Setting up Preview Layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.frame
        view.layer.insertSublayer(previewLayer, at: 0)
        
        // Commit the configuration
        captureSession.commitConfiguration()
    }
    
    public func switchFormat(device: AVCaptureDevice?, fps: Float64) {
        guard let device = device else { return }
        for format in device.formats {
            let ranges: [AVFrameRateRange] = format.videoSupportedFrameRateRanges
            let frameRates = ranges[0]
            if frameRates.maxFrameRate == fps {
                do {
                    try device.lockForConfiguration()
                    device.activeFormat = format
                    device.activeVideoMinFrameDuration = frameRates.minFrameDuration
                    device.activeVideoMaxFrameDuration = frameRates.minFrameDuration
                    device.unlockForConfiguration()
                    break
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    /**
     Start and stop the recording of the video at 1 second intervals.
     
     - parameter delegate: AVCaptureFileOutputRecordingDelegate associated with the view controller.
     - parameter customURL: An optional URL to write to. If none is provided, it will use the default Vivid URL Path.
     
     # Notes: #
     1. This function will start the recording to a URL.
     2. After 1 second, it will stop the recording within the main thread.
     3. If the flash/torch is on, it will automatically turn it off upon the stopped recording.
     */
    public func record(delegate: AVCaptureFileOutputRecordingDelegate, customURL: URL?) {
        guard let _ = currentDevice else {
            print("Camera Manager - Unable to record video. No video device found.")
            return
        }
        if let customURL = customURL {
            videoOutput.startRecording(to: customURL, recordingDelegate: delegate)
        } else {
            videoOutput.startRecording(to: URL.createDateUrl(), recordingDelegate: delegate)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.videoOutput.stopRecording()
            if let currentDevice = self.currentDevice, currentDevice.isTorchActive {
                self.toggleFlash()
            }
        }
    }
    
    /**
     Confugring flash in AVFoundation to allow for torch mode to be activated/disabled.
     
     # Notes: #
     1. The torch mode will be set to 1.0 when turned on.
     */
    public func toggleFlash() {

        guard let currentDevice = self.currentDevice else {
            print("Camera Manager - Unable to toggle flash. No video device found.")
            return
        }
        guard currentDevice.hasTorch else { return }
        do {
            try currentDevice.lockForConfiguration()
            
            if (currentDevice.torchMode == AVCaptureDevice.TorchMode.on) {
                currentDevice.torchMode = AVCaptureDevice.TorchMode.off
                
            } else {
                do {
                    try currentDevice.setTorchModeOn(level: 1.0)
                } catch {
                    print(error.localizedDescription)
                }
            }
            currentDevice.unlockForConfiguration()
        } catch {
            print("Camera Manager - ", error.localizedDescription)
        }
    }
    
    /**
     Switch between the front facing and back facing camera.
     */
    public func switchCamera() {
        print("Cameera Manageer - Cameera switch initiated")
        guard let _ = currentDevice else {
            print("Camera Manager - Unable to switch cameras. No video device found.")
            return
        }

        captureSession.stopRunning()
        captureSession.beginConfiguration()
        captureSession.removeOutput(videoOutput)
        guard let newDevice = (currentDevice?.position == .back) ? frontFacingDevice : backFacingDevice else {
            print("Camera Manager - Unable to switch cameras. No new camera device found.")
            return
        }
        
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        
        guard let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            print("Camera Manager - Unable to switch cameras. Unable to add device to new input.")
            return
        }
        captureSession.addInput(newInput)
        captureSession.addOutput(videoOutput)
        videoOutput.connection(with: AVMediaType.video)!.videoOrientation = .portrait
        currentDevice = newDevice
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    /**
     Creates a focus point and overlays a temporary view
     
     - parameter tap: A UITapGestureRecognizer in which the area point is identified
     */
    public func focus(with tap: UITapGestureRecognizer) {
        print("Cameera Manageer - Focus method initiated")
        // Grabbing coordinates for view
        let screenSize = view.bounds.size
        let tapPoint = tap.location(in: nil)
        let x = tapPoint.y / screenSize.height
        let y = 1.0 - tapPoint.x / screenSize.width
        let focusPoint = CGPoint(x: x, y: y)
        
        // Initializing View
        let focusView = UIView(frame: CGRect(x: tapPoint.x - 30, y: tapPoint.y - 30, width: 60, height: 60))
        
        // Checks to see if focus is supported on each camera
        if let device = currentDevice {
            if device.isFocusPointOfInterestSupported {
                do {
                    // Instantiaing Focus Point
                    try device.lockForConfiguration()
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                    device.unlockForConfiguration()
                    
                    // Focus Animation
                    DispatchQueue.main.async {
                        focusView.layer.borderWidth = 3.0
                        focusView.layer.borderColor = UIColor.white.cgColor
                        focusView.layer.cornerRadius = 10
                        focusView.layer.masksToBounds = true
                        focusView.alpha = 1.0
                        self.view.addSubview(focusView)
                    }
                    
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 1.0, animations: {
                            focusView.alpha = 0.0
                        }) { (success) in
                            focusView.removeFromSuperview()
                        }
                    }
                }
                catch {
                    print("Camera Manager - Error toggling back focus.")
                }
            } else if device.isExposurePointOfInterestSupported {
                do {
                    // Instantiaing Focus Point
                    try device.lockForConfiguration()
                    device.exposurePointOfInterest = focusPoint
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .continuousAutoExposure
                    device.unlockForConfiguration()
                    
                    // Focus Animation
                    DispatchQueue.main.async {
                        focusView.layer.borderWidth = 3.0
                        focusView.layer.borderColor = UIColor.white.cgColor
                        focusView.layer.cornerRadius = 10
                        focusView.layer.masksToBounds = true
                        focusView.alpha = 1.0
                        self.view.addSubview(focusView)
                    }
                    
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 1.0, animations: {
                            focusView.alpha = 0.0
                        }) { (success) in
                            focusView.removeFromSuperview()
                        }
                    }
                }
                catch {
                    print("Camera Manager - Error toggling front focus.")
                }
            } else {
                print("Camera Manager - Focus not supported on front camera.")
            }
        } else {
            print("Camera Manager - Unable to focus. No current device found.")
        }
    }
    
    public func zoom(to type: ZoomType) {
        captureSession.stopRunning()
        captureSession.beginConfiguration()
        captureSession.removeOutput(videoOutput)
        
        var expectedNewDevice: AVCaptureDevice?
        switch type {
        case .Telephoto:
            expectedNewDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            switchFormat(device: expectedNewDevice, fps: 240)
            currentZoomType = .Telephoto
        case .Wide:
            expectedNewDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            switchFormat(device: expectedNewDevice, fps: 240)
            currentZoomType = .Wide
        case .UltraWide:
            expectedNewDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            switchFormat(device: expectedNewDevice, fps: 240)
            currentZoomType = .UltraWide
        }
        guard let newDevice = expectedNewDevice else {
            print("Camera Manager - Unable to set new camera")
            return
        }
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        
        guard let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            print("Camera Manager - Unable to switch cameras. Unable to add device to new input.")
            return
        }
        captureSession.addInput(newInput)
        captureSession.addOutput(videoOutput)
        videoOutput.connection(with: AVMediaType.video)!.videoOrientation = .portrait
        backFacingDevice = newDevice
        currentDevice = newDevice
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    // MARK: View Controller Functions
    
    /**
     Animate the buttons with a fading effect to and from a hidden state.
     
     - parameter buttons: An array of buttons which should be animated.
     - parameter animation: The speeed at which the fade animation will complete.
     
     # Notes: #
     1. Ensure that this function is called within the main thread
     */
    public func fadeButtons(buttons: [UIButton], animationSpeed: TimeInterval) {
        buttons.forEach { (button) in
            if button.isHidden {
                button.alpha = 0
                button.isHidden.toggle()
                UIView.animate(withDuration: animationSpeed) {
                    button.alpha = 1.0
                }
            } else {
                button.alpha = 1.0
                UIView.animate(withDuration: animationSpeed) {
                    button.alpha = 0
                } completion: { _ in
                    button.isHidden.toggle()
                }
            }
        }
    }
    
    /**
     Animate the buttons with a fading effect to and from a hidden state.
     
     - parameter sliders: An array of UISegmentedControl which should be animated.
     - parameter animation: The speeed at which the fade animation will complete.
     
     # Notes: #
     1. Ensure that this function is called within the main thread
     */
    public func fadeSiders(sliders: [UISegmentedControl], animationSpeed: TimeInterval) {
        sliders.forEach { (slider) in
            if slider.isHidden {
                slider.alpha = 0
                slider.isHidden.toggle()
                UIView.animate(withDuration: animationSpeed) {
                    slider.alpha = 1.0
                }
            } else {
                slider.alpha = 1.0
                UIView.animate(withDuration: animationSpeed) {
                    slider.alpha = 0
                } completion: { _ in
                    slider.isHidden.toggle()
                }
            }
        }
    }
}


