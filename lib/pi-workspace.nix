{ pkgs }:
let
  validator = pkgs.writeShellApplication {
    name = "pi-validate-workspace";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
    ];
    text = builtins.readFile ../scripts/pi-workspace-validator.sh;
  };
  sshRunnerValidator = pkgs.writeShellApplication {
    name = "pi-validate-ssh-runner";
    text = builtins.readFile ../scripts/pi-ssh-runner-validator.sh;
  };
in
{
  inherit sshRunnerValidator validator;

  test = pkgs.runCommand "pi-workspace-policy-test" { } ''
    export PATH=${
      pkgs.lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.git
        pkgs.gnugrep
        sshRunnerValidator
        validator
      ]
    }
    ${pkgs.bash}/bin/bash ${../tests/pi-workspace-validator.sh}
    ${pkgs.bash}/bin/bash ${../tests/pi-ssh-runner-validator.sh}
    touch "$out"
  '';
}
