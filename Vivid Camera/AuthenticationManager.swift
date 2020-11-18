//
//  AuthenticationManager.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/14/20.
//

import UIKit
import AVKit

internal enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}

internal class AuthenticationManager {
    
    /// Authentication session queue
    private var authorizationQueue = DispatchQueue(label: "Authorization Queue")
    
    /// Authorization result
    internal var sessionResult: SessionSetupResult = .notAuthorized
    
    // Requesting authorization
    internal func requestAuthorization(viewController: UIViewController) {
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            sessionResult = .success
            print("Camera Authorization - Authorized")
        case .notDetermined: // The user has not yet been asked for camera access.
            print("Camera Authorization - Not Determined")
            authorizationQueue.suspend() // Suspending entire session until authorized.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionResult = .success
                    print("Camera Authorization - Granted")
                } else {
                    self.sessionResult = .notAuthorized
                    print("Camera Authorization - Rejected")
                }
                self.authorizationQueue.resume()
            }
            
        case .denied: // The user has previously denied access.
            sessionResult = .notAuthorized
            print("Camera Authorization - Denied")
            
        case .restricted: // The user can't grant access due to restrictions.
            sessionResult = .notAuthorized
            print("Camera Authorization - Restricted")
            
        default: // The user has experienced an unknown error.
            sessionResult = .notAuthorized
            print("Camera Authorization - Unknown")
            return
        }
    }
}
