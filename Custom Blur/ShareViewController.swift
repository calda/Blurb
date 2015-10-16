//
//  ShareViewController.swift
//  Custom Blur
//
//  Created by Cal on 6/26/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import Foundation
import UIKit

let IBCloseShareSheetNotification = "com.cal.instablur.close-share-sheet"
let IBPassImageNotification = "com.cal.instablur.pass-share-image"

class ShareViewController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIDocumentInteractionControllerDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewTop: NSLayoutConstraint!
    var imageToSave: UIImage!
    var document: UIDocumentInteractionController!
    var showIconText = true
    
    let order: [(name: String, function: ShareViewController -> (UIImage) -> ())] = [
        ("Camera Roll", saveToCameraRoll),
        ("Instagram", copyToInstagram),
        ("Other App", otherApp)
    ]

    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receiveImage:", name: IBPassImageNotification, object: nil)
    }
    
    func receiveImage(notification: NSNotification) {
        dispatch_sync(dispatch_get_main_queue(), {
            let array = notification.object as! [AnyObject]
            
            if let image = array[0] as? UIImage {
                self.imageToSave = image
            }
            
            //do check for 4S
            if is4S() { //is 4S
                self.showIconText = false
                self.collectionView.reloadData()
                return
            }
            
            //center icons in sheet
            if let topPosition = array[1] as? CGFloat {
                let canvasTop = topPosition + 30.0
                let canvasHeight = UIScreen.mainScreen().bounds.height - canvasTop
                
                let width = self.collectionView.frame.width
                let cellHeight = width / 3.0
                let availableCanvas = canvasHeight - cellHeight
                
                let centerOffset = availableCanvas / 3.0
                self.collectionView.contentInset = UIEdgeInsets(top: centerOffset, left: 0.0, bottom: 0.0, right: 0.0)
            }
        })
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("icon", forIndexPath: indexPath) as! IconCell
        let cellName = order[indexPath.item].name
        cell.decorate(cellName, showText: showIconText)
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return order.count
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let width = UIScreen.mainScreen().bounds.width
        let cellWidth = width / 3.0
        return CGSizeMake(cellWidth, cellWidth)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let item = indexPath.item
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! IconCell
        cell.gray()
        order[item].function(self)(imageToSave)
    }
    
    func ungrayAll() {
        for cell in collectionView.visibleCells() {
            if let cell = cell as? IconCell {
                cell.decorate(cell.name.text!, showText: showIconText)
            }
        }
    }
    
    //pragma MARK: - Service Saving Functions
    
    func saveToCameraRoll(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, "cameraRollComplete:finishedSavingWithError:contextInfo:", nil)
    }
    
    func cameraRollComplete(image: UIImage, finishedSavingWithError error: NSError, contextInfo: UnsafeMutablePointer<Void>) {
        let alert = UIAlertController(title: "Saved to Camera Roll", message: nil, preferredStyle: .Alert)
        let ok = UIAlertAction(title: "ok", style: UIAlertActionStyle.Default, handler: { success in
            self.ungrayAll()
        })
        alert.addAction(ok)
        self.presentViewController(alert, animated: true, completion: nil)
        
    }
 
    func copyToInstagram(image: UIImage) {
        delay(0.1) {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            var savePath = paths[0]
            savePath.appendContentsOf("/export.igo")
            
            self.document = UIDocumentInteractionController(URL: NSURL(string: "file://\(savePath)")!)
            self.document.annotation = ["InstagramCaption" : "#instaBlur"]
            self.document.UTI = "com.instagram.exclusivegram"
            self.document.delegate = self
            self.document.presentOpenInMenuFromRect(self.view.frame, inView: self.view, animated: true)
            delay(0.2) {
                self.ungrayAll()
            }
        }
    }
    
    func otherApp(image: UIImage) {
        delay(0.1) {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            var savePath = paths[0]
            savePath.appendContentsOf("/export.png")
            
            self.document = UIDocumentInteractionController(URL: NSURL(string: "file://\(savePath)")!)
            self.document.presentOpenInMenuFromRect(self.view.frame, inView: self.view, animated: true)
            delay(0.2) {
                self.ungrayAll()
            }
        }
    }
    
    @IBAction func close(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(IBCloseShareSheetNotification, object: nil)
    }
}

class IconCell : UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var name: UILabel!
    
    func decorate(name: String, showText: Bool) {
        self.name.hidden = !showText
        self.name.text = name
        self.image.image = UIImage(named: name)
    }
    
    func gray() {
        self.image.image = UIImage(named: "\(name.text!) gray")
    }
    
}

///returns trus if the current device is an iPad
func iPad() -> Bool {
    return UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad
}

///returns trus if the current device is an iPhone 4S
func is4S() -> Bool {
    return UIScreen.mainScreen().bounds.height == 480.0
}
