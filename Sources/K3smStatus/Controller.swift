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

/// OwnerRef is a Kubernetes object by API version, kind and name: a pod's
/// controller, or the controller above it. All three are validated, since
/// they come from the cluster and the name may later reach an argument list.
public struct OwnerRef: Equatable, Sendable {
    /// The group and version, "apps/v1" for the built-in controllers.
    public let apiVersion: String
    public let kind: String
    public let name: ResourceName

    public init?(apiVersion: String, kind: String, name: String) {
        guard OwnerRef.validAPIVersion(apiVersion), OwnerRef.validKind(kind), let name = ResourceName(name) else {
            return nil
        }
        self.apiVersion = apiVersion
        self.kind = kind
        self.name = name
    }

    /// "Kind name", as the inspector shows it.
    public var text: String { "\(kind) \(name.value)" }

    /// Whether this is one of the built-in workload controllers' group,
    /// `apps/v1`. A custom resource may reuse a kind such as ReplicaSet or
    /// Deployment in its own group; only the group tells them apart.
    public var isAppsV1: Bool { apiVersion == "apps/v1" }

    /// The app's own rule for a kind it will show or put on an argument
    /// list: an upper-case letter then ASCII letters and digits, at most 63
    /// characters. The API server asks only that a kind be non-empty (a
    /// custom resource's kind may be any case), so this is stricter on
    /// purpose; a kind outside it is shown as no owner.
    static func validKind(_ kind: String) -> Bool {
        guard let first = kind.unicodeScalars.first, kind.unicodeScalars.count <= 63,
              ("A"..."Z").contains(first) else { return false }
        return kind.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0) }
    }

    /// An API version is "version" or "group/version": lower-case letters,
    /// digits, dots and dashes, at most 253 characters, at most one slash.
    static func validAPIVersion(_ apiVersion: String) -> Bool {
        let scalars = apiVersion.unicodeScalars
        guard !scalars.isEmpty, scalars.count <= 253, scalars.filter({ $0 == "/" }).count <= 1,
              apiVersion.first != "/", apiVersion.last != "/" else { return false }
        return scalars.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "-" || $0 == "/" }
    }
}

/// Controller finds the object that runs a pod, the one a user would scale.
/// A Deployment's pods are owned by a ReplicaSet, and the Deployment owns
/// that ReplicaSet: scaling the ReplicaSet would be undone by the
/// Deployment, so a ReplicaSet owner is followed one step up.
public enum Controller {
    /// Whether the pod's owner needs one more read to find its controller:
    /// an `apps/v1` ReplicaSet, not a custom kind of the same name.
    public static func needsLookup(_ owner: OwnerRef?) -> Bool {
        owner?.kind == "ReplicaSet" && owner?.isAppsV1 == true
    }

    /// The ReplicaSet's own controller from `kubectl get replicaset -o json`:
    /// the owner reference marked `controller: true`, as apimachinery's
    /// `GetControllerOf` picks it; nil when no reference is marked. A
    /// reference without the mark is an ownership link for garbage
    /// collection, not the object that scales the ReplicaSet. Anything but a
    /// ReplicaSet is refused.
    public static func decodeReplicaSetOwner(_ data: Data) throws -> OwnerRef? {
        let wire = try JSONDecoder().decode(ReplicaSetWire.self, from: data)
        guard wire.kind == "ReplicaSet" else { throw ControllerDecodeError.notAReplicaSet(StatusDisplay.clip(wire.kind ?? "")) }
        guard let ref = OwnerReferenceWire.controller(in: wire.metadata.ownerReferences) else { return nil }
        return OwnerRef(apiVersion: ref.apiVersion ?? "", kind: ref.kind, name: ref.name)
    }

    /// controller is the `apps/v1` object that runs the pod: the
    /// ReplicaSet's controller when the pod's owner is a ReplicaSet that has
    /// one, else the pod's owner. Nil when there is no owner, or when the
    /// owner or the ReplicaSet's controller is outside `apps/v1`: a custom
    /// kind is never read or acted on as the built-in one.
    public static func controller(of owner: OwnerRef?, replicaSetOwner: OwnerRef?) -> OwnerRef? {
        guard let owner, owner.isAppsV1 else { return nil }
        guard needsLookup(owner), let replicaSetOwner else { return owner }
        return replicaSetOwner.isAppsV1 ? replicaSetOwner : nil
    }

    struct ReplicaSetWire: Decodable {
        struct Metadata: Decodable {
            let ownerReferences: [OwnerReferenceWire]?
        }
        let kind: String?
        let metadata: Metadata
    }
}

/// OwnerReferenceWire is one `metadata.ownerReferences` entry as the API
/// serves it, for pods and ReplicaSets alike.
struct OwnerReferenceWire: Decodable {
    let apiVersion: String?
    let kind: String
    let name: String
    let controller: Bool?

    /// The reference marked `controller: true`, the first if several are, as
    /// apimachinery's `GetControllerOf` returns it; nil when none is marked.
    static func controller(in refs: [OwnerReferenceWire]?) -> OwnerReferenceWire? {
        refs?.first { $0.controller == true }
    }
}

public enum ControllerDecodeError: Error, Equatable {
    case notAReplicaSet(String)
}
