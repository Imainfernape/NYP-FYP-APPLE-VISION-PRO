import Foundation
import RealityKit
import Combine
import RealityKitContent

enum TrashType {
    case recyclable
    case nonRecyclable
}

enum ThrowDirection {
    case left
    case right
}

struct CustomComponent: Component {
    var hasGravity: Bool
    var gravityActivatedTime: TimeInterval?
    var hasCollided: Bool = false
}

@MainActor
class GameManager: ObservableObject {
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var lives: Int = 3
    @Published var gameOver: Bool = false
    @Published var finalScore: Int = 0
    @Published var finalCombo: Int = 0
    
    private var anchor: AnchorEntity?
    private var collisionSubscription: Cancellable?
    private var currentTrash: Entity?
    private var lastSpawnTime: TimeInterval = 0
    
    func startGame(using anchor: AnchorEntity) {
        self.anchor = anchor
        resetStats()
        
        Task {
            guard let immersiveScene = try? await Entity(named: "Immersive", in: RealityKitContent.realityKitContentBundle) else {
                print("❌ Failed to load Immersive scene")
                return
            }
            
            await MainActor.run {
                let ground = ModelEntity(mesh: .generatePlane(width: 5, depth: 10))
                ground.name = "Ground"
                ground.position = [0, -0.05, -6.5]
                ground.components.set(CollisionComponent(shapes: [.generateBox(size: [10, 0.2, 10])]))
                ground.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static))
                ground.generateCollisionShapes(recursive: true)
                anchor.addChild(ground)
                
                if let trashBin = immersiveScene.findEntity(named: "TrashBin") {
                    let bin = trashBin.clone(recursive: true)
                    bin.name = "TrashBin"
                    bin.position = [-1.0, 0.0, -6.5]
                    bin.components.set(CollisionComponent(shapes: [.generateBox(size: [0.6, 1.0, 0.6])]))
                    bin.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static))
                    bin.generateCollisionShapes(recursive: true)
                    anchor.addChild(bin)
                }
                
                if let recycleBin = immersiveScene.findEntity(named: "RecyclingBin") {
                    let bin = recycleBin.clone(recursive: true)
                    bin.name = "RecyclingBin"
                    bin.position = [1.0, 0.0, -5]
                    bin.components.set(CollisionComponent(shapes: [.generateBox(size: [0.6, 1.0, 0.6])]))
                    bin.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static))
                    bin.generateCollisionShapes(recursive: true)
                    anchor.addChild(bin)
                }
                
                if let scene = anchor.scene {
                    collisionSubscription = scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
                        Task { await self?.handleCollision(event: event) }
                    }
                }
            }
            
            await spawnTrash()
        }
    }
    
    func handleCollision(event: CollisionEvents.Began) async {
        guard !gameOver else { return }
        
        let trashEntity = [event.entityA, event.entityB].first {
            $0.name == "recyclable" || $0.name == "nonRecyclable"
        }
        
        guard let trash = trashEntity,
              var custom = trash.components[CustomComponent.self] else { return }
        
        let other = (trash == event.entityA) ? event.entityB : event.entityA
        
        if custom.hasCollided {
            print("🔁 Already collided")
            return
        }
        
        if !custom.hasGravity {
            print("⛔ Gravity not active")
            return
        }
        
        let resolvedTargetName = resolveBinOrGroundName(from: other)
        let trashType = trash.name
        
        switch resolvedTargetName {
        case "Ground":
            print("❌ Trash missed — hit ground")
            handleWrongSort()
        case "RecyclingBin" where trashType == "recyclable",
            "TrashBin" where trashType == "nonRecyclable":
            print("✅ Correct throw: \(trashType) → \(resolvedTargetName)")
            handleCorrectSort()
        case "RecyclingBin", "TrashBin":
            print("❌ Wrong throw: \(trashType) → \(resolvedTargetName)")
            handleWrongSort()
        default:
            print("🤷 Unknown collision with \(resolvedTargetName)")
            return
        }
        
        custom.hasCollided = true
        trash.components.set(custom)
        trash.removeFromParent()
        currentTrash = nil
        
        if !gameOver {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await spawnTrash()
        }
    }
    
    func resolveBinOrGroundName(from entity: Entity) -> String {
        var current: Entity? = entity
        while let c = current {
            if ["Ground", "TrashBin", "RecyclingBin"].contains(c.name) {
                return c.name
            }
            current = c.parent
        }
        return entity.name
    }
    
    func spawnTrash() async {
        guard !gameOver else { return }
        
        let now = Date().timeIntervalSince1970
        if now - lastSpawnTime < 1.0 { return }
        lastSpawnTime = now
        
        guard currentTrash == nil else {
            print("⚠️ Trash still active")
            return
        }
        
        guard let anchor = anchor else { return }
        
        let trashOptions: [(String, TrashType)] = [
            ("PlasticRecyclable", .recyclable),
            ("BatteryTrash", .nonRecyclable),
            ("RustyMetalTrash", .nonRecyclable)
        ]
        
        guard let selected = trashOptions.randomElement(),
              let scene = try? await Entity(named: "Immersive", in: RealityKitContent.realityKitContentBundle),
              let source = scene.findEntity(named: selected.0) else {
            print("⚠️ Trash not found")
            return
        }
        
        let trash = source.clone(recursive: true)
        trash.name = selected.1 == .recyclable ? "recyclable" : "nonRecyclable"
        trash.position = [0, 1.5 + Float.random(in: 0...0.05), -1.2 + Float.random(in: -0.05...0.05)]
        trash.transform.scale = {
            switch selected.0 {
            case "PlasticRecyclable":
                return SIMD3<Float>(repeating: 0.01)
            case "BatteryTrash":
                return SIMD3<Float>(repeating: 0.002)
            case "RustyMetalTrash":
                return SIMD3<Float>(repeating: 0.02)
            default:
                return SIMD3<Float>(repeating: 0.02)
            }
        }()
        trash.isEnabled = true
        
        trash.components.set(InputTargetComponent())
        trash.components.set(CollisionComponent(shapes: [.generateBox(size: [0.1, 0.2, 0.1])]))
        trash.generateCollisionShapes(recursive: true)
        trash.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static))
        trash.components.set(CustomComponent(hasGravity: false, gravityActivatedTime: nil, hasCollided: false))
        
        anchor.addChild(trash)
        currentTrash = trash
        print("🗑️ Spawned: \(trash.name)")
    }
    
    func throwCurrentTrash(toward direction: ThrowDirection) {
        guard !gameOver, let trash = currentTrash else {
            print("❌ No trash to throw")
            return
        }
        
        var custom = trash.components[CustomComponent.self] ?? CustomComponent(hasGravity: false, gravityActivatedTime: nil)
        if custom.hasGravity {
            print("⚠️ Already thrown")
            return
        }
        
        trash.components.remove(PhysicsBodyComponent.self)
        trash.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .dynamic))
        
        let velocity: SIMD3<Float> = direction == .left ? [-1.2, 3.5, -5.0] : [1.2, 3.5, -5.0]
        
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await MainActor.run {
                trash.components.set(PhysicsMotionComponent(linearVelocity: velocity))
                print("🏹 Motion applied: \(velocity)")
            }
        }
        
        custom.hasGravity = true
        custom.gravityActivatedTime = Date().timeIntervalSince1970
        trash.components.set(custom)
    }
    
    func activateGravity(for entity: Entity) {
        guard !gameOver else { return }
        
        Task {
            await MainActor.run {
                var custom = entity.components[CustomComponent.self] ?? CustomComponent(hasGravity: false, gravityActivatedTime: nil)
                
                if let body = entity.components[PhysicsBodyComponent.self], body.mode == .static {
                    entity.components.remove(PhysicsBodyComponent.self)
                    entity.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .dynamic))
                    entity.components.set(PhysicsMotionComponent(linearVelocity: [0, 1.0, -1.0]))
                    custom.hasGravity = true
                    custom.gravityActivatedTime = Date().timeIntervalSince1970
                    entity.components.set(custom)
                    print("🌍 Gravity activated for \(entity.name)")
                }
            }
        }
    }
    
    @MainActor
    func handleCorrectSort() {
            combo += 1
            score += 10 * combo
            print("✅ Correct! Score: \(score), Combo: \(combo)")
    }

    @MainActor
    func handleWrongSort() {
            combo = 0
            lives -= 1
            print("❌ Wrong! Lives left: \(lives)")
            if isGameOver() {
                gameOver = true
                finalScore = score
                finalCombo = combo
                print("🎮 Game Over!")
        }
    }
    
    @MainActor
    func resetStats() {
        score = 0
        combo = 0
        lives = 3
        finalScore = 0
        finalCombo = 0
        gameOver = false
        currentTrash = nil
    }

    func resetGame() {
        Task {
            resetStats()
            await spawnTrash()
        }
    }

        func isGameOver() -> Bool {
            return lives <= 0
        }
    }
