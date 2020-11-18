//
//  CameraButton.swift
//  Vivid Camera
//
//  Created by Nolan Fuchs on 11/14/20.
//

import UIKit

@IBDesignable
public class CameraButton: UIButton {
    @IBInspectable var color: UIColor? = .gray {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable var ringWidth: CGFloat = 5
    
    var progress: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    
    private var progressLayer = CAShapeLayer()
    private var backgroundMask = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        backgroundMask.lineWidth = ringWidth
        backgroundMask.fillColor = nil
        backgroundMask.strokeColor = UIColor.black.cgColor
        layer.mask = backgroundMask
        
        progressLayer.lineWidth = ringWidth
        progressLayer.lineCap = .round
        progressLayer.fillColor = nil
        progressLayer.strokeEnd = 0
       
        layer.addSublayer(progressLayer)
        layer.transform = CATransform3DMakeRotation(CGFloat(90 * Double.pi / 180), 0, 0, -1)
    }
    
    public override func draw(_ rect: CGRect) {

        // Creating the paths for the background and progress layer
        let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
        backgroundMask.path = circlePath.cgPath
        progressLayer.path = circlePath.cgPath
        
        // Respond to touch events by user
        self.addTarget(self, action: #selector(onPress), for: .touchDown)
    }
    
    @objc
    func onPress() {
        // Creating the initial haptic feedback
        let initialGenerator = UIImpactFeedbackGenerator(style: .medium)
        initialGenerator.prepare()
        initialGenerator.impactOccurred()
        
        // Setting progress to 1 in order to complete a full rotation
        progress = 1
        
        // Disabling user interaction
        self.isUserInteractionEnabled = false
 
        // Begin button animations
        CATransaction.begin()
        // Upon completion, re-enable button interaction and create a success haptic feedback
        CATransaction.setCompletionBlock({
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.prepare()
    successGenerator.notificationOccurred(.success)
            self.isUserInteractionEnabled = true
        })
        //Create the animation
        let strokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        strokeEndAnimation.toValue = progress
        strokeEndAnimation.duration = 1
        strokeEndAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        strokeEndAnimation.fillMode = .forwards
        // Add the animation
        progressLayer.add(strokeEndAnimation, forKey: "strokeEndAnimation")
        // Call animation complete
        CATransaction.commit()
        
        // Stroke color for the progress layer
        progressLayer.strokeColor = color?.cgColor
    }
        
        
}


