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
let backgroundQueue = dispatch_queue_create("image rendering", DISPATCH_QUEUE_CONCURRENT)

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ADBannerViewDelegate, UIGestureRecognizerDelegate, UIViewControllerPreviewingDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var customBlur: UIImageView!
    @IBOutlet weak var customBlurTop: NSLayoutConstraint!
    @IBOutlet weak var blurBackground: UIView!
    @IBOutlet weak var backgroundAlphaSlider: UISlider!
    @IBOutlet weak var backgroundTintSlider: UISlider!
    @IBOutlet weak var ySlider: UISlider!
    @IBOutlet weak var xSlider: UISlider!
    @IBOutlet weak var centerImageButton: UIButton!
    @IBOutlet weak var scaleSlider: UISlider!
    @IBOutlet weak var blur: UIVisualEffectView!
    @IBOutlet weak var statusBarHeight: NSLayoutConstraint!
    @IBOutlet weak var backLeading: NSLayoutConstraint!
    @IBOutlet weak var downloadTrailing: NSLayoutConstraint!
    @IBOutlet weak var controlsHeight: NSLayoutConstraint!
    @IBOutlet weak var controlsPosition: NSLayoutConstraint!
    @IBOutlet weak var controlsScrollView: UIScrollView!
    @IBOutlet weak var controlsSuperview: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var indicatorPosition: NSLayoutConstraint!
    @IBOutlet weak var exportGray: UIView!
    var shareSheetOpen = false
    @IBOutlet weak var shareSheetPosition: NSLayoutConstraint!
    @IBOutlet weak var shareContainer: UIView!
    @IBOutlet weak var statusBarBlur: UIVisualEffectView!
    @IBOutlet weak var statusBarDark: UIVisualEffectView!
    @IBOutlet weak var statusBarDarkHeight: NSLayoutConstraint!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var bannerView: ADBannerView!
    
    var transitionImage: UIImageView!
    var translationView: UIImageView!
    var transitionView: UIImageView!
    var changesMade = false
    
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
    var downsampledScale: CGFloat? // the scale of the downsampling
    
    var currentBlurRadius: CGFloat = 10.0 {
        didSet{
            applyBlurWithSettings(animate: false)
        }
    }
    
    var FORCE_ANIMATION_FOR_BLUR_CALCULATION = false
    
    func applyBlurWithSettings(animate animate: Bool) {
        
        let selectedImage: UIImage
        if self.selectedImage != nil {
            selectedImage = self.selectedImage!
        } else { return }
        
        let downsampleScale: CGFloat
        if currentBlurRadius < 3.0 { downsampleScale = 1.0 }
        else if currentBlurRadius < 7.0 { downsampleScale = 3.0 }
        else { downsampleScale = 5.0 }
        
        //downsample to improve calculation times
        if downsampled == nil || downsampleScale != downsampledScale {
            var downsampleSize = CGSizeZero
            let originalSize = selectedImage.size
            let scale = UIScreen.mainScreen().scale / downsampleScale
            
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
            downsampledScale = downsampleScale
        }
        
        self.customBlur.image = blurImage(downsampled!, withRadius: self.currentBlurRadius / (downsampleScale))
        
        if animate {
            self.playFadeTransitionForView(self.customBlur, duration: 0.5)
        }
        
        if FORCE_ANIMATION_FOR_BLUR_CALCULATION {
            FORCE_ANIMATION_FOR_BLUR_CALCULATION = false
            self.playFadeTransitionForView(self.customBlur, duration: 0.25)
        }
    }
    
    func blurImage(image: UIImage, withRadius: CGFloat) -> UIImage {
        let ciImage = CIImage(CGImage: image.CGImage!)
        
        let gaussian = CIFilter(name: "CIGaussianBlur")!
        gaussian.setDefaults()
        gaussian.setValue(ciImage, forKey: kCIInputImageKey)
        gaussian.setValue(withRadius, forKey: kCIInputRadiusKey)
        
        let filterOutput = gaussian.outputImage
        //bring CIImage back down to UIImage
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(filterOutput!, fromRect: ciImage.extent)
        return UIImage(CGImage: cgImage)
    }
    
    
    //pragma MARK: - Managing the view itself
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handlePhotosAuth", name: IBAppOpenedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "closeShareSheet", name: IBCloseShareSheetNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "statusBarTapped", name: IBStatusBarTappedNotification, object: nil)
        
        //handlePhotosAuth()
        //don't call the auth here because it will always be called through
        //the notification from the AppDelegate
        
        //update controls position
        let unavailableHeight = CGFloat(44.0 + self.view.frame.width - (iPad() ? 110 : 0))
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
        
        //add force touch delegate
        if #available(iOS 9.0, *) {
            if traitCollection.forceTouchCapability == .Available {
                registerForPreviewingWithDelegate(self, sourceView: self.view)
            }
        }
        
        //add gradient to color picker slider
        let slider = backgroundTintSlider
        let colors = [UIColor.redColor().CGColor, UIColor.orangeColor().CGColor, UIColor.yellowColor().CGColor,
            UIColor.greenColor().CGColor, UIColor.cyanColor().CGColor, UIColor.blueColor().CGColor,
            UIColor.purpleColor().CGColor, UIColor.magentaColor().CGColor, UIColor.redColor().CGColor]
        
        let maxTrack = slider.subviews[0].subviews[0] as! UIImageView
        let minTrack = slider.subviews[1] as! UIImageView
        let tracks = [maxTrack, minTrack]
        
        for track in tracks {
            let tenthWidth = slider.frame.width * 0.1
            
            //add gradient
            let gradientLayer = CAGradientLayer()
            var gradientFrame = track.frame
            gradientFrame.origin.x = tenthWidth
            gradientFrame.origin.y = 0.0
            gradientFrame.size.width = slider.frame.width - tenthWidth - tenthWidth
            
            gradientLayer.frame = gradientFrame
            gradientLayer.colors = colors
            gradientLayer.startPoint = CGPointMake(0.0, 0.5)
            gradientLayer.endPoint = CGPointMake(1.0, 0.5)
            track.layer.cornerRadius = 2.5
            track.layer.insertSublayer(gradientLayer, atIndex: 0)
            
            //add white to the left of the gradient
            let whiteLayer = CALayer()
            var whiteFrame = track.frame
            whiteFrame.size.width = tenthWidth
            whiteFrame.origin.x = 0.0
            whiteFrame.origin.y = 0.0
            
            whiteLayer.frame = whiteFrame
            whiteLayer.backgroundColor = UIColor.whiteColor().CGColor
            track.layer.insertSublayer(whiteLayer, atIndex: 0)
            
            //add black to the right of the gradient
            let blackLayer = CALayer()
            var blackFrame = track.frame
            blackFrame.size.width = tenthWidth
            blackFrame.origin.x = tenthWidth * 9.0
            blackFrame.origin.y = 0.0
            
            blackLayer.frame = blackFrame
            blackLayer.backgroundColor = UIColor.blackColor().CGColor
            track.layer.insertSublayer(blackLayer, atIndex: 0)
        }
    }
    
    var sliderDefaults: [UISlider : Float] = [:]
    var sentToSettings = false
    var appearAlreadyHandled = false
    
    override func viewDidAppear(animated: Bool) {
        if appearAlreadyHandled { return }
        
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
        
        appearAlreadyHandled = true
    }
    
    func handlePhotosAuth() {
        
        let authorization = PHPhotoLibrary.authorizationStatus()
        if authorization == PHAuthorizationStatus.NotDetermined {
            PHPhotoLibrary.requestAuthorization() { status in
                if status == PHAuthorizationStatus.Authorized {
                    dispatch_sync(dispatch_get_main_queue(), {
                        self.displayThumbnails()
                    })
                } else {
                    self.theyPulledADickMoveAndDeniedPermissions()
                }
            }
        }
        else if authorization == PHAuthorizationStatus.Authorized || sentToSettings {
            self.displayThumbnails()
        } else {
            theyPulledADickMoveAndDeniedPermissions()
        }
    }
    
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
        if let fetch = fetch {
            return fetch.count
        }
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("image", forIndexPath: indexPath) as! ImageCell
        
        if fetch == nil { return cell }
        
        //get thumbnail for cell
        let asset: PHAsset! = fetch![indexPath.item] as? PHAsset
        if asset == nil { return cell }
        
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
        let width = UIScreen.mainScreen().bounds.width - (iPad() ? 4.0 : 2.0)
        let count = CGFloat(iPad() ? 4.0 : 3.0)
        let cellWidth = width / count
        return CGSizeMake(cellWidth, cellWidth)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        collectionView.userInteractionEnabled = false
        
        if fetch == nil { return }
        
        //get thumbnail for cell
        let asset: PHAsset! = fetch![indexPath.item] as? PHAsset
        if asset == nil { return }
        
        var requestedImageCount = 0
        self.changesMade = false
        var lateArrivalImage: UIImage?
        
        imageManager.requestImageForAsset(asset, targetSize: self.view.frame.size, contentMode: PHImageContentMode.AspectFill, options: nil, resultHandler: { result, info in
            
            if let result = result {
                
                //any time other than the first time should only update the image, not start a new animation
                requestedImageCount++
                if requestedImageCount > 1 {
                    self.backgroundHue = -1
                    lateArrivalImage = result
                    self.currentBlurRadius = 0.04 * self.customBlur.frame.width
                    self.selectedImage = lateArrivalImage
                    
                    self.transitionImage.image = lateArrivalImage
                    self.playFadeTransitionForView(self.transitionImage, duration: 0.25)
                    
                    delay(0.25) {
                        self.FORCE_ANIMATION_FOR_BLUR_CALCULATION = true
                        self.selectedImage = lateArrivalImage
                    }
                    
                    delay(0.5) {
                        if self.backgroundHue == -1 {
                            self.blurBackground.backgroundColor = UIColor.blackColor()
                        }
                    }
                    
                    return
                }
                
                //position animated view on top of selected cell
                let selectedCell: ImageCell! = self.findOnScreenCellWithIndex(indexPath)
                if selectedCell == nil { return }
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
                
                //dynamic y-position to keep in-call status bar in check
                let statusBarHeight = UIApplication.sharedApplication().statusBarFrame.height
                let endY: CGFloat
                if statusBarHeight == 20.0 {
                    endY = 44.0
                } else {
                    endY = 4.0
                }
                
                var endFrame = CGRectMake(0.0, endY, self.view.frame.width, self.view.frame.width)
                if iPad() {
                    endFrame = CGRectMake(55.0, endY, self.view.frame.width - 110.0, self.view.frame.width - 110.0)
                }
                let duration: Double = 0.3
                
                //create the transition view and translation view (confusing right?)
                self.translationView = UIImageView(frame: self.view.frame)
                self.translationView.addSubview(self.transitionImage)
                
                self.transitionView = UIImageView(frame: self.view.frame)
                self.transitionView.addSubview(self.translationView)
                self.view.addSubview(self.transitionView)
                
                //do non animated view prep
                self.hideStatusBar = true
                self.blurBackground.backgroundColor = UIColor.whiteColor()
                self.shareSheetPosition.constant = self.controlsSuperview.frame.height

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
                        
                        //add mask to transition view
                        let maskFrame: CGRect
                        let offset: CGFloat = (iPad() ? 110.0 : 0.0)
                        if endY == 4.0 {
                            maskFrame = CGRectMake(offset / 2, 24.0, self.view.frame.width - offset, self.view.frame.width - offset)
                        } else {
                            maskFrame = CGRectMake(offset / 2, 44.0, self.view.frame.width - offset, self.view.frame.width - offset)
                        }
                        let maskPath = CGPathCreateWithRect(maskFrame, nil)
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
    
    func playFadeTransitionForView(view: UIView, duration: Double) {
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        transition.type = kCATransitionFade
        view.layer.addAnimation(transition, forKey: nil)
    }
    
    func statusBarTapped() {
        self.collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), atScrollPosition: .Top, animated: true)
    }
    
    //MARK: - 3D Touch support, peek and pop
    
    @available(iOS 9.0, *)
    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        if translationView != nil { return nil } //do nothing if the editor is already open
        
        let locationInCollection = collectionView.convertPoint(location, fromView: self.view)
        guard let indexPath = collectionView.indexPathForItemAtPoint(locationInCollection) else { return nil }
        guard let cell = findOnScreenCellWithIndex(indexPath) else { return nil }
        
        //get thumbnail for cell
        let asset: PHAsset! = fetch![indexPath.item] as? PHAsset
        if asset == nil { return nil }
        
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("peekImage") as! PeekViewController
        viewController.decorateWithAsset(asset)
        viewController.indexPath = indexPath
        viewController.collectionView = self.collectionView
        viewController.preferredContentSize = CGSizeMake(CGFloat(asset.pixelWidth), CGFloat(asset.pixelHeight))
        
        //calculate proper source rect
        var rect = collectionView.convertRect(cell.frame, toView: self.view)
        let rectBottom = CGRectGetMaxY(rect)
        let adBannerTop = CGRectGetMinY(bannerView.frame)
        
        if rectBottom > adBannerTop {
            let difference = rectBottom - adBannerTop
            rect = CGRect(origin: rect.origin, size: CGSizeMake(rect.width, rect.height - difference))
            if !rect.contains(location) {
                return nil
            }
        }
        
        previewingContext.sourceRect = rect
        
        return viewController
    }
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController) {
        if let peek = viewControllerToCommit as? PeekViewController {
            peek.pop()
        }
    }
    
    //pragma MARK: - Editor Functions
    
    @IBAction func backButtonPressed(sender: AnyObject) {
        
        if shareSheetOpen { closeShareSheet() }
        else if !changesMade { goBack() }
        else {
            //show an alert first
            let alert = UIAlertController(title: "Discard Edits", message: "Are you sure? You won't be able to get them back.", preferredStyle: .Alert)
            let discard = UIAlertAction(title: "Discard", style: UIAlertActionStyle.Destructive, handler: goBack)
            let nevermind = UIAlertAction(title: "Nevermind", style: .Default, handler: nil)
            alert.addAction(nevermind)
            alert.addAction(discard)
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
    }
    
    func goBack(_ : UIAlertAction? = nil) {
        
        if transitionView == nil { return }
        
        let offScreenOrigin = CGPointMake(0, -customBlur.frame.height * 1.2)
        self.hideStatusBar = false
        
        if self.statusBarDarkHeight.constant != 0.0 {
            self.statusBarDarkHeight.constant = 20.0
        }
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.statusBarDark.alpha = 0.0
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
            self.translationView = nil
            self.customBlurTop.constant = 0
            self.customBlur.alpha = 0.0
            self.customBlur.image = nil
            self.selectedImage = nil
            self.downsampled = nil
            self.statusBarDarkHeight.constant = 0.0
            self.view.layoutIfNeeded()
            self.statusBarDark.alpha = 1.0
            
            self.cancelButton.setImage(UIImage(named: "cancel-100 (black)"), forState: UIControlState.Normal)
            self.downloadButton.alpha = 1.0
            
            //set all sliders back to their default value
            for (slider, defaultValue) in self.sliderDefaults {
                slider.value = defaultValue
            }
            //set scroll view to top too
            self.controlsScrollView.contentOffset = CGPointZero
            
            self.centerImageButtonIsVisible(false)
        })
        
    }
    
    var previousCommitedSlider: CGFloat = 0.0
    @IBAction func blurChanged(sender: UISlider) {
        self.changesMade = true
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
        self.changesMade = true
        let slider = CGFloat(sender.value)
        customBlur.alpha = slider
    }
    
    @IBAction func blurBackgroundHueChanged(sender: UISlider) {
        self.changesMade = true
        let slider = CGFloat(sender.value)
        
        if backgroundHue == -1 && backgroundAlphaSlider.value == 1.0{
            //make sure the user is aware that this is affecting color
            UIView.animateWithDuration(0.85, animations: {
                self.backgroundAlphaSlider.setValue(0.75, animated: true)
                self.customBlur.alpha = 0.75
            })
        }
        
        backgroundHue = slider
        var newColor = UIColor(hue: backgroundHue - 0.1, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        
        if backgroundHue < 0.1 {
            newColor = UIColor.whiteColor()
        } else if backgroundHue > 1.1 {
            newColor = UIColor.blackColor()
        }
        
        blurBackground.backgroundColor = newColor
    }
    
    
    
    @IBAction func scaleChanged(sender: UISlider) {
        self.changesMade = true
        foregroundEdit?.scale = CGFloat(sender.value)
        updateForegroundImage()
    }
    
    @IBAction func horizontalCropChanged(sender: UISlider) {
        self.changesMade = true
        foregroundEdit?.horizontalCrop = -CGFloat(sender.value)
        updateForegroundImage()
    }

    @IBAction func verticalCropChanged(sender: UISlider) {
        self.changesMade = true
        foregroundEdit?.verticalCrop = -CGFloat(sender.value)
        updateForegroundImage()
    }
    
    @IBAction func yPositionChanged(sender: UISlider) {
        self.changesMade = true
        let slider = -CGFloat(sender.value)
        let height = blurBackground.frame.height
        let yOffset = height * slider
        
        let previousX = translationView.transform.tx
        translationView.transform = CGAffineTransformMakeTranslation(previousX, yOffset)
        centerImageButtonIsVisible(true)
    }
    
    @IBAction func xPositionChanged(sender: UISlider) {
        self.changesMade = true
        let slider = CGFloat(sender.value)
        let width = blurBackground.frame.width
        let xOffset = width * slider
        
        let previousY = translationView.transform.ty
        translationView.transform = CGAffineTransformMakeTranslation(xOffset, previousY)
        centerImageButtonIsVisible(true)
    }
    
    @IBAction func centerImage(sender: AnyObject) {
        centerImageButtonIsVisible(false)
        
        UIView.animateWithDuration(0.4, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
            self.xSlider.setValue(0.0, animated: true)
            self.ySlider.setValue(0.0, animated: true)
            self.translationView.transform = CGAffineTransformIdentity
        }, completion: nil)
    }
    
    func centerImageButtonIsVisible(visible: Bool) {
        UIView.animateWithDuration(0.2, animations: {
            self.centerImageButton.alpha = visible ? 1.0 : 0.0
            self.centerImageButton.transform = CGAffineTransformMakeScale(visible ? 1.0 : 0.5, visible ? 1.0 : 0.5)
        })
    }
    
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    var transformBeforePan: CGPoint?
    @IBAction func panDetected(sender: UIPanGestureRecognizer) {
        if self.statusBarDarkHeight.constant != 0.0 { return } //return if in share sheet
        
        if let translationView = self.translationView {
            
            if sender.state == .Began {
                transformBeforePan = CGPointMake(translationView.transform.tx, translationView.transform.ty)
            }
            
            if let transformBeforePan = transformBeforePan {
                let translation = sender.translationInView(translationView)
                let newTransform = CGPointMake(translation.x + transformBeforePan.x, translation.y + transformBeforePan.y)
                translationView.transform = CGAffineTransformMakeTranslation(newTransform.x, newTransform.y)
                
                //adjust sliders
                let ySliderValue = newTransform.y / blurBackground.frame.width
                ySlider.value = -Float(ySliderValue)
                let xSliderValue = newTransform.x / blurBackground.frame.width
                xSlider.value = Float(xSliderValue)
            }
        }
        
        if sender.state == .Ended {
            transformBeforePan = nil
        }
        
        centerImageButtonIsVisible(true)
    }
    
    var scaleBeforePinch: CGFloat?
    @IBAction func scaleDetected(sender: UIPinchGestureRecognizer) {
        if self.statusBarDarkHeight.constant != 0.0 { return } //return if in share sheet
        
        if let foregroundEdit = self.foregroundEdit {
            
            if sender.state == .Began {
                scaleBeforePinch = foregroundEdit.scale
            }
            
            if let scaleBeforePinch = scaleBeforePinch {
                var newScale = scaleBeforePinch + (sender.scale - 1.0)
                if newScale < 0.0 {
                    newScale = 0.0
                }
                foregroundEdit.scale = newScale
                updateForegroundImage()
                
                //adjust sliders
                scaleSlider.value = Float(newScale)
            }
        }
        
        if sender.state == .Ended {
            scaleBeforePinch = nil
        }
    }
    
    //pragma MARK: - iAd Delegate Functions
    
    @IBOutlet weak var adPosition: NSLayoutConstraint!
    
    func bannerViewDidLoadAd(banner: ADBannerView!) {
        
        if is4S() {
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
    
    //pragma MARK: - Export
    
    @IBAction func downloadButtonPressed(sender: AnyObject) {
        
        //animate activity indicator
        view.bringSubviewToFront(exportGray)
        view.bringSubviewToFront(activityIndicator)
        view.bringSubviewToFront(shareContainer)
        indicatorPosition.constant = 40
        self.view.layoutIfNeeded()
        indicatorPosition.constant = 0
        self.view.userInteractionEnabled = false
        
        UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [], animations: {
            self.view.layoutIfNeeded()
            self.activityIndicator.alpha = 1.0
            self.exportGray.alpha = 1.0
        }, completion: nil)
        
        dispatch_async(backgroundQueue, {
            
            //create image asynchronously
            let image = self.createImage()
            
            //write data now so it doesn't have to be done later
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documentsURL = NSURL(fileURLWithPath: paths[0])
            let savePath = documentsURL.URLByAppendingPathComponent("export.igo")
            let savePath2 = documentsURL.URLByAppendingPathComponent("export.png")
            let imageData = UIImagePNGRepresentation(image)!
            let success1 = imageData.writeToFile(savePath.path!, atomically: true)
            let success2 = imageData.writeToFile(savePath2.path!, atomically: true)
            
            let shareSheetTop = (self.statusBarBlur.frame.height + self.view.frame.width) - 10.0
            let arrayObject: [AnyObject] = [image, self, shareSheetTop]
            NSNotificationCenter.defaultCenter().postNotificationName(IBPassImageNotification, object: arrayObject)
            
            dispatch_sync(dispatch_get_main_queue(), {
                
                self.view.userInteractionEnabled = true
                
                let success = success1 && success2
                if !success {
                    //there wasn't enough disk space to save the images
                    let alert = UIAlertController(title: "Your storage space is full.", message: "There wasn't enough disk space to process the image.", preferredStyle: .Alert)
                    let ok = UIAlertAction(title: "ok", style: .Default, handler: { action in
                        UIView.animateWithDuration(0.5, animations: {
                            self.activityIndicator.alpha = 0.0
                            self.exportGray.alpha = 0.0
                        })
                    })
                    alert.addAction(ok)
                    self.presentViewController(alert, animated: true, completion: nil)
                    return
                }
                
                self.shareSheetOpen = true
                
                //animate change in staus bar buttons
                self.cancelButton.setImage(UIImage(named: "cancel-100 (white)"), forState: UIControlState.Normal)
                self.playFadeTransitionForView(self.cancelButton, duration: 0.45)
                UIView.animateWithDuration(0.45, animations: {
                    self.downloadButton.alpha = 0.0
                })
                
                UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [], animations: {
                    
                    self.statusBarDarkHeight.constant = self.statusBarBlur.frame.height
                    self.shareSheetPosition.constant = -10.0
                    self.adPosition.constant = -self.bannerView.frame.height
                    self.view.layoutIfNeeded()
                    if iPad() { self.blur.effect = UIBlurEffect(style: .Dark) }
                    self.activityIndicator.alpha = 0.0
                    self.exportGray.alpha = 0.0
                    
                    
                }, completion: nil)
                
            })
            
        })
    }
    
    func closeShareSheet() {
        
        shareSheetOpen = false
        
        //animate change in staus bar buttons
        self.cancelButton.setImage(UIImage(named: "cancel-100 (black)"), forState: UIControlState.Normal)
        self.playFadeTransitionForView(self.cancelButton, duration: 0.45)
        UIView.animateWithDuration(0.45, animations: {
            self.downloadButton.alpha = 1.0
        })
        
        
        UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.shareSheetPosition.constant = self.controlsSuperview.frame.height
            self.statusBarDarkHeight.constant = 0.0
            self.adPosition.constant = self.bannerView.bannerLoaded ? 0.0 : -self.bannerView.frame.height
            self.view.layoutIfNeeded()
            if iPad() { self.blur.effect = UIBlurEffect(style: .ExtraLight) }
            self.activityIndicator.alpha = 0.0
            self.exportGray.alpha = 0.0
            
            
        }, completion: nil)
    }
    
    
    func createFillRect(aspectFill aspectFill: Bool, originalSize: CGSize, squareArea: CGRect) -> CGRect {
        let fillRect: CGRect
        
        let isTallerThanWide = originalSize.width < originalSize.height
        
        if originalSize.width == originalSize.height {
            fillRect = squareArea
        }
        else if (aspectFill ? isTallerThanWide : !isTallerThanWide) {
            let downWidth = squareArea.width
            let proportion = downWidth / originalSize.width
            let downHeight = proportion * originalSize.height
            let fillSize = CGSizeMake(downWidth, downHeight)
            
            let heightDiff = fillSize.height - squareArea.height
            let yOffset = -heightDiff / 2
            let fillOrigin = CGPointMake(squareArea.origin.x, squareArea.origin.y + yOffset)
            fillRect = CGRect(origin: fillOrigin, size: fillSize)
        }
        else {// if originalSize.width > originalSize.height {
            let downHeight = squareArea.height
            let proportion = downHeight / originalSize.height
            let downWidth = proportion * originalSize.width
            let fillSize = CGSizeMake(downWidth, downHeight)
            
            let widthDiff = fillSize.width - squareArea.width
            let xOffset = -widthDiff / 2
            let fillOrigin = CGPointMake(squareArea.origin.x + xOffset, squareArea.origin.y)
            fillRect = CGRect(origin: fillOrigin, size: fillSize)
        }
        
        return fillRect
    }
    
    func createImage() -> UIImage {
        
        UIGraphicsBeginImageContext(CGSizeMake(2000, 2000))
        let context = UIGraphicsGetCurrentContext()
        
        //draw background on to context @1.2x
        let backgroundRect = CGRectMake(-200, -200, 2400, 2400)
        
        //fill background color
        let backgroundColor: UIColor
        if let color = blurBackground.backgroundColor {
            backgroundColor = color
        }
        else { backgroundColor = UIColor.whiteColor() }
        
        CGContextSetFillColorWithColor(context, backgroundColor.CGColor)
        CGContextFillRect(context, backgroundRect)
        
        let imageToBlur = self.selectedImage!
        
        let blurredBackground = blurImage(imageToBlur, withRadius: self.currentBlurRadius)
        let correctBackground = UIImage(CIImage: CIImage(CGImage: blurredBackground.CGImage!), scale: blurredBackground.scale, orientation: self.selectedImage!.imageOrientation)
        let backgroundFillRect = createFillRect(aspectFill: true, originalSize: imageToBlur.size, squareArea: backgroundRect)
        correctBackground.drawInRect(backgroundFillRect, blendMode: CGBlendMode.Normal, alpha: customBlur.alpha)
        
        //process foregroud
        let foreground: UIImage
        if let croppedImage = foregroundEdit?.processedImage {
            foreground = croppedImage
        } else { foreground = self.selectedImage! }
        
        //figure out square rect for foreground
        let baseRect = CGRectMake(0, 0, 2000, 2000)
        
        //processScale
        let scale: CGFloat
        if let customScale = foregroundEdit?.scale {
            scale = customScale
        }
        else { scale = 1.0}
        
        let scaledSize = CGSizeMake(baseRect.width * scale, baseRect.height * scale)
        let sizeDiff = scaledSize.width - baseRect.width //is always square
        let offset = -sizeDiff / 2
        let scaledOrigin = CGPointMake(offset, offset)
        let scaledRect = CGRect(origin: scaledOrigin, size: scaledSize)
        
        //process position
        let xSlider = translationView.transform.tx / blurBackground.frame.width
        let ySlider = translationView.transform.ty / blurBackground.frame.height
        
        let finalRect = CGRectOffset(scaledRect, xSlider * 2000, ySlider * 2000)
        
        let foregroundFillRect = createFillRect(aspectFill: false, originalSize: foreground.size, squareArea: finalRect)
        foreground.drawInRect(foregroundFillRect, blendMode: CGBlendMode.Normal, alpha: 1.0)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
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

