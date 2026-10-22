<div align="center">

# Signatures - Mailstead

[![Version](https://img.shields.io/badge/version-0.6.0-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![License](https://img.shields.io/badge/license-GPL--3.0-dc2626?style=flat-square)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![Platform](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

Mailstead can generate text, image and HTML signatures, apply them in Roundcube,
export them for desktop clients, and (experimentally) append a server-side legal
footer to outbound mail.

## Flags

```
--signatures none|client|server     # default: client in standard/full, none otherwise
--sig-policy default|enforce        # default: set only when the identity signature is empty
--sig-images hosted|cid             # default: hosted (https URL); cid only for desktop export
```

## Storage

```
${APP_LIB}/signatures/
  templates/                          built-in + custom-*.html.tpl
  domains/<domain>/profile.env        ORG, WEBSITE, ACCENT, LOGO_FILE, BANNER_FILE, BANNER_LINK, TEMPLATE
  domains/<domain>/users/<local>.env  NAME, TITLE, PHONE, ORG, WEBSITE, ACCENT, DIR, ...
  assets/<domain>/<sha16>.<png|jpg|gif>
  rendered/<domain>/<local>.html + .txt   (0640 root:$(web_user))
```

Priority: user override > domain profile > template. All values are HTML-escaped;
no raw text is ever copied into HTML.

## Built-in templates

- `text-only` — plain text, first line `-- `.
- `classic-html` — logo left/right + name + title + phone + email + website.
- `banner-html` — as above plus a wide banner (optional link).

Templates use tables and inline CSS only (no flex/grid, no web fonts). `DIR=rtl`
sets `dir="rtl"` and flips alignment/padding; fallback font is `Tahoma, Arial`.
Every HTML template also produces a `.txt` alternative.

## Commands

```
mailstead sig template list|show NAME
mailstead sig set DOMAIN|user@d [--template …] [--name …] [--title …] [--org …]
                              [--phone …] [--website URL] [--accent "#0a66c2"] [--dir ltr|rtl]
                              [--logo FILE] [--banner FILE --banner-link URL --banner-alt "…"]
                              [--disclaimer-file FILE]
mailstead sig set-html DOMAIN|user@d FILE.html      # sanitized; rejected if disallowed content remains
mailstead sig set-text DOMAIN|user@d FILE.txt
mailstead sig image add DOMAIN FILE [--kind logo|banner]
mailstead sig preview user@d
mailstead sig apply user@d|DOMAIN|--all
mailstead sig export user@d --format thunderbird|outlook|apple|html|txt --out DIR
mailstead sig remove user@d|DOMAIN
mailstead sig server enable|disable|status
```

`sig apply` is idempotent and honours `--dry-run`.

## HTML sanitizer (`scripts/mailstead-sig.py`)

Allowlist-based, using the Python standard library only:

- Allowed tags: `table tbody thead tr td th p br div span a img b strong i em u hr`
  `font small h1 h2 h3 h4 ul ol li`.
- Allowed attributes: `style href src alt width height border cellpadding cellspacing`
  `align valign bgcolor colspan rowspan dir title`.
- `href` only `https:`/`http:`/`mailto:`/`tel:`; external links get
  `rel="noopener noreferrer" target="_blank"`.
- `src` only `https:` or `cid:`; `data:` is rejected.
- `script iframe object embed form input button link meta base svg style(tag)` and
  any `on*=`/`javascript:`/`expression(`/`url(` are removed.
- Size limit: warn > 6 KB, reject > 10 KB. Output is well-formed (tags closed).

Images: PNG/JPEG/GIF only (SVG and WebP rejected), ≤ 200 KB, banner width ≤ 600 px,
logo ≤ 200×80 (stored at 2x, shown at half via `width`/`height`). Type is verified
by file content (not extension); EXIF is stripped if `exiftool` is available.

## Image hosting

With `--sig-images hosted`, images are served from
`https://<MAIL_HOSTNAME>/sig-assets/<domain>/<file>` by the mail vhost (read-only,
immutable filenames, `Cache-Control: public, immutable`). No tracking pixels, ever.
`cid:` inline images are only used for desktop export and increase message size.

## Roundcube integration

The `mailstead_signature` plugin reads `rendered/<domain>/<local>.html` on
`login_after` and, in `default` policy, sets the main identity’s signature only when
empty (with `html_signature=1`); in `enforce`, it refreshes when the file is newer
than the stored `mailstead_sig_mtime`. It uses Roundcube’s identity/pref API, not
direct DB writes. **[تحقق]** verify hook and API names against the installed
Roundcube version.

## Desktop export

`mailstead sig export user@d --format … --out DIR` writes `signature.html`
(Thunderbird), `<local>.htm`/`.txt` (Outlook, place in
`%APPDATA%\Microsoft\Signatures\`), or HTML/txt plus a `README-signature.md`. Server
signatures cannot be forced on desktop clients, so image URLs must be reachable —
which is why `hosted` is the default.

## Server footer (experimental)

`--signatures server` adds a legal footer to **outbound** mail. The footer must be
inserted **before** DKIM signing, so Postfix routes submission through a `footer`
pipe service (`mailstead-footer.py`, Python stdlib) that reinjects to
`127.0.0.1:10025`, where the OpenDKIM milter signs the message. On any error the
script returns `EX_TEMPFAIL` (75) so Postfix retries instead of dropping mail. It
skips `multipart/signed`, `multipart/encrypted`, `application/pkcs7-mime`, and any
message already carrying `X-Mailstead-Footer`. Master.cf is edited with
`postconf -M/-P`, never by hand.

Required tests before enabling: plain text, HTML only, multipart/alternative, a
message with attachments, an S/MIME-signed message, and Arabic UTF-8/base64 — then
confirm **DKIM = pass** on Gmail after the footer. If a system does not pass, leave
the feature disabled (“not supported yet”).

## Quality checks (warned in `sig preview`)

No image-only signatures; no URL shorteners/tracking/off-domain images; HTML ≤ 10 KB;
images ≤ 200 KB and width ≤ 600 px; every image has `alt`; contrast ≥ 4.5:1 when
colors are set; ≤ 5 links; legal footer ≤ 1000 chars. Keep name/title/phone as
**text** (not inside an image), since Outlook may block remote images by default.
