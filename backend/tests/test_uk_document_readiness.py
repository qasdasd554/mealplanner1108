"""Drafts and an HTTP 200 alone must never pass the UK publication gate."""

import importlib.util
from pathlib import Path
from datetime import date, timedelta
import hashlib
import json
import shutil

import httpx
import pytest


ROOT = Path(__file__).resolve().parents[2]
HEADINGS = {"privacy-policy.html": "Privacy policy", "terms-of-use.html": "Terms of use",
    "delete-account.html": "Delete your account", "support.html": "Help and contact"}
spec = importlib.util.spec_from_file_location("uk_document_readiness", ROOT / "scripts/check_uk_documents.py")
subject = importlib.util.module_from_spec(spec)
spec.loader.exec_module(subject)


def minimal_test_page(name):
    return (f'<html lang="en-GB" data-publication-state="approved" data-document="{name}">'
        '<head><title>Meal Planner Polska</title></head><body><main>'
        f'<h1>{HEADINGS[name]}</h1><p>Meal Planner Polska. Synthetic published document for transport tests, '
        'not actual legal terms. This fixture checks the document identity, language, '
        'publication marker and contact destination without asserting legal compliance.</p>'
        '<a href="mailto:kontakt@mealplannerpolska.pl">Contact</a></main></body></html>')


def test_current_english_drafts_are_structurally_valid_but_not_release_approved():
    report = subject.check_local(ROOT / "docs/uk-release-review")
    assert report["structure_passed"] is True
    assert report["approved"] is False
    assert report["document_count"] == 4
    assert report["unresolved_count"] > 0
    assert report["errors"] == []


def test_all_english_pages_are_plain_review_drafts_not_live_legal_promises():
    for name in subject.DOCUMENTS:
        page = subject.Page.parse((ROOT / "docs/uk-release-review/en" / name).read_text(encoding="utf-8"))
        assert page.language == "en-GB" and page.state == "draft"
        assert page.noindex and page.main_count == 1 and page.h1_count == 1
        assert "DRAFT" in page.text
        assert not page.scripts and not page.forms
        assert "mailto:kontakt@mealplannerpolska.pl" in page.links


@pytest.mark.parametrize("kind", ["polish", "draft", "missing-app", "wrong-document", "missing-main", "empty"])
def test_success_status_is_not_enough_to_verify_a_published_document(kind):
    html = minimal_test_page("privacy-policy.html")
    if kind == "polish":
        html = html.replace('lang="en-GB"', 'lang="pl"')
    elif kind == "draft":
        html = html.replace('data-publication-state="approved"', 'data-publication-state="draft"')
    elif kind == "missing-app":
        html = html.replace("Meal Planner Polska", "Unrelated application")
    elif kind == "wrong-document":
        html = html.replace('data-document="privacy-policy.html"', 'data-document="support.html"')
    elif kind == "missing-main":
        html = html.replace("<main>", "<div>").replace("</main>", "</div>")
    else:
        html = ""
    failures = subject.validate_published_html(html, "privacy-policy.html")
    assert failures


@pytest.mark.parametrize("status", [301, 302, 404, 503])
def test_redirect_missing_or_failing_pages_do_not_pass(status):
    with httpx.Client(transport=httpx.MockTransport(lambda request: httpx.Response(status,
            headers={"location": "https://unrelated.example/"}, text="not a document"))) as client:
        report = subject.check_published(client)
    assert report["published"] is False
    assert len(report["errors"]) == 4


def test_four_correct_approved_english_pages_can_pass_transport_checks():
    requested = []
    def transport(request):
        requested.append(str(request.url))
        name = request.url.path.rsplit("/", 1)[-1]
        return httpx.Response(200, headers={"content-type": "text/html; charset=utf-8"},
            text=minimal_test_page(name))
    with httpx.Client(transport=httpx.MockTransport(transport)) as client:
        report = subject.check_published(client)
    assert report == {"published": True, "errors": []}
    assert requested == [subject.PUBLIC_BASE + name for name in subject.DOCUMENTS]


def test_oversized_or_non_html_response_cannot_be_treated_as_a_document():
    for headers, body in [({"content-type": "application/json"}, b"{}"),
            ({"content-type": "text/html"}, b"x" * 600_000)]:
        with httpx.Client(transport=httpx.MockTransport(lambda request:
                httpx.Response(200, headers=headers, content=body))) as client:
            assert subject.check_published(client)["published"] is False


def test_network_exception_does_not_expose_raw_query_or_private_exception():
    def transport(request):
        raise httpx.ConnectError("Do not print secret diagnostic contents", request=request)
    with httpx.Client(transport=httpx.MockTransport(transport)) as client:
        report = subject.check_published(client)
    assert report["published"] is False
    assert "secret diagnostic" not in str(report)


def test_approval_without_publication_and_publication_without_approval_are_not_ready():
    local = {"structure_passed": True, "approved": False, "errors": []}
    assert subject.release_ready(local, {"published": True, "errors": []}) is False
    local["approved"] = True
    assert subject.release_ready(local, None) is False
    assert subject.release_ready(local, {"published": False, "errors": []}) is False
    assert subject.release_ready(local, {"published": True, "errors": []}) is True


def test_redirects_are_not_followed_even_if_callers_client_default_allows_them():
    requested = []
    def transport(request):
        requested.append(str(request.url))
        return httpx.Response(302, headers={"location": "https://unexpected.example/private"})
    with httpx.Client(follow_redirects=True, transport=httpx.MockTransport(transport)) as client:
        report = subject.check_published(client)
    assert report["published"] is False
    assert requested == [subject.PUBLIC_BASE + name for name in subject.DOCUMENTS]


@pytest.mark.parametrize("kind", ["draft-edit", "source-edit", "traversal", "file-state", "false-approval"])
def test_changed_or_mislabelled_review_files_cannot_pass_release_check(tmp_path, kind):
    root = tmp_path / "review"
    shutil.copytree(ROOT / "docs/uk-release-review", root)
    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    name = subject.DOCUMENTS[0]
    if kind == "draft-edit":
        path = root / manifest["files"][name]["draft_path"]
        path.write_text(path.read_text(encoding="utf-8") + "Unreviewed change", encoding="utf-8")
    elif kind == "source-edit":
        path = root / manifest["files"][name]["source_path"]
        path.write_text("Changed captured source", encoding="utf-8")
    elif kind == "traversal":
        manifest["files"][name]["source_path"] = "../../outside.txt"
    elif kind == "file-state":
        manifest["files"][name]["state"] = "approved"
    else:
        manifest["approval"] = {"approved": True, "reviewed_by": "reviewer", "reviewed_on": date.today().isoformat()}
        manifest["unresolved"] = []
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    report = subject.check_local(root)
    assert report["approved"] is False
    if kind != "false-approval":
        assert report["structure_passed"] is False


def test_approval_needs_all_final_documents_resolved_questions_and_real_review_date(tmp_path):
    root = tmp_path / "review"
    shutil.copytree(ROOT / "docs/uk-release-review", root)
    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name in subject.DOCUMENTS:
        row = manifest["files"][name]
        body = minimal_test_page(name)
        (root / row["draft_path"]).write_text(body, encoding="utf-8")
        row["draft_sha256"] = hashlib.sha256(body.encode()).hexdigest()
        row["state"] = "approved"
    manifest["unresolved"] = []
    manifest["approval"] = {"approved": True, "reviewed_by": "Synthetic test reviewer", "reviewed_on": date.today().isoformat()}
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    assert subject.check_local(root)["approved"] is True
    for reviewer, day in [("", date.today().isoformat()),
            ("reviewer", (date.today() + timedelta(days=1)).isoformat()), ("reviewer", "")]:
        manifest["approval"].update(reviewed_by=reviewer, reviewed_on=day)
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        assert subject.check_local(root)["approved"] is False


def test_checkout_line_endings_and_bom_do_not_change_reviewed_document_contents(tmp_path):
    root = tmp_path / "review"
    shutil.copytree(ROOT / "docs/uk-release-review", root)
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    for row in manifest["files"].values():
        for key in ("source_path", "draft_path"):
            path = root / row[key]
            text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
            path.write_bytes(b"\xef\xbb\xbf" + text.replace("\n", "\r\n").encode("utf-8"))
    report = subject.check_local(root)
    assert report["structure_passed"] is True
    assert report["approved"] is False


def test_historical_source_provenance_is_independent_of_future_publication_host(monkeypatch):
    # No request is made to this placeholder; choosing a future publication
    # host must not rewrite where the captured Polish notice came from.
    monkeypatch.setattr(subject, "PUBLIC_BASE", "https://example.invalid/en/")
    report = subject.check_local(ROOT / "docs/uk-release-review")
    assert report["structure_passed"] is True
    assert report["approved"] is False


def test_confirmed_uk_domain_is_the_publication_target_not_the_polish_source():
    manifest = json.loads((ROOT / "docs/uk-release-review/manifest.json").read_text(encoding="utf-8"))
    assert subject.PUBLIC_BASE == "https://mealplannerworld.com/"
    assert subject.SOURCE_BASE == "https://mealplannerpolska.pl/"
    assert manifest["publication_host"] == {
        "base_url": subject.PUBLIC_BASE,
        "ownership_confirmed_by": "user",
        "confirmed_on": "2026-10-24",
    }
    for name, row in manifest["files"].items():
        assert row["proposed_public_url"] == subject.PUBLIC_BASE + name
        assert row["source_url"] == subject.SOURCE_BASE + name
        assert row["state"] == "draft"
    assert "public_document_domain" not in {item["id"] for item in manifest["unresolved"]}
    assert manifest["approval"]["approved"] is False


@pytest.mark.parametrize("name", HEADINGS)
def test_public_english_site_does_not_need_private_review_html_attributes(name):
    html = minimal_test_page(name).replace(
        f' data-publication-state="approved" data-document="{name}"', '').replace(
        'mailto:kontakt@mealplannerpolska.pl', 'mailto:support@mealplannerworld.com')
    assert subject.validate_published_html(html, name) == []


def test_navigation_links_cannot_disguise_the_wrong_document_without_custom_attributes():
    html = minimal_test_page('support.html').replace(
        ' data-publication-state="approved" data-document="support.html"', '')
    html = html.replace('</main>', '<nav>Privacy policy Terms of use</nav></main>')
    assert subject.validate_published_html(html, 'privacy-policy.html')
