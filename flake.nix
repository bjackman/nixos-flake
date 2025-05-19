{
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    kernel-6_14 = {
      url = "github:torvalds/linux?ref=v6.14";
      flake = false;
    };
    kernel-asi-rfcv2-preview = {
      url = "github:googleprodkernel/linux-kvm?ref=asi-rfcv2-preview";
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
        asi-rfcv2-preview = pkgs.linuxPackages_custom {
          version = "6.12";
          src = inputs.kernel-asi-rfcv2-preview;
          configfile = kconfigs/v6.12_nix_based_asi.config;
        };
      };
      # Wrapper for running the benchmarks themselves. This needs to be
      # available on the host target, but we also define it up here so we can
      # expose it as an app for convenient testing. This is probably dumb
      # though, we should just use nix develop to produce a shell where the
      # script works and then just support running the script directly!
      benchmarksWrapper = pkgs.callPackage ./pkgs/benchmarks-wrapper.nix { };
      benchmarkBuildsDeps = [ pkgs.nixos-rebuild pkgs.docopts ];
      benchmarkBuilds = pkgs.writeShellApplication {
        name = "benchmark-builds";
        runtimeInputs = benchmarkBuildsDeps;
        # Shellcheck can't tell ARGS_* is set.
        excludeShellChecks = [ "SC2154" ];
        text = builtins.readFile ./src/benchmark-builds.sh;
      };
    in {
      nixosModules.brendan = import ./modules/brendan.nix;
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
              kernelPackages = kernelPackages.asi-rfcv2-preview;
              # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
              # For newer kernels instead use setcpuid.
              kernelParams = [ "force_cpu_bug=retbleed" ];
            }
            {
              name = "asi-on";
              kernelPackages = kernelPackages.asi-rfcv2-preview;
              # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
              # For newer kernels instead use setcpuid.
              kernelParams = [ "asi=on" "force_cpu_bug=retbleed" ];
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
              ./modules/brendan.nix
              ./modules/common.nix
              ./modules/kernel.nix
              ./modules/${variant.machine}.nix
              {
                # Record the version of the flake, this will then be available
                # from the `nixos-version` command.
                system.configurationRevision = self.rev or "dirty";
                # This goes encoded into the /etc/os-release as VARIANT_ID=
                system.nixos.variant_id = name;
                environment.systemPackages = [ benchmarksWrapper ];
              }
            ];
            specialArgs = {
              kernelPackages = variant.kernel.kernelPackages;
              kernelParams = variant.kernel.kernelParams;
            };
          };
        }) variants);

      # This lets you run `nix develop` and you get a shell with `nil` in it,
      # which is a LSP implementation for Nix. Then if you start VSCode from that
      # shell, and you have something like the Nix IDE plugin, you can do
      # go-to-definition...
      # But AFAICS it only works within a given file.
      # For this not to be tied to x86 you should use something like flake-utils
      # which provides more wrappers, which lets you make this architecture
      # agnostic.
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs;
          [ nil nixfmt-classic nixos-rebuild ] ++ benchmarkBuildsDeps;
      };

      apps.x86_64-linux = {
        # This app is the actual main entry point of this whole tooling so this
        # does make sense to expose as an app.
        benchmark-builds = {
          type = "app";
          program = "${benchmarkBuilds}/bin/benchmark-builds";
        };
      };
    };
}
