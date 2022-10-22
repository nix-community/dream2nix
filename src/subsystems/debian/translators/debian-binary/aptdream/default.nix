/*
This apt is patched so it can run inside the nix build sandbox.
By default apt refuses to execute if it does not detect a debian-like system.
The patch is a one-liner bypassing that check.
*/
{pkgs, ...}:
pkgs.apt.overrideDerivation (oldAttrs: {patches = [./apt.patch];})
