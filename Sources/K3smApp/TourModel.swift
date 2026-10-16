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

import AppKit
import K3smStatus
import SwiftUI

/// TourModel is the guided tour's state, kept here rather than in views
/// (no view in this app holds state). It runs the stops `Tour.steps` gives,
/// applies the layout every stop can be seen in and puts the user's back
/// when the tour ends, and measures the stops in window coordinates: the
/// console's panel and content are hosted separately, so a SwiftUI
/// preference cannot carry their bounds to one overlay.
@MainActor
final class TourModel: ObservableObject {
    /// The stop the guide is at or flying to, nil when the tour is not running.
    @Published private(set) var step: Int?
    /// The stop whose box and card are shown: the same as `step` once the
    /// guide has landed there, nil while it flies, so the guide leads.
    @Published private(set) var lit: Int?
    /// Counts moves, so a reveal still pending from an earlier stop is dropped.
    private var move = 0
    /// The stops, built when the tour starts from this Mac's place in its
    /// cluster, so the first one says what the panel's heading says.
    @Published private(set) var steps = Tour.steps(for: .unknown)
    /// The stops' frames in window coordinates (origin bottom left), measured
    /// when a stop is shown and when the window changes size.
    @Published private(set) var frames: [TourTarget: CGRect] = [:]
    /// Where the wordmark's mark sits, in window coordinates: the guide
    /// lifts off from here and flies back here.
    @Published private(set) var home: CGRect?
    /// The overlay's own frame in window coordinates, so it can place the
    /// stops and the guide in its space.
    @Published private(set) var overlay: CGRect?
    /// Whether the mark has left the wordmark to guide the tour.
    @Published private(set) var markAway = false
    /// Asked to scroll the panel to a stop inside it; the panel clears it.
    @Published var scrollTarget: TourTarget?

    /// The views that report each stop, and the wordmark's mark.
    private var targets: [TourTarget: WeakView] = [:]
    private var homeView = WeakView()
    private var overlayView = WeakView()
    private var keys: Any?
    private var saved: Tour.Layout?
    private let layout: TourLayoutAccess

    init(layout: TourLayoutAccess) {
        self.layout = layout
    }

    var current: TourStep? { step.map { steps[$0] } }
    var litStop: TourStep? { lit.map { steps[$0] } }

    /// start shows the first stop. The user's layout is saved and the one
    /// every stop can be seen in is applied; ending the tour restores it.
    func start() {
        if step == nil {
            steps = Tour.steps(for: layout.shape())
            saved = layout.read()
            layout.apply(Tour.shown)
            keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let code = event.keyCode
                let modified = !event.modifierFlags.intersection([.command, .option, .control]).isEmpty
                let consumed = MainActor.assumeIsolated { self?.handle(code: code, modified: modified) ?? false }
                return consumed ? nil : event
            }
        }
        go(to: 0)
    }

    func next() { move(.next) }
    func back() { move(.back) }
    func end() { move(.end) }

    private func move(_ key: Tour.Key) {
        guard let i = step else { return }
        if let to = Tour.step(after: key, from: i) {
            go(to: to)
        } else {
            finish()
        }
    }

    private func go(to i: Int) {
        let target = steps[i].target
        if target.inPanel { scrollTarget = target }
        move += 1
        let this = move
        // The box and card go dark while the guide flies to the next stop,
        // and light when it lands there.
        lit = nil
        markAway = true
        step = i
        // Measure after the layout change and any scroll have been drawn.
        DispatchQueue.main.async { [weak self] in self?.measure() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.measure() }
        let delay = Tour.reveal(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.move == this, self.step == i else { return }
            self.measure()
            self.lit = i
        }
    }

    private func finish() {
        move += 1
        lit = nil
        step = nil
        if let keys { NSEvent.removeMonitor(keys) }
        keys = nil
        if let saved { layout.apply(saved) }
        saved = nil
        measure()
        // The mark flies home before it becomes the wordmark's glyph again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.step == nil else { return }
            self.markAway = false
        }
    }

    /// handle steps the tour for a key and says whether it used the key.
    private func handle(code: UInt16, modified: Bool) -> Bool {
        guard step != nil, let key = Tour.key(code: code, commandOptionOrControl: modified) else { return false }
        move(key)
        return true
    }

    /// measure reads every registered stop's frame in window coordinates.
    func measure() {
        var now: [TourTarget: CGRect] = [:]
        for (target, ref) in targets {
            if let view = ref.view, view.window != nil, !view.isHiddenOrHasHiddenAncestor {
                now[target] = view.convert(view.bounds, to: nil)
            }
        }
        if now != frames { frames = now }
        let h = homeView.view.flatMap { $0.window == nil ? nil : $0.convert($0.bounds, to: nil) }
        if h != home { home = h }
        let o = overlayView.view.flatMap { $0.window == nil ? nil : $0.convert($0.bounds, to: nil) }
        if o != overlay { overlay = o }
    }

    func register(_ view: NSView, for target: TourTarget) { targets[target] = WeakView(view) }
    func registerHome(_ view: NSView) { homeView = WeakView(view) }
    func registerOverlay(_ view: NSView) { overlayView = WeakView(view) }
}

/// TourLayoutAccess reads and applies the console layout the tour depends
/// on; AppModel provides it.
struct TourLayoutAccess {
    let read: @MainActor () -> Tour.Layout
    let apply: @MainActor (Tour.Layout) -> Void
    /// This Mac's place in its cluster, from the latest status report.
    let shape: @MainActor () -> ClusterShape
}

/// WeakView holds a reporting view without keeping it alive.
struct WeakView {
    weak var view: NSView?
    init(_ view: NSView? = nil) { self.view = view }
}

/// TourReporter is an empty AppKit view placed behind a stop; it registers
/// itself with the tour so the tour can read the stop's frame in the window.
struct TourReporter: NSViewRepresentable {
    enum Role { case stop(TourTarget), home, overlay }
    let tour: TourModel
    let role: Role

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        switch role {
        case .stop(let target): tour.register(view, for: target)
        case .home: tour.registerHome(view)
        case .overlay: tour.registerOverlay(view)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

extension View {
    /// Marks this view as the stop for `target`.
    func tourTarget(_ target: TourTarget, _ tour: TourModel) -> some View {
        background(TourReporter(tour: tour, role: .stop(target)))
    }

    /// Marks this view as the guide's home, the wordmark's mark.
    func tourHome(_ tour: TourModel) -> some View {
        background(TourReporter(tour: tour, role: .home))
    }
}
