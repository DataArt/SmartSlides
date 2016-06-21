//
//  ConnectivityViewController.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/23/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import UIKit
import MultipeerConnectivity

private let kPresentationControllerSegueID = "ModalPresentation"
private let kBrowsingControllerSegueID = "EmbeddedBrowsing"
private let kPresentationSelectControllerSegueID = "EmbeddedPresentationSelect"
private let kAboutControllerSegueID = "aboutSegueID"

private enum TitleViewMode : CGFloat {
    case Long = 212.0, Short = 100.0
}

class ConnectivityViewController: UIViewController {
    
    var presentationToShow: String?

    var activePresentationSlide: Int = 0
    var slidesAmount : Int = 0
    var observationContext = KVOContext()
    
    var invitesAmount = 0
    
    @IBOutlet weak var customTitleView: UIView!
    @IBOutlet weak var switcher: UISegmentedControl!
    @IBOutlet weak var advertiserContainerView: UIView!
    @IBOutlet weak var browsingContainerView: UIView!
    @IBOutlet weak var rightBarButtonItem: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dropboxDownloadingStatusLabel: UILabel!
    @IBOutlet weak var bottomTitleLabelConstraint: NSLayoutConstraint!
    @IBOutlet weak var dropboxSyncButton: UIButton!
    @IBOutlet weak var dropboxSyncStatusLabel: UILabel!
    
    var browsingVC : BrowsingViewController!
    var presentationSelectVC : PresentationSelectViewController!
    weak var presentationVC : PresentationViewController?

    //MARK: View's lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ConnectivityViewController.prepareForPresentation(_:)), name: kReadyToStartImportedPresentationNotification, object: nil)
        self.shouldAutorotate()
        
        AppDelegate.shared.browsingManager.connectivityDelegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        customTitleView?.frame = CGRect(x: 0.0, y: 0.0, width: TitleViewMode.Long.rawValue, height: customTitleView.frame.height)
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if identifier == kAboutControllerSegueID && rightBarButtonItem?.titleLabel?.text == "Cancel" {
            return false
        } else {
            return true
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch (segue.identifier!) {
        case kPresentationControllerSegueID:
            if let presVC = segue.destinationViewController as? PresentationViewController {
                presVC.presentationToShow = presentationToShow
                presVC.startSlide = activePresentationSlide
                presVC.obligatorySlidesAmount = slidesAmount
                presVC.delegate = self
                
                presentationVC = presVC
            }
        case kPresentationSelectControllerSegueID:
            presentationSelectVC = segue.destinationViewController as! PresentationSelectViewController
            presentationSelectVC.viewcontrollerDelegate = self
        case kBrowsingControllerSegueID:
            browsingVC = segue.destinationViewController as! BrowsingViewController
            browsingVC.delegate = self
        default: break
        }
    }
    
    //MARK: Callbacks
    
    @IBAction func dropboxSyncButtonDidTap(sender: UIButton) {
        presentationSelectVC.dropboxSyncDidTap()
    }
    
    @IBAction func switcherDidChangeValue(sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            advertiserContainerView.hidden = false
            browsingContainerView.hidden = true
            
            titleLabel?.text = "Presentations for advertise"
            
            rightBarButtonDidTap(rightBarButtonItem ?? nil)
            
            customTitleView?.frame = CGRect(x: 0.0, y: 0.0, width: TitleViewMode.Long.rawValue, height: customTitleView.frame.height)
        } else {
            advertiserContainerView.hidden = true
            browsingContainerView.hidden = false
            
            titleLabel?.text = "\(invitesAmount) invites"
            
            customTitleView?.frame = CGRect(x: 0.0, y: 0.0, width: TitleViewMode.Short.rawValue, height: customTitleView.frame.height)
        }
    }
    
    @IBAction func rightBarButtonDidTap(sender: UIButton?) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone && sender?.titleLabel?.text == "Cancel" {
            browsingVC.cancelDidTap(nil)
        }
    }
    
    //MARK: Private
    
    func prepareForPresentation(note: NSNotification?) {
        if let userInfo = note?.userInfo {
            let presentationPath = userInfo["presentationPath"] as! NSString?
            startAdvertising(presentationPath as? String)
        }
    }
    
    func startAdvertising(presentationPath: String?) {
        if let path = presentationPath {
            AppDelegate.shared.advertisingManager.createPresentationSessionWithName(NSURL(fileURLWithPath: path).lastPathComponent!)

            self.presentationToShow = path
            self.performSegueWithIdentifier(kPresentationControllerSegueID, sender: self)
        }
    }
    
    //MARK: Clean up
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

//MARK: Handling PresentationSelectionProtocol

extension ConnectivityViewController: PresentationSelectionProtocol {
    
    func didFinishWithResult(controller: PresentationSelectViewController, path: String) {
        startAdvertising(path)
    }
    
    func didStartSynchronization(controller: PresentationSelectViewController) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            dropboxDownloadingStatusLabel.text = "Searching new files on dropbox..."
            UIView.animateWithDuration(0.5, animations: {[unowned self] () -> Void in
                self.bottomTitleLabelConstraint.constant = self.dropboxDownloadingStatusLabel.frame.height
                self.dropboxDownloadingStatusLabel.alpha = 1.0
                
                self.navigationController?.navigationBar.layoutIfNeeded()
                self.navigationController?.navigationBar.layoutSubviews()
                })
        }
    }
    
    func dropboxSynchronizationDidChangeStatusWithText(text: String, controller: PresentationSelectViewController) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            dropboxDownloadingStatusLabel.text = text
        }
    }
    
    func didFinishDownloadingDropboxFiles(controller: PresentationSelectViewController) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            UIView.animateWithDuration(0.5, animations: {[unowned self] () -> Void in
                self.bottomTitleLabelConstraint.constant = 0
                self.dropboxDownloadingStatusLabel.alpha = 0.0
                
                self.navigationController?.navigationBar.layoutIfNeeded()
                self.navigationController?.navigationBar.layoutSubviews()
                })
        }
    }
    
    func downloadingDropboxFilesWithProgressText(progressText: String, controller: PresentationSelectViewController) {
        self.dropboxDownloadingStatusLabel?.text = progressText
    }
    
    func didConnectToDropbox(controller: PresentationSelectViewController) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            dropboxSyncStatusLabel.text = "Unlink dropbox"
        } else {
            dropboxSyncStatusLabel.text = "Unlink"
        }
    }
    
    func didUnlinkFromDropbox(controller: PresentationSelectViewController) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            dropboxSyncStatusLabel.text = "Synchronize with dropbox"
        } else {
            dropboxSyncStatusLabel.text = "Sync"
        }
    }
    
    func disableDropboxButton(controller: PresentationSelectViewController) {
        dropboxSyncButton.enabled = false
        dropboxSyncStatusLabel.alpha = 0.5
    }
    
    func enableDropboxButton(controller: PresentationSelectViewController) {
        dropboxSyncButton.enabled = true
        dropboxSyncStatusLabel.alpha = 1.0
    }
}

//MARK: Handling browsing actions

extension ConnectivityViewController: BrowsingViewControllerDelegate {
    
    func browsingViewControllerAsksToShowCancelButton(vc: BrowsingViewController) {
        rightBarButtonItem.setTitle("Cancel", forState: .Normal)
    }
    
    func browsingViewControllerAsksToHideCancelButton(vc: BrowsingViewController) {
        rightBarButtonItem.setTitle("About", forState: .Normal)
    }
    
    func browsingViewControllerDidDetermineInvitesAmount(invitesAmount: Int, vc: BrowsingViewController) {
        self.invitesAmount = invitesAmount
        if switcher.selectedSegmentIndex == 1 {
            titleLabel.text = "\(invitesAmount) invites"
        }
    }
}

//MARK: BrowserConnectivityDelegate

extension ConnectivityViewController: BrowsingConnectivityDelegate {
    
    func browsingHandlerDidStartDownloadingPresentation(progress: NSProgress, presentationName : String) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("\(progress.localizedDescription)")
        }
    }
    
    func browsingHandlerDidReceiveActiveSlideCommand(command : BrowserCommandsHelper.CommandReceiveActiveSlide) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
            self.presentationToShow = command.presentationName
            if let page = command.pageNumber {
                self.activePresentationSlide = page
            }
            if let slidesAmount = command.slidesAmount {
                self.slidesAmount = slidesAmount
            }
            
            if self.presentationVC != nil && self.presentedViewController is PresentationViewController {
                self.presentationVC?.updatePresentationSlide(self.activePresentationSlide)
            } else {
                self.performSegueWithIdentifier(kPresentationControllerSegueID, sender: self)
            }
        }
    }
    
    func browsingHandlerDidUpdateActiveSlideCommand(command : BrowserCommandsHelper.CommandUpdatePresentationSlide) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
            if let page = command.pageNumber {
                self.presentationVC?.updatePresentationSlide(page)
            }
        }
    }
    
    func browsingHandlerDidReceiveStopPresentationCommand(command : BrowserCommandsHelper.CommandStopCurrentPresentation) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
            self.presentationVC?.dismissViewControllerAnimated(true, completion: { () -> Void in
                self.activePresentationSlide = 0
                self.slidesAmount = 0
                
                if let options = command.parameters!["wait"] where options == "show_again" {
                    AppDelegate.shared.browsingManager.removeLastConnectedAdvertiserSessionHash()
                }
                
                AppDelegate.shared.invalidateAllSessions()
                
                self.browsingVC.setupBrowser()
            })
        }
    }
    
    func browsingHandlerDidDisconnectedFromPeer(peerID: MCPeerID) {
        MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
        if let currentAdvertiserPeer = AppDelegate.shared.browsingManager.advertiserPeer {
            if currentAdvertiserPeer.isEqual(peerID) {
                print("\(currentAdvertiserPeer.displayName) isEqual to \(peerID.displayName)")
                if self.presentationVC != nil && self.presentedViewController is PresentationViewController {
                    UIAlertController.showAlertWithMessageAndMultipleAnswers("Seems like connection with \(currentAdvertiserPeer.displayName) was lost. Do you want to reconnect?", affirmativeCompletionBlock: { (yesAlertAction) -> Void in
                        self.browsingVC.reconnectWithPeerID(peerID)
                        MBProgressHUD.showHUDAddedTo(UIApplication.sharedApplication().keyWindow, animated: true)
                        
                        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(30.0 * Double(NSEC_PER_SEC)))
                        dispatch_after(delayTime, dispatch_get_main_queue()) {
                            MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
                        }
                        }, negativeCompletionBlock: { (noAlertAction) -> Void in
                            self.presentationVC?.dismissViewControllerAnimated(true, completion: { () -> Void in
                                self.activePresentationSlide = 0
                                self.slidesAmount = 0
                                
                                AppDelegate.shared.invalidateAllSessions()
                                AppDelegate.shared.browsingManager.removeLastConnectedAdvertiserSessionHash()
                                
                                self.browsingVC.setupBrowser()
                                AppDelegate.shared.browsingManager.connectivityDelegate = self
                            })
                    })
                }
            }
        }
    }

}

//MARK: PresentationViewControllerDelegate

extension ConnectivityViewController : PresentationViewControllerDelegate {
    
    func presentationViewControllerWillDismiss(controller: PresentationViewController) {
        controller.dismissViewControllerAnimated(true, completion: { () -> Void in
            self.activePresentationSlide = 0
            self.slidesAmount = 0
            
            AppDelegate.shared.invalidateAllSessions()
            if controller.mode == .ListenerMode {
                AppDelegate.shared.browsingManager.removeLastConnectedAdvertiserSessionHash()
            }
            
            self.browsingVC.setupBrowser()
        })
    }
}
