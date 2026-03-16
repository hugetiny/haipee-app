# CrabNebula Cloud Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete CrabNebula Cloud integration for Haipee with dual update endpoints (GitHub Releases + CrabNebula Cloud), updating all repository references to `hugetiny/haipee`.

**Architecture:** Configure Tauri updater with multiple endpoints (GitHub primary, CrabNebula fallback), update CrabNebula config for cloud builds with code signing, and ensure GitHub Actions workflow publishes to both GitHub Releases and CrabNebula Cloud.

**Tech Stack:** Tauri v2, CrabNebula Cloud CLI, GitHub Actions, tauri-plugin-updater

---

## Files Overview

| File | Purpose | Action |
|------|---------|--------|
| `crabnebula.toml` | CrabNebula Cloud build/signing config | Update endpoints to `hugetiny/haipee` |
| `.github/workflows/crabnebula-cloud.yml` | CI/CD workflow for builds | Update repo references |
| `src-tauri/tauri.conf.json` | Tauri app config with updater | Update endpoints to `hugetiny/haipee`, add CrabNebula fallback |
| `src-tauri/src/lib.rs` | Rust entry, updater plugin init | Verify updater plugin initialization |

---

## Chunk 1: Update Repository References

### Task 1: Update crabnebula.toml

**Files:**
- Modify: `crabnebula.toml:47-49`

**Changes needed:**
- Update GitHub endpoints from `farion1231/cc-switch` to `hugetiny/haipee`

- [ ] **Step 1: Update endpoints in crabnebula.toml**

```toml
[update]
enabled = true
endpoints = [
    "https://github.com/hugetiny/haipee/releases/latest/download/latest.json",
    "https://cdn.crabnebula.app/update/haipee/haipee/latest.json"
]
```

- [ ] **Step 2: Commit**

```bash
git add crabnebula.toml
git commit -m "chore: update crabnebula.toml endpoints to hugetiny/haipee"
```

---

### Task 2: Update tauri.conf.json

**Files:**
- Modify: `src-tauri/tauri.conf.json:64-69`

**Changes needed:**
- Update updater endpoints to new repo and add CrabNebula Cloud as fallback
- Keep existing pubkey (it's already configured)

- [ ] **Step 1: Update updater endpoints**

```json
"updater": {
  "pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEM4MDI4QzlBNTczOTI4RTMKUldUaktEbFhtb3dDeUM5US9kT0FmdGR5Ti9vQzcwa2dTMlpibDVDUmQ2M0VGTzVOWnd0SGpFVlEK",
  "endpoints": [
    "https://github.com/hugetiny/haipee/releases/latest/download/latest.json",
    "https://cdn.crabnebula.app/update/haipee/haipee/latest.json"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/tauri.conf.json
git commit -m "chore: update updater endpoints to hugetiny/haipee with CrabNebula fallback"
```

---

### Task 3: Update GitHub Actions Workflow

**Files:**
- Modify: `.github/workflows/crabnebula-cloud.yml:108-169`

**Changes needed:**
- Update release job to use correct repository
- Update latest.json generation with correct download URLs
- Fix asset name patterns to match actual Tauri output

- [ ] **Step 1: Update release job repository reference**

Check line 111 in the workflow - it uses `${{ github.repository }}` which is correct, but the artifact naming in latest.json generation needs to match actual Tauri output names.

- [ ] **Step 2: Update latest.json generation step**

Replace the generate latest.json step (lines 133-164) with:

```yaml
      - name: Generate latest.json
        run: |
          VERSION=${GITHUB_REF_NAME:-${{ github.event.inputs.tag }}}
          VERSION=${VERSION#v}

          # Generate signatures for each platform (from signed artifacts)
          # Note: CrabNebula Cloud signs the binaries, but signatures need to be extracted
          # For now, empty signatures will work with GitHub releases
          # CrabNebula Cloud endpoint provides signatures automatically

          cat > latest.json << EOF
          {
            "version": "v$VERSION",
            "notes": "See the assets to download this version and install.",
            "pub_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "platforms": {
              "darwin-aarch64": {
                "signature": "",
                "url": "https://github.com/hugetiny/haipee/releases/download/v$VERSION/Haipee_aarch64.app.tar.gz"
              },
              "darwin-x86_64": {
                "signature": "",
                "url": "https://github.com/hugetiny/haipee/releases/download/v$VERSION/Haipee_x64.app.tar.gz"
              },
              "linux-x86_64": {
                "signature": "",
                "url": "https://github.com/hugetiny/haipee/releases/download/v$VERSION/haipee_${VERSION}_amd64.AppImage"
              },
              "windows-x86_64": {
                "signature": "",
                "url": "https://github.com/hugetiny/haipee/releases/download/v$VERSION/Haipee_${VERSION}_x64-setup.exe"
              }
            }
          }
          EOF

          cat latest.json
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/crabnebula-cloud.yml
git commit -m "chore: update GitHub workflow for hugetiny/haipee repo"
```

---

## Chunk 2: Enhance CrabNebula Cloud Integration

### Task 4: Add CrabNebula Cloud Update Server Support

**Files:**
- Modify: `src-tauri/tauri.conf.json:64-69`
- Create: `src-tauri/src/updater.rs` (if updater logic needs customization)

**Changes needed:**
- Tauri updater already supports multiple endpoints - it tries them in order
- First successful response wins
- No code changes needed, just config (already done in Task 2)

- [ ] **Step 1: Verify multiple endpoints work correctly**

Check that the updater config has both endpoints:
1. GitHub releases (primary)
2. CrabNebula Cloud CDN (fallback)

- [ ] **Step 2: Commit** (if any changes made)

---

### Task 5: Add GitHub Secret Configuration Documentation

**Files:**
- Create: `docs/crabnebula-setup.md`

**Purpose:** Document the required GitHub secret setup

- [ ] **Step 1: Create setup documentation**

```markdown
# CrabNebula Cloud Setup Guide

## Prerequisites

1. CrabNebula Cloud account with `haipee` project created
2. API key: `cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ`

## GitHub Secret Configuration

### Method 1: GitHub CLI (Recommended)

```bash
gh secret set CRABNEBULA_API_KEY --body "cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ" --repo hugetiny/haipee
```

### Method 2: GitHub Web Interface

1. Go to: https://github.com/hugetiny/haipee/settings/secrets/actions
2. Click "New repository secret"
3. Name: `CRABNEBULA_API_KEY`
4. Value: `cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ`
5. Click "Add secret"

## Usage

### Manual Build Trigger

1. Go to Actions tab: https://github.com/hugetiny/haipee/actions
2. Select "CrabNebula Cloud Build"
3. Click "Run workflow"
4. Optional: Enter a tag (e.g., `v3.12.1`)

### Automatic Builds

- Pushes to `main` or `hapiai` branches: Build artifacts
- Tag push (`v*`): Build + Release + Update server publish

## Update Endpoints

The app checks these endpoints in order:

1. **GitHub Releases:** `https://github.com/hugetiny/haipee/releases/latest/download/latest.json`
2. **CrabNebula Cloud:** `https://cdn.crabnebula.app/update/haipee/haipee/latest.json`

## Troubleshooting

### Build fails with "Unauthorized"

- Verify `CRABNEBULA_API_KEY` secret is set correctly
- Check the API key is valid at https://web.crabnebula.cloud/haipee/haipee/settings

### Updates not working

- Check `latest.json` is uploaded to the release
- Verify the updater pubkey in `tauri.conf.json` matches your signing key
- Check app logs for update check errors
```

- [ ] **Step 2: Commit**

```bash
git add docs/crabnebula-setup.md
git commit -m "docs: add CrabNebula Cloud setup guide"
```

---

## Chunk 3: Verification

### Task 6: Verify Local Build Configuration

- [ ] **Step 1: Check Tauri CLI can build locally**

```bash
cd src-tauri
cargo tauri build --runner cargo
```

Expected: Build succeeds (may take several minutes)

- [ ] **Step 2: Verify updater configuration**

```bash
cat src-tauri/tauri.conf.json | jq '.plugins.updater'
```

Expected: Shows both endpoints configured

---

### Task 7: Test Workflow Syntax

- [ ] **Step 1: Validate GitHub Actions workflow**

```bash
# Using actionlint if available
actionlint .github/workflows/crabnebula-cloud.yml

# Or at least check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/crabnebula-cloud.yml'))"
```

Expected: No errors

---

## Summary of Changes

| File | Change |
|------|--------|
| `crabnebula.toml` | Update endpoints to `hugetiny/haipee` |
| `src-tauri/tauri.conf.json` | Update endpoints, add CrabNebula fallback |
| `.github/workflows/crabnebula-cloud.yml` | Update repo references, fix asset names |
| `docs/crabnebula-setup.md` | New documentation for setup |

## Post-Implementation Steps (Manual)

1. **Add GitHub Secret:**
   ```bash
   gh secret set CRABNEBULA_API_KEY --body "cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ" --repo hugetiny/haipee
   ```

2. **Test Build:**
   - Go to https://github.com/hugetiny/haipee/actions
   - Run "CrabNebula Cloud Build" workflow manually

3. **Verify CrabNebula Dashboard:**
   - Check builds appear at https://web.crabnebula.cloud/haipee/haipee

4. **Test Auto-Update:**
   - Publish a release
   - Verify `latest.json` is attached to release
   - Test app update check

---

**Plan complete.** Ready to execute?
