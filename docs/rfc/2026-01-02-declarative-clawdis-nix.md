# RFC: Declarative Clawdis as a Nix Package (nix-clawdis)

- Date: 2026-01-02
- Status: Implementing
- Audience: Nix users, agents (Codex/Claude), package maintainers, operators

## 1) Narrative: what we are building and why

Clawdis is powerful but hard to install and configure for new users, especially those who do not want to learn Nix internals. We need a batteries-included, obvious, and safe path to get a working Clawdis instance with minimal friction. This RFC proposes a dedicated public repo, `nix-clawdis`, that packages Clawdis for Nix and provides a declarative, user-friendly configuration layer with strong defaults, clear examples, and an agent-friendly onboarding flow.

The goal is to make Clawdis installation and configuration feel as simple as: add a flake input, enable a module, paste tokens, and run a single build. The output should be deterministic, secure by default, and easy to troubleshoot.

## 1.1) Non-negotiables

- Nix-first installation: no global installs, no manual brew steps required for core functionality.
- Safe defaults: providers disabled unless explicitly enabled and configured.
- No secrets committed to the repo; clear guidance for secrets injection (agenix, env vars, files).
- Obvious, copy-pasteable configuration examples.
- Deterministic builds and reproducible outputs.
- Documentation must be suitable for publication on the internet.

## 1.2) Scope boundaries (avoid confusion)

This RFC is only about:
- The public `nix-clawdis` repo (package + module + docs).
- A generic, end-user Nix setup that lives outside any personal config repo.

This RFC is explicitly **not** about:
- Josh’s personal `nixos-config` or any private machine configuration.
- Editing or publishing personal settings, tokens, or machine-specific modules.

## 2) Goals / Non-goals

Goals:
- Provide a Nix package for Clawdis and a Home Manager module with batteries-included defaults.
- Provide a flake app for the gateway CLI and a quick verification path.
- Make configuration technically light with explicit options and guardrails.
- Provide Telegram-first examples and workflows.
- Provide clear troubleshooting and a minimal verification checklist.
- New user can get a working bot in 10 minutes without understanding Nix internals.

Non-goals:
- Rewriting Clawdis core functionality.
- Supporting non-Nix install paths in this repo.
- Shipping a hosted SaaS or paid hosting.
- Replacing upstream Clawdis docs.
- Cross-platform support (Linux/Windows) in v1.
- CI automation in v1.

## 3) System overview

`nix-clawdis` is a public repo that provides (macOS-only in v1, no CI in v1):
- A Nix package derivation for Clawdis.
- A Home Manager module for user-level config and service wiring.
- A nix-darwin module for macOS users (optional, thin wrapper over HM).
- A flake with devShell + example configs.
- Documentation and examples optimized for new users and agents.

## 4) Components and responsibilities

- **Package derivation**: builds Clawdis from a pinned source (tag or rev) and exposes a binary.
- **Home Manager module**: declarative config, writes `~/.clawdis/clawdis.json`, manages services.
- **Flake outputs**:
  - `packages.<system>.clawdis-gateway` (binary)
  - `apps.<system>.clawdis` (gateway CLI)
  - `devShells.<system>.default` (docs + lint + tests)
  - `homeManagerModules.clawdis`
  - `darwinModules.clawdis` (if needed)
- **Docs + examples**: Quick start, minimal config, provider-specific guides, troubleshooting.

### 4.1) Module option schema (proposed)

Top-level options (Home Manager):
- `programs.clawdis.enable` (bool, default false)
- `programs.clawdis.package` (package, default `pkgs.clawdis-gateway`)
- `programs.clawdis.stateDir` (string, default `~/.clawdis`)
- `programs.clawdis.workspaceDir` (string, default `~/.clawdis/workspace`)
- `programs.clawdis.providers.telegram.enable` (bool, default false)
- `programs.clawdis.providers.telegram.botTokenFile` (path, required if enabled)
- `programs.clawdis.providers.telegram.allowFrom` (list of chat IDs, required if enabled)
- `programs.clawdis.providers.telegram.requireMention` (bool, default false)
- `programs.clawdis.routing.queue.mode` (enum: queue|interrupt, default interrupt)
- `programs.clawdis.routing.queue.bySurface` (attrset)
- `programs.clawdis.routing.groupChat.requireMention` (bool, default false)
- `programs.clawdis.launchd.enable` (bool, default true)

Defaults:
- All providers disabled.
- Queue mode defaults to interrupt for Telegram, queue for Discord/WebChat.
- No allowlist means no replies at all.

### 4.2) Tradeoffs (why this design)

- **Safe defaults vs. zero-friction**: default-off providers reduce risk but require explicit config. We accept the extra step for safety and clarity.
- **Home Manager first**: HM is the clearest UX for user config, but NixOS-only users must adopt HM or a thin wrapper module.
- **Agent copypasta**: single prompt is the fastest path for non-Nix users.

## 5) Inputs / workflow profiles

Minimum inputs (new user):
- Nix with flakes enabled.
- Telegram bot token.
- A minimal config snippet.

Workflow profiles (Telegram-first):
1) **Telegram-only quick start**
   - Enable module
   - Provide bot token
   - Add allowFrom chat IDs
   - Run build
2) **Multi-chat allowlist**
   - Add multiple Telegram chat IDs
   - Verify routing

Validation rules:
- Nix assertions require tokens and allowlists when providers are enabled.
- Providers must not start unless explicitly enabled and configured.
- Generated config is deterministic from Nix options.

### 5.1) Example configs (inline, required)

Telegram minimal (opinionated defaults):

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

Telegram multi-chat (two groups + one DM):

```nix
{
  programs.clawdis = {
    enable = true;
    providers.telegram = {
      enable = true;
      botTokenFile = "/run/agenix/telegram-bot-token";
      allowFrom = [ 12345678 -1001234567890 -1009876543210 ];
    };
    routing.queue.mode = "interrupt";
  };
}
```

WhatsApp example is deferred until the Telegram-first path is fully verified.

## 6) Artifacts / outputs

- `clawdis` gateway binary in PATH.
- Declarative `~/.clawdis/clawdis.json` (generated).
- Launchd service `com.nix-clawdis.gateway` (macOS).
- Example configs inline in the RFC (Telegram-first).

## 7) State machine (if applicable)

Not applicable. (Packaging + configuration RFC.)

## 8) API surface (protobuf)

None. This RFC does not introduce new protobuf APIs.

## 9) Interaction model

Users interact via:
- Nix config (flake + module options)
- CLI (`clawdis` gateway binary)
- Provider-specific setup steps (Telegram token)

Agent-friendly flow:
- Docs include a “copy-paste config” section with clear placeholders.
- A guided troubleshooting checklist with exact commands and expected output.

### 9.1) Zero to Clawdis (no-Nix user path)

The public docs must include a step-by-step “Zero to Clawdis” guide that covers:
1) Install Determinate Nix on macOS (copy/paste command + link).
2) Enable flakes and basic Nix config.
3) Create a minimal flake (template).
4) Add `nix-clawdis` input and HM module.
5) Paste minimal config snippet (Telegram).
6) Run build and verify via launchd status + a test message.

### 9.2) Agent copypasta (Codex/Claude)

Provide a single prompt users can paste into a coding agent that results in:
- Determinate Nix installed (if missing).
- A local flake scaffold created.
- `nix-clawdis` added as an input.
- A minimal Clawdis config generated with batteries‑included defaults (Telegram-first).
- A final “run these commands” section.

## 10) System interaction diagram

```
User -> Nix flake config -> HM module -> ~/.clawdis/clawdis.json
User -> nix run .#clawdis (CLI) -> gateway/service -> providers
Providers -> Clawdis -> responses to chat
```

## 11) API call flow (detailed)

Not applicable (no new APIs). Primary flows are CLI and provider interactions.

## 12) Determinism and validation

- Pin Clawdis source to a known revision or release tag.
- Nix assertions validate required tokens and allowlists.
- Refuse to start provider services without required tokens/credentials.
- Strict allowlists for inbound chat IDs.
- Emit clear, actionable error messages when config is invalid.

## 12.1) Secrets handling (opinionated default)

- Recommend agenix for bot tokens on macOS.
- Default docs and examples use `/run/agenix/telegram-bot-token`.
- Provide an example agenix entry and a note on file permissions (readable by the user running Home Manager).

## 13) Outputs and materialization

- Primary output: working Clawdis instance configured via Nix.
- Docs output: README + Quick Start + Troubleshooting.
- Example configs embedded in the RFC.

Docs structure (public-facing):
- `README.md` (30-second quick start + install matrix)
- `docs/quickstart-telegram.md`
- `docs/quickstart-whatsapp.md` (optional, future)
- `docs/configuration.md` (all options, defaults, and examples)
- `docs/troubleshooting.md` (copy-paste commands + expected outputs)
- `docs/zero-to-clawdis.md` (Determinate Nix install + macOS bootstrap path)
- `docs/agent-copypasta.md` (copy/paste prompt for Codex/Claude)

## 14) Testing philosophy and trust

- Build derivation test: Nix build must succeed on macOS (v1).
- Smoke test: launchd status + log output + minimal Telegram ping (documented).
- Provider tests: Telegram token presence and minimal send test (documented).
- No CI in v1 (manual validation checklist only).

## 15) Incremental delivery plan

1) Repo scaffold with flake, package derivation, minimal docs.
2) Home Manager module with basic config generation and safe defaults.
3) Telegram quick start and example config.
4) Troubleshooting guide + FAQ.
5) Public release and announcement.

### 15.1) Rollout / rollback

- Rollout: publish repo and pin a release tag; users pin via flake input.
- Rollback: document how to pin to a prior tag and revert module options.

## 16) Implementation order

1) Create `nix-clawdis` repo structure and flake.
2) Implement package derivation (pin Clawdis source).
3) Implement HM module with assertions and config generation.
4) Document CLI usage (`clawdis` gateway).
5) Add examples + docs (README + quickstarts + troubleshooting).

## 17) Brutal self-review (required)

Findings (by persona):
- Junior engineer: Needed a concrete agent copypasta and example config. Added 9.1.
- Mid-level engineer: Lacked explicit module option schema and defaults. Added 4.1 + defaults.
- Senior/principal engineer: Missing tradeoff framing and rollback plan. Added 4.2 + 15.1.
- PM: Success criteria needed to be explicit. Added 10‑minute onboarding goal in section 2.
- EM: Delivery plan was fine, but rollback not stated; now explicit.
- External stakeholder: Narrative needed clearer public framing; kept non‑negotiables and internet‑safe doc requirements.
- End user: Needed a technically light path with clear next command; added 9.1 + 9.2 to require that output.

Open gaps (must resolve before “Reviewed”):
- Verification commands and expected outputs need to be explicit in docs.

Second pass review (delta):
- Tightened language to “technically light” and made Telegram-first explicit.
- Made macOS-only + no-CI explicit in goals/non-goals and testing.
- Moved examples into inline RFC blocks to keep the document self-contained.
- Added Zero-to-Clawdis + Agent Copypasta requirements as first-class docs.

## 18) Definition of Done (DoD)

This RFC is complete when:
- The repo is public with a clear README and Zero‑to‑Clawdis guide.
- Telegram‑first quickstart works on macOS with a real bot token.
- `nix run .#clawdis` launches the gateway and responds in an allowlisted chat.
- Documentation includes a copy‑paste agent prompt and explicit verification steps.
- Smoke test: user sends a Telegram message in an allowlisted chat and receives a response.
- Secrets flow documented with agenix‑style token file wiring.
- A release tag is published and referenced in examples.

## 19) Implementation status (current)

Implemented in `nix-clawdis` repo:
- Flake outputs: package + app + devShell + HM module + darwin wrapper
- Clawdis gateway package pinned to `e5cae2a2e4676111d7bbf1cd1d9956e78ca9088a` (v2.0.0-beta4)
- Telegram-first HM module (launchd on macOS)
- README + Zero-to-Clawdis + Agent Copypasta + Quickstart/Config/Troubleshooting docs

Remaining:
- Publish a release tag once Telegram flow is verified end‑to‑end
