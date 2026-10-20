enum PluginHealthStatus {
  idle,
  testing,
  passed,
  failed,
}

class PluginHealthRecord {
  final PluginHealthStatus status;
  final int? latencyMs;
  final String? error;
  final DateTime testedAt;

  const PluginHealthRecord({
    required this.status,
    this.latencyMs,
    this.error,
    required this.testedAt,
  });
}

// 记录规则有效性与健康状态
// 跟踪规则搜索可用性、连通性耗时 (ms) 及异常信息
class PluginValidityTracker {
  final Map<String, PluginHealthRecord> _healthRecords = {};
  final Set<String> _searchValidPlugins = {};

  void markTesting(String pluginName) {
    _healthRecords[pluginName] = PluginHealthRecord(
      status: PluginHealthStatus.testing,
      testedAt: DateTime.now(),
    );
  }

  void markValid(String pluginName, {int? latencyMs}) {
    _searchValidPlugins.add(pluginName);
    _healthRecords[pluginName] = PluginHealthRecord(
      status: PluginHealthStatus.passed,
      latencyMs: latencyMs,
      testedAt: DateTime.now(),
    );
  }

  void markInvalid(String pluginName, {String? error, int? latencyMs}) {
    _searchValidPlugins.remove(pluginName);
    _healthRecords[pluginName] = PluginHealthRecord(
      status: PluginHealthStatus.failed,
      latencyMs: latencyMs,
      error: error,
      testedAt: DateTime.now(),
    );
  }

  PluginHealthRecord? getRecord(String pluginName) => _healthRecords[pluginName];

  PluginHealthStatus getStatus(String pluginName) {
    return _healthRecords[pluginName]?.status ?? PluginHealthStatus.idle;
  }

  int? getLatency(String pluginName) => _healthRecords[pluginName]?.latencyMs;

  String? getError(String pluginName) => _healthRecords[pluginName]?.error;

  // 兼容旧接口：标记规则搜索有效
  void markSearchValid(String pluginName) {
    markValid(pluginName);
  }

  // 兼容旧接口：检查规则搜索是否有效
  bool isSearchValid(String pluginName) {
    return _searchValidPlugins.contains(pluginName) ||
        _healthRecords[pluginName]?.status == PluginHealthStatus.passed;
  }

  void clear() {
    _healthRecords.clear();
    _searchValidPlugins.clear();
  }
}

