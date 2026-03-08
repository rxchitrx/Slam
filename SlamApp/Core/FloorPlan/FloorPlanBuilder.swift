import Foundation
import RoomPlan
import simd

struct FloorPlanBuilder {
    func build(from room: CapturedRoom) throws -> FloorPlanData {
        let rawWalls = extractWalls(from: room)
        
        let alignmentAngle = computeAlignmentAngle(walls: rawWalls)
        
        let walls = rotateWalls(rawWalls, by: alignmentAngle)
        let openings = rotateOpenings(extractOpenings(from: room, walls: walls), by: alignmentAngle)
        let objects = rotateObjects(extractObjects(from: room), by: alignmentAngle)
        
        let bounds = computeBounds(walls: walls, openings: openings, objects: objects)
        let majorDimensions = selectMajorDimensions(from: walls)

        return FloorPlanData(
            version: 1,
            unit: "meters",
            bounds: bounds,
            walls: walls,
            openings: openings,
            objects: objects,
            majorDimensions: majorDimensions,
            renderDefaults: FloorPlanRenderDefaults(
                preferredPaddingMeters: 0.5,
                wallThicknessMeters: 0.15,
                openingStrokeMeters: 0.08
            )
        )
    }

    private func computeAlignmentAngle(walls: [FloorPlanWallSegment]) -> Float {
        guard !walls.isEmpty else { return 0 }
        
        var dominantAngle: Float = 0
        var maxWeight: Float = 0
        
        for wall in walls {
            let dx = wall.endX - wall.startX
            let dz = wall.endZ - wall.startZ
            let length = wall.lengthMeters
            
            let angle = atan2(dz, dx)
            
            let normalizedAngle = normalizeAngle(angle)
            
            let weight = length
            if weight > maxWeight {
                maxWeight = weight
                dominantAngle = normalizedAngle
            }
        }
        
        return -dominantAngle
    }
    
    private func normalizeAngle(_ angle: Float) -> Float {
        let twoPi = Float.pi * 2
        var normalized = angle.truncatingRemainder(dividingBy: twoPi)
        if normalized < 0 { normalized += twoPi }
        
        if normalized > Float.pi / 4 && normalized <= 3 * Float.pi / 4 {
            return normalized - Float.pi / 2
        } else if normalized > 3 * Float.pi / 4 && normalized <= 5 * Float.pi / 4 {
            return normalized - Float.pi
        } else if normalized > 5 * Float.pi / 4 && normalized <= 7 * Float.pi / 4 {
            return normalized - 3 * Float.pi / 2
        }
        return normalized
    }
    
    private func rotatePoint(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return SIMD2<Float>(
            point.x * cosA - point.y * sinA,
            point.x * sinA + point.y * cosA
        )
    }
    
    private func rotateWalls(_ walls: [FloorPlanWallSegment], by angle: Float) -> [FloorPlanWallSegment] {
        walls.map { wall in
            let start = rotatePoint(SIMD2<Float>(wall.startX, wall.startZ), by: angle)
            let end = rotatePoint(SIMD2<Float>(wall.endX, wall.endZ), by: angle)
            return FloorPlanWallSegment(
                id: wall.id,
                startX: start.x,
                startZ: start.y,
                endX: end.x,
                endZ: end.y,
                lengthMeters: wall.lengthMeters
            )
        }
    }
    
    private func rotateOpenings(_ openings: [FloorPlanOpening], by angle: Float) -> [FloorPlanOpening] {
        openings.map { opening in
            let center = rotatePoint(SIMD2<Float>(opening.centerX, opening.centerZ), by: angle)
            return FloorPlanOpening(
                id: opening.id,
                kind: opening.kind,
                centerX: center.x,
                centerZ: center.y,
                rotationRadians: opening.rotationRadians + angle,
                widthMeters: opening.widthMeters,
                depthMeters: opening.depthMeters,
                hostWallID: opening.hostWallID
            )
        }
    }
    
    private func rotateObjects(_ objects: [FloorPlanObject], by angle: Float) -> [FloorPlanObject] {
        objects.map { obj in
            let center = rotatePoint(SIMD2<Float>(obj.centerX, obj.centerZ), by: angle)
            return FloorPlanObject(
                id: obj.id,
                kind: obj.kind,
                label: obj.label,
                centerX: center.x,
                centerZ: center.y,
                sizeX: obj.sizeX,
                sizeZ: obj.sizeZ,
                rotationRadians: obj.rotationRadians + angle
            )
        }
    }

    private func extractWalls(from room: CapturedRoom) -> [FloorPlanWallSegment] {
        var segments: [FloorPlanWallSegment] = []

        for wall in room.walls {
            let transform = wall.transform
            let dimensions = wall.dimensions

            let length = abs(dimensions.x)
            let thickness = abs(dimensions.z)

            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let right = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)

            let halfLength = length / 2

            let startOffset = right * (-halfLength)
            let endOffset = right * halfLength

            let startXZ = SIMD2<Float>(position.x + startOffset.x, position.z + startOffset.z)
            let endXZ = SIMD2<Float>(position.x + endOffset.x, position.z + endOffset.z)

            let segment = FloorPlanWallSegment(
                id: UUID(),
                startX: startXZ.x,
                startZ: startXZ.y,
                endX: endXZ.x,
                endZ: endXZ.y,
                lengthMeters: length
            )
            segments.append(segment)
        }

        return segments
    }

    private func extractOpenings(from room: CapturedRoom, walls: [FloorPlanWallSegment]) -> [FloorPlanOpening] {
        var result: [FloorPlanOpening] = []

        for opening in room.openings {
            let transform = opening.transform
            let dimensions = opening.dimensions

            let category = opening.category
            let kind: FloorPlanOpeningKind
            switch category {
            case .door:
                kind = .door
            case .window:
                kind = .window
            default:
                kind = .opening
            }

            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let right = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)

            let rotation = atan2(right.z, right.x)

            let width = abs(dimensions.x)
            let depth = abs(dimensions.z)

            let centerXZ = SIMD2<Float>(position.x, position.z)

            let hostWallID = findNearestWallID(center: centerXZ, walls: walls, threshold: 0.5)

            let resultOpening = FloorPlanOpening(
                id: UUID(),
                kind: kind,
                centerX: centerXZ.x,
                centerZ: centerXZ.y,
                rotationRadians: rotation,
                widthMeters: width,
                depthMeters: depth,
                hostWallID: hostWallID
            )
            result.append(resultOpening)
        }

        return result
    }

    private func extractObjects(from room: CapturedRoom) -> [FloorPlanObject] {
        var result: [FloorPlanObject] = []

        for obj in room.objects {
            let transform = obj.transform
            let dimensions = obj.dimensions

            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let right = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)

            let rotation = atan2(right.z, right.x)

            let centerXZ = SIMD2<Float>(position.x, position.z)
            let sizeXZ = SIMD2<Float>(abs(dimensions.x), abs(dimensions.z))

            let kind = mapObjectCategory(obj.category)
            let label = String(describing: obj.category)

            let floorPlanObject = FloorPlanObject(
                id: UUID(),
                kind: kind,
                label: label,
                centerX: centerXZ.x,
                centerZ: centerXZ.y,
                sizeX: sizeXZ.x,
                sizeZ: sizeXZ.y,
                rotationRadians: rotation
            )
            result.append(floorPlanObject)
        }

        return result
    }

    private func computeBounds(walls: [FloorPlanWallSegment], openings: [FloorPlanOpening], objects: [FloorPlanObject]) -> FloorPlanBounds {
        var minX: Float = .greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude

        for wall in walls {
            minX = min(minX, wall.startX, wall.endX)
            minZ = min(minZ, wall.startZ, wall.endZ)
            maxX = max(maxX, wall.startX, wall.endX)
            maxZ = max(maxZ, wall.startZ, wall.endZ)
        }

        for opening in openings {
            let halfWidth = opening.widthMeters / 2
            let halfDepth = opening.depthMeters / 2
            minX = min(minX, opening.centerX - halfWidth)
            minZ = min(minZ, opening.centerZ - halfDepth)
            maxX = max(maxX, opening.centerX + halfWidth)
            maxZ = max(maxZ, opening.centerZ + halfDepth)
        }

        for object in objects {
            let halfSizeX = object.sizeX / 2
            let halfSizeZ = object.sizeZ / 2
            minX = min(minX, object.centerX - halfSizeX)
            minZ = min(minZ, object.centerZ - halfSizeZ)
            maxX = max(maxX, object.centerX + halfSizeX)
            maxZ = max(maxZ, object.centerZ + halfSizeZ)
        }

        if minX == .greatestFiniteMagnitude {
            minX = 0
            minZ = 0
            maxX = 1
            maxZ = 1
        }

        return FloorPlanBounds(minX: minX, minZ: minZ, maxX: maxX, maxZ: maxZ)
    }

    private func selectMajorDimensions(from walls: [FloorPlanWallSegment]) -> [FloorPlanDimension] {
        let filtered = walls.filter { $0.lengthMeters >= 0.6 }
        let sorted = filtered.sorted { $0.lengthMeters > $1.lengthMeters }
        let topWalls = Array(sorted.prefix(4))

        var dimensions: [FloorPlanDimension] = []
        for wall in topWalls {
            let text = formatDimension(wall.lengthMeters)
            let dimension = FloorPlanDimension(
                id: UUID(),
                startX: wall.startX,
                startZ: wall.startZ,
                endX: wall.endX,
                endZ: wall.endZ,
                text: text
            )
            dimensions.append(dimension)
        }

        return dimensions
    }

    private func findNearestWallID(center: SIMD2<Float>, walls: [FloorPlanWallSegment], threshold: Float) -> UUID? {
        var nearestID: UUID?
        var nearestDistance: Float = threshold

        for wall in walls {
            let distance = pointToLineDistance(point: center, lineStart: wall.start, lineEnd: wall.end)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestID = wall.id
            }
        }

        return nearestID
    }

    private func pointToLineDistance(point: SIMD2<Float>, lineStart: SIMD2<Float>, lineEnd: SIMD2<Float>) -> Float {
        let lineLength = simd_distance(lineStart, lineEnd)
        guard lineLength > 0 else {
            return simd_distance(point, lineStart)
        }

        let t = max(0, min(1, simd_dot(point - lineStart, lineEnd - lineStart) / (lineLength * lineLength)))
        let projection = lineStart + t * (lineEnd - lineStart)
        return simd_distance(point, projection)
    }

    private func mapObjectCategory(_ category: CapturedRoom.Object.Category) -> FloorPlanObjectKind {
        switch category {
        case .storage:
            return .storage
        case .bed:
            return .bed
        case .chair:
            return .chair
        case .sofa:
            return .sofa
        case .table:
            return .table
        case .toilet:
            return .toilet
        case .sink:
            return .sink
        case .bathtub:
            return .bathtub
        case .refrigerator:
            return .refrigerator
        case .stove:
            return .stove
        case .washerDryer:
            return .washerDryer
        case .television:
            return .television
        default:
            return .unknown
        }
    }

    private func formatDimension(_ meters: Float) -> String {
        if meters < 10 {
            return String(format: "%.2fm", meters)
        } else {
            return String(format: "%.1fm", meters)
        }
    }
}