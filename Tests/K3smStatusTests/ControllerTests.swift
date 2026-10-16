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

@Suite("a pod's controller")
struct ControllerTests {
    /// A running pod with `owner`, as the decoder writes it ("Kind name").
    static func pod(owner: String?) -> Pod {
        Pod(name: "p", namespace: "default", uid: "default-p", image: "registry.local/app:1", kind: .nativeProcess,
            phase: "Running", health: .running, ready: true, restarts: 0, ports: [], owner: owner, created: nil,
            cpuRequest: nil, memoryRequest: nil, nodeName: nil)
    }

    @Test("an owner splits into a validated kind and name", arguments: [
        ("ReplicaSet hello-http-6bcddf6f77", OwnerRef(kind: "ReplicaSet", name: "hello-http-6bcddf6f77")),
        ("StatefulSet postgres", OwnerRef(kind: "StatefulSet", name: "postgres")),
        ("Job nightly-backup", OwnerRef(kind: "Job", name: "nightly-backup")),
        ("replicaSet lower-case-kind", nil),
        ("ReplicaSet ../etc", nil),
        ("ReplicaSet -leading-dash", nil),
        ("Replica\u{202E}Set x", nil),
        ("NoSpace", nil),
    ] as [(String, OwnerRef?)])
    func split(owner: String, want: OwnerRef?) {
        #expect(Self.pod(owner: owner).ownerRef == want)
    }

    @Test("pods from a real list keep their owners")
    func fromPodList() throws {
        let pods = try Workloads.decode(try fixture("kubectl_pods_running.json")).pods
        let owners = Set(pods.compactMap { $0.ownerRef?.text })
        #expect(owners.contains("ReplicaSet hello-http-6bcddf6f77"))
        #expect(pods.contains { $0.owner == nil && $0.ownerRef == nil })
    }

    @Test("a Deployment's ReplicaSet names the Deployment")
    func replicaSetWithDeployment() throws {
        let owner = try Controller.decodeReplicaSetOwner(try fixture("kubectl_replicaset_deployment.json"))
        #expect(owner == OwnerRef(kind: "Deployment", name: "hello-http"))
    }

    @Test("a ReplicaSet with no owner has no controller above it")
    func bareReplicaSet() throws {
        #expect(try Controller.decodeReplicaSetOwner(try fixture("kubectl_replicaset_bare.json")) == nil)
    }

    @Test("anything but a ReplicaSet is refused")
    func notAReplicaSet() throws {
        #expect(throws: ControllerDecodeError.notAReplicaSet("Pod")) {
            try Controller.decodeReplicaSetOwner(try fixture("kubectl_pod_single.json"))
        }
    }

    @Test("the reference marked as the controller wins, and a hostile one is dropped")
    func controllerFlag() throws {
        let marked = #"{"kind":"ReplicaSet","metadata":{"ownerReferences":[{"kind":"Other","name":"first","controller":false},{"kind":"Deployment","name":"web","controller":true}]}}"#
        #expect(try Controller.decodeReplicaSetOwner(Data(marked.utf8)) == OwnerRef(kind: "Deployment", name: "web"))
        let hostile = #"{"kind":"ReplicaSet","metadata":{"ownerReferences":[{"kind":"Deployment","name":"--all","controller":true}]}}"#
        #expect(try Controller.decodeReplicaSetOwner(Data(hostile.utf8)) == nil)
    }

    @Test("the controller is the ReplicaSet's owner when there is one, else the pod's owner")
    func resolve() {
        let rs = OwnerRef(kind: "ReplicaSet", name: "web-5d8f")
        let deploy = OwnerRef(kind: "Deployment", name: "web")
        let sts = OwnerRef(kind: "StatefulSet", name: "db")
        #expect(Controller.needsLookup(rs))
        #expect(!Controller.needsLookup(sts))
        #expect(!Controller.needsLookup(nil))
        #expect(Controller.controller(of: rs, replicaSetOwner: deploy) == deploy)
        #expect(Controller.controller(of: rs, replicaSetOwner: nil) == rs)
        #expect(Controller.controller(of: sts, replicaSetOwner: deploy) == sts)
        #expect(Controller.controller(of: nil, replicaSetOwner: nil) == nil)
    }

    @Test("the ReplicaSet read is a fixed argument list")
    func arguments() {
        let ns = ResourceName("default")!, name = ResourceName("hello-http-6bcddf6f77")!
        #expect(K3smCLI.replicaSetArguments(namespace: ns, name: name)
            == ["kubectl", "get", "replicaset", "hello-http-6bcddf6f77", "-n", "default", "-o", "json"])
    }
}
