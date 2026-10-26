import SwiftUI

struct SettingsSheet: View {
    @AppStorage(SettingsKey.focusingScreen) private var screen = FocusingScreen.grid
    @AppStorage(SettingsKey.saveMirrored) private var saveMirrored = false
    @AppStorage(SettingsKey.rotationCorrection) private var rotationCorrection = 0
    @AppStorage(SettingsKey.exposureCount) private var exposureCount = 0
    @AppStorage(SettingsKey.appliesLook) private var appliesLook = true
    @AppStorage(SettingsKey.prefersNaturalTone) private var prefersNaturalTone = true
    @AppStorage(SettingsKey.flipsWaistLevel) private var flipsWaistLevel = true
    @AppStorage(SettingsKey.mirrorsViewfinder) private var mirrorsViewfinder = false
    @AppStorage(SettingsKey.language) private var languagePreference = LanguagePreference.system
    @Environment(\.language) private var language
    let onDone: () -> Void

    var body: some View {
        let l = language
        NavigationStack {
            Form {
                Section {
                    Picker(l.pick("语言", "Language"), selection: $languagePreference) {
                        ForEach(LanguagePreference.allCases) { preference in
                            Text(preference.title(in: l)).tag(preference)
                        }
                    }
                }

                Section(l.pick("对焦屏", "Focusing Screen")) {
                    Picker(l.pick("对焦屏", "Focusing Screen"), selection: $screen) {
                        ForEach(FocusingScreen.allCases) { screen in
                            Label(screen.title(in: l), systemImage: screen.symbol).tag(screen)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle(l.pick("哈苏风格色调", "Hasselblad-Style Color"), isOn: $appliesLook)
                    Toggle(l.pick("自然影调（少用多帧合成）", "Natural Tones (Less Multi-Frame Fusion)"), isOn: $prefersNaturalTone)
                } header: {
                    Text(l.pick("色彩", "Color"))
                } footer: {
                    Text(l.pick(
                        "色调同时用在取景屏和照片上：偏冷的底色带一点自然暖意，高光压低、暗部提亮、对比和鲜艳度略降，蓝色更沉，绿色更淡。自然影调会尽量不用 Smart HDR 这类多帧合成，光影过渡更自然，但暗光下噪点会多一些。",
                        "Applied to both the viewfinder and your photos: a cool base with a touch of natural warmth, softer highlights, lifted shadows, slightly lower contrast and vibrance, deeper blues and quieter greens. Natural Tones avoids multi-frame fusion such as Smart HDR for smoother light and shadow, with a little more noise in low light."
                    ))
                }

                Section {
                    Toggle(l.pick("镜像取景（真实腰平）", "Mirrored Viewfinder (True Waist-Level)"), isOn: $mirrorsViewfinder)
                } footer: {
                    Text(l.pick(
                        "真正的腰平取景器没有棱镜，看到的画面左右相反：相机往左移，画面往右跑。打开可以体验原汁原味的感觉。",
                        "A real waist-level finder has no prism, so the image is reversed left to right: move the camera left and the scene moves right. Turn this on for the authentic experience."
                    ))
                }

                Section {
                    Toggle(l.pick("保存镜像照片", "Save Mirrored Photos"), isOn: $saveMirrored)
                } footer: {
                    Text(l.pick(
                        "关闭时，保存的照片方向和真实场景一致；打开时，照片左右相反。",
                        "When off, photos match the real scene. When on, they're reversed left to right."
                    ))
                }

                Section {
                    Toggle(l.pick("腰平模式自动转正", "Turn Waist-Level Mode Upright"), isOn: $flipsWaistLevel)
                } footer: {
                    Text(l.pick(
                        "半折时 iPhone Duo 会把界面上下颠倒，打开后会让系统换到另一个横屏方向，屏幕、上滑回主屏幕的手势和系统弹窗都会转正。如果半折后取景屏出现在竖起来的那半屏，就切换这个开关，再重新折一次。",
                        "Half folded, iPhone Duo turns the interface upside down. With this on, the app asks the system for the other landscape orientation, so the screen, the Home gesture and system alerts are the right way up. If the viewfinder ends up on the upright half, switch this and fold again."
                    ))
                }

                Section {
                    Picker(l.pick("画面旋转校正", "Rotation Correction"), selection: $rotationCorrection) {
                        ForEach([0, 90, 180, 270], id: \.self) { degrees in
                            Text("\(degrees)°").tag(degrees)
                        }
                    }
                } footer: {
                    Text(l.pick(
                        "如果取景画面或拍出来的照片方向不对，在这里校正。",
                        "If the viewfinder or your photos come out rotated, correct it here."
                    ))
                }

                Section {
                    Button(l.pick("装新胶卷（计数归零）", "Load New Roll (Reset Counter)")) {
                        exposureCount = 0
                    }
                }

                Section(l.pick("怎么用", "How to Use")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.pick(
                            "1. 在控制中心关闭竖排方向锁定，否则半折后画面会上下颠倒。",
                            "1. Turn off Orientation Lock in Control Center, or the screen will be upside down when folded."
                        ))
                        Text(l.pick(
                            "2. 把 iPhone Duo 展开，再横过来半折到 90° 左右，像一台小笔记本电脑。",
                            "2. Unfold iPhone Duo, turn it sideways and fold it to about 90°, like a small laptop."
                        ))
                        Text(l.pick(
                            "3. 让背面有摄像头的那一半竖起来，镜头朝前；另一半平放，屏幕朝上。",
                            "3. Keep the half with the camera standing up, lens facing forward, and the other half flat, screen up."
                        ))
                        Text(l.pick(
                            "4. 把手机端在腰间，低头看平放的半屏取景，点按画面对焦，按旁边的快门拍照；其他按钮在竖起来的半屏。",
                            "4. Hold it at your waist and look down at the flat half to frame. Tap to focus and press the shutter beside it; the other controls are on the upright half."
                        ))
                    }
                    .font(.callout)
                }
            }
            .navigationTitle(l.pick("设置", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.pick("完成", "Done"), action: onDone)
                }
            }
        }
    }
}
