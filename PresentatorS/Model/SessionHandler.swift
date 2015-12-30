//
//  SessionHandler.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/24/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import MultipeerConnectivity

enum CommantType: String {
    case Unknown = "unknown", GetSharedMaterialsList = "get_shared_materials", GetPresentationWithNameAndCrc = "get_presentation", GetPresentationActiveSlide = "get_active_slide", UpdatePresentationActiveSlide = "update_active_slide", PingServer = "ping", StopPresentation = "stop_sharing", UpdateActivePresentation = "update_presentation", SetDeviceAsController = "set_controller_device"
}

class SessionHandler: NSObject, MCSessionDelegate {
    
    typealias StatusChange = (MCSessionState) -> ()
    internal var commandFactory: SessionCommandFactory?

    var onStatusChange: StatusChange?
    
    
    override init() {
        super.init()
        setup()
    }
    
    func setup(){ }
    
    // Remote peer changed state
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState){
        
    }
    
    // Received data from remote peer
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID){
        NSException(name: "MethodNotImplementedException", reason: "\(__FILE__), \(__LINE__): \(__FUNCTION__) should be overriden", userInfo: nil).raise()
    }
    
    // Received a byte stream from remote peer
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID){
        NSException(name: "MethodNotImplementedException", reason: "\(__FILE__), \(__LINE__): \(__FUNCTION__) should be overriden", userInfo: nil).raise()
    }
    
    // Start receiving a resource from remote peer
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress){
        Logger.printLine("\(__FILE__), \(__LINE__): \(__FUNCTION__) resourceName:\(resourceName), peer: \(peerID), progress:\(progress)")
    }
    
    // Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?){
        NSException(name: "MethodNotImplementedException", reason: "\(__FILE__), \(__LINE__): \(__FUNCTION__) should be overriden", userInfo: nil).raise()
    }
    
    func session(session: MCSession, didReceiveCertificate certificate: [AnyObject]?, fromPeer peerID: MCPeerID, certificateHandler: ((Bool) -> Void)) {
        certificateHandler(true)
    }
}

extension SessionHandler{
    class func dataRequestForCommandType(type: CommantType, parameters: [String:String]?) -> NSData {
        if type != .PingServer {
            Logger.printLine("Sending Request with type \(type.rawValue) and parameters: \(parameters)")
        }
        var result = ["type": type.rawValue]
        if let params = parameters {
            for (key, value) in params{
                result[key] = value
            }
        }
        return NSKeyedArchiver.archivedDataWithRootObject(result)
    }
    
    class func parseResponseToDictionary(data: NSData) -> [String: String] {
        let result = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! [String: String]
        if result["type"] != "ping" {
           Logger.printLine("get response \(result)")
        }
        return result
    }
}

protocol SessionCommand {
    init(parameters: [String: String])
    func execute(session: MCSession, peers: [MCPeerID]) -> (Bool)
}

protocol SessionCommandFactory{
    func commandWithType(response: [String : String]) -> SessionCommand
}

class CommandUnknown: SessionCommand {
    required init(parameters: [String : String]) {
    }
    
    func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
//        NSException(name: "CommandNotFoundException", reason: "\(__FILE__), \(__LINE__): \(__FUNCTION__) should be overriden", userInfo: nil).raise()
        return false
    }
}
