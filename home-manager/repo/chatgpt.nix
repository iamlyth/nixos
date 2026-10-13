{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.chatgptmodule;

  # OpenAI's official Linux build (Electron), repackaged from their apt repo.
  # Not in nixpkgs: pkgs.chatgpt is the macOS app only. The version, pool
  # path and hash live in pins.json; bump them with
  # `scripts/update-deps.sh chatgpt-desktop`, never by hand.
  pin = (importJSON ./pins.json)."chatgpt-desktop";

  # Libraries the bundled Electron and its native modules link or dlopen.
  runtimeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libsecret
    libusb1
    libxkbcommon
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc.lib
    systemd # libudev
    tpm2-tss
    vulkan-loader
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
  ];

  chatgpt = pkgs.stdenv.mkDerivation {
    pname = "chatgpt-desktop";
    inherit (pin) version;

    src = pkgs.fetchurl {
      url = "${pin.repo}/${pin.filename}";
      inherit (pin) hash;
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      dpkg
      makeWrapper
    ];
    buildInputs = runtimeLibs;

    # Optional Qt shims for KDE theming; Electron falls back to GTK without them.
    autoPatchelfIgnoreMissingDeps = [ "libQt5*.so*" "libQt6*.so*" ];

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt $out/bin
      cp -r usr/lib/chatgpt $out/opt/chatgpt
      cp -r usr/share $out/share

      # Prebuilt native modules for other platforms (darwin, arm, musl) that
      # autoPatchelf would otherwise trip over.
      find $out/opt/chatgpt -path '*/prebuilds/*' -type d \( -name '*darwin*' -o -name '*win32*' -o -name '*arm*' -o -name '*musl*' \) -prune -exec rm -rf {} +
      find $out/opt/chatgpt -path '*/prebuilds/*' -type f -name '*.musl.node' -delete

      makeWrapper $out/opt/chatgpt/ChatGPT $out/bin/chatgpt \
        --prefix LD_LIBRARY_PATH : ${makeLibraryPath runtimeLibs} \
        --prefix PATH : ${makeBinPath [ pkgs.xdg-utils ]} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-wayland-ime}}"

      # Keep the codex:// handler but don't let the app claim http(s) or
      # office documents away from the browser and LibreOffice.
      substituteInPlace $out/share/applications/chatgpt.desktop \
        --replace-fail "MimeType=" "X-Upstream-MimeType=" \
        --replace-fail "Exec=chatgpt" "Exec=$out/bin/chatgpt"
      echo "MimeType=x-scheme-handler/codex;" >> $out/share/applications/chatgpt.desktop

      runHook postInstall
    '';

    meta = {
      description = "ChatGPT desktop app by OpenAI (official Linux preview)";
      homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
      license = licenses.unfree;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "chatgpt";
    };
  };
in
{
  options.chatgptmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to install the ChatGPT desktop app.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ chatgpt ];
  };
}
