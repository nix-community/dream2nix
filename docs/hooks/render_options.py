import logging
import json
from pathlib import Path
from collections import OrderedDict
from typing import Dict, Tuple
from urllib.request import UnknownHandler

from mkdocs.structure.pages import Page
from mkdocs.structure.nav import Navigation, Section
from mkdocs.structure.files import Files
from mkdocs.config.defaults import MkDocsConfig
from mkdocs.plugins import event_priority

from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import HtmlFormatter


log = logging.getLogger("mkdocs")


def is_reference_page(page: Page) -> bool:
    return page.file.src_path.startswith("reference/")


def pygments(code: str, lang: str) -> str:
    return highlight(code, get_lexer_by_name(lang), HtmlFormatter())


def sort_options(item: Tuple[str, Dict], module_name: str) -> int:
    """
    Sort the modules. First the one the page is about,
    then single options, then the rest, alphabetically
    """
    name, option = item
    if name == module_name:
        return -1
    elif len(option["children"]) == 0:
        return 0
    else:
        return ord(name[0])


def preprocess_options(options, module_name):
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
    return OrderedDict(sorted(tree.items(), key=lambda i: sort_options(i, module_name)))


def on_page_markdown(
    markdown: str, page: Page, config: MkDocsConfig, files: Files
) -> str | None:
    """Check whether the source path starts with "reference/".
    If it does:
    - render a header template, containing values from the source markdown file
    - render the source markdown file
    - render an options.json file containing nixos option definitions from the
      same directory where the source file is found. Then render those options.
    """
    if not is_reference_page(page):
        return markdown
    src_path = Path(config.docs_dir) / page.file.src_path
    module_name = src_path.parent.stem
    env = config.theme.get_env()
    env.filters["pygments"] = pygments

    header = env.get_template("reference_header.html").render(meta=page.meta)

    options_path = src_path.parent / "options.json"
    if not options_path.exists():
        log.error(f"{options_path} does not exist")
        return None
    with open(options_path, "r") as f:
        options = preprocess_options(json.load(f), module_name)
    reference = env.get_template("reference_options.html").render(options=options)

    return "\n\n".join([header, markdown, reference])


@event_priority(-100)
def on_nav(nav: Navigation, config: MkDocsConfig, files: Files) -> Navigation | None:
    """Customize the navigation: If a reference section is found,
    filter for a "state" variable defined in a markdown files front-matter.
    Leave all items where "state" equals "released" as-is, but put
    all others in an "experimental" section below that."""
    try:
        reference_section = next(filter(lambda i: i.title == "Reference", nav.items))
        reference_index = nav.items.index(reference_section)
    except StopIteration:
        # Return the navigation as-is if we don't find
        # a reference section
        return nav

    released = []
    experimental = []
    for page in reference_section.children:
        # to have metadata from the yaml front-matter available
        page.read_source(config)
        state = page.meta.get("state")
        if state == "released":
            released.append(page)
        else:
            experimental.append(page)

    experimental_section = Section("Experimental Modules", experimental)
    reference_section.children = released + [experimental_section]

    nav.items[reference_index] = reference_section
    return nav
