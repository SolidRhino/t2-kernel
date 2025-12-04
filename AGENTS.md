# AGENTS.md

This file provides context for AI coding agents working on this repository.

## Project Overview

This is a **NixOS T2 Kernel Cache** repository that automatically builds and caches Linux kernels for Apple T2 hardware using GitHub Actions and Cachix.

**Purpose:** Pre-build T2 kernels so users don't have to compile them locally (saves 1-2 hours per kernel).

**Similar to:** [cache.soopy.moe](https://cache.soopy.moe)

## Repository Structure

```
.
├── flake.nix                          # Nix flake defining T2 kernel packages
├── flake.lock                         # Locked dependency versions
├── .github/workflows/
│   ├── check-updates.yml             # Runs every 2hrs, checks for nixos-hardware updates
│   └── build-and-cache.yml           # Builds kernels and pushes to Cachix
├── README.md                          # User-facing documentation
├── AGENTS.md                          # This file (for AI agents)
└── CLAUDE.md                          # Claude-specific pointer to AGENTS.md
```

## Key Technologies

- **Nix Flakes**: Declarative package management
- **nixos-hardware**: Upstream T2 kernel definitions
- **GitHub Actions**: CI/CD for automated builds
- **Cachix**: Binary cache hosting (like a CDN for Nix packages)

## Build System

### Local Building

```bash
# Build stable kernel
nix build .#linux-t2-stable

# Build latest kernel
nix build .#linux-t2-latest

# Build all packages
nix build .#all

# Check flake validity
nix flake check

# Update dependencies
nix flake update
```

### What Gets Built

The flake exposes these packages:

- `linux-t2-stable`: Kernel from nixos-hardware (stable channel, ~6.12.x)
- `linux-t2-latest`: Kernel from nixos-hardware (latest channel, ~6.16.x)
- `linux-t2-lts`: Alias for stable
- `*-kernel`: Just the kernel (no modules)
- `all`: Symlink join of both kernels

**Implementation:** Direct `callPackage` from nixos-hardware paths:
```nix
linux-t2-stable-kernel = pkgs.callPackage "${nixos-hardware}/apple/t2/pkgs/linux-t2" { };
linux-t2-latest-kernel = pkgs.callPackage "${nixos-hardware}/apple/t2/pkgs/linux-t2/latest.nix" { };
```

## GitHub Actions Workflows

### 1. Check for Updates (`.github/workflows/check-updates.yml`)

**Trigger:** Every 2 hours (cron: `0 */2 * * *`)

**Purpose:** Detect nixos-hardware changes without wasting CI minutes

**Process:**
1. Get current nixos-hardware commit hash
2. Run `nix flake lock --update-input nixos-hardware`
3. Get new commit hash
4. If different:
   - Extract kernel versions
   - Create PR with updated flake.lock
   - Trigger build workflow
5. If same:
   - Revert flake.lock
   - Exit (uses ~2 min CI time)

**Critical:** Uses `git checkout flake.lock` to revert when no updates found.

### 2. Build and Cache (`.github/workflows/build-and-cache.yml`)

**Triggers:**
- Push to main/master (paths: flake.nix, flake.lock, workflows)
- Pull requests
- Called by check-updates workflow
- Manual dispatch

**Process:**
1. **Matrix Build** (parallel):
   - Build linux-t2-stable
   - Build linux-t2-latest
   - Each: kernel + full package set
2. **Build All** (sequential after matrix):
   - Build `#all` package
   - Display kernel versions

**Cachix Integration:**
- Automatic upload via `cachix-action`
- Filter: `(-source$|nixpkgs\.tar\.gz$)` (excludes source tarballs)
- Requires secrets: `CACHIX_CACHE_NAME`, `CACHIX_AUTH_TOKEN`

**CI Time:** ~150-180 minutes per build (both kernels)

## Testing

### Pre-commit Checks

```bash
# Validate flake
nix flake check

# Build locally to verify
nix build .#linux-t2-latest -L

# Check kernel version
nix eval .#linux-t2-latest.kernel.version --raw
```

### Workflow Testing

```bash
# Test check-updates logic locally
OLD=$(nix flake metadata --json | jq -r '.locks.nodes["nixos-hardware"].locked.rev')
nix flake lock --update-input nixos-hardware
NEW=$(nix flake metadata --json | jq -r '.locks.nodes["nixos-hardware"].locked.rev')
[ "$OLD" == "$NEW" ] && echo "No updates" || echo "Updates found"
```

## Conventions

### Commit Messages

Follow Conventional Commits:
- `feat:` New features
- `fix:` Bug fixes
- `chore:` Maintenance (like flake.lock updates)
- `docs:` Documentation changes
- `refactor:` Code restructuring

Example:
```
chore: update nixos-hardware T2 module

Kernel versions:
- Stable: 6.12.5
- Latest: 6.16.2
```

### Branch Naming

- Feature branches: `feature/description`
- Fixes: `fix/issue-description`
- Auto-update PRs: `auto-update-t2` (created by check-updates workflow)
- Claude branches: `claude/*` (for AI development sessions)

### File Modifications

**Never modify these directly:**
- `flake.lock` - Updated by workflows or `nix flake update`
- Workflow-generated files

**Safe to modify:**
- `flake.nix` - Kernel definitions, package exports
- Workflow files - Schedule, matrix, steps
- Documentation - README.md, AGENTS.md

## CI/CD Budget

**GitHub Actions Free Tier:** 2,000 minutes/month

**Current Usage:**
- Check-updates: 12 runs/day × 2 min = 24 min/day = **720 min/month**
- Builds: ~4/month × 150 min = **600 min/month**
- **Total: ~1,320 min/month** (34% under budget)

**If reducing frequency needed:**
```yaml
# Every 4 hours instead of 2:
- cron: '0 */4 * * *'  # Saves ~360 min/month
```

## Common Issues

### Workflow Not Running

- GitHub disables workflows after 60 days of repo inactivity
- Solution: Push any commit or manually trigger

### Build Failures

**Nix evaluation error:**
```bash
# Check locally
nix flake check
```

**Kernel build failure:**
- Usually upstream nixos-hardware issue
- Check: https://github.com/NixOS/nixos-hardware/issues
- Temporarily pin to working commit in flake.nix

**Kernel version mismatch (EOL error):**
- Symptom: `error: linux X.XX was removed because it has reached its end of life upstream`
- Cause: nixos-hardware references a kernel version that nixpkgs has removed
- Solution: Override the kernel version in flake.nix:
  ```nix
  linux-t2-latest-kernel = pkgs.callPackage "${nixos-hardware}/apple/t2/pkgs/linux-t2/latest.nix" {
    linux_6_16 = pkgs.linuxKernel.kernels.linux_6_17;  # Override EOL kernel
  };
  ```
- This is a temporary workaround until nixos-hardware updates

**Cachix auth failure:**
- Regenerate token at app.cachix.org
- Update `CACHIX_AUTH_TOKEN` secret

### PR Creation Fails

**Permissions issue:**
```yaml
# Verify in check-updates.yml:
permissions:
  contents: write
  pull-requests: write
```

**PR already exists:**
- Check for existing `auto-update-t2` branch
- Workflow won't create duplicate

## Dependencies

### Primary Inputs

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nixos-hardware.url = "github:NixOS/nixos-hardware";
};
```

**nixpkgs:** General Nix packages, updated on every build
**nixos-hardware:** T2 kernel definitions, checked every 2 hours

### Why nixos-hardware?

The T2 module lives at `nixos-hardware/apple/t2/` and provides:
- Kernel source (linux_6_6, linux_latest)
- T2-specific patches (from t2linux/linux-t2-patches)
- Kernel config options (APPLE_BCE, HID_APPLE_TOUCHBAR, etc.)
- Firmware integration

**We don't define kernels ourselves** - we import from nixos-hardware to stay in sync with upstream.

## Development Workflow

### Adding New Kernel Variant

1. Check if nixos-hardware provides it
2. If yes, add to flake.nix:
   ```nix
   linux-t2-experimental = pkgs.callPackage "${nixos-hardware}/apple/t2/pkgs/linux-t2/experimental.nix" { };
   ```
3. Add to workflow matrix:
   ```yaml
   matrix:
     kernel: [linux-t2-stable, linux-t2-latest, linux-t2-experimental]
   ```

### Changing Update Frequency

Edit `.github/workflows/check-updates.yml`:
```yaml
schedule:
  - cron: '0 */X * * *'  # Replace X with hours
```

**Impact:** Reduces check frequency = saves CI minutes

### Building Only One Kernel

Edit `.github/workflows/build-and-cache.yml`:
```yaml
# Remove one from matrix:
matrix:
  kernel: [linux-t2-latest]  # Only build latest
```

**Impact:** Saves ~75 min per build

## Debugging

### Check Workflow Logs

1. Actions tab → Workflow name → Latest run
2. Expand failed step
3. Look for error messages

### Test Locally

```bash
# Replicate check-updates workflow
git clone <repo>
cd t2-kernel
nix flake lock --update-input nixos-hardware
nix build .#linux-t2-latest -L

# Check if Cachix would succeed
cachix authtoken <token>
nix build .#linux-t2-latest
cachix push <cache-name> result
```

### Verify Cachix

```bash
# Check if package is in cache
nix path-info --store https://<cache>.cachix.org $(nix build .#linux-t2-latest --print-out-paths --no-link)
```

## Secrets Management

### Required Secrets

Set in: Repository Settings → Secrets and variables → Actions

**CACHIX_CACHE_NAME**
- Your Cachix cache name (e.g., "my-t2-kernels")
- Get from: app.cachix.org → Your cache

**CACHIX_AUTH_TOKEN**
- Authentication token with write permissions
- Get from: app.cachix.org → Cache → Settings → Auth Tokens
- **Important:** Must have "Write" permission

### Rotation

Tokens should be rotated if:
- Token exposed/leaked
- Team member leaves
- Security audit requirements

Process:
1. Generate new token in Cachix
2. Update GitHub secret
3. Revoke old token

## Performance Optimization

### Current Optimizations

1. **Matrix builds:** Parallel kernel builds
2. **Conditional updates:** Only build when nixos-hardware changes
3. **Cachix deduplication:** Same hash = no re-upload
4. **Filter uploads:** Exclude source tarballs

### Potential Improvements

1. **Build caching:** Use GitHub Actions cache for Nix store
   ```yaml
   - uses: actions/cache@v3
     with:
       path: /nix/store
       key: nix-store-${{ hashFiles('flake.lock') }}
   ```

2. **Reduce check frequency:** Every 4 hours instead of 2
   - Impact: -360 CI min/month

3. **Smart build matrix:** Only build changed kernels
   - Requires detecting which kernel updated
   - Complex but possible

## References

- [nixos-hardware T2 module](https://github.com/NixOS/nixos-hardware/tree/master/apple/t2)
- [T2Linux Project](https://t2linux.org/)
- [Cachix Documentation](https://docs.cachix.org/)
- [Nix Flakes Manual](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html)
- [GitHub Actions Docs](https://docs.github.com/en/actions)

---

**Last Updated:** December 2024
**Maintained by:** Automated workflows + AI agents
