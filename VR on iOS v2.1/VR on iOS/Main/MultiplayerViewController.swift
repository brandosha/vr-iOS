//
//  MultiplayerViewController.swift
//  VR on iOS
//
//  Created by Emily on 9/15/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation
import UIKit

class MultiplayerViewController: VRMultipeerController {
    
    override func loadView() {
        
        super.loadView()
        
        ARMode = true
        safetyNet = false
        measurmentType = .meters
        interactive = true
        
        let mainScene = MainScene(self)
        scenes["main scene"] = mainScene
        
        displayScene("main scene")
        
        // scene.background.contents = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        
    }
    
}
