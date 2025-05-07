{
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    kernel-6_14 = {
      url = "github:torvalds/linux?ref=v6.14";
      flake = false;
    };
    kernel-asi-rfcv2 = {
      url = "github:bjackman/linux?ref=asi/rfcv2";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      kernelPackages = {
        # NixOS's default kernel. This is just here so that I can work on these
        # configs on tiny wittle waptops as it lets you avoid compiling a kernel.
        nixos = pkgs.linuxPackages;
        v6_14 = pkgs.linuxPackages_custom {
          version = "6.14";
          src = inputs.kernel-6_14;
          configfile = kconfigs/v6.14_nix_based.config;
        };
        asi-rfcv2 = pkgs.linuxPackages_custom {
          version = "6.12";
          src = inputs.kernel-asi-rfcv2;
          configfile = kconfigs/v6.12_nix_based_asi.config;
        };
      };
    in {
      nixosConfigurations = let
        # This cartesianProduct call will produce a list of attrsets, with each
        # possible combination of the values for .kernel and .machine.
        variants = nixpkgs.lib.cartesianProduct {
          kernel = [
            {
              name = "nixos";
              kernelPackages = kernelPackages.nixos;
              kernelParams = [ ];
            }
            {
              name = "base";
              kernelPackages = kernelPackages.v6_14;
              kernelParams = [ ];
            }
            {
              name = "asi-off";
              kernelPackages = kernelPackages.asi-rfcv2;
              kernelParams = [ ];
            }
            {
              name = "asi-on";
              kernelPackages = kernelPackages.asi-rfcv2;
              kernelParams = [ "asi=on" ];
            }
          ];
          # "aethlered" is intended for the big chungus in the office on my
          # desk-area-network. Whether this approach of combining separate modules
          # instead of using options to a single shared module is a good one... I
          # have no idea.
          machine = [ "aethelred" "qemu" ];
        };
        # The inner map call will convert each of the variants into a NixOS
        # configuration definition, so we'll have those in a list. But actually we
        # need to output an attrset, so we convert the list into one using
        # listToAttrs. That requires a list of attrsets with fields .name and
        # .value.
      in builtins.listToAttrs (map (variant: {
        name = "${variant.machine}-${variant.kernel.name}";
        value = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./common.nix ./kernel.nix ./${variant.machine}.nix ];
          specialArgs = {
            kernelPackages = variant.kernel.kernelPackages;
            kernelParams = variant.kernel.kernelParams;
          };
        };
      }) variants) // {
        # Raspberry Pi 4B at my mum's place
        sandy = nixpkgs.lib.nixosSystem {
          modules = [ ./common.nix ./sandy.nix ];
        };
      };

      # This lets you run `nix develop` and you get a shell with `nil` in it,
      # which is a LSP implementation for Nix. Then if you start VSCode from that
      # shell, and you have something like the Nix IDE plugin, you can do
      # go-to-definition...
      # But AFAICS it only works within a given file.
      # For this not to be tied to x86 you should use something like flake-utils
      # which provides more wrappers, which lets you make this architecture
      # agnostic.
      devShells.x86_64-linux.default =
        pkgs.mkShell { packages = with pkgs; [ nil nixfmt-classic nixos-rebuild ]; };
    };
}
