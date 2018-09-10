//
//  CCPhotoRenderer.swift
//  CCCamera
//
//  Created by cyd on 2018/9/7.
//  Copyright © 2018 cyd. All rights reserved.
//

import CoreMedia
import CoreVideo
import CoreImage

class CCPhotoRenderer: CCFilterRenderer {

    var description: String {
        switch name {
        case "CIPhotoEffectChrome":
            return name + "(铬黄)"
        case "CIPhotoEffectFade":
            return name + "(褪色)"
        case "CIPhotoEffectInstant":
            return name + "(怀旧)"
        case "CIPhotoEffectMono":
            return name + "(单色)"
        case "CIPhotoEffectNoir":
            return name + "(黑白)"
        case "CIPhotoEffectProcess":
            return name + "(冲印)"
        case "CIPhotoEffectTonal":
            return name + "(色调)"
        case "CIPhotoEffectTransfer":
            return name + "(岁月)"
        default:
            return name
        }
    }

    var isPrepared = false

    private var name: String = ""

    private var ciContext: CIContext?

    private var rosyFilter: CIFilter?

    private var outputColorSpace: CGColorSpace?

    private var outputPixelBufferPool: CVPixelBufferPool?

    private(set) var onputFormatDescription: CMFormatDescription?

    private(set) var inputFormatDescription: CMFormatDescription?

    required init(_ name: String) {
        self.name = name
    }

    func prepare(with formatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        reset()

        (outputPixelBufferPool, outputColorSpace, onputFormatDescription) = allocateOutputBufferPool(with: formatDescription,
                                                             outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        if outputPixelBufferPool == nil {
            return
        }
        inputFormatDescription = formatDescription

        ciContext  = CIContext()
        rosyFilter = CIFilter(name: self.name)
        isPrepared = true
    }

    func reset() {
        ciContext  = nil
        rosyFilter = nil
        isPrepared = false
        outputColorSpace = nil
        outputPixelBufferPool  = nil
        onputFormatDescription = nil
        inputFormatDescription = nil
    }

    func render(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard let rosyFilter = rosyFilter, let ciContext = ciContext, isPrepared else {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }

        let sourceImage = CIImage(cvImageBuffer: pixelBuffer)
        rosyFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        guard let filteredImage = rosyFilter.value(forKey: kCIOutputImageKey) as? CIImage else {
            print("CIFilter failed to render image")
            return nil
        }

        var pbuf: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &pbuf)
        guard let outputPixelBuffer = pbuf else {
            print("Allocation failure")
            return nil
        }

        ciContext.render(filteredImage, to: outputPixelBuffer, bounds: filteredImage.extent, colorSpace: outputColorSpace)
        return outputPixelBuffer
    }
}
