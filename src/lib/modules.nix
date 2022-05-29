{
  config,
  dlib,
  lib,
}: let
  l = lib // builtins;

  configFuncMsg = ''
    consider passing a path to a file instead of a function:
    functions can't be encoded to JSON, and as such most features of
    dream2nix won't work because of this since they require passing around
    the config as JSON.
  '';

  # imports a module.
  #
  # - 'file' can be a function or a path to a function.
  # - 'dlib', 'lib', 'config' and attributes in
  # 'extraArgs' are passed to the function.
  importModule = {
    file,
    validator ? _: true,
    extraArgs ? {},
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
    isAttrs = val: l.isAttrs val && (! val ? drvPath);
    # imports a modules declaration
    importDecl = decl:
      if l.isFunction decl
      then l.throw configFuncMsg (decl {inherit config dlib lib;})
      else if isAttrs decl
      then decl
      else import decl {inherit config dlib lib;};
    # extra attrset itself
    # config.extra is imported here if it's a path
    extra = importDecl _extra;
    # warn user if they are declaring a module as a function
    throwIfModuleNotPath = module:
      l.throwIf ((isAttrs _extra) && (l.isFunction module)) configFuncMsg module;
    # collect subsystem modules (translators, discoverers, builders)
    _extraSubsystemModules =
      l.mapAttrsToList
      (subsystem: categories:
        l.mapAttrs
        (category: modules:
          l.mapAttrsToList
          (name: module: {
            file = throwIfModuleNotPath module;
            extraArgs = {inherit subsystem name;};
          })
          (importDecl modules))
        categories)
      (importDecl (extra.subsystems or {}));
    extraSubsystemModules =
      collectExtraModules (l.flatten _extraSubsystemModules);
    # collect fetcher modules
    extraFetcherModules =
      l.mapAttrsToList
      (name: fetcher: {
        file = throwIfModuleNotPath fetcher;
        extraArgs = {inherit name;};
      })
      (importDecl (extra.fetchers or {}));
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

  mapSubsystemModules = f: modules:
    l.mapAttrs
    (
      subsystem: names:
        l.mapAttrs
        (name: module: f module)
        names
    )
    modules;

  # collect subsystem modules into a list
  # ex: {rust.translators.cargo-lock = cargo-lock; go.translators.gomod2nix = gomod2nix;}
  # -> [cargo-lock gomod2nix]
  collectSubsystemModules = modules: let
    allModules = l.flatten (l.map l.attrValues (l.attrValues modules));
    hasModule = module: modules:
      l.any
      (
        omodule:
          (omodule.name == module.name)
          && (omodule.subsystem == module.subsystem)
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

  # create subsystem modules
  # returns ex: {rust = {moduleName = module;}; go = {moduleName = module;};}
  makeSubsystemModules = {
    modulesCategory,
    validator,
    extraModules ? extra.${modulesCategory} or [],
    defaults ? {},
  }: let
    callModule = {
      file,
      extraArgs ? {},
    }:
      importModule {inherit file validator extraArgs;};

    # import the extra modules
    importedExtraModules =
      l.map
      (
        module:
          (callModule module)
          // {inherit (module.extraArgs) subsystem name;}
      )
      extraModules;

    # import builtin modules from subsystems directory
    modulesBuiltin =
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
          modulesLoaded = l.genAttrs moduleNames loadModule;
        in
          l.filterAttrs (name: t: t.disabled or false == false) modulesLoaded
      );
    # extend the builtin modules with the extra modules
    modulesExtended =
      l.foldl'
      (
        acc: el:
          l.recursiveUpdate acc
          {"${el.subsystem}"."${el.name}" = el;}
      )
      modulesBuiltin
      importedExtraModules;
    # add default module attribute to a subsystem if declared in `defaults`
    modules =
      l.mapAttrs
      (
        subsystem: modules:
          if l.hasAttr subsystem defaults
          then modules // {default = modules.${defaults.${subsystem}};}
          else modules
      )
      modulesExtended;
    mapModules = f: mapSubsystemModules f modules;
  in {
    inherit
      callModule
      mapModules
      modules
      ;
  };
in {
  inherit
    importModule
    makeSubsystemModules
    collectSubsystemModules
    mapSubsystemModules
    extra
    ;
}
