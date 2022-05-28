# Extending dream2nix with external translators, builders etc.

`dream2nix` can be extended while you are `init`ializing it.
This can be done in a few ways. For extending, you need to
utilize the `config.extra` option of the dream2nix config.

## Declare `extra`s from a nix file

```nix
dream2nix.lib.init {
  # this also works around errors with function modules
  # being declared here, which will be explained later.
  config.extra = ./nix/d2n/extras.nix;
}
```
this file should look like this:
```nix
{dlib, lib, config, ...}:
{
  subsystems.rust.translators.new = ./rust-translator.nix;
  # you can declare modules using functions here
  fetchers.ipfs = {...}: {/* fetcher attrs */};
}
```

See the [`d2n-extended-new-subsystem` example](../examples/d2n-extended-new-subsystem) for a basic example.

## Declare `extra`s as an attribute set

```nix
dream2nix.lib.init {
  config.extra = {
    subsystems = {
      # add new modules
      ruby.discoverers.default = ./nix/d2n/ruby/discoverer.nix;
      ruby.translators.bundix = ./nix/d2n/ruby/bundix.nix;
      # existing modules can be overridden
      rust.builders.crane = ./nix/d2n/rust/crane.nix;
    };
    # add new fetchers
    fetchers.ipfs = ./nix/d2n/fetchers/ipfs.nix;
    fetchers.gitea = ./nix/d2n/fetchers/gitea.nix;
    # existing fetchers can be overridden
    fetchers.http = ./nix/d2n/fetchers/http-proxied.nix;
  };
}
```

note: you can't declare modules using functions here. This is
because the `config` may need to be serialized to JSON and passed
around in impure situations (mostly impure translators).

See the [`d2n-extended` example](../examples/d2n-extended/flake.nix) for a basic example.

## Compose multiple different `extra`s

This allows one to compose multiple `extra`s together with ease.
The `dream2nixExtras` flake output in this case can be any of the
approaches explained in this document for declaring `config.extra`.

```nix
dream2nix.lib.init {
  # note: .dream2nixExtras is a hypothetical standardized flake output
  # in practice this can be any flake output.
  config.extra = [
    haskellSubsystemFlake.dream2nixExtras
    crystalSubsystemFlake.dream2nixExtras
    gleamSubsystemFlake.dream2nixExtras
  ];
}
```
