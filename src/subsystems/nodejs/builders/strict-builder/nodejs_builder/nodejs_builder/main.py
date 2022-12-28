from .lib.checks import check_platform
from .lib.module import is_main_package
from .lib.node_modules import create_node_modules
from .lib.package import get_package_json, has_scripts


def check():
    """
    Checks if the package can be installed.
    - platform must have compatible: os + cpu
    """
    if not check_platform():
        exit(3)


def d2nNodeModules():
    """
    generate the node_modules folder.
    - on main packages
    - on packages with scripts that could need them
    """
    package_json = get_package_json()
    if is_main_package() or has_scripts(package_json):
        create_node_modules()
