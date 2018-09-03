//
//  MainViewController.swift
//  VR on iOS
//
//  Created by Emily on 9/3/18.
//  Copyright © 2018 Brandon. All rights reserved.
//

import Foundation

class MainViewController: VRViewController {
    
    override func loadView() {
        
        super.loadView()
        
        ARMode = true
        measurmentType = .meters
        
        let mainScene = MainScene(self)
        scenes["main scene"] = mainScene
        
        displayScene("main scene")
        
    }
    
}
