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

      # Import the T2 kernel packages from nixos-hardware
      # Stable kernel (6.12.x currently)
      linux-t2-stable-kernel = pkgs.callPackage "${nixos-hardware}/apple/t2/pkgs/linux-t2" { };

      # Latest kernel (6.16.x currently)
      # NOTE: Temporarily not built due to patch incompatibility
      # nixos-hardware patches for 6.16 are EOL, and 6.17 patches conflict
      linux-t2-latest-kernel = pkgs.callPackage "${nixos-hardware}/apple/t2/pkgs/linux-t2/latest.nix" { };

      # Create full kernel package sets with modules
      linux-t2-stable = pkgs.linuxPackagesFor linux-t2-stable-kernel;
      linux-t2-latest = pkgs.linuxPackagesFor linux-t2-latest-kernel;

    in
    {
      packages.${system} = {
        # Full kernel package sets (kernel + modules)
        inherit linux-t2-stable linux-t2-latest;

        # Alias for compatibility
        linux-t2-lts = linux-t2-stable;

        default = linux-t2-latest;

        # Just the kernel packages (no modules)
        linux-t2-stable-kernel = linux-t2-stable.kernel;
        linux-t2-latest-kernel = linux-t2-latest.kernel;
        linux-t2-lts-kernel = linux-t2-stable.kernel;

        # Bundle all kernels together
        all = pkgs.symlinkJoin {
          name = "all-t2-kernels";
          paths = [
            linux-t2-stable.kernel
            linux-t2-latest.kernel
          ];
        };
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
