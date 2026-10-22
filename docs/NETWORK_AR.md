<div align="center">

# اتصالات الشبكة - Mailstead

[![الإصدار](https://img.shields.io/badge/version-0.8.4-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![الرخصة](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![المنصّة](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

<a id="outbound-connections"></a>
## الاتصالات الصادرة

لا يحتوي Mailstead على أي **telemetry**. تسرد هذه الصفحة كل اتصال خارجي تستطيع الأداة
إنشاءه، والغرض منه، وكيفية تعطيله.

| الوجهة | الغرض | متى | التعطيل |
|---|---|---|---|
| `https://api.ipify.org` | كشف عنوان IPv4 العام للخادم لسجلات DNS/SPF | `install`، ما لم يُمرَّر `--ip4` | `--offline` (يرتدّ إلى `ip route get 1.1.1.1`) |
| `github.com` (روابط الإصدارات في `config/versions.env`) | تنزيل أرشيفات Roundcube / PostfixAdmin المثبَّتة (مُتحقَّق منها بـ SHA-256) | `install`، `upgrade-web`، عندما لا يكون الملف مخزَّناً مؤقتاً | `--offline` مع وضع الملف مسبقاً في `/var/lib/mailstead/cache/` |
| Let’s Encrypt ACME (`acme-v02.api.letsencrypt.org`) | إصدار/تجديد شهادات TLS عبر certbot أو acme.sh | `install`، `cert-issue`، `cert-renew` | اختر `--tls selfsigned` أو `--tls existing` |
| Cloudflare API (`api.cloudflare.com`) | فقط عند تمرير `--acme-challenge dns-cloudflare` | إصدار الشهادة | لا تُفعّل هذا التحدّي |
| مُحلِّلات DNS العامة (`1.1.1.1`، `8.8.8.8`) | استعلامات التحقق في `dns-check` | `dns-check` | شغّل `dns-check` في الوقت المناسب؛ فهو للقراءة فقط |

<a id="notes"></a>
## ملاحظات

- استعلامات `dig`/DNS أثناء الإعداد (فحوص PTR/A في preflight، و`dns-check`، والتحقق من
  MX/SRV/CAA) للقراءة فقط وهي جزء أصيل من تشغيل خادم بريد.
- المُحلِّل المحلي الاختياري (`unbound`، مفعّل افتراضياً في `full`) يستعلم DNS مباشرةً من
  الخادم؛ وليس «اتصالاً بالمنزل» ويمكن تعطيله بـ `--resolver system`.
- لا تُرسَل الأسرار إلى أي مكان. كلمات المرور المولَّدة تُطبَع في طرفيتك فقط.

<a id="offline-install"></a>
## التثبيت دون اتصال

استخدم `--offline` مع `--tls selfsigned` (أو `existing`)، وضع أرشيفات
Roundcube/PostfixAdmin مسبقاً في دليل التخزين المؤقت الذي يتوقعه `config/versions.env`.
