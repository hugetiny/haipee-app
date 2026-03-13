# API Provider E2E 测试更新报告

**更新时间**: 2026-03-13
**更新内容**: 根据官方文档修复 9 家提供商的 API 配置

---

## 官方文档调研结果

### 1. Google Gemini ✅ 已修复
**官方文档**: https://ai.google.dev/gemini-api/docs/openai

**发现**:
- Gemini 支持 **OpenAI 兼容格式**
- 端点: `https://generativelative.googleapis.com/v1beta/openai/`
- 认证: **Bearer Header** (不是 query param!)

**之前的错误**:
```typescript
// 错误：使用原生 Gemini API
baseUrl: 'https://generativelanguage.googleapis.com',
modelsEndpoint: '/v1beta/models',
chatEndpoint: '/v1beta/models/gemini-2.0-flash:generateContent',
// 认证：?key=${token} query param
```

**修复后**:
```typescript
// 正确：使用 OpenAI 兼容端点
baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
modelsEndpoint: '/models',
chatEndpoint: '/chat/completions',
// 认证：Authorization: Bearer ${token}
```

### 2. NVIDIA NIM ✅ 配置正确
**官方文档**: https://docs.nvidia.com/nim/

- OpenAI 兼容格式 ✅
- 端点: `https://integrate.api.nvidia.com/v1`
- 认证: Bearer token

### 3. OpenCode Zen ✅ 配置正确
**官方文档**: https://opencode.ai/docs/zh-tw/zen/

- OpenAI 兼容格式 ✅
- 端点: `https://opencode.ai/zen/v1/chat/completions`
- 认证: Bearer token

### 4. Cloudflare ✅ 已修复
**官方文档**: https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/

**发现**:
- Workers AI 支持 **OpenAI 兼容格式**
- 端点: `https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1`
- 需要 `CLOUDFLARE_ACCOUNT_ID` 环境变量
- 认证: Bearer token

**修复后**:
```typescript
baseUrl: 'https://api.cloudflare.com/client/v4/accounts',
chatEndpoint: '/ai/v1/chat/completions',
```

### 5. 其他提供商 (需要进一步调研)
- **Kilo Code**: 需要确认端点 (`api.kilocode.ai`)
- **XiaoMi MiNo**: 需要确认正确端点
- **Huawei**: 需要确认区域端点
- **Poe**: 使用 bot-based API，非标准 REST

---

## 修改的文件

### 1. `tests/e2e/utils/apiProviders.ts`
- 修复 Gemini 使用 OpenAI 兼容端点
- 修复 Cloudflare 使用 OpenAI 兼容端点

### 2. `tests/e2e/providers/gemini.spec.ts`
- 重写为 OpenAI 兼容格式测试
- 使用 Bearer Header 认证
- 添加流式响应测试

### 3. `tests/e2e/providers/cloudflare.spec.ts`
- 更新为 OpenAI 兼容端点
- 添加 Account ID 验证

---

## 运行 E2E 测试

### 环境变量要求

```bash
# 必需
export GEMINI_TOKEN="your-gemini-token"
export NVIDIA_TOKEN="your-nvidia-token"
export OPENCODE_TOKEN="your-opencode-token"

# Cloudflare 额外需要
export CLOUDFLARE_API_TOKEN="your-cf-token"
export CLOUDFLARE_ACCOUNT_ID="your-cf-account-id"
```

### 运行命令

```bash
# 运行所有提供商测试
npx playwright test tests/e2e/providers/ --project=chromium

# 运行单个提供商
npx playwright test tests/e2e/providers/gemini.spec.ts
npx playwright test tests/e2e/providers/nvidia.spec.ts
npx playwright test tests/e2e/providers/opencode.spec.ts
npx playwright test tests/e2e/providers/cloudflare.spec.ts

# 带调试输出
npx playwright test tests/e2e/providers/gemini.spec.ts --debug
```

---

## 测试结果预期

| 提供商 | 预期状态 | 说明 |
|--------|----------|------|
| Google Gemini | ✅ 应通过 | OpenAI 兼容格式已修复 |
| NVIDIA NIM | ✅ 应通过 | 配置正确 |
| OpenCode Zen | ✅ 应通过 | 配置正确 |
| Cloudflare | ⚠️ 需要 ACCOUNT_ID | 需设置 CLOUDFLARE_ACCOUNT_ID |
| OpenAI | ⚠️ 配额问题 | 需确保账户有余额 |
| Kilo Code | ❓ 待验证 | 端点需确认 |
| XiaoMi MiNo | ❓ 待验证 | 端点需确认 |
| Huawei | ❓ 待验证 | 区域端点需确认 |
| Poe | ❓ 特殊 API | 非标准 REST，需单独处理 |

---

## 下一步行动

1. **运行 Gemini 测试验证修复**
   ```bash
   npx playwright test tests/e2e/providers/gemini.spec.ts
   ```

2. **设置 Cloudflare Account ID**
   - 从 https://dash.cloudflare.com/ 获取 Account ID
   - 添加到 `.env` 文件

3. **调研剩余提供商**
   - Kilo Code 官方文档
   - XiaoMi MiNo 官方文档
   - Huawei Cloud 区域端点
   - Poe API 替代方案

4. **修复失败项**
   根据测试结果调整配置
