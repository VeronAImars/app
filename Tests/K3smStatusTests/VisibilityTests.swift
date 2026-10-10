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

@Suite("visibility rule")
struct VisibilityTests {
    struct ClassifyCase: Sendable, CustomTestStringConvertible {
        let file: String
        let exitCode: Int32
        let want: Reading
        var testDescription: String { "\(file) exit \(exitCode)" }
    }

    static let classifyCases: [ClassifyCase] = [
        ClassifyCase(file: "status_daemons_json_running.json", exitCode: 0, want: .running),
        ClassifyCase(file: "status_json_running.json", exitCode: 0, want: .running),
        ClassifyCase(file: "status_daemons_json_degraded.json", exitCode: 4, want: .notRunning),
        ClassifyCase(file: "status_daemons_json_stopped-clean.json", exitCode: 3, want: .notRunning),
        ClassifyCase(file: "status_json_stopped-clean.json", exitCode: 3, want: .notRunning),
        ClassifyCase(file: "status_daemons_json_not-installed.json", exitCode: 5, want: .notRunning),
        ClassifyCase(file: "status_daemons_json_unknown.json", exitCode: 6, want: .notRunning),
        ClassifyCase(file: "status_daemons_json_agent-waiting.json", exitCode: 4, want: .notRunning),
        ClassifyCase(file: "cli-error.txt", exitCode: 2, want: .cliError),
        ClassifyCase(file: "cli-error.txt", exitCode: 0, want: .cliError),
        ClassifyCase(file: "status_daemons_json_running.json", exitCode: 1, want: .cliError),
        ClassifyCase(file: "schema-v2.json", exitCode: 0, want: .cliError),
    ]

    @Test("classify one CLI run", arguments: classifyCases)
    func classify(_ c: ClassifyCase) throws {
        #expect(Reading.classify(exitCode: c.exitCode, stdout: try fixture(c.file)) == c.want)
    }

    struct SequenceCase: Sendable, CustomTestStringConvertible {
        let name: String
        let readings: [Reading]
        let visible: [Bool]
        var testDescription: String { name }
    }

    static let r = Reading.running
    static let n = Reading.notRunning
    static let m = Reading.binaryMissing
    static let e = Reading.cliError

    static let sequences: [SequenceCase] = [
        SequenceCase(name: "show after one running read", readings: [r], visible: [true]),
        SequenceCase(name: "starts hidden while not running", readings: [n, n, n], visible: [false, false, false]),
        SequenceCase(name: "hide after two not-running reads", readings: [r, n, n], visible: [true, true, false]),
        SequenceCase(name: "a single missed poll does not flicker", readings: [r, n, r, n, r], visible: [true, true, true, true, true]),
        SequenceCase(name: "a restart blip keeps the item", readings: [r, e, r], visible: [true, true, true]),
        SequenceCase(name: "stays hidden while the binary is missing", readings: [m, m, m, m], visible: [false, false, false, false]),
        SequenceCase(name: "uninstall hides after two reads", readings: [r, m, m], visible: [true, true, false]),
        SequenceCase(name: "CLI errors hide after two reads", readings: [r, e, e], visible: [true, true, false]),
        SequenceCase(name: "mixed misses count together", readings: [r, n, e], visible: [true, true, false]),
        SequenceCase(name: "comes back after one running read", readings: [r, n, n, r], visible: [true, true, false, true]),
        SequenceCase(name: "long hidden stretch reshows at once", readings: [n, n, n, n, n, n, r], visible: [false, false, false, false, false, false, true]),
    ]

    @Test("visibility across polls", arguments: sequences)
    func sequence(_ c: SequenceCase) {
        var t = VisibilityTracker()
        var got: [Bool] = []
        for reading in c.readings {
            t.observe(reading)
            got.append(t.visible)
        }
        #expect(got == c.visible)
    }

    @Test("visibility changes are reported only on transitions")
    func transitions() {
        var t = VisibilityTracker()
        #expect(t.observe(Self.r).visibilityChanged)
        #expect(!t.observe(Self.r).visibilityChanged)
        #expect(!t.observe(Self.n).visibilityChanged)
        #expect(t.observe(Self.n).visibilityChanged)
        #expect(!t.observe(Self.n).visibilityChanged)
    }

    @Test("an unreadable CLI is logged once until a good read")
    func logOnce() {
        var t = VisibilityTracker()
        #expect(t.observe(Self.m).logUnavailable)
        #expect(!t.observe(Self.m).logUnavailable)
        #expect(!t.observe(Self.e).logUnavailable)
        #expect(!t.observe(Self.n).logUnavailable)
        #expect(t.observe(Self.e).logUnavailable)
        #expect(!t.observe(Self.r).logUnavailable)
        #expect(t.observe(Self.m).logUnavailable)
    }
}
