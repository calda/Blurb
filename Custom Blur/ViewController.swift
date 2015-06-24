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
import iAd

let IBAppOpenedNotification = "com.cal.instablur.app-opened-notification"

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ADBannerViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var customBlur: UIImageView!
    @IBOutlet weak var customBlurTop: NSLayoutConstraint!
    @IBOutlet weak var blurBackground: UIView!
    @IBOutlet weak var backgroundAlphaSlider: UISlider!
    @IBOutlet weak var blur: UIVisualEffectView!
    @IBOutlet weak var statusBarHeight: NSLayoutConstraint!
    @IBOutlet weak var backLeading: NSLayoutConstraint!
    @IBOutlet weak var downloadTrailing: NSLayoutConstraint!
    @IBOutlet weak var controlsHeight: NSLayoutConstraint!
    @IBOutlet weak var controlsPosition: NSLayoutConstraint!
    @IBOutlet weak var controlsScrollView: UIScrollView!
    @IBOutlet weak var controlsSuperview: UIView!
    var transitionImage: UIImageView!
    var transitionView: UIView!
    
    var imageManager = PHImageManager()
    var fetch: PHFetchResult?
    
    var hideStatusBar = false {
        didSet {
            UIView.animateWithDuration(0.3, animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return hideStatusBar
    }
    
    //pragma MARK: - Managing the blur customization
    //manage the image and the radius
    
    var foregroundEdit: EditProxy?
    var backgroundHue: CGFloat = -1.0
    
    func updateForegroundImage() {
        let processedImage = foregroundEdit?.processedImage
        self.transitionImage.image = processedImage
        
        let scale = foregroundEdit!.scale
        transitionImage.transform = CGAffineTransformMakeScale(scale, scale)
    }
    
    var selectedImage: UIImage? {
        didSet {
            downsampled = nil
            if let selectedImage = selectedImage {
                foregroundEdit = EditProxy(image: selectedImage)
                applyBlurWithSettings(animate: true)
            }
            else {
                foregroundEdit = nil
            }
            
        }
    }
    var downsampled: UIImage? //the selected image downsampled
    
    var currentBlurRadius: CGFloat = 10.0 {
        didSet{
            applyBlurWithSettings(animate: false)
        }
    }
    
    var FORCE_ANIMATION_FOR_BLUR_CALCULATION = false
    
    func applyBlurWithSettings(animate animate: Bool) {
        guard let selectedImage = selectedImage else { return }
        
        //downsample to improve calculation times
        if downsampled == nil {
            var downsampleSize = CGSizeZero
            let originalSize = selectedImage.size
            let scale = UIScreen.mainScreen().scale
            
            //must be atleast the size of the customBlur view
            if originalSize.width == originalSize.height {
                downsampleSize = customBlur.frame.size
            }
            else if originalSize.width < originalSize.height {
                let downWidth = customBlur.frame.width
                let proportion = downWidth / originalSize.width
                let downHeight = proportion * originalSize.height
                downsampleSize = CGSizeMake(downWidth * scale, downHeight * scale)
            }
            else if originalSize.width > originalSize.height {
                let downHeight = customBlur.frame.height
                let proportion = downHeight / originalSize.height
                let downWidth = proportion * originalSize.width
                downsampleSize = CGSizeMake(downWidth * scale, downHeight * scale)
            }
            
            UIGraphicsBeginImageContextWithOptions(downsampleSize, false, 1.0)
            selectedImage.drawInRect(CGRect(origin: CGPointZero, size: downsampleSize))
            downsampled = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            //fix orientation
            let cgImage = downsampled!.CGImage
            downsampled = UIImage(CGImage: cgImage!, scale: 0.0, orientation: selectedImage.imageOrientation)
        }
        
        let ciImage = CIImage(CGImage: downsampled!.CGImage!)
        
        
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
        
        if FORCE_ANIMATION_FOR_BLUR_CALCULATION {
            FORCE_ANIMATION_FOR_BLUR_CALCULATION = false
            self.playFadeTransitionForImage(self.customBlur, duration: 0.25)
        }
        
        
        
    }
    
    
    //pragma MARK: - Managing the view itself
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handlePhotosAuth", name: IBAppOpenedNotification, object: nil)
    }
    
    var sliderDefaults: [UISlider : Float] = [:]
    var sentToSettings = false
    
    override func viewWillAppear(animated: Bool) {
        
        //handlePhotosAuth()
        //don't call the auth here because it will always be called through
        //the notification from the AppDelegate
        
        //update controls position
        let unavailableHeight = CGFloat(44.0 + self.view.frame.width)
        controlsHeight.constant = self.view.frame.height - unavailableHeight
        controlsPosition.constant = -controlsHeight.constant
        self.view.layoutIfNeeded()
        
        //save slider default positions
        for subview in controlsSuperview.subviews {
            if let slider = subview as? UISlider {
                let defaultValue = slider.value
                sliderDefaults.updateValue(defaultValue, forKey: slider)
            }
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
        
        //animate visible cells
        for cell in collectionView.visibleCells() as! [ImageCell] {
            let index = collectionView.indexPathForCell(cell)!.item
            let row = Int(index / 3)
            let delay: Double = Double(row) * 0.2
            cell.playLaunchAnimation(delay)
        }
    }
    
    func handlePhotosAuth() {
        
        func theyPulledADickMoveAndDeniedPermissions() {
            delay(0.5) {
                //create an alert to send the user to settings
                let alert = UIAlertController(title: "You denied access to the camera roll.", message: "That's kinda important for a Photo app. It's not hard to fix though!", preferredStyle: UIAlertControllerStyle.Alert)
                
                let okAction = UIAlertAction(title: "Nevermind", style: UIAlertActionStyle.Destructive, handler: nil)
                let fixAction = UIAlertAction(title: "Go to Settings", style: .Default, handler: { action in
                    self.sentToSettings = true
                    UIApplication.sharedApplication().openURL(NSURL(string:UIApplicationOpenSettingsURLString)!)
                })
                
                alert.addAction(okAction)
                alert.addAction(fixAction)
                
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }
        
        
        let authorization = PHPhotoLibrary.authorizationStatus()
        if authorization == PHAuthorizationStatus.NotDetermined {
            PHPhotoLibrary.requestAuthorization() { status in
                if status == PHAuthorizationStatus.Authorized {
                    dispatch_sync(dispatch_get_main_queue(), {
                        self.displayThumbnails()
                    })
                } else {
                    theyPulledADickMoveAndDeniedPermissions()
                }
            }
        }
        else if authorization == PHAuthorizationStatus.Authorized || sentToSettings {
            self.displayThumbnails()
        } else {
            theyPulledADickMoveAndDeniedPermissions()
        }
    }
    
    func displayThumbnails() {
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetch = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: options)
        
        if fetch == nil || fetch?.count == 0  {
            //no permissions
            let alert = UIAlertController(title: "There was a problem loading your pictures.", message: "This just happens sometimes. Sorry. Restart the app through the app switcher (double-tap the home button) and then launch the app again.", preferredStyle: .Alert)
            self.presentViewController(alert, animated: true, completion: nil)
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
                    self.currentBlurRadius = 0.008 * self.customBlur.frame.width
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
                
                //create the transition image
                self.transitionImage = UIImageView(frame: startFrame)
                self.transitionImage.image = selectedCell.bottom.image!
                self.transitionImage.contentMode = .ScaleAspectFit
                
                //mask transition image to square
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
                self.transitionImage.layer.mask = maskLayer
                
                //animate to full screen with blur
                let endFrame = CGRectMake(0.0, 44.0, self.view.frame.width, self.view.frame.width)
                let duration: Double = 0.3
                
                //create the transition view
                self.transitionView = UIImageView(frame: self.view.frame)
                self.transitionView.addSubview(self.transitionImage)
                self.view.addSubview(self.transitionView)
                
                //do non animated view prep
                self.hideStatusBar = true
                self.blurBackground.backgroundColor = UIColor.whiteColor()

                //animate views
                UIView.animateWithDuration(duration, animations: {

                        self.transitionImage.frame = endFrame
                        self.blur.alpha = 1.0
                        self.customBlur.alpha = 1.0
                        self.blurBackground.alpha = 1.0
                        self.statusBarHeight.constant = 44
                        self.backLeading.constant = 8
                        self.downloadTrailing.constant = 8
                        self.controlsPosition.constant = 0.0
                        self.view.layoutIfNeeded()
                    
                    }, completion: { success in
                
                        if let lateArrivalImage = lateArrivalImage {
                            self.transitionImage.image = lateArrivalImage
                            self.playFadeTransitionForImage(self.transitionImage, duration: 0.25)
                            
                            delay(0.25) {
                                self.FORCE_ANIMATION_FOR_BLUR_CALCULATION = true
                                self.selectedImage = lateArrivalImage
                            }
                            
                            delay(0.5) {
                                self.blurBackground.backgroundColor = UIColor.redColor()
                            }
                        }
                        
                        //add mask to transition view
                        let maskPath = CGPathCreateWithRect(endFrame, nil)
                        let maskLayer = CAShapeLayer()
                        maskLayer.path = maskPath
                        self.transitionView.layer.mask = maskLayer
                        
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
        
        if transitionView == nil { return }
        
        let offScreenOrigin = CGPointMake(0, -customBlur.frame.height * 1.2)
        self.hideStatusBar = false
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.transitionImage.frame.origin = offScreenOrigin
            self.transitionImage.alpha = 0.0
            self.customBlurTop.constant = offScreenOrigin.y
            self.blurBackground.alpha = 0.0
            self.statusBarHeight.constant = 20.0
            self.backLeading.constant = -90.0
            self.downloadTrailing.constant = -30.0
            self.controlsPosition.constant = -self.controlsHeight.constant
            self.view.layoutIfNeeded()
            self.blur.alpha = 0.0
            
        }, completion: { success in
            self.collectionView.userInteractionEnabled = true
            self.transitionImage.removeFromSuperview()
            self.transitionView.removeFromSuperview()
            self.transitionImage = nil
            self.transitionView = nil
            self.customBlurTop.constant = 0
            self.customBlur.alpha = 0.0
            self.customBlur.image = nil
            self.selectedImage = nil
            self.downsampled = nil
            self.view.layoutIfNeeded()
            
            //set all sliders back to their default value
            for (slider, defaultValue) in self.sliderDefaults {
                slider.value = defaultValue
            }
            //set scroll view to top too
            self.controlsScrollView.contentOffset = CGPointZero
        })
        
    }
    
    var previousCommitedSlider: CGFloat = 0.0
    @IBAction func blurChanged(sender: UISlider) {
        let slider = CGFloat(sender.value)
        
        //blur radius is a proportion of the shortest side of the image.
        //the shortest size of the downsampled image is the width of the customBlur
        //because of the way the image was downsampled
        //slider has range [0,0.04]
        let shortest = customBlur.frame.width
        let newBlurRadius = slider * shortest
        
        //print("\(slider)  >>//(\(shortest))//==  \(newBlurRadius)")
        
        if slider >= previousCommitedSlider + 0.00132 || slider <= previousCommitedSlider - 0.00132 || slider == 0.0 {
                self.currentBlurRadius = newBlurRadius
            previousCommitedSlider = slider
        }
    }
    
    @IBAction func blurAlphaChanged(sender: UISlider) {
        let slider = CGFloat(sender.value)
        customBlur.alpha = slider
    }
    
    @IBAction func blurBackgroundHueChanged(sender: UISlider) {
        let slider = CGFloat(sender.value)
        
        if backgroundHue == -1 && previousCommitedSlider < 0.034 {
            //make sure the user is aware that this is affecting color
            UIView.animateWithDuration(0.85, animations: {
                self.backgroundAlphaSlider.setValue(0.85, animated: true)
                self.customBlur.alpha = 0.75
            })
        }
        
        backgroundHue = slider
        var newColor = UIColor(hue: backgroundHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        
        if backgroundHue > 1.0 && backgroundHue < 1.1 {
            newColor = UIColor.whiteColor()
        } else if backgroundHue > 1.1 {
            newColor = UIColor.blackColor()
        }
        
        blurBackground.backgroundColor = newColor
    }
    
    
    
    @IBAction func scaleChanged(sender: UISlider) {
        foregroundEdit?.scale = CGFloat(sender.value)
        updateForegroundImage()
    }
    
    @IBAction func horizontalCropChanged(sender: UISlider) {
        foregroundEdit?.horizontalCrop = -CGFloat(sender.value)
        updateForegroundImage()
    }

    @IBAction func verticalCropChanged(sender: UISlider) {
        foregroundEdit?.verticalCrop = -CGFloat(sender.value)
        updateForegroundImage()
    }

    @IBAction func yPositionChanged(sender: UISlider) {
        let slider = CGFloat(sender.value)
        let height = transitionImage.frame.height
        let yPosition = height * slider
        //TODO: re-implement position
    }
    
    @IBAction func xPositionChanged(sender: UISlider) {
        let slider = CGFloat(sender.value)
        let width = transitionImage.frame.width
        let xPosition = width * slider
    }
    
    //pragma MARK: - iAd Delegate Functions
    
    @IBOutlet weak var adPosition: NSLayoutConstraint!
    
    func bannerViewDidLoadAd(banner: ADBannerView!) {
        
        //do not show ad if 4S (aspect != 9:16) (9/16 = 0.5625)
        let aspect = self.view.frame.width / self.view.frame.height
        if aspect > 0.6 || aspect < 0.5 {
            banner.hidden = true
            return
        }
        
        if adPosition.constant != 0.0 {
            adPosition.constant = 0
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                    self.view.layoutIfNeeded()
                    self.collectionView.contentInset = UIEdgeInsets(top: 20.0, left: 0.0, bottom: banner.frame.height, right: 0.0)
            }, completion: nil)
        }
    }
    
    func bannerView(banner: ADBannerView!, didFailToReceiveAdWithError error: NSError!) {
        if adPosition.constant != -banner.frame.height {
            adPosition.constant = -banner.frame.height
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                self.view.layoutIfNeeded()
                self.collectionView.contentInset = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0)
            }, completion: nil)
        }
    }
    
    
    //pragma MARK: - Export (ugh)
    
    @IBAction func downloadButtonPressed(sender: AnyObject) {
        exportToCameraRoll()
    }
    
    func createImage() -> UIImage? {
        
        //
        //UIGraphicsBeginImageContext(CGSizeMake(2000, 2000))
        //let context = UIGraphicsGetCurrentContext()
        
        
        /*
        let context = UIGraphicsGetCurrentContext()
        
        let color: UIColor
        if let background = self.labelContainer.backgroundColor {
            color = background
        } else {
            color = UIColor.whiteColor()
        }
        
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, size)
        CGContextSetAllowsAntialiasing(context, true)
        CGContextSetShouldAntialias(context, true)
        //CGContextSetShouldSmoothFonts(context, true)
        
        let font = UIFont.systemFontOfSize(350.0)
        let emoji = emojiDisplay.text! as NSString
        let attributes = [NSFontAttributeName : font as AnyObject]
        let drawSize = emoji.boundingRectWithSize(size.size, options: .UsesLineFragmentOrigin, attributes: attributes, context: NSStringDrawingContext()).size
        
        let xOffset = (size.width - drawSize.width) / 2
        let yOffset = (size.height - drawSize.height) / 2
        let drawPoint = CGPointMake(xOffset, yOffset)
        let drawRect = CGRect(origin: drawPoint, size: drawSize)
        emoji.drawInRect(CGRectIntegral(drawRect), withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()*/
        return nil
        
    }
    
    func exportToCameraRoll() {
        
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

