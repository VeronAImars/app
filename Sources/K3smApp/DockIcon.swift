/*
Copyright The k3sm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import AppKit
import SwiftUI

/// DockIcon is the running app's Dock image: a tile of its own (the night
/// concept's navy, standing in until an icon is chosen) that stays still,
/// with the mark on it flapping at `angle`. The Dock shows a runtime image
/// as drawn, so the tile is part of the drawing rather than the system's.
struct DockIcon: View {
    let angle: Double

    var body: some View {
        GeometryReader { g in
            let side = g.size.width
            let tile = side * 824 / 1024
            ZStack {
                RoundedRectangle(cornerRadius: tile * 185 / 824, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.067, green: 0.102, blue: 0.361), Color(red: 0.027, green: 0.051, blue: 0.239)], startPoint: .top, endPoint: .bottom))
                    .overlay(RadialGradient(colors: [Color(red: 0.239, green: 0.357, blue: 1).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: tile * 0.46).clipShape(RoundedRectangle(cornerRadius: tile * 185 / 824, style: .continuous)))
                    .frame(width: tile, height: tile)
                    .shadow(color: .black.opacity(0.35), radius: side * 0.027, y: side * 0.014)
                FlappingButterfly(angle: angle, color: Color(red: 0.561, green: 0.643, blue: 1))
                    .shadow(color: Color(red: 0.435, green: 0.533, blue: 0.996).opacity(0.9), radius: side * 0.035)
                    .frame(width: side * 0.62, height: side * 0.62)
            }
            .frame(width: side, height: side)
        }
    }

    /// image renders the icon at `angle` for the Dock, 512 pixels square.
    @MainActor static func image(angle: Double) -> NSImage? {
        let renderer = ImageRenderer(content: DockIcon(angle: angle).frame(width: 256, height: 256))
        renderer.scale = 2
        return renderer.nsImage
    }
}
