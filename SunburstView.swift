import SwiftUI

// MARK: - Sunburst Segment

struct SunburstSegment: Identifiable {
    let id: String
    let item: FolderUsage
    let level: Int
    let startAngle: Double
    let endAngle: Double
    let color: Color
}

// MARK: - Sunburst View

struct SunburstView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    var scanProgress: ScanProgress? = nil
    let onSelect: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void
    
    @State private var hoveredItem: FolderUsage?
    @State private var navigationStack: [FolderUsage] = []
    
    private let maxLevels = 4
    private let centerRadius: CGFloat = 70
    private let ringWidth: CGFloat = 45
    
    // Цветовая палитра в стиле DaisyDisk
    private let colors: [Color] = [
        Color(hue: 0.6, saturation: 0.7, brightness: 0.9),   // синий
        Color(hue: 0.85, saturation: 0.6, brightness: 0.9),  // розовый
        Color(hue: 0.45, saturation: 0.7, brightness: 0.85), // бирюзовый
        Color(hue: 0.75, saturation: 0.6, brightness: 0.85), // фиолетовый
        Color(hue: 0.55, saturation: 0.6, brightness: 0.9),  // голубой
        Color(hue: 0.95, saturation: 0.6, brightness: 0.9),  // красный
        Color(hue: 0.12, saturation: 0.7, brightness: 0.95), // оранжевый
        Color(hue: 0.35, saturation: 0.6, brightness: 0.85), // зелёный
    ]
    
    private var currentItems: [FolderUsage] {
        navigationStack.last?.children ?? items
    }
    
    private var currentTotal: Int64 {
        navigationStack.last?.size ?? totalSize
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Навигация (breadcrumb + кнопка назад)
            navigationBar
            
            // Диаграмма
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let segments = buildSegments()
                // Сортируем: внешние уровни рисуются последними (поверх внутренних)
                let sortedSegments = segments.sorted { $0.level < $1.level }
                
                ZStack {
                    // Сегменты — рисуем от внутренних к внешним
                    ForEach(sortedSegments) { segment in
                        segmentView(segment: segment, center: center)
                    }
                    
                    // Центр — информация (поверх всего)
                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: centerRadius * 2, height: centerRadius * 2)
                        .position(center)
                        .onHover { isHovered in
                            if isHovered {
                                hoveredItem = nil
                            }
                        }
                    
                    // Текст в центре
                    centerInfo
                        .frame(width: centerRadius * 1.8)
                        .position(center)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
    
    // MARK: - Segment View
    
    private func segmentView(segment: SunburstSegment, center: CGPoint) -> some View {
        let isHovered = hoveredItem?.path == segment.item.path
        
        return SunburstArc(
            center: center,
            innerRadius: centerRadius + CGFloat(segment.level) * ringWidth,
            outerRadius: centerRadius + CGFloat(segment.level + 1) * ringWidth - 1,
            startAngle: segment.startAngle,
            endAngle: segment.endAngle
        )
        .fill(segment.color.opacity(isHovered ? 1.0 : 0.85))
        .overlay(
            SunburstArc(
                center: center,
                innerRadius: centerRadius + CGFloat(segment.level) * ringWidth,
                outerRadius: centerRadius + CGFloat(segment.level + 1) * ringWidth - 1,
                startAngle: segment.startAngle,
                endAngle: segment.endAngle
            )
            .stroke(isHovered ? Color.white : Color.white.opacity(0.3), lineWidth: isHovered ? 2 : 0.5)
        )
        .contentShape(
            SunburstArc(
                center: center,
                innerRadius: centerRadius + CGFloat(segment.level) * ringWidth,
                outerRadius: centerRadius + CGFloat(segment.level + 1) * ringWidth - 1,
                startAngle: segment.startAngle,
                endAngle: segment.endAngle
            )
        )
        .onHover { hovering in
            if hovering {
                hoveredItem = segment.item
            }
        }
        .onTapGesture {
            if !segment.item.children.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    navigationStack.append(segment.item)
                    hoveredItem = nil
                }
            }
        }
        .contextMenu {
            contextMenu(for: segment.item)
        }
    }
    
    // MARK: - Center Info
    
    private var centerInfo: some View {
        VStack(spacing: 4) {
            if let progress = scanProgress {
                // Во время сканирования показываем прогресс
                Text(formatBytes(progress.bytesFound))
                    .font(.system(size: 18, weight: .bold))
                Text(String(localized: "sunburst.scanning", defaultValue: "scanning…"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if let item = hoveredItem {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(formatBytes(item.size))
                    .font(.system(size: 15, weight: .bold))
                Text(formatPercent(item.size, of: currentTotal))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text(formatBytes(currentTotal))
                    .font(.system(size: 18, weight: .bold))
                Text(String(localized: "sunburst.scanned", defaultValue: "scanned"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack(spacing: 8) {
            // Кнопка назад
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    _ = navigationStack.popLast()
                    hoveredItem = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(navigationStack.isEmpty)
            .help(String(localized: "sunburst.back", defaultValue: "Go back"))
            
            // Breadcrumb
            HStack(spacing: 4) {
                // Корень
                Button("/") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        navigationStack.removeAll()
                        hoveredItem = nil
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(navigationStack.isEmpty ? .primary : .secondary)
                
                // Путь
                ForEach(Array(navigationStack.enumerated()), id: \.element.path) { index, item in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Button(item.name) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navigationStack = Array(navigationStack.prefix(index + 1))
                            hoveredItem = nil
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == navigationStack.count - 1 ? .primary : .secondary)
                    .lineLimit(1)
                }
            }
            .font(.system(size: 13))
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Build Segments
    
    private func buildSegments() -> [SunburstSegment] {
        var segments: [SunburstSegment] = []
        
        let sortedItems = currentItems.sorted { $0.size > $1.size }
        buildSegmentsRecursive(
            items: sortedItems,
            total: currentTotal,
            level: 0,
            startAngle: 0,
            endAngle: 360,
            colorIndex: 0,
            segments: &segments
        )
        
        return segments
    }
    
    private func buildSegmentsRecursive(
        items: [FolderUsage],
        total: Int64,
        level: Int,
        startAngle: Double,
        endAngle: Double,
        colorIndex: Int,
        segments: inout [SunburstSegment]
    ) {
        guard level < maxLevels, total > 0 else { return }
        
        let angleRange = endAngle - startAngle
        var currentAngle = startAngle
        
        for (index, item) in items.enumerated() {
            let proportion = Double(item.size) / Double(total)
            let itemAngle = angleRange * proportion
            
            // Пропускаем слишком маленькие сегменты (< 1 градус)
            guard itemAngle >= 1.0 else { continue }
            
            let itemEndAngle = currentAngle + itemAngle
            let color = colors[(colorIndex + index) % colors.count]
            
            segments.append(SunburstSegment(
                id: "\(item.path)-\(level)",
                item: item,
                level: level,
                startAngle: currentAngle,
                endAngle: itemEndAngle,
                color: color
            ))
            
            // Рекурсивно добавляем детей
            if !item.children.isEmpty {
                let childItems = item.children.sorted { $0.size > $1.size }
                buildSegmentsRecursive(
                    items: childItems,
                    total: item.size,
                    level: level + 1,
                    startAngle: currentAngle,
                    endAngle: itemEndAngle,
                    colorIndex: colorIndex + index,
                    segments: &segments
                )
            }
            
            currentAngle = itemEndAngle
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenu(for item: FolderUsage) -> some View {
        Button {
            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
        } label: {
            Label(String(localized: "context.showInFinder", defaultValue: "Show in Finder"), systemImage: "folder")
        }
        
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        } label: {
            Label(String(localized: "context.copyPath", defaultValue: "Copy Path"), systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            onDelete(item)
        } label: {
            Label(String(localized: "context.moveToTrash", defaultValue: "Move to Trash"), systemImage: "trash")
        }
    }
}

// MARK: - Sunburst Arc Shape

struct SunburstArc: Shape {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Double
    let endAngle: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let startRad = Angle(degrees: startAngle - 90).radians
        let endRad = Angle(degrees: endAngle - 90).radians
        
        // Внешняя дуга
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: Angle(radians: startRad),
            endAngle: Angle(radians: endRad),
            clockwise: false
        )
        
        // Линия к внутренней дуге
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: endRad),
            endAngle: Angle(radians: startRad),
            clockwise: true
        )
        
        path.closeSubpath()
        
        return path
    }
}
