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

/// NodeRole is which node daemon this Mac runs. It is a closed set: any other
/// role word means the app cannot tell which daemon to watch.
public enum NodeRole: String, Equatable, Sendable, CaseIterable {
    case server
    case agent

    /// The launchd label of this role's node daemon.
    public var daemonLabel: String {
        switch self {
        case .server: return "io.k3sm.server"
        case .agent: return "io.k3sm.agent"
        }
    }

    /// Detects the role from a report: the top-level `role` first, then the
    /// presence of a `server` row, then an `agent` row.
    public static func detect(in report: StatusReport) -> NodeRole? {
        if let role = NodeRole(rawValue: report.role) {
            return role
        }
        if report.row(named: NodeRole.server.rawValue) != nil {
            return .server
        }
        if report.row(named: NodeRole.agent.rawValue) != nil {
            return .agent
        }
        return nil
    }
}

extension StatusReport {
    /// Reports whether this Mac's node daemon reads `running`: the row named
    /// by the detected role must carry the state `running`.
    public var nodeDaemonRunning: Bool {
        guard let role = NodeRole.detect(in: self), let row = row(named: role.rawValue) else {
            return false
        }
        return row.state == "running"
    }
}
