//
//  EditProxy.swift
//  Custom Blur
//
//  Created by Cal on 6/16/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

class EditProxy {
    
    let originalImage: UIImage
    var scale: CGFloat = 1.0
    var horizontalCrop: CGFloat = 1.0
    var verticalCrop: CGFloat = 1.0
    
    var processedImage: UIImage? {
        get{

            let cgImage = originalImage.cgImage!
            var width = CGFloat(cgImage.width)
            var height = CGFloat(cgImage.height)
            var processed: CGImage = cgImage
            
            //process horizontal crop
            if horizontalCrop != 1.0 {
                
                let edgeCropAmount = CGFloat(1.0 - horizontalCrop) * CGFloat(width)
                let croppedWidth = width - (edgeCropAmount) * 2.0
                if croppedWidth <= 0 { return nil }
                let croppedRect = CGRect(x: edgeCropAmount, y: 0, width: croppedWidth, height: height)
                processed = processed.cropping(to: croppedRect)!
                width = croppedWidth
                
            }
            
            //process vertical crop
            if verticalCrop != 1.0 {
                
                let edgeCropAmount = CGFloat(1.0 - verticalCrop) * CGFloat(height)
                let croppedHeight = height - (edgeCropAmount) * 2.0
                if croppedHeight <= 0 { return nil }
                let croppedRect = CGRect(x: 0, y: edgeCropAmount, width: width, height: croppedHeight)
                processed = processed.cropping(to: croppedRect)!
                height = croppedHeight
                
            }
            
            //process scaling
            if scale == 0.0 { return nil }
            if scale > 1.0 {
                
                //TODO: scale ugh
                
            }
            
            return UIImage(cgImage: processed, scale: 0.0, orientation: originalImage.imageOrientation)
        }
    }
    
    init(image: UIImage) {
        self.originalImage = image
    }
    
}
