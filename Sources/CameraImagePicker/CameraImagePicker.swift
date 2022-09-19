import SwiftUI
import PhotosUI
import SwiftHaptics

public struct CameraImagePicker: View {

    @Environment(\.dismiss) var dismiss
    
    @State var didAppear = false
    
    let cameraService = CameraService()
    @Binding var capturedImage: UIImage?

    @Binding var capturedImages: [UIImage]

    @State var selectedPhotos: [PhotosPickerItem] = []
    @State var isPresentingPhotosPicker = false
    
    @State var imageToAnimate: UIImage? = nil
    
    @State var animateImageAppearance = false
    @State var animateCameraViewShrinking = false
    @State var animateImageShrinking = false
    @State var makeCameraViewTranslucent = false
    
    @State var mockCameraView: Bool
    let presentedInNavigationStack: Bool
    
    let willCapturePhoto = NotificationCenter.default.publisher(for: .willCapturePhoto)
    
    public init(capturedImage: Binding<UIImage?>,
                capturedImages: Binding<[UIImage]>? = nil,
                presentedInNavigationStack: Bool = false,
                mockCameraView: Bool = false)
    {
        _capturedImage = capturedImage
        _capturedImages = capturedImages ?? .constant([])
        _mockCameraView = State(initialValue: mockCameraView)
        self.presentedInNavigationStack = presentedInNavigationStack
    }
}

//MARK: - Body
extension CameraImagePicker {
    
    public var body: some View {
        Group {
            if didAppear || !presentedInNavigationStack {
                content
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width)
        .onAppear {
            if presentedInNavigationStack {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 ) {
                    didAppear = true
                }
            }
//            imageToAnimate = mockImage
        }
        .onChange(of: selectedPhotos) { newValue in
            selectedPhotosChanged(to: newValue)
        }
        .onReceive(willCapturePhoto) { notification in
            print("\(Date().timeIntervalSince1970) willCapturePhoto")
        }
    }

    //MARK: - Components

    var content: some View {
        ZStack {
            GeometryReader { proxy in
//                if animateCameraViewShrinking {
//                    cameraLayer
//                }
                topCameraLayer
                buttonsLayer
                captureAnimationLayer
                    .frame(width: proxy.size.width)
            }
        }
    }
    
    var captureAnimationLayer: some View {
        var opacity: Double {
            guard !animateImageShrinking else {
                return 0
            }
            
            if animateImageAppearance {
                return 1
            } else {
                return 0
            }
        }
        
        return VStack {
            Spacer()
            if let image = imageToAnimate {
                HStack {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
//                        .aspectRatio(contentMode: shrinkImageToAnimate ? .fit : .fill)
//                        .frame(width: 100, height: 100)
                        .frame(maxWidth: animateImageShrinking ? 1 : .infinity,
                               maxHeight: animateImageShrinking ? 1 : .infinity)
//                        .opacity(opacity)
                }
                .padding(.trailing)
                .padding(.bottom)
                .opacity(animateImageAppearance ? 1 : 0)
            }
        }
    }
    
    var cameraLayer: some View {
        Group {
            if mockCameraView {
                Color.blue
            } else {
                CameraView(cameraService: cameraService) { result in
                    photoCaptured(in: result)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
    }

    var topCameraLayer: some View {
        Group {
            if mockCameraView {
                Color.blue
            } else {
                CameraView(cameraService: cameraService) { result in
                    photoCaptured(in: result)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .scaleEffect(animateCameraViewShrinking ? 0.01 : 1, anchor: .bottomTrailing)
        .padding(.bottom, animateCameraViewShrinking ? 15 : 0)
        .padding(.trailing, animateCameraViewShrinking ? 15 : 0)
        .opacity(makeCameraViewTranslucent ? 0 : 1)
    }
    
    var buttonsLayer: some View {
        
        var photoPickerButtonLayer: some View {
            
            var photoPickerButton: some View {
                PhotosPicker(selection: $selectedPhotos,
                             maxSelectionCount: 5,
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
            .padding(.leading, 10)

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
            return Group {
                if !capturedImages.isEmpty {
                    HStack {
                        Spacer()
                        doneButton
                    }
                    .padding(.trailing)
                }
            }
        }
    
        return ZStack {
            VStack {
                Spacer()
                ZStack {
                    photoPickerButtonLayer
                    capturePhotoButtonLayer
                    doneButtonLayer
                }
                .padding(.bottom)
            }
        }
    }
}

//MARK: - Actions

extension CameraImagePicker {
    
    var mockImage: UIImage? {
        guard let path = Bundle.module.path(forResource: "image3", ofType: "jpg"),
              let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        return image
    }
    
    func tappedCapture() {
        Haptics.feedback(style: .rigid)
        withAnimation(.easeInOut(duration: 0.4)) {
            animateCameraViewShrinking = true
            makeCameraViewTranslucent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateCameraViewShrinking = false
            withAnimation(.easeInOut(duration: 0.2)) {
                makeCameraViewTranslucent = false
            }
        }

        guard !mockCameraView else {
            capturedImages.append(UIImage())
            
            if let mockImage = mockImage {
//                animateImageCapture(mockImage)
            }
            return
        }
        
        cameraService.capturePhoto()
    }
    
    func animateImageCapture(_ image: UIImage) {
        Haptics.feedback(style: .heavy)
        withAnimation(.easeInOut(duration: 0.5)) {
            imageToAnimate = image
            animateImageAppearance = true
        }

//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            withAnimation(.easeInOut(duration: 0.6)) {
//                animateImageShrinking = true
//            }
//        }

//        animateImageShrinking = false
//        withAnimation(.easeInOut(duration: 0.3)) {
//        }
    }
    
    func photoCaptured(in result: Result<AVCapturePhoto, Error>) {
        switch result {
        case .success(let photo):
            guard let data = photo.fileDataRepresentation() else {
                print("Error: no image data found")
                return
            }
            
            if let image = UIImage(data: data) {
//                animateImageCapture(image)
                capturedImages.append(image)
                capturedImage = image
            } else {
                capturedImage = nil
            }
            
            //TODO: Dismiss if we've captured the requirement number
//            dismiss()
            
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

public struct CameraImagePickerPreview: View {
    
    @State var capturedImage: UIImage? = nil
    @State var capturedImages: [UIImage] = []
    
    let mockCameraView: Bool
    public var body: some View {
        CameraImagePicker(
            capturedImage: $capturedImage,
            capturedImages: $capturedImages,
            mockCameraView: mockCameraView)
    }
    
    public init(mockCameraView: Bool = false) {
        self.mockCameraView = mockCameraView
    }
}

struct CameraImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        CameraImagePickerPreview(mockCameraView: true)
    }
}
