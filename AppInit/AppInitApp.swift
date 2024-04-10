//
//  AppInitApp.swift
//  AppInit
//
//  Created by Emilia Elgfors on 2024-04-09.
//

import SwiftUI

@main
struct AppInitApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(Router())
        }
    }
}
