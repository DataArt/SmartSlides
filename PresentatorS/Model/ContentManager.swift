//
//  ContentManager.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/24/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import Foundation

enum DirectoryType: Int {
    case Shared = 0
    case Imported = 1
    case Dropbox = 2
}

class ContentManager: NSObject {
    typealias PresentationUpdate = (PresentationState) -> ()
    typealias StopSharingType = () -> Void
    
    class var sharedInstance: ContentManager {
        struct Static {
            static let instance = ContentManager()
        }
        return Static.instance
    }
    
    struct PresentationState{
        var presentationName = ""
        var currentSlide = UInt(0)
        var slidesAmount = 0
        
        init(name: String, page: UInt, amount: Int){
            presentationName = name
            currentSlide = page
            slidesAmount = amount
        }
    }
    
    var presentationUpdateClosure: PresentationUpdate?
    var onStopSharingClosure: StopSharingType?
    var onStartSharingClosure: PresentationUpdate?
    
    private var activePresentation: PresentationState?
    
    func startShowingPresentation(name: String, page: UInt, slidesAmount : Int){
        self.activePresentation = PresentationState(name: name, page: page, amount: slidesAmount)
        
        if let presentation = self.activePresentation {
            self.onStartSharingClosure?(presentation)
        }
    }
    
    func stopShatingPresentation(){
        self.activePresentation = nil
        self.onStopSharingClosure?()
    }
    
    func updateActivePresentationPage(page: UInt){
        let shouldNotifyPageChange = self.activePresentation?.currentSlide != page
        self.activePresentation?.currentSlide = page
        
        if let present = self.activePresentation {
            if shouldNotifyPageChange {
                self.presentationUpdateClosure?(present)
            }
        }
    }
    
    func getActivePresentationState() -> PresentationState? {
        let state = self.activePresentation
        return state
    }
    
    func getSharedMaterials() -> [String]{
        if let name = self.activePresentation?.presentationName {
            let pathToPresentation = NSURL.CM_pathForPresentationWithName(name)
            let file = File(fullPath: pathToPresentation?.path ?? "")
            let crc = file.md5 as String
            let sharedString = "\(name)/md5Hex=\(crc)"
            if self.activePresentation?.presentationName != nil {
                return [sharedString]
            } else {
                return []
            }
        }
        return []
    }
    
//    func getControllerPeer() -> MCPeerID{
//        
//        return nil
//    }
    
    func getLocalResources() -> [String]?{
        let homeDirPath = NSURL.CM_fileURLToSharedPresentationDirectory().path!
        let content : [String]?
        
        do {
            try content = NSFileManager.defaultManager().contentsOfDirectoryAtPath(homeDirPath) as [String]?
            return content?.map {$0.stringByReplacingOccurrencesOfString(homeDirPath, withString: "", options: [], range: nil)}
        } catch {
            print("Error fetching content from \(homeDirPath)")
            
            return nil
        }
    }
    
    func isResourceAvailable(presentation: String, directoryType: DirectoryType) -> Bool {
        if directoryType == .Dropbox {
            if NSURL.CM_pathForPresentationWithName(presentation) != nil {
                return true
            } else {
                return false
            }
        } else {
            var array : [String] = presentation.componentsSeparatedByString("/md5Hex=")
            if array.count > 1 {
                let name = array[0]
                let crc = array[1]
                
                let pathToPresentation = NSURL.CM_pathForPresentationWithName(name)
                let file = File(fullPath: pathToPresentation?.path ?? "")
                if (crc == file.md5 && file.md5.characters.count > 0) {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    //Json Helper
    func JSONStringify(value: AnyObject, prettyPrinted: Bool = false) -> String {
        let options = prettyPrinted ? NSJSONWritingOptions.PrettyPrinted : NSJSONWritingOptions(rawValue: 0)
        if NSJSONSerialization.isValidJSONObject(value) {
            if let data = try? NSJSONSerialization.dataWithJSONObject(value, options: options) {
                if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
                    return string as String
                }
            }
        }
        
        return ""
    }
}

extension NSURL {
    class func CM_fileURLToSharedPresentationDirectory() -> NSURL{
        let documentDirectoryPath: String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        return NSURL(fileURLWithPath: documentDirectoryPath)
    }
    
    class func CM_fileURLToImportedPresentationDirectory() -> NSURL{
        let documentDirectoryURL = CM_fileURLToSharedPresentationDirectory()
        
        return documentDirectoryURL.URLByAppendingPathComponent("Inbox", isDirectory: true)
    }
    
    class func CM_fileURLToDropboxPresentationDirectory() -> NSURL{
        let dropboxDirectoryURL = CM_fileURLToSharedPresentationDirectory().URLByAppendingPathComponent("Dropbox", isDirectory: true)
        
        let isDir = UnsafeMutablePointer<ObjCBool>.alloc(1)
        isDir[0] = true
        
        if !NSFileManager.defaultManager().fileExistsAtPath(dropboxDirectoryURL.path!, isDirectory: isDir) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(dropboxDirectoryURL, withIntermediateDirectories: false, attributes: nil)
            } catch let err as NSError {
                print("Error creating folder \(err)")
            }
        }
        return dropboxDirectoryURL
    }
    
    class func CM_pathForPresentationWithName(presentationName: String) -> NSURL? {
        let result = CM_fileURLToSharedPresentationDirectory().URLByAppendingPathComponent(presentationName)
        if NSFileManager.defaultManager().fileExistsAtPath(result.path!) {
            return result
        } else {
            let resultFromImported = CM_fileURLToImportedPresentationDirectory().URLByAppendingPathComponent(presentationName)
            if NSFileManager.defaultManager().fileExistsAtPath(resultFromImported.path!) {
                return resultFromImported
            } else {
                let resultFromDropbox = CM_fileURLToDropboxPresentationDirectory().URLByAppendingPathComponent(presentationName)
                if NSFileManager.defaultManager().fileExistsAtPath(resultFromDropbox.path!) {
                    return resultFromDropbox
                }
            }
        }
        return nil
    }
    
    class func CM_pathForFramedPresentationDir(presentationURL: NSURL) -> String {
        var presentationName = presentationURL.lastPathComponent!
        
        if let pathComponents : [String]? = presentationURL.pathComponents {
            if pathComponents!.contains("Inbox") {
                presentationName = "Inbox_" + presentationName
            }
        }
        var framedPresentationDirectoryName = presentationName.stringByReplacingOccurrencesOfString(".", withString: "_", options: [], range: nil)
        framedPresentationDirectoryName = framedPresentationDirectoryName.stringByReplacingOccurrencesOfString(" ", withString: "_", options: [], range: nil)
        
        return NSTemporaryDirectory() + framedPresentationDirectoryName
    }
}

