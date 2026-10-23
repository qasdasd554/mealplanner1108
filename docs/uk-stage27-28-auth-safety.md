# Stages 27–28 — account safety and language

## Reproduced before changes

Pending account deletion could continue after logout and dispatch using the
replacement session. Late delete responses/errors could clear that new session
or its loading state. Similar late completions from eight auth/report actions
could display stale errors or trigger a profile read for another account.

Session ownership now guards each continuation. New authentication increments
the generation so an older pre-login action cannot attach its response to the
new user. Delete checks ownership before and after push cleanup and the request;
its own final cleanup updates the owned generation. It does not delete any
additional account data or change server deletion authorization.

Provider/common screen errors use persisted account language, with a normalized
device-region hint only before authentication. Login/password recovery now send
that hint. It is never used to reassign an existing account country.

## Backend regression evidence

Before implementation, the language tests showed 15 failures / 12 passes.
Non-object JSON could escape parsing and produce a server exception; it now
returns 400. Legacy double-encoded JSON objects remain supported.

Existing credential validation, CAPTCHA-before-credentials order, status codes,
rate limits, OTP expiry and identity verification remain intact. Known CAPTCHA
messages are translated without changing rejection status or headers. Wrong
password responses and password-recovery responses do not reveal whether the
account exists or its country. Emails still use the stored account country.

The complete backend run on 23 October passed 1,682 tests (42 dependency warnings),
including synthetic auth tests. No real email, account deletion or production
database was used. Native Google/Apple flows and device storage still require
real-device verification; these tests are not proof of every reported Android
process exit being fixed.
