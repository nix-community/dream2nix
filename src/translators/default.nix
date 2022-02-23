{
  coreutils,
  dlib,
  jq,
  lib,
  nix,
  pkgs,

  callPackageDream,
  externals,
  dream2nixWithExternals,
  utils,
  ...
}:
let

  b = builtins;

  lib = pkgs.lib;

  callTranslator = subsystem: type: name: file: args:
    let
      translatorModule = import file {
        inherit dlib lib;
      };

      translator =
        translatorModule

        # for pure translators
        #   - import the `translate` function
        #   - generate `translateBin`
        // (lib.optionalAttrs (translatorModule ? translate) {
          translate = callPackageDream translatorModule.translate (args // {
            translatorName = name;
          });
          translateBin = wrapPureTranslator [ subsystem type name ];
        })

        # for impure translators:
        #   - import the `translateBin` function
        // (lib.optionalAttrs (translatorModule ? translateBin) {
          translateBin = callPackageDream translatorModule.translateBin
            (args // {
              translatorName = name;
            });
        });

        # supply calls to translate with default arguments
        translatorWithDefaults = translator // {
          inherit subsystem type name;
          translate = args:
            translator.translate
              ((getextraArgsDefaults translator.extraArgs or {}) // args);
        };

    in
      translatorWithDefaults;


  subsystems = utils.dirNames ./.;

  translatorTypes = [ "impure" "ifd" "pure" ];

  # adds a translateBin to a pure translator
  wrapPureTranslator = translatorAttrPath:
    let
      bin = utils.writePureShellScript
        [
          coreutils
          jq
          nix
        ]
        ''
          jsonInputFile=$(realpath $1)
          outputFile=$(jq '.outputFile' -c -r $jsonInputFile)

          nix eval --show-trace --impure --raw --expr "
              let
                dream2nix = import ${dream2nixWithExternals} {};
                dreamLock =
                  dream2nix.translators.translators.${
                    lib.concatStringsSep "." translatorAttrPath
                  }.translate
                    (builtins.fromJSON (builtins.readFile '''$1'''));
              in
                dream2nix.utils.dreamLock.toJSON
                  # don't use nix to detect cycles, this will be more efficient in python
                  (dreamLock // {
                    _generic = builtins.removeAttrs dreamLock._generic [ \"cyclicDependencies\" ];
                  })
          " | jq > $outputFile
        '';
    in
      bin.overrideAttrs (old: {
        name = "translator-${lib.concatStringsSep "-" translatorAttrPath}";
      });

  # attrset of: subsystem -> translator-type -> (function subsystem translator-type)
  mkTranslatorsSet = function:
    lib.genAttrs (utils.dirNames ./.) (subsystem:
      lib.genAttrs
        (lib.filter (dir: builtins.pathExists (./. + "/${subsystem}/${dir}")) translatorTypes)
        (transType: function subsystem transType)
    );

  # attrset of: subsystem -> translator-type -> translator
  translators = mkTranslatorsSet (subsystem: type:
    lib.genAttrs (utils.dirNames (./. + "/${subsystem}/${type}")) (translatorName:
      callTranslator subsystem type translatorName (./. + "/${subsystem}/${type}/${translatorName}") {}
    )
  );

  # flat list of all translators sorted by priority (pure translators first)
  translatorsList =
    let
      list = lib.collect (v: v ? translateBin) translators;
      prio = translator:
        if translator.type == "pure" then
          0
        else if translator.type == "ifd" then
          1
        else if translator.type == "impure" then
          2
        else
          3;
    in
      b.sort
        (a: b: (prio a) < (prio b))
        list;

  # returns the list of translators including their special args
  # and adds a flag `compatible` to each translator indicating
  # if the translator is compatible to all given paths
  translatorsForInput =
    {
      inputDirectories,
      inputFiles,
    }@args:
    lib.forEach translatorsList
      (t: rec {
        inherit (t)
          name
          extraArgs
          subsystem
          type
        ;
        compatiblePaths = t.compatiblePaths args;
        compatible = compatiblePaths == args;
      });

  # also includes subdirectories of the given paths up to a certain depth
  # to check for translator compatibility
  translatorsForInputRecursive =
    {
      inputDirectories,
      depth ? 2,
    }:
    let
      listDirsRec = dir: depth:
        let
          subDirs =
            b.map
              (subdir: "${dir}/${subdir}")
              (utils.listDirs dir);
        in
          if depth == 0 then
            subDirs
          else
            subDirs
            ++
            (lib.flatten
              (map
                (subDir: listDirsRec subDir (depth -1))
                subDirs));

      dirsToCheck =
        inputDirectories
        ++
        (lib.flatten
          (map
            (inputDir: listDirsRec inputDir depth)
            inputDirectories));

    in
      lib.genAttrs
        dirsToCheck
        (dir:
          translatorsForInput {
            inputDirectories = [ dir ];
            inputFiles = [];
          }
        );


  # pupulates a translators special args with defaults
  getextraArgsDefaults = extraArgsDef:
    lib.mapAttrs
      (name: def:
        if def.type == "flag" then
          false
        else
          def.default or null
      )
      extraArgsDef;


  # return one compatible translator or throw error
  findOneTranslator =
    {
      source,
      translatorName ? null,
    }@args:
    let
      translatorsForSource = translatorsForInput {
        inputFiles = [];
        inputDirectories = [ source ];
      };

      nameFilter =
        if translatorName != null then
          (translator: translator.name == translatorName)
        else
          (translator: true);

      compatibleTranslators =
        let
          result =
            b.filter
              (t: t.compatible)
              translatorsForSource;
        in
          if result == [] then
            throw "Could not find a compatible translator for input"
          else
            result;

      translator =
        lib.findFirst
          nameFilter
          (throw ''Specified translator ${translatorName} not found or incompatible'')
          compatibleTranslators;

    in
      translator;

in
{
  inherit
    findOneTranslator
    translators
    translatorsForInput
    translatorsForInputRecursive
  ;
}
