//
//  MultipeerVRController.swift
//  VR 360 app
//
//  Created by Brandon on 9/12/18.
//  Copyright © 2018 test. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import ARKit

class VRMultipeerController: VRViewController, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    static let serviceType = "vr-multipeer"
    
    private var myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var mcSession: MCSession!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    
    private var connected = false
    
    private var mapProvider: MCPeerID?
    
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
        
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        print("recieved invitation from peer: \(peerID) with context: \(context)")
        
        if !connected || mcSession.connectedPeers.isEmpty {
            
            invitationHandler(true, self.mcSession)
            
            connected = true
            
            serviceBrowser.stopBrowsingForPeers()
            
        }
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
        
        print("found peer: \(peerID) with discovery info: \(info)")
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
        // Do nothing
        
    }
    
    var peerNodes: [String:SCNNode] = [:]
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        if state == .connected && peerID != myPeerID && !connected && mapData != nil {
            
            print(peerID.displayName + " is now connected")
            
            do {
                
                try mcSession.send(mapData!, toPeers: [peerID], with: .reliable)
                
            } catch {
                
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
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                
                // Run the session with the received world map.
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                ARView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                // Remember who provided the map for showing UI feedback.
                mapProvider = peerID
                
                print("recieved world map from \(peerID.displayName)")
                
                return
                
            }
            else if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                // Add anchor to the session, ARSCNView delegate adds visible content.
                ARView.session.add(anchor: anchor)
                
                return
                
            }
            else {
                print("unknown data recieved from \(peerID.displayName)")
            }
        } catch {
            
            if PlayerLocation(data) == nil {
                
                print("can't decode map data recieved from \(peerID.displayName)")
            }
            
        }
        
        if let location = PlayerLocation(data) {
            
            print("Recieved location data, \(location) from \(peerID.displayName)")
            
            if let peerNode = peerNodes[peerID.displayName] {
                
                print("updating \(peerID.displayName)'s location")
                
                let actualPos = SCNVector3(
                    location.position.x * multiplier,
                    location.position.y * multiplier,
                    location.position.z * multiplier
                )
                
                let float3Pos = float3(actualPos.x, actualPos.y, actualPos.z)
                recentPeerPositions[peerID.displayName]?.append(float3Pos)
                
                let peerPositions = recentPeerPositions[peerID.displayName]!
                recentPeerPositions[peerID.displayName] = Array(peerPositions.suffix(10))
                
                let average = peerPositions.reduce(float3(0), { $0 + $1 }) / Float(peerPositions.count)
                let averagePos = SCNVector3(
                    average.x * multiplier,
                    average.y * multiplier,
                    average.z * multiplier
                )
                
                peerNode.position = averagePos
                peerNode.eulerAngles = location.rotation
                
            } else {
                
                print("adding cube to \(peerID.displayName)")
                
                let cube = SCNBox(width: CGFloat(0.2 * multiplier), height: CGFloat(0.2 * multiplier), length: CGFloat(0.2 * multiplier), chamferRadius: 0)
                cube.firstMaterial?.diffuse.contents = UIColor.black
                
                let peerNode = SCNNode(geometry: cube)
                
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
            
            print("Recieved action data from \(peerID.displayName)")
            
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
            
            print("Unable to decode action data")
            
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
            
            serviceBrowser.startBrowsingForPeers()
            
        }
        
    }
    
    var previousMappingStatus: ARFrame.WorldMappingStatus? = nil
    
    override func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        super.session(session, didUpdate: frame)
        
        if !mcSession.connectedPeers.isEmpty {
            
            let currentPos = ARView.pointOfView!.worldPosition
            let currentRot = ARView.pointOfView!.eulerAngles
            
            let data = PlayerLocation(position: currentPos, rotation: currentRot).asData
            
            do {
                
                try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .unreliable)
                
            } catch {
                
                print("Unable to send data to peers")
                
            }
            
        }
        
        if connected { return }
        
        switch frame.worldMappingStatus {
            
        case .notAvailable, .limited:
            
            if previousMappingStatus != .notAvailable {
                
                print("no world map available")
                
                previousMappingStatus = .notAvailable
                
            }
            
        case .extending:
            
            if previousMappingStatus != .extending {
                
                print("begun tracking world map")
                
                previousMappingStatus = .extending
                
            }
            
        case .mapped:
            
            if previousMappingStatus != .mapped {
                
                print("ready to send world map")
                
                previousMappingStatus = .mapped
                
            }
            
            session.getCurrentWorldMap { worldMap, error in
                
                guard let map = worldMap else {
                    
                    print("Error: \(error!.localizedDescription)")
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
                
                print("Could not take")
                
            } else {
                
                print("Taken successfully")
                
                holdingObject = object
                
                successful = true
                type = .taken
                
            }
            
        } else if holdingObject == object {
            
            let replaced = object.replace()
            
            if !replaced {
                
                print("Could not replace")
                
            } else {
                
                print("Replaced successfully")
                
                holdingObject = nil
                
                successful = true
                type = .replaced
                
            }
            
        } else if holdingObject != nil {
            
            let used = holdingObject!.use(on: object)
            
            if !used {
                
                print("Could not use")
                
            } else {
                
                print("Used successfully")
                
                successful = true
                type = .used
                
            }
            
        } else {
            
            let used = object.use(on: object)
            
            if !used {
                
                print("Could not use")
                
            } else {
                
                print("Used successfully")
                
                successful = true
                type = .used
                
            }
            
        }
        
        if type != nil && successful {
            
            let tapAction = TapAction(type: type!, lookingAtObject: object, holdingObject: holdingObject)
            
            do {
                
                print("Sending action data to peers")
                try mcSession.send(tapAction.asData, toPeers: mcSession.connectedPeers, with: .reliable)
                
            } catch {
                
                print("Unable to send action data to peers")
                
            }
            
        }
        
    }
    
    @objc func didEnterBackground() {
        
        mcSession.disconnect()
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        
    }
    
}
