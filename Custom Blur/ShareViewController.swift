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
            
            //center icons in sheet and detect 4S
            if let main = array[1] as? UIView {
                let size = main.frame.size
                
                let aspect = size.width / size.height
                if aspect > 0.6 || aspect < 0.5 { //is 4S
                    self.showIconText = false
                    self.collectionView.reloadData()
                    return
                }
                
                /*let unavailableHeight = 44.0 + size.width + 30
                let availableHeight = size.height - unavailableHeight
                let iconsHeight = self.collectionView.frame.width / 3.0
                let availableSplit = availableHeight - iconsHeight
                let offset = availableSplit / 4.0
                self.collectionViewTop.constant = offset
                self.collectionView.layoutIfNeeded()*/
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
        let width = collectionView.frame.width
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
            let documentsPath = paths[0]
            let savePath = documentsPath.stringByAppendingPathComponent("export.igo")
            
            self.document = UIDocumentInteractionController(URL: NSURL(fileURLWithPath: "file://\(savePath)"))
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
            let documentsPath = paths[0]
            let savePath = documentsPath.stringByAppendingPathComponent("export.png")
            
            self.document = UIDocumentInteractionController(URL: NSURL(fileURLWithPath: "file://\(savePath)"))
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