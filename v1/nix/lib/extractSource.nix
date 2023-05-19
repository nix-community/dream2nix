{
  lib,
  mkDerivation,
  ...
}: let
  l = builtins // lib;

  # TODO is this really needed? Seems to make builds slower, why not unpack + build?
  extractSource = {
    source,
    dir ? "",
    name ? null,
  } @ args:
    mkDerivation {
      name = "${(args.name or source.name or "")}-extracted";
      src = source;
      inherit dir;
      phases = ["unpackPhase"];
      dontInstall = true;
      dontFixup = true;
      # Allow to access the original output of the FOD.
      # Some builders like python require the original archive.
      passthru.original = source;
      unpackCmd =
        if l.hasSuffix ".tgz" (source.name or "${source}")
        then ''
          tar --delay-directory-restore -xf $src

          # set executable flag only on directories
          chmod -R +X .
        ''
        else null;
      # sometimes tarballs do not end with .tar.??
      preUnpack = ''
        unpackFallback(){
          local fn="$1"
          tar xf "$fn"
        }

        unpackCmdHooks+=(unpackFallback)
      '';
      postUnpack = ''
        echo postUnpack
        mv "$sourceRoot/$dir" $out
        exit
      '';
    };
in
  extractSource
