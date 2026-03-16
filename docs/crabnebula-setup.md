# CrabNebula Cloud Setup Guide

## Prerequisites

1. CrabNebula Cloud account with `haipee` project created at https://web.crabnebula.cloud/haipee/haipee
2. API key: `cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ`

## GitHub Secret Configuration

### Method 1: GitHub CLI (Recommended)

```bash
gh secret set CRABNEBULA_API_KEY --body "cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ" --repo hugetiny/haipee-app
```

### Method 2: GitHub Web Interface

1. Go to: https://github.com/hugetiny/haipee-app/settings/secrets/actions
2. Click "New repository secret"
3. Name: `CRABNEBULA_API_KEY`
4. Value: `cn_kdVPgOAr-vWn7oc4oD82rlNMF3QOifrlMKtYC1qxB4bAJVozfeQ4GrL7uTQ17vzaLykavB-seQ1i7FNbXou0DQ`
5. Click "Add secret"

## Usage

### Manual Build Trigger

1. Go to Actions tab: https://github.com/hugetiny/haipee-app/actions
2. Select "CrabNebula Cloud Build"
3. Click "Run workflow"
4. Optional: Enter a tag (e.g., `v3.12.1`)

### Automatic Builds

- Pushes to `main` or `hapiai` branches: Build artifacts
- Tag push (`v*`): Build + Release + Update server publish

## Update Endpoints

The app checks these endpoints in order:

1. **GitHub Releases:** `https://github.com/hugetiny/haipee-app/releases/latest/download/latest.json`
2. **CrabNebula Cloud:** `https://cdn.crabnebula.app/update/haipee/haipee/latest.json`

## Cloud Features Enabled

### Code Signing

- **macOS**: Apple Developer certificate signing via CrabNebula Cloud
- **Windows**: Code signing certificate via CrabNebula Cloud
- No local certificates needed

### Multi-Platform Builds

The workflow builds for:
- macOS (Apple Silicon + Intel)
- Linux (x64, ARM64)
- Windows (x64)

## Troubleshooting

### Build fails with "Unauthorized"

- Verify `CRABNEBULA_API_KEY` secret is set correctly
- Check the API key is valid at https://web.crabnebula.cloud/haipee/haipee/settings

### Updates not working

- Check `latest.json` is uploaded to the release
- Verify the updater pubkey in `tauri.conf.json` matches your signing key
- Check app logs for update check errors
- Ensure the app can reach both update endpoints

### Missing artifacts in release

- Check the build job completed successfully
- Verify artifact upload step in workflow logs
- Check artifact retention period (default 90 days)
