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

  # TODO: implement a user option that will make the vendoring
  # copy sources instead of symlinking them. This can be useful
  # for some Rust packages that modify their own dependencies
  # via their build hooks.
  vendorPackageDependencies = pname: version:
    let
      deps = getAllTransitiveDependencies pname version;

      makeSource = dep: {
        name = "${dep.name}-${dep.version}";
        path = getSource dep.name dep.version;
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
    '';

  buildPackage = pname: version:
    let src = getSource pname version; in
    pkgs.rustPlatform.buildRustPackage {
      inherit pname version src;

      postUnpack = ''
        ln -s ${vendorPackageDependencies mainPackageName mainPackageVersion} ./${src.name}/nix-vendor
      '';

      cargoVendorDir = "nix-vendor";
    };

  mainPkg = buildPackage mainPackageName mainPackageVersion;
in
rec {
  packages."${mainPackageName}"."${mainPackageVersion}" = mainPkg;

  defaultPackage = mainPkg;
}
