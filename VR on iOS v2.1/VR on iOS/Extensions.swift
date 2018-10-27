//
//  Extensions.swift
//  VR 360 app
//
//  Created by Brandon on 7/5/18.
//  Copyright © 2018 test. All rights reserved.
//

import Foundation
import ARKit
import SceneKit
import Darwin

extension ARSCNView {
    
    func setup() {
        antialiasingMode = .none
        
        preferredFramesPerSecond = 30
        
        if let camera = pointOfView?.camera {
            camera.wantsHDR = false
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = 0
            camera.minimumExposure = -1
            camera.maximumExposure = 3
        }
    }
}

extension SCNNode {
    
    func distance(from node: SCNNode) -> Float {
        
        let node1Pos = node.presentation.worldPosition
        let node2Pos = self.presentation.worldPosition
        
        let distance = SCNVector3(
            node2Pos.x - node1Pos.x,
            node2Pos.y - node1Pos.y,
            node2Pos.z - node1Pos.z
        )
        
        let length: Float = sqrtf(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)
        
        return length
        
    }
    
    func setHighlighted(to: Bool) {
        
        let highlightedBitMask = 2
        
        if !to {
            
            categoryBitMask = 1
            
        } else {
            
            categoryBitMask = highlightedBitMask
            
        }
        
        for child in self.childNodes {
            
            if !to {
                
                child.setHighlighted(to: false)
                
            } else {
                
                child.setHighlighted(to: true)
                
            }
            
        }
        
    }
    
    static func fromFile(named: String) -> SCNNode? {
        
        guard let scene = SCNScene(named: named) else {
            return nil
        }
        
        let newNode = scene.rootNode
        
        return newNode
        
    }
    
}
