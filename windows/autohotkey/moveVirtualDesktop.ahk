#Requires AutoHotkey v2.0
#SingleInstance Force
DllPath := A_ScriptDir . "\VirtualDesktopAccessor.dll"

hModule := DllCall("LoadLibrary", "Str", DllPath, "Ptr")


; 関数ポインタの取得
MoveWindowToDesktopProc := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "MoveWindowToDesktopNumber", "Ptr")
GetCurrentDesktopProc   := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "GetCurrentDesktopNumber", "Ptr")
GoToDesktopNumberProc   := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "GoToDesktopNumber", "Ptr")


GoToDesktopNumber(num) {
    global GoToDesktopNumberProc
    DllCall(GoToDesktopNumberProc, "Int", num, "Int")
    return
}

; アクティブウィンドウを取得する関数
GetForegroundWindow() {
    return DllCall("GetForegroundWindow", "Ptr")
}


MoveWindowToDesktop(num) {
    global MoveWindowToDesktopProc
    hwnd := GetForegroundWindow()  ; 現在のアクティブウィンドウを取得
    if (hwnd) {
        DllCall(MoveWindowToDesktopProc, "Ptr", hwnd, "Int", num, "Int")
    }
    return
}


; ウィンドウを隣のデスクトップへ移動させ、自分も移動する関数
MoveAndFollow(direction) {
    global MoveWindowToDesktopProc, GetCurrentDesktopProc, GoToDesktopNumberProc
    
    current := DllCall(GetCurrentDesktopProc, "Int")
    target := current + direction
    
    ; デスクトップ番号が0未満にならないように制限（右側はOS側で無視されるため簡易化）
    if (target < 0)
        return

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if (hwnd) {
        ; 1. ウィンドウを移動
        DllCall(MoveWindowToDesktopProc, "Ptr", hwnd, "Int", target, "Int")
        ; 2. 自分もそのデスクトップへ移動（これが無いとウィンドウだけ消える）
        DllCall(GoToDesktopNumberProc, "Int", target, "Int")
    }
}

; Win + 1～4 で仮想デスクトップに移動
#1::GoToDesktopNumber(0)
#2::GoToDesktopNumber(1)
#3::GoToDesktopNumber(2)
#4::GoToDesktopNumber(3)

; Shift + Win + 1～4 でアクティブウィンドウを仮想デスクトップに移動
#+1::MoveWindowToDesktop(0)
#+2::MoveWindowToDesktop(1)
#+3::MoveWindowToDesktop(2)
#+4::MoveWindowToDesktop(3)



; [Win] + [Ctrl] + [Shift] + [←]
^+#Left::MoveAndFollow(-1)

; [Win] + [Ctrl] + [Shift] + [→]
^+#Right::MoveAndFollow(1)