# initialize pure translator
mkdir -p $dream2nix/src/subsystems/$subsystem/translators/$pureTranslator
cp $dream2nix/src/templates/translators/pure.nix $dream2nix/src/subsystems/$subsystem/translators/$pureTranslator/default.nix

# initialize builder
mkdir -p $dream2nix/src/subsystems/$subsystem/builders/$builder
cp $dream2nix/src/templates/builders/default.nix $dream2nix/src/subsystems/$subsystem/builders/$builder/default.nix
