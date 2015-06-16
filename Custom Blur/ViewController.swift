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

let imageThread = dispatch_queue_create("image thread", DISPATCH_QUEUE_SERIAL)

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var customBlur: UIImageView!
    @IBOutlet weak var customBlurTop: NSLayoutConstraint!
    @IBOutlet weak var blur: UIVisualEffectView!
    @IBOutlet weak var statusBarHeight: NSLayoutConstraint!
    @IBOutlet weak var backLeading: NSLayoutConstraint!
    @IBOutlet weak var downloadTrailing: NSLayoutConstraint!
    @IBOutlet weak var controlsHeight: NSLayoutConstraint!
    @IBOutlet weak var controlsPosition: NSLayoutConstraint!
    var transitionView: UIImageView!
    
    var imageManager = PHImageManager()
    var fetch: PHFetchResult?
    
    //pragma MARK: - Managing the blur customization
    //manage the image and the radius
    var foregroundEdit: EditProxy?
    
    func updateForegroundImage() {
        let processedImage = foregroundEdit?.processedImage
        self.transitionView.image = processedImage
        
        guard let processed = processedImage else { return }
        
        //scale must be handled delicately.
        //if scale is less than one, adjust the transform
        let scale = processed.scale
        if scale < 1.0 {
            transitionView.transform = CGAffineTransformMakeScale(scale, scale)
        } else {
            transitionView.transform = CGAffineTransformIdentity
        }
        
        
    }
    
    var selectedImage: UIImage? {
        didSet {
            if let selectedImage = selectedImage {
                foregroundEdit = EditProxy(image: selectedImage)
                applyBlurWithSettings(animate: true)
            }
            else {
                foregroundEdit = nil
            }
            
        }
    }
    
    var currentBlurRadius: CGFloat = 10.0 {
        didSet{
            applyBlurWithSettings(animate: false)
        }
    }
    
    func applyBlurWithSettings(animate animate: Bool) {
        
        guard let selectedImage = selectedImage else { return }
        
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
        
        self.customBlur.image = blurredImage
        
        if animate {
            self.playFadeTransitionForImage(self.customBlur, duration: 0.5)
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
        
        //update controls position
        let unavailableHeight = CGFloat(64.0 + self.view.frame.width)
        controlsHeight.constant = self.view.frame.height - unavailableHeight
        controlsPosition.constant = -controlsHeight.constant
        self.view.layoutIfNeeded()
        
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
        
        //animate visible cells
        for cell in collectionView.visibleCells() as! [ImageCell] {
            let index = collectionView.indexPathForCell(cell)!.item
            let row = Int(index / 3)
            let delay: Double = Double(row) * 0.2
            cell.playLaunchAnimation(delay)
        }
    }
    
    func displayThumbnails() {
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetch = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: options)
        
        if fetch == nil {
            //no permissions
        }
        
        collectionView.contentInset = UIEdgeInsetsMake(20.0, 0.0, 0.0, 0.0)
        collectionView.scrollIndicatorInsets = collectionView.contentInset
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
                    lateArrivalImage = result
                    self.selectedImage = lateArrivalImage
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
                        self.controlsPosition.constant = 0.0
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
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        transition.type = kCATransitionFade
        imageView.layer.addAnimation(transition, forKey: nil)
    }
    
    //pragma MARK: - Editor Functions
    
    @IBAction func backButtonPressed(sender: AnyObject) {
        
        let offScreenOrigin = CGPointMake(0, -customBlur.frame.height * 1.2)
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.transitionView.frame.origin = offScreenOrigin
            self.transitionView.alpha = 0.0
            self.customBlurTop.constant = offScreenOrigin.y
            self.statusBarHeight.constant = 20.0
            self.backLeading.constant = -90.0
            self.downloadTrailing.constant = -30.0
            self.controlsPosition.constant = -self.controlsHeight.constant
            self.view.layoutIfNeeded()
            self.blur.alpha = 0.0
            
        }, completion: { success in
            self.collectionView.userInteractionEnabled = true
            self.transitionView.removeFromSuperview()
            self.transitionView = nil
            self.customBlurTop.constant = 0
            self.customBlur.alpha = 0.0
            self.customBlur.image = nil
            self.selectedImage = nil
            self.view.layoutIfNeeded()
        })
        
    }
    
    @IBAction func downloadButtonPressed(sender: AnyObject) {
    }
    
    @IBAction func blurChanged(sender: UISlider) {
        // y = 0.012x^2
        // where x is slider value and y is blur amoung
        let slider = CGFloat(sender.value)
        if slider >= self.currentBlurRadius + 2 || slider <= self.currentBlurRadius - 2 {
            
            //dispatch_sync(imageThread, {
                
                self.currentBlurRadius = CGFloat(slider)
                
            //})
            
        }
        //let blurAmount = CGFloat(0.012 * pow(slider, 2)) + 1.0
    }
    
    @IBAction func scaleChanged(sender: UISlider) {
        foregroundEdit?.scale = CGFloat(sender.value)
        updateForegroundImage()
    }
    
    @IBAction func horizontalCropChanged(sender: UISlider) {
        foregroundEdit?.horizontalCrop = CGFloat(sender.value)
        updateForegroundImage()
    }

    @IBAction func verticalCropChanged(sender: UISlider) {
        foregroundEdit?.verticalCrop = CGFloat(sender.value)
        updateForegroundImage()
    }
}

class ImageCell : UICollectionViewCell {
    
    @IBOutlet weak var bottom: UIImageView!
    
    func decorate(image: UIImage) {
        bottom.image = image
    }
    
    func playLaunchAnimation(delay: Double) {
        
        self.transform = CGAffineTransformMakeScale(0.75, 0.75)
        self.bottom.alpha = 0.0
        
        UIView.animateWithDuration(0.5 + delay, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                self.transform = CGAffineTransformMakeScale(1.0, 1.0)
                self.bottom.alpha = 1.0
            }, completion: nil)
        
    }
    
    
}

