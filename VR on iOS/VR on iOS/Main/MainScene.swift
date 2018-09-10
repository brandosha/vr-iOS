//
//  MainScene.swift
//  VR on iOS
//
//  Created by Brandon on 9/3/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation
import SceneKit

class MainScene: VRScene {
    
    var scene: SCNScene = SCNScene(named: "art.scnassets/ship.scn")!
    
    required init(_ current: VRViewController) {
        
    }
    
    func setup() {
        
        var ship = scene.rootNode.childNode(withName: "shipMesh", recursively: true)!
        ship = VRObject(ship, type: .static)
        
        func highlight(object: VRObject) -> Bool {
            
            // get its material
            let material = object.geometry!.firstMaterial!
            
            // highlight it
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            
            // on completion - unhighlight
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                
                material.emission.contents = UIColor.black
                
                SCNTransaction.commit()
            }
            
            material.emission.contents = UIColor.red
            
            SCNTransaction.commit()
            
            return true
            
        }
        
        (ship as! VRObject).useObjectFunc = highlight
        
    }
    
    func switchSceneSetup() {
        
    }
    
}
