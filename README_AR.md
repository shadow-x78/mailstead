<div align="center">

<pre>
   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄    │                             
 ▄██████████████████████▄  │                             
███                    ███ │                             
██████              ██████ │ ██╗   ██╗ █████╗ ██╗██╗     
███  ███          ███  ███ │ ██║   ██║██╔══██╗██║██║     
███    ███      ███    ███ │ ███████║███████║██║██║      
███      ███  ███      ███ │ ██╔══██║██╔══██║██║██║      
███        ████        ███ │ ██║  ██║██║  ██║██║███████╗ 
███                    ███ │ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚══════╝ 
██████████████████████████ │                             
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  │                             
</pre>

# Mailstead

خادم بريد مستضاف ذاتياً لأنظمة Debian و Ubuntu و Fedora وعائلة RHEL.

[![الإصدار](https://img.shields.io/badge/version-0.8.4-2563eb?style=for-the-badge&logo=semver)](CHANGELOG.md)
[![الرخصة](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=for-the-badge&logo=gnu)](LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=for-the-badge&logo=gnubash)
![المنصّة](https://img.shields.io/badge/platform-Linux-9333ea?style=for-the-badge&logo=linux)

</div>

---

## اللغة

<a href="README.md">🇬🇧 English</a> · <a href="README_AR.md">🇸🇦 العربية</a>

---

## المحتويات

- [نظرة عامة](#overview)
- [التوزيعات المدعومة](#supported-distributions)
- [الإعدادات المسبقة](#presets)
- [البدء السريع](#quick-start)
- [نظرة على الأوامر](#cli-overview)
- [جودة التسليم](#delivery-quality)
- [بنية المشروع](#project-structure)
- [التطوير](#development)
- [التوثيق](#documentation)
- [المساهمة](#contributing)
- [الرخصة](#license)

---

<a id="overview"></a>
## نظرة عامة

يبني **Mailstead** ويدير خادم بريد إنتاجياً مستضافاً ذاتياً بأمر واحد. يربط Postfix و
Dovecot و OpenDKIM و Rspamd و MariaDB و Nginx و Roundcube و(اختيارياً) PostfixAdmin،
ويصدر شهادات TLS، ويطبع ويتحقّق من كل سجل DNS، ويضيف الإعداد التلقائي لـ
Thunderbird/Outlook ونظام تواقيع — مهيّأً لوصول عالٍ إلى صندوق الوارد في Google
(Gmail) و Apple (iCloud).

Mailstead **مفتوح المصدر فقط وغير تجاري**. ولا يحتوي على أي **telemetry**؛ كل اتصال
خارجي تُنشئه الأداة موثّق في [`docs/NETWORK_AR.md`](docs/NETWORK_AR.md) ويمكن تعطيله
بـ `--offline`.

- الأمر: `mailstead`
- التوزيع: تعيش حالة التشغيل تحت `/etc/mailstead`، `/var/lib/mailstead`،
  `/var/log/mailstead`، `/var/backups/mailstead`، `/opt/mailstead`.

<a id="supported-distributions"></a>
## التوزيعات المدعومة

| الفئة | التوزيعات | مدير الحزم |
|---|---|---|
| **الفئة الأولى** | Debian 12/13، Ubuntu 22.04/24.04/26.04 | `apt` |
| **الفئة الأولى** | Fedora (آخر إصدارين)، AlmaLinux / Rocky / RHEL 9 و10 | `dnf` |
| غير مدعومة في v1 | Arch (Manjaro/EndeavourOS)، openSUSE Leap/Tumbleweed (SLES) | — |
| غير مدعومة | Alpine، Void، Gentoo، وأي نظام بلا systemd | — |

Arch و openSUSE مرفوضتان عمداً: `mailstead install` يخرج برمز 3 ويطبع
"unsupported in v1". وإضافة توزيعة تغييرُ ملفٍ واحد — انظر
[`docs/ADDING_A_DISTRO_AR.md`](docs/ADDING_A_DISTRO_AR.md).

تجريد التوزيعات (`pkg_install`، `svc_*`، `fw_*`، `path`، `web_user`) يُبقي كل تفاصيل
`apt`/`dnf`/`www-data` داخل `lib/distro/*.sh`.

<a id="presets"></a>
## الإعدادات المسبقة

| الإعداد | المكوّنات |
|---|---|
| `send-only` | postfix + opendkim + tls (بلا mailbox/db/web/spam)؛ الوارد محصور في الأسماء البديلة `postmaster`/`abuse` |
| `minimal` | postfix + dovecot + mariadb + opendkim + rspamd + tls + fail2ban + جدار ناري (CLI فقط) |
| `standard` | minimal + nginx + roundcube + autoconfig (الكل) + signatures (client) |
| `full` | standard + postfixadmin + mta-sts + unbound + signatures (client، وserver اختياري) |
| `custom` | من المُعامِلات أو من ملف إعداد التثبيت |

أي مُعامِل يتجاوز الإعداد المسبق؛ و`--config FILE` يتجاوز سطر الأوامر.
و`--skip COMP[,COMP]` يعطّل مكوّنات من الإعداد المختار.

أهم مُعامِلات المكوّنات:

```
--mode cli|gui  --webmail roundcube|none  --dashboard postfixadmin|none
--webserver nginx|existing|none  --db mariadb|none  --spam rspamd|none
--dkim opendkim|none  --sieve yes|no  --mta-sts yes|no  --resolver unbound|system
--autoconfig none|thunderbird|outlook|all
--signatures none|client|server  --sig-policy default|enforce  --sig-images hosted|cid
--tls letsencrypt|selfsigned|existing  --acme-client certbot|acme.sh
--acme-challenge http|standalone|dns-cloudflare  --firewall auto|ufw|firewalld|nftables|none
--fail2ban yes|no  --admin-allow-ip IP[,IP]  --staging  --dry-run  --yes
```

<a id="quick-start"></a>
## البدء السريع

ثبّت الأداة نفسها (لا يتحقّق من شيء بعد — انظر أدناه)، ثم شغّل المُثبِّت:

```bash
sudo ./install.sh                 # ينسخ إلى /opt/mailstead ويربط /usr/local/bin/mailstead
sudo mailstead install \
  --preset standard \
  --hostname mail.example.com \
  --domain example.com \
  --admin-email admin@example.com
```

المُثبِّت **idempotent** ويطبع كلمات المرور المولَّدة **مرة واحدة** في النهاية. ثم:

```bash
sudo mailstead dns-print example.com     # انشر هذه السجلات
sudo mailstead dns-check example.com     # تحقّق من SPF/DKIM/DMARC/PTR/SRV/CAA ...
sudo mailstead doctor                    # فحص صحي مُجمَّع
```

### التحقق من الإصدار قبل تشغيله

تُوزَّع الإصدارات كأرشيف مع `sha256sum` وتوقيع GPG. يُفضَّل التنزيل والتحقق على تمرير
رابط إلى صدفة:

```bash
VERSION=0.8.4
BASE="https://github.com/shadow-x78/mailstead/releases/download/v${VERSION}"
curl -fsSLO "${BASE}/mailstead-${VERSION}.tar.gz"
curl -fsSLO "${BASE}/mailstead-${VERSION}.tar.gz.sha256"
sha256sum -c "mailstead-${VERSION}.tar.gz.sha256"
# اختياري: gpg --verify "mailstead-${VERSION}.tar.gz.asc" "mailstead-${VERSION}.tar.gz"
```

<a id="cli-overview"></a>
## نظرة على الأوامر

```
mailstead install …                         # إعداد الخادم بأمر واحد
mailstead add-domain / del-domain           # لكل نطاق: DNS، DKIM، autoconfig، mta-sts
mailstead add-mailbox / del-mailbox / passwd
mailstead add-alias / del-alias / list
mailstead dkim-show / dkim-rotate
mailstead dns-print / dns-check
mailstead cert-issue / cert-renew / cert-status
mailstead autoconfig regenerate / test-autoconfig user@domain
mailstead mta-sts-enforce DOMAIN
mailstead apple-profile user@domain
mailstead sig …                             # التواقيع (templates/set/export/server)
mailstead components list|add|remove ; mailstead wizard
mailstead test-send / test-tls / status / queue / logs
mailstead backup / restore / upgrade-web / doctor / uninstall
```

جلسة مثال:

```
$ sudo mailstead status
=== Mailstead - حالة النظام (mail.example.com) ===
SERVICE        STATE
postfix        active
dovecot        active
opendkim       active
rspamd         active
mariadb        active
redis-server   active
nginx          active
fail2ban       active

الطابور: 0 رسالة
انتهاء الشهادة: Apr 11 12:00:00 2027 GMT
```

<a id="delivery-quality"></a>
## جودة التسليم

تستهدف الأداة متطلبات Gmail/iCloud/Microsoft: توافق SPF + DKIM + DMARC، وصلاحية
PTR/FCrDNS، وTLS على الوارد والصادر، وتقييد التسليم إلى المستقبِلين الحسّاسين، ورسائل
متوافقة مع RFC 5322، ومسار موثّق لتشديد DMARC (`p=none` → `quarantine` → `reject`).
انظر `docs/` لسجلات DNS التي تطبعها والفحوص اليدوية المتبقية (mail-tester،
Postmaster Tools، Outlook لسطح المكتب).

<a id="project-structure"></a>
## بنية المشروع

```
mailstead/
├── mailstead                  # نقطة دخول سطر الأوامر
├── install.sh                 # يثبّت الأداة في /opt/mailstead
├── lib/                       # وحدات مشتركة (common، os، backends التوزيعات، الخدمات)
│   └── distro/                # خلفيات مديري الحزم (apt، dnf)
├── phases/                    # مراحل التثبيت المرتّبة P00..P16
├── config/                    # الإصدارات المثبَّتة والمُجمَّعات
├── templates/                 # قوالب nginx، dovecot، postfix، rspamd، php، sql
├── scripts/                   # مساعدات Python (منقّي التواقيع ومرسّمها)
├── tests/                     # أجنحة bats وأداة اختبار الأجهزة الوهمية
├── docs/                      # الأدلة، بالإنجليزية والعربية (NETWORK، AUTOCONFIG، ...)
└── .gitattributes             # قواعد linguist
```

<a id="development"></a>
## التطوير

```bash
shellcheck -x mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
shfmt -d -i 4 -ci mailstead install.sh lib/*.sh lib/distro/*.sh phases/*.sh
bats tests/*.bats
```

يشغّل CI الأوامر الثلاثة نفسها على كل طلب سحب؛ أما اختبارات التكامل في الأجهزة
الوهمية فتُشغَّل يدوياً/ليلاً (انظر [`tests/vm/`](tests/vm/)).

<a id="documentation"></a>
## التوثيق

| الملف | الوصف |
|----------|-------------|
| [NETWORK_AR.md](docs/NETWORK_AR.md) | كل اتصال خارجي تُنشئه الأداة |
| [AUTOCONFIG_AR.md](docs/AUTOCONFIG_AR.md) | الإعداد التلقائي لـ Thunderbird و Autodiscover لـ Outlook و MTA-STS |
| [SIGNATURES_AR.md](docs/SIGNATURES_AR.md) | قوالب التواقيع وسياساتها وصورها |
| [ADDING_A_DISTRO_AR.md](docs/ADDING_A_DISTRO_AR.md) | كيفية إضافة خلفية مدير حزم |

<a id="contributing"></a>
## المساهمة

انظر [`CONTRIBUTING.md`](CONTRIBUTING.md) و[`SECURITY.md`](SECURITY.md)
و[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). تُقبل المساهمات بموجب شهادة أصل
المطوّر (Developer Certificate of Origin) عبر `git commit -s`.

أبلغ عن المشكلات عبر [GitHub Issues](https://github.com/shadow-x78/mailstead/issues).

<a id="license"></a>
## الرخصة

موزَّع بموجب [رخصة AGPL-3.0](LICENSE).

---

<div align="center">

صُنع بواسطة <a href="https://github.com/shadow-x78">shadow-x78</a> ·
[سجل التغييرات](CHANGELOG.md) ·
[الأمان](SECURITY.md)

<sub>&copy; 2026 Mailstead</sub>

</div>
