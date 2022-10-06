{
  config,
  callPackageDream,
  ...
}: {
  config = {
    outputsInstanced = callPackageDream config.outputs {};
  };
}
