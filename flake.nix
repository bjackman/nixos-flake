{
  inputs = { nixpkgs = { url = "github:nixos/nixpkgs/nixos-24.11"; }; };

  outputs = inputs@{ self, nixpkgs }:
    let pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      nixosConfigurations = {
        # A configuration that looks kinda just like a plain default NixOS host.
        base = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./common.nix ];
          specialArgs = { inherit inputs; };
        };

        # Configuration intended for the big chungus in the office on my desk-area-network.
        # Whether this approach of combining separate modules instead of using
        # options to a single shared module is a good one... I have no idea.
        aethelred = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./common.nix ./aethelred.nix ];
          specialArgs = { inherit inputs; };
        };

        qemu = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./common.nix ./qemu.nix ];
          specialArgs = { inherit inputs; };
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
      devShells.x86_64-linux.default = pkgs.mkShell { packages = with pkgs; [ nil nixfmt-classic ]; };

      apps.x86_64-linux.rebuild-aethelred = {
        type = "app";
        # writeShellApplication was suggested by AI. It returns a derivation.
        # But .program needs to be a store path. AI suggested that I just
        # interpolate it into a string and append the binary path onto the end
        # of it. This is stupid as hell and definitely not how you're supposed
        # to do this. Examples I found on GitHub seem to not have this problem.
        # I dunno.
        program = "${pkgs.writeShellApplication {
          name = "rebuild-aethelred-script";
          runtimeInputs = [ self pkgs.nixos-rebuild ];
          text = ''
          nixos-rebuild switch --flake .#aethelred --target-host brendan@192.168.2.3 --use-remote-sudo
          '';
        }}/bin/rebuild-aethelred-script";
      };
    };
}
