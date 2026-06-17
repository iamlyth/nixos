# hosts/paperLXC.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/paper.nix
  ];

  # Hardware (Proxmox VM disk + CIFS family vault).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--106--disk--0";
    fsType = "ext4";
  };

  fileSystems."/mnt/familyvault" = {
    device = "//192.168.5.114/familyvault";
    fsType = "cifs";
  };

  environment.systemPackages = with pkgs; [ openssl ];

  papermodule.enable = true;

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
