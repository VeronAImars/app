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

@Suite("output cap")
struct OutputLimitTests {
    @Test("a stream under the limit is kept whole")
    func underLimit() {
        var out = CappedOutput(limit: 10)
        let r1 = out.append(Data("abc".utf8))
        #expect(r1)
        let r2 = out.append(Data("defg".utf8))
        #expect(r2)
        #expect(out.data == Data("abcdefg".utf8))
        #expect(!out.overflowed)
    }

    @Test("a stream that ends exactly at the limit has not overflowed")
    func exactLimit() {
        var out = CappedOutput(limit: 4)
        let r3 = out.append(Data("abcd".utf8))
        #expect(r3)
        #expect(!out.overflowed)
        let r4 = out.append(Data("e".utf8))
        #expect(!r4)
        #expect(out.overflowed)
        #expect(out.data == Data("abcd".utf8))
    }

    @Test("the chunk that crosses the limit is cut and later chunks are dropped")
    func crossing() {
        var out = CappedOutput(limit: 5)
        let r5 = out.append(Data("abc".utf8))
        #expect(r5)
        let r6 = out.append(Data("defgh".utf8))
        #expect(!r6)
        let r7 = out.append(Data("ijk".utf8))
        #expect(!r7)
        #expect(out.data == Data("abcde".utf8))
        #expect(out.overflowed)
    }

    @Test("a zero or negative limit keeps nothing")
    func zeroLimit() {
        var out = CappedOutput(limit: -3)
        #expect(out.limit == 0)
        let r8 = out.append(Data())
        #expect(r8)
        let r9 = out.append(Data("a".utf8))
        #expect(!r9)
        #expect(out.data.isEmpty)
    }

    @Test("the limits are ordered and the detail limit is what the inspector shows")
    func limits() {
        #expect(OutputLimit.detail == 64 * 1024)
        #expect(OutputLimit.detail < OutputLimit.status)
        #expect(OutputLimit.status < OutputLimit.list)
    }
}
