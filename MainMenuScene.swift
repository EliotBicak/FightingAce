//
//  MainMenuScene.swift
//  FightingAce
//
//  Created by Eliot R. Bicak on 4/27/26.
//

import SpriteKit

class MainMenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black

        let title = SKLabelNode(text: "FightingAce")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 54
        title.fontColor = .white
        title.position = CGPoint(x: frame.midX, y: frame.midY + 100)
        addChild(title)

        let play = SKLabelNode(text: "PLAY")
        play.name = "playButton"
        play.fontName = "AvenirNext-Bold"
        play.fontSize = 36
        play.fontColor = .white
        play.position = CGPoint(x: frame.midX, y: frame.midY - 20)
        addChild(play)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let node = atPoint(location)

        if node.name == "playButton" {
            let gameScene = GameScene(size: size)
            gameScene.scaleMode = scaleMode
            view?.presentScene(gameScene, transition: .fade(withDuration: 0.5))
        }
    }
}
