#!/usr/bin/env python3
"""Pack JumpServer Client plugins into .jscplugin ZIP archives.

Default: every plugins/{macos,windows,linux}/*/ directory that has manifest.json.
Pass plugin directories to pack only those (demo plugins, local experiments).
"""
from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "dist" / "plugins"
SKIP_NAMES = {".DS_Store", "Thumbs.db"}
PLATFORMS = ("macos", "windows", "linux")


def read_manifest(plugin_dir: Path) -> dict:
    path = plugin_dir / "manifest.json"
    if not path.is_file():
        raise SystemExit(f"missing manifest.json: {plugin_dir}")
    data = json.loads(path.read_text(encoding="utf-8"))
    plugin_id = str(data.get("id") or "").strip()
    version = str(data.get("version") or "").strip()
    if not plugin_id or not version:
        raise SystemExit(f"manifest.json must have id and version: {path}")
    if "/" in plugin_id or "\\" in plugin_id:
        raise SystemExit(f"invalid plugin id '{plugin_id}'")
    return data


def packed_manifest_bytes(data: dict) -> bytes:
    packed = dict(data)
    packed["builtin"] = False
    return (json.dumps(packed, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def archive_name(manifest: dict) -> str:
    return f"{manifest['id']}@{manifest['version']}.jscplugin"


def iter_files(plugin_dir: Path):
    for path in sorted(plugin_dir.rglob("*")):
        if not path.is_file() or path.name in SKIP_NAMES:
            continue
        yield path, path.relative_to(plugin_dir).as_posix()


def pack_plugin(plugin_dir: Path, out_dir: Path) -> Path:
    plugin_dir = plugin_dir.resolve()
    if not plugin_dir.is_dir():
        raise SystemExit(f"plugin directory not found: {plugin_dir}")
    manifest = read_manifest(plugin_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / archive_name(manifest)
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as zf:
        for path, rel in iter_files(plugin_dir):
            info = zipfile.ZipInfo(rel)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (path.stat().st_mode & 0xFFFF) << 16
            payload = packed_manifest_bytes(manifest) if path.name == "manifest.json" else path.read_bytes()
            zf.writestr(info, payload)
    return dest


def discover_platform_plugins() -> list[Path]:
    found = []
    for platform in PLATFORMS:
        for plugin_dir in sorted((ROOT / "plugins" / platform).glob("*")):
            if plugin_dir.is_dir() and (plugin_dir / "manifest.json").is_file():
                found.append(plugin_dir)
    return found


def verify_archive(path: Path, expected_id: str | None = None) -> None:
    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
        if "manifest.json" not in names:
            raise SystemExit(f"{path.name}: archive root must contain manifest.json, got {names}")
        if any(name.startswith("..") or name.startswith("/") for name in names):
            raise SystemExit(f"{path.name}: unsafe archive paths")
        manifest = json.loads(zf.read("manifest.json"))
        if expected_id and manifest.get("id") != expected_id:
            raise SystemExit(f"{path.name}: expected id {expected_id}, got {manifest.get('id')}")
        if manifest.get("builtin") is not False:
            raise SystemExit(f"{path.name}: packed manifest must set builtin=false")
        if "connect.json" not in names:
            raise SystemExit(f"{path.name}: missing connect.json")


def self_check() -> None:
    import tempfile

    tmp = Path(tempfile.mkdtemp(prefix="jscplugin-"))
    samples = [
        ROOT / "plugins" / "macos" / "macos.warp",
        ROOT / "plugins" / "demo" / "hello-terminal",
    ]
    for plugin_dir in samples:
        dest = pack_plugin(plugin_dir, tmp)
        verify_archive(dest, json.loads((plugin_dir / "manifest.json").read_text(encoding="utf-8"))["id"])
    print("pack-client-plugins self-check ok")


def artifact_name(filename: str) -> str:
    # GitHub Actions artifact names cannot contain @.
    return filename.replace("@", "-")


def ci_matrix() -> list[dict[str, str]]:
    items = []
    names = set()
    artifacts = set()
    for plugin_dir in discover_platform_plugins():
        name = archive_name(read_manifest(plugin_dir))
        artifact = artifact_name(name)
        if name in names:
            raise SystemExit(f"duplicate plugin package name: {name}")
        if artifact in artifacts:
            raise SystemExit(f"duplicate GitHub artifact name: {artifact}")
        names.add(name)
        artifacts.add(artifact)
        items.append(
            {
                "dir": str(plugin_dir.relative_to(ROOT)),
                "file": name,
                "artifact": artifact,
            }
        )
    if not items:
        raise SystemExit("no plugins to pack")
    return items


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "plugins",
        nargs="*",
        help="plugin directories to pack; default is all macos/windows/linux plugins",
    )
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="output directory")
    parser.add_argument("--self-check", action="store_true", help="pack sample plugins and verify ZIP layout")
    parser.add_argument(
        "--ci-matrix",
        action="store_true",
        help="print JSON matrix of packed plugin files for GitHub Actions",
    )
    args = parser.parse_args()
    if args.self_check:
        self_check()
        return
    if args.ci_matrix:
        print(json.dumps(ci_matrix(), ensure_ascii=False))
        return

    out_dir = Path(args.out)
    targets = [Path(item) for item in args.plugins] if args.plugins else discover_platform_plugins()
    if not targets:
        raise SystemExit("no plugins to pack")

    written = []
    for plugin_dir in targets:
        dest = pack_plugin(plugin_dir, out_dir)
        verify_archive(dest)
        written.append(dest)
        try:
            print(dest.relative_to(ROOT))
        except ValueError:
            print(dest)

    print(f"packed {len(written)} plugin(s) -> {out_dir}")


if __name__ == "__main__":
    main()
