import Foundation
import PDFKit
import UIKit

struct FloorPlanPDFExporter {
    func export(artifact: ScanArtifact, to destinationURL: URL) throws {
        guard let floorPlan = artifact.metadata.floorPlan else {
            throw ScanError.exportFailed("2D floor plan is unavailable.")
        }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            drawHeader(in: context.cgContext, rect: pageRect, margin: margin, createdAt: artifact.createdAt)
            drawSummary(in: context.cgContext, rect: pageRect, artifact: artifact, margin: margin)
            drawFloorPlan(in: context.cgContext, rect: pageRect, floorPlan: floorPlan, margin: margin)
            drawFooter(in: context.cgContext, rect: pageRect, margin: margin)
        }

        try data.write(to: destinationURL)
    }

    private func drawHeader(in context: CGContext, rect: CGRect, margin: CGFloat, createdAt: Date) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]

        let title = "Slam Floor Plan"
        let titleRect = CGRect(x: margin, y: margin, width: rect.width - 2 * margin, height: 30)
        title.draw(in: titleRect, withAttributes: titleAttributes)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        let subtitle = dateFormatter.string(from: createdAt)
        let subtitleRect = CGRect(x: margin, y: margin + 35, width: rect.width - 2 * margin, height: 20)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
    }

    private func drawSummary(in context: CGContext, rect: CGRect, artifact: ScanArtifact, margin: CGFloat) {
        var summaryParts: [String] = []

        if let dimensions = artifact.metadata.roomDimensions {
            summaryParts.append("Room: \(String(format: "%.2f", dimensions.x))m × \(String(format: "%.2f", dimensions.z))m")
        }

        summaryParts.append("Walls: \(artifact.metadata.wallCount)")
        summaryParts.append("Openings: \(artifact.metadata.openingCount)")
        summaryParts.append("Objects: \(artifact.metadata.objectCount)")
        summaryParts.append("Confidence: \(Int(artifact.metadata.confidence * 100))%")

        let summaryText = summaryParts.joined(separator: " | ")

        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        let summaryRect = CGRect(x: margin, y: margin + 65, width: rect.width - 2 * margin, height: 20)
        summaryText.draw(in: summaryRect, withAttributes: summaryAttributes)
    }

    private func drawFloorPlan(in context: CGContext, rect: CGRect, floorPlan: FloorPlanData, margin: CGFloat) {
        let headerHeight: CGFloat = 90
        let footerHeight: CGFloat = 40
        let planRect = CGRect(
            x: margin,
            y: margin + headerHeight,
            width: rect.width - 2 * margin,
            height: rect.height - headerHeight - footerHeight - 2 * margin
        )

        context.setFillColor(UIColor.white.cgColor)
        context.fill(planRect)

        let renderer = FloorPlanRenderer()
        renderer.draw(plan: floorPlan, in: context, rect: planRect, style: .pdf)
    }

    private func drawFooter(in context: CGContext, rect: CGRect, margin: CGFloat) {
        let footerText = "Measurements are approximate and derived from RoomPlan."

        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.gray
        ]

        let footerRect = CGRect(x: margin, y: rect.height - margin - 20, width: rect.width - 2 * margin, height: 20)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
    }
}