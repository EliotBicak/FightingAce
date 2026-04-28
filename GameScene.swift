//
//  GameScene.swift
//  FightingAce
//
//  Created by Eliot R. Bicak on 2/11/26.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Terrain System
    let chunkSize = 32
    let tileSize: CGFloat = 16

    var loadedChunks: [String: SKTileMapNode] = [:]
    var terrainTileSet: SKTileSet!
    
    // MARK: - Score / Game State
    var score: Int = 0
    var scoreLabel: SKLabelNode!

    var isGameOver: Bool = false

    // MARK: - Player
    var playerJet: SKSpriteNode!

    // MARK: - Enemy
    var enemyAtlas: SKTextureAtlas!
    let maxEnemies = 3
    var activeEnemies: [EnemyJet] = []
    var lastEnemySpawnTime: TimeInterval = 0
    let enemySpawnInterval: TimeInterval = 8.0
    let enemyInitialSpawnDelay: TimeInterval = 5.0
    var gameStartTime: TimeInterval = 0
    
    // MARK: - Armament
    var armamentAtlas: SKTextureAtlas!
    
    let maxBulletRange: CGFloat = 600.0
    let maxMissileRange: CGFloat = 1200.0
    var roundsPerMinute: CGFloat = 900
    var lastGunFireTime: TimeInterval = 0.0
    var isGunButtonHeld: Bool = false
    
    var activeBullets: [SKSpriteNode] = []
    var activeMissiles: [SKSpriteNode] = []
    
    // MARK: - Missile Lock
    var lockedTarget: EnemyJet? = nil
    var lockProgress: CGFloat = 0.0
    var lockIndicator: SKShapeNode!
    var lockLabel: SKLabelNode!
    let lockRange: CGFloat = 500
    let lockAcquireTime: CGFloat = 0.5
    let lockConeAngle: CGFloat = CGFloat.pi / 4 // 45 degrees total-ish
    var lockingTarget: EnemyJet? = nil
    
    // MARK: - Camera
    var cam: SKCameraNode!

    // MARK: - Control State
    var turnInput: CGFloat = 0.0
    var movementInput = CGVector.zero
    var throttleInput: CGFloat = 0.5

    var joystickTouch: UITouch?
    var throttleTouch: UITouch?

    // MARK: - HUD Controls
    var joystickBase: SKSpriteNode!
    var joystickKnob: SKSpriteNode!

    var throttleTrack: SKSpriteNode!
    var throttleKnob: SKSpriteNode!

    var flareButton: SKShapeNode!
    var gunButton: SKShapeNode!
    var missileButton: SKShapeNode!
    var bombButton: SKShapeNode!

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        createTileSet()
        armamentAtlas = SKTextureAtlas(named: "Armament")
        enemyAtlas = SKTextureAtlas(named: "Jets")
        createPlayer()
        setupCamera()
        setupControls()
        setupScoreLabel()
        throttleInput = 0.35
        setThrottleKnobPosition()
        updateChunks()
    }
    
    // MARK: - Score UI
    
    func setupScoreLabel() {
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.zPosition = 1200
        if let view = self.view {
            let halfHeight = view.bounds.height / 2
            scoreLabel.position = CGPoint(x: 0, y: halfHeight - 50)
        }
        cam.addChild(scoreLabel)
    }

    // MARK: - Tile Map Creation

    func createTileSet() {
        let atlas = SKTextureAtlas(named: "Environment")

        let textures = [
            "grass0", "grass1", "grass2",
            "sand0",
            "water0",
            "rock0",
            "mud0"
        ].map { name -> SKTexture in
            let tex = atlas.textureNamed(name)
            tex.filteringMode = .nearest
            return tex
        }

        let grassDefs = [
            SKTileDefinition(texture: textures[0]),
            SKTileDefinition(texture: textures[1]),
            SKTileDefinition(texture: textures[2])
        ]

        let grassGroup = SKTileGroup(
            rules: [SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: grassDefs)]
        )

        let sandGroup = SKTileGroup(tileDefinition: SKTileDefinition(texture: textures[3]))
        let waterGroup = SKTileGroup(tileDefinition: SKTileDefinition(texture: textures[4]))
        let rockGroup = SKTileGroup(tileDefinition: SKTileDefinition(texture: textures[5]))
        let mudGroup = SKTileGroup(tileDefinition: SKTileDefinition(texture: textures[6]))

        terrainTileSet = SKTileSet(tileGroups: [
            grassGroup, // 0
            sandGroup,  // 1
            waterGroup, // 2
            rockGroup,  // 3
            mudGroup    // 4
        ])
    }

    // MARK: - Player

    func createPlayer() {
        playerJet = SKSpriteNode(imageNamed: "f22")
        playerJet.position = CGPoint(x: 0, y: 0)
        playerJet.zPosition = 1
        playerJet.setScale(0.1)
        
        addChild(playerJet)
    }

    // MARK: - Enemy Spawning
    func spawnEnemy() {
        guard activeEnemies.count < maxEnemies else { return }
        guard let view = self.view else { return }

        let spriteName = EnemyJet.spriteNames.randomElement()!
        let texture = enemyAtlas.textureNamed(spriteName)
        texture.filteringMode = .nearest

        let enemy = EnemyJet(texture: texture)
        let scale = EnemyJet.spriteScales[spriteName] ?? 0.09
        enemy.setScale(scale)
        enemy.zPosition = 1
        enemy.turnRate = CGFloat.random(in: 0.025...0.05)
        enemy.flySpeed = CGFloat.random(in: 1.8...2.8)

        // Spawn off screen relative to camera
        let halfW = view.bounds.width / 2 + 200
        let halfH = view.bounds.height / 2 + 200
        let side = Int.random(in: 0...3)
        var spawnPos = CGPoint.zero

        switch side {
        case 0: spawnPos = CGPoint(x: cam.position.x + CGFloat.random(in: -halfW...halfW),
                                    y: cam.position.y + halfH)
        case 1: spawnPos = CGPoint(x: cam.position.x + CGFloat.random(in: -halfW...halfW),
                                    y: cam.position.y - halfH)
        case 2: spawnPos = CGPoint(x: cam.position.x + halfW,
                                    y: cam.position.y + CGFloat.random(in: -halfH...halfH))
        default: spawnPos = CGPoint(x: cam.position.x - halfW,
                                     y: cam.position.y + CGFloat.random(in: -halfH...halfH))
        }

        enemy.position = spawnPos
        let dx = playerJet.position.x - spawnPos.x
        let dy = playerJet.position.y - spawnPos.y
        enemy.heading = atan2(-dx, dy)
        enemy.zRotation = enemy.heading
        enemy.zRotation = enemy.heading

        addChild(enemy)
        activeEnemies.append(enemy)
    }
    
    // MARK: - Camera

    func setupCamera() {
        cam = SKCameraNode()
        camera = cam
        addChild(cam)
    }

    // MARK: - Controls UI

    func setupControls() {
        guard let view = self.view else { return }

        let halfW = view.bounds.width / 2
        let halfH = view.bounds.height / 2

        let leftX = -halfW + 90
        let rightX = halfW - 90
        let bottomY = -halfH + 110

        // JOYSTICK BASE
        joystickBase = SKSpriteNode(color: .black, size: CGSize(width: 90, height: 90))
        joystickBase.alpha = 0.45
        joystickBase.zPosition = 1000
        joystickBase.position = CGPoint(x: leftX, y: bottomY - 20)
        cam.addChild(joystickBase)

        // JOYSTICK KNOB
        joystickKnob = SKSpriteNode(color: .white, size: CGSize(width: 40, height: 40))
        joystickKnob.alpha = 0.9
        joystickKnob.zPosition = 1001
        joystickKnob.position = joystickBase.position
        cam.addChild(joystickKnob)

        // FLARE BUTTON
        flareButton = makeButton(
            named: "flareButton",
            label: "CF",
            radius: 28,
            position: CGPoint(x: leftX + 95, y: bottomY - 35)
        )
        flareButton.zPosition = 1000
        cam.addChild(flareButton)

        // THROTTLE TRACK
        throttleTrack = SKSpriteNode(color: .black, size: CGSize(width: 26, height: 150))
        throttleTrack.alpha = 0.45
        throttleTrack.zPosition = 1000
        throttleTrack.position = CGPoint(x: rightX - 35, y: bottomY + 20)
        cam.addChild(throttleTrack)

        // THROTTLE KNOB
        throttleKnob = SKSpriteNode(color: .white, size: CGSize(width: 32, height: 32))
        throttleKnob.alpha = 0.95
        throttleKnob.zPosition = 1001
        throttleKnob.position = CGPoint(x: throttleTrack.position.x, y: throttleTrack.position.y)
        cam.addChild(throttleKnob)

        // RIGHT-SIDE BUTTONS
        gunButton = makeButton(
            named: "gunButton",
            label: "G",
            radius: 24,
            position: CGPoint(x: rightX + 30, y: bottomY + 70)
        )
        gunButton.zPosition = 1000

        missileButton = makeButton(
            named: "missileButton",
            label: "M",
            radius: 24,
            position: CGPoint(x: rightX + 30, y: bottomY + 5)
        )
        missileButton.zPosition = 1000

        bombButton = makeButton(
            named: "bombButton",
            label: "B",
            radius: 24,
            position: CGPoint(x: rightX + 30, y: bottomY - 60)
        )
        bombButton.zPosition = 1000

        cam.addChild(gunButton)
        cam.addChild(missileButton)
        cam.addChild(bombButton)
        
        // LOCK INDICATOR
        lockIndicator = SKShapeNode(circleOfRadius: 36)
        lockIndicator.strokeColor = .green
        lockIndicator.fillColor = .clear
        lockIndicator.lineWidth = 2
        lockIndicator.alpha = 0
        lockIndicator.zPosition = 1100
        cam.addChild(lockIndicator)

        lockLabel = SKLabelNode(text: "LOCK")
        lockLabel.fontName = "AvenirNext-Bold"
        lockLabel.fontSize = 13
        lockLabel.fontColor = .green
        lockLabel.verticalAlignmentMode = .center
        lockLabel.position = CGPoint(x: 0, y: -52)
        lockLabel.alpha = 0
        lockIndicator.addChild(lockLabel)
    }

    func makeButton(named: String, label: String, radius: CGFloat, position: CGPoint) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: radius)
        button.name = named
        button.fillColor = .gray
        button.strokeColor = .white
        button.lineWidth = 2
        button.alpha = 0.5
        button.position = position

        let text = SKLabelNode(text: label)
        text.name = named
        text.fontName = "AvenirNext-Bold"
        text.fontSize = 18
        text.verticalAlignmentMode = .center
        text.horizontalAlignmentMode = .center
        button.addChild(text)

        return button
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        updateChunks()
        
        if gameStartTime == 0 {
            gameStartTime = currentTime
        }
        
        // Gun held logic
        if isGunButtonHeld {
            fireGun()
        }

        // Throttle controls forward speed
        let minSpeed: CGFloat = 1.2
        let maxSpeed: CGFloat = 4.0
        let speed = minSpeed + (maxSpeed - minSpeed) * throttleInput

        // Joystick controls turning
        let turnRate: CGFloat = 0.05
        playerJet.zRotation -= turnInput * turnRate

        // Move forward in the direction the jet is facing
        let forwardX = -sin(playerJet.zRotation)
        let forwardY = cos(playerJet.zRotation)

        playerJet.position.x += forwardX * speed
        playerJet.position.y += forwardY * speed

        // Camera follow
        let cameraSpeed: CGFloat = 0.08
        cam.position.x += (playerJet.position.x - cam.position.x) * cameraSpeed
        cam.position.y += (playerJet.position.y - cam.position.y) * cameraSpeed
        
        updateEnemies(currentTime: currentTime)
        updateLockOn()
        
        // Spawn enemies on interval
        let timeSinceStart = currentTime - gameStartTime

        if timeSinceStart >= enemyInitialSpawnDelay &&
           currentTime - lastEnemySpawnTime >= enemySpawnInterval {
            lastEnemySpawnTime = currentTime
            spawnEnemy()
        }
        
        // Projectile Updates
        let bulletSpeed: CGFloat = 12.0
        let missileSpeed: CGFloat = 8.0

        activeBullets = activeBullets.filter { bullet in
            let heading = bullet.userData?.value(forKey: "heading") as! CGFloat

            bullet.position.x += -sin(heading) * bulletSpeed
            bullet.position.y += cos(heading) * bulletSpeed

            // REPLACE old dist check with this:
            let spawnX = bullet.userData?.value(forKey: "spawnX") as! CGFloat
            let spawnY = bullet.userData?.value(forKey: "spawnY") as! CGFloat
            let dist = hypot(bullet.position.x - spawnX, bullet.position.y - spawnY)
            if dist > maxBulletRange {
                bullet.removeFromParent()
                return false
            }
            return true
        }

        activeMissiles = activeMissiles.filter { missile in
            var heading = missile.userData?.value(forKey: "heading") as! CGFloat
            let isEnemy = missile.userData?.value(forKey: "isEnemy") as? Bool ?? false

            if !isEnemy, let target = missile.userData?.value(forKey: "target") as? EnemyJet,
               target.parent != nil {
                let dx = target.position.x - missile.position.x
                let dy = target.position.y - missile.position.y
                let angleToTarget = atan2(dx, dy)

                var angleDiff = angleToTarget - heading
                while angleDiff > .pi  { angleDiff -= 2 * .pi }
                while angleDiff < -.pi { angleDiff += 2 * .pi }

                heading += angleDiff * 0.06
                missile.userData?.setValue(heading, forKey: "heading")
                missile.zRotation = heading
            }

            missile.position.x += -sin(heading) * missileSpeed
            missile.position.y +=  cos(heading) * missileSpeed

            // REPLACE old origin/dist check with this:
            let spawnX = missile.userData?.value(forKey: "spawnX") as! CGFloat
            let spawnY = missile.userData?.value(forKey: "spawnY") as! CGFloat
            let dist = hypot(missile.position.x - spawnX, missile.position.y - spawnY)
            if dist > maxMissileRange {
                missile.removeFromParent()
                return false
            }
            return true
        }
        
        checkCombatCollisions()
    }
    
    // MARK: - Asset Collision
    func checkCombatCollisions() {
        guard !isGameOver else { return }

        // Player bullets/missiles hitting enemies
        for enemy in activeEnemies {
            guard enemy.parent != nil else { continue }

            for bullet in activeBullets {
                guard bullet.parent != nil else { continue }

                let isEnemyBullet = bullet.name == "enemyBullet"
                if !isEnemyBullet && bullet.frame.intersects(enemy.frame) {
                    destroyEnemy(enemy)
                    bullet.removeFromParent()
                    return
                }
            }

            for missile in activeMissiles {
                guard missile.parent != nil else { continue }

                let isEnemyMissile = missile.name == "enemyMissile"
                if !isEnemyMissile && missile.frame.intersects(enemy.frame) {
                    destroyEnemy(enemy)
                    missile.removeFromParent()
                    return
                }
            }
        }

        // Enemy bullets/missiles hitting player
        for bullet in activeBullets {
            if bullet.name == "enemyBullet" && bullet.frame.intersects(playerJet.frame) {
                triggerDefeat()
                return
            }
        }

        for missile in activeMissiles {
            if missile.name == "enemyMissile" && missile.frame.intersects(playerJet.frame) {
                triggerDefeat()
                return
            }
        }
    }
    
    // MARK: - Enemy Destruction
    
    func destroyEnemy(_ enemy: EnemyJet) {
        enemy.removeFromParent()
        activeEnemies.removeAll { $0 == enemy }

        score += 1
        scoreLabel.text = "Score: \(score)"
    }
    
    func makeMenuButton(text: String, name: String, position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.name = name
        button.fontName = "AvenirNext-Bold"
        button.fontSize = 28
        button.fontColor = .white
        button.position = position
        button.zPosition = 2002
        return button
    }
    
    // MARK: - Player Destruction / Defeat
    
    func triggerDefeat() {
        isGameOver = true

        playerJet.removeFromParent()

        let overlay = SKSpriteNode(color: .red, size: CGSize(width: 1000, height: 1000))
        overlay.alpha = 0.85
        overlay.zPosition = 2000
        overlay.name = "defeatOverlay"
        cam.addChild(overlay)

        let defeatLabel = SKLabelNode(text: "DEFEAT")
        defeatLabel.fontName = "AvenirNext-Bold"
        defeatLabel.fontSize = 56
        defeatLabel.fontColor = .white
        defeatLabel.position = CGPoint(x: 0, y: 80)
        defeatLabel.zPosition = 2001
        overlay.addChild(defeatLabel)

        let replayButton = makeMenuButton(text: "REPLAY", name: "replayButton", position: CGPoint(x: 0, y: -20))
        let menuButton = makeMenuButton(text: "MAIN MENU", name: "mainMenuButton", position: CGPoint(x: 0, y: -100))

        overlay.addChild(replayButton)
        overlay.addChild(menuButton)
    }
    
    // MARK: - Enemy AI
    func updateEnemies(currentTime: TimeInterval) {
        activeEnemies = activeEnemies.filter { enemy in
            guard enemy.parent != nil else { return false }

            let dx = playerJet.position.x - enemy.position.x
            let dy = playerJet.position.y - enemy.position.y
            let distToPlayer = hypot(dx, dy)

            // Despawn if too far from player
            if distToPlayer > 1000 {
                enemy.removeFromParent()
                return false
            }

            // Correct angle using same convention as movement (-sin/cos)
            let angleToPlayer = atan2(-dx, dy)

            // Check if enemy is behind the player
            let playerFacing = playerJet.zRotation
            var angleBehindPlayer = (playerFacing + .pi) - angleToPlayer
            while angleBehindPlayer > .pi  { angleBehindPlayer -= 2 * .pi }
            while angleBehindPlayer < -.pi { angleBehindPlayer += 2 * .pi }
            let isBehindPlayer = abs(angleBehindPlayer) < 0.6

            enemy.stateTimer -= 1.0 / 60.0

            if enemy.stateTimer <= 0 {
                switch enemy.state {
                case .pursuing:
                    if distToPlayer < 300 && isBehindPlayer {
                        enemy.stateTimer = 0.3
                    } else if distToPlayer < 200 {
                        enemy.state = .evading
                        enemy.stateTimer = TimeInterval(CGFloat.random(in: 0.8...1.5))
                    } else {
                        enemy.stateTimer = 0.3
                    }
                case .strafing:
                    enemy.state = .pursuing
                    enemy.stateTimer = TimeInterval(CGFloat.random(in: 0.5...1.2))
                case .evading:
                    enemy.state = .pursuing
                    enemy.stateTimer = TimeInterval(CGFloat.random(in: 1.0...2.0))
                }
            }

            var targetAngle = angleToPlayer

            switch enemy.state {
            case .pursuing:
                if distToPlayer > 300 {
                    targetAngle = angleToPlayer
                } else if !isBehindPlayer {
                    let sideOffset: CGFloat = angleBehindPlayer > 0 ? .pi * 0.6 : -.pi * 0.6
                    targetAngle = angleToPlayer + sideOffset
                } else {
                    targetAngle = angleToPlayer
                }
            case .strafing:
                targetAngle = angleToPlayer + (.pi * 0.4)
            case .evading:
                targetAngle = angleToPlayer + .pi + CGFloat.random(in: -0.5...0.5)
            }

            // Smooth rotation
            var angleDiff = targetAngle - enemy.heading
            while angleDiff > .pi  { angleDiff -= 2 * .pi }
            while angleDiff < -.pi { angleDiff += 2 * .pi }
            enemy.heading += angleDiff * enemy.turnRate * 4
            enemy.zRotation = enemy.heading

            // Move forward using corrected vector
            let effectiveSpeed = distToPlayer > 400 ? enemy.flySpeed * 1.3 : enemy.flySpeed
            enemy.position.x += -sin(enemy.heading) * effectiveSpeed
            enemy.position.y +=  cos(enemy.heading) * effectiveSpeed

            // Gun attack
            let gunRange: CGFloat = 300
            if distToPlayer < gunRange && isBehindPlayer {
                let fireInterval = 60.0 / 400.0
                if currentTime - enemy.lastGunFireTime >= fireInterval {
                    enemy.lastGunFireTime = currentTime
                    spawnEnemyBullet(from: enemy)
                }
            }

            // Missile attack
            let missileRange: CGFloat = 600
            let missileCooldown: TimeInterval = 10.0
            if distToPlayer < missileRange && isBehindPlayer &&
               currentTime - enemy.lastMissileFireTime >= missileCooldown {
                enemy.lastMissileFireTime = currentTime
                spawnEnemyMissile(from: enemy)
            }

            return true
        }
    }

    func spawnEnemyBullet(from enemy: EnemyJet) {
        let texture = armamentAtlas.textureNamed("round")
        texture.filteringMode = .nearest
        let bullet = SKSpriteNode(texture: texture)
        bullet.setScale(0.07)
        bullet.zRotation = enemy.heading
        bullet.position = enemy.position
        bullet.zPosition = 0.9
        bullet.name = "enemyBullet"
        bullet.userData = NSMutableDictionary()
        bullet.userData?.setValue(enemy.heading, forKey: "heading")
        bullet.userData?.setValue(enemy.position.x, forKey: "spawnX")
        bullet.userData?.setValue(enemy.position.y, forKey: "spawnY")
        addChild(bullet)
        activeBullets.append(bullet)
    }

    func spawnEnemyMissile(from enemy: EnemyJet) {
        let texture = armamentAtlas.textureNamed("aim120")
        texture.filteringMode = .nearest
        let missile = SKSpriteNode(texture: texture)
        missile.setScale(0.08)
        missile.zRotation = enemy.heading
        missile.position = enemy.position
        missile.zPosition = 0.9
        missile.name = "enemyMissile"
        missile.userData = NSMutableDictionary()
        missile.userData?.setValue(enemy.heading, forKey: "heading")
        missile.userData?.setValue(true, forKey: "isEnemy")
        missile.userData?.setValue(enemy.position.x, forKey: "spawnX")
        missile.userData?.setValue(enemy.position.y, forKey: "spawnY")
        addChild(missile)
        activeMissiles.append(missile)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cam = camera else { return }

        for touch in touches {
            let location = touch.location(in: cam)
            let touchedNode = cam.atPoint(location)
            
            if isGameOver {
                if touchedNode.name == "replayButton" {
                    let newScene = GameScene(size: self.size)
                    newScene.scaleMode = self.scaleMode
                    view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
                } else if touchedNode.name == "mainMenuButton" {
                    let menuScene = MainMenuScene(size: self.size)
                    menuScene.scaleMode = self.scaleMode
                    view?.presentScene(menuScene, transition: .fade(withDuration: 0.5))
                }
                return
            }

            if joystickTouch == nil && joystickBase.contains(location) {
                joystickTouch = touch
                updateJoystick(at: location)
                continue
            }

            if throttleTouch == nil && throttleTrack.contains(location) {
                throttleTouch = touch
                updateThrottle(at: location)
                continue
            }

            if touchedNode.name == "flareButton" {
                deployFlare()
            } else if touchedNode.name == "gunButton" {
                isGunButtonHeld = true
            } else if touchedNode.name == "missileButton" {
                fireMissile()
            } else if touchedNode.name == "bombButton" {
                dropBomb()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cam = camera else { return }

        for touch in touches {
            let location = touch.location(in: cam)

            if touch == joystickTouch {
                updateJoystick(at: location)
            } else if touch == throttleTouch {
                updateThrottle(at: location)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                joystickTouch = nil
                resetJoystick()
            } else if touch == throttleTouch {
                throttleTouch = nil
            } else {
                isGunButtonHeld = false
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Joystick Logic

    func updateJoystick(at location: CGPoint) {
        let dx = location.x - joystickBase.position.x
        let dy = location.y - joystickBase.position.y

        let maxRadius: CGFloat = 45
        let distance = sqrt(dx * dx + dy * dy)

        if distance <= maxRadius {
            joystickKnob.position = location
        } else {
            let angle = atan2(dy, dx)
            joystickKnob.position = CGPoint(
                x: joystickBase.position.x + cos(angle) * maxRadius,
                y: joystickBase.position.y + sin(angle) * maxRadius
            )
        }

        let inputDX = joystickKnob.position.x - joystickBase.position.x
        let inputDY = joystickKnob.position.y - joystickBase.position.y

        movementInput = CGVector(dx: inputDX / maxRadius, dy: inputDY / maxRadius)

        // Horizontal axis controls turning
        turnInput = movementInput.dx
    }

    func resetJoystick() {
        joystickKnob.position = joystickBase.position
        movementInput = .zero
        turnInput = 0.0
    }

    // MARK: - Throttle Logic

    func updateThrottle(at location: CGPoint) {
        let halfHeight: CGFloat = 75
        let minY = throttleTrack.position.y - halfHeight
        let maxY = throttleTrack.position.y + halfHeight

        let clampedY = max(min(location.y, maxY), minY)
        throttleKnob.position = CGPoint(x: throttleTrack.position.x, y: clampedY)

        throttleInput = (clampedY - minY) / (maxY - minY)
    }
    
    func setThrottleKnobPosition() {
        let halfHeight: CGFloat = 75
        let minY = throttleTrack.position.y - halfHeight
        let maxY = throttleTrack.position.y + halfHeight

        let knobY = minY + (maxY - minY) * throttleInput
        throttleKnob.position = CGPoint(x: throttleTrack.position.x, y: knobY)
    }

    // MARK: - Armament Actions

    func fireGun() {
        let now = CACurrentMediaTime()
        let fireInterval = 60.0 / Double(roundsPerMinute)
        guard now - lastGunFireTime >= fireInterval else {return}
        lastGunFireTime = now
        
        let texture = armamentAtlas.textureNamed("round")
        texture.filteringMode = .nearest
        let bullet = SKSpriteNode(texture: texture)
        bullet.setScale(0.07)
        bullet.zRotation = playerJet.zRotation
        bullet.position = playerJet.position
        bullet.zPosition = 0.9
        
        addChild(bullet)
        activeBullets.append(bullet)
        bullet.userData = NSMutableDictionary()
        bullet.userData?.setValue(playerJet.zRotation, forKey: "heading")
        
        bullet.userData?.setValue(playerJet.position.x, forKey: "spawnX")
        bullet.userData?.setValue(playerJet.position.y, forKey: "spawnY")
    }

    func fireMissile() {
        let texture = armamentAtlas.textureNamed("aim120")
        texture.filteringMode = .nearest
        let missile = SKSpriteNode(texture: texture)
        missile.setScale(0.08)
        missile.zRotation = playerJet.zRotation
        missile.position = playerJet.position
        missile.zPosition = 0.9
        missile.userData = NSMutableDictionary()
        missile.userData?.setValue(playerJet.zRotation, forKey: "heading")

        // Attach lock target if acquired
        if let target = lockedTarget {
            missile.userData?.setValue(target, forKey: "target")
            lockProgress = 0
            lockedTarget = nil
        }

        addChild(missile)
        activeMissiles.append(missile)
        
        missile.userData?.setValue(playerJet.position.x, forKey: "spawnX")
        missile.userData?.setValue(playerJet.position.y, forKey: "spawnY")
    }

    func dropBomb() {
        let texture = armamentAtlas.textureNamed("bomb")
        texture.filteringMode = .nearest
        let bomb = SKSpriteNode(texture: texture)
        bomb.setScale(0.12)
        bomb.zRotation = playerJet.zRotation
        bomb.position = playerJet.position
        bomb.zPosition = 0.9
        
        addChild(bomb)
        
        let shrink  = SKAction.scale(to: 0.0, duration: 1.5)
        let fade = SKAction.fadeOut(withDuration: 1.5)
        let group = SKAction.group([shrink, fade])
        let remove = SKAction.removeFromParent()
        bomb.run(SKAction.sequence([group, remove]))
    }

    func deployFlare() {
        let texture = armamentAtlas.textureNamed("flare")
            texture.filteringMode = .nearest
            let flare = SKSpriteNode(texture: texture)
            flare.setScale(0.1)
            flare.zRotation = playerJet.zRotation
            flare.position = playerJet.position
            flare.zPosition = 0.9

            addChild(flare)

            // Drift slightly backwards and to the side as it fades
            let drift = SKAction.moveBy(
                x: -sin(playerJet.zRotation) * -40,
                y: cos(playerJet.zRotation) * -40,
                duration: 1.8
            )
            let fade = SKAction.fadeOut(withDuration: 1.8)
            let shrink = SKAction.scale(to: 0.02, duration: 1.8)
            let group = SKAction.group([drift, fade, shrink])
            let remove = SKAction.removeFromParent()
            flare.run(SKAction.sequence([group, remove]))
    }
    
    // MARK: - Missile Lock
    func updateLockOn() {
        var bestTarget: EnemyJet? = nil
        var bestDistance = lockRange

        let playerHeading = playerJet.zRotation

        for enemy in activeEnemies {
            guard enemy.parent != nil else { continue }

            let dx = enemy.position.x - playerJet.position.x
            let dy = enemy.position.y - playerJet.position.y
            let dist = hypot(dx, dy)

            guard dist <= lockRange else { continue }

            // Angle from player to enemy using your movement convention
            let angleToEnemy = atan2(-dx, dy)

            var angleDiff = angleToEnemy - playerHeading
            while angleDiff > .pi { angleDiff -= 2 * .pi }
            while angleDiff < -.pi { angleDiff += 2 * .pi }

            // Enemy must be inside forward cone
            if abs(angleDiff) <= lockConeAngle {
                if dist < bestDistance {
                    bestDistance = dist
                    bestTarget = enemy
                }
            }
        }

        if let target = bestTarget {

            if lockingTarget !== target {
                lockingTarget = target
                lockProgress = 0
            }

            lockProgress = min(lockProgress + (1.0 / 60.0) / lockAcquireTime, 1.0)
            lockedTarget = lockProgress >= 1.0 ? target : nil

            let targetInCam = convert(target.position, to: cam)
            lockIndicator.position = targetInCam
            lockIndicator.alpha = 1.0
            lockIndicator.strokeColor = lockProgress >= 1.0 ? .red : .green
            lockIndicator.setScale(lockProgress >= 1.0 ? 1.0 : 1.0 + (1.0 - lockProgress) * 0.8)

            lockLabel.alpha = lockProgress >= 1.0 ? 1.0 : 0.0

        } else {
            lockingTarget = nil
            lockProgress = 0
            lockedTarget = nil
            lockIndicator.alpha = 0
            lockLabel.alpha = 0
        }
    }

    // MARK: - Terrain System

    func currentChunk() -> (Int, Int) {
        let chunkPixelSize = CGFloat(chunkSize) * tileSize
        let chunkX = Int(floor(playerJet.position.x / chunkPixelSize))
        let chunkY = Int(floor(playerJet.position.y / chunkPixelSize))
        return (chunkX, chunkY)
    }

    func updateChunks() {
        let (cx, cy) = currentChunk()
        let renderDistance = 2

        for x in (cx-renderDistance)...(cx+renderDistance) {
            for y in (cy-renderDistance)...(cy+renderDistance) {
                let key = "\(x),\(y)"

                if loadedChunks[key] == nil {
                    let chunk = generateChunk(chunkX: x, chunkY: y)
                    loadedChunks[key] = chunk
                    addChild(chunk)
                }
            }
        }

        unloadFarChunks(cx: cx, cy: cy)
    }

    func unloadFarChunks(cx: Int, cy: Int) {
        let renderDistance = 2

        for key in loadedChunks.keys {
            let coords = key.split(separator: ",")
            let x = Int(coords[0])!
            let y = Int(coords[1])!

            if abs(x - cx) > renderDistance || abs(y - cy) > renderDistance {
                if let chunk = loadedChunks[key] {
                    chunk.removeFromParent()
                }
                loadedChunks.removeValue(forKey: key)
            }
        }
    }

    func generateChunk(chunkX: Int, chunkY: Int) -> SKTileMapNode {
        let tileMap = SKTileMapNode(
            tileSet: terrainTileSet,
            columns: chunkSize,
            rows: chunkSize,
            tileSize: CGSize(width: tileSize, height: tileSize)
        )

        let chunkPixelSize = CGFloat(chunkSize) * tileSize
        tileMap.position = CGPoint(
            x: CGFloat(chunkX) * chunkPixelSize,
            y: CGFloat(chunkY) * chunkPixelSize
        )

        let biomeNoise = GKNoise(GKPerlinNoiseSource(
            frequency: 0.03,
            octaveCount: 4,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: 12345
        ))

        let biomeMap = GKNoiseMap(
            biomeNoise,
            size: vector_double2(1, 1),
            origin: vector_double2(Double(chunkX), Double(chunkY)),
            sampleCount: vector_int2(Int32(chunkSize), Int32(chunkSize)),
            seamless: false
        )

        let variationNoise = GKNoise(GKPerlinNoiseSource(
            frequency: 0.2,
            octaveCount: 2,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: 54321
        ))

        let variationMap = GKNoiseMap(
            variationNoise,
            size: vector_double2(1, 1),
            origin: vector_double2(Double(chunkX), Double(chunkY)),
            sampleCount: vector_int2(Int32(chunkSize), Int32(chunkSize)),
            seamless: false
        )

        for column in 0..<chunkSize {
            for row in 0..<chunkSize {
                let biomeValue = biomeMap.value(at: vector_int2(Int32(column), Int32(row)))
                let variationValue = variationMap.value(at: vector_int2(Int32(column), Int32(row)))

                let tileGroup: SKTileGroup

                switch biomeValue {
                case -1.0..<(-0.6):
                    tileGroup = terrainTileSet.tileGroups[2] // water

                case -0.6..<(-0.3):
                    tileGroup = terrainTileSet.tileGroups[1] // sand

                case -0.3..<0.2:
                    if variationValue < -0.33 {
                        tileGroup = terrainTileSet.tileGroups[0]
                    } else if variationValue < 0.33 {
                        tileGroup = terrainTileSet.tileGroups[0]
                    } else {
                        tileGroup = terrainTileSet.tileGroups[0]
                    }

                case 0.2..<0.5:
                    tileGroup = terrainTileSet.tileGroups[4] // mud

                default:
                    tileGroup = terrainTileSet.tileGroups[3] // rock
                }

                tileMap.setTileGroup(tileGroup, forColumn: column, row: row)
            }
        }

        return tileMap
    }
}

// MARK: - Enemy Jet Class
class EnemyJet: SKSpriteNode {

    enum AIState {
        case pursuing
        case strafing
        case evading
    }

    var state: AIState = .pursuing
    var health: Int = 3
    var lastGunFireTime: TimeInterval = 0
    var lastMissileFireTime: TimeInterval = 0
    var stateTimer: TimeInterval = 0
    var heading: CGFloat = 0

    // How aggressively this enemy turns (randomized per instance)
    var turnRate: CGFloat = 0.03
    var flySpeed: CGFloat = 2.2

    static let spriteNames = ["f4", "f18", "f16", "f35", "j20", "mig19", "mig35", "su57"]
    
    static let spriteScales: [String: CGFloat] = [
        "f4": 0.1,
        "f18": 0.25,
        "f16": 0.2,
        "f35": 0.25,
        "j20": 0.09,
        "mig19": 0.1,
        "mig35": 0.1,
        "su57": 0.25
    ]
}
