#!/usr/bin/env bash
set -e

# ==============================================================================
# Haipee Firebase Test Lab 双模自动化巡检工具 (Instrumentation 精确巡检 + Robo 探索)
# 用法:
#   ./tool/run_firebase_testlab.sh --mode instrumentation   # 推荐：运行确定性 Robot 闭环套件 (捕获所有溢出/空指针/状态异常)
#   ./tool/run_firebase_testlab.sh --mode robo              # 辅助：运行 Robo 随机探索测试
#   ./tool/run_firebase_testlab.sh --mode both              # 全量执行 Instrumentation + Robo
# ==============================================================================

MODE="${TEST_MODE:-instrumentation}"
PROJECT_ID="${FIREBASE_PROJECT_ID:-flutter-e3137}"
TIMEOUT="${TEST_TIMEOUT:-5m}"
GCLOUD_BIN="${GCLOUD_BIN:-/Users/a12/google-cloud-sdk/bin/gcloud}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "======================================================================"
echo "🚀 启动 Haipee Firebase Test Lab 云端真机自动化验证流水线"
echo "   - Mode:       $MODE (instrumentation | robo | both)"
echo "   - Project ID: $PROJECT_ID"
echo "   - Timeout:    $TIMEOUT"
echo "======================================================================"

if ! command -v "$GCLOUD_BIN" &> /dev/null; then
  if command -v gcloud &> /dev/null; then
    GCLOUD_BIN="gcloud"
  else
    echo "❌ 未检测到 gcloud CLI，请确认 Google Cloud SDK 安装路径。"
    exit 1
  fi
fi

FINAL_EXIT_CODE=0

run_instrumentation() {
  echo "🛠️ [Instrumentation 模式] 编译集成测试 APK (integration_test/app_crawler_test.dart)..."
  pushd android > /dev/null
  ./gradlew app:assembleAndroidTest
  ./gradlew app:assembleDebug -Ptarget="$(pwd)/../integration_test/app_crawler_test.dart" -Pdart-defines="RklSRUJBU0VfVEVTVF9MQUI9dHJ1ZQ=="
  popd > /dev/null

  DEBUG_APK=$(find build/app/outputs/apk/debug -name "*.apk" | head -n 1)
  TEST_APK=$(find build/app/outputs/apk/androidTest/debug -name "*.apk" | head -n 1)
  echo "✓ App APK:  $DEBUG_APK"
  echo "✓ Test APK: $TEST_APK"

  echo "📱 提交 Firebase Test Lab Instrumentation 确定性巡检矩阵..."
  set +e
  "$GCLOUD_BIN" firebase test android run \
    --type instrumentation \
    --app "$DEBUG_APK" \
    --test "$TEST_APK" \
    --project "$PROJECT_ID" \
    --device model=panther,version=33,locale=zh_CN,orientation=portrait \
    --timeout "$TIMEOUT" \
    --client-details matrixLabel="Haipee Instrumentation Bug Hunter" \
    --no-record-video 2>&1 | tee test_lab_instrumentation.log
  INST_EXIT=${PIPESTATUS[0]}
  set -e

  if [ "$INST_EXIT" -ne 0 ]; then
    FINAL_EXIT_CODE=$INST_EXIT
  fi
}

run_robo() {
  APK_FILE=$(ls build/app/outputs/flutter-apk/*release*.apk 2>/dev/null | head -n 1 || true)
  if [ -z "$APK_FILE" ]; then
    echo "📦 [Robo 模式] 构建 Release APK..."
    flutter build apk --release \
      --target-platform android-arm64 \
      --android-skip-build-dependency-validation \
      --dart-define=FIREBASE_TEST_LAB=true
    APK_FILE=$(ls build/app/outputs/flutter-apk/*release*.apk 2>/dev/null | head -n 1)
  fi

  ROBO_ARGS=""
  if [ -f "tool/testlab_roboscript.json" ]; then
    ROBO_ARGS="--robo-script tool/testlab_roboscript.json"
  fi

  echo "📱 提交 Firebase Test Lab Robo 探索矩阵..."
  set +e
  "$GCLOUD_BIN" firebase test android run \
    --type robo \
    --app "$APK_FILE" \
    --project "$PROJECT_ID" \
    --device model=panther,version=33,locale=zh_CN,orientation=portrait \
    $ROBO_ARGS \
    --timeout "$TIMEOUT" \
    --client-details matrixLabel="Haipee Robo Exploration" \
    --no-record-video 2>&1 | tee test_lab_local.log
  ROBO_EXIT=${PIPESTATUS[0]}
  set -e

  GCS_PATH=$(grep -oE 'gs://[a-zA-Z0-9_\.\-]+/[^ ]*' test_lab_local.log | head -n 1 || true)
  if [ -n "$GCS_PATH" ]; then
    mkdir -p test_reports/firebase_android
    "$GCLOUD_BIN" storage cp -r "$GCS_PATH/*" test_reports/firebase_android/ 2>/dev/null || true
    find test_reports/firebase_android -mindepth 2 -type f -exec cp -n {} test_reports/firebase_android/ \; 2>/dev/null || true
  fi

  dart tool/analyze_testlab_logs.dart
  if [ "$ROBO_EXIT" -ne 0 ]; then
    FINAL_EXIT_CODE=$ROBO_EXIT
  fi
}

if [[ "$MODE" == "instrumentation" || "$MODE" == "both" ]]; then
  run_instrumentation
fi

if [[ "$MODE" == "robo" || "$MODE" == "both" ]]; then
  run_robo
fi

exit $FINAL_EXIT_CODE
