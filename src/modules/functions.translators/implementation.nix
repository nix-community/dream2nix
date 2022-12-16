{config, ...}: let
  lib = config.lib;

  # pupulates a translators special args with defaults
  makeTranslatorDefaultArgs = extraArgsDef:
    lib.mapAttrs
    (
      name: def:
        if def.type == "flag"
        then false
        else def.default or null
    )
    extraArgsDef;

  # adds a translateBin to a pure translator
  wrapPureTranslator = {
    subsystem,
    name,
  }: let
    inherit
      (config)
      utils
      pkgs
      dream2nixWithExternals
      dream2nixConfigFile
      ;
    bin =
      utils.writePureShellScript
      (with pkgs; [
        coreutils
        jq
        nix
        python3
      ])
      ''
        jsonInputFile=$(realpath $1)
        outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInputFile))
        pushd $TMPDIR
        nix eval \
          --option experimental-features "nix-command flakes"\
          --show-trace --impure --raw --expr "
          let
            dream2nix = import ${dream2nixWithExternals} {
              dream2nixConfig = builtins.fromJSON (
                builtins.unsafeDiscardStringContext (
                  builtins.readFile ${dream2nixConfigFile}
                )
              );
            };
            translatorArgs =
              (builtins.fromJSON
                  (builtins.unsafeDiscardStringContext (builtins.readFile '''$1''')));
            dreamLock' =
              dream2nix.translatorsBySubsystem.${subsystem}.${name}.finalTranslate
                translatorArgs;
            # simpleTranslate2 puts dream-lock in result
            dreamLock = dreamLock'.result or dreamLock';
          in
            dream2nix.utils.dream-lock.toJSON
              # don't use nix to detect cycles, this will be more efficient in python
              (dreamLock // {
                _generic = builtins.removeAttrs dreamLock._generic [ \"cyclicDependencies\" ];
              })
        " | python3 ${utils.scripts.formatDreamLock} > out
        tmpOut=$(realpath out)
        popd
        mkdir -p $(dirname $outputFile)
        cp $tmpOut $outputFile
      '';
  in
    bin.overrideAttrs (old: {
      name = "translator-${subsystem}-pure-${name}";
    });
in {
  functions.translators = {
    inherit
      makeTranslatorDefaultArgs
      wrapPureTranslator
      ;
  };
}
