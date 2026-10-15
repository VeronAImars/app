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

import Darwin
import Foundation
import IOKit
import K3smStatus

/// HostFacts is the machine the console's panel describes: name, chip, cores
/// and memory. Read once; none of it changes while the app runs. Nothing here
/// touches the cluster.
struct HostFacts: Sendable {
    let modelName: String
    let chip: String
    let cores: Int
    let performanceCores: Int
    let memoryBytes: Int64

    static let dataRoot = "/var/lib/k3sm"

    /// "MacBook Pro (14-inch, Nov 2024), Apple M4 Max, 64 GB"; a part the
    /// system did not give is left out.
    var line: String {
        [modelName, chip, WorkloadsDisplay.bytes(memoryBytes)].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    static func read() -> HostFacts {
        HostFacts(
            modelName: modelName(),
            chip: Sysctl.string("machdep.cpu.brand_string"),
            cores: Int(Sysctl.int("hw.ncpu")),
            performanceCores: Int(Sysctl.int("hw.perflevel0.logicalcpu")),
            memoryBytes: Sysctl.int("hw.memsize")
        )
    }

    /// The marketing name ("MacBook Pro"): the device tree's product name on
    /// Apple silicon, else the model identifier's family, else the identifier.
    private static func modelName() -> String {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        if entry != 0 {
            defer { IOObjectRelease(entry) }
            if let data = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data,
               let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0")), !name.isEmpty {
                return name
            }
        }
        let id = Sysctl.string("hw.model")
        let families = ["MacBookPro": "MacBook Pro", "MacBookAir": "MacBook Air", "Macmini": "Mac mini", "MacStudio": "Mac Studio", "MacPro": "Mac Pro", "iMac": "iMac"]
        return families.first { id.hasPrefix($0.key) }?.value ?? id
    }
}

/// HostLoad is what moves: memory in use and the data root's volume. Read on
/// every poll.
struct HostLoad: Sendable {
    let memoryUsedBytes: Int64
    let dataRootUsedBytes: Int64
    let dataRootSizeBytes: Int64

    static func read() -> HostLoad {
        let (used, size) = volume(at: HostFacts.dataRoot)
        return HostLoad(memoryUsedBytes: memoryInUse(), dataRootUsedBytes: used, dataRootSizeBytes: size)
    }

    /// Active, wired and compressed pages, the sum Activity Monitor calls
    /// memory used.
    private static func memoryInUse() -> Int64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = Int64(getpagesize())
        return (Int64(stats.active_count) + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * page
    }

    /// The volume holding the path, or the root volume before the data root exists.
    private static func volume(at path: String) -> (used: Int64, size: Int64) {
        let probe = FileManager.default.fileExists(atPath: path) ? path : "/"
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: probe),
              let size = attrs[.systemSize] as? Int64, let free = attrs[.systemFreeSize] as? Int64 else { return (0, 0) }
        return (size - free, size)
    }
}

/// Sysctl reads one kernel value by name; a name the kernel lacks reads as empty or zero.
enum Sysctl {
    static func string(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    static func int(_ name: String) -> Int64 {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return 0 }
        return value
    }
}
