{
  description = "Linux T2 kernel builds for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    t2-kernel-patches = {
      url = "github:t2linux/linux-t2-patches";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, t2-kernel-patches }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Helper function to build T2 kernel
      buildT2Kernel = { version, src, modDirVersion ? version }:
        pkgs.linuxPackagesFor (pkgs.linux_latest.override {
          inherit version src modDirVersion;
          kernelPatches = [
            {
              name = "t2-linux-patches";
              patch = null;
              structuredExtraConfig = with pkgs.lib.kernel; {
                # Apple T2 specific configs
                APPLE_BCE = module;
                APPLE_GMUX = module;
                HID_APPLE_MAGIC_BACKLIGHT = module;
                HID_APPLE_TOUCHBAR = module;
                HID_APPLE_IBRIDGE = module;

                # Additional T2 support
                DRM_APPLE = module;
                SND_HDA_CODEC_CS8409 = module;

                # Enable BRCM WiFi/BT
                BRCMFMAC = module;
                BRCMFMAC_PCIE = yes;
              };
              extraStructuredConfig = {
                APPLE_BCE = pkgs.lib.kernel.module;
              };
            }
          ];
        });

      # LTS kernel (6.6.x)
      linux-t2-lts = buildT2Kernel {
        version = "6.6.62";
        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.62.tar.xz";
          hash = "sha256-4V+4fm+zx+NOw5zfeF3xLwuJVi7TZZhSAyKl0kxXr3U=";
        };
      };

      # Latest kernel (6.12.x)
      linux-t2-latest = buildT2Kernel {
        version = "6.12.1";
        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.1.tar.xz";
          hash = "sha256-M7VZk3xYLZ/MEykHkNPc8fQHXjJPkiSkm0qQCrBCFWU=";
        };
      };

    in
    {
      packages.${system} = {
        inherit linux-t2-lts linux-t2-latest;
        default = linux-t2-latest;

        # Also expose just the kernel packages
        linux-t2-lts-kernel = linux-t2-lts.kernel;
        linux-t2-latest-kernel = linux-t2-latest.kernel;
      };

      # Make it easy to build all packages
      packages.${system}.all = pkgs.symlinkJoin {
        name = "all-t2-kernels";
        paths = [
          linux-t2-lts.kernel
          linux-t2-latest.kernel
        ];
      };

      # NixOS module for easy integration
      nixosModules.default = { config, lib, pkgs, ... }: {
        options.hardware.t2 = {
          enable = lib.mkEnableOption "Apple T2 hardware support";
          kernelVariant = lib.mkOption {
            type = lib.types.enum [ "lts" "latest" ];
            default = "latest";
            description = "Which T2 kernel variant to use";
          };
        };

        config = lib.mkIf config.hardware.t2.enable {
          boot.kernelPackages =
            if config.hardware.t2.kernelVariant == "lts"
            then self.packages.${system}.linux-t2-lts
            else self.packages.${system}.linux-t2-latest;
        };
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nix
          cachix
          git
        ];
      };
    };
}
