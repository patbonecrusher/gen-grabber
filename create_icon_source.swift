#!/usr/bin/env swift
import AppKit

let size = 1024
let s = CGFloat(size)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let g = ctx.cgContext

// Clear to fully transparent
g.clear(CGRect(x: 0, y: 0, width: s, height: s))

// === Background: rounded rect, flat color ===
let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                     cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
g.addPath(bgPath)
g.clip()

g.setFillColor(CGColor(red: 0.10, green: 0.20, blue: 0.28, alpha: 1.0))
g.fill(CGRect(x: 0, y: 0, width: s, height: s))

// === Tree centered in the icon ===
let trunkColor = CGColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
let branchColor = CGColor(red: 0.50, green: 0.35, blue: 0.20, alpha: 0.9)
let leafColor = CGColor(red: 0.35, green: 0.65, blue: 0.40, alpha: 1.0)
let leafHighlight = CGColor(red: 0.45, green: 0.75, blue: 0.50, alpha: 1.0)

let treeCenterX = s * 0.50
let trunkBaseY = s * 0.10
let trunkTopY = s * 0.65

// Trunk (tapered)
g.beginPath()
g.move(to: CGPoint(x: treeCenterX - s * 0.03, y: trunkBaseY))
g.addLine(to: CGPoint(x: treeCenterX + s * 0.03, y: trunkBaseY))
g.addLine(to: CGPoint(x: treeCenterX + s * 0.015, y: trunkTopY))
g.addLine(to: CGPoint(x: treeCenterX - s * 0.015, y: trunkTopY))
g.closePath()
g.setFillColor(trunkColor)
g.fillPath()

// Helper to draw a branch from trunk
func drawBranch(fromY: CGFloat, toX: CGFloat, toY: CGFloat, width: CGFloat) {
    g.setStrokeColor(branchColor)
    g.setLineWidth(width)
    g.setLineCap(.round)
    g.beginPath()
    g.move(to: CGPoint(x: treeCenterX, y: fromY))
    g.addLine(to: CGPoint(x: toX, y: toY))
    g.strokePath()
}

// Helper to draw a leaf cluster (overlapping circles)
func drawLeafCluster(cx: CGFloat, cy: CGFloat, radius: CGFloat) {
    let offsets: [(CGFloat, CGFloat)] = [
        (0, 0), (-0.6, 0.4), (0.6, 0.4), (-0.3, -0.5), (0.3, -0.5),
        (-0.7, -0.1), (0.7, -0.1), (0, 0.6), (0, -0.7),
    ]
    for (dx, dy) in offsets {
        let r = radius * CGFloat.random(in: 0.6...1.0)
        let x = cx + dx * radius
        let y = cy + dy * radius
        g.setFillColor(Bool.random() ? leafColor : leafHighlight)
        g.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}

// Main branches and leaf clusters

// Top canopy
drawLeafCluster(cx: treeCenterX, cy: trunkTopY + s * 0.06, radius: s * 0.09)

// Upper left branch
let ulBranchY = trunkTopY - s * 0.05
let ulEndX = treeCenterX - s * 0.18
let ulEndY = ulBranchY + s * 0.12
drawBranch(fromY: ulBranchY, toX: ulEndX, toY: ulEndY, width: s * 0.012)
drawLeafCluster(cx: ulEndX, cy: ulEndY + s * 0.02, radius: s * 0.07)

// Upper right branch
let urEndX = treeCenterX + s * 0.20
let urEndY = ulBranchY + s * 0.10
drawBranch(fromY: ulBranchY, toX: urEndX, toY: urEndY, width: s * 0.012)
drawLeafCluster(cx: urEndX, cy: urEndY + s * 0.02, radius: s * 0.07)

// Middle left branch
let mlBranchY = trunkTopY - s * 0.18
let mlEndX = treeCenterX - s * 0.25
let mlEndY = mlBranchY + s * 0.10
drawBranch(fromY: mlBranchY, toX: mlEndX, toY: mlEndY, width: s * 0.015)
drawLeafCluster(cx: mlEndX, cy: mlEndY + s * 0.02, radius: s * 0.08)

// Middle right branch
let mrEndX = treeCenterX + s * 0.27
let mrEndY = mlBranchY + s * 0.08
drawBranch(fromY: mlBranchY, toX: mrEndX, toY: mrEndY, width: s * 0.015)
drawLeafCluster(cx: mrEndX, cy: mrEndY + s * 0.02, radius: s * 0.08)

// Lower left branch
let llBranchY = trunkTopY - s * 0.32
let llEndX = treeCenterX - s * 0.22
let llEndY = llBranchY + s * 0.08
drawBranch(fromY: llBranchY, toX: llEndX, toY: llEndY, width: s * 0.018)
drawLeafCluster(cx: llEndX, cy: llEndY + s * 0.02, radius: s * 0.07)

// Lower right branch
let lrEndX = treeCenterX + s * 0.24
let lrEndY = llBranchY + s * 0.06
drawBranch(fromY: llBranchY, toX: lrEndX, toY: lrEndY, width: s * 0.018)
drawLeafCluster(cx: lrEndX, cy: lrEndY + s * 0.02, radius: s * 0.07)

// === Magnifying glass (overlapping tree, lower right) ===
let magCenterX = s * 0.68
let magCenterY = s * 0.35
let magR = s * 0.18

// Glass circle - outer ring
g.setLineWidth(s * 0.03)
g.setStrokeColor(CGColor(red: 0.7, green: 0.72, blue: 0.75, alpha: 1.0))
g.strokeEllipse(in: CGRect(x: magCenterX - magR, y: magCenterY - magR, width: magR * 2, height: magR * 2))

// Glass fill
g.setFillColor(CGColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 0.12))
g.fillEllipse(in: CGRect(x: magCenterX - magR, y: magCenterY - magR, width: magR * 2, height: magR * 2))

// Shine
g.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
g.setLineWidth(s * 0.01)
g.setLineCap(.round)
let shineAngle = CGFloat.pi * 0.75
let shineR = magR * 0.7
g.beginPath()
g.addArc(center: CGPoint(x: magCenterX, y: magCenterY), radius: shineR,
         startAngle: shineAngle - 0.3, endAngle: shineAngle + 0.3, clockwise: false)
g.strokePath()

// Handle
let handleAngle = -CGFloat.pi * 0.25
let handleStart = CGPoint(
    x: magCenterX + cos(handleAngle) * magR,
    y: magCenterY + sin(handleAngle) * magR
)
let handleEnd = CGPoint(
    x: magCenterX + cos(handleAngle) * (magR + s * 0.15),
    y: magCenterY + sin(handleAngle) * (magR + s * 0.15)
)

g.setLineWidth(s * 0.04)
g.setLineCap(.round)
g.setStrokeColor(CGColor(red: 0.55, green: 0.57, blue: 0.6, alpha: 1.0))
g.beginPath()
g.move(to: handleStart)
g.addLine(to: handleEnd)
g.strokePath()

// Handle highlight
g.setLineWidth(s * 0.012)
g.setStrokeColor(CGColor(red: 0.75, green: 0.77, blue: 0.8, alpha: 1.0))
g.beginPath()
g.move(to: CGPoint(x: handleStart.x + 2, y: handleStart.y + 2))
g.addLine(to: CGPoint(x: handleEnd.x + 2, y: handleEnd.y + 2))
g.strokePath()

NSGraphicsContext.restoreGraphicsState()

// Save
let data = rep.representation(using: .png, properties: [:])!
let outputPath = "icon_source.png"
try! data.write(to: URL(fileURLWithPath: outputPath))
print("Generated \(outputPath) (1024x1024)")
