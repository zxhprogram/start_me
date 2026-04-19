package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"runtime"
	"sync"
	"sync/atomic"
	"syscall"
	"unsafe"
)

var (
	user32                  = syscall.NewLazyDLL("user32.dll")
	kernel32                = syscall.NewLazyDLL("kernel32.dll")
	procSetWindowsHookExW   = user32.NewProc("SetWindowsHookExW")
	procCallNextHookEx      = user32.NewProc("CallNextHookEx")
	procUnhookWindowsHookEx = user32.NewProc("UnhookWindowsHookEx")
	procGetMessageW         = user32.NewProc("GetMessageW")
	procPostThreadMessageW  = user32.NewProc("PostThreadMessageW")
	procGetCurrentThreadId  = kernel32.NewProc("GetCurrentThreadId")
	procGetModuleHandleW    = kernel32.NewProc("GetModuleHandleW")
)

const (
	WH_KEYBOARD_LL = 13
	WM_KEYDOWN     = 0x0100
	WM_SYSKEYDOWN  = 0x0104
	WM_QUIT        = 0x0012
)

type KBDLLHOOKSTRUCT struct {
	VkCode      uint32
	ScanCode    uint32
	Flags       uint32
	Time        uint32
	DwExtraInfo uintptr
}

type MSG struct {
	HWnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      struct{ X, Y int32 }
}

var (
	keyCounts    sync.Map
	hookHandle   uintptr
	pumpThreadID uint32
	running      atomic.Bool
	lastJSON     *C.char
)

var vkNames = map[uint32]string{
	0x08: "Backspace", 0x09: "Tab", 0x0D: "Enter", 0x10: "Shift",
	0x11: "Ctrl", 0x12: "Alt", 0x14: "CapsLock", 0x1B: "Esc",
	0x20: "Space", 0x21: "PageUp", 0x22: "PageDown", 0x23: "End",
	0x24: "Home", 0x25: "Left", 0x26: "Up", 0x27: "Right", 0x28: "Down",
	0x2C: "PrintScreen", 0x2D: "Insert", 0x2E: "Delete",
	0x5B: "Win", 0x5C: "Win",
	0xA0: "LShift", 0xA1: "RShift", 0xA2: "LCtrl", 0xA3: "RCtrl",
	0xA4: "LAlt", 0xA5: "RAlt",
	0xBA: ";", 0xBB: "=", 0xBC: ",", 0xBD: "-", 0xBE: ".", 0xBF: "/", 0xC0: "`",
	0xDB: "[", 0xDC: "\\", 0xDD: "]", 0xDE: "'",
	0x70: "F1", 0x71: "F2", 0x72: "F3", 0x73: "F4",
	0x74: "F5", 0x75: "F6", 0x76: "F7", 0x77: "F8",
	0x78: "F9", 0x79: "F10", 0x7A: "F11", 0x7B: "F12",
	0x90: "NumLock", 0x91: "ScrollLock",
	0x60: "Num0", 0x61: "Num1", 0x62: "Num2", 0x63: "Num3",
	0x64: "Num4", 0x65: "Num5", 0x66: "Num6", 0x67: "Num7",
	0x68: "Num8", 0x69: "Num9",
	0x6A: "Num*", 0x6B: "Num+", 0x6D: "Num-", 0x6E: "Num.", 0x6F: "Num/",
}

func getKeyName(vk uint32) string {
	if name, ok := vkNames[vk]; ok {
		return name
	}
	if vk >= 0x30 && vk <= 0x39 {
		return string(rune(vk))
	}
	if vk >= 0x41 && vk <= 0x5A {
		return string(rune(vk))
	}
	return ""
}

func hookProc(nCode int32, wParam uintptr, lParam uintptr) uintptr {
	if nCode >= 0 && (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
		kb := (*KBDLLHOOKSTRUCT)(unsafe.Pointer(lParam))
		name := getKeyName(kb.VkCode)
		if name != "" {
			val, _ := keyCounts.LoadOrStore(name, new(int64))
			atomic.AddInt64(val.(*int64), 1)
		}
	}
	ret, _, _ := procCallNextHookEx.Call(0, uintptr(nCode), wParam, lParam)
	return ret
}

//export StartHook
func StartHook() C.int {
	if running.Load() {
		return 0
	}

	started := make(chan C.int, 1)

	go func() {
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()

		tid, _, _ := procGetCurrentThreadId.Call()
		pumpThreadID = uint32(tid)

		hMod, _, _ := procGetModuleHandleW.Call(0)

		cb := syscall.NewCallback(hookProc)
		h, _, err := procSetWindowsHookExW.Call(
			WH_KEYBOARD_LL,
			cb,
			hMod,
			0,
		)
		if h == 0 {
			_ = err
			started <- -1
			return
		}

		hookHandle = h
		running.Store(true)
		started <- 0

		var msg MSG
		for {
			ret, _, _ := procGetMessageW.Call(
				uintptr(unsafe.Pointer(&msg)),
				0, 0, 0,
			)
			if int32(ret) <= 0 {
				break
			}
		}

		procUnhookWindowsHookEx.Call(hookHandle)
		hookHandle = 0
		running.Store(false)
	}()

	return <-started
}

//export StopHook
func StopHook() {
	if !running.Load() {
		return
	}
	procPostThreadMessageW.Call(
		uintptr(pumpThreadID),
		WM_QUIT,
		0, 0,
	)
}

//export GetKeyCounts
func GetKeyCounts() *C.char {
	m := make(map[string]int64)
	keyCounts.Range(func(key, value interface{}) bool {
		m[key.(string)] = atomic.LoadInt64(value.(*int64))
		return true
	})
	data, _ := json.Marshal(m)
	if lastJSON != nil {
		C.free(unsafe.Pointer(lastJSON))
	}
	lastJSON = C.CString(string(data))
	return lastJSON
}

//export ResetCounts
func ResetCounts() {
	keyCounts.Range(func(key, value interface{}) bool {
		keyCounts.Delete(key)
		return true
	})
}

func main() {}
