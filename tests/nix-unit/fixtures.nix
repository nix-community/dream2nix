{dream2nix}: rec {
  basic-derivation = named-derivation "hello";
  named-derivation = name: {
    # select builtins.derivation as a backend for this package
    imports = [
      dream2nix.modules.dream2nix.builtins-derivation
    ];

    inherit name;
    version = "1.0.0";

    # set options
    builtins-derivation = {
      builder = "/bin/sh";
      args = ["-c" "echo $name > $out"];
      system = "x86_64-linux";
    };
  };
}
