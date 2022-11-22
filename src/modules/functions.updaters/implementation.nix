{config, ...}: let
  inherit (config) utils fetchers updaters;

  lockUtils = utils.dream-lock;

  getUpdaterName = {dreamLock}: let
    lock = (utils.dream-lock.readDreamLock {inherit dreamLock;}).lock;
    source = lockUtils.getMainPackageSource lock;
  in
    lock.updater
    or fetchers."${source.type}".defaultUpdater
    or null;

  makeUpdateScript = {
    dreamLock,
    updater ? getUpdaterName {inherit dreamLock;},
  }: let
    lock = (utils.dream-lock.readDreamLock {inherit dreamLock;}).lock;
    source = lockUtils.getMainPackageSource lock;
    updater' = updaters."${updater}";
  in
    updater' source;
in {
  config.functions.updaters = {
    inherit getUpdaterName makeUpdateScript;
  };
}
