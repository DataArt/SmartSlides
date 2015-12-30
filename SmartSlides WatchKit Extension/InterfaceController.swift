//
//  InterfaceController.swift
//  SmartSlides WatchKit Extension
//
//  Created by Michael Murnik on 1/30/15.
//  Copyright (c) 2015 Igor Litvinenko. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity

enum MessageType: String {
    case Initial = "initial", Regular = "regular", Stop = "stop"
}

@available(iOS 9.0, *)
class InterfaceController: WKInterfaceController {
    
    @IBOutlet var presentationNameLabel: WKInterfaceLabel!
    @IBOutlet var presentationSlideLabel: WKInterfaceLabel!
    
    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = self
                session.activateSession()
            }
        }
    }
    
    var isHostAppActive = false
    
    var currIndex = 1
    var slidesAmountCount = 0
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        if WCSession.isSupported() {
            session = WCSession.defaultSession()
        }
    }
    
    @IBAction func prevTapped() {
        if currIndex > 1 && isHostAppActive {
            currIndex--
            self.presentationSlideLabel.setText("\(self.currIndex)")
            session?.sendMessage(["page": currIndex - 1, "type" : "regular"], replyHandler: { (response) -> Void in
                print(response.description)
                }, errorHandler: { (error) -> Void in
                    self.currIndex++
                    self.presentationSlideLabel.setText("\(self.currIndex)")
                    print(error)
            })
        }
    }

    @IBAction func nextTapped() {
        if currIndex < slidesAmountCount && isHostAppActive {
            currIndex++
            self.presentationSlideLabel.setText("\(self.currIndex)")
            session?.sendMessage(["page": currIndex - 1, "type" : "regular"], replyHandler: { (response) -> Void in
                print(response.description)
                }, errorHandler: { (error) -> Void in
                    self.currIndex--
                    self.presentationSlideLabel.setText("\(self.currIndex)")
                    print(error)
            })
        }
    }
    
    override func willActivate() {
        super.willActivate()
        // This method is called when watch view controller is about to be visible to user
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            self.session?.sendMessage(["type" : "initial"], replyHandler: { (response) -> Void in
                print(response.description)
                }, errorHandler: { (error) -> Void in
                    print(error)
            })
        }
    }

    override func didDeactivate() {
        super.didDeactivate()
        // This method is called when watch view controller is no longer visible
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.isHostAppActive = false
            self.currIndex = 1
            self.presentationSlideLabel.setText("")
            self.presentationNameLabel.setText("Waiting for presentation...")
        }
    }

}

@available(iOS 9.0, *)
extension InterfaceController : WCSessionDelegate {
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        let messageType = MessageType(rawValue: message["type"] as! String)
        switch messageType! {
        case .Initial:
            isHostAppActive = true
            if let slidesAmount = message["slides_amount"] as? Int {
                slidesAmountCount = slidesAmount
            }
            
            if let currentSlide = message["current_slide"] as? Int {
                currIndex = currentSlide
                presentationSlideLabel.setText("\(self.currIndex)")
            }
            
            if let presentationName = message["presentation_name"] as? String {
                let main_string = presentationName
                
                if let string_to_color = presentationName.componentsSeparatedByString(".").last {
                    let range = NSMakeRange(main_string.characters.count - string_to_color.characters.count, string_to_color.characters.count)
                    let attributedString = NSMutableAttributedString(string:main_string)
                    let color = UIColor(red: 90.0/255.0, green: 177.0/255.0, blue: 201.0/255.0, alpha: 1.0)
                    attributedString.addAttribute(NSForegroundColorAttributeName, value: color, range: range)
                    
                    presentationNameLabel.setAttributedText(attributedString)
                }
            }

        case .Regular:
            if let page = message["page"] as? Int {
                currIndex = page
                presentationSlideLabel.setText("\(self.currIndex)")
            }
        case .Stop:
            isHostAppActive = false
            currIndex = 1
            presentationSlideLabel.setText("")
            presentationNameLabel.setText("Waiting for presentation...")
        }
    }
}
