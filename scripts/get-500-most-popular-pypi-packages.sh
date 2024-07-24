# Source: https://hugovk.github.io/top-pypi-packages/
set -ex
pkg_names="$(curl -s https://hugovk.github.io/top-pypi-packages/top-pypi-packages-30-days.min.json \
    | jq -r '.rows[:500][] | .project' \
    | sort)";
for pkg_name in $pkg_names
do
    pkg_version="$(curl -s "https://pypi.org/pypi/$pkg_name/json" \
        | jq -r .info.version \
        )"
    echo "$pkg_name==$pkg_version"
done > 500-most-popular-pypi-packages.txt
