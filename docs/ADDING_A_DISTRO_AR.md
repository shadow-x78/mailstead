<div align="center">

# إضافة توزيعة - Mailstead

[![الإصدار](https://img.shields.io/badge/version-0.8.4-2563eb?style=flat-square&logo=semver)](../CHANGELOG.md)
[![الرخصة](https://img.shields.io/badge/license-AGPL--3.0-dc2626?style=flat-square&logo=gnu)](../LICENSE)
![Shell](https://img.shields.io/badge/bash-5.2%2B-16a34a?style=flat-square&logo=gnubash)
![المنصّة](https://img.shields.io/badge/platform-Linux-9333ea?style=flat-square&logo=linux)

</div>

---

يعزل Mailstead كل السلوك الخاص بالتوزيعات خلف واجهة صغيرة، فتصبح إضافة توزيعة جديدة
ملفاً واحداً جديداً مع بضعة مدخلات في الجداول.

<a id="add-the-family-module"></a>
## أضف وحدة العائلة

أنشئ `lib/distro/<family>.sh` تُنفّذ نفس دوال `lib/distro/debian.sh`:

| الدالة | الغرض |
|---|---|
| `pkg_refresh` | تحديث بيانات الحزم الوصفية |
| `pkg_install LOGICAL...` | ترجمة الأسماء المنطقية عبر `pkgmap` والتثبيت |
| `pkg_installed LOGICAL...` | اختبار ما إذا كانت الحزم مثبَّتة |
| `pkg_remove PKG...` | إزالة الحزم |
| `pkg_enable_repo NAME` | تفعيل مستودع إضافي (`epel`، `crb`، `rspamd`، …) |
| `svc_name LOGICAL` | ربط خدمة منطقية باسم وحدتها الحقيقي |
| `svc_enable_now` / `svc_reload` / `svc_restart` / `svc_active` | أغلفة systemd |
| `web_user` | طباعة مستخدم خادم الويب (`www-data`، `nginx`، `http`، …) |
| `fw_backend` / `fw_open` / `fw_close` | تجريد الجدار الناري |
| `path LOGICAL` | مسارات خاصة بالتوزيعة (nginx conf.d، دليل php-fpm pool، شهادة snakeoil، …) |

أبقِ كل `apt`/`dnf`/`pacman`/`zypper` وكل مسار مثبَّت **داخل** هذا الملف. ولا يجوز لأي
مكان آخر في الشيفرة الإشارة إليها.

<a id="extend-the-package-map"></a>
## وسّع خريطة الحزم

أضف عموداً للعائلة الجديدة في `lib/distro/pkgmap.sh` (`_pkgmap_one`،
`case "${fam}:${logical}"`). وعلّم الحزم الاختيارية في `PKG_OPTIONAL` كي لا يُفشِل
غيابُ حزمة اختيارية التشغيل.

<a id="extend-detection"></a>
## وسّع الكشف

حدّث `lib/distro/detect.sh`:

- اربط قيم `ID`/`ID_LIKE` الجديدة بالعائلة،
- أبقِ رفض الأنظمة غير المدعومة فعلاً برمز خروج 3.

<a id="version-sensitive-templates"></a>
## قوالب حسّاسة للإصدار

إذا كانت التوزيعة تشحن إصداراً رئيسياً جديداً من مكوّن بصيغة إعداد مختلفة (مثل
Dovecot 2.4)، فأضف دليل قوالب موازياً (`templates/dovecot24/`) واختره وقت التشغيل.
لا تُعِد استخدام القوالب الخاطئة بصمت — ارفض برسالة واضحة حتى توجد القوالب.

<a id="documentation-and-tests"></a>
## التوثيق والاختبارات

- أضف التوزيعة إلى جدول الدعم في README.
- وثّق أي شيء معلَّم بـ `[تحقق]` في هذا الملف.
- أضف التوزيعة إلى مصفوفة اختبار الأجهزة الوهمية (`tests/vm/`) وشغّل قائمة التحقق
  الكاملة: تثبيت كامل، تثبيت أدنى، إضافة webmail لاحقاً، إزالة مكوّن،
  idempotency، نسخ احتياطي/استعادة، إلغاء التثبيت، و(لعائلة Fedora/RHEL) SELinux
  في وضع enforcing.

<a id="rule-of-thumb"></a>
## قاعدة عامة

إن وجدت نفسك تكتب `apt` أو `dnf` أو `www-data` أو مسار `/etc/...` خارج
`lib/distro/*.sh`، فتوقّف وأضفه إلى التجريد بدلاً من ذلك.
