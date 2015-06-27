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
    var imageToSave: UIImage!
    var document: UIDocumentInteractionController!
    
    let order: [(name: String, function: ShareViewController -> (UIImage) -> ())] = [
        ("Camera Roll", saveToCameraRoll),
        ("Instagram", copyToInstagram),
        ("Other App", otherApp)
    ]

    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receiveImage:", name: IBPassImageNotification, object: nil)
    }
    
    func receiveImage(notification: NSNotification) {
        if let image = notification.object as? UIImage {
            imageToSave = image
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("icon", forIndexPath: indexPath) as! IconCell
        let cellName = order[indexPath.item].name
        cell.decorate(cellName)
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
        order[item].function(self)(imageToSave)
    }
    
    //pragma MARK: - Service Saving Functions
    
    func saveToCameraRoll(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
 
    func copyToInstagram(image: UIImage) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsPath = paths[0]
        let savePath = documentsPath.stringByAppendingPathComponent("export.igo")
        let imageData = UIImagePNGRepresentation(image)!
        imageData.writeToFile(savePath, atomically: true)
        
        document = UIDocumentInteractionController(URL: NSURL(fileURLWithPath: "file://\(savePath)"))
        document.annotation = ["InstagramCaption" : "#instaBlur"]
        document.UTI = "com.instagram.exclusivegram"
        document.delegate = self
        document.presentOpenInMenuFromRect(self.view.frame, inView: self.view, animated: true)
    }
    
    func otherApp(image: UIImage) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsPath = paths[0]
        let savePath = documentsPath.stringByAppendingPathComponent("export.png")
        let imageData = UIImagePNGRepresentation(image)!
        imageData.writeToFile(savePath, atomically: true)
        
        document = UIDocumentInteractionController(URL: NSURL(fileURLWithPath: "file://\(savePath)"))
        document.presentOpenInMenuFromRect(self.view.frame, inView: self.view, animated: true)
    }
    
    @IBAction func close(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(IBCloseShareSheetNotification, object: nil)
    }
}

class IconCell : UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var name: UILabel!
    
    func decorate(name: String) {
        self.name.text = name
        self.image.image = UIImage(named: name)
    }
    
}