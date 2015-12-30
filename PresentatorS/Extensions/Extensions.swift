//
//  Extensions.swift
//  PresentatorS
//
//  Created by Roman Ivchenko on 12/14/15.
//  Copyright © 2015 DataArt. All rights reserved.
//

import Foundation

extension UIAlertController {
    class func showAlertWithTitle(title : String?, message : String?, completionBlock : ((UIAlertAction) -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .Cancel, handler: completionBlock))
        
        let vc = UIApplication.sharedApplication().keyWindow!.rootViewController!.topMostViewController()
        vc.presentViewController(alertController, animated: true, completion: nil)
    }
    
    class func showAlertWithMessage(message : String?, completionBlock : ((UIAlertAction) -> Void)?) {
        let alertController = UIAlertController(title: "Alert", message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .Cancel, handler: completionBlock))
        
        let vc = UIApplication.sharedApplication().keyWindow!.rootViewController!.topMostViewController()
        vc.presentViewController(alertController, animated: true, completion: nil)
    }
    
    class func showAlertWithMessageAndMultipleAnswers(message : String?, affirmativeCompletionBlock : ((UIAlertAction) -> Void)?, negativeCompletionBlock : ((UIAlertAction) -> Void)?) {
        let alertController = UIAlertController(title: "Alert", message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: negativeCompletionBlock))
        alertController.addAction(UIAlertAction(title: "Ok", style: .Default, handler: affirmativeCompletionBlock))
        
        let vc = UIApplication.sharedApplication().keyWindow!.rootViewController!.topMostViewController()
        vc.presentViewController(alertController, animated: true, completion: nil)
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController {
        // Handling Modal views
        if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        }
            // Handling UIViewController's added as subviews to some other views.
        else {
            for view in self.view.subviews
            {
                // Key property which most of us are unaware of / rarely use.
                if let subViewController = view.nextResponder() {
                    if subViewController is UIViewController {
                        let viewController = subViewController as! UIViewController
                        return viewController.topMostViewController()
                    }
                }
            }
            return self
        }
    }
}

extension UITabBarController {
    override func topMostViewController() -> UIViewController {
        return self.selectedViewController!.topMostViewController()
    }
}

extension UINavigationController {
    override func topMostViewController() -> UIViewController {
        return self.visibleViewController!.topMostViewController()
    }
}