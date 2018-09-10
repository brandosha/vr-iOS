//
//  VRObject.swift
//  VR on iOS
//
//  Created by Brandon on 7/5/18.
//  Copyright © 2018 test. All rights reserved.
//

import Foundation
import SceneKit

class VRObject: SCNNode {
    
    enum VRObjectType {
        
        case dynamic
        case `static`
        
    }
    
    /// Set this function to define what happens when the item is used, return true if it is used or false if it isn't
    var useObjectFunc: ((VRObject) -> Bool)?
    /// Phrase that describes the use of the object
    var useObjectStr: String = "Use"
    
    /// Set this function to define what happens when the item is taken, return true if it is taken or false if it isn't
    var takeObjectFunc: (() -> Bool)?
    
    /// Set this function to define what happens when the item is put back, return true if it is replaced or false if it isn't
    var replaceObjectFunc: (() -> Bool)?
    
    var holdingImage: UIImage = UIImage()
    
    var type: VRObjectType
    var tags: [String] = []
    
    var findable = true
    
    private var actualOpacity: CGFloat
    override var opacity: CGFloat {
        
        get {
            
            return super.opacity
            
        }
        
        set {
            
            super.opacity = opacity
            actualOpacity = opacity
            
        }
        
    }
    
    init(geometry: SCNGeometry, type: VRObjectType, tags: [String] = []) {
        
        self.type = type
        self.actualOpacity = 1
        self.tags = tags
        
        super.init()
        super.geometry = geometry
        opacity = 1
        
    }
    
    init?(fromFile: SCNScene, objectName: String, type: VRObjectType, tags: [String] = []) {
        
        self.type = type
        self.tags = tags
        
        guard let object = fromFile.rootNode.childNode(withName: objectName, recursively: true) else {
            
            return nil
            
        }
        
        actualOpacity = object.opacity
        
        super.init()
        
        opacity = object.opacity
        
        transform = object.transform
        geometry = object.geometry
        name = object.name
        castsShadow = object.castsShadow
        
        for player in object.audioPlayers {
            
            addAudioPlayer(player)
            
        }
        
        if let particleSystems = object.particleSystems {
            
            for particles in particleSystems {
                
                addParticleSystem(particles)
                
            }
            
        }
        
    }
    
    init(_ fromNode: SCNNode, type: VRObjectType, tags: [String] = []) {
        
        self.type = type
        self.actualOpacity = fromNode.opacity
        self.tags = tags
        
        super.init()
        
        opacity = fromNode.opacity
        
        transform = fromNode.transform
        geometry = fromNode.geometry
        name = fromNode.name
        castsShadow = fromNode.castsShadow
        
        for player in fromNode.audioPlayers {
            
            addAudioPlayer(player)
            
        }
        
        if let particleSystems = fromNode.particleSystems {
            
            for particles in particleSystems {
                
                addParticleSystem(particles)
                
            }
            
        }
        
        fromNode.parent?.addChildNode(self)
        fromNode.removeFromParentNode()
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func use(on object: VRObject) -> Bool {
        
        guard let used = useObjectFunc?(object) else {
            
            return false
            
        }
        
        return used
        
    }
    
    func take() -> Bool {
        
        if type == .static {
            
            return false
            
        }
        
        guard let taken = takeObjectFunc?() else {
            
            castsShadow = false
            super.opacity = 0.001
            return true
            
        }
        
        if taken {
            
            castsShadow = false
            super.opacity = 0.001
            
        }
        
        return taken
        
    }
    
    func replace() -> Bool {
        
        if type == .static {
            
            return false
            
        }
        
        guard let replaced = replaceObjectFunc?() else {
            
            super.opacity = actualOpacity
            castsShadow = true
            return true
            
        }
        
        if replaced {
            
            super.opacity = actualOpacity
            castsShadow = true
            
        }
        
        return replaced
        
    }
    
}
