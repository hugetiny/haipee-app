# API Providers E2E Configuration

**Updated**: 2026-03-13
**Status**: All 9 providers configured with official documentation references

---

## Provider Overview

| # | Provider | Status | OpenAI Compatible | Authentication |
|---|----------|--------|-------------------|----------------|
| 1 | **NVIDIA NIM** | ✅ Ready | Yes | Bearer Token |
| 2 | **OpenAI** | ✅ Ready | Yes (Reference) | Bearer Token |
| 3 | **Google Gemini** | ✅ Ready | Yes | Bearer Token |
| 4 | **OpenCode Zen** | ✅ Ready | Yes | Bearer Token |
| 5 | **Kilo Code** | ✅ Ready | Yes | Bearer Token |
| 6 | **XiaoMi MiNo** | ⚠️ Limited Info | Expected | Bearer Token |
| 7 | **Huawei** | ⚠️ Limited Info | Expected | Bearer Token |
| 8 | **Cloudflare** | ✅ Ready | Yes | Bearer Token + Account ID |
| 9 | **Poe** | ✅ Ready | Yes | Bearer Token |

---

## Detailed Configuration

### 1. NVIDIA NIM ✅

**Documentation**: https://docs.nvidia.com/nim/

```typescript
baseUrl: 'https://integrate.api.nvidia.com'
modelsEndpoint: '/v1/models'
chatEndpoint: '/v1/chat/completions'
testModel: 'meta/llama-3.1-8b-instruct'
auth: Bearer Token
```

**Test File**: `tests/e2e/providers/nvidia.spec.ts`

---

### 2. OpenAI ✅

**Documentation**: https://platform.openai.com/docs

```typescript
baseUrl: 'https://api.openai.com'
modelsEndpoint: '/v1/models'
chatEndpoint: '/v1/chat/completions'
testModel: 'gpt-4o-mini'
auth: Bearer Token
```

**Test File**: `tests/e2e/providers/openai.spec.ts`

---

### 3. Google Gemini ✅

**Documentation**: https://ai.google.dev/gemini-api/docs/openai

**Key Finding**: Gemini supports OpenAI-compatible endpoint!

```typescript
baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai'
modelsEndpoint: '/models'
chatEndpoint: '/chat/completions'
testModel: 'gemini-2.0-flash'
auth: Bearer Token (in header, not query param)
```

**Important**: Use OpenAI-compatible endpoint with Bearer header, NOT the native Gemini API.

**Test File**: `tests/e2e/providers/gemini.spec.ts`

---

### 4. OpenCode Zen ✅

**Documentation**: https://opencode.ai/docs/zh-tw/zen/

```typescript
baseUrl: 'https://opencode.ai'
modelsEndpoint: '' // No models list endpoint
chatEndpoint: '/zen/v1/chat/completions'
testModel: 'minimax-m2.5-free'
auth: Bearer Token
```

**Test File**: `tests/e2e/providers/opencode.spec.ts`

---

### 5. Kilo Code ✅

**Documentation**: https://kilo.ai/docs

```typescript
baseUrl: 'https://api.kilocode.ai/v1'
modelsEndpoint: '/models'
chatEndpoint: '/chat/completions'
testModel: 'gpt-4o-mini'
auth: Bearer Token
```

**Test File**: `tests/e2e/providers/kilo.spec.ts`

---

### 6. XiaoMi MiNo ⚠️

**Note**: Limited public documentation available.

```typescript
baseUrl: 'https://api.minos.ai/v1'
modelsEndpoint: '/models'
chatEndpoint: '/chat/completions'
testModel: 'mino-default'
auth: Bearer Token
```

**Status**: Configuration based on best effort research. May require updates.

**Test File**: `tests/e2e/providers/xiaomimino.spec.ts`

---

### 7. Huawei ⚠️

**Documentation**: https://support.huaweicloud.com/pangulm/

```typescript
baseUrl: 'https://pangu.huaweicloud.com/v1'
modelsEndpoint: '/models'
chatEndpoint: '/chat/completions'
testModel: 'pangu-llm'
auth: Bearer Token
```

**Note**: May require regional endpoint configuration.

**Test File**: `tests/e2e/providers/huawei.spec.ts`

---

### 8. Cloudflare ✅

**Documentation**: https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/

```typescript
baseUrl: 'https://api.cloudflare.com/client/v4/accounts'
modelsEndpoint: '' // No models endpoint
chatEndpoint: '/ai/v1/chat/completions'
testModel: '@cf/meta/llama-3.1-8b-instruct'
auth: Bearer Token + Account ID
```

**Required Environment Variable**: `CLOUDFLARE_ACCOUNT_ID`

**Test File**: `tests/e2e/providers/cloudflare.spec.ts`

---

### 9. Poe ✅

**Documentation**: https://creator.poe.com/docs/external-applications/openai-compatible-api

**Get API Key**: https://poe.com/api/keys

```typescript
baseUrl: 'https://api.poe.com/v1'
modelsEndpoint: '/models'
chatEndpoint: '/chat/completions'
testModel: 'Claude-Sonnet-4'
auth: Bearer Token
```

**Test File**: `tests/e2e/providers/poe.spec.ts`

---

## Environment Variables

Create `.env` file in project root:

```bash
# Required for all providers
export NVIDIA_TOKEN="nvapi-..."
export OPENAI_TOKEN="sk-..."
export GEMINI_TOKEN="AIzaSy..."
export OPENCODE_TOKEN="oc-..."
export KILO_TOKEN="kilo-..."
export XIAOMIMINO_TOKEN="mino-..."
export HUAWEI_TOKEN="hw-..."
export CLOUDFLARE_API_TOKEN="cf-..."
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
export POE_TOKEN="poe-..."
```

---

## Running Tests

### Test Single Provider

```bash
npx playwright test tests/e2e/providers/gemini.spec.ts
npx playwright test tests/e2e/providers/nvidia.spec.ts
npx playwright test tests/e2e/providers/poe.spec.ts
```

### Test All Providers

```bash
npx playwright test tests/e2e/providers/ --project=chromium
```

### Generate Report

```bash
npx playwright test --reporter=html
```

---

## Test Results Summary

### Expected Behavior

| Provider | Expected Result | Notes |
|----------|----------------|-------|
| Google Gemini | ✅ Pass | OpenAI-compatible endpoint confirmed |
| NVIDIA NIM | ✅ Pass | Standard OpenAI format |
| OpenCode Zen | ✅ Pass | Verified working endpoint |
| Cloudflare | ⚠️ Conditional | Requires ACCOUNT_ID |
| Poe | ✅ Pass | OpenAI-compatible confirmed |
| OpenAI | ⚠️ Quota | May fail due to insufficient quota |
| Kilo Code | ❓ Unknown | Endpoint to be verified |
| XiaoMi MiNo | ❓ Unknown | Limited documentation |
| Huawei | ❓ Unknown | Regional endpoint may be needed |

---

## Troubleshooting

### 429 Rate Limited

All tests handle 429 gracefully with `test.skip()`.

### 401 Unauthorized

Check token is correctly set in environment variables:

```bash
echo $GEMINI_TOKEN  # Should output your token
```

### Connection Timeout

Some providers may have geographic restrictions. Check:
- Network connectivity
- VPN requirements
- Regional endpoint configuration

### Missing Account ID (Cloudflare)

Get your Account ID from: https://dash.cloudflare.com/

Look in the right sidebar of any domain overview page.

---

## File Structure

```
tests/e2e/
├── utils/
│   └── apiProviders.ts          # Provider configurations
├── providers/
│   ├── nvidia.spec.ts           # NVIDIA NIM tests
│   ├── openai.spec.ts           # OpenAI tests
│   ├── gemini.spec.ts           # Google Gemini tests
│   ├── opencode.spec.ts         # OpenCode Zen tests
│   ├── kilo.spec.ts             # Kilo Code tests
│   ├── xiaomimino.spec.ts       # XiaoMi MiNo tests
│   ├── huawei.spec.ts           # Huawei tests
│   ├── cloudflare.spec.ts       # Cloudflare tests
│   └── poe.spec.ts              # Poe tests
├── summary.spec.ts              # Summary report
└── README.md                    # This file
```

---

## Updates

### 2026-03-13

- ✅ Fixed Gemini to use OpenAI-compatible endpoint
- ✅ Fixed Cloudflare to use OpenAI-compatible endpoint
- ✅ Updated Poe with official endpoint documentation
- ✅ Updated Kilo Code with official endpoint
- ⚠️ XiaoMi MiNo and Huawei have limited documentation
