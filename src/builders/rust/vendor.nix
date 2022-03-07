{
  lib,
  pkgs,
  getRoot,
  getSource,
  getSourceSpec,
  getDependencies,
  getCyclicDependencies,
  subsystemAttrs,
  ...
}: let
  l = lib // builtins;

  isCyclic = cyclic: dep:
    l.any (odep: dep.name == odep.name && dep.version == odep.version) cyclic;

  getUncyclicDependencies = cyclic: deps:
    l.map
    (dep: getAllTransitiveDependencies dep.name dep.version)
    (l.filter (dep: !(isCyclic cyclic dep)) deps);

  getAllTransitiveUncyclicDependencies = pname: version: let
    cyclic = getCyclicDependencies pname version;
    direct = getDependencies pname version;
  in
    l.unique (l.flatten (direct ++ (getUncyclicDependencies cyclic direct)));

  getAllTransitiveDependencies = pname: version: let
    direct = getDependencies pname version;
    cyclic = getCyclicDependencies pname version;
  in
    l.unique (l.flatten (
      direct
      ++ (getUncyclicDependencies cyclic direct)
      ++ (
        l.map
        (dep: getAllTransitiveUncyclicDependencies dep.name dep.version)
        (l.filter (isCyclic cyclic) direct)
      )
    ));
in rec {
  # Generates a shell script that writes git vendor entries to .cargo/config.
  # `replaceWith` is the name of the vendored source(s) to use.
  writeGitVendorEntries = replaceWith: let
    makeEntry = source: ''
      [source."${source.url}${l.optionalString (source ? type) "?${source.type}=${source.value}"}"]
      replace-with = "${replaceWith}"
      git = "${source.url}"
      ${l.optionalString (source ? type) "${source.type} = \"${source.value}\""}
    '';
    entries = l.map makeEntry subsystemAttrs.gitSources;
  in ''
    mkdir -p $CARGO_HOME && touch $CARGO_HOME/config.toml
    cat >> $CARGO_HOME/config.toml <<EOF
    ${l.concatStringsSep "\n" entries}
    EOF
  '';

  # Vendor a package's dependencies like how `cargo vendor` would do,
  # so we can use it with `cargo`.
  vendorPackageDependencies = pname: version: let
    deps = getAllTransitiveDependencies pname version;

    makeSource = dep: let
      path = getSource dep.name dep.version;
      spec = getSourceSpec dep.name dep.version;
    in {
      inherit path spec dep;
      name = "${dep.name}-${dep.version}";
    };
    sources = l.map makeSource deps;

    findCrateSource = source: let
      inherit (pkgs) cargo jq;
      pkg = source.dep;
    in ''
      # If the target package is in a workspace, or if it's the top-level
      # crate, we should find the crate path using `cargo metadata`.
      crateCargoTOML=$(${cargo}/bin/cargo metadata --format-version 1 --no-deps --manifest-path $tree/Cargo.toml | \
        ${jq}/bin/jq -r '.packages[] | select(.name == "${pkg.name}") | .manifest_path')
      # If the repository is not a workspace the package might be in a subdirectory.
      if [[ -z $crateCargoTOML ]]; then
        for manifest in $(find $tree -name "Cargo.toml"); do
          echo Looking at $manifest
          crateCargoTOML=$(${cargo}/bin/cargo metadata --format-version 1 --no-deps --manifest-path "$manifest" | ${jq}/bin/jq -r '.packages[] | select(.name == "${pkg.name}") | .manifest_path' || :)
          if [[ ! -z $crateCargoTOML ]]; then
            break
          fi
        done
        if [[ -z $crateCargoTOML ]]; then
          >&2 echo "Cannot find path for crate '${pkg.name}-${pkg.version}' in the tree in: $tree"
          exit 1
        fi
      fi
      echo Found crate ${pkg.name} at $crateCargoTOML
      tree="$(dirname $crateCargoTOML)"
    '';
    makeScript = source: let
      isGit = source.spec.type == "git";
      isPath = source.spec.type == "path";
    in
      l.optionalString (!isPath) ''
        tree="${source.path}"
        ${l.optionalString isGit (findCrateSource source)}
        cp -prvd "$tree" $out/${source.name}
        chmod u+w $out/${source.name}
        ${l.optionalString isGit "printf '{\"files\":{},\"package\":null}' > \"$out/${source.name}/.cargo-checksum.json\""}
      '';
  in
    pkgs.runCommand "vendor-${pname}-${version}" {} ''
      mkdir -p $out

      ${
        l.concatMapStringsSep "\n"
        makeScript
        sources
      }
    '';

  # Vendors a package's roots dependencies.
  vendorDependencies = pname: version: let
    root = getRoot pname version;
  in
    vendorPackageDependencies root.pname root.version;
}
