# Agent Copypasta (Codex / Claude)

Copy this entire block into your coding agent.

```text
I want a batteries-included Clawdis install on macOS using Nix.

Repo: github:joshp123/nix-clawdis

Do this:
1) Check if Determinate Nix is installed; install it if missing.
2) Enable flakes in ~/.config/nix/nix.conf.
3) Create a local flake at ~/code/clawdis-local.
4) Add nix-clawdis as an input.
5) Enable the Clawdis Home Manager module with Telegram-first defaults.
6) Use my bot token file and allowFrom IDs.
7) Run home-manager switch and verify with:
   - `launchctl print gui/$UID/com.nix-clawdis.gateway | grep state`
   - `tail -n 50 ~/.clawdis/logs/clawdis-gateway.log`

My inputs:
- macOS version: [FILL IN]
- Telegram bot token file: [FILL IN]
- Allowed chat IDs: [FILL IN]

Constraints:
- macOS-only, no CI.
- Keep config technically light.
- Use safe defaults; providers disabled unless configured.

Reference docs/zero-to-clawdis.md and docs/rfc/2026-01-02-declarative-clawdis-nix.md for structure and defaults.
```
