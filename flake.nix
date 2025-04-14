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
      };

      # This lets you run `nix develop` and you get a shell with `nil` in it,
      # which is a LSP implementation for Nix. Then if you start VSCode from that
      # shell, and you have something like the Nix IDE plugin, you can do
      # go-to-definition...
      # But AFAICS it only works within a given file.
      # For this not to be tied to x86 you should use something like flake-utils
      # which provides more wrappers, which lets you make this architecture
      # agnostic.
      devShells.x86_64-linux.default = pkgs.mkShell { packages = with pkgs; [ nil nixfmt ]; };
    };
}
