import SwiftUI
import PhotosUI

public struct CameraImagePicker: View {

    @Environment(\.dismiss) var dismiss
    
    let cameraService = CameraService()
    @Binding var capturedImage: UIImage?

    /// This mitigates an issue of the delegate of the `CameraService` being set back to nil when this view is pushed onto a `NavigationStack`. Conditionally toggling the actual camera view in the `onAppear` modifier seems to fix the issue.
    @State var didAppear = false

    @State var selectedPhotos: [PhotosPickerItem] = []
    @State var isPresentingPhotosPicker = false
    
    public init(capturedImage: Binding<UIImage?>) {
        _capturedImage = capturedImage
    }
    
    public var body: some View {
        Group {
            if didAppear {
                content
            } else {
                Color.clear
            }
        }
        .onAppear {
            didAppear = true
        }
//        .sheet(isPresented: $isPresentingPhotosPicker) {
//            PhotosPicker(selection: $selectedPhotos,
//                         maxSelectionCount: 1,
//                         matching: .images) {
//                Image(systemName: "photo.on.rectangle.angled")
//                    .font(.system(size: 25))
//                    .foregroundColor(.white)
//            }
//        }
    }
    
    var content: some View {
        var cameraViewLayer: some View {
            CameraView(cameraService: cameraService) { result in
                switch result {
                case .success(let photo):
                    guard let data = photo.fileDataRepresentation() else {
                        print("Error: no image data found")
                        return
                    }
                    capturedImage = UIImage(data: data)
                    dismiss()
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
        
        var buttonLayer: some View {
            VStack {
                Spacer()
                ZStack {
                    HStack {
                        PhotosPicker(selection: $selectedPhotos,
                                     maxSelectionCount: 1,
                                     matching: .images) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 25))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.leading)
                    Button {
                        cameraService.capturePhoto()
                    } label: {
                        Image(systemName: "circle")
                            .font(.system(size: 72))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.bottom)
            }
        }
        
        return ZStack {
            cameraViewLayer
                .edgesIgnoringSafeArea(.bottom)
            buttonLayer
        }
        .onChange(of: selectedPhotos) { newValue in
            guard let item = newValue.first else {
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
}
