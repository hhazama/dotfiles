#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  app-switch.ahk — キーボードでアプリを一発呼び出し
;    Alt+1 Terminal / Alt+2 Slack / Alt+3 Chrome / Alt+4 Obsidian
;    押下   → 最前面化。別の仮想デスクトップに在っても、そのデスクトップへ
;             移動した上でフォーカスする
;    連打   → 現デスクトップ上に同じアプリが複数あればウィンドウを巡回
;    未起動 → 起動
;    Alt+0  → 上記4アプリを並び順で順送り巡回
; ============================================================

; --- 設定 ---------------------------------------------------------
; フォーカス先ウィンドウの中央へマウスカーソルを飛ばすなら true
global WARP_MOUSE := false

; 並び順 = Alt+1..4。exe はウィンドウ判定、launch は未起動時の起動コマンド。
global APPS := [
    { exe: "WindowsTerminal.exe", launch: "wt.exe" },
    { exe: "slack.exe",           launch: EnvGet("LOCALAPPDATA") "\slack\slack.exe" },
    { exe: "chrome.exe",          launch: "C:\Program Files\Google\Chrome\Application\chrome.exe" },
    { exe: "Obsidian.exe",        launch: EnvGet("LOCALAPPDATA") "\Programs\obsidian\Obsidian.exe" },
]

; --- 仮想デスクトップ操作(VirtualDesktopAccessor.dll。スクリプトと同じ場所に置く) ---
global DLL := DllCall("LoadLibrary", "Str", A_ScriptDir "\VirtualDesktopAccessor.dll", "Ptr")
global pGetCurrentDesktopNumber := DLL ? DllCall("GetProcAddress", "Ptr", DLL, "AStr", "GetCurrentDesktopNumber", "Ptr") : 0
global pGetWindowDesktopNumber  := DLL ? DllCall("GetProcAddress", "Ptr", DLL, "AStr", "GetWindowDesktopNumber", "Ptr") : 0
global pGoToDesktopNumber       := DLL ? DllCall("GetProcAddress", "Ptr", DLL, "AStr", "GoToDesktopNumber", "Ptr") : 0
global VDA := (pGetCurrentDesktopNumber && pGetWindowDesktopNumber && pGoToDesktopNumber)

; --- ホットキー ---------------------------------------------------
!1::Summon(1)
!2::Summon(2)
!3::Summon(3)
!4::Summon(4)
!0::RoundRobin()

; --- 実装 ---------------------------------------------------------
Summon(index) {
    app := APPS[index]

    ; 1) 現デスクトップのウィンドウ(既定検出) → フォーカス、複数なら巡回
    windows := WinGetList("ahk_exe " app.exe)
    if (windows.Length > 0) {
        if (ActiveExe() = app.exe) {
            if (windows.Length > 1)
                Activate(windows[windows.Length])  ; 最背面を前へ = 連打で全ウィンドウを一巡
        } else {
            Activate(windows[1])                   ; Zオーダー最上位 = 直近ウィンドウ
        }
        return
    }

    ; 2) 別デスクトップのウィンドウを探し、そのデスクトップへ移動してフォーカス
    found := FindOnOtherDesktop(app.exe)
    if (found) {
        DllCall(pGoToDesktopNumber, "Int", found.desktop, "Int")
        Sleep(120)  ; デスクトップ切替アニメーションと競合しないよう待つ
        Activate(found.hwnd)
        return
    }

    ; 3) どこにも無ければ起動
    Launch(app)
}

; 全デスクトップから、実デスクトップ上にある本物のウィンドウを1つ返す({hwnd, desktop} or 0)。
; 隠しウィンドウ検出を一時ONにしないと、別デスクトップのウィンドウは列挙されない。
; Electron 等の隠しヘルパ窓は GetWindowDesktopNumber が -1 を返すので除外される。
FindOnOtherDesktop(exe) {
    if !VDA
        return 0
    cur := DllCall(pGetCurrentDesktopNumber, "Int")
    result := 0
    DetectHiddenWindows(true)
    for hwnd in WinGetList("ahk_exe " exe) {
        d := DllCall(pGetWindowDesktopNumber, "Ptr", hwnd, "Int")
        if (d >= 0 && d != cur) {
            result := { hwnd: hwnd, desktop: d }
            break
        }
    }
    DetectHiddenWindows(false)
    return result
}

RoundRobin() {
    active := ActiveExe()
    current := 0
    for i, app in APPS {
        if (app.exe = active) {
            current := i
            break
        }
    }
    Summon(Mod(current, APPS.Length) + 1)
}

ActiveExe() {
    try
        return WinGetProcessName("A")
    catch
        return ""
}

Activate(hwnd) {
    id := "ahk_id " hwnd
    if (WinGetMinMax(id) = -1)
        WinRestore(id)
    WinActivate(id)
    if !WinWaitActive(id, , 0.3) {
        ; Windows のフォアグラウンド固定に阻まれたときのフォールバック
        WinMinimize(id)
        WinRestore(id)
        WinActivate(id)
    }
    WarpMouse(hwnd)
}

WarpMouse(hwnd) {
    if !WARP_MOUSE
        return
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    CoordMode("Mouse", "Screen")
    MouseMove(x + w // 2, y + h // 2, 0)
}

Launch(app) {
    try
        Run(app.launch)
    catch
        TrayTip("起動できませんでした: " app.exe "`nlaunch パスを確認してください", "app-switch")
}
