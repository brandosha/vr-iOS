//
//  MultiplayerViewController.swift
//  VR on iOS
//
//  Created by Emily on 9/15/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation

class MultiplayerViewController: VRMultipeerController {
    
    override func loadView() {
        
        super.loadView()
        
        // ARMode = false
        measurmentType = .meters
        interactive = true
        
        let mainScene = MainScene(self)
        scenes["main scene"] = mainScene
        
        displayScene("main scene")
        
    }
    
}
