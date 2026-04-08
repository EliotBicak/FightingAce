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

    // MARK: - Player
    var playerJet: SKSpriteNode!

    // MARK: - Armament
    var armamentAtlas: SKTextureAtlas!
    
    let maxBulletRange: CGFloat = 600.0
    let maxMissileRange: CGFloat = 1200.0
    var roundsPerMinute: CGFloat = 900
    var lastGunFireTime: TimeInterval = 0.0
    
    var activeBullets: [SKSpriteNode] = []
    var activeMissiles: [SKSpriteNode] = []
    
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
        createPlayer()
        setupCamera()
        setupControls()
        throttleInput = 0.35
        setThrottleKnobPosition()
        updateChunks()
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
        
        // Projectile Updates
        let bulletSpeed: CGFloat = 12.0
        let missileSpeed: CGFloat = 8.0

        activeBullets = activeBullets.filter { bullet in
            let heading = bullet.userData?.value(forKey: "heading") as! CGFloat

            bullet.position.x += -sin(heading) * bulletSpeed
            bullet.position.y += cos(heading) * bulletSpeed

            let dist = hypot(bullet.position.x - playerJet.position.x,
                             bullet.position.y - playerJet.position.y)
            if dist > maxBulletRange {
                bullet.removeFromParent()
                return false
            }
            return true
        }

        activeMissiles = activeMissiles.filter { missile in
            let heading = missile.userData?.value(forKey: "heading") as! CGFloat

            missile.position.x += -sin(heading) * missileSpeed
            missile.position.y += cos(heading) * missileSpeed

            let dist = hypot(missile.position.x - playerJet.position.x,
                             missile.position.y - playerJet.position.y)
            if dist > maxMissileRange {
                missile.removeFromParent()
                return false
            }
            return true
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cam = camera else { return }

        for touch in touches {
            let location = touch.location(in: cam)
            let touchedNode = cam.atPoint(location)

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
                fireGun()
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
    }

    func fireMissile() {
        let texture = armamentAtlas.textureNamed("aim120")
        texture.filteringMode = .nearest
        let missile = SKSpriteNode(texture: texture)
        missile.setScale(0.12)
        missile.zRotation = playerJet.zRotation
        missile.position = playerJet.position
        missile.zPosition = 0.9
        
        // Store heading at time of firing
        missile.userData = NSMutableDictionary()
        missile.userData?.setValue(playerJet.zRotation, forKey: "heading")
        
        addChild(missile)
        activeMissiles.append(missile)
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
                x: sin(playerJet.zRotation) * -40,
                y: cos(playerJet.zRotation) * -40,
                duration: 1.8
            )
            let fade = SKAction.fadeOut(withDuration: 1.8)
            let shrink = SKAction.scale(to: 0.02, duration: 1.8)
            let group = SKAction.group([drift, fade, shrink])
            let remove = SKAction.removeFromParent()
            flare.run(SKAction.sequence([group, remove]))
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



