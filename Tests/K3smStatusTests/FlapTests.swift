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

import Foundation
import Testing

@testable import K3smStatus

@Suite("flap")
struct FlapTests {
    @Test("a beat starts and ends with the wings flat")
    func flatAtBothEnds() {
        let frames = Flap.frames()
        #expect(frames.first == 0)
        #expect(frames.last == 0)
        #expect(Flap.angle(at: -1) == 0)
        #expect(Flap.angle(at: Flap.duration + 1) == 0)
    }

    @Test("the first stroke is the highest and the second is lower")
    func strokeHeights() {
        let first = Flap.angle(at: Flap.duration / 4)
        let second = Flap.angle(at: Flap.duration * 3 / 4)
        #expect(abs(first - Flap.peak) < 1e-9)
        #expect(abs(second - Flap.peak * Flap.secondDepth) < 1e-9)
    }

    @Test("every frame stays between flat and the peak")
    func framesInRange() {
        let frames = Flap.frames()
        #expect(frames.count == Int((Flap.duration * Flap.frameRate).rounded()) + 1)
        for a in frames {
            #expect(a >= 0 && a <= Flap.peak + 1e-9)
        }
    }

    @Test("the rest stays between its bounds", arguments: [-1.0, 0, 0.5, 1, 2])
    func restBounds(unit: Double) {
        let r = Flap.rest(unit: unit)
        #expect(r >= Flap.restMin && r <= Flap.restMax)
    }
}
