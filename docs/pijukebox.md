# pijukeboxOS — Setup & Usage

A Raspberry Pi 4 running NixOS as a Spotify Connect endpoint with onboard Bluetooth audio output. Built from `templates/pitemplate.nix` (the bare base) and specialised by `hosts/pijukeboxOS.nix` (librespot + Bluetooth + PipeWire). See [the SD-image section in the top-level README](../README.md#raspberry-pi-sd-image) for how the image is built and flashed.

> Historical note: this host originally ran spotifyd. spotifyd 0.4.x hardwires its own libmdns zeroconf responder, which fights Avahi over UDP 5353 and made the device vanish from phones about two minutes after each announcement. Plain librespot registers through the already-running Avahi daemon instead, so the box has exactly one mDNS stack.

## First boot

Flash the SD image (see top-level README), insert into the Pi, plug in ethernet, power on. The host advertises itself over mDNS as `pitemplate.local` on first boot — except your DNS server (Pi-hole, eero, etc.) may not forward `.local`, so often the easiest path is the router's lease table.

Default credentials on the bare image:

| Username  | Password |
| --------- | -------- |
| `lalobied` | `nixos`  |

SSH and rebuild into the jukebox config:

```bash
ssh lalobied@<pi-ip>            # or pitemplate.local if mDNS resolves
cd ~/nixos && git pull          # if you've cloned the repo here
sudo nixos-rebuild switch --flake .#pijukeboxOS
```

## Pairing a Bluetooth speaker

The Pi's BlueZ stack is brought up by [`nixos-raspberrypi`'s](https://github.com/nvmd/nixos-raspberrypi) `raspberry-pi-4.bluetooth` module — `bluetoothctl` should already show a controller:

```bash
bluetoothctl show           # expect a MAC address, "Powered: yes"
```

Pair with the speaker (put it in pairing mode first):

```
$ bluetoothctl
[bluetooth]# agent on
[bluetooth]# default-agent
[bluetooth]# scan on
... wait for the speaker to appear, copy its MAC ...
[bluetooth]# pair    AA:BB:CC:DD:EE:FF
[bluetooth]# trust   AA:BB:CC:DD:EE:FF      # auto-reconnect on boot
[bluetooth]# connect AA:BB:CC:DD:EE:FF
[bluetooth]# quit
```

`trust` is the line that makes the speaker auto-reconnect on every boot, paired with `hardware.bluetooth.settings.Policy.AutoEnable` in `modules/pibluetooth.nix`. Without it you'd be running `connect` after every reboot.

### Doing it from a TUI instead

If you'd rather not type bluetoothctl commands, the same flow is available as a full-screen TUI via `bluetuith` (installed by `pibluetoothmodule`):

```bash
bluetuith
```

Keybindings (press `?` inside for the full list):

- `s` — start/stop discovery (equivalent of `scan on`/`off`).
- `Enter` on a device — open the pair / connect / disconnect / remove menu.
- `t` — toggle trust on the highlighted device.
- `a` — cycle the view filter (All / Paired / Trusted / Connected).
- `?` — keybinding help.

It's especially nice for spotting the speaker among a noisy scan: each row shows RSSI alongside the name/MAC, so the one labelled with your speaker's name and the strongest signal is obvious.

## Setting the speaker as librespot's audio output

librespot runs with `--backend alsa`, which on this host is provided by [PipeWire's ALSA shim](https://docs.pipewire.org/page_man_pipewire-pulse_conf_5.html). That means whichever sink PipeWire treats as its default is where librespot plays — including a Bluetooth speaker.

List the sinks PipeWire knows about:

```bash
wpctl status
```

In the `Sinks:` section you'll see something like:

```
   53. JBL Flip 5                          [vol: 1.00]
*  72. bcm2835 ALSA Analog                 [vol: 0.50]
```

The `*` marks the current default. To make the Bluetooth speaker the default sink:

```bash
wpctl set-default 53        # use the ID from `wpctl status`
```

This persists across reboots — wireplumber writes the choice to `/var/lib/wireplumber/`. Now playback from the Spotify app routed to `pijukeboxOS` will play through the speaker.

To switch back to a different sink later, just `wpctl set-default <other-id>`.

## Verifying everything from the phone

1. Open Spotify on a device on the same LAN.
2. Open the device picker (Connect to a device).
3. Look for `pijukeboxOS`. If it's not listed:
   - Confirm the phone is on the same SSID (Connect's mDNS is L2-scoped; guest VLANs and 2.4 / 5 GHz isolation drop the discovery packets).
   - On the Pi: `systemctl status librespot` should be `active (running)`.
   - On the Pi: `avahi-browse -t -r _spotify-connect._tcp` should list the device with port `5354` (our pinned `librespotmodule.zeroconfPort`).
4. Tap `pijukeboxOS`, then hit play.

## Tweaking librespot

The module's options live in `modules/librespot.nix`. Per-host overrides go in `hosts/pijukeboxOS.nix`:

```nix
librespotmodule = {
  enable           = true;
  deviceName       = "Living Room";   # shown in the Spotify picker
  bitrate          = 320;             # 96 | 160 | 320
  zeroconfPort     = 5354;            # control port; opened in the firewall
  beaconSeconds    = 30;              # mDNS re-announce interval; 0 disables
  idleResetMinutes = 2;               # release a stale user claim; 0 disables
};
```

Two options exist because of real-world network and sharing quirks:

- `beaconSeconds` re-announces the Connect service over mDNS on a cycle, for
  networks that drop enough multicast that phones miss on-demand lookups
  (the office network does). Healthy home networks can leave it at 0.
- `idleResetMinutes` restarts librespot when someone has claimed the device
  but played nothing for that long. librespot never clears its `activeUser`
  on its own, and the Spotify app hides a device claimed by another account,
  so without this the first user owns the jukebox until a restart.

Changes take effect on the next `nixos-rebuild switch`.

## Diagnostics

```bash
# librespot (and its helper units)
systemctl status librespot --no-pager
journalctl -u librespot -n 50 --no-pager
systemctl status librespot-beacon --no-pager       # if beaconSeconds != 0
systemctl list-timers librespot-idle-reset         # if idleResetMinutes != 0

# bluetooth
sudo dmesg | grep -i bluetooth --no-pager   # BCM4345C0 chip id + patch loading
systemctl status bluetooth --no-pager
bluetoothctl info <MAC>                     # connection state of a paired device

# pipewire / audio routing
wpctl status                                # sinks, default, current connections
pactl list short sinks                      # canonical sink names
systemctl --user status pipewire            # (system-wide, so no --user needed here)
```

## When things go sideways

| Symptom | Likely cause / fix |
|---|---|
| `Reset failed (-110)` in dmesg | Pi 4 BT bring-up isn't using the vendor kernel. Confirm the flake input is `nvmd/nixos-raspberrypi` and the host imports `raspberry-pi-4.bluetooth`. |
| Speaker pairs but no audio | `wpctl status` shows the speaker but it isn't default — `wpctl set-default <id>`. |
| Spotify app can't find the device | mDNS isn't reaching the phone (guest WLAN / Pi-hole / VLAN isolation). Direct-test with `avahi-browse -t -r _spotify-connect._tcp` on the Pi. On multicast-lossy networks, set `librespotmodule.beaconSeconds`. |
| Device visible to one account but not others | librespot is holding a stale `activeUser` claim. The `librespot-idle-reset` timer clears it after `idleResetMinutes`; for an immediate fix, `systemctl restart librespot`. |
| `Reset failed` returns after a kernel update | The vendor kernel branch on `nixos-raspberrypi` may have shifted; `nix flake update nixos-raspberrypi` and rebuild. |
| OOM on `nixos-rebuild` | Confirm `free -h` shows the 4 GB swap is active. If `Swap: 0B`, the pitemplate-with-swap generation hasn't booted yet. |
