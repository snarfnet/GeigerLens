import SwiftUI

/// レトロ計測器風の配色。暗いパネル＋発光する針・数字。
enum Retro {
    static let bg         = Color(red: 0.06, green: 0.07, blue: 0.08)   // 画面背景
    static let panel      = Color(red: 0.09, green: 0.10, blue: 0.11)   // 本体パネル
    static let panelEdge  = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let bezel      = Color(red: 0.16, green: 0.17, blue: 0.19)   // 金属フレーム
    static let dial       = Color(red: 0.93, green: 0.90, blue: 0.80)   // 計器の文字盤（アイボリー）
    static let dialShadow = Color(red: 0.78, green: 0.74, blue: 0.62)
    static let ink        = Color(red: 0.12, green: 0.12, blue: 0.12)   // 目盛りの黒
    static let needle     = Color(red: 0.80, green: 0.12, blue: 0.10)   // 赤い針

    // LCDのグリーン
    static let lcd        = Color(red: 0.42, green: 0.95, blue: 0.55)
    static let lcdDim     = Color(red: 0.42, green: 0.95, blue: 0.55).opacity(0.16)
    static let amber      = Color(red: 0.98, green: 0.72, blue: 0.25)

    /// cpm値ごとのおおまかな色（参考）
    static func cpmColor(_ cpm: Double) -> Color {
        switch cpm {
        case ..<30:   return Color(red: 0.35, green: 0.85, blue: 0.55)
        case ..<60:   return Color(red: 0.70, green: 0.88, blue: 0.40)
        case ..<120:  return Color(red: 0.98, green: 0.82, blue: 0.30)
        case ..<300:  return Color(red: 0.98, green: 0.55, blue: 0.20)
        default:      return Color(red: 0.95, green: 0.25, blue: 0.20)
        }
    }
}
