//
//  ContentView.swift
//  NYP FYP GAM APP
//
//  Created by SIT on 2/4/25.
//
import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            VStack {
                RealityView { content in
                    if !hasStarted {
                        let anchor = AnchorEntity()
                        content.add(anchor)
                        gameManager.startGame(using: anchor)
                        hasStarted = true
                    }
                }
                .edgesIgnoringSafeArea(.all)
                .frame(height: 500)

                VStack(spacing: 6) {
                    Text("Score: \(gameManager.score)")
                        .font(.title2)

                    Text("Combo: \(gameManager.combo)")
                        .font(.subheadline)

                    Text("Lives: \(gameManager.lives)")
                        .font(.subheadline)
                        .foregroundColor(gameManager.lives <= 1 ? .red : .primary)
                }
                .padding(.top, 10)

                ToggleImmersiveSpaceButton()
                    .padding(.top, 20)
            }

            if gameManager.gameOver {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("🎮 Game Over")
                        .font(.largeTitle)
                        .foregroundColor(.white)

                    Text("Final Score: \(gameManager.finalScore)")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text("Highest Combo: \(gameManager.finalCombo)")
                        .foregroundColor(.white)

                    Button("Restart") {
                        hasStarted = false
                        gameManager.resetGame()
                    }
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .animation(.easeInOut, value: gameManager.gameOver)
    }
}
