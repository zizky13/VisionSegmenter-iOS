//
//  ImagerSegmentationViewModel.swift
//  VisionSegmenter
//
//  Created by Zikar Nurizky on 12/06/25.
//

import Vision
import SwiftUI
import CoreImage.CIFilterBuiltins

class ImageSegmentationViewModel: ObservableObject {
    //the image lives here
    @Published var inputImage: UIImage?
    @Published var segmentedImage: UIImage? //segmented image is in UIImage
    
    init(inputImage: UIImage? = nil, segmentedImage: UIImage? = nil) {
        self.inputImage = inputImage
        self.segmentedImage = segmentedImage
    }
    
    
    func performSegmentation(for image: UIImage) {
        let request = VNGenerateForegroundInstanceMaskRequest()

        guard let cgImage = image.cgImage else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                // The result is now an array of VNInstanceMaskObservation
                guard let observations = request.results else { return }

                // Let's create a composite mask for ALL found instances
                if let compositeMask = self.createCompositeMask(
                    from: observations, for: cgImage)
                {
                    self.applyMask(mask: compositeMask, to: image)
                }

            } catch {
                print(
                    "Failed to perform segmentation: \(error.localizedDescription)"
                )
            }
        }
    }
    
    func createCompositeMask(
        from observations: [VNInstanceMaskObservation], for image: CGImage
    ) -> CVPixelBuffer? {
        // Create a new Core Image context
        let context = CIContext()

        // Get the dimensions of the original image
        let imageWidth = image.width
        let imageHeight = image.height

        // Start with an empty, black CIImage as our canvas for the composite mask
        var compositeMaskImage = CIImage(color: .black).cropped(
            to: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        for observation in observations {
            do {
                // For each observation, generate its individual mask.
                // This is the key change! We call a method on the observation.
                let mask = try observation.generateMaskedImage(
                    ofInstances: observation.allInstances,  // get a mask for all instances in this observation
                    from: VNImageRequestHandler(cgImage: image),
                    croppedToInstancesExtent: false
                )

                // Convert the generated mask (which is a CVPixelBuffer) to a CIImage
                let ciMask = CIImage(cvPixelBuffer: mask)

                // Use a "Source Over" blend filter to add the new mask to our composite canvas.
                // This is like layering stencils on top of each other.
                let blendFilter = CIFilter.sourceOverCompositing()
                blendFilter.inputImage = ciMask
                blendFilter.backgroundImage = compositeMaskImage

                if let blendedImage = blendFilter.outputImage {
                    compositeMaskImage = blendedImage
                }

            } catch {
                print("Failed to generate mask for an instance: \(error)")
                continue  // continue to the next observation if one fails
            }
        }

        // Now, render the final composite CIImage back to a CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, imageWidth, imageHeight,
            kCVPixelFormatType_OneComponent8, nil, &pixelBuffer)

        guard let finalPixelBuffer = pixelBuffer else { return nil }

        context.render(compositeMaskImage, to: finalPixelBuffer)

        return finalPixelBuffer
    }
    
    
    func applyMask(mask: CVPixelBuffer, to originalImage: UIImage) {
        let originalCIImage = CIImage(image: originalImage)!
        var maskCIImage = CIImage(cvPixelBuffer: mask)

        // The mask is often smaller than the original image, so we scale it up.
        let scaleX = originalCIImage.extent.width / maskCIImage.extent.width
        let scaleY = originalCIImage.extent.height / maskCIImage.extent.height
        maskCIImage = maskCIImage.transformed(
            by: .init(scaleX: scaleX, y: scaleY))

        // We use a Core Image filter to blend the original image with the mask.
        let filter = CIFilter.blendWithMask()
        filter.inputImage = originalCIImage
        filter.maskImage = maskCIImage
        filter.backgroundImage = CIImage(color: .black).cropped(
            to: originalCIImage.extent)  // Black background

        if let outputImage = filter.outputImage {
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(
                outputImage, from: outputImage.extent)
            {
                // Update the UI on the main thread
                DispatchQueue.main.async {
                    self.segmentedImage = UIImage(cgImage: cgImage)
                }
            }
        }
    }
    
}

