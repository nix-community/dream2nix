{
  inputs = {
    dream2nix.url = "path:../..";
  };

  outputs = {
    self,
    dream2nix,
  } @ inp:
    (dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      config.modules = [
        ./discoverers.nix
        ./translators.nix
        ./builders.nix
      ];
      source = ./.;
      # The dummy discoverer will discover a project `hello` automatically.
      autoProjects = true;
    })
    // {
      checks.x86_64-linux.hello = self.packages.x86_64-linux.hello;
    };
}
