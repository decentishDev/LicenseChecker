import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var authorizedPlates = ["ZVX967"]
    var greenRectView: UIView!
    var redRectView: UIView!
    var overlayView: UIView!
    var lastDetectionTime = Date()
    var textLabel: UILabel!

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

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
        
        setupOverlayViews()
        setupRegionOverlay()
        setupTextLabel()
    }

    func setupOverlayViews() {
        greenRectView = UIView(frame: CGRect(x: 10, y: 50, width: 50, height: 50))
        greenRectView.backgroundColor = .green
        greenRectView.isHidden = true
        view.addSubview(greenRectView)

        redRectView = UIView(frame: CGRect(x: 10, y: 50, width: 50, height: 50))
        redRectView.backgroundColor = .red
        redRectView.isHidden = true
        view.addSubview(redRectView)
    }
    
    func setupRegionOverlay() {
        overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.isUserInteractionEnabled = false

        // Set the aspect ratio to 3x1
        let aspectRatio: CGFloat = 3.0 / 1.0
        let regionWidth = view.bounds.width * 0.75
        let regionHeight = regionWidth / aspectRatio
        let regionX = (view.bounds.width - regionWidth) / 2.0
        let regionY = (view.bounds.height - regionHeight) / 2.0

        let regionOfInterestPath = UIBezierPath(rect: CGRect(x: regionX, y: regionY+120, width: regionWidth, height: regionHeight))
        let overlayPath = UIBezierPath(rect: overlayView.bounds)
        overlayPath.append(regionOfInterestPath)
        overlayPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = overlayPath.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer

        view.addSubview(overlayView)
    }

    func setupTextLabel() {
        textLabel = UILabel()
        textLabel.frame = CGRect(x: view.bounds.width - 150, y: 50, width: 140, height: 40)
        textLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        textLabel.textColor = .white
        textLabel.textAlignment = .center
        textLabel.text = ""
        view.addSubview(textLabel)
    }

    func handleDetectedText(_ text: String) {
        DispatchQueue.main.async {
            self.textLabel.text = text
            if self.authorizedPlates.contains(text) {
                self.greenRectView.isHidden = false
                self.redRectView.isHidden = true
            } else {
                self.greenRectView.isHidden = true
                self.redRectView.isHidden = false
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastDetectionTime) >= 0.1 else { return }
        lastDetectionTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Adjust the orientation based on the device's orientation
        if let connection = output.connections.first {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = getVideoOrientation()
            }
        }

        let request = VNRecognizeTextRequest(completionHandler: { (request, error) in
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }

            for result in results {
                guard let candidate = result.topCandidates(1).first else { continue }
                let detectedText = candidate.string
                self.handleDetectedText(detectedText)
            }
        })

        // Update regionOfInterest to match the 3x1 aspect ratio
        let regionOfInterest = CGRect(
            x: 0.125,
            y: 0.25,
            width: 0.75,
            height: 0.75 / (3.0 / 1.0)
        )
        request.regionOfInterest = regionOfInterest

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? imageRequestHandler.perform([request])
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
