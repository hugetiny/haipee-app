/// Structured diagnostic explanation for errors and warnings in Haipee.
class DiagnosticInfo {
  final String code;
  final String title;
  final String explanation;
  final String remediation;

  const DiagnosticInfo({
    required this.code,
    required this.title,
    required this.explanation,
    required this.remediation,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'explanation': explanation,
        'remediation': remediation,
      };

  @override
  String toString() => '[$code] $title: $explanation (建议: $remediation)';
}

/// 集中式智能日志丰富器与错误转译管道 (LogEnricher)
/// 
/// 彻底根除 "error 1", "error 5" 等不明所以的原始报错代码，
/// 将所有底层、系统、网络与解码器异常转译为具明确语义、根因解释与可执行动作的结构化诊断信息，
/// 对人类开发者与 AI Coding Agent 均提供最高等级的程序化自省友好度。
class LogEnricher {
  const LogEnricher._();

  /// 对日志消息与错误对象进行结构化深度自省诊断
  static DiagnosticInfo? analyze(dynamic message, [Object? error]) {
    final text = '${message ?? ''} ${error ?? ''}'.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    // 1. 播放器与流媒体解码层
    if (lower.contains('failed to recognize file format')) {
      return const DiagnosticInfo(
        code: 'ERR_MEDIA_UNKNOWN_FORMAT',
        title: '媒体流格式无法识别',
        explanation: '解码器接收到非受支持的数据格式，通常由于源站返回了 HTML 网页而非流媒体直链。',
        remediation: '检查视频规则是否配置了 useWebview 嗅探，或尝试切换播放源/线路。',
      );
    }
    if (lower.contains('[player] has been disposed')) {
      return const DiagnosticInfo(
        code: 'ERR_PLAYER_DISPOSED',
        title: '播放器生命周期已销毁',
        explanation: '在异步起播尚未完成前触发了切集或退出，旧播放器已被安全回收。',
        remediation: '由 PlayerController 生命周期代数守卫自动过滤，无需额外处理。',
      );
    }
    if (lower.contains('property not found _setproperty(osc')) {
      return const DiagnosticInfo(
        code: 'INFO_MPV_OSC_COMPAT',
        title: 'MPV 桌面内置控件属性兼容',
        explanation: '平台层 media_kit 初始化时的桌面属性自动降级，不影响实际视频渲染。',
        remediation: '底层内部平台协商，属正常兼容信息。',
      );
    }
    if (lower.contains('failed to open') || lower.contains('nothing to play')) {
      return const DiagnosticInfo(
        code: 'ERR_STREAM_OPEN_FAILED',
        title: '流媒体连接打开失败',
        explanation: '无法与视频源服务器建立有效的媒体传输链路（链接失效或网络不通）。',
        remediation: '建议切换备用线路或更换视频源规则。',
      );
    }

    // 2. 进程与系统底层退出代码 (Exit Code 1, Error 5 等)
    if (RegExp(r'\b(exit\s*code\s*1|error\s*1|code\s*1|error:\s*1)\b', caseSensitive: false).hasMatch(lower) ||
        lower == '1') {
      return const DiagnosticInfo(
        code: 'ERR_SUBPROCESS_EXIT_1',
        title: '通用执行失败或异常退出 (Code 1)',
        explanation: '外部工具、进程或第三方脚本返回通用错误代码 1。',
        remediation: '检查执行参数、系统依赖完整性与网络联通性，建议切换线路或重试。',
      );
    }
    if (RegExp(r'\b(exit\s*code\s*2|error\s*2|code\s*2)\b', caseSensitive: false).hasMatch(lower)) {
      return const DiagnosticInfo(
        code: 'ERR_SYNTAX_OR_NOT_FOUND',
        title: '命令语法错误或参数未找到 (Code 2)',
        explanation: '子进程接收了无效的调用参数或未定位到指定的文件路径。',
        remediation: '检查调用参数或目标文件是否存在。',
      );
    }
    if (RegExp(r'\b(exit\s*code\s*5|error\s*5|code\s*5|errno\s*=\s*5)\b', caseSensitive: false).hasMatch(lower)) {
      return const DiagnosticInfo(
        code: 'ERR_IO_FAILURE_EIO',
        title: '底层 I/O 读写硬件错误 (Code 5, EIO)',
        explanation: '文件读写被强制中断、磁盘空间不足或存储设备发生 I/O 错误。',
        remediation: '检查磁盘剩余空间与写入权限，清理临时缓存。',
      );
    }
    if (RegExp(r'\b(errno\s*=\s*13|code\s*13|permission\s*denied)\b', caseSensitive: false).hasMatch(lower)) {
      return const DiagnosticInfo(
        code: 'ERR_PERMISSION_DENIED',
        title: '文件系统权限受限 (Code 13, EACCES)',
        explanation: '应用对目标文件或目录无读写权限（常见于沙箱书签失效）。',
        remediation: '进入设置重新授权下载或缓存目录。',
      );
    }
    if (lower.contains('connection refused') || lower.contains('errno = 61') || lower.contains('errno = 111')) {
      return const DiagnosticInfo(
        code: 'ERR_CONNECTION_REFUSED',
        title: '本地守护进程连接拒绝 (ECONNREFUSED)',
        explanation: '应用尝试直连后台下载引擎（如 TorrServer/Gopeed），但服务尚未就绪或端口冲突。',
        remediation: '后台服务正在自动重试拉起，如持续报错请检查端口占用。',
      );
    }

    // 3. HTTP / 网络接口状态码
    if (lower.contains('403') || (lower.contains('bad response') && lower.contains('403'))) {
      return const DiagnosticInfo(
        code: 'HTTP_403_FORBIDDEN',
        title: '接口防盗链或访问被拒 (HTTP 403 Forbidden)',
        explanation: '目标源站触发了防盗链校验、IP 频率限制或 Cloudflare 防护。',
        remediation: '检查规则的 Referer/User-Agent 配置，或开启网络代理。',
      );
    }
    if (lower.contains('404')) {
      return const DiagnosticInfo(
        code: 'HTTP_404_NOT_FOUND',
        title: '请求资源不存在 (HTTP 404 Not Found)',
        explanation: '远端接口地址或视频分片链接已失效或下架。',
        remediation: '检查订阅链接或换用最新有效的规则源。',
      );
    }
    if (lower.contains('401')) {
      return const DiagnosticInfo(
        code: 'HTTP_401_UNAUTHORIZED',
        title: '接口未授权认证失败 (HTTP 401 Unauthorized)',
        explanation: '接口需要用户身份凭证（如 Bilibili Cookie 或 WebDAV 账号密码）。',
        remediation: '在对应设置中重新登录账号或更新认证信息。',
      );
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('521')) {
      return const DiagnosticInfo(
        code: 'HTTP_5XX_SERVER_ERROR',
        title: '第三方源站服务异常 (HTTP 5xx)',
        explanation: '目标源站服务器崩溃、过载或宕机。',
        remediation: '源站服务器故障，建议切换其他视频源。',
      );
    }
    if (lower.contains('connection timeout') || lower.contains('receive timeout')) {
      return const DiagnosticInfo(
        code: 'ERR_NETWORK_TIMEOUT',
        title: '网络连接超时',
        explanation: '源站网络响应延迟过长，连接被客户端自动超时终止。',
        remediation: '检查本地网络或开启代理加速访问。',
      );
    }

    // 4. WebView 嗅探与前端脚本
    if (lower.contains('webview alert 拦截') || lower.contains('sniffer js alert suppressed')) {
      return const DiagnosticInfo(
        code: 'INFO_WEBVIEW_ALERT_INTERCEPTED',
        title: '已自动静默拦截网页弹窗脚本',
        explanation: '目标网页脚本尝试弹出 alert 对话框，已由 WebView 安全沙箱自动屏蔽。',
        remediation: '无需操作，后台自动静默放行。',
      );
    }
    if (lower.contains('嗅探超时') || lower.contains('解析视频资源超时')) {
      return const DiagnosticInfo(
        code: 'WARN_WEBVIEW_SNIFF_TIMEOUT',
        title: '网页视频流嗅探超时 (30s)',
        explanation: '目标网页在 30 秒内未触发直链视频加载或媒体请求。',
        remediation: '建议切换其他播放列表线路或更换视频源。',
      );
    }

    return null;
  }

  /// 清洗晦涩非结构化数字错误代码
  static String sanitizeMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '操作完成';
    final lower = trimmed.toLowerCase();
    if (lower == '1' || lower == 'error 1' || lower == 'error: 1' || lower == 'exception: 1') {
      return '发生通用异常错误 (代码: 1)，建议切换播放线路或视频规则';
    }
    if (lower == '5' || lower == 'error 5' || lower == 'error: 5') {
      return '底层文件读写发生异常 (代码: 5, EIO)，请检查磁盘空间或切换线路';
    }
    if (lower == 'null' || lower == 'undefined' || lower == '[object object]') {
      return '发生未知异常，请稍后重试';
    }
    return raw;
  }
}
