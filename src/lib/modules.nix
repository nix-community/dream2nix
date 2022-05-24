{
  config,
  dlib,
  lib,
}: let
  l = lib // builtins;

  # imports a module.
  #
  # - 'file' can be a function or a path to a function.
  # - 'dlib', 'lib', 'config' and attributes in
  # 'extraArgs' are passed to the function.
  importModule = {
    file,
    validator ? _: true,
    extraArgs,
  }: let
    _module =
      if l.isFunction file
      then file
      else import file;
    module =
      if l.isFunction _module
      then _module ({inherit config dlib lib;} // extraArgs)
      else throw "module file (${file}) must return a function that takes an attrset";
  in
    l.seq (validator module) module;

  # collects extra modules from a list
  # ex: [{translators = [module1];} {translators = [module2];}] -> {translators = [module1 module2];}
  collectExtraModules =
    l.foldl'
    (acc: el:
      acc
      // (
        l.mapAttrs
        (category: modules: modules ++ (acc.${category} or []))
        el
      ))
    {};
  # processes one extra (config.extra)
  # returns extra modules like {fetchers = [...]; translators = [...];}
  processOneExtra = _extra: let
    extra =
      if l.isFunction _extra
      then _extra {inherit config dlib lib;}
      else if l.isAttrs _extra && (! _extra ? drvPath)
      then _extra
      else import _extra {inherit config dlib lib;};
    _extraSubsystemModules =
      l.mapAttrsToList
      (subsystem: categories:
        l.mapAttrs
        (category: modules:
          l.mapAttrsToList
          (name: module: {
            file = module;
            extraArgs = {inherit subsystem name;};
          })
          modules)
        categories)
      (extra.subsystems or {});
    extraSubsystemModules =
      collectExtraModules (l.flatten _extraSubsystemModules);
    extraFetcherModules =
      l.mapAttrsToList
      (name: fetcher: {
        file = fetcher;
        extraArgs = {inherit name;};
      })
      (extra.fetchers or {});
  in
    extraSubsystemModules
    // {
      fetchers = extraFetcherModules;
    };
  extra = let
    _extra = config.extra or {};
  in
    if l.isList _extra
    then
      collectExtraModules
      (l.map processOneExtra _extra)
    else processOneExtra _extra;

  # collect subsystem modules into a list
  # ex: {rust.translators.cargo-lock = cargo-lock; go.translators.gomod2nix = gomod2nix;}
  # -> [cargo-lock gomod2nix]
  collectSubsystemModules = modules: let
    allModules = l.flatten (l.map l.attrValues (l.attrValues modules));
    hasModule = module: modules:
      l.any
      (
        omodule:
          omodule.name
          == module.name
          && omodule.subsystem == module.subsystem
      )
      modules;
  in
    l.foldl'
    (
      acc: el:
        if hasModule el acc
        then acc
        else acc ++ [el]
    )
    []
    allModules;

  validateExtraModules = f: extra:
    l.foldl'
    (acc: el: l.seq (f el) acc)
    {}
    extra;
  # TODO
  validateExtraModule = extra:
    true;

  makeSubsystemModules = {
    modulesCategory,
    validator,
    extraModules ? extra.${modulesCategory} or [],
  }: let
    callModule = {
      file,
      extraArgs ? {},
    }:
      importModule {inherit file validator extraArgs;};

    importedExtraModules =
      l.map
      (
        module:
          (callModule module)
          // {inherit (module.extraArgs) subsystem name;}
      )
      extraModules;
    validatedExtraModules =
      l.seq
      (validateExtraModules validateExtraModule importedExtraModules)
      importedExtraModules;

    modules =
      l.genAttrs
      dlib.subsystems
      (
        subsystem: let
          modulesDir = ../subsystems + "/${subsystem}/${modulesCategory}";
          moduleNames =
            if l.pathExists modulesDir
            then dlib.dirNames modulesDir
            else [];

          loadModule = name: let
            extraArgs = {inherit subsystem name;};
            module = callModule {
              file = "${modulesDir}/${name}";
              inherit extraArgs;
            };
          in
            module // extraArgs;
        in
          l.filterAttrs
          (name: t: t.disabled or false == false)
          (l.genAttrs moduleNames loadModule)
      );
    modulesExtended =
      l.foldl'
      (
        acc: el:
          l.recursiveUpdate acc
          {"${el.subsystem}"."${el.name}" = el;}
      )
      modules
      validatedExtraModules;

    mapModules = f:
      l.mapAttrs
      (
        subsystem: names:
          l.mapAttrs
          (name: module: f module)
          names
      )
      modulesExtended;
  in {
    modules = modulesExtended;
    inherit
      callModule
      mapModules
      ;
  };
in {
  inherit
    importModule
    makeSubsystemModules
    collectSubsystemModules
    extra
    validateExtraModules
    ;
}
