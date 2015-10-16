//
//  PeekViewController.swift
//  Custom Blur
//
//  Created by Cal on 10/16/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import Foundation
import UIKit
import Photos

class PeekViewController : UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var indexPath: NSIndexPath?
    var collectionView: UICollectionView?
    
    func decorateWithAsset(asset: PHAsset) {
        PHImageManager().requestImageForAsset(asset, targetSize: self.view.frame.size, contentMode: PHImageContentMode.AspectFill, options: nil, resultHandler: { result, info in
            
            if let result = result {
                self.imageView.image = result
            }
            
        })
    }
    
    @available(iOS 9.0, *)
    override func previewActionItems() -> [UIPreviewActionItem] {
        let item = UIPreviewAction(title: "Edit", style: .Default, handler: { _ in
            self.pop()
        })
        
        return [item]
    }
    
    func pop() {
        guard let indexPath = self.indexPath else { return }
        guard let collectionView = self.collectionView else { return }
        collectionView.delegate?.collectionView?(collectionView, didSelectItemAtIndexPath: indexPath)
    }
    
}