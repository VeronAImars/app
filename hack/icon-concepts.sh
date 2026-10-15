#!/usr/bin/env bash
# Copyright The k3sm Authors.
# SPDX-License-Identifier: Apache-2.0
#
# icon-concepts.sh <outdir>
# icon-concepts.sh --pick <concept> <out.icns>
#
# Renders the candidate app icons for the maintainers to choose from. Each
# concept puts the k3sm butterfly mark (Resources/k3sm-mark.svg) on a tile of
# its own, so macOS 26 draws it as designed instead of placing the bare mark
# inside a grey rounded square. Only the wing colours change; the mark's
# paths are the SVG's, untouched.
#
# The first form writes <outdir>/<concept>.png (512x512) for every concept
# and <outdir>/sheet.png, a contact sheet with each concept at Dock size on a
# light and a dark Dock. docs/icon-concepts/ holds the committed output.
#
# The second form builds an .icns from one concept, the same way
# hack/make-icon.sh builds the current icon, so adopting a concept is
#   hack/icon-concepts.sh --pick <concept> Resources/AppIcon.icns
# and nothing changes until someone runs it. Concepts: night, night-glow,
# electric, porcelain, breakout, aurora.
#
# Only the toolchain and the system are used: swift, sips and iconutil.
set -euo pipefail

usage() {
	echo "usage: hack/icon-concepts.sh <outdir>" >&2
	echo "       hack/icon-concepts.sh --pick <concept> <out.icns>" >&2
	exit 2
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/Resources/k3sm-mark.svg"
[ -f "$SVG" ] || { echo "icon-concepts: no such file: $SVG" >&2; exit 1; }

PICK=
OUT=
case "${1:-}" in
--pick)
	[ "$#" -eq 3 ] || usage
	PICK="$2"
	OUT="$3"
	case "$OUT" in
	*.icns) ;;
	*) usage ;;
	esac
	;;
"") usage ;;
*)
	[ "$#" -eq 1 ] || usage
	OUT="$1"
	;;
esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/render.swift" <<'SWIFT'
import AppKit

// render <svg> <outdir> [concept]: writes <outdir>/<concept>.png at
// 1024x1024 for the named concept, or for every concept plus sheet.png.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("render: \(message)\n".data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 3 || args.count == 4 else { fail("usage: render <svg> <outdir> [concept]") }
guard let source = try? String(contentsOfFile: args[1], encoding: .utf8) else { fail("cannot read \(args[1])") }
let outdir = args[2]

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

/// mark is the SVG with its two wing fills replaced and the dark-mode style
/// removed, so the colours are the concept's in every appearance.
func mark(upper: String, lower: String) -> NSImage {
    var svg = source.replacingOccurrences(of: #"<style>.*</style>"#, with: "", options: .regularExpression)
    svg = svg.replacingOccurrences(of: ##"fill="#022ffb""##, with: "fill=\"\(upper)\"")
    svg = svg.replacingOccurrences(of: ##"fill="#011389""##, with: "fill=\"\(lower)\"")
    guard let image = NSImage(data: Data(svg.utf8)), image.size.width > 0 else { fail("cannot load the mark") }
    return image
}

let side: CGFloat = 1024
// Apple's macOS icon grid: an 824-point tile centred on the 1024 canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let radius: CGFloat = 185
let shape = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

func shadow(_ color: NSColor, blur: CGFloat, dy: CGFloat = 0) -> NSShadow {
    let s = NSShadow()
    s.shadowColor = color
    s.shadowBlurRadius = blur
    s.shadowOffset = NSSize(width: 0, height: dy)
    return s
}

/// drawTile fills the tile with its drop shadow, then runs `body` clipped to it.
func drawTile(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    shadow(rgb(0x000000, 0.35), blur: 28, dy: -14).set()
    rgb(0x000000).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

/// drawMark centres the mark at `scale` of the canvas width.
func drawMark(_ image: NSImage, scale: CGFloat = 0.62, dy: CGFloat = 0, glow: NSShadow? = nil) {
    let w = side * scale
    let h = w * image.size.height / image.size.width
    NSGraphicsContext.saveGraphicsState()
    glow?.set()
    image.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2 + dy, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
}

/// gloss is a soft highlight across the top of the tile and a thin rim.
func gloss() {
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [rgb(0xffffff, 0.22), rgb(0xffffff, 0)])!
        .draw(in: NSRect(x: tile.minX, y: 560, width: tile.width, height: tile.maxY - 560), angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: radius - 2, yRadius: radius - 2)
    rim.lineWidth = 4
    rgb(0xffffff, 0.18).setStroke()
    rim.stroke()
}

struct Concept {
    let name: String
    let title: String
    let draw: () -> Void
}

let navy = [rgb(0x111a5c), rgb(0x070d3d)]
let concepts: [Concept] = [
    Concept(name: "night", title: "Night: the console's navy, lit wings") {
        drawTile {
            NSGradient(colors: navy)!.draw(in: tile, angle: -90)
            NSGradient(colors: [rgb(0x3d5bff, 0.55), rgb(0x3d5bff, 0)])!
                .draw(fromCenter: NSPoint(x: 512, y: 500), radius: 0, toCenter: NSPoint(x: 512, y: 500), radius: 380, options: [])
        }
        drawMark(mark(upper: "#8fa4ff", lower: "#3d5bff"), glow: shadow(rgb(0x6f88fe, 0.9), blur: 40))
        gloss()
    },
    Concept(name: "night-glow", title: "Night glow: one-tone wings, as the Dock flap draws") {
        drawTile {
            NSGradient(colors: navy)!.draw(in: tile, angle: -90)
            NSGradient(colors: [rgb(0x3d5bff, 0.55), rgb(0x3d5bff, 0)])!
                .draw(fromCenter: NSPoint(x: 512, y: 512), radius: 0, toCenter: NSPoint(x: 512, y: 512), radius: 380, options: [])
        }
        drawMark(mark(upper: "#8fa4ff", lower: "#8fa4ff"), glow: shadow(rgb(0x6f88fe, 0.9), blur: 72))
    },
    Concept(name: "electric", title: "Electric: brand blue, white mark") {
        drawTile { NSGradient(colors: [rgb(0x2d48fe), rgb(0x022ffb), rgb(0x011389)])!.draw(in: tile, angle: -60) }
        drawMark(mark(upper: "#ffffff", lower: "#c9d2ff"), glow: shadow(rgb(0x000a50, 0.45), blur: 24))
        gloss()
    },
    Concept(name: "porcelain", title: "Porcelain: white tile, brand mark") {
        drawTile { NSGradient(colors: [rgb(0xffffff), rgb(0xeef1ff)])!.draw(in: tile, angle: -90) }
        drawMark(mark(upper: "#022ffb", lower: "#011389"), glow: shadow(rgb(0x022ffb, 0.35), blur: 30))
        gloss()
    },
    Concept(name: "breakout", title: "Breakout: the mark fills the navy tile") {
        drawTile { NSGradient(colors: navy)!.draw(in: tile, angle: -90) }
        drawMark(mark(upper: "#8fa4ff", lower: "#3d5bff"), scale: 0.86, dy: 30, glow: shadow(rgb(0x6f88fe, 0.8), blur: 30))
    },
    Concept(name: "aurora", title: "Aurora: navy to violet, glowing mark") {
        drawTile { NSGradient(colors: [rgb(0x070d3d), rgb(0x2a1a7a), rgb(0x5b2bd6)])!.draw(in: tile, angle: 70) }
        drawMark(mark(upper: "#ffffff", lower: "#9fb2ff"), glow: shadow(rgb(0xb9c5ff, 0.9), blur: 50))
        gloss()
    },
]

/// bitmap runs `draw` into a new width x height bitmap.
func bitmap(_ width: Int, _ height: Int, _ draw: () -> Void) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { fail("cannot make a bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    draw()
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, _ name: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else { fail("cannot encode \(name)") }
    do { try png.write(to: URL(fileURLWithPath: "\(outdir)/\(name).png")) } catch { fail("\(error)") }
}

let chosen = args.count == 4 ? concepts.filter { $0.name == args[3] } : concepts
if chosen.isEmpty { fail("no concept \(args[3]); concepts: \(concepts.map(\.name).joined(separator: ", "))") }

var rendered: [(Concept, NSImage)] = []
for concept in chosen {
    let rep = bitmap(Int(side), Int(side), concept.draw)
    write(rep, concept.name)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.addRepresentation(rep)
    rendered.append((concept, image))
}
guard args.count == 3 else { exit(0) }

// The sheet: each concept large with its title, then at Dock size (64 pt)
// on a light and a dark Dock.
let cell = (w: 400, h: 520), columns = 3
let rows = (rendered.count + columns - 1) / columns
let sheet = bitmap(cell.w * columns, cell.h * rows) {
    rgb(0xf4f4f7).setFill()
    NSRect(x: 0, y: 0, width: cell.w * columns, height: cell.h * rows).fill()
    for (i, (concept, image)) in rendered.enumerated() {
        let x = CGFloat(i % columns * cell.w)
        let top = CGFloat((rows - i / columns) * cell.h)
        image.draw(in: NSRect(x: x + 50, y: top - 320, width: 300, height: 300))
        (concept.title as NSString).draw(
            in: NSRect(x: x + 20, y: top - 370, width: CGFloat(cell.w) - 40, height: 44),
            withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: rgb(0x0b0c0e)])
        for (j, dock) in [rgb(0xe6e6ea), rgb(0x2a2a2e)].enumerated() {
            let r = NSRect(x: x + 40 + CGFloat(j) * 165, y: top - 500, width: 155, height: 110)
            dock.setFill()
            NSBezierPath(roundedRect: r, xRadius: 22, yRadius: 22).fill()
            image.draw(in: NSRect(x: r.midX - 36, y: r.midY - 36, width: 72, height: 72))
        }
    }
}
write(sheet, "sheet")
SWIFT

if [ -n "$PICK" ]; then
	echo "==> render $PICK 1024x1024"
	swift "$work/render.swift" "$SVG" "$work" "$PICK"
	set_dir="$work/AppIcon.iconset"
	mkdir -p "$set_dir"
	for size in 16 32 128 256 512; do
		double=$((size * 2))
		sips -z "$size" "$size" "$work/$PICK.png" --out "$set_dir/icon_${size}x${size}.png" > /dev/null
		sips -z "$double" "$double" "$work/$PICK.png" --out "$set_dir/icon_${size}x${size}@2x.png" > /dev/null
	done
	echo "==> iconutil -c icns"
	iconutil -c icns "$set_dir" -o "$OUT"
	echo "icon-concepts: $OUT"
	exit 0
fi

mkdir -p -- "$OUT"
echo "==> render every concept"
swift "$work/render.swift" "$SVG" "$work"
for png in "$work"/*.png; do
	name="$(basename "$png")"
	if [ "$name" = sheet.png ]; then
		cp "$png" "$OUT/$name"
	else
		sips -z 512 512 "$png" --out "$OUT/$name" > /dev/null
	fi
done
echo "icon-concepts: $OUT"
