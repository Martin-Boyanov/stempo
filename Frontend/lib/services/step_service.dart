import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class StepService {
  StepService({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _isConfigured = false;

  static const List<HealthDataType> _types = [HealthDataType.STEPS];
  static const List<HealthDataAccess> _permissions = [HealthDataAccess.READ];

  Future<void> _ensureConfigured() async {
    if (_isConfigured) return;
    await _health.configure();
    _isConfigured = true;
  }

  Future<bool> requestPermissions() async {
    // 1. Request Activity Recognition (Physical Activity popup)
    final activityStatus = await Permission.activityRecognition.request();
    if (!activityStatus.isGranted) {
      return false;
    }

    // 2. Request Health Connect / Health data
    await _ensureConfigured();

    final isAvailable = await _health.isHealthConnectAvailable();
    if (!isAvailable) {
      // If Health Connect is not available, we can't proceed with health data
      // but activity recognition might be enough for some? 
      // User said "move it to after the health connect", suggesting they want both.
      return false;
    }

    final hasPermissions = await _health.hasPermissions(
      _types,
      permissions: _permissions,
    );
    
    if (hasPermissions == true) {
      return true;
    }

    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  Future<int> getTodaySteps() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final totalSteps = await _health.getTotalStepsInInterval(startOfDay, now);
    return totalSteps ?? 0;
  }
}
