//
//  ShareViewController.swift
//  Custom Blur
//
//  Created by Cal on 6/26/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import Foundation
import UIKit

let IBPassImageNotification = "com.cal.instablur.pass-share-image"

class ShareViewController : UIViewController, UIDocumentInteractionControllerDelegate {
    
    @IBOutlet weak var shareLabel: UILabel!
    @IBOutlet weak var optionsStackView: UIStackView!
    
    @IBOutlet weak var saveLabel: UILabel!
    @IBOutlet weak var saveImageView: UIImageView!
    @IBOutlet weak var instagramView: UIView!
    @IBOutlet weak var instagramLabel: UILabel!
    @IBOutlet weak var instagramImageView: UIImageView!
    @IBOutlet weak var otherLabel: UILabel!
    @IBOutlet weak var otherImageView: UIImageView!
    
    private func views(for destination: ExportDestination) -> (label: UILabel, imageView: UIImageView) {
        switch destination {
        case .cameraRoll: return (saveLabel, saveImageView)
        case .instagram: return (instagramLabel, instagramImageView)
        case .other: return (otherLabel, otherImageView)
        }
    }
    
    var imageToSave: UIImage!
    var document: UIDocumentInteractionController!
    var controller: ViewController?

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(ShareViewController.receiveImage(_:)), name: NSNotification.Name(rawValue: IBPassImageNotification), object: nil)
        
        shareLabel.text = NSLocalizedString("Share", comment: "Title for panel where user can share their edited image")
        optionsStackView.spacing = iPad() ? 60 : 30
        
        for destination in ExportDestination.all {
            let (label, imageView) = views(for: destination)
            label.text = destination.interfaceString
            imageView.image = destination.image(selected: false)
        }
        
        // Instagram is blocked in China, so don't show it as an option
        if Locale.current.languageCode == "zh" {
            instagramView.isHidden = true
        }
    }
    
    @objc func receiveImage(_ notification: Notification) {
        DispatchQueue.main.sync(execute: {
            
            view.layoutIfNeeded()
            
            let array = notification.object as! [AnyObject]
            
            if let image = array[0] as? UIImage {
                self.imageToSave = image
            }
            
            if let controller = array[1] as? ViewController {
                self.controller = controller
            }
            
        })
    }
    
    // MARK: User Interaction
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, commitAction: false)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, commitAction: false)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, commitAction: true)
    }
    
    func handleTouches(_ touches: Set<UITouch>, commitAction: Bool) {
        guard let touch = touches.first else { return }
        
        for destination in ExportDestination.all {
            let imageView = views(for: destination).imageView
            let touchInView = imageView.bounds.contains(touch.location(in: imageView))
            imageView.image = destination.image(selected: touchInView && !commitAction)
            
            if commitAction, touchInView, let image = imageToSave {
                switch destination {
                case .cameraRoll: saveToCameraRoll(image)
                case .instagram: copyToInstagram(image)
                case .other: otherApp(image)
                }
            }
        }
    }
    
    //pragma MARK: - Service Saving Functions
    
    func saveToCameraRoll(_ image: UIImage) {
        Event.photoExported(destination: .cameraRoll).record()
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(ShareViewController.cameraRollComplete(_:finishedSavingWithError:contextInfo:)), nil)
    }
    
    @objc func cameraRollComplete(_ image: UIImage, finishedSavingWithError error: NSError, contextInfo: UnsafeMutableRawPointer) {
        let alert = UIAlertController(
            title: NSLocalizedString("Saved to Photo Library",
                comment: "Alert title confirming photo was saved to the system photo library"),
            message: nil,
            preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        self.present(alert, animated: true, completion: nil)
    }
 
    func copyToInstagram(_ image: UIImage) {
        
        Event.photoExported(destination: .instagram).record()
        
        if !UIApplication.shared.canOpenURL(URL(string: "instagram://location?id=1")!) {
            //show alert if Instagram is not installed
            let alert = UIAlertController(
                title: NSLocalizedString("Instagram Not Installed",
                    comment: "Alert title for when Instagram is not installed on the user's device"),
                message: nil,
                preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Open in App Store",
                    comment: "Button title to show the App Store product page for Instagram"),
                style: .default,
                handler: { _ in
                    let link = "itms-apps://itunes.apple.com/us/app/instagram/id389801252?mt=8"
                    UIApplication.shared.openURL(URL(string: link)!)
            }))
            
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Cancel", comment: "Alert cancel button"),
                style: .cancel,
                handler: nil))
            
            UIApplication.shared.windows[0].rootViewController?.present(alert, animated: true, completion: nil)
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            var savePath = paths[0]
            savePath.append("/export.igo")
            
            self.document = UIDocumentInteractionController(url: URL(string: "file://\(savePath)")!)
            self.document.annotation = ["InstagramCaption" : "Made with #Blur"]
            self.document.uti = "com.instagram.exclusivegram"
            self.document.delegate = self
            
            self.document.presentOpenInMenu(
                from: self.view.convert(self.instagramImageView.bounds, from: self.instagramImageView),
                in: self.view,
                animated: true)
        }
    }
    
    func otherApp(_ image: UIImage) {
        Event.photoExported(destination: .other).record()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            
            let shareSheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            shareSheet.popoverPresentationController?.sourceView = self.otherImageView
            shareSheet.popoverPresentationController?.sourceRect = self.otherImageView.bounds
            self.controller?.present(shareSheet, animated: true, completion: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                //self.ungrayAll()
            }
        }
    }
    
}

// MARK: ExportDestination

enum ExportDestination: String {
    
    case cameraRoll
    case instagram
    case other
    
    static var all: [ExportDestination] {
        return [.cameraRoll, .instagram, .other]
    }
    
    var interfaceString: String {
        switch self {
        case .cameraRoll: return NSLocalizedString("Save Image", comment: "Button label for exporting to the system photos app")
        case .instagram: return NSLocalizedString("Instagram", comment: "Button label for exporting to Instagram")
        case .other: return NSLocalizedString("Other App", comment: "Button label for exporting to some app other than Instagram or the system photos app")
        }
    }
    
    func image(selected: Bool) -> UIImage? {
        let baseName: String
        switch self {
        case .cameraRoll: baseName = "Save Image"
        case .instagram: baseName = "Instagram"
        case .other: baseName = "Other App"
        }
        
        if selected {
            return UIImage(named: "\(baseName) gray")
        } else {
            return UIImage(named: baseName)
        }
    }
    
}

///returns trus if the current device is an iPad
func iPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}
