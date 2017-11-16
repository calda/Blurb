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

let IBAppOpenedNotification = "com.cal.instablur.app-opened-notification"
let backgroundQueue = DispatchQueue(label: "image rendering", qos: .utility, attributes: .concurrent)

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIViewControllerPreviewingDelegate {

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
    
    var transitionImage: UIImageView!
    var translationView: UIImageView!
    var transitionView: UIImageView!
    var changesMade = false
    
    var imageManager = PHImageManager()
    var fetch: PHFetchResult<PHAsset>?
    
    var hideStatusBar = false {
        didSet {
            UIView.animate(withDuration: 0.3, animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        return hideStatusBar
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return (shareSheetOpen) ? .lightContent : .default
    }
    
    private lazy var expectedStatusBarHeight: CGFloat = {
        if #available(iOS 11.0, *) {
            print(view.safeAreaInsets.top)
            let safeAreaInset = view.safeAreaInsets.top
            if safeAreaInset == 0 { return 20 }
            else { return safeAreaInset }
        } else {
            return 20
        }
    }()
    
    var expectedStatusBarHeightWithControls: CGFloat {
        if expectedStatusBarHeight == 20 {
            return expectedStatusBarHeight + 24
        } else {
            return expectedStatusBarHeight + 15 + 24
        }
    }
    
    //pragma MARK: - Managing the blur customization
    //manage the image and the radius
    
    var foregroundEdit: EditProxy?
    var backgroundHue: CGFloat = -1.0
    
    func updateForegroundImage() {
        let processedImage = foregroundEdit?.processedImage
        self.transitionImage.image = processedImage
        
        let scale = foregroundEdit!.scale
        transitionImage.transform = CGAffineTransform(scaleX: scale, y: scale)
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
    
    func applyBlurWithSettings(animate: Bool) {
        
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
            var downsampleSize = CGSize.zero
            let originalSize = selectedImage.size
            let scale = UIScreen.main.scale / downsampleScale
            
            //must be atleast the size of the customBlur view
            if originalSize.width == originalSize.height {
                downsampleSize = customBlur.frame.size
            }
            else if originalSize.width < originalSize.height {
                let downWidth = customBlur.frame.width
                let proportion = downWidth / originalSize.width
                let downHeight = proportion * originalSize.height
                downsampleSize = CGSize(width: downWidth * scale, height: downHeight * scale)
            }
            else if originalSize.width > originalSize.height {
                let downHeight = customBlur.frame.height
                let proportion = downHeight / originalSize.height
                let downWidth = proportion * originalSize.width
                downsampleSize = CGSize(width: downWidth * scale, height: downHeight * scale)
            }
            
            UIGraphicsBeginImageContextWithOptions(downsampleSize, false, 1.0)
            selectedImage.draw(in: CGRect(origin: CGPoint.zero, size: downsampleSize))
            downsampled = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            //fix orientation
            let cgImage = downsampled!.cgImage
            downsampled = UIImage(cgImage: cgImage!, scale: 0.0, orientation: selectedImage.imageOrientation)
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
    
    func blurImage(_ image: UIImage, withRadius: CGFloat) -> UIImage {
        let ciImage = CIImage(cgImage: image.cgImage!)
        
        let gaussian = CIFilter(name: "CIGaussianBlur")!
        gaussian.setDefaults()
        gaussian.setValue(ciImage, forKey: kCIInputImageKey)
        gaussian.setValue(withRadius, forKey: kCIInputRadiusKey)
        
        let filterOutput = gaussian.outputImage
        //bring CIImage back down to UIImage
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(filterOutput!, from: ciImage.extent)
        return UIImage(cgImage: cgImage!)
    }
    
    
    //pragma MARK: - Managing the view itself
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.handlePhotosAuth), name: NSNotification.Name(rawValue: IBAppOpenedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.closeShareSheet), name: NSNotification.Name(rawValue: IBCloseShareSheetNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.statusBarTapped), name: NSNotification.Name(rawValue: IBStatusBarTappedNotification), object: nil)
        
        //handlePhotosAuth()
        //don't call the auth here because it will always be called through
        //the notification from the AppDelegate
        
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
            if traitCollection.forceTouchCapability == .available {
                registerForPreviewing(with: self, sourceView: self.view)
            }
        }
        
        //add gradient to color picker slider
        let slider = backgroundTintSlider
        let colors = [UIColor.red.cgColor, UIColor.orange.cgColor, UIColor.yellow.cgColor,
            UIColor.green.cgColor, UIColor.cyan.cgColor, UIColor.blue.cgColor,
            UIColor.purple.cgColor, UIColor.magenta.cgColor, UIColor.red.cgColor]
        
        let maxTrack = slider?.subviews[0].subviews[0] as! UIImageView
        let minTrack = slider?.subviews[1] as! UIImageView
        let tracks = [maxTrack, minTrack]
        
        for track in tracks {
            let tenthWidth = (slider?.frame.width)! * 0.1
            
            //add gradient
            let gradientLayer = CAGradientLayer()
            var gradientFrame = track.frame
            gradientFrame.origin.x = tenthWidth
            gradientFrame.origin.y = 0.0
            gradientFrame.size.width = (slider?.frame.width)! - tenthWidth - tenthWidth
            
            gradientLayer.frame = gradientFrame
            gradientLayer.colors = colors
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
            track.layer.cornerRadius = 2.5
            track.layer.insertSublayer(gradientLayer, at: 0)
            
            //add white to the left of the gradient
            let whiteLayer = CALayer()
            var whiteFrame = track.frame
            whiteFrame.size.width = tenthWidth
            whiteFrame.origin.x = 0.0
            whiteFrame.origin.y = 0.0
            
            whiteLayer.frame = whiteFrame
            whiteLayer.backgroundColor = UIColor.white.cgColor
            track.layer.insertSublayer(whiteLayer, at: 0)
            
            //add black to the right of the gradient
            let blackLayer = CALayer()
            var blackFrame = track.frame
            blackFrame.size.width = tenthWidth
            blackFrame.origin.x = tenthWidth * 9.0
            blackFrame.origin.y = 0.0
            
            blackLayer.frame = blackFrame
            blackLayer.backgroundColor = UIColor.black.cgColor
            track.layer.insertSublayer(blackLayer, at: 0)
        }
        
        //hide everything until the constraints are ready
        view.subviews.forEach { $0.transform = CGAffineTransform(scaleX: 0.005, y: 0.005) }
    }
    
    var sliderDefaults: [UISlider : Float] = [:]
    var sentToSettings = false
    var appearAlreadyHandled = false
    
    override func viewDidAppear(_ animated: Bool) {
        if appearAlreadyHandled { return }
        
        //update status bar view -- this has to happen here because safeAreaInsets are 0 until now
        statusBarHeight.constant = self.expectedStatusBarHeight
        
        //update controls position
        let statusBarViewHeight = self.expectedStatusBarHeightWithControls
        let imageAreaHeight = self.view.frame.width
        let unavailableHeight = CGFloat(statusBarViewHeight + imageAreaHeight - (iPad() ? 110 : 0))
        controlsHeight.constant = self.view.frame.height - unavailableHeight
        controlsPosition.constant = -controlsHeight.constant
        
        self.view.layoutIfNeeded()
        
        //scale up custom blur but mask to original bounds
        let originalFrame = customBlur.frame
        customBlur.transform = customBlur.transform.scaledBy(x: 1.2, y: 1.2)
        
        let maskFrame = customBlur.convert(originalFrame, from: customBlur.superview!)
        let maskPath = CGPath(rect: maskFrame, transform: nil)
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath
        customBlur.layer.mask = maskLayer
        customBlur.clipsToBounds = true
        
        appearAlreadyHandled = true
        
        view.subviews.forEach { $0.transform = .identity }
        
        //wait for the collection view to load and then play the launch animation
        collectionView.alpha = 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200), execute: {
            self.collectionView.alpha = 1.0
            
            //animate visible cells
            for cell in self.collectionView.visibleCells as! [ImageCell] {
                let index = self.collectionView.indexPath(for: cell)!.item
                let delay: Double = Double(index) * 0.015
                cell.playLaunchAnimation(delay)
            }
        })
        
    }
    
    @objc func handlePhotosAuth() {
        
        let authorization = PHPhotoLibrary.authorizationStatus()
        if authorization == PHAuthorizationStatus.notDetermined {
            PHPhotoLibrary.requestAuthorization() { status in
                if status == PHAuthorizationStatus.authorized {
                    DispatchQueue.main.sync(execute: {
                        self.displayThumbnails()
                    })
                } else {
                    self.userDidDenyPhotoPermissions()
                }
            }
        }
        else if authorization == PHAuthorizationStatus.authorized || sentToSettings {
            self.displayThumbnails()
        } else {
            userDidDenyPhotoPermissions()
        }
    }
    
    func userDidDenyPhotoPermissions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            //create an alert to send the user to settings
            let alert = UIAlertController(title: "You denied access to the camera roll.", message: "That's kinda important for a Photo app. It's not hard to fix though!", preferredStyle: UIAlertControllerStyle.alert)
            
            let okAction = UIAlertAction(title: "Nevermind", style: UIAlertActionStyle.destructive, handler: nil)
            let fixAction = UIAlertAction(title: "Go to Settings", style: .default, handler: { action in
                self.sentToSettings = true
                UIApplication.shared.openURL(URL(string:UIApplicationOpenSettingsURLString)!)
            })
            
            alert.addAction(okAction)
            alert.addAction(fixAction)
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func displayThumbnails() {
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetch = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
        
        if fetch == nil || fetch?.count == 0  {
            //no permissions
            let alert = UIAlertController(title: "There was a problem loading your pictures.", message: "This just happens sometimes. Sorry. Restart the app through the app switcher (double-tap the home button) and then launch the app again.", preferredStyle: .alert)
            self.present(alert, animated: true, completion: nil)
        }
        
        collectionView.reloadData()
        customBlur.layer.masksToBounds = true
    }
    
    //pragma MARK: - Managing the Collection View
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let fetch = fetch {
            return fetch.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "image", for: indexPath) as! ImageCell
        
        if fetch == nil { return cell }
        
        //get thumbnail for cell
        let asset: PHAsset! = fetch![indexPath.item]
        if asset == nil { return cell }
        
        let collectionWidth = collectionView.frame.width
        let cellWidth = (collectionWidth - 2.0) / 3.0
        let cellSize = CGSize(width: cellWidth, height: cellWidth)
        
        imageManager.requestImage(for: asset, targetSize: cellSize, contentMode: PHImageContentMode.aspectFill, options: nil, resultHandler: { result, info in
        
            if let result = result {
                cell.decorate(result)
            }
            
        })
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = UIScreen.main.bounds.width - (iPad() ? 4.0 : 2.0)
        let count = CGFloat(iPad() ? 5.0 : 3.0)
        let cellWidth = width / count
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        collectionView.isUserInteractionEnabled = false
        
        if fetch == nil { return }
        
        //get thumbnail for cell
        let asset: PHAsset! = fetch![indexPath.item]
        if asset == nil { return }
        
        var requestedImageCount = 0
        self.changesMade = false
        var lateArrivalImage: UIImage?
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.progressHandler = { progress, error, stop, info in
            if progress < 1.0 {
                DispatchQueue.main.async { self.showImageActivityIndicator() }
            } else if progress >= 1.0 {
                DispatchQueue.main.async { self.hideImageActivityIndicator() }
            }
            
            print(progress)
        }
        
        imageManager.requestImage(for: asset, targetSize: self.view.frame.size, contentMode: PHImageContentMode.aspectFill, options: requestOptions, resultHandler: { result, info in
            
            if let result = result {
                
                //any time other than the first time should only update the image, not start a new animation
                requestedImageCount += 1
                if requestedImageCount > 1 {
                    self.backgroundHue = -1
                    lateArrivalImage = result
                    self.currentBlurRadius = 0.04 * self.customBlur.frame.width
                    self.selectedImage = lateArrivalImage
                    
                    self.transitionImage.image = lateArrivalImage
                    self.playFadeTransitionForView(self.transitionImage, duration: 0.25)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                        self.FORCE_ANIMATION_FOR_BLUR_CALCULATION = true
                        self.selectedImage = lateArrivalImage
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                        if self.backgroundHue == -1 {
                            self.blurBackground.backgroundColor = UIColor.black
                        }
                    }
                    
                    return
                }
                
                //position animated view on top of selected cell
                let selectedCell: ImageCell! = self.findOnScreenCellWithIndex(indexPath)
                if selectedCell == nil { return }
                let imageSize = result.size
                
                //convert selected cell origin to point in root view
                let convertedOrigin = self.view.convert(selectedCell.frame.origin, from: selectedCell.superview!)
                let startFrame: CGRect
                let startWidth: CGFloat
                let startHeight: CGFloat
                
                if imageSize.height >= imageSize.width { //image is tall
                    startWidth = selectedCell.frame.width
                    startHeight = (startWidth / imageSize.width) * imageSize.height
                    let startX = convertedOrigin.x
                    let startY = convertedOrigin.y - (startHeight - selectedCell.frame.height) / 2.0
                    startFrame = CGRect(x: startX, y: startY, width: startWidth, height: startHeight)
                }
                else { //image is wide
                    startHeight = selectedCell.frame.height
                    startWidth = (startHeight / imageSize.height) * imageSize.width
                    let startX = convertedOrigin.x - (startWidth - selectedCell.frame.width) / 2.0
                    let startY = convertedOrigin.y
                    startFrame = CGRect(x: startX, y: startY, width: startWidth, height: startHeight)
                }
                
                //create the transition image
                self.transitionImage = UIImageView(frame: startFrame)
                self.transitionImage.image = selectedCell.bottom.image!
                self.transitionImage.contentMode = .scaleAspectFit
                
                //mask transition image to square
                let maskRect: CGRect
                
                if imageSize.height >= imageSize.width { //image is tall
                    let maskY = (startHeight - startWidth) / 2.0
                    maskRect = CGRect(x: 0.0, y: maskY, width: startWidth, height: startWidth)
                }
                else { //image is wide
                    let maskX = (startWidth - startHeight) / 2.0
                    maskRect = CGRect(x: maskX, y: 0.0, width: startHeight, height: startHeight)
                }
                
                let maskPath = CGPath(rect: maskRect, transform: nil)
                let maskLayer = CAShapeLayer()
                maskLayer.path = maskPath
                self.transitionImage.layer.mask = maskLayer
                
                //animate to full screen with blur
                
                //dynamic y-position to keep in-call status bar in check
                let statusBarHeight = UIApplication.shared.statusBarFrame.height
                let endY: CGFloat
                
                if statusBarHeight == self.expectedStatusBarHeight {
                    endY = self.expectedStatusBarHeightWithControls
                } else {
                    endY = 4.0
                }
                
                var endFrame = CGRect(x: 0.0, y: endY, width: self.view.frame.width, height: self.view.frame.width)
                if iPad() {
                    endFrame = CGRect(x: 55.0, y: endY, width: self.view.frame.width - 110.0, height: self.view.frame.width - 110.0)
                }
                let duration: Double = 0.3
                
                //create the transition view and translation view (confusing right?)
                self.translationView = UIImageView(frame: self.view.frame)
                self.translationView.addSubview(self.transitionImage)
                
                self.transitionView = UIImageView(frame: self.view.frame)
                self.transitionView.addSubview(self.translationView)
                self.view.addSubview(self.transitionView)
                
                //do non animated view prep
                if self.expectedStatusBarHeight == 20 {
                    // only hide status bar on pre-X devices
                    self.hideStatusBar = true
                }
                
                self.blurBackground.backgroundColor = UIColor.white
                self.shareSheetPosition.constant = self.controlsSuperview.frame.height

                //animate views
                UIView.animate(withDuration: duration, animations: {

                        self.transitionImage.frame = endFrame
                        self.blur.alpha = 1.0
                        self.customBlur.alpha = 1.0
                        self.blurBackground.alpha = 1.0
                    
                        self.statusBarHeight.constant = self.expectedStatusBarHeightWithControls // 44 on standard devices, larger on X
                    
                        self.backLeading.constant = 16
                        self.downloadTrailing.constant = 16
                    
                    
                        self.controlsPosition.constant = 0.0
                        self.view.layoutIfNeeded()
                    
                    }, completion: { success in
                        //add mask to transition view
                        let maskFrame: CGRect
                        let offset: CGFloat = (iPad() ? 110.0 : 0.0)
                        if endY == 4.0 {
                            maskFrame = CGRect(x: offset / 2, y: self.expectedStatusBarHeight + 4, width: self.view.frame.width - offset, height: self.view.frame.width - offset)
                        } else {
                            maskFrame = CGRect(x: offset / 2, y: self.expectedStatusBarHeightWithControls, width: self.view.frame.width - offset, height: self.view.frame.width - offset)
                        }
                        let maskPath = CGPath(rect: maskFrame, transform: nil)
                        let maskLayer = CAShapeLayer()
                        maskLayer.path = maskPath
                        self.transitionView.layer.mask = maskLayer
                        
                })
                
                //animate away mask
                let animation = CABasicAnimation(keyPath: "path")
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
                animation.duration = duration / 2.0
                let fullRect = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
                let fullPath = CGPath(rect: fullRect, transform: nil)
                animation.fromValue = maskPath
                animation.toValue = fullPath
                animation.isRemovedOnCompletion = false
                animation.fillMode = kCAFillModeForwards
                maskLayer.add(animation, forKey: "path")
            }
            
        })
        
    }
    
    func findOnScreenCellWithIndex(_ index: IndexPath) -> ImageCell? {
        for cell in collectionView.visibleCells {
            if let cell = cell as? ImageCell, collectionView.indexPath(for: cell) == index {
                return cell
            }
        }
        return nil
    }
    
    func playFadeTransitionForView(_ view: UIView, duration: Double) {
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        transition.type = kCATransitionFade
        view.layer.add(transition, forKey: nil)
    }
    
    @objc func statusBarTapped() {
        self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
    }
    
    //MARK: - 3D Touch support, peek and pop
    
    @available(iOS 9.0, *)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        if translationView != nil { return nil } //do nothing if the editor is already open
        
        let locationInCollection = collectionView.convert(location, from: self.view)
        guard let indexPath = collectionView.indexPathForItem(at: locationInCollection) else { return nil }
        guard let cell = findOnScreenCellWithIndex(indexPath) else { return nil }
        
        //get thumbnail for cell
        let asset: PHAsset! = fetch![indexPath.item]
        if asset == nil { return nil }
        
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "peekImage") as! PeekViewController
        viewController.decorateWithAsset(asset)
        viewController.indexPath = indexPath
        viewController.collectionView = self.collectionView
        viewController.preferredContentSize = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
        
        //calculate proper source rect
        let rect = collectionView.convert(cell.frame, to: self.view)
        previewingContext.sourceRect = rect
        
        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let peek = viewControllerToCommit as? PeekViewController {
            peek.pop()
        }
    }
    
    //pragma MARK: - Editor Functions
    
    @IBAction func backButtonPressed(_ sender: AnyObject) {
        
        if shareSheetOpen { closeShareSheet() }
        else if !changesMade { goBack() }
        else {
            //show an alert first
            let alert = UIAlertController(title: "Discard Edits", message: "Are you sure? You won't be able to get them back.", preferredStyle: .alert)
            let discard = UIAlertAction(title: "Discard", style: UIAlertActionStyle.destructive, handler: goBack)
            let nevermind = UIAlertAction(title: "Nevermind", style: .default, handler: nil)
            alert.addAction(nevermind)
            alert.addAction(discard)
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    func goBack(_ : UIAlertAction? = nil) {
        
        if transitionView == nil { return }
        
        hideImageActivityIndicator()
        
        let offScreenOrigin = CGPoint(x: 0, y: -customBlur.frame.height * 1.2)
        self.hideStatusBar = false
        
        if self.statusBarDarkHeight.constant != 0.0 {
            self.statusBarDarkHeight.constant = 20.0
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.statusBarDark.alpha = 0.0
            self.transitionImage.frame.origin = offScreenOrigin
            self.transitionImage.alpha = 0.0
            self.customBlurTop.constant = offScreenOrigin.y
            self.blurBackground.alpha = 0.0
            self.backLeading.constant = -90.0
            self.downloadTrailing.constant = -30.0
            self.controlsPosition.constant = -self.controlsHeight.constant
            
            self.statusBarHeight.constant = self.expectedStatusBarHeight
            
            self.view.layoutIfNeeded()
            self.blur.alpha = 0.0
            
        }, completion: { success in
            self.collectionView.isUserInteractionEnabled = true
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
            
            self.cancelButton.setImage(UIImage(named: "cancel-100 (black)"), for: UIControlState())
            self.downloadButton.alpha = 1.0
            
            //set all sliders back to their default value
            for (slider, defaultValue) in self.sliderDefaults {
                slider.value = defaultValue
            }
            //set scroll view to top too
            self.controlsScrollView.contentOffset = CGPoint.zero
            
            self.centerImageButtonIsVisible(false)
        })
        
    }
    
    var previousCommitedSlider: CGFloat = 0.0
    @IBAction func blurChanged(_ sender: UISlider) {
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
    
    @IBAction func blurAlphaChanged(_ sender: UISlider) {
        self.changesMade = true
        let slider = CGFloat(sender.value)
        customBlur.alpha = slider
    }
    
    @IBAction func blurBackgroundHueChanged(_ sender: UISlider) {
        self.changesMade = true
        let slider = CGFloat(sender.value)
        
        if backgroundHue == -1 && backgroundAlphaSlider.value == 1.0{
            //make sure the user is aware that this is affecting color
            UIView.animate(withDuration: 0.85, animations: {
                self.backgroundAlphaSlider.setValue(0.75, animated: true)
                self.customBlur.alpha = 0.75
            })
        }
        
        backgroundHue = slider
        var newColor = UIColor(hue: backgroundHue - 0.1, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        
        if backgroundHue < 0.1 {
            newColor = UIColor.white
        } else if backgroundHue > 1.1 {
            newColor = UIColor.black
        }
        
        blurBackground.backgroundColor = newColor
    }
    
    
    
    @IBAction func scaleChanged(_ sender: UISlider) {
        self.changesMade = true
        foregroundEdit?.scale = CGFloat(sender.value)
        updateForegroundImage()
    }
    
    @IBAction func horizontalCropChanged(_ sender: UISlider) {
        self.changesMade = true
        foregroundEdit?.horizontalCrop = -CGFloat(sender.value)
        updateForegroundImage()
    }

    @IBAction func verticalCropChanged(_ sender: UISlider) {
        self.changesMade = true
        foregroundEdit?.verticalCrop = -CGFloat(sender.value)
        updateForegroundImage()
    }
    
    @IBAction func yPositionChanged(_ sender: UISlider) {
        self.changesMade = true
        let slider = -CGFloat(sender.value)
        let height = blurBackground.frame.height
        let yOffset = height * slider
        
        let previousX = translationView.transform.tx
        translationView.transform = CGAffineTransform(translationX: previousX, y: yOffset)
        centerImageButtonIsVisible(true)
    }
    
    @IBAction func xPositionChanged(_ sender: UISlider) {
        self.changesMade = true
        let slider = CGFloat(sender.value)
        let width = blurBackground.frame.width
        let xOffset = width * slider
        
        let previousY = translationView.transform.ty
        translationView.transform = CGAffineTransform(translationX: xOffset, y: previousY)
        centerImageButtonIsVisible(true)
    }
    
    @IBAction func centerImage(_ sender: AnyObject) {
        centerImageButtonIsVisible(false)
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
            self.xSlider.setValue(0.0, animated: true)
            self.ySlider.setValue(0.0, animated: true)
            self.translationView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    func centerImageButtonIsVisible(_ visible: Bool) {
        UIView.animate(withDuration: 0.2, animations: {
            self.centerImageButton.alpha = visible ? 1.0 : 0.0
            self.centerImageButton.transform = CGAffineTransform(scaleX: visible ? 1.0 : 0.5, y: visible ? 1.0 : 0.5)
        })
    }
    
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    var transformBeforePan: CGPoint?
    @IBAction func panDetected(_ sender: UIPanGestureRecognizer) {
        if self.statusBarDarkHeight.constant != 0.0 { return } //return if in share sheet
        
        if let translationView = self.translationView {
            
            if sender.state == .began {
                transformBeforePan = CGPoint(x: translationView.transform.tx, y: translationView.transform.ty)
            }
            
            if let transformBeforePan = transformBeforePan {
                let translation = sender.translation(in: translationView)
                let newTransform = CGPoint(x: translation.x + transformBeforePan.x, y: translation.y + transformBeforePan.y)
                translationView.transform = CGAffineTransform(translationX: newTransform.x, y: newTransform.y)
                
                //adjust sliders
                let ySliderValue = newTransform.y / blurBackground.frame.width
                ySlider.value = -Float(ySliderValue)
                let xSliderValue = newTransform.x / blurBackground.frame.width
                xSlider.value = Float(xSliderValue)
            }
        }
        
        if sender.state == .ended {
            transformBeforePan = nil
        }
        
        centerImageButtonIsVisible(true)
    }
    
    var scaleBeforePinch: CGFloat?
    @IBAction func scaleDetected(_ sender: UIPinchGestureRecognizer) {
        if self.statusBarDarkHeight.constant != 0.0 { return } //return if in share sheet
        
        if let foregroundEdit = self.foregroundEdit {
            
            if sender.state == .began {
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
        
        if sender.state == .ended {
            scaleBeforePinch = nil
        }
    }
    
    //pragma MARK: - Export
    
    private func showImageActivityIndicator() {
        guard self.activityIndicator.alpha == 0.0 else {
            return
        }
        
        //animate activity indicator
        view.bringSubview(toFront: exportGray)
        view.bringSubview(toFront: activityIndicator)
        view.bringSubview(toFront: shareContainer)
        indicatorPosition.constant = 40
        self.view.layoutIfNeeded()
        indicatorPosition.constant = 0
        
        UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [], animations: {
            self.view.layoutIfNeeded()
            self.activityIndicator.alpha = 1.0
            self.exportGray.alpha = 1.0
        }, completion: nil)
    }
    
    private func hideImageActivityIndicator() {
        UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [], animations: {
            self.activityIndicator.alpha = 0.0
            self.exportGray.alpha = 0.0
        })
    }
    
    @IBAction func downloadButtonPressed(_ sender: AnyObject) {
        
        self.view.isUserInteractionEnabled = false
        showImageActivityIndicator()
        
        backgroundQueue.async(execute: {
            
            //create image asynchronously
            let image = self.createImage()
            
            //write data now so it doesn't have to be done later
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsURL = URL(fileURLWithPath: paths[0])
            let savePath = documentsURL.appendingPathComponent("export.igo")
            let savePath2 = documentsURL.appendingPathComponent("export.png")
            let imageData = UIImagePNGRepresentation(image)!
            let success1 = (try? imageData.write(to: URL(fileURLWithPath: savePath.path), options: [.atomic])) != nil
            let success2 = (try? imageData.write(to: URL(fileURLWithPath: savePath2.path), options: [.atomic])) != nil
            
            let statusBarHeight = DispatchQueue.main.sync { self.statusBarBlur.frame.height }
            let imageHeight = DispatchQueue.main.sync { self.view.frame.width }
            
            let shareSheetTop = (statusBarHeight + imageHeight) - 10.0
            let arrayObject: [AnyObject] = [image, self, shareSheetTop as AnyObject]
            NotificationCenter.default.post(name: Notification.Name(rawValue: IBPassImageNotification), object: arrayObject)
            
            DispatchQueue.main.sync(execute: {
                
                self.view.isUserInteractionEnabled = true
                
                let success = success1 && success2
                if !success {
                    //there wasn't enough disk space to save the images
                    let alert = UIAlertController(title: "Your storage space is full.", message: "There wasn't enough disk space to process the image.", preferredStyle: .alert)
                    let ok = UIAlertAction(title: "ok", style: .default, handler: { action in
                        UIView.animate(withDuration: 0.5, animations: {
                            self.activityIndicator.alpha = 0.0
                            self.exportGray.alpha = 0.0
                        })
                    })
                    alert.addAction(ok)
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                
                self.shareSheetOpen = true
                
                //animate change in staus bar buttons
                self.cancelButton.setImage(UIImage(named: "cancel-100 (white)"), for: UIControlState())
                self.playFadeTransitionForView(self.cancelButton, duration: 0.45)
                
                self.hideImageActivityIndicator()
                
                UIView.animate(withDuration: 0.45, animations: {
                    self.downloadButton.alpha = 0.0
                    self.setNeedsStatusBarAppearanceUpdate()
                })
                
                UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [], animations: {
                    
                    self.statusBarDarkHeight.constant = self.statusBarBlur.frame.height
                    self.shareSheetPosition.constant = -10.0
                    self.view.layoutIfNeeded()
                    if iPad() { self.blur.effect = UIBlurEffect(style: .dark) }
                    
                }, completion: nil)
                
            })
            
        })
    }
    
    @objc func closeShareSheet() {
        
        shareSheetOpen = false
        
        //animate change in staus bar buttons
        self.cancelButton.setImage(UIImage(named: "cancel-100 (black)"), for: UIControlState())
        self.playFadeTransitionForView(self.cancelButton, duration: 0.45)
        UIView.animate(withDuration: 0.45, animations: {
            self.downloadButton.alpha = 1.0
        })
        
        
        hideImageActivityIndicator()
        
        UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            
            self.shareSheetPosition.constant = self.controlsSuperview.frame.height
            self.statusBarDarkHeight.constant = 0.0
            self.view.layoutIfNeeded()
            if iPad() { self.blur.effect = UIBlurEffect(style: .extraLight) }
            self.activityIndicator.alpha = 0.0
            self.exportGray.alpha = 0.0
            
            self.setNeedsStatusBarAppearanceUpdate()
            
        }, completion: nil)
    }
    
    
    func createFillRect(aspectFill: Bool, originalSize: CGSize, squareArea: CGRect) -> CGRect {
        let fillRect: CGRect
        
        let isTallerThanWide = originalSize.width < originalSize.height
        
        if originalSize.width == originalSize.height {
            fillRect = squareArea
        }
        else if (aspectFill ? isTallerThanWide : !isTallerThanWide) {
            let downWidth = squareArea.width
            let proportion = downWidth / originalSize.width
            let downHeight = proportion * originalSize.height
            let fillSize = CGSize(width: downWidth, height: downHeight)
            
            let heightDiff = fillSize.height - squareArea.height
            let yOffset = -heightDiff / 2
            let fillOrigin = CGPoint(x: squareArea.origin.x, y: squareArea.origin.y + yOffset)
            fillRect = CGRect(origin: fillOrigin, size: fillSize)
        }
        else {// if originalSize.width > originalSize.height {
            let downHeight = squareArea.height
            let proportion = downHeight / originalSize.height
            let downWidth = proportion * originalSize.width
            let fillSize = CGSize(width: downWidth, height: downHeight)
            
            let widthDiff = fillSize.width - squareArea.width
            let xOffset = -widthDiff / 2
            let fillOrigin = CGPoint(x: squareArea.origin.x + xOffset, y: squareArea.origin.y)
            fillRect = CGRect(origin: fillOrigin, size: fillSize)
        }
        
        return fillRect
    }
    
    func createImage() -> UIImage {
        
        UIGraphicsBeginImageContext(CGSize(width: 2000, height: 2000))
        let context = UIGraphicsGetCurrentContext()
        
        //draw background on to context @1.2x
        let backgroundRect = CGRect(x: -200, y: -200, width: 2400, height: 2400)
        
        //fill background color
        let backgroundColor = DispatchQueue.main.sync { blurBackground.backgroundColor ?? .white }
        context?.setFillColor(backgroundColor.cgColor)
        context?.fill(backgroundRect)
        
        let alpha = DispatchQueue.main.sync { customBlur.alpha }
        let imageToBlur = self.selectedImage!
        
        let blurredBackground = blurImage(imageToBlur, withRadius: self.currentBlurRadius)
        let correctBackground = UIImage(ciImage: CIImage(cgImage: blurredBackground.cgImage!), scale: blurredBackground.scale, orientation: self.selectedImage!.imageOrientation)
        let backgroundFillRect = createFillRect(aspectFill: true, originalSize: imageToBlur.size, squareArea: backgroundRect)
        correctBackground.draw(in: backgroundFillRect, blendMode: CGBlendMode.normal, alpha: alpha)
        
        //process foregroud
        let foreground: UIImage
        if let croppedImage = foregroundEdit?.processedImage {
            foreground = croppedImage
        } else { foreground = self.selectedImage! }
        
        //figure out square rect for foreground
        let baseRect = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        
        //processScale
        let scale: CGFloat
        if let customScale = foregroundEdit?.scale {
            scale = customScale
        }
        else { scale = 1.0}
        
        let scaledSize = CGSize(width: baseRect.width * scale, height: baseRect.height * scale)
        let sizeDiff = scaledSize.width - baseRect.width //is always square
        let offset = -sizeDiff / 2
        let scaledOrigin = CGPoint(x: offset, y: offset)
        let scaledRect = CGRect(origin: scaledOrigin, size: scaledSize)
        
        //process position
        let backgroundFrame = DispatchQueue.main.sync { blurBackground.frame }
        let translationTransform = DispatchQueue.main.sync { translationView.transform }
        let xSlider = translationTransform.tx / backgroundFrame.width
        let ySlider = translationTransform.ty / backgroundFrame.height
        
        let finalRect = scaledRect.offsetBy(dx: xSlider * 2000, dy: ySlider * 2000)
        
        let foregroundFillRect = createFillRect(aspectFill: false, originalSize: foreground.size, squareArea: finalRect)
        foreground.draw(in: foregroundFillRect, blendMode: CGBlendMode.normal, alpha: 1.0)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}

class ImageCell : UICollectionViewCell {
    
    @IBOutlet weak var bottom: UIImageView!
    
    func decorate(_ image: UIImage) {
        bottom.image = image
    }
    
    func playLaunchAnimation(_ delay: Double) {
        
        self.transform = CGAffineTransform(scaleX: 0.65, y: 0.65).translatedBy(x: 0, y: 60)
        self.bottom.alpha = 0.0
        
        UIView.animate(
            withDuration: 0.65,
            delay: delay,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0.0,
            options: [],
            animations: {
                self.transform = .identity
                self.bottom.alpha = 1.0
            })
        
    }
    
    
}

