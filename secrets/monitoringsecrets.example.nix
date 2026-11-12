# secrets/monitoringsecrets.example.nix
# Copy this file to secrets/monitoringsecrets.nix and fill in real values.
# secrets/monitoringsecrets.nix is gitignored — it will NOT be committed to the public repo.
{
  # Grafana secret key — used to encrypt secrets stored in the Grafana database.
  # Generate with: openssl rand -base64 32
  grafanaSecretKey = "CHANGE_ME_generate_with_openssl_rand_base64_32";

  # Home Assistant long-lived access token for the Prometheus scrape endpoint.
  # Create in HA: Profile → Long-Lived Access Tokens → Create Token
  haAuthToken = "CHANGE_ME_ha_long_lived_access_token";
}
