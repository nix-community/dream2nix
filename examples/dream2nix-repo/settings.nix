{config, ...}: {
  lock.repoRoot = ./.;
  lock.lockFileRel = "/locks/${config.name}.json";
}
