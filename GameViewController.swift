//
//  GameViewController.swift
//  FightingAce
//
//  Created by Eliot R. Bicak on 2/11/26.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make sure the view is an SKView
        if let view = self.view as? SKView {
            
            // Create your GameScene
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            
            // Present the Scene
            view.presentScene(scene)
            
            // OPTIONAL Debug Info
            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
