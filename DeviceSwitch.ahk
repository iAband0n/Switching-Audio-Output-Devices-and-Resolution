#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================================
; 自动获取系统当前合法的显示模式
; =========================================================================
Global UniqueRes := []
Global PresetData := Map()     
Global PresetButtons := []
Global CurrentAudioHotkey := ""
Global AudioTrayMenu := Menu()
Global AudioTrayDeviceMap := Map()
Global AppDataDir := A_AppData "\DisplayAudioControl"
Global AppIconPath := A_IsCompiled ? A_ScriptFullPath : A_ScriptDir "\icon.ico"

Global AppIconHandle := 0
Global StartupShortcutPath := A_Startup "\DisplayAudioControl.lnk"
Global LaunchHiddenOnStartup := HasStartupLaunchArg()
Global SettingsFile := AppDataDir "\DeviceSwitch.ini"


Global IsExiting := false



     

devMode := Buffer(220, 0)
NumPut("UShort", 220, devMode, 68)
Index := 0
While DllCall("EnumDisplaySettingsW", "Ptr", 0, "Int", Index, "Ptr", devMode) {
    W := NumGet(devMode, 172, "UInt")
    H := NumGet(devMode, 176, "UInt")
    Str := W "x" H
    Exists := false
    For r In UniqueRes {
        if (r == Str) {
            Exists := true
            break
        }
    }
    if !Exists {
        UniqueRes.Push(Str)
    }
    Index++
}

; =========================================================================
; 可视化音频切换悬浮窗 (OSD HUD) 初始化
; =========================================================================
Global OsdGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20") 
OsdGui.BackColor := "1A1A1A"                                    
OsdGui.SetFont("s13 Bold", "Microsoft YaHei")                    
Global OsdIcon := OsdGui.Add("Picture", "x10 y9 w18 h18 Icon1", "mmsys.cpl")
Global OsdText := OsdGui.Add("Text", "cWhite x36 y8 w280 h22 +0x200", "音频设备已切换")


WinSetTransparent(210, OsdGui)
RefreshTrayMenu()
EnsureAppDataDir()



; =========================================================================
; UI 界面设计

; =========================================================================


MyGui := Gui("+Resize", "音频/分辨率快捷切换 by Jin")
MyGui.SetFont("s10", "Microsoft YaHei")

MyGui.Add("Text", "x20 y18 w75 h25 +0x0200", "音频快捷键:")
Global HK_Audio := MyGui.Add("Hotkey", "x95 y14 w110 h26")
BtnSetAudioHK := MyGui.Add("Button", "x210 y14 w85 h26", "设置音频键")
BtnSetAudioHK.OnEvent("Click", SetAudioHotkey)

Global Text_Count := MyGui.Add("Text", "x455 y14 w90 h26 +0x0200 +Right", "快捷按钮数量:")
Global DDL_Count := MyGui.Add("DropDownList", "x550 y14 w60 R10", ["1","2","3","4","5","6","7","8","9","10"])
DDL_Count.Value := 2 
DDL_Count.OnEvent("Change", OnPresetCountChange)

Global CHK_Startup := MyGui.Add("CheckBox", "x20 y112 w180 h24", "开机自启并后台运行")
CHK_Startup.OnEvent("Click", ToggleStartupLaunch)


MyGui.SetFont("s26 Bold", "Microsoft YaHei") 
 
Global DDL_Res := MyGui.Add("DropDownList", "x20 y55 w310 R12", UniqueRes)
DDL_Res.OnEvent("Change", (*) => HK_Res.Value := "")

MaxW := 0, MaxH := 0, MaxIdx := 1
For Idx, Res In UniqueRes {
    parts := StrSplit(Res, "x")
    W := Integer(parts[1]), H := Integer(parts[2])
    if (W > MaxW || (W == MaxW && H > MaxH)) {
        MaxW := W
        MaxH := H
        MaxIdx := Idx
    }
}
if (UniqueRes.Length > 0) {
    DDL_Res.Value := MaxIdx
}
MyGui.SetFont("s10 Norm", "Microsoft YaHei") 

Global HK_Res := MyGui.Add("Hotkey", "x345 y55 w130 h26") 
Global HK_Hint := MyGui.Add("Text", "x345 y59 w130 h20 +Center +BackgroundTrans cGray", "点击设置热键")
HK_Hint.OnEvent("Click", (*) => HK_Res.Focus()) 

SetTimer(MonitorHotkeyFocus, 100)

Global DDL_Freq := MyGui.Add("DropDownList", "x345 y89 w130 R6", ["60 Hz", "144 Hz", "165 Hz", "240 Hz"])
DDL_Freq.Value := 4

MyGui.SetFont("s14 Bold", "Microsoft YaHei")
Global BtnSwitch := MyGui.Add("Button", "x490 y55 w120 h60", "立即切换")
BtnSwitch.OnEvent("Click", (*) => ApplyFromUI())
MyGui.SetFont("s10 Norm", "Microsoft YaHei") 

B_X := 20, B_Y := 140, B_W := 110, B_H := 46 
MyGui.SetFont("s12", "Microsoft YaHei")

Loop 10 {
    Idx := A_Index
    Btn := MyGui.Add("Button", "x" B_X " y" B_Y " w" B_W " h" B_H " +Center", "未设置 " Idx)
    Btn.PresetIdx := Idx
    Btn.OnEvent("Click", HandlePresetClick)
    Btn.OnEvent("ContextMenu", HandlePresetRightClick)
    PresetButtons.Push(Btn)
    
    B_X += 120
    if (Mod(Idx, 5) == 0) {
        B_X := 20
        B_Y += 56          
    }
}
MyGui.SetFont("s10 Norm", "Microsoft YaHei") 

MyGui.OnEvent("Size", Gui_Size)
MyGui.OnEvent("Close", OnGuiExit)
MyGui.OnEvent("Escape", OnGuiExit)
LoadSettings()
MyGui.Show("Hide w630 h10")
ApplyAppIcons()
AdjustMainWindowHeight(MyGui, true)

if !LaunchHiddenOnStartup {
    CenterMainWindow(MyGui)
    MyGui.Show()
}







; =========================================================================
; 辅助功能函数
; =========================================================================
HasStartupLaunchArg() {
    for _, arg in A_Args {
        if (arg = "--startup")
            return true
    }
    return false
}

EnsureAppDataDir() {
    global AppDataDir
    if !DirExist(AppDataDir)
        DirCreate(AppDataDir)
}

ApplyAppIcons() {


    global AppIconPath, AppIconHandle, OsdGui, MyGui
    if !FileExist(AppIconPath)
        return

    TraySetIcon(AppIconPath)
    AppIconHandle := LoadPicture(AppIconPath, "Icon1", &iconType)
    if !AppIconHandle
        return

    try SendMessage(0x80, 0, AppIconHandle, , OsdGui)
    try SendMessage(0x80, 1, AppIconHandle, , OsdGui)
    try SendMessage(0x80, 0, AppIconHandle, , MyGui)
    try SendMessage(0x80, 1, AppIconHandle, , MyGui)
}


Gui_Size(GuiObj, MinMax, Width, Height) {
    if (MinMax == -1) 
        return
    NewRightX := Width - 20
    BtnSwitch.Move(NewRightX - 120)
    NewDDLCountX := NewRightX - 60
    DDL_Count.Move(NewDDLCountX)
    Text_Count.Move(NewDDLCountX - 95) 
    TunePresetVisibility(GuiObj, Width)
}

AdjustMainWindowHeight(GuiObj, KeepHidden := false) {
    GuiObj.GetPos(&winX, &winY, &winWidth, &winHeight)
    GuiObj.GetClientPos(, , &clientCurrentWidth)
    targetHeight := TunePresetVisibility(GuiObj, clientCurrentWidth)
    showOptions := "x" winX " y" winY " w" clientCurrentWidth " h" targetHeight
    if KeepHidden
        showOptions .= " Hide"
    GuiObj.Show(showOptions)
}

CenterMainWindow(GuiObj) {
    GuiObj.GetPos(, , &winWidth, &winHeight)
    posX := Floor((A_ScreenWidth - winWidth) / 2)
    posY := Floor((A_ScreenHeight - winHeight) / 2)
    GuiObj.Show("x" posX " y" posY)
}



OnPresetCountChange(*) {
    global MyGui
    AdjustMainWindowHeight(MyGui)
    SaveSettings()
}

ToggleStartupLaunch(*) {
    SaveSettings()
}

ShowMainWindow(*) {

    global MyGui
    AdjustMainWindowHeight(MyGui, true)
    CenterMainWindow(MyGui)
    MyGui.Show()
    WinActivate(MyGui)
}

HideToTray(*) {
    global MyGui
    SaveSettings()
    MyGui.Hide()
}

ExitFromTray(*) {
    global IsExiting
    IsExiting := true
    SaveSettings()
    ExitApp
}

OnGuiExit(*) {
    HideToTray()
}

MonitorHotkeyFocus() {




    Global MyGui, HK_Res, HK_Hint
    if !WinActive(MyGui.Hwnd)
        return
    Try {
        FocusedCtrl := MyGui.FocusedCtrl
        if (FocusedCtrl && FocusedCtrl.Hwnd == HK_Res.Hwnd) {
            if (HK_Hint.Visible)
                HK_Hint.Visible := false
        } else {
            if (HK_Res.Value == "") {
                if (!HK_Hint.Visible)
                    HK_Hint.Visible := true
            } else {
                if (HK_Hint.Visible)
                    HK_Hint.Visible := false
            }
        }
    }
}

FormatHotkeyText(hkString) {
    if (hkString == "") {
        return ""
    }
    readable := ""
    if InStr(hkString, "^") {
        readable .= "Ctrl+"
        hkString := StrReplace(hkString, "^")
    }
    if InStr(hkString, "!") {
        readable .= "Alt+"
        hkString := StrReplace(hkString, "!")
    }
    if InStr(hkString, "+") {
        readable .= "Shift+"
        hkString := StrReplace(hkString, "+")
    }
    if InStr(hkString, "#") {
        readable .= "Win+"
        hkString := StrReplace(hkString, "#")
    }
    if (StrLen(hkString) == 1) {
        hkString := Format("{:U}", hkString)
    }
    return readable . hkString
}

CalculateTextWidth(text, fontSize, fontName := "Microsoft YaHei") {
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    Height := -DllCall("MulDiv", "Int", fontSize, "Int", DllCall("GetDeviceCaps", "Ptr", hDC, "Int", 90), "Int", 72)
    hFont := DllCall("CreateFontW", "Int", Height, "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "Str", fontName, "Ptr")
    hOldFont := DllCall("SelectObject", "Ptr", hDC, "Ptr", hFont, "Ptr")
    size := Buffer(8)
    MaxWidth := 0
    Loop Parse, text, "`n", "`r" {
        DllCall("GetTextExtentPoint32W", "Ptr", hDC, "Str", A_LoopField, "Int", StrLen(A_LoopField), "Ptr", size)
        W := NumGet(size, 0, "Int")
        if (W > MaxWidth)
            MaxWidth := W
    }
    DllCall("SelectObject", "Ptr", hDC, "Ptr", hOldFont)
    DllCall("DeleteObject", "Ptr", hFont)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    return MaxWidth + 24
}

UpdatePresetButtonText(Idx) {
    global PresetButtons, PresetData
    Btn := PresetButtons[Idx]

    if !PresetData.Has(Idx) {
        Btn.Text := "未设置 " Idx
        return
    }
    Data := PresetData[Idx]
    displayText := Data.W "x" Data.H " " Data.F "Hz"
    displayKeyName := FormatHotkeyText(Data.HK)
    if (displayKeyName != "")
        displayText .= "`n[" displayKeyName "]"
    Btn.Text := displayText
}

RefreshTrayMenu() {
    global PresetData, AudioTrayMenu, AudioTrayDeviceMap
    A_TrayMenu.Delete()
    AudioTrayMenu.Delete()
    AudioTrayDeviceMap.Clear()

    currentAudioDevice := GetWindowsDefaultPlaybackDeviceInfo()

    A_TrayMenu.Add("显示主窗口", ShowMainWindow)
    A_TrayMenu.Add("音频设备", AudioTrayMenu)
    A_TrayMenu.Default := "显示主窗口"

    AudioTrayMenu.Add("循环切换", TrayCycleAudio)
    AudioTrayMenu.Add()

        audioDevices := GetAvailablePlaybackDevices()

    if (audioDevices.Length > 0) {
        for idx, device in audioDevices {
            menuText := idx ". " device.Name
            AudioTrayDeviceMap[menuText] := device.Id
            AudioTrayMenu.Add(menuText, TraySwitchAudioDevice)
            if (device.Id = currentAudioDevice.Id)
                AudioTrayMenu.Check(menuText)
        }
    } else {
        AudioTrayMenu.Add("未找到可切换的音频设备", (*) => 0)
    }

    addedPreset := false
    Loop 10 {
        idx := A_Index
        if PresetData.Has(idx) {
            data := PresetData[idx]
            menuText := idx ". " data.W "×" data.H " @ " data.F "Hz"
            A_TrayMenu.Add(menuText, TrayExecutePreset)
            addedPreset := true
        }
    }

    if addedPreset
        A_TrayMenu.Add()
    A_TrayMenu.Add("退出程序", ExitFromTray)
}




TrayExecutePreset(ItemName, ItemPos, MyMenu) {
    idxText := Trim(StrSplit(ItemName, ".")[1])
    idx := Integer(idxText)
    ExecutePresetByIdx(idx)
}

TrayCycleAudio(*) {
    AudioCycleLogic()
    RefreshTrayMenu()
}



TraySwitchAudioDevice(ItemName, ItemPos, MyMenu) {
    global AudioTrayDeviceMap
    if !AudioTrayDeviceMap.Has(ItemName)
        return
    if !SetDefaultPlaybackDevice(AudioTrayDeviceMap[ItemName]) {
        ToolTip("音频设备切换失败。")
        SetTimer () => ToolTip(), -3000
        return
    }
    Sleep(40)
    deviceInfo := GetWindowsDefaultPlaybackDeviceInfo()
    ShowAudioOsd(FormatAudioDisplayName(deviceInfo, ItemName))
    RefreshTrayMenu()
}




SaveSettings() {

    global DDL_Count, HK_Audio, CHK_Startup, SettingsFile, PresetData
    EnsureAppDataDir()
    IniWrite(DDL_Count.Text, SettingsFile, "General", "PresetCount")

    IniWrite(HK_Audio.Value, SettingsFile, "General", "AudioHotkey")
    IniWrite(CHK_Startup.Value, SettingsFile, "General", "LaunchAtStartup")
    EnsureStartupShortcut(CHK_Startup.Value = 1)

    Loop 10 {

        idx := A_Index
        section := "Preset" idx
        if PresetData.Has(idx) {
            data := PresetData[idx]
            IniWrite(data.W, SettingsFile, section, "W")
            IniWrite(data.H, SettingsFile, section, "H")
            IniWrite(data.F, SettingsFile, section, "F")
            IniWrite(data.HK, SettingsFile, section, "HK")
        } else {
            IniWrite("", SettingsFile, section, "W")
            IniWrite("", SettingsFile, section, "H")
            IniWrite("", SettingsFile, section, "F")
            IniWrite("", SettingsFile, section, "HK")
        }
    }
}

LoadSettings() {
    global DDL_Count, HK_Audio, CHK_Startup, SettingsFile, PresetData
    EnsureAppDataDir()
    savedCount := Trim(IniRead(SettingsFile, "General", "PresetCount", "2"))



    if (savedCount != "") {
        try DDL_Count.Choose(savedCount)
        catch {
            DDL_Count.Value := 2
        }
    }

    Loop 10 {

        idx := A_Index
        section := "Preset" idx
        w := IniRead(SettingsFile, section, "W", "")
        h := IniRead(SettingsFile, section, "H", "")
        f := IniRead(SettingsFile, section, "F", "")
        hk := IniRead(SettingsFile, section, "HK", "")

        if (w != "" && h != "" && f != "") {
            PresetData[idx] := {W: Integer(w), H: Integer(h), F: Integer(f), HK: hk}
            if (hk != "") {
                ; Bind 在此保存当前 idx 的值。直接使用闭包会引用 Loop 变量，
                ; 循环结束后所有已加载的快捷键都会错误地执行最后一个预设（Preset10）。
                try Hotkey(hk, ExecutePresetByIdx.Bind(idx), "On")
                catch {
                    PresetData[idx].HK := ""
                }
            }
        }
        UpdatePresetButtonText(idx)
    }

        audioKey := IniRead(SettingsFile, "General", "AudioHotkey", "")
    if (audioKey != "") {
        HK_Audio.Value := audioKey
        if !BindAudioHotkey(audioKey, false)
            HK_Audio.Value := ""
    }

    startupEnabled := IniRead(SettingsFile, "General", "LaunchAtStartup", "0")
    CHK_Startup.Value := (startupEnabled = "1") ? 1 : 0
    EnsureStartupShortcut(CHK_Startup.Value = 1)
    RefreshTrayMenu()
}


BindAudioHotkey(Key, showMessages := true) {

    global CurrentAudioHotkey
    if (CurrentAudioHotkey != "" && CurrentAudioHotkey != Key)
        Try Hotkey(CurrentAudioHotkey, "Off")
    Try {
        Hotkey(Key, AudioCycleLogic, "On")
        CurrentAudioHotkey := Key
        return true
    } Catch {
        if showMessages
            MsgBox("该音频热键无效或已被系统级程序强行占用！", "错误", "Iconx")
        return false
    }
}

EnsureStartupShortcut(enabled) {
    global StartupShortcutPath
    EnsureAppDataDir()
    if enabled {

        CreateStartupShortcut()
    } else if FileExist(StartupShortcutPath) {
        FileDelete(StartupShortcutPath)
    }
}

CreateStartupShortcut() {
    global StartupShortcutPath, AppIconPath
    shell := ComObject("WScript.Shell")
    shortcut := shell.CreateShortcut(StartupShortcutPath)

    if A_IsCompiled {
        shortcut.TargetPath := A_ScriptFullPath
        shortcut.Arguments := "--startup"
        shortcut.WorkingDirectory := A_ScriptDir
    } else {
        shortcut.TargetPath := A_AhkPath
        shortcut.Arguments := '"' A_ScriptFullPath '" --startup'
        shortcut.WorkingDirectory := A_ScriptDir
    }

    if FileExist(AppIconPath)
        shortcut.IconLocation := AppIconPath ",0"
    shortcut.WindowStyle := 7
    shortcut.Save()
}

TunePresetVisibility(GuiObj, CurrentWidth := 0) {

    global DDL_Count, PresetButtons

    if (CurrentWidth == 0) {
        GuiObj.GetClientPos(, , &CurrentWidth)
    }
    Count := Integer(DDL_Count.Text)
    StartX := 20
    StartY := 140
    BtnHeight := 46
    ColSpace := 10
    RowSpace := 10
    ColumnCount := 2
    BtnWidth := Floor((CurrentWidth - (StartX * 2) - ColSpace) / ColumnCount)
    if (BtnWidth < 110)
        BtnWidth := 110
    LastBottom := StartY

    For Index, Btn In PresetButtons {
        if (Index <= Count) {
            Btn.Visible := true
            row := Floor((Index - 1) / ColumnCount)
            col := Mod(Index - 1, ColumnCount)
            posX := StartX + col * (BtnWidth + ColSpace)
            posY := StartY + row * (BtnHeight + RowSpace)
            Btn.Move(posX, posY, BtnWidth, BtnHeight)
            LastBottom := posY + BtnHeight
        } else {
            Btn.Visible := false
        }
        }
        return LastBottom + 10

}

ApplyFromUI() {

    global DDL_Res, DDL_Freq
    ResStr := DDL_Res.Text

    if (ResStr == "")
        return
    Freq := Integer(StrSplit(DDL_Freq.Text, " ")[1])
    parts := StrSplit(ResStr, "x")
    ExecuteSwitch(Integer(parts[1]), Integer(parts[2]), Freq)
}

ExecuteSwitch(W, H, F) {
    devMode := Buffer(220, 0)
    NumPut("UShort", 220, devMode, 68)      
    NumPut("UInt", 0x5C0000, devMode, 72)   
    NumPut("UInt", 32, devMode, 168)        
    NumPut("UInt", W, devMode, 172)         
    NumPut("UInt", H, devMode, 176)         
    NumPut("UInt", F, devMode, 184)         
    Result := DllCall("ChangeDisplaySettingsW", "Ptr", devMode, "UInt", 0)
    if (Result == 0) {
        ToolTip("已切换至: " W "x" H " 32Bit " F "Hz")
    } else {
        ToolTip("显示器硬件拒绝该模式，错误码: " Result)
    }
    SetTimer () => ToolTip(), -2000
}

HandlePresetRightClick(GuiCtrl, *) {
    global DDL_Res, DDL_Freq, HK_Res, HK_Audio, PresetData, MyGui
    ResStr := DDL_Res.Text

    if (ResStr == "")
        return
    Idx := GuiCtrl.PresetIdx
    Freq := Integer(StrSplit(DDL_Freq.Text, " ")[1])
    Key := HK_Res.Value 
    if (Key != "") {
        if (Key == HK_Audio.Value) {
            MsgBox("快捷键 [" FormatHotkeyText(Key) "] 已被上面的【音频快捷键】占用！", "热键冲突提示", "Icon!")
            return
        }
        For OtherIdx, Data In PresetData {
            if (OtherIdx != Idx && Data.HK == Key) {
                MsgBox("快捷键 [" FormatHotkeyText(Key) "] 已在【快捷按钮 " OtherIdx "】中设置！", "热键冲突提示", "Icon!")
                return 
            }
        }
    }
    if PresetData.Has(Idx) {
        OldData := PresetData[Idx]
        if (OldData.HK != "") {
            Try Hotkey(OldData.HK, "Off")
        }
    }
    if (Key != "") {
        Try {
            Hotkey(Key, (*) => ExecutePresetByIdx(Idx), "On")
        } Catch {
            MsgBox("快捷键 [" FormatHotkeyText(Key) "] 无效或已被抢行占用！", "热键注册失败", "Iconx")
            Key := "" 
        }
    }
                PresetData[Idx] := {W: Integer(StrSplit(ResStr, "x")[1]), H: Integer(StrSplit(ResStr, "x")[2]), F: Freq, HK: Key}
        UpdatePresetButtonText(Idx)
    RefreshTrayMenu()
    AdjustMainWindowHeight(MyGui)
    SaveSettings()


    ToolTip("预设 " Idx " 配置集成成功！")

    SetTimer () => ToolTip(), -1500
}

HandlePresetClick(GuiCtrl, *) {
    ExecutePresetByIdx(GuiCtrl.PresetIdx)
}

; Hotkey 回调会额外传入热键名称；允许忽略这些参数，
; 以便通过 Bind(idx) 恢复的快捷键可正常调用该函数。
ExecutePresetByIdx(Idx, *) {
    if !PresetData.Has(Idx) {
        ToolTip("该预设按钮还未设置参数！")
        SetTimer () => ToolTip(), -2500
        return
    }
    Data := PresetData[Idx]
    ExecuteSwitch(Data.W, Data.H, Data.F)
}

; =========================================================================
; Windows Core Audio 原生读取默认播放设备信息
; =========================================================================
GetWindowsDefaultPlaybackDeviceInfo() {
    IMMDeviceEnumerator_IID := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    MMDeviceEnumerator_CLSID := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"

    pDevice := 0
    pStore := 0
    try {
        enumerator := ComObject(MMDeviceEnumerator_CLSID, IMMDeviceEnumerator_IID)
        hr := ComCall(4, enumerator, "Int", 0, "Int", 1, "Ptr*", &pDevice := 0)
        if (hr < 0 || !pDevice)
            throw Error("GetDefaultAudioEndpoint failed",, hr)

        deviceId := GetMmDeviceId(pDevice)

        hr := ComCall(4, pDevice, "UInt", 0, "Ptr*", &pStore := 0)
        if (hr < 0 || !pStore)
            throw Error("OpenPropertyStore failed",, hr)

        modelName := GetPropertyStoreString(pStore, "{026e516e-b814-414b-83cd-856d6fef4822}", 2)
        friendlyName := GetPropertyStoreString(pStore, "{a45c254e-df1c-4efd-8020-67d146a850e0}", 14)

        return {
            Id: deviceId,
            ModelName: modelName,
            FriendlyName: friendlyName
        }
    } catch {
        return {
            Id: "",
            ModelName: "",
            FriendlyName: ""
        }
    } finally {
        if (pStore)
            ObjRelease(pStore)
        if (pDevice)
            ObjRelease(pDevice)
    }
}

GetMmDeviceId(pDevice) {
    idPtr := 0
    hr := ComCall(5, pDevice, "Ptr*", &idPtr := 0)
    if (hr < 0 || !idPtr)
        return ""
    try {
        return StrGet(idPtr, "UTF-16")
    } finally {
        DllCall("Ole32\CoTaskMemFree", "Ptr", idPtr)
    }
}

GetAvailablePlaybackDevices() {
    IMMDeviceEnumerator_IID := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    MMDeviceEnumerator_CLSID := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    DEVICE_STATE_ACTIVE := 0x00000001

    devices := []
    pCollection := 0
    pDevice := 0
    try {
        enumerator := ComObject(MMDeviceEnumerator_CLSID, IMMDeviceEnumerator_IID)
        hr := ComCall(3, enumerator, "Int", 0, "UInt", DEVICE_STATE_ACTIVE, "Ptr*", &pCollection := 0)
        if (hr < 0 || !pCollection)
            throw Error("EnumAudioEndpoints failed",, hr)

        count := 0
        hr := ComCall(3, pCollection, "UInt*", &count := 0)
        if (hr < 0)
            throw Error("IMMDeviceCollection.GetCount failed",, hr)

        Loop count {
            hr := ComCall(4, pCollection, "UInt", A_Index - 1, "Ptr*", &pDevice := 0)
            if (hr < 0 || !pDevice)
                continue

            deviceInfo := GetMmDeviceInfo(pDevice)
            if (deviceInfo.Id != "")
                devices.Push(deviceInfo)

            ObjRelease(pDevice)
            pDevice := 0
        }
    } catch {
        return []
    } finally {
        if (pDevice)
            ObjRelease(pDevice)
        if (pCollection)
            ObjRelease(pCollection)
    }
    return devices
}

GetMmDeviceInfo(pDevice) {
    pStore := 0
    try {
        deviceId := GetMmDeviceId(pDevice)
        hr := ComCall(4, pDevice, "UInt", 0, "Ptr*", &pStore := 0)
        if (hr < 0 || !pStore)
            throw Error("OpenPropertyStore failed",, hr)

        modelName := GetPropertyStoreString(pStore, "{026e516e-b814-414b-83cd-856d6fef4822}", 2)
        friendlyName := GetPropertyStoreString(pStore, "{a45c254e-df1c-4efd-8020-67d146a850e0}", 14)
        displayName := FormatAudioDisplayName({ModelName: modelName, FriendlyName: friendlyName})

        return {
            Id: deviceId,
            Name: displayName,
            ModelName: modelName,
            FriendlyName: friendlyName
        }
    } catch {
        return {
            Id: "",
            Name: "",
            ModelName: "",
            FriendlyName: ""
        }
    } finally {
        if (pStore)
            ObjRelease(pStore)
    }
}

GetSelectedPlaybackDevices() {

    configPath := A_AppData "\SoundSwitch\SoundSwitchConfiguration.json"
    if !FileExist(configPath)
        return []

    configText := FileRead(configPath, "UTF-8")
    if !RegExMatch(configText, 's)"SelectedDevices"\s*:\s*\[(.*?)\]\s*,\s*"PlaybackHotKey"', &selectedBlock)
        return []

    devices := []
    pos := 1
    pattern := 's)"Name"\s*:\s*"((?:\\.|[^"])*)"\s*,\s*"Id"\s*:\s*"((?:\\.|[^"])*)".*?"Type"\s*:\s*(\d+)'
    while RegExMatch(selectedBlock[1], pattern, &match, pos) {
        if (Integer(match[3]) == 0) {
            devices.Push({
                Name: JsonUnescape(match[1]),
                Id: JsonUnescape(match[2])
            })
        }
        pos := match.Pos + match.Len
    }
    return devices
}

JsonUnescape(text) {
    text := StrReplace(text, '\\/', '/')
    text := StrReplace(text, '\\"', '"')
    text := StrReplace(text, '\\\\', '\\')
    text := StrReplace(text, '\\b', Chr(8))
    text := StrReplace(text, '\\f', Chr(12))
    text := StrReplace(text, '\\n', '`n')
    text := StrReplace(text, '\\r', '`r')
    text := StrReplace(text, '\\t', '`t')

    pos := 1
    while RegExMatch(text, '\\u([0-9A-Fa-f]{4})', &unicodeMatch, pos) {
        text := SubStr(text, 1, unicodeMatch.Pos - 1) Chr('0x' unicodeMatch[1]) SubStr(text, unicodeMatch.Pos + unicodeMatch.Len)
        pos := unicodeMatch.Pos + 1
    }
    return text
}

SetDefaultPlaybackDevice(deviceId) {
    psPath := EnsureAudioHelperScript()
    if (psPath = "")
        return false

    escapedPsPath := StrReplace(psPath, '"', '""')
    escapedDeviceId := StrReplace(deviceId, '"', '""')
    command := 'powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' escapedPsPath '" -DeviceId "' escapedDeviceId '"'
    try {
        exitCode := RunWait(command, , "Hide")
        return exitCode = 0
    } catch {
        return false
    }
}

EnsureAudioHelperScript() {
    psPath := A_Temp "\DisplayAudioControl_SetDefaultAudioDevice.ps1"
    if FileExist(psPath)
        return psPath

    try {
        FileInstall("SetDefaultAudioDevice.ps1", psPath, 1)
        return FileExist(psPath) ? psPath : ""
    } catch {
        return ""
    }
}











FormatAudioDisplayName(deviceInfo, fallbackName := "") {
    modelName := Trim(deviceInfo.ModelName, "`r`n `t")
    friendlyName := Trim(deviceInfo.FriendlyName, "`r`n `t")
    friendlyNameCompact := StrLower(StrReplace(StrReplace(friendlyName, "（", "("), "）", ")"))
    modelNameCompact := StrLower(modelName)

    if (friendlyName == "" && modelName == "") {
        return fallbackName != "" ? fallbackName : "音频设备已切换"
    }
    if (friendlyName == "")
        return modelName
    if (modelName == "" || friendlyName == modelName)
        return friendlyName
    if InStr(friendlyNameCompact, "(" modelNameCompact ")")
        return friendlyName
    return friendlyName "（" modelName "）"
}

ShowAudioOsd(displayName) {
    global OsdGui, OsdText, CalculateTextWidth

    OsdText.Value := displayName
    textWidth := CalculateTextWidth(OsdText.Value, 13)
    if (textWidth < 220)
        textWidth := 220

    OsdText.Move(36, 8, textWidth, 22)

    winW := textWidth + 48
    winH := 38
    posX := 16
    posY := 16

    OsdGui.Show(Format("x{1} y{2} w{3} h{4} NoActivate", posX, posY, winW, winH))
    SetTimer(() => OsdGui.Hide(), -1500)
}


GetPropertyStoreString(pStore, fmtid, pid) {

    pkey := Buffer(20, 0)
    DllCall("Ole32\CLSIDFromString", "Str", fmtid, "Ptr", pkey)
    NumPut("UInt", pid, pkey, 16)

    propVar := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    try {
        hr := ComCall(5, pStore, "Ptr", pkey, "Ptr", propVar)
        if (hr < 0)
            return ""

        vt := NumGet(propVar, 0, "UShort")
        if (vt != 31)
            return ""

        pwszVal := NumGet(propVar, 8, "Ptr")
        if !pwszVal
            return ""
        return StrGet(pwszVal, "UTF-16")
    } finally {
        DllCall("Ole32\PropVariantClear", "Ptr", propVar)
    }
}






; =========================================================================
; 音频快捷键设定与纯静默无窗口 OSD 渲染核心
; =========================================================================
SetAudioHotkey(*) {
    global HK_Audio, PresetData, CurrentAudioHotkey
    Key := HK_Audio.Value
    if (Key == "") {
        if (CurrentAudioHotkey != "") {
            Try Hotkey(CurrentAudioHotkey, "Off")
            CurrentAudioHotkey := ""
        }
        SaveSettings()
        return
    }
    For Idx, Data In PresetData {
        if (Data.HK == Key) {
            MsgBox("快捷键 [" FormatHotkeyText(Key) "] 已在下方的【快捷按钮 " Idx "】中设置！`n音频热键绑定失败。", "热键冲突提示", "Icon!")
            return
        }
    }
    if BindAudioHotkey(Key) {
        MsgBox("音频秒切热键 [" FormatHotkeyText(Key) "] 动态绑定成功！", "绑定成功", "Iconi")
        SaveSettings()
    }
}



AudioCycleLogic(*) {
        selectedDevices := GetAvailablePlaybackDevices()
    if (selectedDevices.Length < 2) {
        ToolTip("系统中至少需要 2 个启用的播放设备。")

        SetTimer () => ToolTip(), -3000
        return
    }

    currentDevice := GetWindowsDefaultPlaybackDeviceInfo()
    currentIndex := 0
    for index, device in selectedDevices {
        if (device.Id = currentDevice.Id) {
            currentIndex := index
            break
        }
    }

    targetIndex := (currentIndex >= selectedDevices.Length || currentIndex = 0) ? 1 : currentIndex + 1
    targetDevice := selectedDevices[targetIndex]

        if !SetDefaultPlaybackDevice(targetDevice.Id) {
        ToolTip("音频设备切换失败。")

        SetTimer () => ToolTip(), -3000
        return
    }

    Sleep(40)
    deviceInfo := GetWindowsDefaultPlaybackDeviceInfo()
    Loop 2 {
        if (deviceInfo.Id = targetDevice.Id || deviceInfo.Id = "")
            break
        Sleep(40)
        deviceInfo := GetWindowsDefaultPlaybackDeviceInfo()
    }

    ShowAudioOsd(FormatAudioDisplayName(deviceInfo, targetDevice.Name))
    RefreshTrayMenu()
}