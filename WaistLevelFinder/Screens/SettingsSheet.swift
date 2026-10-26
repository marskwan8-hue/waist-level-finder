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
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("对焦屏") {
                    Picker("对焦屏", selection: $screen) {
                        ForEach(FocusingScreen.allCases) { screen in
                            Label(screen.title, systemImage: screen.symbol).tag(screen)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle("哈苏风格色调", isOn: $appliesLook)
                    Toggle("自然影调（少用多帧合成）", isOn: $prefersNaturalTone)
                } header: {
                    Text("色彩")
                } footer: {
                    Text("色调同时用在取景屏和照片上：偏冷的底色带一点自然暖意，高光压低、暗部提亮、对比和鲜艳度略降，蓝色更沉，绿色更淡。自然影调会尽量不用 Smart HDR 这类多帧合成，光影过渡更自然，但暗光下噪点会多一些。")
                }

                Section {
                    Toggle("镜像取景（真实腰平）", isOn: $mirrorsViewfinder)
                } footer: {
                    Text("真正的腰平取景器没有棱镜，看到的画面左右相反：相机往左移，画面往右跑。打开可以体验原汁原味的感觉。")
                }

                Section {
                    Toggle("保存镜像照片", isOn: $saveMirrored)
                } footer: {
                    Text("关闭时，保存的照片方向和真实场景一致；打开时，照片和取景屏上看到的一样，左右相反。")
                }

                Section {
                    Toggle("腰平模式自动转正", isOn: $flipsWaistLevel)
                } footer: {
                    Text("半折时 iPhone Duo 会把界面上下颠倒，打开后会让系统换到另一个横屏方向，屏幕、上滑回主屏幕的手势和系统弹窗都会转正。如果半折后取景屏出现在竖起来的那半屏，就切换这个开关，再重新折一次。")
                }

                Section {
                    Picker("画面旋转校正", selection: $rotationCorrection) {
                        ForEach([0, 90, 180, 270], id: \.self) { degrees in
                            Text("\(degrees)°").tag(degrees)
                        }
                    }
                } footer: {
                    Text("半折时，如果取景画面或拍出来的照片方向不对，在这里校正。")
                }

                Section {
                    Button("装新胶卷（计数归零）") {
                        exposureCount = 0
                    }
                }

                Section("怎么用") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 在控制中心关闭竖排方向锁定，否则半折后画面会上下颠倒。")
                        Text("2. 把 iPhone Duo 展开，再横过来半折到 90° 左右，像一台小笔记本电脑。")
                        Text("3. 让背面有摄像头的那一半竖起来，镜头朝前；另一半平放，屏幕朝上。")
                        Text("4. 把手机端在腰间，低头看下半屏取景。点按画面对焦，按右边的快门拍照。")
                    }
                    .font(.callout)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: onDone)
                }
            }
        }
    }
}
