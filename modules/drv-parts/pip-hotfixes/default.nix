{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.pip;
  metadata = config.lock.content.fetchPipMetadata;

  ignored = l.genAttrs cfg.ignoredDependencies (name: true);

  filterTarget = target:
    l.filterAttrs (name: target: ! ignored ? ${name}) target;

  # filter out ignored dependencies
  targets = l.flip l.mapAttrs metadata.targets (
    targetName: target:
      l.flip l.mapAttrs (filterTarget target) (
        packageName: deps:
          l.filter (dep: ! ignored ? ${dep}) deps
      )
  );
  rootDependencies =
    if cfg.flattenDependencies
    then
      if targets.default ? ${config.name}
      then
        throw ''
          Top-level package ${config.name} is listed in the lockfile.
          Set `pip.flattenDependencies` to false to use only the top-level dependencies.
        ''
      else l.attrNames (targets.default)
    else if ! targets.default ? ${config.name}
    then
      throw ''
        Top-level package ${config.name} is not listed in the lockfile.
        Set `pip.flattenDependencies` to true to use all dependencies for the top-level package.
      ''
    else targets.default.${config.name};
in {
  imports = [
    ./interface.nix
  ];
  pip.targets = targets;
  pip.rootDependencies = lib.genAttrs rootDependencies (_: true);
}
