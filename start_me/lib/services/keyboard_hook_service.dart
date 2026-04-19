import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef StartHookNative = Int32 Function();
typedef StartHookDart = int Function();

typedef StopHookNative = Void Function();
typedef StopHookDart = void Function();

typedef GetKeyCountsNative = Pointer<Utf8> Function();
typedef GetKeyCountsDart = Pointer<Utf8> Function();

typedef ResetCountsNative = Void Function();
typedef ResetCountsDart = void Function();

class KeyboardHookService {
  static DynamicLibrary? _lib;
  static StartHookDart? _startHook;
  static StopHookDart? _stopHook;
  static GetKeyCountsDart? _getKeyCounts;
  static ResetCountsDart? _resetCounts;

  static bool loadDll() {
    if (_lib != null) return true;
    try {
      _lib = DynamicLibrary.open('assets/dll/keyboard_hook.dll');
      _startHook = _lib!.lookupFunction<StartHookNative, StartHookDart>('StartHook');
      _stopHook = _lib!.lookupFunction<StopHookNative, StopHookDart>('StopHook');
      _getKeyCounts = _lib!.lookupFunction<GetKeyCountsNative, GetKeyCountsDart>('GetKeyCounts');
      _resetCounts = _lib!.lookupFunction<ResetCountsNative, ResetCountsDart>('ResetCounts');
      return true;
    } catch (_) {
      return false;
    }
  }

  static int startHook() {
    if (_startHook == null) return -1;
    return _startHook!();
  }

  static void stopHook() {
    _stopHook?.call();
  }

  static Map<String, int> getKeyCounts() {
    if (_getKeyCounts == null) return {};
    final ptr = _getKeyCounts!();
    if (ptr == nullptr) return {};
    final jsonStr = ptr.toDartString();
    if (jsonStr.isEmpty) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static void resetCounts() {
    _resetCounts?.call();
  }
}
