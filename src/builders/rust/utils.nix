{
  getSourceSpec,
  getSource,
  getRoot,
  lib,
  dlib,
  ...
}: let
  l = lib // builtins;
in rec {
  # Gets the root source for a package
  getRootSource = pname: version: let
    root = getRoot pname version;
  in
    getSource root.pname root.version;

  # Generates a script that replaces relative path dependency paths with absolute
  # ones, if the path dependency isn't in the source dream2nix provides
  replaceRelativePathsWithAbsolute = {paths}: let
    replacements =
      l.concatStringsSep
      " \\\n"
      (
        l.mapAttrsToList
        (
          from: rel: ''--replace "\"${from}\"" "\"$TEMPDIR/$sourceRoot/${rel}\""''
        )
        paths
      );
  in ''
    substituteInPlace ./Cargo.toml \
      ${replacements}
  '';
}
