{
  curl,
  gnugrep,
  jq,
  lib,
  python3,
  writeText,
  # dream2nix inputs
  callPackageDream,
  fetchers,
  utils,
  ...
}: let
  lockUtils = utils.dreamLock;

  updaters = callPackageDream ./updaters.nix {};

  getUpdaterName = {dreamLock}: let
    lock = (utils.readDreamLock {inherit dreamLock;}).lock;
    source = lockUtils.getMainPackageSource lock;
  in
    lock.updater
    or fetchers.fetchers."${source.type}".defaultUpdater
    or null;

  makeUpdateScript = {
    dreamLock,
    updater ? getUpdaterName {inherit dreamLock;},
  }: let
    lock = (utils.readDreamLock {inherit dreamLock;}).lock;
    source = lockUtils.getMainPackageSource lock;
    updater' = updaters."${updater}";
  in
    updater' source;
in {
  inherit getUpdaterName makeUpdateScript updaters;
}
