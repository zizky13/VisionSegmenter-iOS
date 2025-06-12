//
//  ImagePicker.swift
//  VisionSegmenter
//
//  Created by Zikar Nurizky on 11/06/25.
//

import SwiftUI
import UIKit

// This is a wrapper to make UIImagePickerController work with SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    // This class handles the user's actions (e.g., picking an image or canceling)
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Use the camera. For simulator, you can use .photoLibrary
        #if targetEnvironment(simulator)
        picker.sourceType = .photoLibrary
        #else
        picker.sourceType = .camera
        #endif
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // We don't need to update it
    }
}
