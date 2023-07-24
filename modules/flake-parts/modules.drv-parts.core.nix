{
  self,
  lib,
  ...
}: {
  flake.modules.drv-parts.core = lib.mkForce {
    imports = [
      self.inputs.drv-parts.modules.drv-parts.core
      self.modules.drv-parts.lock
      self.modules.drv-parts.eval-cache
    ];
  };
}
