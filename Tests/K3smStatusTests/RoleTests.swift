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

@Suite("role detection")
struct RoleTests {
    static func report(role: String, rows: [String]) -> StatusReport {
        StatusReport(schemaVersion: 1, verdict: .running, role: role, summary: "",
                     rows: rows.map { StatusRow(name: $0, state: "running", detail: "pid 1") })
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let role: String
        let rows: [String]
        let want: NodeRole?
        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(name: "top-level server", role: "server", rows: ["netd", "server"], want: .server),
        Case(name: "top-level agent", role: "agent", rows: ["netd", "agent"], want: .agent),
        Case(name: "top-level role wins over rows", role: "agent", rows: ["server"], want: .agent),
        Case(name: "no role, server row", role: "", rows: ["netd", "server"], want: .server),
        Case(name: "no role, agent row", role: "", rows: ["netd", "agent"], want: .agent),
        Case(name: "unknown role word, server row", role: "witness", rows: ["server"], want: .server),
        Case(name: "no role, both rows prefers server", role: "", rows: ["agent", "server"], want: .server),
        Case(name: "no role, no node row", role: "", rows: ["netd"], want: nil),
    ]

    @Test("detect", arguments: cases)
    func detect(_ c: Case) {
        #expect(NodeRole.detect(in: Self.report(role: c.role, rows: c.rows)) == c.want)
    }

    @Test("role from a fixture with no top-level role")
    func noRoleFixture() throws {
        let report = try StatusReport.decode(try fixture("no-role.json"))
        #expect(NodeRole.detect(in: report) == .agent)
        #expect(report.nodeDaemonRunning)
    }

    @Test("daemon labels are a closed table")
    func labels() {
        #expect(NodeRole.server.daemonLabel == "io.k3sm.server")
        #expect(NodeRole.agent.daemonLabel == "io.k3sm.agent")
        #expect(NodeRole.allCases.count == 2)
    }
}
