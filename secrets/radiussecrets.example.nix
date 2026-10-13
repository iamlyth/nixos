# hosts/secrets.example.nix
# Copy this file to hosts/secrets.nix and fill in real passwords.
# secrets.nix is gitignored — it will NOT be committed to the public repo.
{
  # MariaDB password for the 'raduser' account
  dbPassword = "CHANGE_ME_strong_db_password";

  # RADIUS shared secret — must match what you configure in UniFi
  radiusSecret = "CHANGE_ME_radius_shared_secret";
}