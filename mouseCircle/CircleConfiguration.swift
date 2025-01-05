//
//  CircleConfiguration.swift
//  mouseCircle
//
//  Created by Charlie Culbert on 1/6/25.
//


import AppKit

struct CircleConfiguration {
    var size: CGFloat = 100
    var intensity: CGFloat = 0.5
    var thickness: CGFloat = 4
    var type: AnimationType = .singleRipple
    var color: NSColor = .green
    var opacity: CGFloat = 0.6
    

    enum AnimationType: String, CaseIterable {
        case singleRipple = "Single Ripple"
        case pulseOnClick = "Pulse On Click"
    }
}
