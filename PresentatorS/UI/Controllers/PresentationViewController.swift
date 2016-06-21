//
//  ViewController.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/19/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import WatchConnectivity

protocol PresentationViewControllerDelegate: class {
    func presentationViewControllerWillDismiss(controller: PresentationViewController)
}

class PageInfo : NSObject {
    let kDefaultSelectedPageIndex = 1
    
    var index : Int
    var selected : Bool
    
    init(index pageIndex : Int) {
        index = pageIndex
        selected = pageIndex == kDefaultSelectedPageIndex ? true : false
        
        super.init()
    }
}

class PagingCell : UICollectionViewCell {
    
    static let kCellIdentifier = String(PagingCell)
    
    @IBOutlet weak var indexLabel: UILabel!
    
    var pageInfo : PageInfo? {
        didSet {
            if pageInfo != nil {
                indexLabel.text = "\(pageInfo!.index)"
                
                if pageInfo!.selected {
                    indexLabel.superview?.backgroundColor =  UIColor(red: CGFloat(61.0/255.0), green: CGFloat(87.0/255.0), blue: CGFloat(100.0/255.0), alpha: 1.0)
                } else {
                    indexLabel.superview?.backgroundColor =  UIColor.clearColor()
                }
            }
        }
    }
}

class SlideCell : UICollectionViewCell {
    
    static let kCellIdentifier = String(SlideCell)
    
    @IBOutlet weak var imageView: UIImageView!
    
    var imagePath : String? {
        didSet {
            if imagePath != nil {
                imageView.image = UIImage(contentsOfFile: imagePath!)
            }
        }
    }
}

class PresentationViewController: UIViewController {
    
    var slides : [String] = []
    
    @IBOutlet weak var menuView: UIView!
    @IBOutlet weak var menuViewYConstraint: NSLayoutConstraint!
    @IBOutlet weak var pagingCollectionView: UICollectionView!
    @IBOutlet weak var carouselYConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var presentationNameLabel: UILabel!
    
    var isInLandscape = false
    var tapGestureRecognizer: UITapGestureRecognizer!
    
    var mode : ConnectivityManagerMode {
        get {
            return AppDelegate.shared.currentActiveMode
        }
    }
    
    var isMenuShowed = false
    var isCarouselShowed = false
    var carouselTimer : NSTimer!
    var presentationToShow: String?
    var startSlide = 0
    var currentPage = 0
    var obligatorySlidesAmount = 0
    var pages = [PageInfo]()
    weak var delegate: PresentationViewControllerDelegate?
    
    private var framer: FrameCutter?
    
    private func createFrameCutter() {
        var presentationFilename: String
        if let filename = presentationToShow {
            presentationFilename = filename
        } else {
            presentationFilename = ContentManager.sharedInstance.getSharedMaterials().first!
        }
        self.framer = FrameCutter(fileUrl: NSURL(fileURLWithPath: presentationFilename))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createFrameCutter()
        initializePresentation()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PresentationViewController.orientationChanged), name: UIDeviceOrientationDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PresentationViewController.restoreWatchKitConnectivity), name: kRestoreNotification, object: nil)
        
        menuView.hidden = true
        pagingCollectionView.hidden = true
        currentPage = Int(startSlide)
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PresentationViewController.handleTapGesture(_:)))
        collectionView.addGestureRecognizer(tapGestureRecognizer)
        
        switch(UIApplication.sharedApplication().statusBarOrientation) {
            case .Portrait: isInLandscape = false
            case .PortraitUpsideDown: isInLandscape = false
            default: isInLandscape = true
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView.setContentOffset(CGPoint(x: self.view.frame.width * CGFloat(currentPage), y: 0), animated: true)
        updatePagingWithPage(Int(currentPage))
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        tapGestureRecognizer.enabled = true
        
        menuViewYConstraint.constant = -menuView.frame.height
        isMenuShowed = false
        menuView.hidden = true
        
        carouselYConstraint.constant = pagingCollectionView.frame.height
        isCarouselShowed = false
        pagingCollectionView.hidden = true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.AllButUpsideDown
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    func orientationChanged() {
        isInLandscape = !isInLandscape
        
        if self.isMenuShowed {
            self.menuViewYConstraint.constant = 0
        }
        
        if self.isCarouselShowed {
            self.carouselYConstraint.constant = 0
        }
        
        var point : CGPoint!
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            var xPoint = 0.0
            
            if isInLandscape {
                xPoint = 1024.0 * Double(self.currentPage)
            } else {
                xPoint = 768.0 * Double(self.currentPage)
            }
            
            point = CGPoint(x: xPoint, y: 0)
            
            self.collectionView.reloadData()
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.collectionView.setContentOffset(point, animated: false)
            }
        } else {
            point = CGPoint(x: self.view.frame.width * CGFloat(self.currentPage), y: 0)
            
            self.collectionView.reloadData()
            self.collectionView.setContentOffset(point, animated: false)
        }
    }
    
    func restoreWatchKitConnectivity() {
        if #available(iOS 9.0, *) {
            AppDelegate.shared.watchSession?.sendMessage(["presentation_name" : NSURL(fileURLWithPath: presentationToShow!).lastPathComponent!,  "slides_amount" : slides.count, "current_slide" : currentPage + 1, "type" : "initial"], replyHandler: nil, errorHandler: { (error) -> Void in
                print(error)
            })
        }
    }
    
    //MARK: Public
    
    func updatePresentationSlide(page : Int) {
        self.collectionView.setContentOffset(CGPoint(x: self.view.frame.width * CGFloat(page), y: 0), animated: true)
        self.updatePagingWithPage(page)
    }
    
    //MARK: Callbacks
    
    @IBAction func aboutDidTap(sender: UIButton) {
        performSegueWithIdentifier("AboutSegue", sender: self)
    }
    
    @IBAction func didTapReloadPresentation(sender: UIButton?) {
        slides.removeAll()
        pages.removeAll()
        
        collectionView.reloadData()
        pagingCollectionView.reloadData()
        
        let framedPresentationDirectory = NSURL.CM_pathForFramedPresentationDir(self.framer!.fileUrl)
        let fm = NSFileManager.defaultManager()
        
        do {
            try fm.removeItemAtPath(framedPresentationDirectory)
        } catch let error as NSError {
            print("Remove directory error \(error)")
        }
        
        initializePresentation()
    }
    
    @IBAction func handleTapGesture(sender: UITapGestureRecognizer) {
        if !isMenuShowed {
            menuView.hidden = false
            sender.enabled = false
            UIView.animateWithDuration(0.3, animations: { () -> Void in
                self.menuViewYConstraint.constant = 0
                
                self.view.layoutIfNeeded()
                }, completion: { (finished) -> Void in
                    if finished {
                        sender.enabled = true
                        self.isMenuShowed = true
                        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC)))
                        dispatch_after(delayTime, dispatch_get_main_queue()) {
                            if self.isMenuShowed {
                                sender.enabled = false
                                UIView.animateWithDuration(0.3, animations: { () -> Void in
                                    self.menuViewYConstraint.constant = -self.menuView.frame.height
                                    
                                    self.view.layoutIfNeeded()
                                    }, completion: { (finished) -> Void in
                                        if finished {
                                            self.isMenuShowed = false
                                            sender.enabled = true
                                            self.menuView.hidden = true
                                        }
                                })
                            }
                        }
                    }
            })
        }
        
        if !isCarouselShowed {
            pagingCollectionView.hidden = false
            sender.enabled = false
            UIView.animateWithDuration(0.3, animations: { () -> Void in
                self.carouselYConstraint.constant = 0
                
                self.view.layoutIfNeeded()
                }, completion: { (finished) -> Void in
                    if finished {
                        sender.enabled = true
                        self.isCarouselShowed = true
                        self.carouselTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: #selector(PresentationViewController.didTickCarouselTimer(_:)), userInfo: nil, repeats: false)
                    }
            })
            
        }
    }
    
    //MARK: Menu handlers
    
    @IBAction func didTapCloseButton(sender: UIButton) {
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.menuViewYConstraint.constant = -self.menuView.frame.height
            
            self.view.layoutIfNeeded()
            }, completion: { (finished) -> Void in
                if finished {
                    self.isMenuShowed = false
                    self.menuView.hidden = true
                }
        })
    }
    
    @IBAction func didTapStopButton(sender: UIButton) {
        if mode == ConnectivityManagerMode.AdvertiserMode {
            ContentManager.sharedInstance.stopShatingPresentation()
            
            if #available(iOS 9.0, *) {
                AppDelegate.shared.watchSession?.sendMessage(["type" : "stop"], replyHandler: nil, errorHandler: { (error) -> Void in
                    print(error)
                })
            }
        }
        self.delegate?.presentationViewControllerWillDismiss(self)
        MBProgressHUD.hideHUDForView(UIApplication.sharedApplication().keyWindow, animated: true)
    }
    
    //MARK: Private
    
    func didTickCarouselTimer(timer : NSTimer) {
        if self.isCarouselShowed {
            UIView.animateWithDuration(0.3, animations: { () -> Void in
                self.carouselYConstraint.constant = self.pagingCollectionView.frame.height
                
                self.view.layoutIfNeeded()
                }, completion: { (finished) -> Void in
                    if finished {
                        self.isCarouselShowed = false
                        self.pagingCollectionView.hidden = true
                    }
            })
        }
    }
    
    func updatePagingWithPage(page : Int) {
        if pages.count > page {
            for pageInfo in pages {
                pageInfo.selected = false
            }
            
            let currentPageInfo = pages[page]
            currentPageInfo.selected = true
            
            currentPage = page
            
            pagingCollectionView.reloadData()
            
            pagingCollectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: page, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: true)
        }
    }
    
    func initializePresentation() {
        if #available(iOS 9.0, *) {
            if WCSession.isSupported() && mode == .AdvertiserMode {
                AppDelegate.shared.watchSession = WCSession.defaultSession()
                AppDelegate.shared.watchSession!.delegate = self
                AppDelegate.shared.watchSession!.activateSession()
            }
        }
        
        collectionView.pagingEnabled = true
        
        unowned let weakSelf = self
        self.framer?.startFramingProcess(self.view, callback: { (imagePaths) -> Void in
            for imageName in imagePaths {
                weakSelf.slides.append(imageName)
                weakSelf.pages.append(PageInfo(index: weakSelf.slides.count))
            }
            
            if let filename = self.framer?.fileUrl.lastPathComponent {
                if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
                    self.presentationNameLabel.text = "\(filename)"
                } else {
                    self.presentationNameLabel.text = "Presentation: \(filename)"
                }
                
                if self.mode == ConnectivityManagerMode.AdvertiserMode {
                    ContentManager.sharedInstance.startShowingPresentation(filename, page: 0, slidesAmount : self.slides.count)
                }
            }
            
            if #available(iOS 9.0, *) {
                AppDelegate.shared.watchSession?.sendMessage(["presentation_name" : NSURL(fileURLWithPath: weakSelf.presentationToShow!).lastPathComponent!,  "slides_amount" : weakSelf.slides.count, "current_slide" : weakSelf.currentPage + 1, "type" : "initial"], replyHandler: nil, errorHandler: { (error) -> Void in
                    print(error)
                })
            }
            
            weakSelf.collectionView.reloadData()
            weakSelf.pagingCollectionView.reloadData()
            
            weakSelf.collectionView.setContentOffset(CGPoint(x: self.view.frame.width * CGFloat(weakSelf.currentPage), y: 0), animated: true)
            weakSelf.updatePagingWithPage(Int(weakSelf.currentPage))
        })
    }
}

//MARK: UICollectionViewDelegate/UICollectionViewDataSource

extension PresentationViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return slides.count
    }
    
    func collectionView(view: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell : UICollectionViewCell!
        
        if view == collectionView {
            cell = collectionView.dequeueReusableCellWithReuseIdentifier(SlideCell.kCellIdentifier, forIndexPath: indexPath) as! SlideCell
            
            cell.setValue(slides[indexPath.row], forKey: "imagePath")
        } else {
            cell = pagingCollectionView.dequeueReusableCellWithReuseIdentifier(PagingCell.kCellIdentifier, forIndexPath: indexPath) as! PagingCell
            
            cell.setValue(pages[indexPath.row], forKey: "pageInfo")
        }
        
        return cell
    }
    
    func collectionView(view: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if view == pagingCollectionView {
            
            collectionView.setContentOffset(CGPoint(x: view.frame.width * CGFloat(indexPath.row), y: 0), animated: true)
            
            if mode == ConnectivityManagerMode.AdvertiserMode {
                ContentManager.sharedInstance.updateActivePresentationPage(UInt(indexPath.row))
            }
            
            carouselTimer.invalidate()
            carouselTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: #selector(PresentationViewController.didTickCarouselTimer(_:)), userInfo: nil, repeats: false)
            
            updatePagingWithPage(indexPath.row)
            if #available(iOS 9.0, *) {
                AppDelegate.shared.watchSession?.sendMessage(["page" : indexPath.row + 1, "type" : "regular"], replyHandler: nil, errorHandler: { (error) -> Void in
                    print(error)
                })
            }
        }
    }
    
    func collectionView(view: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        if view == pagingCollectionView {
            return CGSize(width: 60.0, height: 60.0)
        } else {
            return CGSize(width: view.bounds.width, height: view.bounds.height)
        }
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if scrollView == collectionView {
            if scrollView.contentOffset.x < 0 { return }
            
            let page = Int(scrollView.contentOffset.x / CGRectGetWidth(scrollView.bounds))
            
            if mode == ConnectivityManagerMode.AdvertiserMode {
                ContentManager.sharedInstance.updateActivePresentationPage(UInt(page))
            }
            
            updatePagingWithPage(page)
            if #available(iOS 9.0, *) {
                AppDelegate.shared.watchSession?.sendMessage(["page" : page + 1, "type" : "regular"], replyHandler: nil, errorHandler: { (error) -> Void in
                    print(error)
                })
            }
        }
    }
}

@available(iOS 9.0, *)

extension PresentationViewController : WCSessionDelegate {
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        let messageType = MessageType(rawValue: message["type"] as! String)
        switch messageType! {
        case .Initial:
            AppDelegate.shared.watchSession?.sendMessage(["presentation_name" : NSURL(fileURLWithPath: self.presentationToShow!).lastPathComponent!,  "slides_amount" : slides.count, "current_slide" : currentPage + 1, "type" : "initial"], replyHandler: nil, errorHandler: { (error) -> Void in
                print(error)
            })
        case .Regular:
            if let page = message["page"] as? Int {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.collectionView.setContentOffset(CGPoint(x: self.view.frame.width * CGFloat(page), y: 0), animated: true)
                    self.updatePagingWithPage(page)
                    ContentManager.sharedInstance.updateActivePresentationPage(UInt(page))
                })
            }
        default: break
        }
    }
}
