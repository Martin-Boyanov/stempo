import 'package:health/health.dart';

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
    await _ensureConfigured();

    final isAvailable = await _health.isHealthConnectAvailable();
    if (!isAvailable) {
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
