import SwiftUI
import PhotosUI
import SwiftHaptics

public protocol CameraImagePickerDelegate {
    public func didCapture(_ image: UIImage) -> ()
    public func didPickLibraryImages(numberOfImagesBeingLoaded: Int) -> ()
    public func didLoadLibraryImage(_ image: UIImage, at index: Int) -> ()
}

public struct CameraImagePicker: View {

    @Environment(\.dismiss) var dismiss
    @State var didAppear = false
    @State var selectedPhotos: [PhotosPickerItem] = []
    @State var isPresentingPhotosPicker = false
    @State var animateCameraViewShrinking = false
    @State var makeCameraViewTranslucent = false
    
//    @State var refreshBool = false
    
    let cameraService = CameraService()
    
    let presentedInNavigationStack: Bool
    let maxSelectionCount: Int
    
    @State var imageLoadTask: Task<Void, Error>? = nil
    
    let delegate: CameraImagePickerDelegate
    
    public init(maxSelectionCount: Int = 1, presentedInNavigationStack: Bool = false, delegate: CameraImagePickerDelegate) {
        self.maxSelectionCount = maxSelectionCount
        self.presentedInNavigationStack = presentedInNavigationStack
        self.delegate = delegate
    }
}

//MARK: - Body
extension CameraImagePicker {
    
    public var body: some View {
        ZStack {
            Color.black
            Group {
                if didAppear || !presentedInNavigationStack {
                    content
                } else {
                    Color.clear
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .frame(maxWidth: UIScreen.main.bounds.width)
        .onAppear {
            if presentedInNavigationStack {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 ) {
                    didAppear = true
                }
            }
        }
//        .onChange(of: capturedImages) { newValue in
//            if capturedImages.count == maxSelectionCount {
//                dismiss()
//            } else if selectedPhotos.isEmpty {
//                /// Only refresh the CameraView if we haven't selected photos so that it doesn't jarringly animate the change
//                refreshBool.toggle()
//            }
//        }
        .onChange(of: selectedPhotos) { newValue in
            selectedPhotosChanged(to: newValue)
            dismiss()
        }
        .onDisappear {
//            imageLoadTask?.cancel()
        }
    }

    //MARK: - Components
    var content: some View {
        ZStack {
            cameraLayer
            buttonsLayer
        }
    }
    
    var cameraLayer: some View {
        CameraView(cameraService: cameraService) { result in
            photoCaptured(in: result)
        }
//        .id(refreshBool)
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
                Button {
                    dismiss()
                } label: {
//                    Image(systemName: "\(capturedImages.count).square.fill")
                    Image(systemName: "\("1").square.fill")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                }
            }
            return Group {
                if true {
//                if !capturedImages.isEmpty {
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
        
        cameraService.capturePhoto()
    }
}

//MARK: - Events
extension CameraImagePicker {
    
    func photoCaptured(in result: Result<AVCapturePhoto, Error>) {
        switch result {
        case .success(let photo):
            guard let data = photo.fileDataRepresentation() else {
                print("Error: no image data found")
                return
            }

            DispatchQueue.main.async {
                guard let image = UIImage(data: data) else {
                    return
                }
                delegate.didCapture(image)
//                capturedImages.append(image)
            }

        case .failure(let error):
            print(error.localizedDescription)
        }
    }

    func selectedPhotosChanged(to items: [PhotosPickerItem]) {
        
        delegate.didPickLibraryImages(numberOfImagesBeingLoaded: items.count)
        
        Task {
            imageLoadTask?.cancel()
            imageLoadTask = Task {
                try await withThrowingTaskGroup(of: (Void).self) { group in
                    for index in items.indices {
                        group.addTask {
                            let image = try await loadImage(pickerItem: items[index])
                            try Task.checkCancellation()
                            delegate.didLoadLibraryImage(image, at: index)
                        }
                    }
                    
                    for try await _ in group {
                        try Task.checkCancellation()
                    }
                                
                    try Task.checkCancellation()
                }
            }
        }
    }

    @Sendable func loadImage(pickerItem: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
            throw PhotoPickerError.load
        }
        guard let image = UIImage(data: data) else {
            throw PhotoPickerError.image
        }
        return image
    }
}

enum PhotoPickerError: Error {
    case load
    case image
}


//MARK: - Preview

public struct CameraImagePickerPreview: View {
    
    @State var capturedImages: [UIImage] = []
    
    @StateObject var viewModel: ViewModel = ViewModel()
    
    public var body: some View {
        CameraImagePicker(maxSelectionCount: 5, delegate: viewModel)
    }
    
    public init() { }
    
    class ViewModel: ObservableObject {
        
    }
}

extension CameraImagePickerPreview.ViewModel: CameraImagePickerDelegate {
    func didCapture(_ image: UIImage) {
        print("didCapture an image")
    }
    
    func didPickLibraryImages(numberOfImagesBeingLoaded: Int) {
        print("didPick: \(numberOfImagesBeingLoaded) images")
    }
    
    func didLoadLibraryImage(_ image: UIImage, at index: Int) {
        print("didLoadLibraryImage: at \(index)")
    }
}

struct CameraImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        CameraImagePickerPreview()
    }
}
