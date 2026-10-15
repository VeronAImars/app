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

import SwiftUI

/// Palette is the console's colours: the tokens of the design it follows,
/// named for their role so a view never spells a colour itself.
enum Palette {
    static let deep = Color(red: 0.027, green: 0.051, blue: 0.239)      // #070d3d, the Mac panel
    static let deep2 = Color(red: 0.067, green: 0.102, blue: 0.361)     // #111a5c, meters' tracks
    static let blue = Color(red: 0.008, green: 0.184, blue: 0.984)      // #022ffb, the accent
    static let navy = Color(red: 0.004, green: 0.075, blue: 0.537)      // #011389, icons and native marks
    static let tint = Color(red: 0.918, green: 0.929, blue: 1.0)        // #eaedff, the selected row
    static let wash = Color(red: 0.965, green: 0.969, blue: 0.984)      // #f6f7fb, text wells
    static let paper = Color(red: 0.988, green: 0.988, blue: 0.996)     // #fcfcfe, the inspector
    static let line = Color(red: 0.890, green: 0.898, blue: 0.933)      // #e3e5ee, rules
    static let ink2 = Color(red: 0.337, green: 0.361, blue: 0.451)      // #565c73, secondary text
    static let ink3 = Color(red: 0.541, green: 0.561, blue: 0.639)      // #8a8fa3, labels
    static let vm = Color(red: 0.780, green: 0.467, blue: 0.0)          // #c77700, the Linux VM mark
    static let fill = Color(red: 0.373, green: 0.482, blue: 1.0)        // #5f7bff, meters on the panel
    static let fillSoft = Color(red: 0.725, green: 0.773, blue: 1.0)    // #b9c5ff, efficiency cores
    static let fillDim = Color(red: 0.227, green: 0.263, blue: 0.502)   // #3a4380, the rest of memory
    static let okOnDark = Color(red: 0.384, green: 0.902, blue: 0.627)  // #62e6a0, a healthy daemon

    static let ok = Color(red: 0.090, green: 0.569, blue: 0.310)
    static let warn = Color(red: 0.722, green: 0.416, blue: 0.0)
    static let bad = Color(red: 0.788, green: 0.188, blue: 0.173)
    static let unknown = Color(red: 0.616, green: 0.631, blue: 0.702)

    /// The dot for a pod's health severity word; an unknown word is grey.
    static func health(_ severity: String) -> Color {
        switch severity {
        case "ok": return ok
        case "warn": return warn
        case "bad": return bad
        default: return unknown
        }
    }
}
