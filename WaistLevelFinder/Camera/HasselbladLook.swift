import CoreImage
import Foundation

/// A Hasselblad-like colour grade, baked into one 3D LUT so it's cheap enough
/// for the live viewfinder and identical on the saved photo.
///
/// Based on a community recipe for iPhone:
/// - "Cool" photographic style: a cool base with subtle natural warmth.
/// - Stage one (Photos editor): Exposure +10, Highlights −40, Shadows +30, Contrast −15,
///   Vibrance −10, Warmth −8, Tint +2, Sharpness +10.
/// - Stage two: lift shadows slightly and pull highlights down gently;
///   Blues saturation +5, luminance −5; Greens hue +5, saturation −8.
///
/// The Photos sliders have no published formulas, so the numbers below are
/// approximations of how far each slider moves the image.
nonisolated enum HasselbladLook {
    static let cubeDimension = 33
    static let cubeData: Data = makeCube()

    static func apply(to image: CIImage) -> CIImage {
        image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": cubeDimension,
            "inputCubeData": cubeData,
            "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB)!,
        ])
    }

    /// Sharpness +10. Only for the saved photo; the viewfinder doesn't need it.
    static func sharpen(_ image: CIImage) -> CIImage {
        image.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.25])
    }

    // MARK: - Recipe

    /// Cool base + Warmth −8 + Tint +2 (towards magenta), as linear-light channel gains.
    private static let whiteBalance: (r: Double, g: Double, b: Double) = (0.975, 0.996, 1.025)
    /// Exposure +10.
    private static let exposureEV = 0.12
    /// Highlights −40, Shadows +30, Contrast −15 and the stage-two curve, as one tone curve.
    /// A slightly lifted black point gives the soft, matte shadows.
    private static let toneCurve = MonotoneCurve(points: [
        (0, 0.025), (0.25, 0.27), (0.5, 0.52), (0.75, 0.755), (1, 0.965),
    ])
    /// Vibrance −10: mutes the less saturated colours more than the saturated ones.
    private static let vibrance = -0.15

    private static func grade(_ input: (r: Double, g: Double, b: Double)) -> (r: Double, g: Double, b: Double) {
        let gain = pow(2, exposureEV)
        var r = encode(decode(input.r) * whiteBalance.r * gain)
        var g = encode(decode(input.g) * whiteBalance.g * gain)
        var b = encode(decode(input.b) * whiteBalance.b * gain)

        r = toneCurve.value(at: r)
        g = toneCurve.value(at: g)
        b = toneCurve.value(at: b)

        var (h, s, l) = rgbToHSL(r, g, b)
        s *= 1 + vibrance * (1 - s)

        // Greens: hue +5 (towards aqua), saturation −8.
        let green = hueWeight(h, center: 115, width: 50)
        h += 4 * green
        s *= 1 - 0.08 * green

        // Blues: saturation +5, luminance −5.
        let blue = hueWeight(h, center: 215, width: 45)
        s *= 1 + 0.05 * blue
        l *= 1 - 0.05 * blue

        let out = hslToRGB(h, min(max(s, 0), 1), min(max(l, 0), 1))
        return (clamp(out.r), clamp(out.g), clamp(out.b))
    }

    private static func makeCube() -> Data {
        let n = cubeDimension
        var values = [Float]()
        values.reserveCapacity(n * n * n * 4)
        // Red changes fastest, then green, then blue.
        for bi in 0..<n {
            for gi in 0..<n {
                for ri in 0..<n {
                    let scale = Double(n - 1)
                    let c = grade((Double(ri) / scale, Double(gi) / scale, Double(bi) / scale))
                    values.append(contentsOf: [Float(c.r), Float(c.g), Float(c.b), 1])
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: - Colour helpers

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    /// sRGB → linear light.
    private static func decode(_ x: Double) -> Double {
        x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }

    /// Linear light → sRGB, clipped to 0...1.
    private static func encode(_ x: Double) -> Double {
        let x = clamp(x)
        return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
    }

    /// 1 at `center`, easing to 0 at `width` degrees away.
    private static func hueWeight(_ hue: Double, center: Double, width: Double) -> Double {
        var d = abs(hue - center).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        guard d < width else { return 0 }
        return 0.5 * (1 + cos(.pi * d / width))
    }

    private static func rgbToHSL(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let l = (maxC + minC) / 2
        let d = maxC - minC
        guard d > 1e-6 else { return (0, 0, l) }
        let s = d / (1 - abs(2 * l - 1))
        var h: Double
        if maxC == r {
            h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            h = 60 * ((b - r) / d + 2)
        } else {
            h = 60 * ((r - g) / d + 4)
        }
        if h < 0 { h += 360 }
        return (h, s, l)
    }

    private static func hslToRGB(_ h: Double, _ s: Double, _ l: Double) -> (r: Double, g: Double, b: Double) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double) = switch hp {
        case ..<1: (c, x, 0)
        case ..<2: (x, c, 0)
        case ..<3: (0, c, x)
        case ..<4: (0, x, c)
        case ..<5: (x, 0, c)
        default: (c, 0, x)
        }
        let m = l - c / 2
        return (r1 + m, g1 + m, b1 + m)
    }
}

/// A smooth curve through control points that never overshoots (Fritsch–Carlson).
nonisolated struct MonotoneCurve {
    private let xs: [Double]
    private let ys: [Double]
    private let tangents: [Double]

    init(points: [(Double, Double)]) {
        xs = points.map(\.0)
        ys = points.map(\.1)
        let n = points.count
        let slopes = (0..<n - 1).map { (ys[$0 + 1] - ys[$0]) / (xs[$0 + 1] - xs[$0]) }
        var m = [Double](repeating: 0, count: n)
        m[0] = slopes[0]
        m[n - 1] = slopes[n - 2]
        for i in 1..<n - 1 {
            m[i] = slopes[i - 1] * slopes[i] <= 0 ? 0 : (slopes[i - 1] + slopes[i]) / 2
        }
        for i in 0..<n - 1 where slopes[i] != 0 {
            let a = m[i] / slopes[i], b = m[i + 1] / slopes[i]
            let t = a * a + b * b
            if t > 9 {
                let k = 3 / t.squareRoot()
                m[i] = k * a * slopes[i]
                m[i + 1] = k * b * slopes[i]
            }
        }
        tangents = m
    }

    func value(at x: Double) -> Double {
        if x <= xs[0] { return ys[0] }
        if x >= xs[xs.count - 1] { return ys[ys.count - 1] }
        let i = (0..<xs.count - 1).first { x < xs[$0 + 1] } ?? xs.count - 2
        let h = xs[i + 1] - xs[i]
        let t = (x - xs[i]) / h
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * ys[i]
            + (t3 - 2 * t2 + t) * h * tangents[i]
            + (-2 * t3 + 3 * t2) * ys[i + 1]
            + (t3 - t2) * h * tangents[i + 1]
    }
}
