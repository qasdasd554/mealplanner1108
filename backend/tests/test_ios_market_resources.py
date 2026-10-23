"""Source-level iOS language resources; not a substitute for an Xcode build."""

import plistlib
import re
from pathlib import Path

import pytest


IOS = Path(__file__).resolve().parents[2] / "frontend/ios"
PROJECT = IOS / "Runner.xcodeproj/project.pbxproj"
PURPOSE_KEYS = {"NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"}
SHARE_KEYS = {
    "share_reading", "share_done", "share_no_link", "share_prompt",
    "share_no_address", "share_invalid_address", "share_save_failed", "share_saved",
}


def strings(path):
    source = path.read_text(encoding="utf-8-sig")
    entries = re.findall(r'^"([^"\\]+)"\s*=\s*"((?:[^"\\]|\\.)*)";', source, re.M)
    assert len(dict(entries)) == len(entries), "duplicate localized keys"
    assert not re.sub(r'^"[^"\\]+"\s*=\s*"(?:[^"\\]|\\.)*";\s*', "", source, flags=re.M).strip()
    return dict(entries)


@pytest.mark.parametrize("language", ["pl", "en"])
def test_localized_permission_purposes_are_complete_and_keep_brand(language):
    entries = strings(IOS / "Runner" / f"{language}.lproj/InfoPlist.strings")
    assert set(entries) == PURPOSE_KEYS
    assert all(len(value) > 40 for value in entries.values())
    base = plistlib.loads((IOS / "Runner/Info.plist").read_bytes())
    assert base["CFBundleDisplayName"] == "Meal Planner Polska"
    if language == "pl":
        assert entries == {key: base[key] for key in PURPOSE_KEYS}


@pytest.mark.parametrize("language", ["pl", "en"])
def test_share_keys_are_complete_and_used_by_existing_controller(language):
    entries = strings(IOS / "ShareExtension" / f"{language}.lproj/Localizable.strings")
    assert set(entries) == SHARE_KEYS
    assert "Meal Planner Polska" in entries["share_saved"]
    source = (IOS / "ShareExtension/ShareViewController.swift").read_text(encoding="utf-8")
    assert set(re.findall(r'NSLocalizedString\("([^"]+)"', source)) == SHARE_KEYS
    assert 'suiteName: appGroup' in source
    assert 'private let pendingUrlKey = "pending_recipe_url"' in source
    assert 'showResult("' not in source
    if language == "pl":
        assert entries == {
            "share_reading": "Odczytuję link…",
            "share_done": "Gotowe",
            "share_no_link": "Nie otrzymano linku do przepisu.",
            "share_prompt": "Udostępnij link do filmu lub strony z przepisem.",
            "share_no_address": "Nie znaleziono adresu w udostępnionej treści.",
            "share_invalid_address": "Udostępniony adres nie jest poprawnym linkiem.",
            "share_save_failed": "Nie można zapisać linku. Sprawdź App Groups w ustawieniach podpisu aplikacji.",
            "share_saved": "Link zapisany. Otwórz Meal Planner Polska — rozpoznawanie przepisu ruszy automatycznie.",
        }


@pytest.mark.parametrize("target,table,group_id,resource_id", [
    ("Runner", "InfoPlist.strings", "97C146F01CF9000F007C117D", "97C146EC1CF9000F007C117D"),
    ("ShareExtension", "Localizable.strings", "A10000000000000000000007", "A1000000000000000000000A"),
])
def test_localized_tables_are_registered_in_the_correct_resource_target(target, table, group_id, resource_id):
    source = PROJECT.read_text(encoding="utf-8")
    variant = re.search(r'([A-F0-9]{24}) /\* ' + re.escape(table) + r' \*/ = \{\s*isa = PBXVariantGroup;(.*?)\n\s*\};', source, re.S)
    assert variant is not None
    variant_id, variant_body = variant.groups()
    for language in ("pl", "en"):
        path = f"{language}.lproj/{table}"
        ref = re.search(r'([A-F0-9]{24}) /\* ' + language + r' \*/ = \{[^\n]*path = ' + re.escape(path) + r';[^\n]*\};', source)
        assert ref is not None, path
        assert ref.group(1) in variant_body
        assert (IOS / target / path).is_file()
    group = re.search(group_id + r' /\* [^*]+ \*/ = \{\s*isa = PBXGroup;(.*?)\n\s*\};', source, re.S)
    assert variant_id in group.group(1)
    build = re.search(r'([A-F0-9]{24}) /\* ' + re.escape(table) + r' in Resources \*/ = \{isa = PBXBuildFile; fileRef = ' + variant_id + r' ', source)
    assert build is not None
    resources = re.search(resource_id + r' /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;(.*?)\n\s*\};', source, re.S)
    assert build.group(1) in resources.group(1)
    assert "developmentRegion = pl;" in source


def test_xcode_object_identifiers_are_unique():
    source = PROJECT.read_text(encoding="utf-8")
    ids = re.findall(r'^\t\t([A-F0-9]{24})(?: /\* .*? \*/)? = \{', source, re.M)
    assert len(ids) == len(set(ids))
