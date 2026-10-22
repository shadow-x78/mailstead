<div align="center">

# التواقيع - Mailstead

[![الإصدار](https://img.shields.io/badge/version-0.8.5-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![الرخصة](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![المنصّة](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

يستطيع Mailstead توليد تواقيع نصية وصورية وHTML، وتطبيقها في Roundcube، وتصديرها
لعملاء سطح المكتب، و(تجريبياً) إلحاق تذييل قانوني من جهة الخادم بالبريد الصادر.

<a id="flags"></a>
## المُعامِلات

```
--signatures none|client|server     # الافتراضي: client في standard/full، وnone فيما عدا ذلك
--sig-policy default|enforce        # الافتراضي: الضبط فقط عندما يكون توقيع الهوية فارغاً
--sig-images hosted|cid             # الافتراضي: hosted (رابط https)؛ cid للتصدير لسطح المكتب فقط
```

<a id="storage"></a>
## التخزين

```
${APP_LIB}/signatures/
  templates/                          المدمجة + custom-*.html.tpl
  domains/<domain>/profile.env        ORG, WEBSITE, ACCENT, LOGO_FILE, BANNER_FILE, BANNER_LINK, TEMPLATE
  domains/<domain>/users/<local>.env  NAME, TITLE, PHONE, ORG, WEBSITE, ACCENT, DIR, ...
  assets/<domain>/<sha16>.<png|jpg|gif>
  rendered/<domain>/<local>.html + .txt   (0640 root:$(web_user))
```

الأولوية: تجاوز المستخدم > ملف النطاق > القالب. كل القيم تُهرَّب بـ HTML؛ ولا يُنسَخ
أي نص خام إلى HTML.

<a id="built-in-templates"></a>
## القوالب المدمجة

- `text-only` — نص عادي، السطر الأول `-- `.
- `classic-html` — شعار يميناً/يساراً + الاسم + المسمّى + الهاتف + البريد + الموقع.
- `banner-html` — كما سبق مع لافتة عريضة (رابط اختياري).

تستخدم القوالب الجداول وCSS المضمّن فقط (بلا flex/grid، وبلا خطوط ويب). `DIR=rtl`
يضبط `dir="rtl"` ويعكس المحاذاة والحشو؛ والخط البديل `Tahoma, Arial`. كل قالب HTML
ينتج أيضاً نسخة `.txt`.

<a id="commands"></a>
## الأوامر

```
mailstead sig template list|show NAME
mailstead sig set DOMAIN|user@d [--template …] [--name …] [--title …] [--org …]
                              [--phone …] [--website URL] [--accent "#0a66c2"] [--dir ltr|rtl]
                              [--logo FILE] [--banner FILE --banner-link URL --banner-alt "…"]
                              [--disclaimer-file FILE]
mailstead sig set-html DOMAIN|user@d FILE.html      # يُنقّى؛ ويُرفض إن بقي محتوى غير مسموح
mailstead sig set-text DOMAIN|user@d FILE.txt
mailstead sig image add DOMAIN FILE [--kind logo|banner]
mailstead sig preview user@d
mailstead sig apply user@d|DOMAIN|--all
mailstead sig export user@d --format thunderbird|outlook|apple|html|txt --out DIR
mailstead sig remove user@d|DOMAIN
mailstead sig server enable|disable|status
```

`sig apply` عمليّة idempotent وتحترم `--dry-run`.

<a id="html-sanitizer"></a>
## مُنقّي HTML

`scripts/mailstead-sig.py` قائم على قائمة سماح ويستخدم مكتبة Python القياسية فقط:

- الوسوم المسموحة: `table tbody thead tr td th p br div span a img b strong i em u hr`
  `font small h1 h2 h3 h4 ul ol li`.
- الخصائص المسموحة: `style href src alt width height border cellpadding cellspacing`
  `align valign bgcolor colspan rowspan dir title`.
- `href` فقط `https:`/`http:`/`mailto:`/`tel:`؛ والروابط الخارجية تحصل على
  `rel="noopener noreferrer" target="_blank"`.
- `src` فقط `https:` أو `cid:`؛ و`data:` مرفوض.
- تُزال `script iframe object embed form input button link meta base svg style(tag)`
  وكل `on*=`/`javascript:`/`expression(`/`url(`.
- حدّ الحجم: تحذير > 6 KB، رفض > 10 KB. والمخرَج سليم البنية (الوسوم مغلقة).

الصور: PNG/JPEG/GIF فقط (SVG وWebP مرفوضان)، ≤ 200 KB، عرض اللافتة ≤ 600 px،
والشعار ≤ 200×80 (يُخزَّن بالضعف ويُعرض بالنصف عبر `width`/`height`). يُتحقَّق من النوع
من محتوى الملف (لا من الامتداد)؛ ويُزال EXIF إن توفّر `exiftool`.

<a id="image-hosting"></a>
## استضافة الصور

مع `--sig-images hosted` تُقدَّم الصور من
`https://<MAIL_HOSTNAME>/sig-assets/<domain>/<file>` بواسطة vhost البريد (للقراءة فقط،
أسماء ملفات ثابتة، `Cache-Control: public, immutable`). لا بكسلات تتبّع أبداً.
صور `cid:` المضمّنة تُستخدم للتصدير لسطح المكتب فقط وتزيد حجم الرسالة.

<a id="roundcube-integration"></a>
## تكامل Roundcube

يقرأ إضافة `mailstead_signature` الملف `rendered/<domain>/<local>.html` عند
`login_after`، وفي سياسة `default` يضبط توقيع الهوية الرئيسية فقط عندما يكون فارغاً
(مع `html_signature=1`)؛ وفي `enforce` يحدّثه عندما يكون الملف أحدث من
`mailstead_sig_mtime` المخزَّن. يستخدم واجهة الهويات/التفضيلات في Roundcube، لا
الكتابة المباشرة في قاعدة البيانات. **[تحقق]** تحقّق من أسماء الخطّافات والواجهة مقابل
نسخة Roundcube المثبَّتة.

<a id="desktop-export"></a>
## التصدير لسطح المكتب

`mailstead sig export user@d --format … --out DIR` يكتب `signature.html`
(Thunderbird)، أو `<local>.htm`/`.txt` (Outlook، ضعها في
`%APPDATA%\Microsoft\Signatures\`)، أو HTML/txt مع `README-signature.md`. لا يمكن فرض
تواقيع الخادم على عملاء سطح المكتب، لذا يجب أن تكون روابط الصور قابلة للوصول — ولهذا
يكون `hosted` هو الافتراضي.

<a id="server-footer"></a>
## تذييل الخادم

`--signatures server` يضيف تذييلاً قانونياً إلى البريد **الصادر**. ويجب إدخال التذييل
**قبل** توقيع DKIM، لذا يوجّه Postfix الإرسال عبر خدمة pipe باسم `footer`
(`mailstead-footer.py`، Python stdlib) تُعيد الحقن إلى `127.0.0.1:10025`، حيث يوقّع
milter الخاص بـ OpenDKIM الرسالة. عند أي خطأ يُعيد السكربت `EX_TEMPFAIL` (75) كي
يعيد Postfix المحاولة بدلاً من إسقاط البريد. ويتخطّى `multipart/signed`،
و`multipart/encrypted`، و`application/pkcs7-mime`، وأي رسالة تحمل
`X-Mailstead-Footer` مسبقاً. يُحرَّر Master.cf بـ `postconf -M/-P`، لا يدوياً.

هذه الميزة **تجريبية**. الاختبارات المطلوبة قبل التفعيل: نص عادي، HTML فقط،
multipart/alternative، رسالة بمرفقات، رسالة موقّعة S/MIME، ونص عربي UTF-8/base64 —
ثم تأكيد **DKIM = pass** على Gmail بعد التذييل. وإن لم ينجح نظام ما، فأبقِ الميزة
معطّلة («غير مدعومة بعد»).

<a id="quality-checks"></a>
## فحوص الجودة

تُنبَّه في `sig preview`:

- لا تواقيع صورة فقط.
- لا مختصرات روابط، ولا بكسلات تتبّع، ولا صور من نطاق خارجي.
- HTML ≤ 10 KB؛ الصور ≤ 200 KB والعرض ≤ 600 px.
- لكل صورة `alt`.
- التباين ≥ 4.5:1 عند ضبط الألوان.
- ≤ 5 روابط؛ التذييل القانوني ≤ 1000 حرف.
- أبقِ الاسم/المسمّى/الهاتف **نصاً** (لا داخل صورة)، لأن Outlook قد يحجب الصور
  البعيدة افتراضياً.
