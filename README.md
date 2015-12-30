# SmartSlides

SmartSlides is an easy-to-use tool, which allows you to share your presentation with anyone who has an iPhone or iPad. Just upload your presentation and start your speech, SmartSlides will help your audience to follow your presentation on their personal iOS devices real-time. It is also integrated with AppleWatch, so you can control the slides from your wrist.

## Requirements

* iOS 8.0+ (Apple Watch & Keynote presentations support - iOS 9.0+)

## Get Started

SmartSlides workflow mechanism is based on Apple [MultipeerConnectivity](https://developer.apple.com/library/ios/documentation/MultipeerConnectivity/Reference/MultipeerConnectivityFramework/) framework. Managing advertiser & browsing functionality implemented in AdvertisingManager & BrowsingManager classes.

For example, creating advertising session workhorse method:

```swift
    func createPresentationSessionWithName(name : String) {
        let presentationSession = PresentationSession(peer: MCPeerID(displayName: name), serviceType: kServiceTypeName, delegate:     handler, index: 0, creationDate: NSDate(), broadcastingDevice: UIDevice().model)
        
        sessions.append(presentationSession)
        
        isActive = true
        delegate?.connectivityManagerDidChangeState(self)
    }
```
Creating browsing session:

```swift
    func instantiateObserverSessionWithName(name : String, browsingDelegate delegate : BrowsingHandlerDelegate?) {
        browsingSession = MCSession(peer : MCPeerID(displayName: name), securityIdentity : nil, encryptionPreference: .None)
        handler = BrowsingHandler(browsingDelegate: delegate)
        (handler as! BrowsingHandler).connectivityDelegate = connectivityDelegate
        browsingSession!.delegate = handler
    }
```
Both AdvertisingManager & BrowsingManager callbacks handling incapsulated in SessionHandler child classes - AdvertiserHandler & BrowsingHandler. These classes handle receiving messages data between peers, monitoring connection state & files transfering progress. Messaging between peers is also incapsulated via SessionCommand classes. Each message type, data transfers actions should be encapsulated in specific class, SessionCommand inheriter.

Simple ping message sending & receiving command class example:

```swift
    class CommandPing: SessionCommand {

        required init(parameters: [String : String]) {}
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            AppDelegate.shared.browsingManager.backPingMessageReceived()
            return true
        }
    }
    
    
    class CommandGetPing: SessionCommand{
        required init(parameters: [String : String]) { }
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            do {
                print("Ping received, ping sent back")
                try session.sendData(SessionHandler.dataRequestForCommandType(.PingServer, parameters: nil), toPeers: peers, withMode: .Reliable)
                return true
            } catch let error as NSError {
                print("Error sending ping: \(error)")
                return false
            }
        }
    }

```

Presentation files can be provided by Dropbox (just create app page on [Dropbox] (https://www.dropbox.com/developers) and add key & secret string in AppDelegate), Mail app attachments and also 2 presentation files are already presented in the app by default

## Frameworks & 3rd party components

* MBProgressHUD
* Dropbox SDK
* Fabric
* Crashlytics

## License

SmartSlides app is under MIT license. See the LICENSE file for more info.
