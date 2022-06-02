{
  getSourceSpec,
  getSource,
  getRoot,
  dreamLock,
  lib,
  dlib,
  utils,
  subsystemAttrs,
  writeText,
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
    rm -f "$PWD/Cargo.lock"
    cat ${cargoLock} > "$PWD/Cargo.lock"
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
          gitSpec =
            l.findFirst
            (src: src.url == sourceSpec.url && src.sha == sourceSpec.rev)
            (throw "no git source: ${sourceSpec.url}#${sourceSpec.rev}")
            (subsystemAttrs.gitSources or {});
          refPart =
            l.optionalString
            (gitSpec ? type)
            "?${gitSpec.type}=${gitSpec.value}";
        in "git+${sourceSpec.url}${refPart}#${sourceSpec.rev}"
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
    lock = utils.toTOML {inherit package;};
  in
    # on Nix 2.9.0> builtins.toFile doesn't trigger IFD
    if l.compareVersions l.nixVersion "2.9.0" >= 0
    then l.toFile "dream-lock.json" lock
    else writeText "dream-lock.json" lock;
}
