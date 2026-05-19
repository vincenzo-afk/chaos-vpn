import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/logger.dart';

/// Handles microphone and notification permission requests,
/// including battery optimization exemption.
class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

  /// Check if microphone permission is granted.
  Future<bool> hasMicPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Request microphone permission.
  Future<bool> requestMicPermission() async {
    try {
      final status = await Permission.microphone.request();
      final granted = status.isGranted;
      AppLogger.info('Mic permission status: $status');
      return granted;
    } catch (e) {
      AppLogger.error('Failed to request mic permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted (Android 13+).
  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true; // iOS doesn't need this
    return await Permission.notification.isGranted;
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.notification.request();
      final granted = status.isGranted;
      AppLogger.info('Notification permission status: $status');
      return granted;
    } catch (e) {
      AppLogger.error('Failed to request notification permission: $e');
      return false;
    }
  }

  /// Request all required permissions.
  Future<bool> requestAll() async {
    final mic = await requestMicPermission();
    final notif = await requestNotificationPermission();
    return mic && notif;
  }

  /// Request battery optimization exemption using FlutterForegroundTask.
  /// Affected OEMs: Samsung (One UI), Xiaomi/MIUI, OPPO/ColorOS,
  /// Huawei (EMUI), OnePlus (OxygenOS).
  Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      final isIgnoring =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        AppLogger.info('[Permissions] Battery optimization exemption requested');
      }
    } catch (e) {
      AppLogger.error('Failed to request battery optimization exemption: $e');
    }
  }

  /// Check if battery optimization is already disabled.
  Future<bool> isBatteryOptimizationExempted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return false;
    }
  }

  /// Open the app settings page (for when user permanently denied).
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
