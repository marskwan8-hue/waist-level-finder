import SwiftUI

struct SettingsSheet: View {
    @AppStorage(SettingsKey.focusingScreen) private var screen = FocusingScreen.grid
    @AppStorage(SettingsKey.saveMirrored) private var saveMirrored = false
    @AppStorage(SettingsKey.rotationCorrection) private var rotationCorrection = 0
    @AppStorage(SettingsKey.exposureCount) private var exposureCount = 0
    @Environment(\.dismiss) private var dismiss

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
                    Toggle("保存镜像照片", isOn: $saveMirrored)
                } footer: {
                    Text("关闭时，保存的照片方向和真实场景一致；打开时，照片和取景屏上看到的一样，左右相反。")
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
                        Text("1. 把 iPhone Duo 展开，再横过来半折到 90° 左右，像一台小笔记本电脑。")
                        Text("2. 让背面有摄像头的那一半竖起来，镜头朝前；另一半平放，屏幕朝上。")
                        Text("3. 把手机端在腰间，低头看下半屏取景。点按画面对焦，按右边的快门拍照。")
                    }
                    .font(.callout)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
