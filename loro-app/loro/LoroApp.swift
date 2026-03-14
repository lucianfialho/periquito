//
//  loroApp.swift
//  loro
//
//  Created by Ruban on 2026-01-30.
//

import SwiftUI

@main
struct loroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
