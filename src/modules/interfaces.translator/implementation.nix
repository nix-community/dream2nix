{
  config,
  framework,
  ...
}: {
  config = {
    finalTranslate = args:
      if config.translate != null
      then
        config.translate
        (
          (framework.functions.translators.makeTranslatorDefaultArgs
            (config.extraArgs or {}))
          // args
          // (args.project.subsystemInfo or {})
          // {
            tree =
              args.tree or (framework.dlib.prepareSourceTree {inherit (args) source;});
          }
        )
      else null;
    finalTranslateBin =
      if config.translate != null
      then
        framework.functions.translators.wrapPureTranslator
        {inherit (config) subsystem name;}
      else if config.translateBin != null
      then config.translateBin
      else null;
  };
}
