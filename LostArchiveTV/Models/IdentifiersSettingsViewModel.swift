//
//  IdentifiersSettingsViewModel.swift
//  LostArchiveTV
//
//  Created by Claude on 5/9/25.
//

import Foundation
import SwiftUI
import OSLog

@MainActor
class IdentifiersSettingsViewModel: ObservableObject {
    @Published var identifiers: [UserSelectedIdentifier] = []
    @Published var searchText: String = ""
    
    private let logger = Logger(subsystem: "com.saygoodnight.LostArchiveTV", category: "IdentifiersSettings")
    private let manager = UserSelectedIdentifiersManager.shared
    
    var filteredIdentifiers: [UserSelectedIdentifier] {
        if searchText.isEmpty {
            return identifiers
        } else {
            return identifiers.filter { 
                $0.title.lowercased().contains(searchText.lowercased()) ||
                $0.identifier.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    init() {
        loadIdentifiers()
    }
    
    func loadIdentifiers() {
        self.identifiers = manager.identifiers
    }
    
    func removeIdentifier(_ id: String) {
        manager.removeIdentifier(withId: id)
        loadIdentifiers()
    }
}