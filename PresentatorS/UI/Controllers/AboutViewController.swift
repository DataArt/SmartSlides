//
//  AboutViewController.swift
//  PresentatorS
//
//  Created by Roman Ivchenko on 12/8/15.
//  Copyright © 2015 DataArt. All rights reserved.
//

import Foundation

class AboutViewController : UIViewController {
    @IBOutlet weak var hyperlinkLabel: UILabel!
    
    //MARK: View's lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let underlineAttribute = [NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "DataArt Apps, Inc.", attributes: underlineAttribute)
        hyperlinkLabel.attributedText = underlineAttributedString
    }
    
    //MARK: Callbacks
    
    @IBAction func backDidTap(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func hyperlinkDidTap(sender: AnyObject) {
        UIApplication.sharedApplication().openURL(NSURL(string: "http://www.dataart.com/")!)
    }
    
    @IBAction func facebookDidTap(sender: AnyObject) {
        UIApplication.sharedApplication().openURL(NSURL(string: "https://www.facebook.com/dataart/")!)
    }
    
    @IBAction func linkedInDidTap(sender: AnyObject) {
        UIApplication.sharedApplication().openURL(NSURL(string: "https://www.linkedin.com/company/dataart")!)
    }
    
    @IBAction func twitterDidTap(sender: AnyObject) {
        UIApplication.sharedApplication().openURL(NSURL(string: "https://twitter.com/DataArt/")!)
    }
    
    @IBAction func googlePlusDidTap(sender: AnyObject) {
        UIApplication.sharedApplication().openURL(NSURL(string: "https://plus.google.com/107801340583213295402/posts")!)
    }
}