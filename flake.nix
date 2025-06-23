{
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-25.05"; };
    falba = {
      url = "github:bjackman/falba";
      flake = false;
    };
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
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        # https://github.com/NixOS/nixpkgs/pull/408168/
        overlays = [
          (final: prev: {
            docopts = prev.docopts.overrideAttrs (prev: {
              postInstall = ''
                cp ${prev.src}/docopts.sh $out/bin/docopts.sh
                chmod +x $out/bin/docopts.sh
              '';
            });
          })
        ];
      };
      benchmarkVariantsDeps = [
        pkgs.docopts
        pkgs.nixos-rebuild
        self.packages.x86_64-linux.falba-cli
      ];
      baseKernelParams = [
        "nokaslr"
        "mitigations=off"
        "init_on_alloc=0"
        "earlyprintk=serial"
        # Got a bug in the la57 logic and I can't get QEMU to run with la57 for
        # some reason. Think I'm gonna throw the buggy code away anyway so let's
        # just kick this can down the road.
        "no5lvl"
      ];
      kernelPackages = self.kernelPackages.x86_64-linux;
    in {
      nixosModules.brendan = import ./modules/brendan.nix;
      nixosConfigurations = let
        kernelVariants = [
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
          {
            name = "asi-page-cache-fix-alloc-ephmap";
            kernelPackages = kernelPackages.asi-page-cache-fix;
            # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
            # For newer kernels instead use setcpuid.
            kernelParams = [
              "asi=off"
              "force_cpu_bug=retbleed"
              "page_alloc_ephmap=always_alloc"
              "shmem_ephmap=always_alloc"
            ];
          }
          {
            name = "asi-page-cache-fix-use-ephmap";
            kernelPackages = kernelPackages.asi-page-cache-fix;
            # WARNING: force_cpu_bug was added as a hack in my rfcv2-preview branch.
            # For newer kernels instead use setcpuid.
            kernelParams = [
              "asi=off"
              "force_cpu_bug=retbleed"
              "page_alloc_ephmap=always_use"
              "shmem_ephmap=always_use"
            ];
          }
        ];
        modules = [
          ./modules/brendan.nix
          ./modules/common.nix
          ./modules/kernel.nix
          {
            # Record the version of the flake, this will then be available
            # from the `nixos-version` command.
            system.configurationRevision = self.rev or "dirty";
            environment.systemPackages =
              builtins.attrValues self.targetPackages.x86_64-linux;
          }
        ];
      in builtins.listToAttrs (map (kernelVariant: {
        name = "aethelred-${kernelVariant.name}";
        value = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = modules ++ [
            # "aethlered" is intended for the big chungus in the office on my
            # desk-area-network. The only thing special about it is its
            # hostname.
            ./modules/aethelred.nix
            {
              # This goes encoded into the /etc/os-release as VARIANT_ID=
              system.nixos.variant_id = kernelVariant.name;
              environment.systemPackages = [
                self.nixosConfigurations.guest.config.system.build.vm
                # Wrapper wrapper that runs the wrapper in a VM guest. This sucks :(
                # It is really only designed to be called from benchmark-variants.
                (pkgs.writeShellApplication {
                  name = "benchmarks-guest";
                  runtimeInputs = [
                    pkgs.docopts
                    self.nixosConfigurations.guest.config.system.build.vm
                  ];
                  text = builtins.readFile ./src/benchmarks-guest.sh;
                  excludeShellChecks =
                    [ "SC2154" ]; # Shellcheck can't tell ARGS_* is set.
                  extraShellCheckFlags = [
                    "--external-sources"
                    "--source-path=${pkgs.docopts}/bin"
                  ];
                })
              ];
            }
          ];
          specialArgs = {
            kernelPackages = kernelVariant.kernelPackages;
            kernelParams = baseKernelParams ++ kernelVariant.kernelParams;
          };
        };
      }) kernelVariants) // {
        # For running a guest VM that is basically the same as the other
        # nixosConfigurations. It needs to be defined separately to avoid
        # infinite recursion in the config. For the guets we just leave the
        # kernel setup to be the NixOS default.
        guest = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit modules;
          specialArgs = {
            kernelPackages = kernelPackages.v6_14;
            kernelParams = [ ];
          };
        };
      };

      kernelPackages.x86_64-linux = {
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

      # Packages intended to be run on the target host. These are exposed
      # as flake outputs just so they can easily be inspected
      targetPackages.x86_64-linux = rec {
        # This creates a program called bpftrace_asi_exits that will call
        # bpftrace with the appropriate script.
        bpftraceScripts = pkgs.stdenv.mkDerivation {
          pname = "bpftrace-scripts";
          version = "0.1";
          src = pkgs.writeScriptBin "asi_exits.bpftrace"
            (builtins.readFile src/asi_exits.bpftrace);
          installPhase = ''
            mkdir -p $out/bin
            makeWrapper $src/bin/asi_exits.bpftrace $out/bin/bpftrace_asi_exits \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.bpftrace ]}
          '';
          buildInputs = [ pkgs.makeWrapper ];
        };
        # Very thin inner wrapper, mostly just a helper for benchmarks-wrapper.
        # This runs inside the guest when running on a VM.
        runBenchmark = pkgs.writeShellApplication {
          name = "run-benchmark";
          runtimeInputs = [ compile-kernel ] ++ (with pkgs; [
            # Some of these are available in a normal shell but need to be
            # specified explicitly so we can run this via systemd.
            docopts
            fio
            jq
            gawk # Required by docopts
            coreutils
            util-linux
          ]);
          text = builtins.readFile ./src/run-benchmark.sh;
          excludeShellChecks =
            [ "SC2154" ]; # Shellcheck can't tell ARGS_* is set.
          extraShellCheckFlags =
            [ "--external-sources" "--source-path=${pkgs.docopts}/bin" ];
        };
        # Wrapper for actually running the benchmarks.
        benchmarksWrapper = pkgs.writeShellApplication {
          name = "benchmarks-wrapper";
          runtimeInputs = [ bpftraceScripts runBenchmark ] ++ (with pkgs; [
            # Some of these are available in a normal shell but need to be
            # specified explicitly so we can run this via systemd.
            docopts
            gawk # Required by docopts
            coreutils
            util-linux
          ]);
          text = builtins.readFile ./src/benchmarks-wrapper.sh;
          excludeShellChecks =
            [ "SC2154" ]; # Shellcheck can't tell ARGS_* is set.
          extraShellCheckFlags =
            [ "--external-sources" "--source-path=${pkgs.docopts}/bin" ];
        };
        # Package that compiles a kernel, as a "benchmark"
        compile-kernel =
          let kernel = self.kernelPackages.x86_64-linux.nixos.kernel;
          in pkgs.writeShellApplication {
            name = "compile-kernel";
            runtimeInputs = with pkgs; [
              libelf
              elfutils.dev
              gnumake
              gcc
              bison
              flex
              bc
              rsync
            ];
            text = ''
              # Nix does this for you in the build environment but doesn't
              # really make libraries available to the toolchain at runtime.
              # Normally I think people would just use a nix-shell or something
              # that provides the relevant wrappers? I'm not sure, I might be
              # barking up the wrong tree.
              # Anyway, here's a super simple way to make the necessary
              # libraries available:
              export HOSTCFLAGS="-isystem ${pkgs.elfutils.dev}/include"
              export HOSTLDFLAGS="-L ${pkgs.elfutils.out}/lib"
              export HOSTCFLAGS="$HOSTCFLAGS -isystem ${pkgs.openssl.dev}/include"
              export HOSTLDFLAGS="$HOSTLDFLAGS -L ${pkgs.openssl.out}/lib"

              output="$(mktemp -d)"
              trap 'rm -rf $output' EXIT
              echo "Unpacking kernel source ${kernel.src} in $output"
              cd "$output"
              tar xJf ${kernel.src}
              cd "linux-${kernel.version}"

              make -sj tinyconfig
              make -sj"$(nproc)" vmlinux
            '';
          };
        # We donly do this for the x86 kselftests because building these tests
        # is so annoying. The x86 ones are the only ones that I know can be
        # built without being fussy about the exact kernel config, and without
        # requiring a full kernel build in the tree.
        kselftests-x86 = let
          kernel = self.kernelPackages.x86_64-linux.nixos.kernel;
          buildInstallFlags = [ "-C" "tools/testing/selftests" "TARGETS=x86" ];
          # multiStdenv gives us a toolchain with multilib support, which some
          # of the kselftests need.
        in pkgs.multiStdenv.mkDerivation rec {
          pname = "kselftests-x86";
          version = kernel.version;
          src = kernel.src;
          # Not sure why but we need to explicitly include glibc, for both
          # archs.
          buildInputs = with pkgs; [
            glibc
            glibc.static
            pkgsi686Linux.glibc
            pkgsi686Linux.glibc.static
          ];
          nativeBuildInputs = with pkgs; [ bison flex bc rsync ];
          configurePhase = "make $makeFlags defconfig";
          preBuild = "make $makeFlags headers";
          buildFlags = buildInstallFlags;
          preInstall = ''
            mkdir -p $out/bin
            export KSFT_INSTALL_PATH=$out/bin
          '';
          installFlags = buildInstallFlags;
          postInstall = "ln -s $out/bin/run_kselftest.sh $out/bin/${pname}";
          enableParallelBuilding = true;
        };
        # Convenience helper for some tests I currently care about.
        kselftests-ldt = pkgs.writeShellApplication {
          name = "kselftests-ldt";
          runtimeInputs = [ kselftests-x86 ];
          text = "kselftests-x86 --test x86:ldt_gdt_32 --test x86:ldt_gdt_64";
        };
      };

      # Arguably defining these as pacakges is pointless, we can probably just
      # use them directly from the devShell. But this keeps the flake from
      # getting too weird I think...
      packages.x86_64-linux = rec {
        benchmarkVariants = pkgs.writeShellApplication {
          name = "benchmark-variants";
          runtimeInputs = benchmarkVariantsDeps;
          # Shellcheck can't tell ARGS_* is set.
          excludeShellChecks = [ "SC2154" ];
          text = builtins.readFile ./src/benchmark-variants;
          extraShellCheckFlags =
            [ "--external-sources" "--source-path=${pkgs.docopts}/bin" ];
        };
        falba = with pkgs.python3Packages;
          buildPythonPackage {
            pname = "falba";
            version = "0.1.0";
            pyproject = true;
            src = inputs.falba;
            build-system = [ setuptools setuptools-scm ];
            propagatedBuildInputs = [ polars ];
          };
        falba-cli = pkgs.python3Packages.toPythonApplication falba;
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
            nil
            nixfmt-classic
            nixos-rebuild
          ]
          # Directly expose the dependencies of this script so it can be run
          # directly from source for convenient development.
          ++ benchmarkVariantsDeps;
      };

      apps.x86_64-linux = {
        benchmark-variants = {
          type = "app";
          program = self.packages.x86_64-linux.benchmarkVariants;
        };
      };
    };
}
