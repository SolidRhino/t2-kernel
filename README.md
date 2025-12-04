# T2 Kernel Cache for NixOS

Automated builds of Linux T2 kernels (LTS and latest) for Apple T2 hardware, cached with Cachix via GitHub Actions. This saves you from having to build kernels locally on your machine!

## What This Does

Similar to [cache.soopy.moe](https://cache.soopy.moe), this repository:

- 🔨 Builds `linux-t2-lts` (6.6.x) and `linux-t2-latest` (6.12.x) kernels with T2 patches
- 📦 Caches the built kernels on Cachix so you can download pre-built binaries
- 🤖 **Automatically detects new kernel versions** and updates them daily
- 🎯 **Only builds when new versions are available** - no wasted CI time!
- 🔄 Checks kernel.org daily for updates and rebuilds automatically
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

- **Daily at 3 AM UTC** - Checks for new kernel versions and builds if updates are found
- **On push to main/master** - When flake.nix or workflows change
- **Manually** - Via workflow_dispatch with option to force build

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

  # Use the flake
  boot.kernelPackages = (builtins.getFlake "github:YOUR_USERNAME/t2-kernel").packages.x86_64-linux.linux-t2-latest;
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

  hardware.t2 = {
    enable = true;
    kernelVariant = "latest"; # or "lts"
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

- `linux-t2-lts`: Linux 6.6.x LTS kernel with T2 patches
- `linux-t2-latest`: Linux 6.12.x latest kernel with T2 patches
- `linux-t2-lts-kernel`: Just the kernel (no modules)
- `linux-t2-latest-kernel`: Just the kernel (no modules)
- `all`: All kernels bundled together

## Building Locally

If you want to build locally instead of using the cache:

```bash
# Build LTS kernel
nix build .#linux-t2-lts

# Build latest kernel
nix build .#linux-t2-latest

# Build all
nix build .#all
```

## How It Works

### Automatic Updates

1. **Daily check** - GitHub Actions runs `scripts/check-kernel-updates.sh` daily at 3 AM UTC
2. **Version detection** - Script fetches latest versions from kernel.org for both 6.6.x (LTS) and 6.12.x (latest) series
3. **Smart updates** - If new versions are found:
   - Automatically updates `flake.nix` with new version and hash
   - Commits the changes with a descriptive message
   - Triggers the build workflow
4. **Efficient building** - Only builds when new versions are available (no wasted CI time!)

### Build and Cache Process

1. **GitHub Actions** runs the build workflow when updates are detected or on manual trigger
2. **Nix** builds the kernel packages with T2 hardware support
3. **Cachix** receives and stores the built packages
4. **Your NixOS machine** downloads pre-built binaries from Cachix instead of building locally

This is exactly how caches like `cache.soopy.moe` work - they pre-build packages and serve them to users!

## T2 Hardware Support

These kernels include patches and configurations for:

- Apple BCE (Buffer Copy Engine)
- Apple GMUX (GPU multiplexer)
- Apple Magic Backlight
- Apple Touch Bar
- Apple iBridge
- Apple DRM
- CS8409 HDA codec (audio)
- Broadcom WiFi/Bluetooth (BRCMFMAC)

## Updating Kernel Versions

### Automatic (Recommended)

Kernel versions are updated automatically! The workflow:
- Checks kernel.org daily for new releases
- Updates `flake.nix` automatically when new versions are found
- Commits and builds the new kernels
- No manual intervention needed!

### Manual Update

If you want to manually update or switch to different kernel series:

1. Edit `flake.nix`
2. Update the `version` and `src` for the kernel you want to update
3. Get new hash: `nix-prefetch-url https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-VERSION.tar.xz`
4. Commit and push - GitHub Actions will build the new version

Or run the update script locally:
```bash
./scripts/check-kernel-updates.sh
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

- [T2Linux](https://t2linux.org) for T2 hardware support
- [cache.soopy.moe](https://cache.soopy.moe) for inspiration
- [Cachix](https://cachix.org) for binary cache hosting

## License

MIT License - See LICENSE file for details
