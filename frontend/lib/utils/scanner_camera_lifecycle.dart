import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Owns camera transitions for scanners with an explicit controller.
/// MobileScanner only observes app lifecycle for its internal controller.
class ScannerCameraLifecycle with WidgetsBindingObserver {
  ScannerCameraLifecycle(this.controller, {this.onPause, this.onStarted})
    : _foreground =
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed {
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_controllerChanged);
  }

  final MobileScannerController controller;
  final VoidCallback? onPause;
  final VoidCallback? onStarted;
  Future<void> _pending = Future<void>.value();
  bool _foreground;
  bool _requested = false;
  bool _suspended = false;
  bool _disposed = false;
  Completer<void>? _startingComplete;

  bool get canDetect => !_disposed && _foreground && !_suspended;

  Future<void> start() {
    if (_disposed) return _pending;
    _requested = true;
    _suspended = false;
    return _schedule();
  }

  Future<void> suspend() {
    if (_disposed) return _pending;
    _suspended = true;
    onPause?.call();
    return _schedule();
  }

  /// Resume an existing permitted session without requesting a new camera.
  Future<void> resume() {
    if (_disposed) return _pending;
    _suspended = false;
    if (!controller.value.hasCameraPermission) return _pending;
    return _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) onPause?.call();
    // Permission dialogs can interrupt the initial start. Its completion
    // reconciles the latest foreground state instead of racing another start.
    if (!controller.value.hasCameraPermission) return;
    unawaited(_schedule());
  }

  void _controllerChanged() {
    // Support an injected controller whose autoStart is still enabled.
    if (controller.value.isRunning) _requested = true;
    if (!controller.value.isStarting && _startingComplete != null) {
      _startingComplete!.complete();
      _startingComplete = null;
    }
  }

  Future<void> _schedule() {
    return _pending = _pending
        .then((_) async {
          if (_disposed || !_requested) return;
          if (controller.value.isStarting) {
            await (_startingComplete ??= Completer<void>()).future;
            if (_disposed) return;
          }
          if (_foreground && !_suspended) {
            if (!controller.value.isRunning) {
              await controller.start();
              if (!_disposed && controller.value.isRunning) onStarted?.call();
            }
            // The app can leave the foreground while permission/start is pending.
            if ((_disposed || !_foreground || _suspended) &&
                controller.value.isRunning) {
              await controller.stop();
            }
          } else if (controller.value.isRunning) {
            await controller.stop();
          }
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('Camera lifecycle transition failed: $error');
        });
  }

  Future<void> dispose() {
    if (_disposed) return _pending;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // Dispose after any native start/stop already in progress has completed.
    return _pending = _pending
        .then((_) async {
          controller.removeListener(_controllerChanged);
          await controller.dispose();
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('Camera disposal failed: $error');
        });
  }
}
