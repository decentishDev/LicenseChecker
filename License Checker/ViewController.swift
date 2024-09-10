import UIKit
import AVFoundation
import Vision
import CoreImage

class ViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var authorizedPlates = ["CD 80519", "ZVX 967"]
    var greenRectView: UIView!
    var redRectView: UIView!
    var overlayView: UIView!
    var lastDetectionTime = Date()
    var textLabel: UILabel!
    var videoDimensions: CMVideoDimensions!
    var downscaledImageView: UIImageView!
    
    var videoX: CGFloat = 0
    var videoY: CGFloat = 0
    var videoW: CGFloat = 500
    var videoH: CGFloat = 500
    
    var whRatio: CGFloat = 2
    
    var shouldDisplayPreview = false

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermission()
    }
    
    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert()
        @unknown default:
            break
        }
    }

    func showPermissionDeniedAlert() {
        let alert = UIAlertController(title: "Camera Access Denied", message: "Please enable camera access in settings to use this feature.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            return
        }

        // Capture video dimensions
        let formatDescription = videoCaptureDevice.activeFormat.formatDescription
        videoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
        
        
        
//        if view.bounds.width > view.bounds.height {
//            previewLayer.setAffineTransform(CGAffineTransform(rotationAngle: -1 * (.pi / 2)))
//        }
        
        setupOverlayViews()
        setupRegionOverlay()
        setupTextLabel()
        if shouldDisplayPreview {
            setupDownscaledImageView()
        }
        setupSettingsButton()
    }
    
    func setupSettingsButton(){
        let settingsButton = UIButton(frame: CGRect(x: 50, y: view.frame.height - 100, width: 50, height: 50))
        settingsButton.addTarget(self, action: #selector(self.SettingsButton(sender:)), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        let settingsImage = UIImageView(frame: CGRect(x: 60, y: view.frame.height - 90, width: 30, height: 30))
        settingsImage.image = UIImage(systemName: "gearshape")
        settingsImage.tintColor = .label
        settingsImage.contentMode = .scaleAspectFit
        view.addSubview(settingsImage)
    }
    
    @objc func SettingsButton(sender: UIButton){
            performSegue(withIdentifier: "showSettings", sender: nil)
        }
    
    func setupDownscaledImageView() {
        downscaledImageView = UIImageView()
        downscaledImageView.frame = CGRect(x: view.bounds.width - 210, y: view.bounds.height - 120, width: 200, height: 200 / whRatio)
        downscaledImageView.contentMode = .scaleAspectFit
        downscaledImageView.layer.borderWidth = 1
        downscaledImageView.layer.borderColor = UIColor.white.cgColor
        view.addSubview(downscaledImageView)
    }

    func setupOverlayViews() {

        redRectView = UIView(frame: CGRect(x: 60, y: 60, width: 40, height: 40))
        redRectView.layer.cornerRadius = 10
        redRectView.backgroundColor = .red
        view.addSubview(redRectView)
        
        greenRectView = UIView(frame: CGRect(x: 60, y: 60, width: 40, height: 40))
        greenRectView.layer.cornerRadius = 10
        greenRectView.backgroundColor = .green
        greenRectView.layer.opacity = 0
        view.addSubview(greenRectView)
    }
    
    func cameraToScreen(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let sW = CGFloat(view.bounds.width)
        let sH = CGFloat(view.bounds.height)
        let vW = CGFloat(videoDimensions.width)
        let vH = CGFloat(videoDimensions.height)

        let screenAspectRatio = sW / sH
        let videoAspectRatio = vW / vH
        
        let scaleX: CGFloat
        let scaleY: CGFloat
        
        if screenAspectRatio > videoAspectRatio {
            let scaleFactor = sH / vH
            scaleX = scaleFactor
            scaleY = scaleFactor
        } else {
            let scaleFactor = sW / vW
            scaleX = scaleFactor
            scaleY = scaleFactor
        }
        
        let offsetX = (sW - vW * scaleX) / 2.0
        let offsetY = (sH - vH * scaleY) / 2.0
        
        let screenX = (x * scaleX) + offsetX
        let screenY = (y * scaleY) + offsetY
        
        return CGPoint(x: screenX, y: screenY)
    }

    func setupRegionOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.isUserInteractionEnabled = false

        let vW = CGFloat(videoDimensions.width)
        let vH = CGFloat(videoDimensions.height)
        videoX = vW * 0.25
        videoW = vW * 0.5
        videoH = videoW / whRatio
        videoY = (vH - videoH)/2

        let screenPoint = cameraToScreen(videoX, videoY)
        let otherPoint = cameraToScreen(videoX + videoW, videoY + videoH)

        let regionRect = CGRect(x: screenPoint.x, y: screenPoint.y, width: otherPoint.x - screenPoint.x, height: otherPoint.y - screenPoint.y)
        let cornerRadius: CGFloat = 10
        let regionOfInterestPath = UIBezierPath(roundedRect: regionRect, cornerRadius: cornerRadius)

        let overlayPath = UIBezierPath(rect: overlay.bounds)
        overlayPath.append(regionOfInterestPath)
        overlayPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = overlayPath.cgPath
        maskLayer.fillRule = .evenOdd
        overlay.layer.mask = maskLayer

        view.addSubview(overlay)
        self.overlayView = overlay
    }
    
    func setupTextLabel() {
        let backgroundColor = UIView(frame: CGRect(x: 110, y: 60, width: view.bounds.width - 170, height: 40))
        backgroundColor.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backgroundColor.layer.cornerRadius = 10
        view.addSubview(backgroundColor)
        textLabel = UILabel()
        textLabel.frame = CGRect(x: 110, y: 50 + 10, width: view.bounds.width - 170, height: 40)
        //textLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        textLabel.textColor = .white
        textLabel.textAlignment = .center
        textLabel.text = ""
        textLabel.layer.cornerRadius = 5
        view.addSubview(textLabel)
    }

    func handleDetectedText(_ text: String) {
        DispatchQueue.main.async {
            self.textLabel.text = text
            if self.authorizedPlates.contains(text) {
                self.greenRectView.layer.opacity = 1
            } else {
                if self.greenRectView.layer.opacity != 0 {
                    self.greenRectView.layer.opacity -= 0.1
                }
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastDetectionTime) >= 0.1 else { return }
        lastDetectionTime = Date()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if let connection = output.connections.first {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = getVideoOrientation()
            }
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let bufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        videoX = bufferWidth * 0.25
        videoW = bufferWidth * 0.5
        videoH = videoW / whRatio
        videoY = (bufferHeight - videoH)/2
        
        let roiRect = CGRect(x: videoX, y: videoY, width: videoW, height: videoH)
        let croppedCIImage = ciImage.cropped(to: roiRect)
        
        let downscaleTransform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        var downscaledCIImage = croppedCIImage.transformed(by: downscaleTransform)
        //downscaledCIImage = increaseContrast(of: downscaledCIImage, contrast: 2)!
        downscaledCIImage = enhanceRedText(in: downscaledCIImage)!
        downscaledCIImage = enhanceRedText(in: downscaledCIImage)!
        //downscaledCIImage = increaseContrast(of: downscaledCIImage, contrast: 2)!
        
        if shouldDisplayPreview {
            DispatchQueue.main.async {
                let downscaledUIImage = self.convertCIImageToUIImage(ciImage: downscaledCIImage)
                self.downscaledImageView.image = downscaledUIImage
            }
        }
        
        let context = CIContext()
        if let cgImage = context.createCGImage(downscaledCIImage, from: downscaledCIImage.extent) {
            
            let request = VNRecognizeTextRequest(completionHandler: { (request, error) in
                guard let results = request.results as? [VNRecognizedTextObservation] else { return }
                
                var anyGood = false
                var lastThing = ""
                for result in results {
                    guard let candidate = result.topCandidates(1).first else { continue }
                    let detectedText = candidate.string
                    if self.authorizedPlates.contains(detectedText) {
                        anyGood = true
                        lastThing = detectedText
                    }
                    if !anyGood {
                        lastThing = detectedText
                    }
                }
                self.handleDetectedText(lastThing)
            })
            
            let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? imageRequestHandler.perform([request])
        }
    }
    
    func createWeightedBWImage(from downscaledCIImage: CIImage) -> CIImage? {
        let context = CIContext()
        
        let redFilter = CIFilter(name: "CIColorMatrix")!
        redFilter.setValue(downscaledCIImage, forKey: kCIInputImageKey)
        redFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        redFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        redFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        redFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        let redCIImage = redFilter.outputImage!.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputBrightnessKey: 0, kCIInputContrastKey: 1])
        
        let greenFilter = CIFilter(name: "CIColorMatrix")!
        greenFilter.setValue(downscaledCIImage, forKey: kCIInputImageKey)
        greenFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        greenFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        greenFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        greenFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        let greenCIImage = greenFilter.outputImage!.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputBrightnessKey: 0, kCIInputContrastKey: 1])
        
        let blueFilter = CIFilter(name: "CIColorMatrix")!
        blueFilter.setValue(downscaledCIImage, forKey: kCIInputImageKey)
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        let blueCIImage = blueFilter.outputImage!.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputBrightnessKey: 0, kCIInputContrastKey: 1])
        
        let redWeightedImage = redCIImage.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputImageKey: redCIImage, kCIInputBackgroundImageKey: CIImage(color: .black).cropped(to: downscaledCIImage.extent), kCIInputMaskImageKey: CIImage(color: .white).cropped(to: downscaledCIImage.extent)])
        let greenWeightedImage = greenCIImage.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputImageKey: greenCIImage, kCIInputBackgroundImageKey: CIImage(color: .black).cropped(to: downscaledCIImage.extent), kCIInputMaskImageKey: CIImage(color: .white).cropped(to: downscaledCIImage.extent)])
        let blueWeightedImage = blueCIImage.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputImageKey: blueCIImage, kCIInputBackgroundImageKey: CIImage(color: .black).cropped(to: downscaledCIImage.extent), kCIInputMaskImageKey: CIImage(color: .white).cropped(to: downscaledCIImage.extent)])
        
        let redBlend = CIFilter(name: "CIBlendWithAlphaMask")!
        redBlend.setValue(redWeightedImage, forKey: kCIInputImageKey)
        redBlend.setValue(greenWeightedImage, forKey: kCIInputBackgroundImageKey)
        redBlend.setValue(blueCIImage, forKey: kCIInputMaskImageKey)
        let intermediateImage = redBlend.outputImage!

        let finalFilter = CIFilter(name: "CIBlendWithAlphaMask")!
        finalFilter.setValue(intermediateImage, forKey: kCIInputImageKey)
        finalFilter.setValue(CIImage(color: .black).cropped(to: downscaledCIImage.extent), forKey: kCIInputBackgroundImageKey)
        finalFilter.setValue(CIImage(color: .white).cropped(to: downscaledCIImage.extent), forKey: kCIInputMaskImageKey)

        return finalFilter.outputImage?.cropped(to: downscaledCIImage.extent)
    }
    
    func createGreenBlueBWImage(from downscaledCIImage: CIImage) -> CIImage? {
        let context = CIContext()
        
        let greenFilter = CIFilter(name: "CIColorMatrix")!
        greenFilter.setValue(downscaledCIImage, forKey: kCIInputImageKey)
        greenFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector") // Ignore red
        greenFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        greenFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        greenFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        let greenCIImage = greenFilter.outputImage!.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputBrightnessKey: 0, kCIInputContrastKey: 1])
        
        let blueFilter = CIFilter(name: "CIColorMatrix")!
        blueFilter.setValue(downscaledCIImage, forKey: kCIInputImageKey)
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector") // Ignore red
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        blueFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        let blueCIImage = blueFilter.outputImage!.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputBrightnessKey: 0, kCIInputContrastKey: 1])
        
        let greenWeightedImage = greenCIImage.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputImageKey: greenCIImage, kCIInputBackgroundImageKey: CIImage(color: .black).cropped(to: downscaledCIImage.extent), kCIInputMaskImageKey: CIImage(color: .white).cropped(to: downscaledCIImage.extent)])
        let blueWeightedImage = blueCIImage.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputImageKey: blueCIImage, kCIInputBackgroundImageKey: CIImage(color: .black).cropped(to: downscaledCIImage.extent), kCIInputMaskImageKey: CIImage(color: .white).cropped(to: downscaledCIImage.extent)])
        
        let combinedImageFilter = CIFilter(name: "CISourceOverCompositing")!
        combinedImageFilter.setValue(greenWeightedImage, forKey: kCIInputImageKey)
        combinedImageFilter.setValue(blueWeightedImage, forKey: kCIInputBackgroundImageKey)
        let combinedCIImage = combinedImageFilter.outputImage!

        return combinedCIImage.cropped(to: downscaledCIImage.extent)
    }
    
    func enhanceRedText(in image: CIImage) -> CIImage? {
        // Create a Core Image context
        let context = CIContext(options: nil)
        
        // Step 1: Increase saturation to enhance red colors
        guard let saturationFilter = CIFilter(name: "CIColorControls") else { return nil }
        saturationFilter.setValue(image, forKey: kCIInputImageKey)
        saturationFilter.setValue(1.5, forKey: kCIInputSaturationKey)  // Increase saturation
        saturationFilter.setValue(0.0, forKey: kCIInputBrightnessKey)   // No change to brightness
        saturationFilter.setValue(1.0, forKey: kCIInputContrastKey)     // Adjust contrast as needed
        
        guard let saturatedImage = saturationFilter.outputImage else { return nil }
        
        // Step 2: Apply hue adjustment to emphasize reds
        guard let hueFilter = CIFilter(name: "CIHueAdjust") else { return nil }
        hueFilter.setValue(saturatedImage, forKey: kCIInputImageKey)
        hueFilter.setValue(0.0, forKey: kCIInputAngleKey)  // Keep hue as-is for red

        guard let hueAdjustedImage = hueFilter.outputImage else { return nil }
        
        // Step 3: Brighten the white areas
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return nil }
        exposureFilter.setValue(hueAdjustedImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.7, forKey: kCIInputEVKey)  // Increase exposure to brighten white
        
        guard let brightenedImage = exposureFilter.outputImage else { return nil }

        // Render the final image
        return brightenedImage
    }
    
    func increaseContrast(of inputImage: CIImage, contrast: Float) -> CIImage? {
        // Apply the CIColorControls filter to adjust contrast
        let contrastFilter = CIFilter(name: "CIColorControls")
        contrastFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        contrastFilter?.setValue(contrast, forKey: kCIInputContrastKey) // Default contrast is 1.0, values > 1 increase contrast

        // Get the output image from the filter
        guard let outputImage = contrastFilter?.outputImage else {
            return nil
        }

        return outputImage
    }

    func convertCIImageToUIImage(ciImage: CIImage) -> UIImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    func getVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}
