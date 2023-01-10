from pathlib import Path
from .derivation import get_env

# root is used to create the node_modules structure
# might default to $out,
# which will create the node_modules directly in
# $out of the derivation, and saves copy time
root = Path(get_env("out"))
bin_dir = root / Path(".bin")
