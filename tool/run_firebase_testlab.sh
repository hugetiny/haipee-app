#!/usr/bin/env bash
set -e

# ==============================================================================
# Haipee Firebase Test Lab 自动化巡检与确定性日志分析全链路执行工具
# ==============================================================================

PROJECT_ID="${FIREBASE_PROJECT_ID:-flutter-e3137}"
TIMEOUT="${TEST_TIMEOUT:-3m}"
GCLOUD_BIN="${GCLOUD_BIN:-/Users/a12/google-cloud-sdk/bin/gcloud}"

echo "======================================================================"
echo "🚀 启动 Haipee Firebase Test Lab 自动化巡检与闭环分析流水线"
echo "   - Project ID: $PROJECT_ID"
echo "   - Timeout:    $TIMEOUT"
echo "   - gcloud:     $GCLOUD_BIN"
echo "======================================================================"

# 1. 检查 gcloud 工具链
if ! command -v "$GCLOUD_BIN" &> /dev/null; then
  if command -v gcloud &> /dev/null; then
    GCLOUD_BIN="gcloud"
  else
    echo "❌ 未检测到 gcloud CLI，请确认 Google Cloud SDK 安装路径。"
    exit 1
  fi
fi

# 2. 定位或构建 Release APK
APK_FILE=$(ls build/app/outputs/flutter-apk/*.apk 2>/dev/null | head -n 1 || true)
if [ -z "$APK_FILE" ]; then
  echo "📦 未检测到已编译 APK，开始本地轻量构建 (Release APK)..."
  flutter build apk --release \
    --target-platform android-arm64 \
    --android-skip-build-dependency-validation \
    --dart-define=FIREBASE_TEST_LAB=true
  APK_FILE=$(ls build/app/outputs/flutter-apk/*.apk 2>/dev/null | head -n 1)
fi

echo "✓ 目标测试 APK: $APK_FILE"

# 3. 准备 Robo 脚本参数
ROBO_ARGS=""
if [ -f "tool/testlab_roboscript.json" ]; then
  ROBO_ARGS="--robo-script tool/testlab_roboscript.json"
  echo "✓ 已加载全覆盖 Robo 巡检导航脚本: tool/testlab_roboscript.json"
fi

# 4. 执行云端真机自动化巡检
echo "📱 提交 Google Cloud Firebase Test Lab 云端真机矩阵..."
"$GCLOUD_BIN" firebase test android run \
  --type robo \
  --app "$APK_FILE" \
  --project "$PROJECT_ID" \
  --device model=panther,version=33,locale=zh_CN,orientation=portrait \
  $ROBO_ARGS \
  --timeout "$TIMEOUT" \
  --client-details matrixLabel="Haipee Local CLI Test" \
  --no-record-video 2>&1 | tee test_lab_local.log

TEST_EXIT_CODE=${PIPESTATUS[0]}
echo "Test Lab 云端执行完成，Exit Code: $TEST_EXIT_CODE"

# 5. 自动下载云端制品到本地 test_reports
GCS_PATH=$(grep -oE 'gs://[a-zA-Z0-9_\.\-]+/[^ ]*' test_lab_local.log | head -n 1 || true)
if [ -n "$GCS_PATH" ]; then
  mkdir -p test_reports/firebase_android
  echo "📥 正在从 GCS 下载测试制品与原始日志: $GCS_PATH ..."
  "$GCLOUD_BIN" storage cp -r "$GCS_PATH/*" test_reports/firebase_android/ 2>/dev/null || true
  # 同步设备子目录文件到根目录，保持平铺与子目录双重兼容
  find test_reports/firebase_android -mindepth 2 -type f -exec cp -n {} test_reports/firebase_android/ \; 2>/dev/null || true
fi

# 6. 本地执行全量确定性日志解析
echo "🔬 执行本地全量确定性日志分析..."
dart tool/analyze_testlab_logs.dart

exit $TEST_EXIT_CODE
