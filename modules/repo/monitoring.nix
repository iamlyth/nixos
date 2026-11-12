# modules/repo/monitoring.nix
# Prometheus + Grafana monitoring stack.
# Prometheus collects metrics (self + node_exporter); Grafana visualizes them
# with a pre-provisioned Prometheus data source.
#
# Secrets (grafanaSecretKey) are NOT hardcoded — the host file passes them
# via module options from the gitignored secrets/monitoringsecrets.nix.
{ config, lib, ... }:
with lib;
let
  cfg = config.monitoringmodule;
in
{
  options.monitoringmodule = {
    enable = mkEnableOption "Prometheus + Grafana monitoring stack";

    grafanaSecretKey = mkOption {
      type = types.str;
      description = "Grafana secret key for encrypting stored secrets. Generate with: openssl rand -base64 32";
    };

    haAuthToken = mkOption {
      type = types.str;
      description = "Home Assistant long-lived access token for the Prometheus scrape endpoint";
    };
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 9090;

      exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
      };

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [{
            targets = [ "localhost:${toString config.services.prometheus.port}" ];
          }];
        }
        {
          job_name = "node";
          static_configs = [{
            targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
          }];
        }
        {
          job_name = "homeassistant";
          metrics_path = "/api/prometheus";
          authorization.credentials = cfg.haAuthToken;
          static_configs = [{
            targets = [ "192.168.10.13:8123" ];
          }];
        }
      ];
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          domain = "localhost";
        };
        security.secret_key = cfg.grafanaSecretKey;
      };
      provision.datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ 9090 3000 ];
  };
}
