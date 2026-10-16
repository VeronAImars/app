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

/// OwnerRef is a Kubernetes object by kind and name: a pod's owner, or the
/// controller above it. Both parts are validated, since they come from the
/// cluster: the kind is a Kubernetes kind name and the name a resource name.
public struct OwnerRef: Equatable, Sendable {
    public let kind: String
    public let name: ResourceName

    public init?(kind: String, name: String) {
        guard OwnerRef.validKind(kind), let name = ResourceName(name) else { return nil }
        self.kind = kind
        self.name = name
    }

    /// "Kind name", as the inspector shows it.
    public var text: String { "\(kind) \(name.value)" }

    /// A kind is an upper-case letter then letters and digits, at most 63
    /// characters, as Kubernetes kind names are.
    static func validKind(_ kind: String) -> Bool {
        guard let first = kind.unicodeScalars.first, kind.unicodeScalars.count <= 63,
              ("A"..."Z").contains(first) else { return false }
        return kind.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0) }
    }
}

extension Pod {
    /// The owner as kind and name, read from `owner` ("Kind name"; a kind
    /// has no spaces), or nil for a bare pod or an owner that does not
    /// validate.
    public var ownerRef: OwnerRef? {
        guard let owner, let space = owner.firstIndex(of: " ") else { return nil }
        return OwnerRef(kind: String(owner[..<space]), name: String(owner[owner.index(after: space)...]))
    }
}

/// Controller finds the object that runs a pod, the one a user would scale.
/// A Deployment's pods are owned by a ReplicaSet, and the Deployment owns
/// that ReplicaSet: scaling the ReplicaSet would be undone by the
/// Deployment, so a ReplicaSet owner is followed one step up.
public enum Controller {
    /// Whether the pod's owner needs one more read to find its controller.
    public static func needsLookup(_ owner: OwnerRef?) -> Bool {
        owner?.kind == "ReplicaSet"
    }

    /// The ReplicaSet's own controller from `kubectl get replicaset -o json`:
    /// the owner reference marked as the controller, else the first; nil
    /// when the ReplicaSet has no owner. Anything but a ReplicaSet is refused.
    public static func decodeReplicaSetOwner(_ data: Data) throws -> OwnerRef? {
        let wire = try JSONDecoder().decode(ReplicaSetWire.self, from: data)
        guard wire.kind == "ReplicaSet" else { throw ControllerDecodeError.notAReplicaSet(StatusDisplay.clip(wire.kind ?? "")) }
        let refs = wire.metadata.ownerReferences ?? []
        guard let ref = refs.first(where: { $0.controller == true }) ?? refs.first else { return nil }
        return OwnerRef(kind: ref.kind, name: ref.name)
    }

    /// controller is what runs the pod: the ReplicaSet's controller when the
    /// pod's owner is a ReplicaSet that has one, else the pod's owner.
    public static func controller(of owner: OwnerRef?, replicaSetOwner: OwnerRef?) -> OwnerRef? {
        if needsLookup(owner), let replicaSetOwner { return replicaSetOwner }
        return owner
    }

    struct ReplicaSetWire: Decodable {
        struct Metadata: Decodable {
            struct Owner: Decodable { let kind: String; let name: String; let controller: Bool? }
            let ownerReferences: [Owner]?
        }
        let kind: String?
        let metadata: Metadata
    }
}

public enum ControllerDecodeError: Error, Equatable {
    case notAReplicaSet(String)
}
