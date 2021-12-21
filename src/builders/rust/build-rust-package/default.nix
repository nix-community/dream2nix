{
  lib,
  pkgs,

  ...
}:

{
  subsystemAttrs,
  mainPackageName,
  mainPackageVersion,
  getCyclicDependencies,
  getDependencies,
  getSource,
  produceDerivation,

  ...
}@args:

let
  l = lib // builtins;

  getAllDependencies = pname: version:
    (args.getDependencies pname version)
    ++ (args.getCyclicDependencies pname version);

  getAllTransitiveDependencies = pname: version:
    let direct = getAllDependencies pname version; in
    l.unique (l.flatten (
      direct ++ (l.map (dep: getAllTransitiveDependencies dep.name dep.version) direct)
    ));

  # TODO: this is shared between the translator and this builder
  # we should dedup this somehow (maybe put in a common library for Rust subsystem?)
  recurseFiles = path:
    l.flatten (
      l.mapAttrsToList
      (n: v: if v == "directory" then recurseFiles "${path}/${n}" else "${path}/${n}")
      (l.readDir path)
    );
  getAllFiles = dirs: l.flatten (l.map recurseFiles dirs);
  getCargoTomlPaths = l.filter (path: l.baseNameOf path == "Cargo.toml");
  getCargoTomls = l.map (path: { inherit path; value = l.fromTOML (l.readFile path); });
  getCargoPackages = l.filter (toml: l.hasAttrByPath [ "package" "name" ] toml.value);
  findCratePath = cargoPackages: name:
    l.dirOf (
      l.findFirst
      (toml: toml.value.package.name == name)
      (throw "could not find crate ${name}")
      cargoPackages
    ).path;
  
  # TODO: implement a user option that will make the vendoring
  # copy sources instead of symlinking them. This can be useful
  # for some Rust packages that modify their own dependencies
  # via their build hooks.
  vendorPackageDependencies = pname: version:
    let
      deps = getAllTransitiveDependencies pname version;

      makeSource = dep:
        let
          # These locate the actual path of the crate in the source...
          # This is important because git dependencies may or may not be in a
          # workspace with complex crate hierarchies. This can locate the crate
          # accurately using Cargo.toml files.
          srcPath = getSource dep.name dep.version;
          cargoPackages = l.pipe [ srcPath ] [ getAllFiles getCargoTomlPaths getCargoTomls getCargoPackages ];
          path = findCratePath cargoPackages dep.name;
        in {
          name = "${dep.name}-${dep.version}";
          inherit path;
        };
      sources = l.map makeSource deps;
    in
    pkgs.runCommand "vendor-${pname}-${version}" {} ''
      mkdir -p $out

      ${
        l.concatMapStringsSep "\n"
        (source: "ln -s ${source.path} $out/${source.name}")
        sources
       }

      ls -l $out
    '';

  buildPackage = pname: version:
    let src = getSource pname version; in
    produceDerivation pname (pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      postUnpack = ''
        ln -s ${vendorPackageDependencies pname version} ./nix-vendor
      '';

      cargoVendorDir = "../nix-vendor";
    });
in
rec {
  packages =
    l.listToAttrs (
      l.map ({ name, version }: {
        inherit name;
        value = {
          ${version} = buildPackage name version;
        };
      }) subsystemAttrs.packages
    );

  defaultPackage = packages."${mainPackageName}"."${mainPackageVersion}";
}