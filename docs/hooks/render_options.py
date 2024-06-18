import logging
import json
from pathlib import Path
from collections import OrderedDict
from typing import Dict, Tuple

from mkdocs.structure.pages import Page
from mkdocs.structure.files import Files
from mkdocs.config.defaults import MkDocsConfig


from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import HtmlFormatter


log = logging.getLogger("mkdocs")


def is_reference_page(page: Page) -> bool:
    return page.file.src_path.startswith("reference/")


def pygments(code: str, lang: str) -> str:
    return highlight(code, get_lexer_by_name(lang), HtmlFormatter())


def sort_options(item: Tuple[str, Dict]):
    """
    Sort the modules. First the one the page is about,
    then single options, then the rest, alphabetically
    """
    name, option = item
    if name == "pip":
        return -1
    elif len(option["children"]) == 0:
        return 0
    else:
        return ord(name[0])


def preprocess_options(options):
    tree = dict()
    for name, option in options.items():
        if name.startswith("_module"):
            continue
        cursor = tree
        parts = name.split(".")
        for index, part in enumerate(parts):
            if part not in cursor:
                if index + 1 == len(parts):
                    cursor[part] = dict(**option, children={})
                else:
                    cursor[part] = dict(children=dict())
                    cursor = cursor[part]
            else:
                cursor = cursor[part]["children"]
    return OrderedDict(sorted(tree.items(), key=sort_options))


def on_page_markdown(
    markdown: str, page: Page, config: MkDocsConfig, files: Files
) -> str | None:
    if not is_reference_page(page):
        return markdown
    src_path = Path(config.docs_dir) / page.file.src_path
    env = config.theme.get_env()
    env.filters["pygments"] = pygments

    header = env.get_template("reference_header.html").render(meta=page.meta)

    options_path = src_path.parent / "options.json"
    if not options_path.exists():
        log.error(f"{options_path} does not exist")
        return None
    with open(options_path, "r") as f:
        options = preprocess_options(json.load(f))
    reference = env.get_template("reference_options.html").render(options=options)

    return "\n\n".join([header, markdown, reference])
