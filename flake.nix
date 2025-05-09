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
      in builtins.listToAttrs (map (variant:
        let name = "${variant.machine}-${variant.kernel.name}";
        in {
          inherit name;
          value = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./common.nix
              ./kernel.nix
              ./${variant.machine}.nix
              {
                # Record the version of the flake, this will then be available
                # from the `nixos-version` command.
                system.configurationRevision = self.rev or "dirty";
                # This goes encoded into the /etc/os-release as VARIANT_ID=
                system.nixos.variant_id = name;
              }
            ];
            specialArgs = {
              kernelPackages = variant.kernel.kernelPackages;
              kernelParams = variant.kernel.kernelParams;
            };
          };
        }) variants) // {
          # Raspberry Pi 4B at my mum's place
          sandy =
            nixpkgs.lib.nixosSystem { modules = [ ./common.nix ./sandy.nix ]; };
        };

      # This lets you run `nix develop` and you get a shell with `nil` in it,
      # which is a LSP implementation for Nix. Then if you start VSCode from that
      # shell, and you have something like the Nix IDE plugin, you can do
      # go-to-definition...
      # But AFAICS it only works within a given file.
      # For this not to be tied to x86 you should use something like flake-utils
      # which provides more wrappers, which lets you make this architecture
      # agnostic.
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [ nil nixfmt-classic nixos-rebuild ];
      };

      apps.x86_64-linux = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        # Wrapper for running the benchmarks themselves. This needs to be
        # available on the host target.
        benchmarks-wrapper = pkgs.writeShellApplication {
          name = "benchmarks-wrapper";
          runtimeInputs = [ pkgs.docopts pkgs.fio ];
          excludeShellChecks =
            [ "SC2154" "SC1091" ]; # Shellcheck can't tell ARGS_* is set.
          text = ''
            DOC="
            Usage:
              benchmarks-wrapper [--out-dir DIR]
              benchmarks-wrapper --help

            Options:
              -h --help              Show this screen.
              -o DIR --out-dir DIR   Directory to dump results in. Default uses mktemp.
            "
            eval "$(docopts -G ARGS -h "$DOC" : "$@")"

            set -e

            OUT_DIR="$ARGS_out_dir"
            if [ -z "$OUT_DIR" ]; then
              OUT_DIR="$(mktemp -d)"
              echo "Dumping results in $OUT_DIR, specify --out-dir to override"
            fi

            if [ ! -d "$OUT_DIR" ]; then
              echo "$OUT_DIR not a directory"
              exit 1
            fi
            if [ -n "$( ls -A "$OUT_DIR" )" ]; then
              echo "$OUT_DIR not empty"
              exit 1
            fi

            # We'll record the version of the system, to be as hermetic as possible,
            # bail if there have been configuration changes since the last reboot.
            if [ ! -d /run/current-system ]; then
              echo "No /run/current-system - not NodeOS? Not capturing system data"
            elif [ "$(readlink /run/current-system)" != "$(readlink /run/booted-system)" ]; then
              echo "current-system not the same as booted-system, not capturing system data"
            else
              cp /etc/os-release "$OUT_DIR"/etc_os-release
              nixos-version --json > "$OUT_DIR"/nixos-version.json
            fi

            exec fio --name=randread \
            --rw=randread --size=64M --blocksize=4K --directory=/tmp \
              --output="$OUT_DIR"/fio_output.json --output-format=json+
          '';
        };
      in {
        benchmarks-wrapper = {
          type = "app";
          program = "${benchmarks-wrapper}/bin/benchmarks-wrapper";
        };
      };
    };
}
