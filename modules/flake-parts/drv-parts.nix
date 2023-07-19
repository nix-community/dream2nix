# Re-export lib and drv-parts from `inputs.drv-parts`
{
  config,
  lib,
  inputs,
  ...
}: {
  # merge drv-parts from upstream drv-parts
  config.flake.modules.drv-parts = inputs.drv-parts.modules.drv-parts;

  # inherit lib from drv-parts
  config.flake.lib = inputs.drv-parts.lib;
}
