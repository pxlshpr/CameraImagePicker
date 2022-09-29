import Foundation
import AVFoundation
import Photos

class CameraService: NSObject, ObservableObject {
    
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
            
            if input.device.isFocusModeSupported(.continuousAutoFocus) {
                try input.device.lockForConfiguration()
                input.device.focusMode = .continuousAutoFocus
                input.device.unlockForConfiguration()
            }
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
//            session.sessionPreset = .high
            
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
        output.capturePhoto(with: settings, delegate: self)
//        guard let delegate else {
//            return
//        }
//        output.capturePhoto(with: settings, delegate: delegate)
    }
}

import UIKit

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: Result<AVCapturePhoto, Error>
        if let error {
            result = .failure(error)
        } else {
            result = .success(photo)
        }
        
        switch result {
        case .success(let photo):
            guard let data = photo.fileDataRepresentation() else {
                print("Error: no image data found")
                return
            }

            guard let image = UIImage(data: data) else {
                return
            }
            let userInfo = [
                Notification.CameraImagePickerKeys.image: image,
            ]
            NotificationCenter.default.post(name: .didCaptureImage, object: nil, userInfo: userInfo)
//                delegate.didCapture(image)
//                numberOfCapturedImages += 1
//                if numberOfCapturedImages == maxSelectionCount {
//                    dismiss()
//                }
        case .failure(let error):
            print(error.localizedDescription)
            let userInfo = [
                Notification.CameraImagePickerKeys.error: error,
            ]
            NotificationCenter.default.post(name: .didNotCaptureImage, object: nil, userInfo: userInfo)
        }
    }
}

extension Notification.Name {
    static var didCaptureImage: Notification.Name { return .init("didCaptureImage") }
    static var didNotCaptureImage: Notification.Name { return .init("didNotCaptureImage") }
}

extension Notification {
    struct CameraImagePickerKeys {
        static let error = "error"
        static let image = "image"
    }
}
