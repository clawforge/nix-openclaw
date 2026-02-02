{
  description = "nix-openclaw macOS Home Manager activation test";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = { nixpkgs, home-manager, nix-openclaw, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-openclaw.overlays.default ];
      };
    in {
      homeConfigurations.hm-test = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-openclaw.homeManagerModules.openclaw
          ({ ... }: {
            home = {
              username = "runner";
              homeDirectory = "/tmp/hm-activation-home";
              stateVersion = "23.11";
            };

            programs.openclaw = {
              enable = true;
              installApp = false;
              instances.default = {
                gatewayPort = 18999;
                config = {
                  logging = {
                    level = "debug";
                    file = "/tmp/openclaw/openclaw-gateway.log";
                  };
                  gateway = {
                    mode = "local";
                    auth = {
                      token = "hm-activation-test-token";
                    };
                  };
                };
              };
            };
          })
        ];
      };
    };
}
