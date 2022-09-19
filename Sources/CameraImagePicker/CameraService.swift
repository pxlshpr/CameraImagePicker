import Foundation
import AVFoundation

class CameraService {
    
    var session: AVCaptureSession?
    var delegate: AVCapturePhotoCaptureDelegate?
    
    let output = AVCapturePhotoOutput()
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    func start(delegate: AVCapturePhotoCaptureDelegate, completion: @escaping (Error?) -> ()) {
        self.delegate = delegate
        checkPermissions(completion: completion)
    }
    
    private func checkPermissions(completion: @escaping (Error?) -> ()) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.setupCamera(completion: completion)
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setupCamera(completion: completion)
        @unknown default:
            break
        }
    }
    
    private func setupCamera(completion: @escaping (Error?) -> ()) {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.session = session
            
            DispatchQueue.global(qos: .userInteractive).async {
                session.startRunning()
            }
            self.session = session
        } catch {
            completion(error)
        }
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings = AVCapturePhotoSettings()) {
        guard let delegate = delegate else {
            return
        }
        NotificationCenter.default.post(name: .willCapturePhoto, object: nil)
//        self.session?.stopRunning()
//        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.) {
//            self.session?.startRunning()
//        }
        output.capturePhoto(with: settings, delegate: delegate)
    }
}

extension Notification.Name {
    static var willCapturePhoto: Notification.Name { return .init("willCapturePhoto") }
}
