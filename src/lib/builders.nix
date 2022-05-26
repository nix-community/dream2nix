{
  dlib,
  lib,
  config,
}: let
  l = lib // builtins;

  defaults = {
    rust = "build-rust-package";
    nodejs = "granular";
    python = "simple-builder";
  };

  ifdWarnMsg = builder: ''
    the builder you are using (`${builder.subsystem}.${builder.name}`)
    uses IFD (https://nixos.wiki/wiki/Glossary) and this *might* cause issues
    (for example, `nix flake show` not working). if you are aware of this and
    don't wish to see this message, set `config.disableIfdWarning` to `true`
    in `dream2nix.lib.init` (or similar functions that take `config`).
  '';
  ifdWarningEnabled = ! (config.disableIfdWarning or false);
  warnIfIfd = builder: val:
    l.warnIf
    (ifdWarningEnabled && builder.type == "ifd")
    (ifdWarnMsg builder)
    val;

  # TODO
  validator = module: true;

  modules = dlib.modules.makeSubsystemModules {
    inherit validator defaults;
    modulesCategory = "builders";
  };
in {
  inherit warnIfIfd;
  callBuilder = modules.callModule;
  mapBuilders = modules.mapModules;
  builders = modules.modules;
}
