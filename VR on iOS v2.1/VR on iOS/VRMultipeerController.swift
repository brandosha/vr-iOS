//
//  VRMultipeerController.swift
//  VR 360 app
//
//  Created by Brandon on 9/12/18.
//  Copyright © 2018 test. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import ARKit

class VRMultipeerController: VRViewController, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // Unique identifier for connecting with other players
    static let serviceType = "vr-escape"
    
    private var myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var mcSession: MCSession!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    
    private var connected = false
    
    var sharedData: DataCodable?
    
    override func loadView() {
        
        super.loadView()
        
        mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: VRMultipeerController.serviceType)
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: VRMultipeerController.serviceType)
        serviceBrowser.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        //  print("recieved invitation from peer: \(peerID) with context: \(context)")
        
        if !connected || mcSession.connectedPeers.isEmpty {
            
            //  print("accepting invitiation from peer: \(peerID.displayName)")
            
            if let context = context {
                
                handleSharedData(context, from: peerID)
                
            }
            
            invitationHandler(true, self.mcSession)
            
            connected = true
            
            serviceBrowser.stopBrowsingForPeers()
            serviceAdvertiser.stopAdvertisingPeer()
            
        }
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        let context = sharedData?.asData
        
        browser.invitePeer(peerID, to: mcSession, withContext: context, timeout: 10)
        
        //  print("found peer: \(peerID) with discovery info: \(info)")
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
        // Do nothing
        
    }
    
    var peerNodes: [String:SCNNode] = [:]
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        if state == .connected && peerID != myPeerID && !connected {
            
            //  print("\(peerID.displayName) accepted invitation")
            
            do {
                
                try mcSession.send(mapData!, toPeers: [peerID], with: .reliable)
                
                sentRecievedMap = true
                
            } catch {
                
                sentRecievedMap = false
                
                print("error sending data to peer: \(error.localizedDescription)")
                
            }
            
        } else if state == .notConnected {
            
            if let disconnectedPeer = peerNodes[peerID.displayName] {
                
                disconnectedPeer.removeFromParentNode()
                peerNodes.removeValue(forKey: peerID.displayName)
                
            }
            
        }
        
    }
    
    var recentPeerPositions: [String: [float3]] = [:]
    var sentRecievedMap = false
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                
                self.mapData = nil
                
                // Run the session with the received world map.
                let configuration = setUpConfig()
                configuration.initialWorldMap = worldMap
                ARView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                print("recieved world map from \(peerID.displayName)")
                
                sentRecievedMap = true
                
                return
                
            }
            else if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                // Add anchor to the session, ARSCNView delegate adds visible content.
                ARView.session.add(anchor: anchor)
                
                sentRecievedMap = true
                
                return
                
            }
            else {
                //  print("unknown data recieved from \(peerID.displayName)")
            }
        } catch {
            
            //  print("can't decode map data recieved from \(peerID.displayName)")
            
        }
        
        if let location = PlayerLocation(data) {
            
            //  print("Recieved location data, \(location) from \(peerID.displayName)")
            
            if let peerNode = peerNodes[peerID.displayName] {
                
                let float3Pos = float3(location.position.x, location.position.y, location.position.z)
                recentPeerPositions[peerID.displayName]?.append(float3Pos)
                
                let peerPositions = recentPeerPositions[peerID.displayName]!
                recentPeerPositions[peerID.displayName] = Array(peerPositions.suffix(10))
                
                let average = peerPositions.reduce(float3(0), { $0 + $1 }) / Float(peerPositions.count)
                let averagePos = SCNVector3(
                    average.x,
                    average.y,
                    average.z
                )
                
                peerNode.position = averagePos
                peerNode.eulerAngles = location.rotation
                
                if let cube = peerNode.geometry {
                    
                    if ARMode {
                        
                        cube.firstMaterial?.colorBufferWriteMask = []
                        peerNode.renderingOrder = -1
                        
                    } else {
                        
                        cube.firstMaterial?.diffuse.contents = UIColor.black
                        
                    }
                    
                }
                
            } else {
                
                //  print("adding cube to \(peerID.displayName)")
                
                let cube = SCNBox(width: CGFloat(0.2 * multiplier), height: CGFloat(0.2 * multiplier), length: CGFloat(0.2 * multiplier), chamferRadius: 0)
                
                let peerNode = SCNNode(geometry: cube)
                
                if ARMode {
                    
                    cube.firstMaterial?.colorBufferWriteMask = []
                    peerNode.renderingOrder = -1
                    
                } else {
                    
                    cube.firstMaterial?.diffuse.contents = UIColor.black
                    
                }
                
                let actualPos = SCNVector3(
                    location.position.x * multiplier,
                    location.position.y * multiplier,
                    location.position.z * multiplier
                )
                
                let float3Pos = float3(actualPos.x, actualPos.y, actualPos.z)
                recentPeerPositions[peerID.displayName] = [float3Pos]
                
                peerNode.position = actualPos
                peerNode.eulerAngles = location.rotation
                
                peerNodes[peerID.displayName] = peerNode
                
                mainPointOfView.addChildNode(peerNode)
                
            }
            
            return
            
        }
        
        if let action = TapAction(data, scene: scene) {
            
            //  print("Recieved action data from \(peerID.displayName)")
            
            switch action.type {
                
            case .taken, .replaced:
                action.lookingAtObject.toggleHidden()
            case .used:
                if let object = action.holdingObject {
                    
                    _ = object.use(on: action.lookingAtObject)
                    
                } else {
                    
                    _ = action.lookingAtObject.use(on: action.lookingAtObject)
                    
                }
                
            }
            
        } else {
            
            //  print("Unable to decode action data")
            
        }
        
    }
    
    override var multiplier: Float {
        
        didSet {
            
            super.multiplier = multiplier
            
            for peerNode in peerNodes {
                
                guard let geometry = peerNode.value.geometry else {
                    return
                }
                guard let cube = geometry as? SCNBox else {
                    return
                }
                
                cube.length = CGFloat(0.2 * multiplier)
                cube.width  = CGFloat(0.2 * multiplier)
                cube.height = CGFloat(0.2 * multiplier)
                
            }
            
        }
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
        fatalError("this app does not send/recieve streams")
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
        fatalError("this app does not send/recieve resources")
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
        fatalError("this app does not send/recieve resources")
        
    }
    
    var previousPeers: [MCPeerID] = []
    
    
    var mapData: Data? = nil {
        
        didSet {
            
            if mapData != nil {
                
                serviceBrowser.startBrowsingForPeers()
                
            }
            
        }
        
    }
    
    var previousMappingStatus: ARFrame.WorldMappingStatus? = nil
    
    override func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        super.session(session, didUpdate: frame)
        
        if !mcSession.connectedPeers.isEmpty && sentRecievedMap {
            
            let currentPos = mainCameraNode.position
            let currentRot = mainCameraNode.eulerAngles
            
            let data = PlayerLocation(position: currentPos, rotation: currentRot).asData
            
            do {
                
                try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .unreliable)
                
            } catch {
                
                //  print("Unable to send location data to peers")
                
            }
            
        }
        
        if connected { return }
        
        switch frame.worldMappingStatus {
            
        case .notAvailable, .limited:
            
            if previousMappingStatus != .notAvailable {
                
                //  print("no world map available")
                
                previousMappingStatus = .notAvailable
                
            }
            
        case .extending:
            
            if previousMappingStatus != .extending {
                
                //  print("begun tracking world map")
                
                previousMappingStatus = .extending
                
            }
            
        case .mapped:
            
            if previousMappingStatus != .mapped {
                
                //  print("ready to send world map")
                
                previousMappingStatus = .mapped
                
            }
            
            session.getCurrentWorldMap { worldMap, error in
                
                guard let map = worldMap else {
                    
                    //  print("Error: \(error!.localizedDescription)")
                    return
                    
                }
                
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) else {
                    
                    fatalError("can't encode map")
                    
                }
                
                self.mapData = data
                
            }
            
        }
        
    }
    
    override func userTapped(lookingAt object: VRObject, lookingAt position: SCNVector3) {
        
        var successful = false
        var type: ActionType? = nil
        
        if holdingObject == nil && object.type != .static {
            
            let taken = object.take()
            
            if !taken {
                
                //  print("Could not take")
                
            } else {
                
                //  print("Taken successfully")
                
                holdingObject = object
                
                successful = true
                type = .taken
                
            }
            
        } else if holdingObject == object {
            
            let replaced = object.replace()
            
            if !replaced {
                
                //  print("Could not replace")
                
            } else {
                
                //  print("Replaced successfully")
                
                holdingObject = nil
                
                successful = true
                type = .replaced
                
            }
            
        } else if holdingObject != nil {
            
            let used = holdingObject!.use(on: object)
            
            if !used {
                
                //  print("Could not use")
                
            } else {
                
                //  print("Used successfully")
                
                successful = true
                type = .used
                
            }
            
        } else {
            
            let used = object.use(on: object)
            
            if !used {
                
                //  print("Could not use")
                
            } else {
                
                //  print("Used successfully")
                
                successful = true
                type = .used
                
            }
            
        }
        
        if type != nil && successful {
            
            let tapAction = TapAction(type: type!, lookingAtObject: object, holdingObject: holdingObject)
            
            do {
                
                //  print("Sending action data to peers")
                try mcSession.send(tapAction.asData, toPeers: mcSession.connectedPeers, with: .reliable)
                
            } catch {
                
                //  print("Unable to send action data to peers")
                
            }
            
        }
        
    }
    
    @objc func didEnterBackground() {
        
        mcSession.disconnect()
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        
    }
    
    @objc func didBecomeActive() {
        
        connected = false
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: VRMultipeerController.serviceType)
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: VRMultipeerController.serviceType)
        serviceBrowser.delegate = self
        
    }
    
    /// override in child class
    func handleSharedData(_ data: Data, from peer: MCPeerID) {  }
    
}
