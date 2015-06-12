//
//  ViewController.swift
//  Custom Blur
//
//  Created by Cal on 6/10/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import UIKit
import Photos
import Foundation

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var customBlur: UIImageView!
    @IBOutlet weak var customBlurTop: NSLayoutConstraint!
    @IBOutlet weak var blur: UIVisualEffectView!
    @IBOutlet weak var statusBarHeight: NSLayoutConstraint!
    @IBOutlet weak var backLeading: NSLayoutConstraint!
    @IBOutlet weak var downloadTrailing: NSLayoutConstraint!
    var transitionView: UIImageView!
    
    
    var imageManager = PHImageManager()
    var fetch: PHFetchResult?
    
    //pragma MARK: - Managing the blur customization
    //manage the image and the radius
    var selectedImage: UIImage? {
        didSet {
            applyBlurWithSettings()
        }
    }
    var currentBlurRadius: CGFloat = 10.0 {
        didSet{
            applyBlurWithSettings()
        }
    }
    
    func applyBlurWithSettings() {
        guard let selectedImage = selectedImage else { return }
        
        //apply blur to the selected image
        let ciImage = CIImage(CGImage: selectedImage.CGImage!)
        
        let gaussian = CIFilter(name: "CIGaussianBlur")!
        gaussian.setDefaults()
        gaussian.setValue(ciImage, forKey: kCIInputImageKey)
        gaussian.setValue(currentBlurRadius, forKey: kCIInputRadiusKey)
        
        let filterOutput = gaussian.outputImage
        //bring CIImage back down to UIImage
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(filterOutput, fromRect: ciImage.extent)
        let blurredImage = UIImage(CGImage: cgImage)
        
        var animate = false
        if customBlur.image != nil { animate = true }
        customBlur.image = blurredImage
        
        if animate {
            self.playFadeTransitionForImage(customBlur, duration: 0.5)
        }
        
    }
    
    
    //pragma MARK: - Managing the view itself
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        
        let authorization = PHPhotoLibrary.authorizationStatus()
        if authorization == PHAuthorizationStatus.NotDetermined {
            PHPhotoLibrary.requestAuthorization() { status in
                if status == PHAuthorizationStatus.Authorized {
                    self.displayThumbnails()
                }
            }
        }
        else {
            self.displayThumbnails()
        }
        
    }
    
    override func viewDidAppear(animated: Bool) {
        //scale up custom blur but mask to original bounds
        let originalFrame = customBlur.frame
        customBlur.transform = CGAffineTransformScale(customBlur.transform, 1.2, 1.2)
        
        let maskFrame = customBlur.convertRect(originalFrame, fromView: customBlur.superview!)
        let maskPath = CGPathCreateWithRect(maskFrame, nil)
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath
        customBlur.layer.mask = maskLayer
    }
    
    func displayThumbnails() {
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetch = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: options)
        
        if fetch == nil {
            //no permissions
        }
        
        collectionView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 0.0, 0.0)
        collectionView.reloadData()
        customBlur.layer.masksToBounds = true
    }
    
    //pragma MARK: - Managing the Collection View
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let fetch = fetch else { return 0 }
        return fetch.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("image", forIndexPath: indexPath) as! ImageCell
        
        guard let fetch = fetch else { return cell }
        
        //get thumbnail for cell
        guard let asset = fetch[indexPath.item] as? PHAsset else { return cell }
        
        let collectionWidth = collectionView.frame.width
        let cellWidth = (collectionWidth - 2.0) / 3.0
        let cellSize = CGSizeMake(cellWidth, cellWidth)
        
        imageManager.requestImageForAsset(asset, targetSize: cellSize, contentMode: PHImageContentMode.AspectFill, options: nil, resultHandler: { result, info in
        
            if let result = result {
                cell.decorate(result)
            }
            
        })
        return cell
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1.0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1.0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let width = collectionView.frame.width - 2.0
        let count = CGFloat(3.0)
        let cellWidth = width / count
        return CGSizeMake(cellWidth, cellWidth)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        collectionView.userInteractionEnabled = false
        
        guard let fetch = fetch else { return }
        
        //get full sized image
        guard let asset = fetch[indexPath.item] as? PHAsset else { return }
        var requestedImageCount = 0
        var lateArrivalImage: UIImage?
        
        imageManager.requestImageForAsset(asset, targetSize: self.view.frame.size, contentMode: PHImageContentMode.AspectFill, options: nil, resultHandler: { result, info in
            
            if let result = result {
                
                //any time other than the first time should only update the image, not start a new animation
                requestedImageCount++
                if requestedImageCount > 1 {
                    self.selectedImage = lateArrivalImage
                    lateArrivalImage = result
                    return
                }
                
                //position animated view on top of selected cell
                guard let selectedCell = self.findOnScreenCellWithIndex(indexPath) else { return }
                let imageSize = result.size
                
                //convert selected cell origin to point in root view
                let convertedOrigin = self.view.convertPoint(selectedCell.frame.origin, fromView: selectedCell.superview!)
                let startFrame: CGRect
                let startWidth: CGFloat
                let startHeight: CGFloat
                
                if imageSize.height >= imageSize.width { //image is tall
                    startWidth = selectedCell.frame.width
                    startHeight = (startWidth / imageSize.width) * imageSize.height
                    let startX = convertedOrigin.x
                    let startY = convertedOrigin.y - (startHeight - selectedCell.frame.height) / 2.0
                    startFrame = CGRectMake(startX, startY, startWidth, startHeight)
                }
                else { //image is wide
                    startHeight = selectedCell.frame.height
                    startWidth = (startHeight / imageSize.height) * imageSize.width
                    let startX = convertedOrigin.x - (startWidth - selectedCell.frame.width) / 2.0
                    let startY = convertedOrigin.y
                    startFrame = CGRectMake(startX, startY, startWidth, startHeight)
                }
                
                
                //create the transition view
                self.transitionView = UIImageView(frame: startFrame)
                self.transitionView.image = selectedCell.bottom.image!
                self.selectedImage = selectedCell.bottom.image!
                self.transitionView.contentMode = .ScaleAspectFit
                self.view.addSubview(self.transitionView)
                
                //mask transition view to square
                let maskRect: CGRect
                
                if imageSize.height >= imageSize.width { //image is tall
                    let maskY = (startHeight - startWidth) / 2.0
                    maskRect = CGRectMake(0.0, maskY, startWidth, startWidth)
                }
                else { //image is wide
                    let maskX = (startWidth - startHeight) / 2.0
                    maskRect = CGRectMake(maskX, 0.0, startHeight, startHeight)
                }
                
                let maskPath = CGPathCreateWithRect(maskRect, nil)
                let maskLayer = CAShapeLayer()
                maskLayer.path = maskPath
                self.transitionView.layer.mask = maskLayer
                
                //animate to full screen with blur
                let endFrame = CGRectMake(0.0, 64.0, self.view.frame.width, self.view.frame.width)
                let duration: Double = 0.3
                
                UIView.animateWithDuration(duration, animations: {

                        self.transitionView.frame = endFrame
                        self.blur.alpha = 1.0
                        self.customBlur.alpha = 1.0
                        self.statusBarHeight.constant = 64
                        self.backLeading.constant = 8
                        self.downloadTrailing.constant = 8
                        self.view.layoutIfNeeded()
                    
                    }, completion: { success in
                
                        if let lateArrivalImage = lateArrivalImage {
                            self.transitionView.image = lateArrivalImage
                            self.playFadeTransitionForImage(self.transitionView, duration: 0.25)
                        }
                        
                })
                
                //animate away mask
                let animation = CABasicAnimation(keyPath: "path")
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
                animation.duration = duration / 2.0
                let fullRect = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height)
                let fullPath = CGPathCreateWithRect(fullRect, nil)
                animation.fromValue = maskPath
                animation.toValue = fullPath
                animation.removedOnCompletion = false
                animation.fillMode = kCAFillModeForwards
                maskLayer.addAnimation(animation, forKey: "path")
            }
            
        })
        
    }
    
    func findOnScreenCellWithIndex(index: NSIndexPath) -> ImageCell? {
        for cell in collectionView.visibleCells() {
            if let cell = cell as? ImageCell where collectionView.indexPathForCell(cell) == index {
                return cell
            }
        }
        return nil
    }
    
    func playFadeTransitionForImage(imageView: UIImageView, duration: Double) {
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionFade
        imageView.layer.addAnimation(transition, forKey: nil)
    }
    
    //pragma MARK: - Editor Functions
    
    @IBAction func backButtonPressed(sender: AnyObject) {
        
        let offScreenOrigin = CGPointMake(0, -transitionView.frame.height * 1.2)
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.transitionView.frame.origin = offScreenOrigin
            self.customBlurTop.constant = offScreenOrigin.y
            self.statusBarHeight.constant = 20.0
            self.backLeading.constant = -90.0
            self.downloadTrailing.constant = -30.0
            self.view.layoutIfNeeded()
            self.blur.alpha = 0.0
            
        }, completion: { success in
            self.collectionView.userInteractionEnabled = true
            self.transitionView.removeFromSuperview()
            self.transitionView = nil
            self.customBlurTop.constant = 0
            self.customBlur.alpha = 0.0
            self.customBlur.image = nil
            self.view.layoutIfNeeded()
        })
        
    }
    
    @IBAction func downloadButtonPressed(sender: AnyObject) {
    }
    

}

class ImageCell : UICollectionViewCell {
    
    @IBOutlet weak var bottom: UIImageView!
    
    func decorate(image: UIImage) {
        bottom.image = image
    }
    
    
}

