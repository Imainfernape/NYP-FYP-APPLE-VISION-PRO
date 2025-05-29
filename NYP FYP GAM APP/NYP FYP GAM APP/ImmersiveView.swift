//
//  ImmersiveView.swift
//  NYP FYP GAM APP
//
//  Created by SIT on 2/4/25.
//
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @StateObject private var gameManager = GameManager()
    @State private var didInitialize = false

    var body: some View {
        RealityView { content in
            if !didInitialize {
                let anchor = AnchorEntity(world: .zero)
                content.add(anchor)
                gameManager.startGame(using: anchor)
                didInitialize = true
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    var entity: Entity? = value.entity

                    while let current = entity,
                          current.name != "recyclable",
                          current.name != "nonRecyclable",
                          current.parent != nil {
                        entity = current.parent
                    }

                    if let resolved = entity {
                        print("📌 Tapped resolved entity: \(resolved.name)")
                        if resolved.name == "recyclable" || resolved.name == "nonRecyclable" {
                            gameManager.activateGravity(for: resolved)
                        } else {
                            print("⚠️ Tapped entity is not a trash item")
                        }
                    } else {
                        print("⚠️ Could not resolve tapped entity")
                    }
                }
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    let tapX = value.location.x
                    let mid = 512.0 // Adjust for your device resolution
                    if tapX < mid {
                        print("👈 Left throw tapped")
                        gameManager.throwCurrentTrash(toward: .left)
                    } else {
                        print("👉 Right throw tapped")
                        gameManager.throwCurrentTrash(toward: .right)
                    }
                }
        )
        .environmentObject(gameManager)
    }
}
