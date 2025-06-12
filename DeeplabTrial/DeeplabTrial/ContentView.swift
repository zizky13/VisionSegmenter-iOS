//
//  ContentView.swift
//  DeeplabTrial
//
//  Created by Zikar Nurizky on 10/06/25.
//

import CoreML
import SwiftUI
import Vision


// Extension to convert UIImage to CVPixelBuffer
extension UIImage {
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}

// Helper function to convert the MLMultiArray to a UIImage mask
func createImageMask(from segmentationMap: MLMultiArray) -> UIImage? {
    let height = segmentationMap.shape[0].intValue
    let width = segmentationMap.shape[1].intValue

    // Create a color map for different classes
    // You can expand this with more colors for more classes
    let colorMap: [Int32: (UInt8, UInt8, UInt8)] = [
        0: (0, 0, 0),       // Background (black)
        15: (255, 0, 0)     // Person (red) - class 15 in DeepLabV3
        // Add other class indices and colors as needed
    ]
    
    // Create a buffer to hold the pixel data
    var pixelData = [UInt8](repeating: 0, count: width * height * 4)

    for y in 0..<height {
        for x in 0..<width {
            let index = y * width + x
            let classIndex = segmentationMap[index].int32Value
            
            // Get the color for the class, default to transparent if not in map
            let color = colorMap[classIndex] ?? (0, 0, 0)
            let alpha: UInt8 = (classIndex == 0) ? 0 : 255 // Make background transparent

            pixelData[index * 4] = color.0 // Red
            pixelData[index * 4 + 1] = color.1 // Green
            pixelData[index * 4 + 2] = color.2 // Blue
            pixelData[index * 4 + 3] = alpha // Alpha
        }
    }

    // Create a CGImage from the pixel data
    let bitsPerComponent = 8
    let bitsPerPixel = 32
    let bytesPerRow = 4 * width
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let provider = CGDataProvider(data: NSData(bytes: pixelData, length: pixelData.count)) else {
        return nil
    }
    
    guard let cgImage = CGImage(width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bitsPerPixel: bitsPerPixel,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                                provider: provider,
                                decode: nil,
                                shouldInterpolate: false,
                                intent: .defaultIntent) else {
        return nil
    }

    return UIImage(cgImage: cgImage)
}

struct ContentView: View {
    // State variables to hold our images
    @State private var originalImage: UIImage?
    @State private var maskImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            Text("Core ML Image Segmentation")
                .font(.largeTitle)

            // Display the original image
            if let image = originalImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .border(Color.gray)
            }

            // Display the resulting segmentation mask
            if let mask = maskImage {
                Image(uiImage: mask)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .border(Color.blue)
            } else {
                Text("Segmentation result will appear here.")
                    .italic()
            }

            Spacer()
        }
        .padding()
        .onAppear(perform: setupAndPerformSegmentation)
    }

    // We will add our logic function here
    private func setupAndPerformSegmentation() {
        originalImage = UIImage(named: "barrack")
        
        guard let image = originalImage else {
            print("Failed to load test image.")
            return
        }
        
        // Perform the segmentation on a background thread to avoid freezing the UI
        DispatchQueue.global(qos: .userInitiated).async {
            performSegmentation(on: image)
        }
    }

    private func performSegmentation(on image: UIImage) {
        do {
            // 1. Instantiate the model. Xcode generates this class for us.
            let model = try DeepLabV3(configuration: MLModelConfiguration())
            
            // 2. Prepare the model's input.
            // The model expects a CVPixelBuffer, so we need to convert our UIImage.
            guard let pixelBuffer = image.pixelBuffer(width: 513, height: 513) else {
                print("Failed to create pixel buffer.")
                return
            }
            let input = DeepLabV3Input(image: pixelBuffer)

            // 3. Make the prediction
            let output = try model.prediction(input: input)
            
            // 4. Process the output
            // The output is an MLMultiArray. We need to convert this into an image.
            let segmentationMask = output.semanticPredictions
            
            // We'll create a helper function for this complex conversion.
            let mask = createImageMask(from: segmentationMask)
            
            // 5. Update the UI on the main thread
            DispatchQueue.main.async {
                self.maskImage = mask
            }

        } catch {
            print("Error during segmentation: \(error)")
        }
    }
}



#Preview {
    ContentView()
}
