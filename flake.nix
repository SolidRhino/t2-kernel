{
  description = "Cached builds of Linux T2 kernels from nixos-hardware";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixos-hardware }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Evaluate a minimal NixOS configuration with the T2 module
      # to extract the kernel packages it provides
      evaluateT2Kernel = variant: (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-hardware.nixosModules.apple-t2
          {
            hardware.apple-t2 = {
              enableAppleSetOsLoader = true;
              kernelVariant = variant; # "stable" or "latest"
            };
            # Minimal config just to evaluate
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
            boot.loader.systemd-boot.enable = true;
          }
        ];
      }).config.boot.kernelPackages;

      # Get both kernel variants from the T2 module
      linux-t2-stable = evaluateT2Kernel "stable";
      linux-t2-latest = evaluateT2Kernel "latest";

    in
    {
      packages.${system} = {
        # Stable kernel (LTS)
        linux-t2-lts = linux-t2-stable;
        linux-t2-stable = linux-t2-stable;

        # Latest kernel
        linux-t2-latest = linux-t2-latest;

        default = linux-t2-latest;

        # Also expose just the kernel packages
        linux-t2-lts-kernel = linux-t2-stable.kernel;
        linux-t2-stable-kernel = linux-t2-stable.kernel;
        linux-t2-latest-kernel = linux-t2-latest.kernel;
      };

      # Make it easy to build all packages
      packages.${system}.all = pkgs.symlinkJoin {
        name = "all-t2-kernels";
        paths = [
          linux-t2-stable.kernel
          linux-t2-latest.kernel
        ];
      };

      # Re-export the nixos-hardware T2 module for convenience
      nixosModules.default = nixos-hardware.nixosModules.apple-t2;

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
