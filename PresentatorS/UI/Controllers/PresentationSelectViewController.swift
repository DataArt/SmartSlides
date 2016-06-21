//
//  PresentationSelectViewController.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/29/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import UIKit

protocol PresentationSelectionProtocol: class {
    func didFinishWithResult(controller: PresentationSelectViewController, path : String)
    func didStartSynchronization(controller: PresentationSelectViewController)
    func dropboxSynchronizationDidChangeStatusWithText(text: String, controller: PresentationSelectViewController)
    func downloadingDropboxFilesWithProgressText(progressText : String, controller: PresentationSelectViewController)
    func didFinishDownloadingDropboxFiles(controller: PresentationSelectViewController)
    func didConnectToDropbox(controller: PresentationSelectViewController)
    func didUnlinkFromDropbox(controller: PresentationSelectViewController)
    func disableDropboxButton(controller: PresentationSelectViewController)
    func enableDropboxButton(controller: PresentationSelectViewController)
}

class PresentationItem : NSObject {
    
    var type : DirectoryType
    var presentationURL : String
    
    init(type: DirectoryType, presentationURL : String) {
        self.type = type
        self.presentationURL = presentationURL
        
        super.init()
    }
}

class PresentationCell : UITableViewCell {
    static let kCellIdentifier = "PresentationSelectCell"
    static let kCellHeight = 70.0
    
    @IBOutlet weak var presentationNameLabel: UILabel!
    @IBOutlet weak var presentationTypeImageView: UIImageView!
    @IBOutlet weak var presentationDateLabel: UILabel!

    var file : File? {
        didSet {
            if file != nil {
                presentationTypeImageView.image = UIImage(named: file!.type.getImageNameForType())
                presentationNameLabel.text = file!.name
                presentationDateLabel.text = file!.descriptionText
            }
        }
    }
}

class PresentationSelectViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var sharedHeaderView: UIView!
    @IBOutlet var importedHeaderView: UIView!
    @IBOutlet var dropboxHeaderView: UIView!
    @IBOutlet weak var dropboxSyncLabel: UILabel!
    
    var refreshControl: UIRefreshControl!
    var sections = [DirectoryType]()
    var dbPresentationFiles = [DBMetadata]()
    var downloadedFilesCount = 0
    var dispatchBlock : dispatch_block_t {
        get {
            return {
                print("Finished looking for presentation files on dropbox")
                var isDownloading = false
                for presentationMeta in self.dbPresentationFiles {
                    isDownloading = true
                    dispatch_group_enter(self.downloadingSyncGroup)
                    self.dbRestClient.loadFile(presentationMeta.path, intoPath: NSURL.CM_fileURLToDropboxPresentationDirectory().URLByAppendingPathComponent(presentationMeta.filename).path)
                }
                
                dispatch_group_notify(self.downloadingSyncGroup, dispatch_get_main_queue()) { () -> Void in
                    self.dbPresentationFiles.removeAll()
                    self.viewcontrollerDelegate?.didFinishDownloadingDropboxFiles(self)
                    UIView.animateWithDuration(0.5, animations: { () -> Void in
                        self.dropboxSyncLabel?.alpha = 0.0
                    })
                    self.tableView.addSubview(self.refreshControl)
                    self.viewcontrollerDelegate?.enableDropboxButton(self)
                }
                
                if isDownloading {
                    print("Started downloading presentations from dropbox")
                    self.dropboxSyncLabel?.text = "Dropbox synchronization..."
                    self.viewcontrollerDelegate?.dropboxSynchronizationDidChangeStatusWithText("Dropbox synchronization...", controller: self)
                } else {
                    self.dbPresentationFiles.removeAll()
                    print("Nothing to synchronize")
                    self.tableView.addSubview(self.refreshControl)
                    self.viewcontrollerDelegate?.enableDropboxButton(self)
                }
            }
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
    
    var headerHeight : CGFloat {
        get {
            if UIDevice.currentDevice().userInterfaceIdiom == .Phone  {
                return 30.0
            } else {
                return 47.0
            }
        }
    }
    
    var dropboxSynchronizationAllowed : Bool {
        set {
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: "allow_dropbox")
        }
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey("allow_dropbox")
        }
    }
    
    weak var viewcontrollerDelegate: PresentationSelectionProtocol?
    
    var dbRestClient: DBRestClient!
    var datasource = [PresentationItem]()
    
    var metadataSyncGroup = dispatch_group_create()
    var downloadingSyncGroup = dispatch_group_create()
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to synchronize with dropbox", attributes: [NSForegroundColorAttributeName: UIColor.whiteColor().colorWithAlphaComponent(0.7)])
        refreshControl.addTarget(self, action: #selector(PresentationSelectViewController.refresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        
        if dropboxSynchronizationAllowed {
            setupDropboxSynchronization()
        }
        
        addPredefinePresentationFileWithName("Presentation #1", type: "pptx")
        addPredefinePresentationFileWithName("Presentation #2", type: "key")
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PresentationSelectViewController.handleDidLinkNotification(_:)), name: "didLinkToDropboxAccountNotification", object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        fetchItems()
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //MARK: Callbacks
    
    func refresh(sender: UIRefreshControl) {
        sender.endRefreshing()
        sender.removeFromSuperview()
        
        self.dbPresentationFiles.removeAll()

        dispatch_group_enter(metadataSyncGroup)
        dispatch_group_notify(metadataSyncGroup, dispatch_get_main_queue(), dispatchBlock)
        downloadedFilesCount = 0
        dbRestClient?.loadMetadata("/")
        
        viewcontrollerDelegate?.didConnectToDropbox(self)
        viewcontrollerDelegate?.didStartSynchronization(self)
        viewcontrollerDelegate?.disableDropboxButton(self)
        
        self.dropboxSyncLabel?.text = "Searching new files on dropbox..."
        UIView.animateWithDuration(0.5, animations: { () -> Void in
            self.dropboxSyncLabel?.alpha = 0.7
        })
    }
    
    //MARK: Public
    
    func dropboxSyncDidTap() {
        if !DBSession.sharedSession().isLinked() {
            DBSession.sharedSession().linkFromController(self)
        } else {
            if !dropboxSynchronizationAllowed {
                setupDropboxSynchronization()
                
                dropboxSynchronizationAllowed = true
            } else {
                DBSession.sharedSession().unlinkAll()
                refreshControl.removeFromSuperview()
                dropboxSynchronizationAllowed = false
                viewcontrollerDelegate?.didUnlinkFromDropbox(self)
            }
        }
    }

    //MARK: Private
    
    func addPredefinePresentationFileWithName(name : String, type : String) {
        if let path = NSBundle.mainBundle().pathForResource(name, ofType: type) {
            let url = NSURL.fileURLWithPath(path)
            do {
                let pathToSave = NSURL.CM_fileURLToSharedPresentationDirectory().URLByAppendingPathComponent("\(name).\(type)")
                if !NSFileManager.defaultManager().fileExistsAtPath(pathToSave.path!) {
                    try NSFileManager.defaultManager().copyItemAtPath(url.path!, toPath: pathToSave.path!)
                } else {
                    print("Presentation already exists")
                }
            } catch {
                print("Error while adding default presentation")
            }
        }
    }
    
    func setupDropboxSynchronization() {
        dbRestClient = DBRestClient(session: DBSession.sharedSession())
        
        dbRestClient.delegate = self
        dispatch_group_enter(metadataSyncGroup)
        dbRestClient.loadMetadata("/")
        downloadedFilesCount = 0
        dispatch_group_notify(metadataSyncGroup, dispatch_get_main_queue(), dispatchBlock)
        viewcontrollerDelegate?.didConnectToDropbox(self)
        viewcontrollerDelegate?.didStartSynchronization(self)
        viewcontrollerDelegate?.disableDropboxButton(self)
        
        self.dropboxSyncLabel?.text = "Searching new files on dropbox..."
        UIView.animateWithDuration(0.5, animations: { () -> Void in
            self.dropboxSyncLabel?.alpha = 0.7
        })
    }
    
    func handleDidLinkNotification(notification: NSNotification) {
        dropboxSynchronizationAllowed = true
        setupDropboxSynchronization()
    }
    
    func contentsOfDirectory(type: DirectoryType) -> [String]? {
        var path: String?
        switch type {
        case .Shared:
            path = NSURL.CM_fileURLToSharedPresentationDirectory().path!
        case .Imported:
            path = NSURL.CM_fileURLToImportedPresentationDirectory().path!
        case .Dropbox:
            path = NSURL.CM_fileURLToDropboxPresentationDirectory().path!
        }
        let content : [String]?
        
        do {
            content = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path!)
            if content != nil {
                if #available(iOS 9.0, *) {
                    return content!.filter({
                        $0.rangeOfString(".pptx", options: NSStringCompareOptions(), range: nil, locale: nil) != nil ||
                            $0.rangeOfString(".key", options: NSStringCompareOptions(), range: nil, locale: nil) != nil
                    }).map({ (path! as NSString).stringByAppendingPathComponent($0) })
                } else {
                    return content!.filter({
                        $0.rangeOfString(".pptx", options: NSStringCompareOptions(), range: nil, locale: nil) != nil}).map({ (path! as NSString).stringByAppendingPathComponent($0) })
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    func fetchItems() {
        sections.removeAll()
        datasource.removeAll()
        
        if let sharedContents = self.contentsOfDirectory(.Shared) where sharedContents.count > 0 {
            sections.append(.Shared)
            for itemPath in sharedContents {
                let sharedItem = PresentationItem(type: .Shared, presentationURL: itemPath)
                
                datasource.append(sharedItem)
            }
        }
        if let importedContents = self.contentsOfDirectory(.Imported) where importedContents.count > 0 {
            sections.append(.Imported)
            for itemPath in importedContents {
                let importedItem = PresentationItem(type: .Imported, presentationURL: itemPath)
                
                datasource.append(importedItem)
            }
        }
        if let dropboxContents = self.contentsOfDirectory(.Dropbox) where dropboxContents.count > 0 {
            sections.append(.Dropbox)
            for itemPath in dropboxContents {
                let dropboxItem = PresentationItem(type: .Dropbox, presentationURL: itemPath)
                
                datasource.append(dropboxItem)
            }
        }
    }
    
    func itemForIndexPath(indexPath: NSIndexPath) -> PresentationItem {
        let filteredDatasource = datasource.filter() { $0.type == sections[indexPath.section] }
        
        return filteredDatasource[indexPath.row]
    }
    
    func searchPresFilesInMetadata(metadata: DBMetadata!) {
        for meta in metadata.contents as! [DBMetadata] {
            let fileExtension = meta.filename.componentsSeparatedByString(".").last
            if #available(iOS 9.0, *) {
                if fileExtension == "pptx" || fileExtension == "ppt" || fileExtension == "key" {
                    if !ContentManager.sharedInstance.isResourceAvailable(meta.filename, directoryType: .Dropbox) {
                        dbPresentationFiles.append(meta)
                        print("\(meta.filename) was found on dropbox")
                    }
                }
            } else {
                if fileExtension == "pptx" || fileExtension == "ppt" {
                    if !ContentManager.sharedInstance.isResourceAvailable(meta.filename, directoryType: .Dropbox) {
                        dbPresentationFiles.append(meta)
                        print("\(meta.filename) was found on dropbox")
                    }
                }
            }
            if meta.isDirectory {
                dispatch_group_enter(metadataSyncGroup)
                dbRestClient.loadMetadata(meta.path)
            }
        }
    }
}

//MARK: UITableViewDataSource/UITableViewDelegate

extension PresentationSelectViewController : UITableViewDataSource, UITableViewDelegate {
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cellHeight
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let delegate = self.viewcontrollerDelegate {
            
            delegate.didFinishWithResult(self, path: itemForIndexPath(indexPath).presentationURL)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let filteredDatasource = datasource.filter() { $0.type == sections[section] }
        
        return filteredDatasource.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let result = tableView.dequeueReusableCellWithIdentifier(PresentationCell.kCellIdentifier) as! PresentationCell
        
        result.file = File(fullPath: itemForIndexPath(indexPath).presentationURL)
        
        return result
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        let item = itemForIndexPath(indexPath)
        let filePath = item.presentationURL
        let framedPresentationDirectory = NSURL.CM_pathForFramedPresentationDir(NSURL(fileURLWithPath: filePath))
        let fm = NSFileManager.defaultManager()
        
        var removeError: NSError?
        var removeDirectoryError: NSError?
        
        do {
            try fm.removeItemAtPath(filePath)
            do {
                try fm.removeItemAtPath(framedPresentationDirectory)
            } catch let error as NSError {
                removeDirectoryError = error
                print("remove directory error \(removeDirectoryError)")
            }
            
            fetchItems()
            tableView.reloadData()
        } catch let error as NSError {
            removeError = error
            print("remove error \(removeError)")
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        switch sections[section] {
        case .Shared:
            return sharedHeaderView
        case .Imported:
            return importedHeaderView
        case .Dropbox:
            return dropboxHeaderView
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return headerHeight
    }
}

//MARK: DropboxRestClientDelegate

extension PresentationSelectViewController : DBRestClientDelegate {
    
    func restClient(client: DBRestClient!, loadedMetadata metadata: DBMetadata!) {
        searchPresFilesInMetadata(metadata)
        
        dispatch_group_leave(metadataSyncGroup)
    }
    
    func restClient(client: DBRestClient!, loadedFile destPath: String!, contentType: String!, metadata: DBMetadata!) {
        print("\(metadata.filename) was downloaded. Content type: \(contentType)")
        downloadedFilesCount += 1
        dispatch_group_leave(downloadingSyncGroup)
        
        let progressText = "Downloading files... \(downloadedFilesCount) of \(dbPresentationFiles.count)"
        
        self.dropboxSyncLabel?.text = progressText
        viewcontrollerDelegate?.downloadingDropboxFilesWithProgressText(progressText, controller: self)
        
        fetchItems()
        tableView.reloadData()
    }
    
    func restClient(client: DBRestClient!, loadProgress progress: CGFloat, forFile destPath: String!) {
        if dbPresentationFiles.count == 1 {
            let str = String(format: "%.1f", Float(progress * 100))
            let progressText = "Downloading file... \(str)%"
            
            self.dropboxSyncLabel?.text = progressText
            viewcontrollerDelegate?.downloadingDropboxFilesWithProgressText(progressText, controller: self)
        }
    }
    
    func restClient(client: DBRestClient!, loadMetadataFailedWithError error: NSError!) {
        print(error.description)
        dispatch_group_leave(metadataSyncGroup)
        UIAlertController.showAlertWithMessage("Failed to load dropbox metadata. Please, try again", completionBlock: nil)
    }
    
    func restClient(client: DBRestClient!, loadFileFailedWithError error: NSError!) {
        print(error.description)
        dbPresentationFiles.removeLast()
        let filePath = error.userInfo["destinationPath"] as! String
        UIAlertController.showAlertWithMessage("Failed to download \(NSURL(fileURLWithPath : filePath).lastPathComponent!) presentation. Please, try again", completionBlock: nil)
        do {
            try NSFileManager.defaultManager().removeItemAtPath(filePath)
        } catch let error as NSError {
            print("Remove error \(error)")
        }

        dispatch_group_leave(downloadingSyncGroup)
    }
}
