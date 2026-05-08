#!/usr/bin/env python3
from __future__ import annotations

import io
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from pathlib import Path
from urllib.parse import urlparse
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
SITE_ROOT = ROOT / "joeyslime.com"
SITE_URL = "https://joeyslime.com"
SITEMAP_PATH = SITE_ROOT / "sitemap.xml"
ROBOTS_PATH = SITE_ROOT / "robots.txt"
SITEMAP_NAMESPACE = "http://www.sitemaps.org/schemas/sitemap/0.9"

EXPECTED_INDEXABLE_PATHS = [
    "/",
    "/play/",
    "/shop/",
    "/world/",
    "/devlog/",
    "/wiki/",
    "/wiki/mechanics/",
    "/wiki/enemies/",
    "/wiki/items/",
    "/wiki/progression/",
    "/media/",
    "/about/",
    "/faq/",
]

UTILITY_NOINDEX_PATHS = {
    "/reward/",
    "/web_demo/",
}

ROBOTS_DISALLOW_PATHS = [
    "/web_demo/",
    "/index_old.html",
    "/wiki/bat/",
]

SITEMAP_ORDER = {
    path: index
    for index, path in enumerate(
        [
            "/",
            "/play/",
            "/shop/",
            "/world/",
            "/devlog/",
            "/wiki/",
            "/wiki/mechanics/",
            "/wiki/enemies/",
            "/wiki/items/",
            "/wiki/progression/",
            "/media/",
            "/about/",
            "/faq/",
        ]
    )
}


@dataclass(frozen=True)
class PageMeta:
    path: str
    file: Path
    title: str
    description: str
    canonical: str
    robots: str
    h1_count: int
    indexable: bool
    lastmod: str | None


def main() -> None:
    pages = discover_pages()
    validate_pages(pages)
    write_text(SITEMAP_PATH, build_sitemap(pages))
    write_text(ROBOTS_PATH, build_robots())


def discover_pages() -> list[PageMeta]:
    pages: list[PageMeta] = []
    for file in sorted(SITE_ROOT.rglob("index.html")):
        path = route_from_file(file)
        html = file.read_text(encoding="utf-8")
        robots = extract_meta_content(html, "robots")
        indexable = path not in UTILITY_NOINDEX_PATHS and "noindex" not in robots.lower()
        pages.append(
            PageMeta(
                path=path,
                file=file,
                title=extract_title(html),
                description=extract_meta_content(html, "description"),
                canonical=extract_canonical(html),
                robots=robots,
                h1_count=count_tag_occurrences(html, "h1"),
                indexable=indexable,
                lastmod=resolve_lastmod(file),
            )
        )
    return pages


def route_from_file(file: Path) -> str:
    relative = file.relative_to(SITE_ROOT)
    if relative == Path("index.html"):
        return "/"
    return f"/{'/'.join(relative.parts[:-1])}/"


def extract_title(html: str) -> str:
    match = re.search(r"<title>(.*?)</title>", html, flags=re.IGNORECASE | re.DOTALL)
    if not match:
        return ""
    return normalize_text(unescape(match.group(1)))


def extract_meta_content(html: str, name: str) -> str:
    for tag in re.findall(r"<meta\b[^>]*>", html, flags=re.IGNORECASE):
        meta_name = extract_attribute(tag, "name")
        if meta_name and meta_name.lower() == name.lower():
            return normalize_text(unescape(extract_attribute(tag, "content")))
    return ""


def extract_canonical(html: str) -> str:
    for tag in re.findall(r"<link\b[^>]*>", html, flags=re.IGNORECASE):
        rel = extract_attribute(tag, "rel")
        if not rel:
            continue
        rel_tokens = {token.strip().lower() for token in rel.split()}
        if "canonical" in rel_tokens:
            return normalize_text(extract_attribute(tag, "href"))
    return ""


def extract_attribute(tag: str, attribute: str) -> str:
    match = re.search(
        rf"""\b{re.escape(attribute)}\s*=\s*(?:"([^"]*)"|'([^']*)')""",
        tag,
        flags=re.IGNORECASE,
    )
    if not match:
        return ""
    return match.group(1) or match.group(2) or ""


def count_tag_occurrences(html: str, tag_name: str) -> int:
    return len(re.findall(rf"<{re.escape(tag_name)}\b", html, flags=re.IGNORECASE))


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


def resolve_lastmod(file: Path) -> str | None:
    git_path = file.relative_to(ROOT).as_posix()
    if is_dirty_path(git_path):
        timestamp = datetime.fromtimestamp(file.stat().st_mtime, tz=timezone.utc)
        return timestamp.date().isoformat()

    result = subprocess.run(
        ["git", "-C", str(ROOT), "log", "-1", "--format=%cs", "--", git_path],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
        return result.stdout.strip()

    timestamp = datetime.fromtimestamp(file.stat().st_mtime, tz=timezone.utc)
    return timestamp.date().isoformat()


def is_dirty_path(git_path: str) -> bool:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain", "--", git_path],
        capture_output=True,
        text=True,
        check=False,
    )
    return bool(result.stdout.strip())


def validate_pages(pages: list[PageMeta]) -> None:
    issues: list[str] = []
    pages_by_path = {page.path: page for page in pages}
    site_host = urlparse(SITE_URL).netloc

    for expected_path in EXPECTED_INDEXABLE_PATHS:
        page = pages_by_path.get(expected_path)
        if page is None:
            issues.append(f"Fehlende erwartete Seite: {expected_path}")
            continue
        if not page.indexable:
            issues.append(f"Erwartete indexierbare Seite ist nicht indexierbar: {expected_path}")
        if is_disallowed_in_robots(expected_path):
            issues.append(f"Erwartete indexierbare Seite ist in robots.txt blockiert: {expected_path}")

    title_to_paths: dict[str, list[str]] = {}
    description_to_paths: dict[str, list[str]] = {}
    canonical_to_paths: dict[str, list[str]] = {}

    for page in pages:
        if page.path in UTILITY_NOINDEX_PATHS and "noindex" not in page.robots.lower():
            issues.append(f"Utility-Seite sollte noindex sein: {page.path}")

        if not page.indexable:
            continue

        expected_canonical = f"{SITE_URL}{page.path}"
        parsed_canonical = urlparse(page.canonical)

        if not page.title:
            issues.append(f"Fehlender <title>: {page.path}")
        if not page.description:
            issues.append(f"Fehlende Meta Description: {page.path}")
        if not page.robots:
            issues.append(f"Fehlendes Robots-Meta-Tag: {page.path}")
        if "noindex" in page.robots.lower():
            issues.append(f"Indexierbare Seite steht auf noindex: {page.path}")
        if page.h1_count != 1:
            issues.append(f"Seite braucht genau eine H1 ({page.h1_count} gefunden): {page.path}")
        if page.canonical != expected_canonical:
            issues.append(
                f"Canonical stimmt nicht mit Live-URL ueberein: {page.path} -> {page.canonical or '(leer)'}"
            )
        if parsed_canonical.netloc and parsed_canonical.netloc != site_host:
            issues.append(f"Canonical zeigt auf falschen Host: {page.path} -> {page.canonical}")

        if page.title:
            title_to_paths.setdefault(page.title, []).append(page.path)
        if page.description:
            description_to_paths.setdefault(page.description, []).append(page.path)
        if page.canonical:
            canonical_to_paths.setdefault(page.canonical, []).append(page.path)

    issues.extend(find_duplicates("Duplicate Title", title_to_paths))
    issues.extend(find_duplicates("Duplicate Description", description_to_paths))
    issues.extend(find_duplicates("Duplicate Canonical", canonical_to_paths))

    if issues:
        message = "\n".join(f"- {issue}" for issue in issues)
        raise SystemExit(f"SEO-Validierung fehlgeschlagen:\n{message}")


def find_duplicates(label: str, grouped_values: dict[str, list[str]]) -> list[str]:
    issues: list[str] = []
    for value, paths in grouped_values.items():
        if len(paths) < 2:
            continue
        issues.append(f"{label}: {value!r} auf {', '.join(sorted(paths))}")
    return issues


def is_disallowed_in_robots(path: str) -> bool:
    return any(path == blocked or path.startswith(blocked.rstrip("/") + "/") for blocked in ROBOTS_DISALLOW_PATHS)


def build_sitemap(pages: list[PageMeta]) -> str:
    urlset = ET.Element("urlset", {"xmlns": SITEMAP_NAMESPACE})
    for page in sorted((page for page in pages if page.indexable), key=sitemap_sort_key):
        url = ET.SubElement(urlset, "url")
        ET.SubElement(url, "loc").text = f"{SITE_URL}{page.path}"
        if page.lastmod:
            ET.SubElement(url, "lastmod").text = page.lastmod

    tree = ET.ElementTree(urlset)
    ET.indent(tree, space="  ")
    buffer = io.BytesIO()
    tree.write(buffer, encoding="utf-8", xml_declaration=True)
    xml = buffer.getvalue().decode("utf-8")
    xml = xml.replace(
        "<?xml version='1.0' encoding='utf-8'?>",
        '<?xml version="1.0" encoding="UTF-8"?>',
        1,
    )
    if not xml.endswith("\n"):
        xml += "\n"
    return xml


def sitemap_sort_key(page: PageMeta) -> tuple[int, str]:
    return (SITEMAP_ORDER.get(page.path, 999), page.path)


def build_robots() -> str:
    lines = [
        "User-agent: *",
        "Allow: /",
        *[f"Disallow: {path}" for path in ROBOTS_DISALLOW_PATHS],
        "",
        f"Sitemap: {SITE_URL}/sitemap.xml",
        "",
    ]
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
