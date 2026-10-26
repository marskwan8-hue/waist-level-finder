import SwiftUI

/// The interchangeable focusing screens of a medium-format waist-level camera.
enum FocusingScreen: String, CaseIterable, Identifiable {
    case plain, thirds, grid, splitImage

    var id: Self { self }

    func title(in language: Language) -> String {
        switch self {
        case .plain: language.pick("全磨砂", "Matte")
        case .thirds: language.pick("三分线", "Thirds")
        case .grid: language.pick("方格", "Grid")
        case .splitImage: language.pick("裂像", "Split")
        }
    }

    var symbol: String {
        switch self {
        case .plain: "square"
        case .thirds: "squareshape.split.3x3"
        case .grid: "square.grid.4x3.fill"
        case .splitImage: "circle.circle"
        }
    }

    var next: FocusingScreen {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

// MARK: - Markings

/// The lines etched into the focusing screen.
struct ScreenMarkings: View {
    let screen: FocusingScreen

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let ink = GraphicsContext.Shading.color(.black.opacity(0.45))

            switch screen {
            case .plain:
                break

            case .thirds, .grid:
                let divisions = screen == .thirds ? 3 : 4
                var lines = Path()
                for i in 1..<divisions {
                    let x = size.width * CGFloat(i) / CGFloat(divisions)
                    let y = size.height * CGFloat(i) / CGFloat(divisions)
                    lines.move(to: CGPoint(x: x, y: 0))
                    lines.addLine(to: CGPoint(x: x, y: size.height))
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(lines, with: ink, lineWidth: 0.8)
                guard screen == .grid else { break }
                let r = side * 0.06
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                               with: ink, lineWidth: 0.8)

            case .splitImage:
                let inner = side * 0.06
                let outer = side * 0.1
                // Microprism collar: a fine dot pattern between the two circles.
                let step = max(side / 160, 2)
                var dots = Path()
                var y = center.y - outer
                while y <= center.y + outer {
                    var x = center.x - outer
                    while x <= center.x + outer {
                        let d = hypot(x - center.x, y - center.y)
                        if d > inner, d < outer {
                            dots.addEllipse(in: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1))
                        }
                        x += step
                    }
                    y += step
                }
                context.fill(dots, with: .color(.black.opacity(0.35)))
                for r in [inner, outer] {
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                                   with: ink, lineWidth: 0.8)
                }
                var split = Path()
                split.move(to: CGPoint(x: center.x - inner, y: center.y))
                split.addLine(to: CGPoint(x: center.x + inner, y: center.y))
                context.stroke(split, with: ink, lineWidth: 0.8)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Ground glass texture

/// What makes it look like an image on frosted glass rather than a phone screen:
/// a bright hot spot, faint Fresnel rings, and a static grain.
struct GroundGlassTexture: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [.white.opacity(0.08), .clear], center: .center, startRadius: 0, endRadius: 220)
                .blendMode(.screen)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = hypot(size.width, size.height) / 2
                var rings = Path()
                for r in stride(from: CGFloat(6), to: maxRadius, by: 6) {
                    rings.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
                }
                context.stroke(rings, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
            }

            Image(uiImage: GrainTexture.image)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.55)
        }
        .allowsHitTesting(false)
    }
}

/// A darkening toward the corners, stronger and rounder through the loupe.
struct Vignette: View {
    let isLoupe: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            RadialGradient(
                stops: isLoupe
                    ? [.init(color: .clear, location: 0.62), .init(color: .black, location: 0.72)]
                    : [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.6), location: 1)],
                center: .center,
                startRadius: 0,
                endRadius: side * 0.72
            )
        }
        .allowsHitTesting(false)
    }
}

/// A tileable grey noise texture centred on 50% grey, so `.overlay` leaves average brightness alone.
enum GrainTexture {
    static let image: UIImage = {
        let size = 192
        var pixels = [UInt8](repeating: 128, count: size * size)
        for i in pixels.indices {
            pixels[i] = UInt8.random(in: 92...164)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: size, height: size,
                bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              )
        else { return UIImage() }
        return UIImage(cgImage: image, scale: 2, orientation: .up)
    }()
}
