## Install nix
If you don't have nix already, check out [nixos.org/download.html](https://nixos.org/download.html) on how to install it.

### Enable the nix flakes feature
For internal dependency management dream2nix requires the experimental nix feature `flakes` being enabled.
```
export NIX_CONFIG="extras-experimental-features = flakes nix-command"
```

If you find yourself using dream2nix regularly, you can permanently save these settings by adding the following line to your `/etc/nix/nix.conf`:
```
experimental-features = flakes nix-command
```
