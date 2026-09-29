# hosts/paperLXC.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/paper.nix
    ../modules/ghostty-terminfo.nix
  ];

  # Hardware (Proxmox VM disk + CIFS family vault).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--106--disk--0";
    fsType = "ext4";
  };

  fileSystems."/mnt/familyvault" = {
    device = "//192.168.10.50/familyvault";
    fsType = "cifs";
  };

  environment.systemPackages = with pkgs; [ openssl ];

  papermodule.enable = true;

  networking = {
    hostName = "paper";
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.10.15";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "192.168.10.1";
      interface = "eth0";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      28981  # paperless
      21     # ftp
    ];
    allowedTCPPortRanges = [ { from = 51000; to = 51999; } ];
  };

  services.vsftpd = {
    enable = true;
    writeEnable = true;
    localUsers = true;
    chrootlocalUser = true;
    allowWriteableChroot = true;
    forceLocalLoginsSSL = true;
    forceLocalDataSSL = true;
    rsaCertFile = "/var/vsftpd/vsftpd.pem";
    extraConfig = ''
      pasv_enable=YES
      pasv_min_port=51000
      pasv_max_port=51999
      require_ssl_reuse=NO
      ssl_ciphers=HIGH
      seccomp_sandbox=NO
      chmod_enable=YES
      strict_ssl_read_eof=NO
    '';
  };

  # Regenerate /etc/pam.d/vsftpd with the default PAM stack (pam_unix).
  # The nixos-26.05 vsftpd module (upstream 4b864991, "replace 'text' with
  # structured PAM rules") only defines the PAM service when virtual users
  # are enabled; with localUsers-only the file vanished and vsftpd fell back
  # to /etc/pam.d/other (pam_warn + pam_deny), rejecting every login with
  # "530 Login incorrect" — including the printer's scan-to-FTP upload.
  security.pam.services.vsftpd = { };

  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * * root ${pkgs.coreutils}/bin/chmod 775 /Users/printer/inbox/*.pdf; ${pkgs.coreutils}/bin/mv /Users/printer/inbox/*.pdf /var/lib/paperless/consume 2>&1 | logger -t paperless-move"
    ];
  };

  users.users.printer = {
    isNormalUser = true;
    home = "/Users/printer";
    shell = pkgs.bash;
    extraGroups = [ "vault" ];
  };

  system.activationScripts.createFtpDirectory = ''
    chown -R printer:vault /Users/printer
    chmod -R 777 /Users/printer
  '';
}
