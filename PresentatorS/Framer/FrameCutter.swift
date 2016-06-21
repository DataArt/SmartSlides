//
//  FrameCutter.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/19/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import Foundation
import UIKit

protocol FrameCutterInternal{
    static func createWebView() -> UIWebView
    func loadWebView(webView: UIWebView)
    func freeWebView(webView: UIWebView)
    func frameWebContent(webView: UIWebView, callback:(([String]) -> ()))
}

class FrameCutter: NSObject, FrameCutterInternal {
    typealias FramingResult = ([String]) -> Void
    
    private var presentationFileUrl: NSURL
    private var resultClosure: FramingResult?
    private var viewForWebView: UIView?
    private var internalWebView: UIWebView
    
    private let progressView = ProgressView.loadFromNib() as! ProgressView
    
    var fileUrl: NSURL {
        get { return presentationFileUrl }
    }

    var presenterView: UIView {
        get {
            if let viewForWebView = viewForWebView{
                return viewForWebView
            } else if let viewForWebView = UIApplication.sharedApplication().keyWindow{
                return viewForWebView;
            }
            return UIView()
        }
    }
    
    init(fileUrl: NSURL){
        
        presentationFileUrl = fileUrl
        internalWebView = FrameCutter.createWebView()
    }
    
    func startFramingProcess(parentView: UIView?, callback: FramingResult){
        
        let famedPresentationDirectoryPath = getPathToFolderForFamedPresentation()
        
        if NSFileManager.defaultManager().fileExistsAtPath(famedPresentationDirectoryPath){
            let content = (try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(famedPresentationDirectoryPath)) 
            if (content?.count > 0) {
                callback(content!.map({ (famedPresentationDirectoryPath as NSString).stringByAppendingPathComponent($0) }))
            } else {
                do {
                    try NSFileManager.defaultManager().createDirectoryAtPath(famedPresentationDirectoryPath, withIntermediateDirectories: true, attributes: nil)
                } catch _ {
                }
                viewForWebView = parentView
                resultClosure = callback
                loadWebView(internalWebView)
            }
        } else {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(famedPresentationDirectoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
            }
            viewForWebView = parentView
            resultClosure = callback
            loadWebView(internalWebView)
        }
    }
    
    private func getPathToFolderForFamedPresentation() -> String {
        return NSURL.CM_pathForFramedPresentationDir(presentationFileUrl)
    }
    
//MARK: Internal
    internal class func createWebView() -> UIWebView {
        let scaleCoefficient = CGFloat(1.32129037);
        let screenHeight = CGRectGetHeight(UIScreen.mainScreen().bounds)
        let result = UIWebView(frame: CGRectMake(0, 0, screenHeight * scaleCoefficient, screenHeight))
        result.scalesPageToFit = true
        result.autoresizingMask = .None
        return result
    }
    
    internal func freeWebView(webView: UIWebView) {
        webView.delegate = nil
        webView.removeFromSuperview()
        viewForWebView = nil
    }
    
    internal func loadWebView(webView: UIWebView) {
        let parent = self.presenterView
        
        var frame = internalWebView.frame
        frame.origin.x = (CGRectGetWidth(parent.bounds) - CGRectGetWidth(frame)) / 2
        internalWebView.frame = frame
        parent.addSubview(internalWebView)
        
        internalWebView.loadRequest(NSURLRequest(URL: presentationFileUrl))
        internalWebView.delegate = self
        
        self.progressView.frame = parent.bounds
        self.progressView.progressView.hidden = false
        self.progressView.progressView.progress = 0
        parent.addSubview(self.progressView)
    }
    
    internal func frameWebContent(webView: UIWebView, callback: (([String]) -> ())) {
        var currentOffset = CGFloat(0.0)
        let frameSize = internalWebView.bounds.size
        let presentationHeight = internalWebView.scrollView.contentSize.height
        var page = 0
        var totalPages = 0
        if presentationFileUrl.pathExtension == "key" {
            totalPages = Int(ceil(presentationHeight/frameSize.height))
        } else {
            if let slidesCount = webView.stringByEvaluatingJavaScriptFromString("document.getElementsByClassName('slide').length") {
                totalPages = Int(slidesCount)!
            }
        }
        
        print("FRAME CUTTER: total pages = \(totalPages)")
        var result = [String]()
//        let group = dispatch_group_create()
//        let queue = dispatch_queue_create("Saving images queue", nil)
//        
        while page < totalPages {
            let image = takeScreenShot()
//            dispatch_group_async(group, queue, {
            page += 1
            result.append(self.saveImageToTmpDirectory(image, page: page))
            NSOperationQueue.mainQueue().addOperationWithBlock({ [unowned self] in
                let value = CGFloat(page)/CGFloat(totalPages)
                self.progressView.progressView.progress = Float(value)
                })
            //            })
//            currentOffset = ceil(currentOffset + frameSize.height) - CGFloat(page) * 0.08
            currentOffset = ceil(currentOffset + frameSize.height)
            webView.scrollView.scrollRectToVisible(CGRectMake(0, currentOffset, frameSize.width, frameSize.height), animated: false)
        }
        
        webView.scrollView.scrollRectToVisible(CGRectMake(0, 0, 0, 0), animated: false)
        
        self.freeWebView(webView)
        if let callback = self.resultClosure{
            callback(result)
        }
        
        NSOperationQueue.mainQueue().addOperationWithBlock({ [unowned self] in
            self.progressView.removeFromSuperview()
        })
    }
    
    internal func takeScreenShot() -> UIImage{
        UIGraphicsBeginImageContext(internalWebView.bounds.size)
        internalWebView.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    internal func saveImageToTmpDirectory(image: UIImage, page: Int) -> String{
        let resultPath = String(format: "%@/page_%03d.jpg", getPathToFolderForFamedPresentation(), page)
        //println("resultPath \(resultPath)")
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            UIImageJPEGRepresentation(image, 0.9)!.writeToFile(resultPath, atomically: true)
//        })
        return resultPath as String
    }

}

//MARK: WebView Delegate
extension FrameCutter: UIWebViewDelegate{
    func webViewDidFinishLoad(webView: UIWebView) {
        frameWebContent(webView, callback: {
            if let callback = self.resultClosure{ callback($0) }
        })
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        print("FRAMECUTTER: didFailLoadWithError \(error)")
        if let callback = self.resultClosure{ callback([]) }
    }
}
