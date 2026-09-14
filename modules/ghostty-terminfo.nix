{ pkgs, ... }:
{
  # Let remote applications understand TERM=xterm-ghostty without installing
  # the full Ghostty terminal emulator on headless systems.
  environment.systemPackages = [ pkgs.ghostty.terminfo ];
}
