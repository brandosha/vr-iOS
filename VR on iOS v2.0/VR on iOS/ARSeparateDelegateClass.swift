//
//  ARSeparateDelegateClass.swift
//  VR on iOS
//
//  Created by Brandon on 9/11/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation
import ARKit

class ARSeparateDelegateClass: NSObject, ARSCNViewDelegate {
    
    var current: VRViewController
    
    init(_ current: VRViewController) {
        
        self.current = current
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        // print("updating... \(time)")
        
        /*
        if current.ARMode {
            
            if let originalImage = current.session.currentFrame?.capturedImage {
                
                let ciImage = CIImage(cvImageBuffer: originalImage)
                if let cgImage = CIContext().createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: 1080, height: 1080)) {
                    
                    current.scene.background.contents = cgImage
                    
                } else {
                    
                    print("no background image")
                    
                }
                
            }
            
        }
        */
        
    }
    
}

