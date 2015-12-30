//
//  ProgressView.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/26/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import UIKit
import QuartzCore

typealias KVOContext = UInt8

class LoadableView: UIView {
    
    class func loadFromNibNamed<T: UIView> (nibNamed: String, bundle : NSBundle? = nil) -> T? {
        return UINib(
            nibName: nibNamed,
            bundle: bundle
            ).instantiateWithOwner(nil, options: nil)[0] as? T
    }
    
    class func loadFromNib() -> UIView {
        let name = NSStringFromClass(self).componentsSeparatedByString(".").last!
        return self.loadFromNibNamed(name, bundle: nil)!
    }
    
    class func getPureType() -> String {
        return NSStringFromClass(self).componentsSeparatedByString(".").last!
    }
    
    final func getPureType() -> String {
        return NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last!
    }
    
    override func awakeAfterUsingCoder(aDecoder: NSCoder) -> AnyObject? {
        if self.subviews.count == 0 {
            let contraints = self.constraints
            self.removeConstraints(contraints)
            let result = LoadableView.loadFromNibNamed(self.getPureType(), bundle: nil)
            result?.translatesAutoresizingMaskIntoConstraints = false
            result?.addConstraints(contraints)
            result?.hidden = self.hidden
            return result
        }
        return self
    }
}

class ProgressView: LoadableView {
    
    @IBOutlet weak var placeholderView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    
    private var MyObservationContext = KVOContext()
    
    private var _progress: NSProgress?
    var progress: NSProgress? {
        set {
            _progress?.removeObserver(self, forKeyPath: "fractionCompleted", context: &MyObservationContext)
            _progress = newValue
            _progress?.addObserver(self, forKeyPath: "fractionCompleted", options: .Initial, context: &MyObservationContext)
//            _progress?.becomeCurrentWithPendingUnitCount(1)
            
            if let _ = _progress {
//                self.label.hidden = false
                self.progressView.hidden = false
                progressIndicator.stopAnimating()
            }
            
        }
        
        get { return _progress }
    }
    
    var filename: String? {
//        set { self.label.text = "Loading file \(newValue!)..." }
        get { return "" }
    }
    
    override func awakeFromNib() {
        self.placeholderView.layer.cornerRadius = 10
//        self.label.hidden = true
        self.progressView.hidden = true
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context != &MyObservationContext{
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        } else {
            if keyPath == "fractionCompleted" {
                NSOperationQueue.mainQueue().addOperationWithBlock({ [unowned self] in
                    let progress = object as! NSProgress
                    self.progressView.progress = Float(progress.fractionCompleted)
                })
            }
        }
    }
    
    deinit{
        self.progress = nil
    }
    
}
