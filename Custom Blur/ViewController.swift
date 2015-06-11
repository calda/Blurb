//
//  ViewController.swift
//  Custom Blur
//
//  Created by Cal on 6/10/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var imageManager = PHImageManager()
    var fetch: PHFetchResult?
    
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet weak var blur: UIVisualEffectView!
    
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
    
    func displayThumbnails() {
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetch = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: options)
        
        if fetch == nil {
            //no permissions
        }
        
        collectionView.reloadData()
        
    }
    
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
        let cellWidth = collectionWidth / 3.0
        let cellSize = CGSizeMake(cellWidth, cellWidth)
        
        imageManager.requestImageForAsset(asset, targetSize: cellSize, contentMode: PHImageContentMode.AspectFill, options: nil, resultHandler: { result, info in
        
            if let result = result {
                cell.decorate(result)
            }
            
        })
        return cell
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let width = collectionView.frame.width
        let count = CGFloat(3.0)
        let cellWidth = width / count
        return CGSizeMake(cellWidth, cellWidth)
    }
    

}

class ImageCell : UICollectionViewCell {
    
    @IBOutlet weak var bottom: UIImageView!
    
    func decorate(image: UIImage) {
        bottom.image = image
    }
    
    
}

