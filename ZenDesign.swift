import AppKit
import SwiftUI

enum ZenDesign {
    enum Spacing {
        static let compact: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }

    enum Colors {
        static var primaryBackground: Color { Color("ZenBackground") }
        static var surface: Color { Color("ZenSurface") }
        static var elevatedSurface: Color { Color("ZenElevatedSurface") }

        static var primaryText: Color { Color(nsColor: NSColor.labelColor) }
        static var secondaryText: Color { Color(nsColor: NSColor.secondaryLabelColor) }
        static var mutedText: Color { Color(nsColor: NSColor.tertiaryLabelColor) }

        static var separator: Color { Color(nsColor: NSColor.separatorColor) }
        static var accent: Color { Color.accentColor }
        static var warning: Color { Color(nsColor: NSColor.systemOrange) }
        static var destructive: Color { Color(nsColor: NSColor.systemRed) }
    }

    enum Typography {
        static var windowTitle: Font { .title2.weight(.semibold) }
        static var section: Font { .headline }
        static var body: Font { .body }
        static var detail: Font { .caption }
        static var micro: Font { .caption2 }
    }
}
