{
  dream2nix,
}:

(dream2nix.riseAndShine {
  dreamLock = ./dream.lock;
}).package.overrideAttrs (old: {

})
