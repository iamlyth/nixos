{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.ralphmodule;
  pins = importJSON ./pins.json;
  pin = pins."ralph-orchestrator";
  ralphSrc = pkgs.fetchFromGitHub {
    inherit (pin)
      owner
      repo
      rev
      hash
      ;
  };

  ralph-orchestrator = pkgs.rustPlatform.buildRustPackage {
    pname = "ralph-orchestrator";
    inherit (pin) version;

    src = ralphSrc;
    cargoLock.lockFile = "${ralphSrc}/Cargo.lock";
    cargoBuildFlags = [
      "--package"
      "ralph-cli"
    ];

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];

    # The workspace contains several binaries; desktopOS only needs the CLI.
    installPhase = ''
      runHook preInstall
      ralphBinary="$(find target -type f -path '*/release/ralph' -print -quit)"
      test -n "$ralphBinary"
      install -Dm755 "$ralphBinary" "$out/bin/ralph"
      runHook postInstall
    '';

    # Upstream's full workspace suite includes integration and network tests.
    doCheck = false;

    meta = {
      description = "AI agent loop orchestrator";
      homepage = "https://github.com/mikeyobrien/ralph-orchestrator";
      license = licenses.mit;
      mainProgram = "ralph";
      platforms = platforms.linux;
    };
  };

  # Ralph's first-class Pi backend invokes a binary named `pi`. Keep the user's
  # normal `pi` command unchanged while making only Ralph resolve that name to
  # the separately configured Ollama Cloud-backed `pi2` instance.
  pi2AsPi = pkgs.writeShellScriptBin "pi" ''
    exec "${config.home.profileDirectory}/bin/pi2" "$@"
  '';

  ralphWithPi2 =
    pkgs.runCommand "ralph-orchestrator-pi2-${pin.version}"
      { nativeBuildInputs = [ pkgs.makeWrapper ]; }
      ''
        mkdir -p "$out/bin"
        makeWrapper "${ralph-orchestrator}/bin/ralph" "$out/bin/ralph" \
          --prefix PATH : ${makeBinPath [ pi2AsPi ]}
      '';
in
{
  options.ralphmodule.enable = mkEnableOption "Ralph Orchestrator using pi2 as its Pi backend";

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.pimodule.enable && config.pimodule.pi2.enable;
        message = "ralphmodule requires pimodule.pi2.enable because Ralph's Pi backend is wired to pi2";
      }
    ];

    home.packages = [ ralphWithPi2 ];
  };
}
