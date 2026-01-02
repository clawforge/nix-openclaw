# Zero to Clawdis (macOS)

This guide is for people who have never used Nix. You will:
1) Install Determinate Nix
2) Enable flakes
3) Create a local flake
4) Add nix-clawdis
5) Paste a minimal Telegram config
6) Verify via launchd status + logs

## 1) Install Determinate Nix

Run this command:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Open a new terminal after install.

## 2) Enable flakes

Create or edit `~/.config/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
```

## 3) Create a local flake

```bash
mkdir -p ~/code/clawdis-local
cd ~/code/clawdis-local
```

Create `flake.nix`:

Replace `<user>` with your Home Manager configuration name.

```nix
{
  description = "Clawdis local";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-clawdis.url = "github:joshp123/nix-clawdis";
  };

  outputs = { self, nixpkgs, home-manager, nix-clawdis }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell { };
      homeManagerConfigurations.<user> = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-clawdis.homeManagerModules.clawdis
          {
            programs.clawdis = {
              enable = true;
              providers.telegram = {
                enable = true;
                botTokenFile = "/run/agenix/telegram-bot-token";
                allowFrom = [ 12345678 -1001234567890 ];
              };
              routing.queue.mode = "interrupt";
            };
          }
        ];
      };
    };
}
```

## 4) Apply via Home Manager

If you already use Home Manager, run your normal switch command.
Otherwise, install HM once:

```bash
nix run home-manager/release-24.11 -- init
```

Then switch:

```bash
home-manager switch --flake .#<user>
```

## 5) Verify Clawdis

```bash
launchctl print gui/$UID/com.nix-clawdis.gateway | grep state
tail -n 50 ~/.clawdis/logs/clawdis-gateway.log
```

If the agent is running and logs show Telegram connected, send a test message in an allowlisted chat.
Expected:
- `state = running`
- Log shows startup without fatal errors

## Troubleshooting

See `docs/troubleshooting.md`.
