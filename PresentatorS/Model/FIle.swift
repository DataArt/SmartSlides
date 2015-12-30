//
//  FIle.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/29/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import UIKit

extension Int {
    func hexString() -> String {
        return NSString(format:"%02x", self) as String
    }
}

extension NSData {
    func md5() -> NSData {
        let ctx = UnsafeMutablePointer<CC_MD5_CTX>.alloc(sizeof(CC_MD5_CTX))
        CC_MD5_Init(ctx);
        
        CC_MD5_Update(ctx, self.bytes, UInt32(self.length));
        let length = Int(CC_MD5_DIGEST_LENGTH) * sizeof(UInt8)
        let output = UnsafeMutablePointer<UInt8>.alloc(length)
        CC_MD5_Final(output, ctx);
        
        let outData = NSData(bytes: output, length: Int(CC_MD5_DIGEST_LENGTH))
        output.destroy()
        ctx.destroy()
        return outData;
    }
    func hexString() -> String {
        var string = String()
        for i in UnsafeBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(bytes), count: length) {
            string += Int(i).hexString()
        }
        return string
    }

}

class File: NSObject {
    
    enum DocumentType: String {
        case Unknown = "unknown", PowerPointPresentation = "pptx", KeynotePresentation = "key"
        
        func getImageNameForType() -> String {
            var result = ""
            
            switch self {
            case .PowerPointPresentation:
                    result = "powerpoint_pres_icon"
            case .KeynotePresentation:
                result = "keynote_pres_icon"
            default:
                result = ""
            }
            return result
        }
    }
    
    let name: String
    let type: DocumentType
    let descriptionText: String
    let fullPath: String
    let md5: String
    
    init(fullPath: String){
        self.fullPath = fullPath
        self.name = ((fullPath as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
        
        let date = (try? NSFileManager.defaultManager().attributesOfItemAtPath(fullPath))?[NSFileCreationDate] as? NSDate
        if let date = date {
            let formatter = NSDateFormatter()
            formatter.dateStyle = .LongStyle
            self.descriptionText = "\(formatter.stringFromDate(date))"
        } else {
            self.descriptionText = ""
        }

        
        if let type = DocumentType(rawValue: (fullPath as NSString).pathExtension){
            self.type = type
        } else {
            self.type = .Unknown
        }
        
        let fileURL = NSURL.fileURLWithPath(fullPath)
        if let data = NSData(contentsOfURL: fileURL) {
            self.md5 = data.md5().hexString()
        } else {
             self.md5 = ""
        }
    }
    
    
}
