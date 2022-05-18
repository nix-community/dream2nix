{
  getSourceSpec,
  getSource,
  getRoot,
  dreamLock,
  lib,
  dlib,
  utils,
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

  # Script to write the Cargo.lock if it doesn't already exist.
  writeCargoLock = ''
    if [ ! -f "$PWD/Cargo.lock" ]; then
      echo '${cargoLock}' > "$PWD/Cargo.lock"
    fi
  '';

  # The Cargo.lock for this dreamLock.
  cargoLock = let
    mkPkgEntry = {
      name,
      version,
      dependencies,
    }: let
      sourceSpec = getSourceSpec name version;
      source =
        if sourceSpec.type == "crates-io"
        then "registry+https://github.com/rust-lang/crates.io-index"
        else if sourceSpec.type == "git"
        then let
          ref = sourceSpec.ref or null;
          refPart =
            if l.hasPrefix "refs/heads/" ref
            then "branch=${l.removePrefix "refs/heads/" ref}"
            else if l.hasPrefix "refs/tags/" ref
            then "tag=${l.removePrefix "refs/tags/" ref}"
            else "rev=${sourceSpec.rev}";
        in "git+${sourceSpec.url}?${refPart}#${sourceSpec.rev}"
        else throw "source type '${sourceSpec.type}' not supported";
    in
      {
        inherit name version;
        dependencies =
          l.map
          (dep: "${dep.name} ${dep.version}")
          dependencies;
      }
      // (
        l.optionalAttrs
        (sourceSpec.type != "path")
        {inherit source;}
      )
      // (
        l.optionalAttrs
        (sourceSpec.type == "crates-io")
        {checksum = sourceSpec.hash;}
      );
    package = l.flatten (
      l.mapAttrsToList
      (
        name: versions:
          l.mapAttrsToList
          (
            version: dependencies:
              mkPkgEntry {inherit name version dependencies;}
          )
          versions
      )
      dreamLock.dependencies
    );
    lock = {inherit package;};
  in
    utils.toTOML lock;
}
