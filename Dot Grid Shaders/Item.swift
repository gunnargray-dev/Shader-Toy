//
//  Item.swift
//  Dot Grid Shaders
//
//  Created by Gunnar Gray on 1/15/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
