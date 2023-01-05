from pathlib import Path
from .derivation import env

root = Path("/build")
node_modules = root / Path("node_modules")
bin_dir = node_modules / Path(".bin")
