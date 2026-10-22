#!/usr/bin/env python3
# mailstead-footer.py - Postfix pipe content_filter that appends a per-domain
# legal footer (disclaimer) to outbound mail, then reinjects the message on
# 127.0.0.1:10025 so that DKIM signing happens AFTER the footer is added.
#
# Invocation (master.cf pipe service):
#   mailstead-footer.py ${sender} ${recipient}
#
# Behaviour:
#   * skips multipart/signed, multipart/encrypted, application/pkcs7-mime and
#     messages already carrying the X-Mailstead-Footer header (loop guard);
#   * appends the footer to every text/plain and text/html part;
#   * adds X-Mailstead-Footer: 1;
#   * reinjects via SMTP to 127.0.0.1:10025 with the original envelope;
#   * on any error exits with EX_TEMPFAIL (75) so Postfix retries; the message
#     is never silently dropped.

import base64
import email
import logging
import os
import quopri
import smtplib
import sys

REINJECT_HOST = "127.0.0.1"
REINJECT_PORT = 10025
EX_TEMPFAIL = 75
SKIP_CTE_TYPES = ("multipart/signed", "multipart/encrypted", "application/pkcs7-mime")

LIB_DIR = "@@APP_LIB@@"
FOOTER_MARKER = "X-Mailstead-Footer"

logging.basicConfig(
    level=logging.INFO,
    format="mailstead-footer[%(levelname)s] %(message)s",
    stream=sys.stderr,
)


def domain_of(addr):
    addr = (addr or "").strip().strip("<>")
    if "@" not in addr:
        return ""
    return addr.rsplit("@", 1)[1].strip().lower()


def load_disclaimers(domain):
    base = os.path.join(LIB_DIR, "signatures", "domains", domain)
    txt = ""
    htm = ""
    for name, attr in (("disclaimer.txt", "txt"), ("disclaimer.html", "html")):
        path = os.path.join(base, name)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                value = fh.read()
        except OSError:
            value = ""
        if attr == "txt":
            txt = value
        else:
            htm = value
    return txt, htm


def append_to_text(text, disclaimer_txt):
    if not disclaimer_txt:
        return text
    body = text.rstrip("\n")
    return body + "\n\n-- \n" + disclaimer_txt.strip() + "\n"


def insert_into_html(text, disclaimer_html):
    if not disclaimer_html:
        return text
    block = '<div style="font-size:11px;color:#777777;padding-top:10px;">%s</div>' % disclaimer_html
    low = text.lower()
    idx = low.rfind("</body>")
    if idx >= 0:
        return text[:idx] + block + text[idx:]
    return text + block


def set_text_payload(part, text, charset):
    cte = (part.get("Content-Transfer-Encoding") or "").strip().lower()
    if cte == "base64":
        encoded = base64.encodebytes(text.encode(charset, "replace"))
        part.set_payload(encoded.decode("ascii", "replace"))
        part["Content-Transfer-Encoding"] = "base64"
    elif cte == "quoted-printable":
        encoded = quopri.encodestring(text.encode(charset, "replace"))
        part.set_payload(encoded.decode("ascii", "replace"))
        part["Content-Transfer-Encoding"] = "quoted-printable"
    else:
        part.set_payload(text, charset)


def process_part(part, disclaimer_txt, disclaimer_html):
    if part.is_multipart():
        for child in part.get_payload():
            process_part(child, disclaimer_txt, disclaimer_html)
        return
    ctype = part.get_content_type()
    if ctype not in ("text/plain", "text/html"):
        return
    payload = part.get_payload(decode=True)
    if payload is None:
        return
    charset = part.get_content_charset() or "utf-8"
    try:
        text = payload.decode(charset, "replace")
    except LookupError:
        charset = "utf-8"
        text = payload.decode(charset, "replace")
    if ctype == "text/plain":
        text = append_to_text(text, disclaimer_txt)
    else:
        text = insert_into_html(text, disclaimer_html)
    set_text_payload(part, text, charset)


def main(argv):
    sender = argv[0] if len(argv) > 0 else ""
    recipient = argv[1] if len(argv) > 1 else ""

    raw = sys.stdin.buffer.read()
    if not raw:
        logging.info("empty message; skipping")
        return 0

    try:
        msg = email.message_from_bytes(raw)
    except Exception as exc:  # noqa: BLE001
        logging.error("cannot parse message: %s", exc)
        return EX_TEMPFAIL

    ctype = (msg.get("Content-Type") or "").split(";", 1)[0].strip().lower()
    if ctype in SKIP_CTE_TYPES:
        logging.info("skip %s message", ctype)
        return reinject(sender, recipient, raw)
    if msg.get(FOOTER_MARKER):
        logging.info("X-Mailstead-Footer already present; skip")
        return reinject(sender, recipient, raw)

    domain = domain_of(sender) or domain_of(recipient)
    if not domain:
        logging.warning("no domain in envelope; reinjecting unchanged")
        return reinject(sender, recipient, raw)

    disclaimer_txt, disclaimer_html = load_disclaimers(domain)
    if not disclaimer_txt and not disclaimer_html:
        logging.info("no disclaimer for %s; reinjecting unchanged", domain)
        return reinject(sender, recipient, raw)

    try:
        process_part(msg, disclaimer_txt, disclaimer_html)
        msg[FOOTER_MARKER] = "1"
    except Exception as exc:  # noqa: BLE001
        logging.error("failed to add footer: %s", exc)
        return EX_TEMPFAIL

    return reinject(sender, recipient, msg.as_bytes())


def reinject(sender, recipient, data):
    try:
        client = smtplib.SMTP(REINJECT_HOST, REINJECT_PORT, timeout=30)
    except Exception as exc:  # noqa: BLE001
        logging.error("cannot connect to reinject port: %s", exc)
        return EX_TEMPFAIL
    try:
        recipients = [recipient] if recipient else []
        client.sendmail(sender, recipients, data)
    except Exception as exc:  # noqa: BLE001
        logging.error("reinject failed: %s", exc)
        return EX_TEMPFAIL
    finally:
        try:
            client.quit()
        except Exception:  # noqa: BLE001
            pass
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:  # noqa: BLE001
        logging.error("unexpected failure: %s", exc)
        sys.exit(EX_TEMPFAIL)