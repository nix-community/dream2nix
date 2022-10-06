{
  config,
  framework,
  ...
}: {
  config = {
    translateInstanced = args:
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
      );
    translateBin =
      framework.functions.translators.wrapPureTranslator
      {inherit (config) subsystem name;};
  };
}
