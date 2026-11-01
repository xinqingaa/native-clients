//
//  EngineeringLabApp.swift
//  EngineeringLab
//
//  Created by lrq on 2026/10/29.
//

import SwiftUI

// @main 启动入口
// App 对象遵循的协议
// body 应用提供的 Scene
// WindowGroup 提供一组窗口的根内容
// LabRootView() 根内容，提供工程、生命周期和 UI 实验入口
@main
struct EngineeringLabApp: App {
    var body: some Scene {
        WindowGroup {
            LabRootView()
        }
    }
}
