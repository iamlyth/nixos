# secrets/monitoringsecrets.example.nix
# Copy this file to secrets/monitoringsecrets.nix and fill in real values.
# secrets/monitoringsecrets.nix is gitignored — it will NOT be committed to the public repo.
{
  # Grafana secret key — used to encrypt secrets stored in the Grafana database.
  # Generate with: openssl rand -base64 32
  grafanaSecretKey = "CHANGE_ME_generate_with_openssl_rand_base64_32";
}
