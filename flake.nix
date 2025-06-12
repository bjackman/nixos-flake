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
    devlib = {
      url = "github:ARM-software/devlib?ref=master";
      flake = false;
    };
    workload-automation = {
      url = "github:ARM-software/workload-automation?ref=master";
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
      baseKernelParams = [ "nokaslr" "mitigations=off" "init_on_alloc=0" ];
      kernelPackages = self.kernelPackages.x86_64-linux;
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
              modules = [ ];
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
                environment.systemPackages =
                  [pkgs.fio] ++
                  builtins.attrValues self.targetPackages.x86_64-linux;
              }
            ] ++ variant.machine.modules;
            specialArgs = {
              kernelPackages = variant.kernel.kernelPackages;
              kernelParams = baseKernelParams ++ variant.kernel.kernelParams;
            };
          };
        }) variants);

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
        # Wrapper for actually running the benchmarks.
        benchmarksWrapper = pkgs.writeShellApplication {
          name = "benchmarks-wrapper";
          runtimeInputs = [ bpftraceScripts pkgs.docopts pkgs.fio pkgs.jq ];
          excludeShellChecks =
            [ "SC2154" ]; # Shellcheck can't tell ARGS_* is set.
          text = builtins.readFile ./src/benchmarks-wrapper.sh;
        };
        # Package that compiles a kernel, as a "benchmark"
        compile-kernel =
          let
            kernel = self.kernelPackages.x86_64-linux.nixos.kernel;
          in pkgs.writeShellApplication {
            name = "compile-kernel";
            runtimeInputs = with pkgs; [ libelf elfutils.dev gnumake gcc bison flex bc rsync ];
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

              make -j defconfig
              make -sj"$(nproc)" vmlinux
            '';
          };
        # We donly do this for the x86 kselftests because building these tests
        # is so annoying. The x86 ones are the only ones that I know can be
        # built without being fussy about the exact kernel config, and without
        # requiring a full kernel build in the tree.
        kselftests-x86 =
          let
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
            configurePhase = ''make $makeFlags defconfig'';
            preBuild = ''make $makeFlags headers'';
            buildFlags = buildInstallFlags;
            preInstall = ''
              mkdir -p $out/bin
              export KSFT_INSTALL_PATH=$out/bin
            '';
            installFlags = buildInstallFlags;
            postInstall = ''ln -s $out/bin/run_kselftest.sh $out/bin/${pname}'';
            enableParallelBuilding = true;
          };
        # Convenience helper for some tests I currently care about.
        kselftests-ldt = pkgs.writeShellApplication {
          name = "kselftests-ldt";
          runtimeInputs = [ kselftests-x86 ];
          text = ''kselftests-x86 --test x86:ldt_gdt_32 --test x86:ldt_gdt_64'';
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
        # TODO: clean this up and separate it.
        # The packaging for WA seems to be broken so we have to manually set up
        # the devlip depdendency.
        devlib = with pkgs.python3Packages;
          buildPythonPackage {
            pname = "devlib";
            version = "1.4.0";
            src = inputs.devlib;
            dependencies = [
              # Um, I dunno... this seems kinda dumb. I copied this list from
              # the setup.py in the repo.
              python-dateutil pexpect pyserial paramiko scp wrapt numpy
              pandas pytest lxml nest-asyncio greenlet future ruamel-yaml
            ];
          };
        workload-automation = with pkgs.python3Packages;
          buildPythonApplication {
            pname = "workload-automation";
            version = "3.4.0";
            src = inputs.workload-automation;
            dependencies = [
              # Copied this from the docs.
              pexpect docutils pyserial pyyaml python-dateutil
              pandas devlib wrapt requests colorama future
              # Library not packaged in nixpkgs
              (let
                pname = "Louie";
                version = "2.0.1";
               in
                buildPythonPackage {
                  inherit pname version;
                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "sha256-fWZQ+RcrXj+iEpBl/Ex0vNFNaqpUMMoNm08Smf0MImg=";
                  };
                }
              )
            ];
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
            nil
            nixfmt-classic
            nixos-rebuild
          ]
          # Directly expose the dependencies of this script so it can be run
          # directly from source for convenient development.
          ++ benchmarkVariantsDeps
          ++ builtins.attrValues self.packages.x86_64-linux;
      };

      apps.x86_64-linux = {
        benchmark-variants = {
          type = "app";
          program = self.packages.x86_64-linux.benchmarkVariants;
        };
      };
    };
}
