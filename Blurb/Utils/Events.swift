//
//  Events.swift
//  Blurb
//
//  Created by Cal Stephens on 11/26/17.
//  Copyright © 2017 Cal. All rights reserved.
//

import Fabric
import Crashlytics
import UIKit

// MARK: Event

enum Event {
    
    case appLaunched
    case photoSelected(source: PhotoSource)
    case photoCreated(blurIndensity: CGFloat, alpha: CGFloat, colorHue: CGFloat)
    case photoExported(destination: ExportDestination)
    
    enum PhotoSource {
        case device
        case iCloudPhotoLibrary(downloadSucceeded: Bool)
        
        var rawValue: String {
            switch self {
            case .device:
                return "Device"
            case .iCloudPhotoLibrary(let downloadSucceeded):
                return "iCloud Photo Library (\(downloadSucceeded ? "Success" : "Failure"))"
            }
        }
    }
    
}

// MARK: Event+Fabric

extension Event {
    
    func record() {
        var customAttributes = self.customAttributes ?? [:]
        customAttributes["User Language"] = Locale.current.languageCode ?? "en"
            
        print("Logged event \(eventName) with \(customAttributes)")
        Answers.logCustomEvent(withName: eventName, customAttributes: customAttributes)
    }
    
    private var eventName: String {
        switch(self) {
        case .appLaunched: return "App Launched"
        case .photoSelected(_): return "Photo Selected"
        case .photoCreated(_, _, _): return "Photo Created"
        case .photoExported(_): return "Photo Exported"
        }
    }
    
    private var customAttributes: [String: Any]? {
        switch(self) {
        case .photoSelected(let source):
            return ["Source": source.rawValue]
        case .photoCreated(let blurIntensity, let alpha, let colorHue):
            return [
                "Blur Intensity": blurIntensity,
                "Alpha": alpha,
                "Color Hue": colorHue]
        case .photoExported(let destination):
            return ["Destination": destination.rawValue]
        default:
            return nil
        }
    }
    
}

extension Bool {
    var stringValue: String {
        return self ? "true" : "false"
    }
}
