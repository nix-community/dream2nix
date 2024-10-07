{
  dream2nix,
  pkgs,
  config,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation-mixin
    dream2nix.modules.dream2nix.core
  ];
  deps = {nixpkgs, ...}: {
    foo = nixpkgs.hello.overrideAttrs (old: {
      pname = "foo";
      phases = ["buildPhase"];
      buildPhase = "echo -n hello > $out";
    });
  };
  name = "test";
  version = "0.0.0";
  phases = ["buildPhase"];
  buildPhase = ''
    # explicit package
    echo ${pkgs.foo} >> $out
    # implicit package
    echo ${pkgs.hello} >> $out

    if [ "${pkgs.foo}" != "${config.deps.foo}" ]; then
      echo "foo mismatch: ${pkgs.foo} != ${config.deps.foo}" >&2
      exit 1
    fi
  '';
}
