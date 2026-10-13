# modules/repo/freeradius.nix
# FreeRADIUS + daloRADIUS module for UniFi MAC-based VLAN assignment.
# Known MACs → assigned VLAN; unknown MACs → Guest VLAN (50) fallback.
#
# Secrets (dbPassword, radiusSecret) are NOT hardcoded — the host file
# passes them via module options. Keep them out of the public repo.
#
# Design notes:
#   - services.freeradius is thin (enable/configDir/debug), so the raddb
#     directory is built as a derivation and handed to configDir.
#   - The sql module is WRITTEN from scratch (25 lines) instead of sed-patching
#     the 421-line upstream template: regex-editing a commented template
#     over-matches (duplicate keys) and is fragile across upgrades. A minimal
#     file with grep verification is simpler and can't produce duplicates.
#   - The default site gets ONE insertion (guest fallback, first -sql only).
#     The existing -sql call sites (authorize/accounting/post-auth) already do
#     everything else once the sql module is enabled.
#   - No sqlcounter/noresetcounter/session-sql/sql_session_start: those are
#     ISP/hotspot features (time quotas, Simultaneous-Use) irrelevant to
#     MAC-auth VLAN assignment.
#   - DB init runs as a systemd oneshot AFTER mysql.service, not as an
#     activation script (activation runs before services start).
{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.radiusmodule;

  # VLAN groups — each gets Tunnel-Type=13, Tunnel-Medium-Type=6,
  # Tunnel-Private-Group-Id=<VLAN ID> reply attributes.
  # (Tunnel-Private-Group-Id is the canonical dictionary spelling.)
  vlanGroups = [
    { group = "vlan_1_management";  vlan = "1"; }
    { group = "vlan_10_servers";    vlan = "10"; }
    { group = "vlan_20_smart_home"; vlan = "20"; }
    { group = "vlan_30_iot_media";  vlan = "30"; }
    { group = "vlan_40_trusted";    vlan = "40"; }
    { group = "vlan_50_guest";      vlan = "50"; }
    { group = "vlan_60_work";       vlan = "60"; }
  ];

  # radgroupreply has no unique key on (groupname, attribute), so
  # ON DUPLICATE KEY UPDATE never fires and plain INSERTs would duplicate
  # on every boot. WHERE NOT EXISTS is the correct idempotent form.
  # Never deletes rows — user-added group attributes survive rebuilds.
  groupsSql = pkgs.writeText "vlan-groups.sql" (concatMapStrings (g: ''
    INSERT INTO radgroupreply (groupname, attribute, op, value)
    SELECT '${g.group}', 'Tunnel-Type', '=', '13' FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM radgroupreply
                      WHERE groupname = '${g.group}' AND attribute = 'Tunnel-Type');
    INSERT INTO radgroupreply (groupname, attribute, op, value)
    SELECT '${g.group}', 'Tunnel-Medium-Type', '=', '6' FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM radgroupreply
                      WHERE groupname = '${g.group}' AND attribute = 'Tunnel-Medium-Type');
    INSERT INTO radgroupreply (groupname, attribute, op, value)
    SELECT '${g.group}', 'Tunnel-Private-Group-Id', '=', '${g.vlan}' FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM radgroupreply
                      WHERE groupname = '${g.group}' AND attribute = 'Tunnel-Private-Group-Id');
  '') vlanGroups);

  # Build the FreeRADIUS config directory as a Nix derivation.
  freeradiusConfigDir = pkgs.runCommand "freeradius-config" {
    nativeBuildInputs = [ pkgs.gnused pkgs.gnugrep ];
  } ''
    cp -a ${freeradiusPkg}/etc/raddb $out
    chmod -R u+w $out

    #-----------------------------------------------------------------
    # SQL module — written in full, not sed-patched (see header comment)
    #-----------------------------------------------------------------
    cat > "$out/mods-available/sql" <<'SQLEOF'
# Minimal SQL module for UniFi MAC-auth + daloRADIUS (MariaDB backend)
sql {
	dialect = "mysql"
	driver = "rlm_sql_''${dialect}"

	# Connection info
	server = "localhost"
	port = 3306
	login = "raduser"
	password = "${cfg.dbPassword}"
	radius_db = "raddb"

	# Table names (daloRADIUS-compatible)
	acct_table1 = "radacct"
	acct_table2 = "radacct"
	postauth_table = "radpostauth"
	authcheck_table = "radcheck"
	groupcheck_table = "radgroupcheck"
	authreply_table = "radreply"
	groupreply_table = "radgroupreply"
	usergroup_table = "radusergroup"

	# Connection pool — matches upstream defaults (sized to the thread pool)
	pool {
		start = ''${thread[pool].start_servers}
		min = ''${thread[pool].min_spare_servers}
		max = ''${thread[pool].max_servers}
		spare = ''${thread[pool].max_spare_servers}
		uses = 0
		retry_delay = 30
		lifetime = 0
		idle_timeout = 60
		max_retries = 5
	}

	# Read RADIUS clients (APs) from the 'nas' table at startup
	read_clients = yes
	client_table = "nas"

	group_attribute = "SQL-Group"

	# Load the dialect-specific queries
	$INCLUDE ''${modconfdir}/''${.:name}/main/''${dialect}/queries.conf
}
SQLEOF

    # Enable the sql module
    ln -sf "$out/mods-available/sql" "$out/mods-enabled/sql"
    # Ensure the default site is enabled (defensive; already a symlink upstream)
    ln -sf "$out/sites-available/default" "$out/sites-enabled/default"

    # Verify the sql file (fixed-string grep — password may contain regex chars)
    grep -qF 'password = "${cfg.dbPassword}"' "$out/mods-available/sql" \
      || { echo "ERROR: sql module missing db password"; exit 1; }
    grep -q 'dialect = "mysql"' "$out/mods-available/sql" \
      || { echo "ERROR: sql module missing dialect"; exit 1; }
    grep -qF '$INCLUDE ''${modconfdir}' "$out/mods-available/sql" \
      || { echo "ERROR: sql module missing queries INCLUDE"; exit 1; }

    #-----------------------------------------------------------------
    # Default site — insert guest VLAN fallback after the authorize -sql.
    # The 0,/re/ address limits the substitution to the FIRST -sql line
    # (the authorize call site); the other three -sql call sites
    # (accounting, post-auth) must NOT be touched.
    #-----------------------------------------------------------------
    sed -i '0,/^\s*-sql\s*$/s//&\n\t# Guest VLAN fallback for unknown MACs\n\tif (notfound) {\n\t\tupdate control {\n\t\t\tAuth-Type := Accept\n\t\t}\n\t\tupdate reply {\n\t\t\tTunnel-Type = 13\n\t\t\tTunnel-Medium-Type = 6\n\t\t\tTunnel-Private-Group-Id = "50"\n\t\t\tReply-Message = "Unknown device - assigned to Guest VLAN"\n\t\t}\n\t}/' "$out/sites-available/default"

    grep -q 'Guest VLAN fallback for unknown MACs' "$out/sites-available/default" \
      || { echo "ERROR: guest fallback missing from default site"; exit 1; }

    #-----------------------------------------------------------------
    # EAP module — written minimal. MAC auth (PAP) never uses EAP, but
    # the eap module is enabled by default in the package raddb and the
    # default site calls it. The upstream config instantiates the TLS
    # methods (tls/ttls/peap), which demand certs/server.pem — but the
    # nixpkgs package deliberately strips generated certs (reproducibility:
    # LOCAL_CERT_FILES= in its package.nix), so rlm_eap_tls failed to
    # init. Keeping only the md5 method (the default_eap_type) means no
    # SSL context, no certs, and the module still instantiates cleanly.
    # If EAP-TLS/PEAP is ever needed, real certs must be provisioned and
    # the tls methods restored.
    #-----------------------------------------------------------------
    cat > "$out/mods-available/eap" <<'EAPEOF'
eap {
	default_eap_type = md5
	timer_expire = 60
	ignore_unknown_eap_types = no
	cisco_accounting_username_bug = no

	md5 {
	}
}
EAPEOF

    # Ensure eap is enabled (mods-enabled/eap may be a copy in the package)
    ln -sf "$out/mods-available/eap" "$out/mods-enabled/eap"
    grep -qF 'default_eap_type = md5' "$out/mods-available/eap" \
      || { echo "ERROR: minimal eap module missing default_eap_type"; exit 1; }

    #-----------------------------------------------------------------
    # RADIUS clients — UniFi APs / controller (Management VLAN)
    #-----------------------------------------------------------------
    cat >> "$out/clients.conf" <<CLIENTCONF

client unifi_network {
    ipaddr = ${cfg.unifiSubnet}
    secret = ${cfg.radiusSecret}
    require_message_authenticator = no
    nas_type = other
}
CLIENTCONF

    grep -q 'unifi_network' "$out/clients.conf" \
      || { echo "ERROR: unifi client missing from clients.conf"; exit 1; }
  '';

  daloradiusDir = "/var/www/daloradius";

  # The nixpkgs freeradius package builds WITHOUT SQL drivers by default
  # (withMysql ? false in pkgs/by-name/fr/freeradius). Without this override
  # rlm_sql_mysql.so does not exist and radiusd fails at startup with
  # "Could not link driver rlm_sql_mysql". Scoped override — no global effect.
  freeradiusPkg = pkgs.freeradius.override { withMysql = true; };

in {
  options.radiusmodule = {
    enable = mkEnableOption "FreeRADIUS + daloRADIUS for UniFi MAC-based VLAN assignment";

    dbPassword = mkOption {
      type = types.str;
      description = "Password for the MariaDB 'raduser' account. Set in the host file, not in the public repo. Avoid single quotes and pipe characters — they break shell/sed embedding.";
    };

    radiusSecret = mkOption {
      type = types.str;
      description = "RADIUS shared secret — must match the UniFi RADIUS server config. Set in the host file, not in the public repo.";
    };

    unifiSubnet = mkOption {
      type = types.str;
      default = "192.168.1.0/24";
      description = "CIDR subnet of UniFi APs / controller (Management VLAN). RADIUS clients are allowed from this subnet.";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable FreeRADIUS debug logging (-xx). WARNING: logs passwords in plaintext. Use only for troubleshooting.";
    };
  };

  config = mkIf cfg.enable {
    #===================================================================
    # MariaDB
    #
    # ensureDatabases is idempotent (runs every boot). ensureUsers and
    # initialScript are deliberately NOT used: ensureUsers creates the
    # user with unix_socket auth (no password), which FreeRADIUS cannot
    # use (it runs as user 'radius'); initialScript runs before
    # ensureUsers on first boot, so ALTER USER would fail silently.
    # User/password/grants are handled by radius-db-init below.
    #===================================================================
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "raddb" ];
    };

    services.freeradius = {
      enable = true;
      package = freeradiusPkg;
      configDir = freeradiusConfigDir;
      debug = cfg.debug;
    };

    #===================================================================
    # Apache + PHP for the daloRADIUS web UI (operators on :8000)
    #===================================================================
    services.httpd = {
      enable = true;
      enablePHP = true;
      phpPackage = pkgs.php;
      adminAddr = "admin@daloradius.example.org";
      # daloRADIUS targets older PHP and emits deprecation warnings on 8.4.
      # Never render PHP errors in the page — log them to the httpd error log.
      phpOptions = ''
        display_errors = Off
        log_errors = On
      '';

      virtualHosts."daloradius-operators" = {
        hostName = "radius";
        listen = [{ port = 8000; }];
        documentRoot = "${daloradiusDir}/app/operators";
        extraConfig = ''
          DirectoryIndex index.php index.html
          <Directory "${daloradiusDir}/app/operators">
            Options -Indexes +FollowSymLinks
            AllowOverride All
            Require all granted
          </Directory>
          <Directory "${daloradiusDir}/app/operators/notifications">
            AllowOverride None
            Require all denied
          </Directory>
          <Directory "${daloradiusDir}">
            Require all denied
          </Directory>
        '';
      };

      virtualHosts."daloradius-users" = {
        hostName = "radius";
        listen = [{ port = 80; }];
        documentRoot = "${daloradiusDir}/app/users";
        extraConfig = ''
          DirectoryIndex index.php index.html
          <Directory "${daloradiusDir}/app/users">
            Options -Indexes +FollowSymLinks
            AllowOverride None
            Require all granted
          </Directory>
          <Directory "${daloradiusDir}/app/users/notifications">
            AllowOverride None
            Require all denied
          </Directory>
          <Directory "${daloradiusDir}">
            Require all denied
          </Directory>
        '';
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ 1812 1813 ];
      allowedTCPPorts = [ 80 8000 ];
    };

    environment.systemPackages = [
      freeradiusPkg     # radtest / radsnoop for debugging
      pkgs.mariadb.client # CLI tools (renamed from mariadb-client in 26.05)
    ];

    #===================================================================
    # www-data user (NixOS has no www-data by default)
    #===================================================================
    users.users.www-data = {
      isSystemUser = true;
      group = "www-data";
      description = "Apache web server user";
    };
    users.groups.www-data = {};

    #===================================================================
    # daloRADIUS provisioning — activation script (files only, no DB
    # access; runs before services start, which is fine for file writes)
    #===================================================================
    system.activationScripts.daloradius-setup = {
      deps = [ "users" "groups" ];
      text = ''
        # Clone or update daloRADIUS
        if [ ! -d "${daloradiusDir}" ]; then
          mkdir -p /var/www
          ${pkgs.git}/bin/git clone https://github.com/lirantal/daloradius.git "${daloradiusDir}"
        else
          cd "${daloradiusDir}" && ${pkgs.git}/bin/git pull -q || true
        fi

        # Write daloRADIUS config from the sample, then set our values
        # (sed must be fully qualified — activation PATH has coreutils but NOT gnused)
        DALO_CONF="${daloradiusDir}/app/common/includes"
        if [ ! -f "$DALO_CONF/daloradius.conf.php" ]; then
          cp "$DALO_CONF/daloradius.conf.php.sample" "$DALO_CONF/daloradius.conf.php"
        fi
        SED="${pkgs.gnused}/bin/sed"
        # All patterns anchored on the exact ['KEY'] so substring keys can't
        # cross-match — ['CONFIG_DB_PASS'] must NOT also hit
        # ['CONFIG_DB_PASSWORD_ENCRYPTION'] (a substring match clobbered the
        # encryption flag and made daloRADIUS hide Cleartext-Password from
        # the New User form).
        $SED -i "/\['CONFIG_DB_HOST'\]/s|=.*|= 'localhost';|" "$DALO_CONF/daloradius.conf.php"
        $SED -i "/\['CONFIG_DB_PORT'\]/s|=.*|= '3306';|" "$DALO_CONF/daloradius.conf.php"
        $SED -i "/\['CONFIG_DB_USER'\]/s|=.*|= 'raduser';|" "$DALO_CONF/daloradius.conf.php"
        $SED -i "/\['CONFIG_DB_PASS'\]/s|=.*|= '${cfg.dbPassword}';|" "$DALO_CONF/daloradius.conf.php"
        $SED -i "/\['CONFIG_DB_NAME'\]/s|=.*|= 'raddb';|" "$DALO_CONF/daloradius.conf.php"
        $SED -i "/\['FREERADIUS_VERSION'\]/s|=.*|= '3';|" "$DALO_CONF/daloradius.conf.php"
        # Repair the flag on already-clobbered installs (idempotent)
        $SED -i "/\['CONFIG_DB_PASSWORD_ENCRYPTION'\]/s|=.*|= 'yes';|" "$DALO_CONF/daloradius.conf.php"
        # Same for the two length keys the old substring sed also hit
        $SED -i "/\['CONFIG_DB_PASSWORD_MAX_LENGTH'\]/s|=.*|= '14';|" "$DALO_CONF/daloradius.conf.php"
        $SED -i "/\['CONFIG_DB_PASSWORD_MIN_LENGTH'\]/s|=.*|= '8';|" "$DALO_CONF/daloradius.conf.php"

        # var directories + permissions
        mkdir -p "${daloradiusDir}/var/"{log,backup}
        chown -R www-data:www-data "${daloradiusDir}/var"
        chmod -R 775 "${daloradiusDir}/var"
        chown www-data:www-data "$DALO_CONF/daloradius.conf.php"
        chmod 664 "$DALO_CONF/daloradius.conf.php"

        if [ -f "${daloradiusDir}/contrib/scripts/dalo-crontab" ]; then
          chown www-data:www-data "${daloradiusDir}/contrib/scripts/dalo-crontab"
        fi
      '';
    };

    #===================================================================
    # DB initialization — oneshot, runs AFTER mysql.service.
    #
    # Ordering is expressed from OUR unit (before = freeradius), never as
    # a sub-path override of the upstream freeradius service — the
    # upstream module wraps its whole service definition in mkIf, and
    # sub-path definitions beside an mkIf-wrapped whole definition can
    # fail evaluation with "attribute already defined".
    #
    # Everything here is idempotent:
    #   - CREATE USER IF NOT EXISTS + ALTER USER (same value each run)
    #   - GRANT (safe to re-run)
    #   - schema load guarded by SELECT 1 FROM radcheck
    #   - groupsSql uses WHERE NOT EXISTS (no unique index on the table)
    #===================================================================
    systemd.services.radius-db-init = {
      description = "Initialize RADIUS database (user, schemas, VLAN groups)";
      after = [ "mysql.service" ];
      wants = [ "mysql.service" ];
      before = [ "freeradius.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Wait for MariaDB (root connects via unix_socket)
        for i in $(seq 1 60); do
          ${pkgs.mariadb}/bin/mariadb -u root -e 'SELECT 1' >/dev/null 2>&1 && break
          sleep 1
        done
        ${pkgs.mariadb}/bin/mariadb -u root -e 'SELECT 1' >/dev/null 2>&1 \
          || { echo "ERROR: MariaDB not ready after 60s"; exit 1; }

        # Create raduser with password auth (idempotent)
        ${pkgs.mariadb}/bin/mariadb -u root -e "CREATE USER IF NOT EXISTS 'raduser'@'localhost' IDENTIFIED BY '${cfg.dbPassword}'"
        ${pkgs.mariadb}/bin/mariadb -u root -e "ALTER USER 'raduser'@'localhost' IDENTIFIED BY '${cfg.dbPassword}'"
        ${pkgs.mariadb}/bin/mariadb -u root -e "GRANT ALL PRIVILEGES ON raddb.* TO 'raduser'@'localhost'"
        ${pkgs.mariadb}/bin/mariadb -u root -e "FLUSH PRIVILEGES"

        # Load FreeRADIUS schema (guarded — only if radcheck doesn't exist yet)
        if ! ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb -e 'SELECT 1 FROM radcheck' >/dev/null 2>&1; then
          echo "Loading FreeRADIUS SQL schema..."
          ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb \
            < ${freeradiusPkg}/etc/raddb/mods-config/sql/main/mysql/schema.sql 2>/dev/null || true
        fi

        # Load daloRADIUS schemas — FIRST INIT ONLY, guarded on the
        # operators table. mariadb-daloradius.sql DROPs and recreates
        # ALL daloRADIUS tables (operators, userinfo, etc.) before
        # re-seeding them, so re-running it on every boot/rebuild wiped
        # the operator's admin password and any GUI-entered user info.
        # daloRADIUS migrations are NOT auto-applied after first init —
        # apply them deliberately if the daloRADIUS clone ever needs it.
        DB_DIR="${daloradiusDir}/contrib/db"
        if [ -d "$DB_DIR" ]; then
          if ! ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb -e 'SELECT 1 FROM operators' >/dev/null 2>&1; then
            echo "First init: loading daloRADIUS schemas..."
            [ -f "$DB_DIR/mariadb-daloradius.sql" ] && \
              ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb < "$DB_DIR/mariadb-daloradius.sql" 2>/dev/null || true
            [ -f "$DB_DIR/mariadb-daloradius-dictionaries.sql" ] && \
              ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb < "$DB_DIR/mariadb-daloradius-dictionaries.sql" 2>/dev/null || true
            if [ -d "$DB_DIR/migrations" ]; then
              for f in "$DB_DIR"/migrations/*.sql; do
                [ -e "$f" ] && ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb < "$f" 2>/dev/null || true
              done
            fi
            [ -f "$DB_DIR/update-performance-indexes.sql" ] && \
              ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb < "$DB_DIR/update-performance-indexes.sql" 2>/dev/null || true
          else
            echo "daloRADIUS tables present — skipping schema load (destructive if re-run)"
          fi
        fi

        # Normalize collations: the FreeRADIUS schema creates tables with
        # the database-default collation (utf8mb4_unicode_ci here), while
        # daloRADIUS declares DEFAULT CHARSET=utf8mb4 (general_ci). The
        # GUI joins across both families (radacct.calledstationid =
        # hotspots.mac, radcheck.username = userinfo.username), and MariaDB
        # errors with "Illegal mix of collations" on those comparisons.
        # CONVERT TO is a no-op on already-converted tables, so running it
        # every boot converges both fresh and existing databases.
        for tbl in radacct radcheck radgroupcheck radgroupreply radreply radusergroup radpostauth nas; do
          ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb \
            -e "ALTER TABLE $tbl CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci" 2>/dev/null || true
        done

        # Create VLAN groups (WHERE NOT EXISTS — idempotent)
        echo "Creating VLAN groups..."
        ${pkgs.mariadb}/bin/mariadb -u raduser -p'${cfg.dbPassword}' raddb < ${groupsSql} 2>/dev/null || true

        echo "RADIUS database initialization complete."
      '';
    };
  };
}