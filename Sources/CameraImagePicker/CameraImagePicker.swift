import SwiftUI
import PhotosUI
import SwiftHaptics
import SwiftUISugar

public protocol CameraImagePickerDelegate {
    func didCapture(_ image: UIImage) -> ()
    func didPickLibraryImages(numberOfImagesBeingLoaded: Int) -> ()
    func didLoadLibraryImage(_ image: UIImage, at index: Int) -> ()
}

public struct CameraImagePicker: View {

    @Environment(\.dismiss) var dismiss
    @State var didAppear = false
    @State var selectedPhotos: [PhotosPickerItem] = []
    @State var isPresentingPhotosPicker = false
    @State var animateCameraViewShrinking = false
    @State var makeCameraViewTranslucent = false
   
    let didCaptureImage = NotificationCenter.default.publisher(for: .didCaptureImage)
    let didNotCaptureImage = NotificationCenter.default.publisher(for: .didNotCaptureImage)
//    @State var refreshBool = false
    
    let cameraService = CameraService()
    
    let presentedInNavigationStack: Bool
    let maxSelectionCount: Int
    let showPhotoPickerButton: Bool
    @State var numberOfCapturedImages: Int = 0
    
    @State var imageLoadTask: Task<Void, Error>? = nil
    
    @State var flashMode: AVCaptureDevice.FlashMode = .auto
    @State var torchIsOn: Bool = false

    let delegate: CameraImagePickerDelegate
    
    public init(maxSelectionCount: Int = 1, showPhotoPickerButton: Bool = false, presentedInNavigationStack: Bool = false, delegate: CameraImagePickerDelegate) {
        self.maxSelectionCount = maxSelectionCount
        self.showPhotoPickerButton = showPhotoPickerButton
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
        .onReceive(didCaptureImage, perform: didCaptureImage)
        .onReceive(didNotCaptureImage, perform: didNotCaptureImage)
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
//            cameraLayer
            Color.black
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
                Button {
                    dismiss()
                } label: {
//                    Image(systemName: "\(capturedImages.count).square.fill")
                    Image(systemName: "\(numberOfCapturedImages).square.fill")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                }
            }
            return Group {
                if numberOfCapturedImages > 0 {
                    HStack {
                        Spacer()
                        doneButton
                    }
                    .padding(.trailing)
                }
            }
        }
        
        var flashButton: some View {
            Menu {
                Button("On") {
                    Haptics.feedback(style: .medium)
                    withAnimation {
                        flashMode = .on
                    }
                }
                Button("Off") {
                    Haptics.feedback(style: .medium)
                    withAnimation {
                        flashMode = .off
                    }
                }
                Button("Auto") {
                    Haptics.feedback(style: .medium)
                    withAnimation {
                        flashMode = .auto
                    }
                }
            } label: {
                Image(systemName: flashMode.systemImage)
                    .renderingMode(flashMode.renderingMode)
                    .imageScale(.small)
                    .font(.system(size: 25))
                    .foregroundColor(
                        flashMode.foregroundColor
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .foregroundColor(flashMode.backgroundColor)
                            .opacity(flashMode == .off ? 1.0 : 0.6)
                    )
                    .padding(.leading, 9)
                    .padding(.vertical, 20)
                    .padding(.trailing, 40)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            } primaryAction: {
                Haptics.feedback(style: .medium)
                withAnimation {
                    if flashMode == .auto || flashMode == .on {
                        flashMode = .off
                    } else {
                        if flashMode == .off {
                            flashMode = .auto
                        }
                    }
                }
            }
        }
        
        var torchButton: some View {
            Button {
                Haptics.feedback(style: .rigid)
                withAnimation {
                    torchIsOn.toggle()
                }
                setTorch()
            } label: {
                Image(systemName: "flashlight.\(torchIsOn ? "on" : "off").fill")
                    .imageScale(.small)
                    .font(.system(size: 25))
                    .foregroundColor(
                        torchIsOn
                        ? .black
                        : .white
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .foregroundColor(
                                torchIsOn
                                ? Color(.secondarySystemBackground)
                                : Color(.systemFill)
                            )
                            .opacity(!torchIsOn ? 1.0 : 0.6)
                    )
                    .padding(.trailing, 9)
                    .padding(.vertical, 20)
                    .padding(.leading, 40)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
        }
        
        var flashButtonLayer: some View {
            HStack {
                flashButton
                    .padding(.leading)
                Spacer()
                torchButton
                    .padding(.trailing)
            }
        }
    
        return ZStack {
            VStack {
                flashButtonLayer
                    .padding(.top)
                Spacer()
                ZStack {
                    if showPhotoPickerButton {
                        photoPickerButtonLayer
                    }
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
    
    func setTorch() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                device.torchMode = torchIsOn ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
    
    func getTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else {
            return
        }
        
        do {
//            try device.lockForConfiguration()
            torchIsOn = device.torchMode != .off
//            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
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
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        cameraService.capturePhoto(with: settings)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.getTorch()
        }
    }
}

//MARK: - Events
extension CameraImagePicker {
    
    func didCaptureImage(notification: Notification) {
        guard let image = notification.userInfo?[Notification.CameraImagePickerKeys.image] as? UIImage else {
            return
        }
        
        DispatchQueue.main.async {
            delegate.didCapture(image)
            numberOfCapturedImages += 1
            if numberOfCapturedImages == maxSelectionCount {
                dismiss()
            }
        }
    }
    
    func didNotCaptureImage(notification: Notification) {
        //TODO: Handle errors properly
        guard let error = notification.userInfo?[Notification.CameraImagePickerKeys.error] as? Error else {
            return
        }
        print(error.localizedDescription)
    }

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
                numberOfCapturedImages += 1
                if numberOfCapturedImages == maxSelectionCount {
                    dismiss()
                }
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
                            
                            await MainActor.run {
                                delegate.didLoadLibraryImage(image, at: index)
                            }
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

extension AVCaptureDevice.FlashMode {
    var systemImage: String {
        switch self {
        case .off:
            return "bolt.slash.fill"
        case .on, .auto:
            return "bolt.fill"
        @unknown default:
            return "bolt.slash"
        }
    }
    
    var renderingMode: Image.TemplateRenderingMode {
        switch self {
        case .on:
            return .original
        case .off, .auto:
            return .template
        @unknown default:
            return .template
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .on, .auto:
            return Color(.systemGroupedBackground)
        case .off:
            return Color(.systemFill)
        @unknown default:
            return Color.clear
        }
    }

    var foregroundColor: Color {
        switch self {
        case .on, .auto:
            return .black
        case .off:
            return .white
        @unknown default:
            return Color.clear
        }
    }

}
