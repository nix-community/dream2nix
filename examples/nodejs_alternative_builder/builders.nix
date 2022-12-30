{dream2nix}: {config, ...}: {
  builders.nodejs = {...}: {
    name = "nodejs-strict-builder";
    subsystem = "nodejs";
    imports = [(attrs: import "${dream2nix}/src/subsystems/nodejs/builders/strict-builder" attrs.framework)];
  };
}
