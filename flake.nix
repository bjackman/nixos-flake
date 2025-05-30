{
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-25.05"; };
    falba = { url = "github:bjackman/falba"; flake = false; };
    kernel-6_14 = {
      url = "github:torvalds/linux?ref=v6.14";
      flake = false;
    };
    kernel-asi-rfcv2-preview = {
      url = "github:googleprodkernel/linux-kvm?ref=asi-rfcv2-preview";
      flake = false;
    };
    kernel-asi-page-cache-fix = {
      url = "github:bjackman/linux?ref=asi/fix-page-cache";
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
        asi-page-cache-fix = pkgs.linuxPackages_custom {
          version = "6.12";
          src = inputs.kernel-asi-page-cache-fix;
          configfile = kconfigs/v6.12_nix_based_asi.config;
        };
      };
      benchmarkBuildsDeps = [ pkgs.docopts ];
      baseKernelParams = [ "nokaslr" "mitigations=off" "init_on_alloc=0" ];
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
              kernelPackages = kernelPackages.asi-page-cache-fix;
              # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
              # For newer kernels instead use setcpuid.
              kernelParams = [ "force_cpu_bug=retbleed" ];
            }
            {
              name = "asi-off-vmap-files";
              kernelPackages = kernelPackages.asi-page-cache-fix;
              # WARNING: force_cpu_bug and vmap_files were added as hacks in my
              # asi/fix-page-cache branch.  For newer kernels instead use setcpuid.
              kernelParams = [ "force_cpu_bug=retbleed" "vmap_files=yes" ];
            }
            {
              name = "asi-off-vmap-files-only";
              kernelPackages = kernelPackages.asi-page-cache-fix;
              # WARNING: force_cpu_bug and vmap_files were added as hacks in my
              # asi/fix-page-cache branch.  For newer kernels instead use setcpuid.
              kernelParams = [ "force_cpu_bug=retbleed" "vmap_files=only" ];
            }
            {
              name = "asi-on";
              kernelPackages = kernelPackages.asi-rfcv2-preview;
              # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
              # For newer kernels instead use setcpuid.
              kernelParams = [ "asi=on" "force_cpu_bug=retbleed" ];
            }
            {
              name = "asi-page-cache-fix";
              kernelPackages = kernelPackages.asi-page-cache-fix;
              # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
              # For newer kernels instead use setcpuid.
              kernelParams = [ "asi=on" "force_cpu_bug=retbleed" ];
            }
            {
              name = "asi-page-cache-fix-off";
              kernelPackages = kernelPackages.asi-page-cache-fix;
              # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
              # For newer kernels instead use setcpuid.
              kernelParams = [ "asi=off" "force_cpu_bug=retbleed" ];
            }
          ];
          # "aethlered" is intended for the big chungus in the office on my
          # desk-area-network. The only thing special about it is the networking
          # setup.
          machine = [
            {
              name = "aethelred";
              modules = [ ./modules/aethelred.nix ];
            }
            {
              name = "base";
              modules = [];
            }
          ];
        };
        # The inner map call will convert each of the variants into a NixOS
        # configuration definition, so we'll have those in a list. But actually we
        # need to output an attrset, so we convert the list into one using
        # listToAttrs. That requires a list of attrsets with fields .name and
        # .value.
      in builtins.listToAttrs (map (variant:
        let name = "${variant.machine.name}-${variant.kernel.name}";
        in {
          inherit name;
          value = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./modules/brendan.nix
              ./modules/common.nix
              ./modules/kernel.nix
              {
                # Record the version of the flake, this will then be available
                # from the `nixos-version` command.
                system.configurationRevision = self.rev or "dirty";
                # This goes encoded into the /etc/os-release as VARIANT_ID=
                system.nixos.variant_id = name;
                environment.systemPackages = [
                  self.packages.x86_64-linux.benchmarksWrapper
                  self.packages.x86_64-linux.bpftraceScripts
                ];
              }
            ] ++ variant.machine.modules;
            specialArgs = {
              kernelPackages = variant.kernel.kernelPackages;
              kernelParams = baseKernelParams ++ variant.kernel.kernelParams;
            };
          };
        }) variants);

      packages.x86_64-linux = rec {
        #
        # Packages for use on the development host. Arguably defining these as
        # pacakges is pointless, we can probably just use them directly from the
        # devShell. But this keeps the flake from getting too weird I think...
        #

        benchmarkVariants = pkgs.writeShellApplication {
          name = "benchmark-builds";
          runtimeInputs = benchmarkBuildsDeps;
          # Shellcheck can't tell ARGS_* is set.
          excludeShellChecks = [ "SC2154" ];
          text = builtins.readFile ./src/benchmark-variants;
        };
        falba = with pkgs.python3Packages;
          buildPythonPackage {
            pname = "falba";
            version = "0.1.0";
            pyproject = true;
            src = inputs.falba;
            build-system = [ setuptools setuptools-scm ];
            propagatedBuildInputs = [ pandas ];
          };


        #
        # Packages intendedf for use on the target.
        #

        # This creates a program called bpftrace_asi_exits that will call
        # bpftrace with the appropriate script.
        bpftraceScripts = pkgs.stdenv.mkDerivation {
          pname = "bpftrace-scripts";
          version = "0.1";
          src = pkgs.writeScriptBin "asi_exits.bpftrace" (builtins.readFile src/asi_exits.bpftrace);
          installPhase = ''
          mkdir -p $out/bin
          makeWrapper $src/bin/asi_exits.bpftrace $out/bin/bpftrace_asi_exits \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.bpftrace ]}
          '';
          buildInputs = [ pkgs.makeWrapper ];
        };
        # Wrapper for actually running the benchmarks.
        benchmarksWrapper = pkgs.writeShellApplication {
          name = "benchmarks-wrapper";
          runtimeInputs = [
            bpftraceScripts
            pkgs.docopts
            pkgs.fio
            pkgs.jq
          ];
          excludeShellChecks = [ "SC2154" ]; # Shellcheck can't tell ARGS_* is set.
          text = builtins.readFile ./src/benchmarks-wrapper.sh;
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
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs;
          [
            nil nixfmt-classic nixos-rebuild
          ]
          ++ (with self.packages.x86_64-linux; [ falba bpftraceScripts ])
          ++ benchmarkBuildsDeps;
      };

      apps.x86_64-linux = {
        # This app is the actual main entry point of this whole tooling so this
        # does make sense to expose as an app.
        benchmark-variants = {
          type = "app";
          program =
            "${self.packages.x86_64-linux.benchmarkVariants}/bin/benchmark-variants";
        };
      };
    };
}
