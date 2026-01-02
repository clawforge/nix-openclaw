# Quickstart: Telegram (macOS)

This is the fastest path to a working Clawdis bot.

## 1) Add nix-clawdis to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-clawdis.url = "github:joshp123/nix-clawdis";
  };
}
```

## 2) Enable the module

Replace `<user>` with your Home Manager configuration name.

```nix
{
  homeManagerConfigurations.<user> = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs { system = "aarch64-darwin"; };
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
}
```

## 3) Apply

```bash
home-manager switch --flake .#<user>
```

## 4) Verify

```bash
launchctl print gui/$UID/com.nix-clawdis.gateway | grep state
tail -n 50 ~/.clawdis/logs/clawdis-gateway.log
```

If the agent is running and logs show Telegram connected, send a test message in an allowlisted chat.
Expected:
- `state = running`
- Log shows startup without fatal errors
