<div align="center">

# الإعداد التلقائي و Autodiscover - Mailstead

[![الإصدار](https://img.shields.io/badge/version-0.8.5-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![الرخصة](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![المنصّة](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

يولّد Mailstead إعداداً تلقائياً للعملاء لنطاق ما، بحيث يكتب المستخدم عنوانه وكلمة
مروره فقط.

<a id="thunderbird-autoconfig"></a>
## Thunderbird (Autoconfig)

يُولَّد عند `add-domain` (وعبر `mailstead autoconfig regenerate [DOMAIN|--all]`) إلى
`${APP_LIB}/web/autoconfig/<domain>/mail/config-v1.1.xml`، ويُقدَّم بواسطة Nginx على:

- `https://autoconfig.<domain>/mail/config-v1.1.xml`
- `http://autoconfig.<domain>/mail/config-v1.1.xml`
- `https://<domain>/.well-known/autoconfig/mail/config-v1.1.xml` (فقط إذا كان نطاق
  الجذر مُستضافاً هنا)

يُعلن ملف XML عن IMAP `993`/SSL و SMTP `587`/STARTTLS مع `%EMAILADDRESS%` كاسم
مستخدم. `password-cleartext` تعني «كلمة مرور تُرسَل عبر قناة TLS إلزامية». اسم العرض
يُهرَّب بـ XML ويُتحقَّق منه بـ `xmllint` (الاسم المنطقي للحزمة `xmllint`).

<a id="outlook-autodiscover-pox"></a>
## Outlook (Autodiscover POX)

يجرّب Outlook لسطح المكتب، لكل نطاق:

1. `POST https://<domain>/autodiscover/autodiscover.xml`
2. `POST https://autodiscover.<domain>/autodiscover/autodiscover.xml`
3. `GET http://autodiscover.<domain>/autodiscover/autodiscover.xml` → يجب أن يُعيد
   **HTTP 302** إلى HTTPS (وليس 301)
4. سجل SRV `_autodiscover._tcp.<domain>` → `autodiscover.<domain>:443`

يغطّي Mailstead (2) و(3) و(4). الخطوة (1) تعمل فقط إذا كان نطاق الجذر مُستضافاً هنا.
استجابة POX الديناميكية ينتجها `${APP_OPT}/web/autodiscover.php` عبر PHP-FPM؛
والمسارات الثابتة تُقدَّم لـ Thunderbird.

**الأمان:** لا يُعيد السكربت نطاقاً غير مُستضاف (404)، ولا يعكس إدخال المستخدم دون
regex صارم + تهريب XML، ويحدّ جسم الطلب بـ 8 KB، ولا يسجّل أجسام الطلبات، ويطبّق Nginx
`limit_req` (5 طلبات/ثانية لكل IP) على مسار Autodiscover.

<a id="dns-records"></a>
## سجلات DNS

```
autoconfig.<d>.            A/CNAME  → mail.<d>. أو عنوان IP للخادم
autodiscover.<d>.          A/CNAME  → mail.<d>. أو عنوان IP للخادم
_autodiscover._tcp.<d>.    SRV      0 1 443 autodiscover.<d>.
_submission._tcp.<d>.      SRV      0 1 587 mail.<d>.
_imaps._tcp.<d>.           SRV      0 1 993 mail.<d>.
```

<a id="verification"></a>
## التحقق

```bash
sudo mailstead test-autoconfig user@example.com
```

يتحقّق هذا من XML الخاص بـ Thunderbird (`xmllint`)، وحالة HTTP لكلا النقطتين (200
للإعداد، **302** لـ Autodiscover)، وإرسال POST إلى نقطة Autodiscover (بالتحقق من
`<Server>` = `MAIL_HOSTNAME`، و`<LoginName>` = العنوان، والمنفذين 993/587)، وأن نطاقاً
غير مُستضاف يُعيد 404، وسجل SRV، وصلاحية الشهادة.

<a id="known-limitations"></a>
## حدود معروفة

- **New Outlook** وتطبيقات **Outlook للجوال** لا تستخدم هذه الآلية بالكامل؛ إذ يمرّ
  Outlook للجوال عبر خدمات Microsoft السحابية ولا يمكن إعداده من هنا.
- الاختبار اليدوي الإلزامي هو **Outlook لسطح المكتب على Windows (2019/2021/365)**.
- حسابات Thunderbird تُنشأ من العنوان + كلمة المرور فقط.

إذا تعذّر جعل منصّة ما تعمل، وثّق الفشل المحدد هنا بدلاً من ادّعاء الدعم.
