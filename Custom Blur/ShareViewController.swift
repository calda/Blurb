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
    var controller: ViewController?
    
    let order: [(name: String, function: (ShareViewController) -> (UIImage) -> ())] = [
        ("Camera Roll", saveToCameraRoll),
        ("Instagram", copyToInstagram),
        ("Other App", otherApp)
    ]

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(ShareViewController.receiveImage(_:)), name: NSNotification.Name(rawValue: IBPassImageNotification), object: nil)
    }
    
    @objc func receiveImage(_ notification: Notification) {
        DispatchQueue.main.sync(execute: {
            let array = notification.object as! [AnyObject]
            
            if let image = array[0] as? UIImage {
                self.imageToSave = image
            }
            
            if let controller = array[1] as? ViewController {
                self.controller = controller
            }
            
            //center icons in sheet
            if let topPosition = array[2] as? CGFloat {
                let canvasTop = topPosition + 30.0
                let canvasHeight = UIScreen.main.bounds.height - canvasTop
                
                let width = self.collectionView.frame.width
                let cellHeight = width / 3.0
                let availableCanvas = canvasHeight - cellHeight
                
                let centerOffset = availableCanvas / 3.0
                self.collectionView.contentInset = UIEdgeInsets(top: centerOffset, left: 0.0, bottom: 0.0, right: 0.0)
            }
        })
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "icon", for: indexPath) as! IconCell
        let cellName = order[indexPath.item].name
        cell.decorate(cellName)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return order.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = UIScreen.main.bounds.width
        let cellWidth = width / 3.0
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = indexPath.item
        let cell = collectionView.cellForItem(at: indexPath) as! IconCell
        cell.gray()
        order[item].function(self)(imageToSave)
    }
    
    func ungrayAll() {
        for cell in collectionView.visibleCells {
            if let cell = cell as? IconCell {
                cell.decorate(cell.name.text!)
            }
        }
    }
    
    //pragma MARK: - Service Saving Functions
    
    func saveToCameraRoll(_ image: UIImage) {
        Event.photoExported(destination: .cameraRoll).record()
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(ShareViewController.cameraRollComplete(_:finishedSavingWithError:contextInfo:)), nil)
    }
    
    @objc func cameraRollComplete(_ image: UIImage, finishedSavingWithError error: NSError, contextInfo: UnsafeMutableRawPointer) {
        let alert = UIAlertController(title: "Saved to Camera Roll", message: nil, preferredStyle: .alert)
        let ok = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { success in
            self.ungrayAll()
        })
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
        
    }
 
    func copyToInstagram(_ image: UIImage) {
        
        Event.photoExported(destination: .instagram).record()
        
        if !UIApplication.shared.canOpenURL(URL(string: "instagram://location?id=1")!) {
            self.ungrayAll()
            
            //show alert if Instagram is not installed
            let alert = UIAlertController(title: "Instagram Not Installed", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open in App Store", style: .default, handler: { _ in
                let link = "itms://itunes.apple.com/us/app/instagram/id389801252?mt=8"
                UIApplication.shared.openURL(URL(string: link)!)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            UIApplication.shared.windows[0].rootViewController?.present(alert, animated: true, completion: nil)
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            var savePath = paths[0]
            savePath.append("/export.igo")
            
            self.document = UIDocumentInteractionController(url: URL(string: "file://\(savePath)")!)
            self.document.annotation = ["InstagramCaption" : "Made with #Blurb"]
            self.document.uti = "com.instagram.exclusivegram"
            self.document.delegate = self
            self.document.presentOpenInMenu(from: self.view.frame, in: self.view, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                self.ungrayAll()
            }
        }
    }
    
    func otherApp(_ image: UIImage) {
        Event.photoExported(destination: .other).record()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            
            let shareSheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            self.controller?.present(shareSheet, animated: true, completion: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                self.ungrayAll()
            }
        }
    }
    
    @IBAction func close(_ sender: AnyObject) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: IBCloseShareSheetNotification), object: nil)
    }
}

class IconCell : UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var name: UILabel!
    
    func decorate(_ name: String) {
        self.name.text = name
        self.image.image = UIImage(named: name)
    }
    
    func gray() {
        self.image.image = UIImage(named: "\(name.text!) gray")
    }
    
}

///returns trus if the current device is an iPad
func iPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad
}
