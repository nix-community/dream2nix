#!@python3@/bin/python3

# - identify the root by searching for the marker config.paths.projectRootFile in the current dir and parents
# - if the marker file is not found, raise an error

import os


def find_root():
    marker = "@projectRootFile@"
    path = os.getcwd()
    while True:
        if os.path.exists(os.path.join(path, marker)):
            return path
        newpath = os.path.dirname(path)
        if newpath == path:
            raise Exception(
                f"Could not find root directory (marker file: {marker})\n"
                "Ensure that paths.projectRoot and paths.projectRootFile are set correctly and you are working somewhere within the project directory."
            )
        path = newpath


if __name__ == "__main__":
    print(find_root())
