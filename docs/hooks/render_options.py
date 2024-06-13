import logging
import json
from pathlib import Path

from mkdocs.structure.pages import Page
from mkdocs.structure.files import Files
from mkdocs.config.defaults import MkDocsConfig


log = logging.getLogger("mkdocs")


def is_reference_page(page: Page) -> bool:
    return page.file.src_path.startswith("reference/")


def slugify(name: str) -> str:
    return name.lower().replace(".", "-")


def preprocess_options(options):
    tree = {}
    for name, option in options.items():
        if name.startswith("_module"):
            continue
        cursor = tree
        parts = name.split(".")
        for index, part in enumerate(parts):
            if part not in cursor:
                if index + 1 == len(parts):
                    cursor[part] = option
                else:
                    cursor[part] = dict()
                    cursor = cursor[part]
            else:
                cursor = cursor[part]

    return tree


def on_page_markdown(
    markdown: str, page: Page, config: MkDocsConfig, files: Files
) -> str | None:
    if not is_reference_page(page):
        return markdown

    src_path = Path(config.docs_dir) / page.file.src_path
    options_path = src_path.parent / "options.json"
    if not options_path.exists():
        log.error(f"{options_path} does not exist")

    env = config.theme.get_env()
    env.filters["slugify"] = slugify
    options_template = env.get_template("reference_options.html")
    with open(options_path, "r") as f:
        options = json.load(f)

    tree = preprocess_options(options)
    rendered = options_template.render(options=tree)
    return markdown + rendered
