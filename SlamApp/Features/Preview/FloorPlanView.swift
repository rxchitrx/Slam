import SwiftUI
import simd
import UIKit

struct FloorPlanStyle {
    var backgroundColor: UIColor
    var wallColor: UIColor
    var wallLineWidth: CGFloat
    var openingColor: UIColor
    var openingLineWidth: CGFloat
    var objectFillColor: UIColor
    var objectStrokeColor: UIColor
    var objectLabelColor: UIColor
    var dimensionColor: UIColor
    var dimensionFontSize: CGFloat
    var objectLabelFontSize: CGFloat

    static let `default` = FloorPlanStyle(
        backgroundColor: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1),
        wallColor: UIColor(white: 0.15, alpha: 1),
        wallLineWidth: 3,
        openingColor: UIColor.blue.withAlphaComponent(0.8),
        openingLineWidth: 2,
        objectFillColor: UIColor(white: 0.85, alpha: 1),
        objectStrokeColor: UIColor(white: 0.6, alpha: 1),
        objectLabelColor: UIColor(white: 0.3, alpha: 1),
        dimensionColor: UIColor.red.withAlphaComponent(0.8),
        dimensionFontSize: 10,
        objectLabelFontSize: 9
    )

    static let pdf = FloorPlanStyle(
        backgroundColor: .white,
        wallColor: .black,
        wallLineWidth: 2,
        openingColor: .blue,
        openingLineWidth: 1.5,
        objectFillColor: UIColor(white: 0.9, alpha: 1),
        objectStrokeColor: UIColor(white: 0.5, alpha: 1),
        objectLabelColor: .black,
        dimensionColor: .red,
        dimensionFontSize: 9,
        objectLabelFontSize: 8
    )
}

struct FloorPlanLayout {
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetZ: CGFloat

    func toScreen(_ point: SIMD2<Float>) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * scale + offsetX,
            y: CGFloat(point.y) * scale + offsetZ
        )
    }
}

struct FloorPlanRenderer {
    func layout(plan: FloorPlanData, in rect: CGRect) -> FloorPlanLayout {
        let padding: CGFloat = 40

        let planWidth = CGFloat(plan.bounds.maxX - plan.bounds.minX)
        let planHeight = CGFloat(plan.bounds.maxZ - plan.bounds.minZ)

        guard planWidth > 0 && planHeight > 0 else {
            let centerX = rect.midX
            let centerZ = rect.midY
            return FloorPlanLayout(scale: 1, offsetX: centerX, offsetZ: centerZ)
        }

        let availableWidth = rect.width - 2 * padding
        let availableHeight = rect.height - 2 * padding

        let scaleX = availableWidth / planWidth
        let scaleZ = availableHeight / planHeight
        let scale = min(scaleX, scaleZ)

        let scaledWidth = planWidth * scale
        let scaledHeight = planHeight * scale

        let offsetX = rect.minX + (rect.width - scaledWidth) / 2 - CGFloat(plan.bounds.minX) * scale
        let offsetZ = rect.minY + (rect.height - scaledHeight) / 2 - CGFloat(plan.bounds.minZ) * scale

        return FloorPlanLayout(scale: scale, offsetX: offsetX, offsetZ: offsetZ)
    }

    func draw(plan: FloorPlanData, in context: CGContext, rect: CGRect, style: FloorPlanStyle) {
        let layout = layout(plan: plan, in: rect)

        context.saveGState()

        context.setFillColor(style.backgroundColor.cgColor)
        context.fill(rect)

        drawWalls(plan: plan, context: context, layout: layout, style: style)
        drawOpenings(plan: plan, context: context, layout: layout, style: style)
        drawObjects(plan: plan, context: context, layout: layout, style: style)
        drawDimensions(plan: plan, context: context, layout: layout, style: style)

        context.restoreGState()
    }

    private func drawWalls(plan: FloorPlanData, context: CGContext, layout: FloorPlanLayout, style: FloorPlanStyle) {
        context.setStrokeColor(style.wallColor.cgColor)
        context.setLineWidth(style.wallLineWidth)
        context.setLineCap(.round)

        for wall in plan.walls {
            let start = layout.toScreen(wall.start)
            let end = layout.toScreen(wall.end)

            context.move(to: start)
            context.addLine(to: end)
        }

        context.strokePath()
    }

    private func drawOpenings(plan: FloorPlanData, context: CGContext, layout: FloorPlanLayout, style: FloorPlanStyle) {
        context.setStrokeColor(style.openingColor.cgColor)
        context.setLineWidth(style.openingLineWidth)

        for opening in plan.openings {
            let center = layout.toScreen(opening.center)
            let halfWidth = CGFloat(opening.widthMeters) * layout.scale / 2

            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(opening.rotationRadians))

            context.move(to: CGPoint(x: -halfWidth, y: 0))
            context.addLine(to: CGPoint(x: halfWidth, y: 0))

            context.restoreGState()
        }

        context.strokePath()
    }

    private func drawObjects(plan: FloorPlanData, context: CGContext, layout: FloorPlanLayout, style: FloorPlanStyle) {
        for object in plan.objects {
            let center = layout.toScreen(object.center)
            let sizeX = CGFloat(object.sizeX) * layout.scale
            let sizeZ = CGFloat(object.sizeZ) * layout.scale

            let rect = CGRect(
                x: center.x - sizeX / 2,
                y: center.y - sizeZ / 2,
                width: sizeX,
                height: sizeZ
            )

            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(object.rotationRadians))
            context.translateBy(x: -center.x, y: -center.y)

            context.setFillColor(style.objectFillColor.cgColor)
            context.fill(rect)

            context.setStrokeColor(style.objectStrokeColor.cgColor)
            context.setLineWidth(1)
            context.stroke(rect)

            context.restoreGState()

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: style.objectLabelFontSize, weight: .medium),
                .foregroundColor: style.objectLabelColor
            ]
            let label = object.label as NSString
            let labelSize = label.size(withAttributes: labelAttributes)
            let labelPoint = CGPoint(
                x: center.x - labelSize.width / 2,
                y: center.y - labelSize.height / 2
            )
            label.draw(at: labelPoint, withAttributes: labelAttributes)
        }
    }

    private func drawDimensions(plan: FloorPlanData, context: CGContext, layout: FloorPlanLayout, style: FloorPlanStyle) {
        context.setStrokeColor(style.dimensionColor.cgColor)
        context.setLineWidth(1)
        context.setFillColor(style.dimensionColor.cgColor)

        let font = UIFont.systemFont(ofSize: style.dimensionFontSize, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        for dimension in plan.majorDimensions {
            let start = layout.toScreen(dimension.start)
            let end = layout.toScreen(dimension.end)

            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            let endCapLength: CGFloat = 5
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 0 else { continue }

            let perpX = -dy / length * endCapLength
            let perpY = dx / length * endCapLength

            context.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
            context.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
            context.move(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
            context.addLine(to: CGPoint(x: end.x - perpX, y: end.y - perpY))
            context.strokePath()

            let midX = (start.x + end.x) / 2
            let midY = (start.y + end.y) / 2

            let offset: CGFloat = 8
            let labelPoint = CGPoint(x: midX, y: midY + offset)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.dimensionColor,
                .paragraphStyle: paragraphStyle
            ]

            let text = dimension.text as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: labelPoint.x - textSize.width / 2,
                y: labelPoint.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            let bgColor = style.backgroundColor.withAlphaComponent(0.8)
            context.setFillColor(bgColor.cgColor)
            context.fill(textRect.insetBy(dx: -2, dy: -1))

            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

struct FloorPlanUIView: UIViewRepresentable {
    let plan: FloorPlanData
    var style: FloorPlanStyle = .default

    func makeUIView(context: Context) -> FloorPlanCanvasView {
        let view = FloorPlanCanvasView()
        view.plan = plan
        view.style = style
        return view
    }

    func updateUIView(_ uiView: FloorPlanCanvasView, context: Context) {
        uiView.plan = plan
        uiView.style = style
        uiView.setNeedsDisplay()
    }
}

class FloorPlanCanvasView: UIView {
    var plan: FloorPlanData?
    var style: FloorPlanStyle = .default

    override func draw(_ rect: CGRect) {
        guard let plan = plan, let context = UIGraphicsGetCurrentContext() else { return }
        let renderer = FloorPlanRenderer()
        renderer.draw(plan: plan, in: context, rect: rect, style: style)
    }
}

struct FloorPlanView: View {
    let plan: FloorPlanData
    var style: FloorPlanStyle = .default

    var body: some View {
        FloorPlanUIView(plan: plan, style: style)
    }
}