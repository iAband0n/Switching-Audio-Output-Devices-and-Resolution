# DeviceSwitch

Windows 桌面工具，用快捷键或托盘菜单快速切换显示器分辨率/刷新率，并循环切换默认音频播放设备。

## 功能

- 自动读取系统可用的显示模式
- 保存最多 10 组分辨率、刷新率和快捷键预设
- 支持全局快捷键立即切换显示模式
- 支持托盘菜单和全局快捷键循环切换播放设备
- 可选开机自启并后台运行
- 提供普通构建版和单文件便携版

## 使用已构建版本

从 [Releases](../../releases) 下载最新压缩包或单文件版本，在 Windows 上运行 `Switch UR Device.exe`。程序需要 Windows 10/11；音频切换功能至少需要系统中存在两个启用的播放设备。

程序首次运行后会将设置保存到 `%APPDATA%\DisplayAudioControl\DeviceSwitch.ini`。仓库中的 `DeviceSwitch.ini` 仅作为构建时的初始配置示例，不会覆盖用户目录中的设置。

## 从源码构建

构建环境：

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/)
- AutoHotkey v2 的 `Ahk2Exe.exe`
- .NET Framework 4.x（仅构建单文件版本时需要 `csc.exe`）
- PowerShell 5 或更高版本

在 PowerShell 中执行：

```powershell
.\build.ps1
```

普通版本会输出到 `dist\DeviceSwitch.exe`。构建单文件便携版：

```powershell
.\build_singlefile.ps1
```

单文件版本会输出到 `dist\Switch UR Device.exe`。构建脚本会自动处理图标、音频辅助脚本和初始配置文件。

## 源码说明

- `DeviceSwitch.ahk`：主程序源码
- `SetDefaultAudioDevice.ps1`：设置 Windows 默认播放设备的辅助脚本
- `build.ps1`：编译普通版本
- `build_singlefile.ps1`：生成单文件便携版本
- `SingleFileLauncher.cs`：单文件版本的解包启动器
- `DeviceSwitch.ini`：初始配置示例

## 注意事项

该程序通过 Windows 原生显示设置和 Core Audio 接口工作。显示器驱动、权限或设备状态可能导致某些显示模式或音频设备无法切换。请先保存重要工作，再使用显示模式热键。

## 许可证

当前尚未指定许可证。公开发布前，请由作者确定许可条款并添加对应的 `LICENSE` 文件；在此之前，不应假定代码可自由复制、修改或分发。
