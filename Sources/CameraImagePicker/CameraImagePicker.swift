import SwiftUI
import PhotosUI

public struct CameraImagePicker: View {

    @Environment(\.dismiss) var dismiss
    
    @State var didAppear = false
    
    let cameraService = CameraService()
    @Binding var capturedImage: UIImage?

    @Binding var capturedImages: [UIImage]

    @State var selectedPhotos: [PhotosPickerItem] = []
    @State var isPresentingPhotosPicker = false
    
    @State var imageToAnimate: UIImage? = nil
    
    let mockCameraView: Bool
    
    public init(capturedImage: Binding<UIImage?>, capturedImages: Binding<[UIImage]>? = nil, mockCameraView: Bool = false) {
        _capturedImage = capturedImage
        _capturedImages = capturedImages ?? .constant([])
        self.mockCameraView = mockCameraView
    }
}

//MARK: - Body
extension CameraImagePicker {
    
    public var body: some View {
        Group {
            if didAppear {
                content
            } else {
                Color.clear
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 ) {
                didAppear = true
            }
        }
        .onChange(of: selectedPhotos) { newValue in
            selectedPhotosChanged(to: newValue)
        }
    }
}

//MARK: - Components

extension CameraImagePicker {
    
    var content: some View {
        var cameraLayer: some View {
            CameraView(cameraService: cameraService) { result in
                photoCaptured(in: result)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        
        var buttonsLayer: some View {
            
            var photoPickerButtonLayer: some View {
                
                var photoPickerButton: some View {
                    PhotosPicker(selection: $selectedPhotos,
                                 maxSelectionCount: 1,
                                 matching: .images) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 25))
                            .foregroundColor(.white)
                    }
                }

                return HStack {
                    photoPickerButton
                    Spacer()
                }
                .padding(.leading)

            }
            
            var capturePhotoButtonLayer: some View {
                Button {
                    tappedCapture()
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderless)
            }
            
            var doneButtonLayer: some View {
                var doneButton: some View {
                    Image(systemName: "\(capturedImages.count).square.fill")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                }
                return HStack {
                    Spacer()
                    doneButton
                }
                .padding(.trailing)
            }
            
            return VStack {
                Spacer()
                ZStack {
                    photoPickerButtonLayer
                    capturePhotoButtonLayer
                    if !capturedImages.isEmpty {
                        doneButtonLayer
                    }
                }
                .padding(.bottom)
            }
        }
        
        var mockCameraLayer: some View {
            Color.black
        }
        
        return ZStack {
            if mockCameraView {
                mockCameraLayer
            } else {
                cameraLayer
            }
            buttonsLayer
        }
    }
}

//MARK: - Actions

extension CameraImagePicker {
    func tappedCapture() {
        guard !mockCameraView else {
            capturedImages.append(UIImage())
            if let mockImage = UIImage(named: "mockImage") {
                animateImageCapture(mockImage)
            }
            return
        }
        cameraService.capturePhoto()
    }
    
    func animateImageCapture(_ image: UIImage) {
        imageToAnimate = image
        //Now animate
    }
    
    func photoCaptured(in result: Result<AVCapturePhoto, Error>) {
        switch result {
        case .success(let photo):
            guard let data = photo.fileDataRepresentation() else {
                print("Error: no image data found")
                return
            }
            
            if let image = UIImage(data: data) {
                animateImageCapture(image)
                capturedImage = image
            } else {
                capturedImage = nil
            }
            
            //TODO: Dismiss if we've captured the requirement number
            dismiss()
            
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
    
    func selectedPhotosChanged(to items: [PhotosPickerItem]) {
        guard let item = items.first else {
            return
        }
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                guard let data = data else {
                    print("Data is nil")
                    return
                }
                DispatchQueue.main.async {
                    self.capturedImage = UIImage(data: data)
                    dismiss()
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }

    }
}

//MARK: - Preview

struct CameraImagePickerPreview: View {
    
    @State var capturedImage: UIImage? = nil
    @State var capturedImages: [UIImage] = []
    
    var body: some View {
        CameraImagePicker(
            capturedImage: $capturedImage,
            capturedImages: $capturedImages,
            mockCameraView: true)
    }
}

struct CameraImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        CameraImagePickerPreview()
    }
}
