{ config, lib, pkgs, ... }:

let
  cfg = config.programs.clawdis;

  stateDir = cfg.stateDir;
  workspaceDir = cfg.workspaceDir;

  baseConfig = {
    gateway = { mode = "local"; };
    agent = { workspace = workspaceDir; };
  };

  telegramConfig = lib.optionalAttrs cfg.providers.telegram.enable {
    telegram = {
      enabled = true;
      tokenFile = cfg.providers.telegram.botTokenFile;
      allowFrom = cfg.providers.telegram.allowFrom;
      requireMention = cfg.providers.telegram.requireMention;
    };
  };

  routingConfig = {
    routing = {
      queue = {
        mode = cfg.routing.queue.mode;
        bySurface = cfg.routing.queue.bySurface;
      };
      groupChat = {
        requireMention = cfg.routing.groupChat.requireMention;
      };
    };
  };

  mergedConfig = lib.recursiveUpdate baseConfig (lib.recursiveUpdate telegramConfig routingConfig);

  configJson = builtins.toJSON mergedConfig;

  logPath = "${stateDir}/logs/clawdis-gateway.log";

in {
  options.programs.clawdis = {
    enable = lib.mkEnableOption "Clawdis (Telegram-first gateway)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.clawdis-gateway;
      description = "Clawdis gateway package.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.clawdis";
      description = "State directory for Clawdis (logs, sessions, config).";
    };

    workspaceDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.clawdis/workspace";
      description = "Workspace directory for Clawdis agent skills.";
    };

    providers.telegram = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Telegram provider.";
      };

      botTokenFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to Telegram bot token file.";
      };

      allowFrom = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "Allowed Telegram chat IDs.";
      };

      requireMention = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require @mention in Telegram groups.";
      };
    };

    routing.queue = {
      mode = lib.mkOption {
        type = lib.types.enum [ "queue" "interrupt" ];
        default = "interrupt";
        description = "Queue mode when a run is active.";
      };

      bySurface = lib.mkOption {
        type = lib.types.attrs;
        default = {
          telegram = "interrupt";
          whatsapp = "interrupt";
          discord = "queue";
          webchat = "queue";
        };
        description = "Per-surface queue mode overrides.";
      };
    };

    routing.groupChat.requireMention = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Require mention for group chat activation.";
    };

    launchd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run Clawdis gateway via launchd (macOS).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.providers.telegram.enable || cfg.providers.telegram.botTokenFile != "";
        message = "programs.clawdis.providers.telegram.botTokenFile must be set when Telegram is enabled.";
      }
      {
        assertion = !cfg.providers.telegram.enable || (lib.length cfg.providers.telegram.allowFrom > 0);
        message = "programs.clawdis.providers.telegram.allowFrom must be non-empty when Telegram is enabled.";
      }
    ];

    home.packages = [ cfg.package ];

    home.file.".clawdis/clawdis.json".text = configJson;

    home.activation.clawdisDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      /bin/mkdir -p "${stateDir}/logs" "${workspaceDir}"
    '';

    launchd.agents."clawdis.gateway" = lib.mkIf cfg.launchd.enable {
      enable = true;
      config = {
        Label = "com.nix-clawdis.gateway";
        ProgramArguments = [ "${cfg.package}/bin/clawdis" ];
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = stateDir;
        StandardOutPath = logPath;
        StandardErrorPath = logPath;
        EnvironmentVariables = {
          CLAWDIS_CONFIG_PATH = "${stateDir}/clawdis.json";
          CLAWDIS_STATE_DIR = stateDir;
          CLAWDIS_IMAGE_BACKEND = "sips";
          CLAWDIS_NIX_MODE = "1";
        };
      };
    };
  };
}
