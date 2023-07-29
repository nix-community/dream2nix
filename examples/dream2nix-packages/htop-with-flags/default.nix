{
  config,
  lib,
  dream2nix,
  ...
}: let
  deps = config.deps;
  stdenv = deps.stdenv;
in {
  # select mkDerivation as a backend for this package
  imports = [
    dream2nix.modules.drv-parts.mkDerivation
  ];

  config = {
    deps = {nixpkgs, ...}: {
      inherit
        (nixpkgs)
        autoreconfHook
        fetchFromGitHub
        IOKit
        lm_sensors
        ncurses
        systemd
        ;
    };

    # specify flags that this package provdes
    flagsOffered = {
      sensorsSupport = "enable support for sensors";
      systemdSupport = "enable support for sensors";
    };

    # set defaults for flags
    flags = {
      sensorsSupport = lib.mkDefault stdenv.isLinux;
      systemdSupport = lib.mkDefault stdenv.isLinux;
    };

    name = "htop";
    version = "3.2.1";

    mkDerivation = {
      # set options

      src = deps.fetchFromGitHub {
        owner = "htop-dev";
        repo = config.name;
        rev = config.version;
        sha256 = "sha256-MwtsvdPHcUdegsYj9NGyded5XJQxXri1IM1j4gef1Xk=";
      };

      nativeBuildInputs = [deps.autoreconfHook];

      buildInputs =
        [deps.ncurses]
        ++ lib.optional stdenv.isDarwin deps.IOKit
        ++ lib.optional config.flags.sensorsSupport deps.lm_sensors
        ++ lib.optional config.flags.systemdSupport deps.systemd;

      configureFlags =
        ["--enable-unicode" "--sysconfdir=/etc"]
        ++ lib.optional config.flags.sensorsSupport "--with-sensors";

      postFixup = let
        optionalPatch = pred: so: lib.optionalString pred "patchelf --add-needed ${so} $out/bin/htop";
      in ''
        ${optionalPatch config.flags.sensorsSupport "${deps.lm_sensors}/lib/libsensors.so"}
        ${optionalPatch config.flags.systemdSupport "${deps.systemd}/lib/libsystemd.so"}
      '';

      meta = with lib; {
        description = "An interactive process viewer";
        homepage = "https://htop.dev";
        license = licenses.gpl2Only;
        platforms = platforms.all;
        maintainers = with maintainers; [rob relrod SuperSandro2000];
        changelog = "https://github.com/htop-dev/htop/blob/${config.version}/ChangeLog";
      };
    };
  };
}
