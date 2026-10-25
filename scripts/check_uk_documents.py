"""Check UK review files and, only on request, their public English URLs.

Structural/transport checks cannot certify legal compliance. An HTTP 200 or
translation alone is never an approval. This command does not publish, edit
application links, enable UK, submit forms, send email or execute page scripts.
"""

import argparse
from datetime import date
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urlsplit


DOCUMENTS = ("privacy-policy.html", "terms-of-use.html", "delete-account.html", "support.html")
SOURCE_BASE = "https://mealplannerpolska.pl/"
# Owner confirmed this UK destination on 24 October 2026. Historical Polish
# source provenance stays separate; ownership does not approve legal content.
PUBLIC_BASE = "https://mealplannerworld.com/"
CONTACT = "mailto:kontakt@mealplannerpolska.pl"
PUBLIC_CONTACT = "mailto:support@mealplannerworld.com"
PUBLIC_HEADINGS = {"privacy-policy.html": "privacy policy", "terms-of-use.html": "terms of use",
    "delete-account.html": "delete your account", "support.html": "help and contact"}


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.language = self.state = self.document = ""
        self.main_count = self.h1_count = self.scripts = self.forms = 0
        self.noindex = False
        self.links = []
        self._text = []
        self._hidden = 0
        self._in_h1 = False
        self.heading = []

    @property
    def text(self):
        return " ".join(" ".join(self._text).split())

    @classmethod
    def parse(cls, html):
        page = cls()
        page.feed(html)
        page.close()
        return page

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == "html":
            self.language = attrs.get("lang", "")
            self.state = attrs.get("data-publication-state", "")
            self.document = attrs.get("data-document", "")
        if tag == "main":
            self.main_count += 1
        if tag == "h1":
            self.h1_count += 1
            self._in_h1 = True
        if tag in {"script", "style"}:
            self._hidden += 1
        if tag == "script":
            self.scripts += 1
        if tag == "form":
            self.forms += 1
        if tag == "meta" and attrs.get("name", "").lower() == "robots":
            self.noindex = "noindex" in attrs.get("content", "").lower()
        if tag == "a" and attrs.get("href"):
            self.links.append(attrs["href"])

    def handle_endtag(self, tag):
        if tag == "h1":
            self._in_h1 = False
        if tag in {"script", "style"}:
            self._hidden = max(0, self._hidden - 1)

    def handle_data(self, data):
        if not self._hidden:
            self._text.append(data)
            if self._in_h1:
                self.heading.append(data)


def _file(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()) or path.stat().st_size > 2_000_000:
        raise ValueError("Unexpected review file path or size")
    return path.read_bytes()


def _review_digest(data):
    # Git/Windows may change CRLF or a UTF-8 BOM without changing the text.
    # A substantive edit still invalidates the recorded review digest.
    text = data.decode("utf-8-sig").replace("\r\n", "\n")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def check_local(root):
    root = Path(root)
    errors = []
    manifest = json.loads(_file(root, "manifest.json"))
    if manifest.get("country_code") != "GB" or set(manifest.get("files", {})) != set(DOCUMENTS):
        errors.append("manifest:wrong_country_or_document_set")
    for name in DOCUMENTS:
        try:
            row = manifest["files"][name]
            if row["source_path"] != "sources/" + name + ".txt" or row["draft_path"] != "en/" + name:
                raise ValueError("Unexpected review path")
            source = _file(root, row["source_path"])
            draft = _file(root, row["draft_path"])
            if _review_digest(source) != row["source_sha256"]:
                errors.append(name + ":changed_source")
            if _review_digest(draft) != row["draft_sha256"]:
                errors.append(name + ":changed_draft")
            if row.get("source_http_status") != 200 or row.get("source_url") != SOURCE_BASE + name:
                errors.append(name + ":missing_source_provenance")
            page = Page.parse(draft.decode("utf-8-sig"))
            if page.language != "en-GB" or page.document != name or page.main_count != 1 or page.h1_count != 1:
                errors.append(name + ":invalid_structure")
            if page.scripts or page.forms or CONTACT not in page.links:
                errors.append(name + ":unsafe_review_page_or_missing_contact")
            if page.state != row.get("state"):
                errors.append(name + ":publication_state_mismatch")
            if page.state == "draft" and (not page.noindex or "DRAFT" not in page.text):
                errors.append(name + ":unmarked_draft")
            if page.state not in {"draft", "approved"}:
                errors.append(name + ":unknown_publication_state")
            for link in page.links:
                url = urlsplit(link)
                if url.scheme not in {"", "https", "mailto"}:
                    errors.append(name + ":unsafe_link")
                if not url.scheme and not url.netloc and url.path and url.path not in DOCUMENTS:
                    errors.append(name + ":broken_local_document_link")
        except (KeyError, ValueError, OSError, UnicodeError):
            errors.append(name + ":unreadable_review_file")
    approval = manifest.get("approval", {})
    try:
        approval_date = date.fromisoformat(approval.get("reviewed_on", ""))
        approved = approval_date <= date.today() and bool(approval.get("reviewed_by", "").strip())
    except (ValueError, TypeError):
        approved = False
    approved = (approved and approval.get("approved") is True and not manifest.get("unresolved")
        and not errors and all(manifest["files"][name].get("state") == "approved" for name in DOCUMENTS))
    return {"structure_passed": not errors, "approved": bool(approved),
        "document_count": len(DOCUMENTS), "unresolved_count": len(manifest.get("unresolved", [])), "errors": errors}


def validate_published_html(html, name):
    page = Page.parse(html)
    failures = []
    if page.language.lower() not in {"en", "en-gb"}:
        failures.append("not_english")
    # This is a transport/content check, not legal approval. Public pages do
    # not need private review attributes; local approval remains a separate gate.
    if page.state not in {"", "approved"} or "DRAFT TRANSLATION" in page.text.upper():
        failures.append("draft_publication")
    heading = " ".join(" ".join(page.heading).split()).casefold()
    if (page.document not in {"", name} or page.main_count != 1 or page.h1_count != 1
            or heading != PUBLIC_HEADINGS.get(name)):
        failures.append("wrong_document_structure")
    if ("Meal Planner" not in page.text or len(page.text) < 150
            or not {CONTACT, PUBLIC_CONTACT}.intersection(page.links)):
        failures.append("missing_application_identity_or_content")
    return failures


def check_published(client):
    errors = []
    for name in DOCUMENTS:
        try:
            with client.stream("GET", PUBLIC_BASE + name, follow_redirects=False) as response:
                if response.status_code != 200:
                    errors.append(name + ":http_" + str(response.status_code))
                    continue
                if response.headers.get("content-type", "").split(";", 1)[0].strip().lower() != "text/html":
                    errors.append(name + ":not_html")
                    continue
                body = bytearray()
                for chunk in response.iter_bytes(chunk_size=65_536):
                    body.extend(chunk)
                    if len(body) > 500_000:
                        raise ValueError("Document exceeds bounded response size")
            errors.extend(name + ":" + error for error in validate_published_html(body.decode("utf-8"), name))
        except Exception as error:
            # Do not print raw provider responses, redirects or exceptions.
            errors.append(name + ":" + type(error).__name__)
    return {"published": not errors, "errors": errors}


def release_ready(local, published):
    return bool(local.get("structure_passed") and local.get("approved")
        and published and published.get("published"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "docs/uk-release-review")
    parser.add_argument("--check-published", action="store_true", help="Read four fixed public URLs; no scripts or forms")
    parser.add_argument("--require-ready", action="store_true", help="Exit 2 unless recorded approval and publication both pass")
    args = parser.parse_args()
    try:
        local = check_local(args.root)
        published = None
        if args.check_published:
            import httpx
            with httpx.Client(timeout=8, follow_redirects=False, headers={
                    "User-Agent": "MealPlanner-UK-Document-Readiness/1.0"}) as client:
                published = check_published(client)
        ready = release_ready(local, published)
        print(json.dumps({**local, "publication": published, "ready_for_release": ready}, indent=2))
        raise SystemExit(1 if not local["structure_passed"] else (2 if args.require_ready and not ready else 0))
    except (OSError, ValueError, KeyError) as error:
        print(json.dumps({"structure_passed": False, "error_type": type(error).__name__}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
