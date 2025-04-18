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
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        # Configure ccache. I believe this is configuring something which nixpkgs
        # will set up as ccacheStdenv. You could configure this to be used for _all_
        # NixOS packages with this in a NixOS config module:
        # config = { replaceStdenv = { pkgs }: pkgs.ccacheStdenv; };
        #
        # But, that's a bad idea since you then lose the remote shared cache, plus
        # some builds seem to be incompatible with it and they fail.
        # How to actually apply the ccacheStdenv is a little confusing. See my notes
        # about figuring this out here:
        # https://discourse.nixos.org/t/help-using-ccache-for-kernel-build/63010
        overlays = [
          (final: prev: {
            ccacheWrapper = prev.ccacheWrapper.override {
              extraConfig = ''
                export CCACHE_COMPRESS=1
                export CCACHE_DIR="/nix/var/cache/ccache"
                export CCACHE_UMASK=007
                if [ ! -d "$CCACHE_DIR" ]; then
                  echo "====="
                  echo "Directory '$CCACHE_DIR' does not exist"
                  echo "Please create it with:"
                  echo "  sudo mkdir -p -m0770 '$CCACHE_DIR'"
                  echo "  sudo chown root:nixbld '$CCACHE_DIR'"
                  echo "Then add 'extra-sandbox-paths = $CCACHE_DIR' to /etc/nix/nix.conf"
                  echo "Then 'sudo systemctl restart nix-daemon'"
                  echo "====="
                  exit 1
                fi
                if [ ! -w "$CCACHE_DIR" ]; then
                  echo "====="
                  echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
                  echo "Please verify its access permissions"
                  echo "====="
                  exit 1
                fi
              '';
            };
          })
        ];
      };
      kernelPackages = {
        v6_14 = pkgs.linuxPackages_custom {
          version = "6.14";
          src = inputs.kernel-6_14;
          # TODO: I wanna set stdenv = pkgs.ccacheStdenv. Ultimately the definition
          # of the thing we're using here does allow doing that (see
          # manual-config.nix in nixpkgs), but the wrapper functions
          # (linux-kernels.nix) don't directly export that. I suspect that the
          # callPackage mechanism will have some general way to override this, but
          # I'm a bit too tired to understand this:
          # https://nixos.org/guides/nix-pills/13-callpackage-design-pattern.html
          # Gemini 2.5 gave me something that sounds kiinda plausible, but looks
          # pretty ugly:
          # https://g.co/gemini/share/41cb753acfd9
          configfile = kconfigs/v6.14_nix_based.config;
        };
        asi-rfcv2 = pkgs.linuxPackages_custom {
          version = "6.12";
          src = inputs.kernel-asi-rfcv2;
          # TODO: I wanna set stdenv = pkgs.ccacheStdenv. Ultimately the definition
          # of the thing we're using here does allow doing that (see
          # manual-config.nix in nixpkgs), but the wrapper functions
          # (linux-kernels.nix) don't directly export that. I suspect that the
          # callPackage mechanism will have some general way to override this, but
          # I'm a bit too tired to understand this:
          # https://nixos.org/guides/nix-pills/13-callpackage-design-pattern.html
          # Gemini 2.5 gave me something that sounds kiinda plausible, but looks
          # pretty ugly:
          # https://g.co/gemini/share/41cb753acfd9
          configfile = kconfigs/v6.12_nix_based_asi.config;
        };
      };
    in {
      nixosConfigurations = let
        # This function defines a set NixOS systems for the named target, with
        # various kernel setups. The name is used to identify the output, and
        # also to import a NixOS module called ${name}.nix that should exist
        # in this directory.
        mkNixoses = name: {
          "${name}-base" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./common.nix ./${name}.nix ];
            specialArgs = {
              kernelPackages = kernelPackages.v6_14;
              kernelParams = [ ];
            };
          };
          "${name}-asi-off" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./common.nix ./${name}.nix ];
            specialArgs = {
              kernelPackages = kernelPackages.asi-rfcv2;
              kernelParams = [ ];
            };
          };
          "${name}-asi-on" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./common.nix ./${name}.nix ];
            specialArgs = {
              kernelPackages = kernelPackages.asi-rfcv2;
              kernelParams = [ "asi=on" ];
            };
          };
        };
        # "aethlered" is intended for the big chungus in the office on my
        # desk-area-network. Whether this approach of combining separate modules
        # instead of using options to a single shared module is a good one... I
        # have no idea.
      in mkNixoses "aethelred" // mkNixoses "qemu";

      # This lets you run `nix develop` and you get a shell with `nil` in it,
      # which is a LSP implementation for Nix. Then if you start VSCode from that
      # shell, and you have something like the Nix IDE plugin, you can do
      # go-to-definition...
      # But AFAICS it only works within a given file.
      # For this not to be tied to x86 you should use something like flake-utils
      # which provides more wrappers, which lets you make this architecture
      # agnostic.
      devShells.x86_64-linux.default =
        pkgs.mkShell { packages = with pkgs; [ nil nixfmt-classic ]; };

      apps.x86_64-linux.rebuild-aethelred = {
        type = "app";
        # writeShellApplication was suggested by AI. It returns a derivation.
        # But .program needs to be a store path. AI suggested that I just
        # interpolate it into a string and append the binary path onto the end
        # of it. This is stupid as hell and definitely not how you're supposed
        # to do this. Examples I found on GitHub seem to not have this problem.
        # I dunno.
        program = "${
            pkgs.writeShellApplication {
              name = "rebuild-aethelred-script";
              runtimeInputs = [ self pkgs.nixos-rebuild ];
              text = ''
                HOST=''${1:-192.168.2.3}
                nixos-rebuild switch --flake .#aethelred --target-host brendan@"$HOST" --use-remote-sudo
              '';
            }
          }/bin/rebuild-aethelred-script";
      };

      # A hello-world build that can be used to check the ccacheStdenv, this is
      # helpful because if it's broken the kernel build doesn't show the useful
      # outputs.
      packages.x86_64-linux.hello = pkgs.ccacheStdenv.mkDerivation {
        name = "hello";

        src = ./src;

        buildInputs = with pkgs; [ coreutils gcc ];

        # Build Phases
        # See: https://nixos.org/nixpkgs/manual/#sec-stdenv-phases
        configurePhase = ''
          declare -xp
        '';
        buildPhase = ''
          gcc "$src/hello.c" -o ./hello
        '';
        installPhase = ''
          mkdir -p "$out/bin"
          cp ./hello "$out/bin/"
        '';
      };
    };
}
