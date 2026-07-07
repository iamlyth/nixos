{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.claudemodule;
  claudePluginsOfficial = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "0742692199b49af5c6c33cd68ee674fb2e679d50";
    hash = "sha256-5h7uXbqtuguCw9AMpEFJiKAH7ZmGgJJvm3yyec6+BXE=";
  };
  claudeSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "f458cee31a7577a47ba0c9a101976fa599385174";
    hash = "sha256-jKNYFom6R+Qw7LQ8vFPBe51JpqIP0tTSY8LM4aPlnT4=";
  };
  contextMode = pkgs.fetchFromGitHub {
    owner = "mksglu";
    repo = "context-mode";
    # version = "v1.0.137";
    rev = "8d685716596ce6315d6521cb1669f6c07b372c82";
    hash = "sha256-cPYBI8N1htSjpetL33/hS6EAFN1G0fjoWwpkP5W0A3E=";
  };

  # Runtime deps that start.mjs would normally npm-install at runtime.
  # better-sqlite3 is a native addon compiled against pkgs.nodejs.
  # When running under Bun (which has bun:sqlite built-in), better-sqlite3
  # is never loaded — but we include it for Node fallback correctness.
  # To update: bump package.json versions, regenerate package-lock.json,
  # set npmDepsHash = lib.fakeHash, switch, paste the hash from the error.
  contextModeDeps = pkgs.buildNpmPackage {
    pname = "context-mode-runtime-deps";
    version = "1.0.0";
    src = ./context-mode-deps;
    npmDepsHash = "sha256-0J3z+CgKV9FinGNIqKohPUvrarqeSJyAPRygePagiFI=";
    nativeBuildInputs = [ pkgs.python3 ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # Combines the pre-compiled bundles with node_modules.
  # server.bundle.mjs is the actual MCP server — start.mjs (the bootstrapper
  # that does runtime npm installs into its own dir) is intentionally excluded.
  # server.bundle.mjs uses import.meta.url to resolve siblings, so scripts/,
  # configs/, hooks/, and node_modules must be co-located in $out.
  contextModePkg = pkgs.stdenv.mkDerivation {
    pname = "context-mode";
    version = "1.0.136";
    src = contextMode;
    nativeBuildInputs = [ pkgs.jq ];
    installPhase = ''
      mkdir -p $out
      cp server.bundle.mjs cli.bundle.mjs $out/
      cp package.json stats.json $out/
      cp -r hooks skills configs scripts bin $out/
      # Copy .claude-plugin for Claude Code native plugin registration,
      # but patch plugin.json to use bun + server.bundle.mjs instead of
      # node + start.mjs (which does runtime npm installs, broken on NixOS).
      cp -r .claude-plugin $out/
      jq '.mcpServers["context-mode"] = {"command": "${pkgs.bun}/bin/bun", "args": ["'"$out"'/server.bundle.mjs"]}' \
        $out/.claude-plugin/plugin.json > $out/.claude-plugin/plugin.json.tmp
      mv $out/.claude-plugin/plugin.json.tmp $out/.claude-plugin/plugin.json
      # Symlink node_modules as a sibling so ESM resolution (and createRequire)
      # finds externals by walking up from server.bundle.mjs
      ln -s ${contextModeDeps}/node_modules $out/node_modules
    '';
  };
in {
  options.claudemodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable claude.
      '';
    };
  };
  config = mkIf cfg.enable {
    programs.claude-code.enable = true;
    home.packages = [ pkgs.nodejs pkgs.bun ];

    # settings.json must be a real writable file (not a nix symlink) so Claude Code
    # can persist plugin registrations. home.activation copies from the nix store.
    # The mcpServers key uses the "plugin_<name>_<server>" format that Claude Code's
    # plugin system generates — required for the MCP server to be started.
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        settings = pkgs.writeText "claude-settings.json" (builtins.toJSON {
          skipAutoPermissionPrompt = true;
          teammateMode = "tmux";
          env = {
            CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          };
          enabledPlugins = { "context-mode" = true; };
          mcpServers = {
            "plugin_context-mode_context-mode" = {
              command = "${pkgs.bun}/bin/bun";
              args = [ "${contextModePkg}/server.bundle.mjs" ];
            };
          };
          hooks = {
            PreToolUse = [
              {
                matcher = "";
                hooks = [
                  {
                    type = "command";
                    command = "${pkgs.bun}/bin/bun ${contextModePkg}/hooks/pretooluse.mjs";
                  }
                ];
              }
            ];
            PostToolUse = [
              {
                matcher = "";
                hooks = [
                  {
                    type = "command";
                    command = "${pkgs.bun}/bin/bun ${contextModePkg}/hooks/posttooluse.mjs";
                  }
                ];
              }
            ];
            PreCompact = [
              {
                matcher = "";
                hooks = [
                  {
                    type = "command";
                    command = "${pkgs.bun}/bin/bun ${contextModePkg}/hooks/precompact.mjs";
                  }
                ];
              }
            ];
            SessionStart = [
              {
                matcher = "";
                hooks = [
                  {
                    type = "command";
                    command = "${pkgs.bun}/bin/bun ${contextModePkg}/hooks/sessionstart.mjs";
                  }
                ];
              }
            ];
            UserPromptSubmit = [
              {
                matcher = "";
                hooks = [
                  {
                    type = "command";
                    command = "${pkgs.bun}/bin/bun ${contextModePkg}/hooks/userpromptsubmit.mjs";
                  }
                ];
              }
            ];
          };
        });
      in
      ''
        mkdir -p "$HOME/.claude/plugins"
        $DRY_RUN_CMD cp -f ${settings} "$HOME/.claude/settings.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.claude/settings.json"

        # Register context-mode in installed_plugins.json (merge, don't overwrite)
        if [ -z "''${DRY_RUN_CMD:-}" ]; then
          PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
          if [ ! -f "$PLUGINS_FILE" ]; then
            echo '{"version":2,"plugins":{}}' > "$PLUGINS_FILE"
          fi
          ${pkgs.jq}/bin/jq \
            '."plugins"["context-mode"] = [{"scope":"user","installPath":"${contextModePkg}","version":"${contextModePkg.version}","installedAt":"2026-05-19T14:20:47.000Z","lastUpdated":"2026-05-19T14:20:47.000Z","gitCommitSha":"8d685716596ce6315d6521cb1669f6c07b372c82"}]' \
            "$PLUGINS_FILE" > "$PLUGINS_FILE.tmp" && mv "$PLUGINS_FILE.tmp" "$PLUGINS_FILE"

          # Claude Code reads user mcpServers from ~/.claude.json (via P8()), NOT settings.json.
          # Hooks use a different path (wz9 -> B2 -> settings.json), which is why hooks work
          # but MCP doesn't. Merge our server into ~/.claude.json without overwriting other keys.
          CLAUDE_JSON="$HOME/.claude.json"
          if [ ! -f "$CLAUDE_JSON" ]; then
            echo '{}' > "$CLAUDE_JSON"
          fi
          ${pkgs.jq}/bin/jq \
            '.mcpServers["plugin_context-mode_context-mode"] = {"command": "${pkgs.bun}/bin/bun", "args": ["${contextModePkg}/server.bundle.mjs"]}' \
            "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
        fi
      ''
    );
    # ctx-doctor skill resolves CLI as 2 levels up from skills/ctx-doctor (~/.claude)
    home.file.".claude/cli.bundle.mjs" = {
      source = "${contextModePkg}/cli.bundle.mjs";
    };
    home.file.".claude/plugins/context-mode" = {
      source = "${contextModePkg}";
      recursive = true;
    };
    home.file.".claude/skills/skill-creator" = {
      source = "${claudePluginsOfficial}/plugins/skill-creator/skills/skill-creator";
      recursive = true;
    };
    home.file.".claude/skills/docx" = {
      source = "${claudeSkills}/skills/docx";
      recursive = true;
    };
    home.file.".claude/skills/pdf" = {
      source = "${claudeSkills}/skills/pdf";
      recursive = true;
    };
    home.file.".claude/skills/xlsx" = {
      source = "${claudeSkills}/skills/xlsx";
      recursive = true;
    };
    home.file.".claude/skills/pptx" = {
      source = "${claudeSkills}/skills/pptx";
      recursive = true;
    };
    home.file.".claude/skills/context-mode" = {
      source = "${contextModePkg}/skills/context-mode";
      recursive = true;
    };
    home.file.".claude/skills/ctx-doctor" = {
      source = "${contextModePkg}/skills/ctx-doctor";
      recursive = true;
    };
    home.file.".claude/skills/ctx-insight" = {
      source = "${contextModePkg}/skills/ctx-insight";
      recursive = true;
    };
    home.file.".claude/skills/ctx-purge" = {
      source = "${contextModePkg}/skills/ctx-purge";
      recursive = true;
    };
    home.file.".claude/skills/ctx-stats" = {
      source = "${contextModePkg}/skills/ctx-stats";
      recursive = true;
    };
    home.file.".claude/skills/ctx-upgrade" = {
      source = "${contextModePkg}/skills/ctx-upgrade";
      recursive = true;
    };
  };
}
