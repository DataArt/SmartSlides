//
//  BrowsingViewController.swift
//  MultipeerGroupChat
//
//  Created by Roman Ivchenko on 11/16/15.
//  Copyright © 2015 Apple, Inc. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class BrowsingCell : UITableViewCell {
    static let kCellIdentifier = "BrowsingCell"
    
    @IBOutlet weak var peerNameLabel: UILabel!
    @IBOutlet weak var peerDeviceTypeImageView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    
    var session : PresentationSession? {
        didSet {
            peerNameLabel.text = session!.displayName
            peerDeviceTypeImageView.image = session!.broadcastingDeviceName == "iPhone" ? UIImage(named: "iphone_icon") : UIImage(named: "ipad_icon")
            dateLabel.text = session!.creationDate.toString(format: .Custom("MMMM dd, yyyy"))
        }
    }
}

protocol BrowsingViewControllerDelegate : NSObjectProtocol {
    func browsingViewControllerAsksToShowCancelButton(vc : BrowsingViewController)
    func browsingViewControllerAsksToHideCancelButton(vc : BrowsingViewController)
    func browsingViewControllerDidDetermineInvitesAmount(invitesAmount : Int, vc : BrowsingViewController)
}

class BrowsingViewController: UIViewController {
    
    weak var delegate : BrowsingViewControllerDelegate?
    var serviceType : String?
    
    var manager : BrowsingManager! {
        get {
            return AppDelegate.shared.browsingManager
        }
    }
    
    var session : MCSession? {
        get {
            return manager.browsingSession
        }
    }
    
    var cellHeight : CGFloat {
        get {
            if UIDevice.currentDevice().userInterfaceIdiom == .Phone  {
                return 77.0
            } else {
                return 96.0
            }
        }
    }
    
    var browser : MCNearbyServiceBrowser!
    
    @IBOutlet weak var cancelLabel: UILabel!
    @IBOutlet weak var refreshView: UIView!
    @IBOutlet weak var invitesAmountLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var topTableViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelButton: UIButton!
    
    var refreshControl: UIRefreshControl!
    
    var allAdvertisers = Dictionary<String, [PresentationSession]>()
    var actualAdvertisers = [PresentationSession]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupBrowser()
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh", attributes: [NSForegroundColorAttributeName: UIColor.whiteColor().colorWithAlphaComponent(0.7)])
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        tableView.addSubview(refreshControl)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        refresh(refreshControl)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        browser.stopBrowsingForPeers()
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            cancelButton.enabled = false
            cancelLabel.hidden = true
        } else {
            delegate?.browsingViewControllerAsksToHideCancelButton(self)
        }

        self.statusLabel.text = "Waiting for approvement from advertiser..."
        self.tableView.userInteractionEnabled = true
        
        self.topTableViewConstraint.constant = 0
        self.refreshView.alpha = 0.0
        
        self.view.layoutIfNeeded()
        self.view.layoutSubviews()
        
        print("Stop looking for advertisers")
    }
    
    deinit {
        browser.stopBrowsingForPeers()
    }
    
    //MARK: Public
    
    func reconnectWithPeerID(peer : MCPeerID) {
        AppDelegate.shared.invalidateAllSessions()
        setupBrowser()
        manager.removeLastConnectedAdvertiserSessionHash()
        
        browser.stopBrowsingForPeers()
        browser.startBrowsingForPeers()
        
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            for presentationSession in self.actualAdvertisers {
                if presentationSession.displayName == peer.displayName {
                    self.browser.invitePeer(presentationSession.myPeerID, toSession: self.session!, withContext: nil, timeout: 30)
                    return
                }
            }
            MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
            print("Couldnt reconnect")
        }
    }
    
    //MARK: Callbacks
    
    func refresh(sender: UIRefreshControl) {
        allAdvertisers.removeAll()
        actualAdvertisers.removeAll()
        
        browser.stopBrowsingForPeers()
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            self.browser.startBrowsingForPeers()
            
            sender.endRefreshing()
            self.tableView.reloadData()
            
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                self.invitesAmountLabel.text = "\(self.actualAdvertisers.count) invites"
            } else {
                self.delegate?.browsingViewControllerDidDetermineInvitesAmount(self.actualAdvertisers.count, vc: self)
            }
        }
    }
    
    @IBAction func cancelDidTap(sender: UIButton?) {
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            sender?.enabled = false
            cancelLabel?.hidden = true
        } else {
            self.delegate?.browsingViewControllerAsksToHideCancelButton(self)
        }
        
        UIView.animateWithDuration(0.5, animations: {[unowned self] () -> Void in
            self.topTableViewConstraint.constant = 0
            self.refreshView.alpha = 0.0
            self.view.layoutIfNeeded()
            self.view.layoutSubviews()
            }, completion: {[unowned self] (finished) -> Void in
                if finished {
                    self.statusLabel.text = "Waiting for approvement from advertiser..."
                    self.tableView.userInteractionEnabled = true
                }
            })
    }
    
    //MARK: Private
    
    func removeAdvertisersFromActualWithDisplayName(displayName : String) {
        for session in actualAdvertisers {
            if session.displayName == displayName {
                actualAdvertisers.removeObject(session)
            }
        }
    }
    
    func setupBrowser() {
        serviceType = manager!.kServiceTypeName
        
        manager.instantiateObserverSessionWithName(UIDevice.currentDevice().name, browsingDelegate: self)
        
        browser = MCNearbyServiceBrowser(peer: session!.myPeerID, serviceType: serviceType!)
        browser.delegate = self
    }
}

extension BrowsingViewController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if actualAdvertisers.count > indexPath.row && session != nil {
            
            let peer : MCPeerID = actualAdvertisers[indexPath.row].myPeerID
            print("Connecting to " + actualAdvertisers[indexPath.row].displayName + " \(actualAdvertisers[indexPath.row].index)" + "---" + actualAdvertisers[indexPath.row].creationDate.description + "---" + actualAdvertisers[indexPath.row].broadcastingDeviceName)
            browser.invitePeer(peer, toSession: session!, withContext: nil, timeout: 30)
            
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                cancelButton.enabled = true
                cancelLabel.hidden = false
            } else {
                self.delegate?.browsingViewControllerAsksToShowCancelButton(self)
            }
            
            UIView.animateWithDuration(0.5, animations: {[unowned self] () -> Void in
                self.topTableViewConstraint.constant = self.refreshView.frame.height
                self.refreshView.alpha = 1.0
                
                self.view.layoutIfNeeded()
                self.view.layoutSubviews()
                })
            
            tableView.userInteractionEnabled = false
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actualAdvertisers.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(BrowsingCell.kCellIdentifier) as! BrowsingCell
        
        if actualAdvertisers.count > indexPath.row {
            let session : PresentationSession = actualAdvertisers[indexPath.row]
            
            cell.session = session
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeight
    }
}

extension BrowsingViewController : BrowsingHandlerDelegate {
    
    func browsingHandlerDidDetermineAdvertiser(peerID: MCPeerID, withState state: MCSessionState) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self] () -> Void in
            self.statusLabel.text = state.readableRawValue() + " to \(peerID.displayName)..."
            
            if state == .NotConnected {
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    self.cancelDidTap(self.cancelButton)
                }
            }
            
            if state == .Connected {
                for session in self.actualAdvertisers {
                    if session.displayName == peerID.displayName {
                        // Saving peerID object for reconnection purposes
                        self.manager.registerAdvertiserPeer(peerID)
                        // Adding session in the session history list
                        self.manager.registerAdvertiserSession(session)
                        break
                    }
                }
            }
        }
    }
}

extension BrowsingViewController : MCNearbyServiceBrowserDelegate {
    
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if info != nil {
            guard info!["id"] != UIDevice.currentDevice().identifierForVendor!.UUIDString else {
                // Your own device should not be seen in sessions list
                return
            }
            
            // Allocate & initalize memory for array of new advertiser sessions in general datasource
            if allAdvertisers[peerID.displayName] == nil {
                allAdvertisers[peerID.displayName] = [PresentationSession]()
            }
            
            // Instantiating session object using peerID & data containing in discovery info dictionary
            let presentationSession = PresentationSession(peer: peerID, discoveryInfo: info!)
            allAdvertisers[peerID.displayName]!.append(presentationSession)
            
            print(presentationSession.displayName + " \(presentationSession.index)" + "---" + presentationSession.creationDate.description + "---" + presentationSession.broadcastingDeviceName)
            
            // Actual sessions datasource cleanup
            removeAdvertisersFromActualWithDisplayName(peerID.displayName)
            
            // Finding the latest advertiser session in general sessions datasource
            allAdvertisers[peerID.displayName]!.sortInPlace({ $0.index > $1.index && $0.creationDate.isGreaterThanDate($1.creationDate)})
            let latestSession = allAdvertisers[peerID.displayName]!.last
            
            // Checking latest session for availabilty. Workaround for advertiser ghosts issue
            if manager.checkIfAdvertiserSessionAvailable(latestSession!) {
                // If everything is ok, we show this session in the list
                actualAdvertisers.append(latestSession!)
            }
            
            tableView.reloadData()
            
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                self.invitesAmountLabel.text = "\(self.actualAdvertisers.count) invites"
            } else {
                self.delegate?.browsingViewControllerDidDetermineInvitesAmount(self.actualAdvertisers.count, vc: self)
            }
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        refresh(refreshControl)
    }
}

extension Array {
    mutating func removeObject<U: Equatable>(object: U) -> Bool {
        for (idx, objectToCompare) in enumerate() {
            if let to = objectToCompare as? U {
                if object == to {
                    self.removeAtIndex(idx)
                    return true
                }
            }
        }
        return false
    }
}

extension NSDate {
    func isGreaterThanDate(dateToCompare : NSDate) -> Bool {
        //Declare Variables
        var isGreater = false
        
        //Compare Values
        if self.compare(dateToCompare) == NSComparisonResult.OrderedDescending {
            isGreater = true
        }
        
        //Return Result
        return isGreater
    }
    
    func isLessThanDate(dateToCompare : NSDate) -> Bool {
        //Declare Variables
        var isLess = false
        
        //Compare Values
        if self.compare(dateToCompare) == NSComparisonResult.OrderedAscending {
            isLess = true
        }
        
        //Return Result
        return isLess
    }
}

