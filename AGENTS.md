# Automation Agents Documentation

This document explains the automated system that keeps your T2 kernel cache up-to-date.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Workflows](#workflows)
- [Configuration](#configuration)
- [CI/CD Pipeline](#cicd-pipeline)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)

## Overview

This repository uses GitHub Actions to automatically:
1. ✅ Check for nixos-hardware updates every 2 hours
2. ✅ Build T2 kernels when updates are found
3. ✅ Cache built kernels on Cachix
4. ✅ Create Pull Requests for review

**No manual intervention required!** The system is fully autonomous.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                      │
│                                                                   │
│  ┌────────────────┐         ┌──────────────────┐                │
│  │ Check Updates  │         │  Build & Cache   │                │
│  │  (Every 2hrs)  │────────▶│    (On update)   │                │
│  └────────────────┘         └──────────────────┘                │
│         │                            │                           │
│         │                            │                           │
│         ▼                            ▼                           │
│  Check nixos-hardware         Build both kernels                │
│  commit hash                  - linux-t2-stable                 │
│         │                     - linux-t2-latest                 │
│         │                            │                           │
│         ▼                            ▼                           │
│  Different hash?              Push to Cachix                    │
│         │                            │                           │
│    ┌────┴────┐                      │                           │
│    │         │                      │                           │
│   Yes       No                      │                           │
│    │         │                      │                           │
│    ▼         ▼                      ▼                           │
│  Create PR  Exit            ✅ Cached & Ready                   │
│    │                                                             │
│    └─────────────────────────────────────────────────────────┐ │
│                                                                │ │
└────────────────────────────────────────────────────────────────┘
                                                                 │
                                                                 ▼
                                                        ┌─────────────────┐
                                                        │  Your NixOS Mac │
                                                        │                 │
                                                        │  Downloads from │
                                                        │     Cachix      │
                                                        └─────────────────┘
```

## Workflows

### 1. Check for T2 Updates

**File:** `.github/workflows/check-updates.yml`

**Schedule:** Every 2 hours (0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22 UTC)

**Purpose:** Monitors nixos-hardware for changes and triggers builds when needed.

**Process:**
```yaml
1. Checkout repository
2. Install Nix with flakes enabled
3. Get current nixos-hardware commit hash
4. Run: nix flake lock --update-input nixos-hardware
5. Get new nixos-hardware commit hash
6. Compare hashes:
   - If same: Revert flake.lock, exit cleanly
   - If different: Continue to step 7
7. Extract kernel versions for PR description
8. Create Pull Request with updated flake.lock
9. Trigger build-and-cache workflow
```

**Outputs:**
- `has-updates`: Boolean indicating if updates were found
- Creates PR if updates exist
- Automatically triggers build workflow

**CI Time:** ~2 minutes per check (when no updates)

### 2. Build and Cache T2 Kernels

**File:** `.github/workflows/build-and-cache.yml`

**Triggers:**
- Push to main/master (when flake.nix, flake.lock, or workflows change)
- Pull requests
- Called by check-updates workflow
- Manual dispatch

**Purpose:** Builds both T2 kernel variants and pushes to Cachix.

**Process:**
```yaml
Job 1: build-kernels (Matrix: [linux-t2-stable, linux-t2-latest])
  1. Checkout repository
  2. Install Nix
  3. Run: nix flake update
  4. Setup Cachix with auth token
  5. Show kernel version info
  6. Build kernel package: nix build .#${kernel}-kernel
  7. Build full package set: nix build .#${kernel}
  8. Verify: nix flake check

Job 2: build-all (Runs after job 1 completes)
  1. Checkout repository
  2. Install Nix
  3. Run: nix flake update
  4. Setup Cachix
  5. Build all: nix build .#all
  6. Display summary with kernel versions
```

**CI Time:** ~150-180 minutes per build (both kernels)

**Cachix Integration:**
- Automatically pushes all build outputs
- Filters out source tarballs and nixpkgs archives
- Uses authenticated upload with your token

## Configuration

### GitHub Secrets

Required secrets in your repository settings:

```
CACHIX_CACHE_NAME
  Description: Your Cachix cache name (e.g., "my-t2-kernels")
  Location: Settings → Secrets and variables → Actions

CACHIX_AUTH_TOKEN
  Description: Cachix authentication token
  Location: Settings → Secrets and variables → Actions
  Get from: https://app.cachix.org → Your cache → Settings → Auth Tokens
```

### Flake Inputs

The system tracks these inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };
}
```

**Update behavior:**
- `nixpkgs`: Updated on every build via `nix flake update`
- `nixos-hardware`: Checked every 2 hours, only updated if changed

### Workflow Permissions

```yaml
permissions:
  contents: write        # To push flake.lock changes
  pull-requests: write   # To create PRs
```

## CI/CD Pipeline

### Monthly CI Usage Estimate

**Free Tier Limit:** 2,000 minutes/month

**Expected Usage:**

| Activity | Frequency | Time per Run | Monthly Total |
|----------|-----------|--------------|---------------|
| Update checks | 12/day | 2 min | ~720 min |
| Kernel builds | ~4/month | 150 min | ~600 min |
| **Total** | | | **~1,320 min** |

**Remaining:** ~680 minutes for other projects

### Build Optimization

The workflow uses several optimizations:

1. **Matrix Builds**: Builds both kernels in parallel
   ```yaml
   strategy:
     matrix:
       kernel: [linux-t2-stable, linux-t2-latest]
     fail-fast: false
   ```

2. **Cachix Caching**: Automatic deduplication
   - If kernel hash unchanged → no upload
   - If kernel already cached → instant download

3. **Smart Checking**: Only builds when updates exist
   - Compares commit hashes
   - Reverts check if no changes
   - ~0 CI minutes wasted

4. **Flake Updates**: Gets latest dependencies
   ```bash
   nix flake update  # Updates nixpkgs and nixos-hardware
   ```

## Customization

### Change Check Frequency

Edit `.github/workflows/check-updates.yml`:

```yaml
# Current: Every 2 hours
schedule:
  - cron: '0 */2 * * *'

# Options:
# Every hour:     - cron: '0 * * * *'
# Every 4 hours:  - cron: '0 */4 * * *'
# Every 6 hours:  - cron: '0 */6 * * *'
# Once daily:     - cron: '0 3 * * *'
# Twice daily:    - cron: '0 3,15 * * *'
```

**CI Impact:**

| Schedule | Checks/Month | CI Minutes | Within Free Tier? |
|----------|--------------|------------|-------------------|
| Every hour | 720 | ~1,440 + builds | ⚠️ Borderline |
| Every 2 hours | 360 | ~720 + builds | ✅ Yes |
| Every 4 hours | 180 | ~360 + builds | ✅ Yes |
| Every 6 hours | 120 | ~240 + builds | ✅ Yes |
| Daily | 30 | ~60 + builds | ✅ Yes |

### Build Only One Kernel

To save CI time and Cachix storage, you can build only one variant.

Edit `.github/workflows/build-and-cache.yml`:

```yaml
# Original:
strategy:
  matrix:
    kernel: [linux-t2-stable, linux-t2-latest]

# Build only latest:
strategy:
  matrix:
    kernel: [linux-t2-latest]

# Build only stable:
strategy:
  matrix:
    kernel: [linux-t2-stable]
```

**Savings:** ~75 minutes per build

### Disable Auto-PR Creation

If you prefer manual review before flake.lock updates:

Edit `.github/workflows/check-updates.yml`:

```yaml
# Comment out or remove the "Create Pull Request" step:
# - name: Create Pull Request
#   if: steps.check.outputs.has-updates == 'true'
#   uses: peter-evans/create-pull-request@v6
#   ...

# And the trigger-build job:
# trigger-build:
#   needs: check-updates
#   ...
```

Then manually run the build workflow when ready.

### Pin to Specific nixos-hardware Version

If you want stability over latest updates:

Edit `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pin to specific commit:
    nixos-hardware.url = "github:NixOS/nixos-hardware/COMMIT_HASH";

    # Or pin to specific tag/branch:
    nixos-hardware.url = "github:NixOS/nixos-hardware/release-24.11";
  };
}
```

Then disable the check-updates workflow.

## Troubleshooting

### Workflow Not Running

**Symptom:** Scheduled workflow doesn't execute

**Causes & Solutions:**

1. **Repository inactive**
   - GitHub disables workflows on inactive repos (60 days)
   - Solution: Push a commit or manually trigger workflow

2. **Workflow disabled**
   - Check: Actions tab → Workflows → Check for T2 Updates
   - Solution: Enable the workflow

3. **Branch mismatch**
   - Workflows only run on default branch
   - Check: Settings → Branches → Default branch
   - Solution: Merge to default branch

### Build Failures

**Symptom:** Build workflow fails

**Common Causes:**

1. **Nix evaluation error**
   ```
   Error: flake.nix evaluation failed
   ```
   - Check: Is flake.nix valid? Run `nix flake check` locally
   - Solution: Fix syntax errors

2. **Kernel build failure**
   ```
   Error: builder for 'linux-t2-stable' failed
   ```
   - Check: Is nixos-hardware update broken?
   - Solution: Pin to previous working commit, report upstream

3. **Cachix authentication**
   ```
   Error: Cachix authentication failed
   ```
   - Check: Is CACHIX_AUTH_TOKEN set correctly?
   - Solution: Regenerate token, update secret

4. **CI timeout**
   ```
   Error: Job exceeded maximum time limit
   ```
   - Cause: Kernel build taking >6 hours
   - Solution: GitHub Actions has 6hr limit, this is rare but can happen

### Update Checks Not Creating PRs

**Symptom:** Updates exist but no PR created

**Debug Steps:**

1. Check workflow logs:
   - Actions tab → Check for T2 Updates → Latest run
   - Look at "Check for nixos-hardware updates" step

2. Verify permissions:
   ```yaml
   permissions:
     contents: write
     pull-requests: write
   ```

3. Check if PR already exists:
   - Pull Requests tab
   - Look for branch: `auto-update-t2`

4. Manual check:
   ```bash
   # Clone repo
   git clone https://github.com/YOUR_USERNAME/t2-kernel
   cd t2-kernel

   # Check current hash
   nix flake metadata --json | jq -r '.locks.nodes["nixos-hardware"].locked.rev'

   # Update and check new hash
   nix flake lock --update-input nixos-hardware
   nix flake metadata --json | jq -r '.locks.nodes["nixos-hardware"].locked.rev'
   ```

### Cachix Not Caching

**Symptom:** Builds succeed but not in cache

**Debug Steps:**

1. Verify cache name:
   - Check secret `CACHIX_CACHE_NAME` matches your cache

2. Check token permissions:
   - Log into Cachix
   - Settings → Auth Tokens
   - Ensure token has "Write" permission

3. Review workflow logs:
   - Actions tab → Build and Cache T2 Kernels
   - Look for Cachix upload messages
   - Should see: "Pushing to Cachix..."

4. Test locally:
   ```bash
   cachix use YOUR_CACHE_NAME
   nix build .#linux-t2-latest
   cachix push YOUR_CACHE_NAME result
   ```

### High CI Usage

**Symptom:** Exceeding 2,000 minutes/month

**Solutions:**

1. **Reduce check frequency**
   - Change from every 2 hours to every 4 hours
   - Savings: ~360 minutes/month

2. **Build only one kernel**
   - Remove one variant from matrix
   - Savings: ~75 minutes per build

3. **Disable PR builds**
   - Remove `pull_request:` trigger
   - Only build on merge to main

4. **Use build timeout**
   ```yaml
   jobs:
     build-kernels:
       timeout-minutes: 240  # 4 hours max
   ```

## Advanced Topics

### Understanding Kernel Versions

The nixos-hardware T2 module provides two kernel variants:

**Stable (`linux-t2-stable`):**
- Based on Linux 6.12.x (as of Dec 2024)
- Conservative, well-tested
- Recommended for daily use

**Latest (`linux-t2-latest`):**
- Based on Linux 6.16.x (as of Dec 2024)
- Newest features and fixes
- May be less stable

Check versions:
```bash
nix eval .#linux-t2-stable.kernel.version --raw
nix eval .#linux-t2-latest.kernel.version --raw
```

### Manual Workflow Dispatch

You can manually trigger workflows:

1. Go to Actions tab
2. Select workflow (Check for T2 Updates or Build and Cache)
3. Click "Run workflow"
4. Select branch (usually main)
5. Click "Run workflow"

This is useful for:
- Testing after configuration changes
- Forcing a rebuild
- Recovering from failures

### Monitoring Your Cache

Track your Cachix usage:

1. Log into https://app.cachix.org
2. Select your cache
3. Dashboard shows:
   - Storage used
   - Bandwidth used
   - Number of packages

**Free tier limits:**
- 5 GB storage
- No bandwidth limit
- Public caches only

### Local Testing

Before pushing changes, test locally:

```bash
# Test flake evaluation
nix flake check

# Test kernel build
nix build .#linux-t2-latest -L

# Test cache push (requires auth)
export CACHIX_AUTH_TOKEN="your-token"
cachix push YOUR_CACHE result
```

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Cachix Documentation](https://docs.cachix.org/)
- [nixos-hardware T2 Module](https://github.com/NixOS/nixos-hardware/tree/master/apple/t2)
- [T2Linux Project](https://t2linux.org/)
- [Nix Flakes Manual](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html)

## Support

If you encounter issues:

1. Check this documentation
2. Review workflow logs in Actions tab
3. Search existing GitHub issues
4. Create a new issue with:
   - Workflow logs
   - Error messages
   - Steps to reproduce

---

**Last Updated:** December 2024
**Maintained by:** Automated via GitHub Actions
