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

/// TourOverlay dims the console, lights the current stop and shows the
/// caption card beside it. The guide is the wordmark's mark: it lifts off
/// its spot, flies to each stop on a steady wing beat, and flies home when
/// the tour ends. It holds no state: the step and the measured frames are
/// TourModel's, and the pulse and the beat are read from the clock while
/// the tour runs.
struct TourOverlay: View {
    @ObservedObject var tour: TourModel

    private static let dim = Palette.night.opacity(0.72)
    private static let card = CGSize(width: 330, height: 180)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let i = tour.step, let current = tour.current, let stop = rect(for: current.target) {
                    let rect = Tour.highlight(stop, in: geo.size)
                    let origin = Tour.card(Self.card, by: rect, in: geo.size)
                    Self.dim
                        .mask {
                            ZStack {
                                Rectangle()
                                RoundedRectangle(cornerRadius: 12).frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { tour.end() }
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.glow, lineWidth: 2)
                        .shadow(color: Palette.glow.opacity(0.7), radius: 12)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                    TimelineView(.animation) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1
                        // The pulse grows from the box toward its padded ring, but
                        // never past the window's edge.
                        let ring = Tour.highlight(rect, in: geo.size, pad: 10 * phase, margin: 1)
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Palette.glow.opacity(0.35), lineWidth: 1)
                            .frame(width: ring.width, height: ring.height)
                            .position(x: ring.midX, y: ring.midY)
                            .opacity(0.9 * (1 - phase))
                    }
                    .allowsHitTesting(false)
                    TourCard(step: i, total: Tour.steps.count, current: current, back: tour.back, next: tour.next)
                        .frame(width: Self.card.width)
                        .offset(x: origin.x, y: origin.y)
                        .transition(.opacity)
                }
                if tour.markAway, let home = local(tour.home) {
                    let at = tour.current.flatMap { rect(for: $0.target) }.map { Tour.landing(by: Tour.highlight($0, in: geo.size), in: geo.size) }
                        ?? CGPoint(x: home.midX, y: home.midY)
                    TimelineView(.animation) { context in
                        FlappingButterfly(angle: Tour.guideAngle(at: context.date.timeIntervalSinceReferenceDate), color: .white)
                    }
                    .frame(width: 30, height: 30)
                    .shadow(color: Palette.glow.opacity(0.9), radius: 6)
                    .shadow(color: Palette.glow.opacity(0.6), radius: 16)
                    .position(at)
                    .animation(.easeInOut(duration: 0.9), value: at)
                    .allowsHitTesting(false)
                }
            }
            .animation(.spring(duration: 0.55, bounce: 0.15), value: tour.step)
            .background(TourReporter(tour: tour, role: .overlay))
            .onChange(of: geo.size) { tour.measure() }
        }
        .allowsHitTesting(tour.step != nil)
    }

    /// The stop's frame in the overlay; `Tour.highlight` pads and clamps it.
    private func rect(for target: TourTarget) -> CGRect? {
        local(tour.frames[target])
    }

    private func local(_ window: CGRect?) -> CGRect? {
        guard let window, let overlay = tour.overlay else { return nil }
        return Tour.local(window, in: overlay)
    }
}

/// TourCard is the caption: eyebrow, title, text, the step dots, Back and Next.
struct TourCard: View {
    let step: Int
    let total: Int
    let current: TourStep
    let back: () -> Void
    let next: () -> Void

    private static let stars: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 0.18, 1), (0.78, 0.12, 1), (0.62, 0.42, 1.5), (0.30, 0.70, 1), (0.88, 0.66, 1), (0.44, 0.88, 1.5), (0.08, 0.92, 1), (0.94, 0.30, 1)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("K3SM · TOUR")
                Spacer()
                Text(verbatim: String(format: "%02d / %02d", step + 1, total))
            }
            .font(.system(size: 11, design: .monospaced)).tracking(1.5)
            .foregroundStyle(Palette.glowSoft)
            Text(verbatim: current.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text(verbatim: current.text).font(.system(size: 13)).lineSpacing(3).foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(0..<total, id: \.self) { d in
                        Circle().fill(d == step ? Palette.glow : Color.white.opacity(0.22))
                            .frame(width: 6, height: 6)
                            .shadow(color: d == step ? Palette.glow : .clear, radius: 4)
                    }
                }
                Spacer()
                if step > 0 {
                    Button("Back", action: back).buttonStyle(TourButtonStyle(primary: false))
                }
                Button(step == total - 1 ? "Done" : "Next", action: next).buttonStyle(TourButtonStyle(primary: true))
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
        .background {
            ZStack {
                LinearGradient(colors: [Palette.deep2, Palette.deep, Palette.night], startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { g in
                    ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, s in
                        Circle().fill(.white).frame(width: s.2, height: s.2).position(x: g.size.width * s.0, y: g.size.height * s.1)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.glow.opacity(0.45)))
        .shadow(color: .black.opacity(0.6), radius: 30, y: 18)
        .shadow(color: Palette.fill.opacity(0.25), radius: 20)
    }
}

struct TourButtonStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).frame(height: 28)
            .background(primary ? Palette.blue : Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(primary ? Color.clear : Color.white.opacity(0.22)))
            .shadow(color: primary ? Palette.blue.opacity(0.6) : .clear, radius: 9)
    }
}
