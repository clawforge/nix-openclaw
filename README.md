# nix-clawdis

> Declarative Clawdis for macOS via Nix.
>
> <sub>[skip to agent copypasta](#give-this-to-your-ai-agent)</sub>

## The vibe

- **Technically light.** If you can paste a Nix snippet, you can run Clawdis.
- **Telegram-first.** Fastest path to a working bot, then add more providers later.
- **Batteries included defaults.** Safe, opinionated settings that “just work.”
- **No mystery steps.** Every command is copy/pasteable.

## Scope boundaries

- This repo is a public, generic Nix package + Home Manager module for Clawdis.
- It does not include or depend on any personal `nixos-config` or private machine setup.

## Zero to Clawdis

Never used Nix? Start here:

- Read: `docs/zero-to-clawdis.md`
- You’ll install Determinate Nix, bootstrap a flake, enable the module, and go.

## Quickstart (Telegram)

Minimal config:

```nix
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
```

Then:

```bash
launchctl print gui/$UID/com.nix-clawdis.gateway | grep state
tail -n 50 ~/.clawdis/logs/clawdis-gateway.log
```

## What’s included (v1)

- macOS-only (nix-darwin + Home Manager)
- Telegram-first docs + defaults
- Troubleshooting checklist + verification steps

## Not included (v1)

- Linux/Windows support
- CI automation

## Docs

- `docs/zero-to-clawdis.md` — Nix install + bootstrapping
- `docs/agent-copypasta.md` — paste into Claude/Codex
- `docs/quickstart-telegram.md` — minimal Telegram setup
- `docs/quickstart-whatsapp.md` — optional WhatsApp/web setup
- `docs/configuration.md` — full option reference
- `docs/troubleshooting.md` — exact commands + expected output

## Give this to your AI agent

Copy this block and paste it into Claude/Codex:

```text
I want to install Clawdis on macOS using Nix.

Repo: github:joshp123/nix-clawdis

What I need:
1) Install Determinate Nix if missing
2) Create a minimal flake for my machine
3) Add nix-clawdis as an input
4) Enable the Clawdis module with Telegram-first defaults
5) Configure my bot token + allowFrom list
6) Run build + show launchd status + recent logs

Your setup:
- macOS version: [FILL IN]
- Telegram bot token path: [FILL IN]
- Allowed chat IDs: [FILL IN]

Use docs/zero-to-clawdis.md and docs/agent-copypasta.md for the exact steps.
```

## Status

RFC: `docs/rfc/2026-01-02-declarative-clawdis-nix.md`
