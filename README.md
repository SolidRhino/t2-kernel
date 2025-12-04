# T2 Kernel Cache for NixOS

Automated builds of Linux T2 kernels from nixos-hardware for Apple T2 hardware, cached with Cachix via GitHub Actions. This saves you from having to build kernels locally on your machine!

## What This Does

Similar to [cache.soopy.moe](https://cache.soopy.moe), this repository:

- 🔨 Builds T2 kernels from [nixos-hardware](https://github.com/NixOS/nixos-hardware) - both stable and latest variants
- 📦 Caches the built kernels on Cachix so you can download pre-built binaries
- 🔄 Uses nixos-hardware's T2 module - automatically stays updated as nixos-hardware updates
- 📅 Rebuilds weekly to pick up the latest kernel versions
- ⚡ Eliminates the need to compile kernels on your local machine (saves hours!)

## Setup Instructions

### 1. Create a Cachix Cache

First, you need a Cachix account and cache:

1. Sign up at [cachix.org](https://cachix.org)
2. Create a new cache (e.g., `my-t2-kernels`)
3. Generate an auth token from your cache settings

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `CACHIX_CACHE_NAME`: Your cache name (e.g., `my-t2-kernels`)
- `CACHIX_AUTH_TOKEN`: Your Cachix auth token

### 3. Enable GitHub Actions

Push this repository to GitHub and the workflows will run automatically:

- **Every 2 hours** - Checks if nixos-hardware has updates (12 times/day)
  - If updates found: Creates a PR and builds the new kernels
  - If no updates: Does nothing (quick check only)
- **On push to main/master** - When flake.nix, flake.lock, or workflows change
- **On pull requests** - Builds kernels to verify changes work
- **Manually** - Via workflow_dispatch for on-demand builds

✅ **CI Usage:** ~720 min/month for checks + ~600 min/month for builds = **~1,320 min/month** (well within GitHub's 2,000 min/month free tier)

### 4. Use the Cache in NixOS

Once the kernels are built and cached, use them in your NixOS configuration:

#### Option A: Use as a binary cache (recommended)

Add to your `/etc/nixos/configuration.nix`:

```nix
{
  # Add your Cachix cache
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://my-t2-kernels.cachix.org"  # Replace with your cache name
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "my-t2-kernels.cachix.org-1:YOUR_PUBLIC_KEY_HERE"  # Get from Cachix
    ];
  };

  # Use the cached T2 kernels from this flake
  boot.kernelPackages = (builtins.getFlake "github:YOUR_USERNAME/t2-kernel").packages.x86_64-linux.linux-t2-latest;

  # Or just use nixos-hardware directly (this flake re-exports it)
  imports = [
    (builtins.getFlake "github:YOUR_USERNAME/t2-kernel").nixosModules.default
  ];
  hardware.apple-t2 = {
    kernelChannel = "latest"; # or "stable"
  };
}
```

#### Option B: Use the NixOS module

```nix
{
  imports = [
    (builtins.getFlake "github:YOUR_USERNAME/t2-kernel").nixosModules.default
  ];

  nix.settings = {
    substituters = [ "https://my-t2-kernels.cachix.org" ];
    trusted-public-keys = [ "my-t2-kernels.cachix.org-1:YOUR_PUBLIC_KEY_HERE" ];
  };

  hardware.apple-t2 = {
    kernelChannel = "latest"; # or "stable"
  };
}
```

#### Option C: Use in your own flake

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    t2-kernel.url = "github:YOUR_USERNAME/t2-kernel";
  };

  outputs = { self, nixpkgs, t2-kernel }: {
    nixosConfigurations.your-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nix.settings = {
            substituters = [ "https://my-t2-kernels.cachix.org" ];
            trusted-public-keys = [ "my-t2-kernels.cachix.org-1:YOUR_PUBLIC_KEY_HERE" ];
          };

          boot.kernelPackages = t2-kernel.packages.x86_64-linux.linux-t2-latest;
        }
        ./configuration.nix
      ];
    };
  };
}
```

## Available Packages

- `linux-t2-stable`: Stable T2 kernel from nixos-hardware (with full module set)
- `linux-t2-latest`: Latest T2 kernel from nixos-hardware (with full module set)
- `linux-t2-lts`: Alias for `linux-t2-stable`
- `linux-t2-stable-kernel`: Just the stable kernel (no modules)
- `linux-t2-latest-kernel`: Just the latest kernel (no modules)
- `all`: All kernels bundled together

## Building Locally

If you want to build locally instead of using the cache:

```bash
# Build stable kernel
nix build .#linux-t2-stable

# Build latest kernel
nix build .#linux-t2-latest

# Build all
nix build .#all
```

## How It Works

1. **Uses nixos-hardware** - This flake imports the `hardware.apple-t2` module from [nixos-hardware](https://github.com/NixOS/nixos-hardware) which provides properly patched T2 kernels
2. **Exposes kernel packages** - Directly calls the T2 kernel packages to expose both "stable" and "latest" variants
3. **Regular update checks** - GitHub Actions checks every 2 hours if nixos-hardware has new commits
   - Compares the current and latest nixos-hardware commit hashes
   - Only proceeds if there's an actual update (saves CI time!)
4. **Smart building** - When updates are found:
   - Creates a Pull Request with the changes
   - Automatically triggers the build workflow
   - Builds both stable and latest kernels
   - Pushes to your Cachix cache
5. **Fast downloads** - Your NixOS machine downloads pre-built binaries from Cachix instead of building locally (saves 1-2 hours!)

**Benefits:**
- ✅ **Fast updates** - New kernels available within 2 hours of upstream changes
- ✅ **Catches everything** - Kernel, firmware, audio, TouchBar, etc.
- ✅ **Efficient** - Only builds when there are actual updates
- ✅ **Free** - Stays within GitHub's free tier (1,320 of 2,000 min/month)
- ✅ **No manual work** - Fully automated

This is exactly how caches like `cache.soopy.moe` work - they pre-build packages and serve them to users!

## T2 Hardware Support

These kernels come from nixos-hardware's T2 module and include patches and configurations for:

- Apple BCE (Buffer Copy Engine)
- Apple GMUX (GPU multiplexer)
- Apple Magic Backlight
- Apple Touch Bar
- Apple iBridge
- Apple DRM
- CS8409 HDA codec (audio)
- Broadcom WiFi/Bluetooth (BRCMFMAC)
- Tiny DFRU (Device Firmware Update)
- And more from the [t2linux kernel patches](https://github.com/t2linux/linux-t2-patches)

## Updating Kernel Versions

Kernel versions are managed by [nixos-hardware](https://github.com/NixOS/nixos-hardware). When they update their T2 kernel patches and versions, this cache will automatically rebuild on the next weekly run.

To manually trigger a rebuild with the latest versions:
1. Go to the Actions tab in your GitHub repository
2. Click on "Build and Cache T2 Kernels"
3. Click "Run workflow"
4. The workflow will run `nix flake update` to get the latest nixos-hardware and nixpkgs, then build

Or update locally:
```bash
nix flake update
nix build .#linux-t2-latest
```

## Troubleshooting

### Builds are failing

- Check the Actions tab for error logs
- Verify your kernel version and hash are correct
- Ensure CACHIX_AUTH_TOKEN has write permissions

### Not using cached builds

- Verify your cache name and public key in NixOS config
- Check that `nix.settings.substituters` includes your Cachix cache
- Run `nix build --verbose` to see which substituters are being used

### Cache is too large

- Cachix free tier provides 5GB storage
- Consider building only one kernel variant
- Or upgrade to Cachix Pro for more storage

## Credits

- [nixos-hardware](https://github.com/NixOS/nixos-hardware) for the excellent T2 module and kernel patches
- [T2Linux](https://t2linux.org) for T2 hardware support and kernel patches
- [cache.soopy.moe](https://cache.soopy.moe) for inspiration
- [Cachix](https://cachix.org) for binary cache hosting

## License

MIT License - See LICENSE file for details
