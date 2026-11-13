{ lib, pkgs, ... }:
{
  # Portal 1.22 merges Settings providers across configs; disable GTK's copy
  # to prevent duplicate theme signals while retaining its other interfaces.
  xdg.portal.extraPortals = lib.mkForce [
    pkgs.xdg-desktop-portal-gnome
    (pkgs.xdg-desktop-portal-gtk.overrideAttrs (old: {
      mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dsettings=disabled" ];
    }))
  ];

  # Preserve GNOME's other portal defaults, including GTK fallback and Secret.
  xdg.portal.config.gnome = {
    default = [ "gnome" "gtk" ];
    "org.freedesktop.impl.portal.Settings" = [ "gnome" ];
    "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
  };
}
