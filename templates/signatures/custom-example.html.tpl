<!-- Mailstead - Custom HTML Signature Example https://github.com/shadow-x78/mailstead -->

<table cellpadding="0" cellspacing="0" border="0" dir="{{DIR}}" style="font-family:{{#RTL}}Tahoma, Arial, sans-serif{{/RTL}}{{#LTR}}Arial, Helvetica, sans-serif{{/LTR}};font-size:13px;line-height:1.5;color:#222222;">
  <tr>
    <td style="padding-bottom:4px;font-size:15px;font-weight:bold;color:#111111;">{{NAME}}</td>
  </tr>
  {{#TITLE}}<tr><td>{{TITLE}}{{#ORG}} - {{ORG}}{{/ORG}}</td></tr>{{/TITLE}}
  <tr>
    <td>{{#PHONE}}<a href="tel:{{PHONE_RAW}}" style="color:{{ACCENT}};text-decoration:none;">{{PHONE}}</a> &middot; {{/PHONE}}<a href="mailto:{{EMAIL}}" style="color:{{ACCENT}};">{{EMAIL}}</a></td>
  </tr>
  {{#WEBSITE}}<tr><td><a href="{{WEBSITE}}" style="color:{{ACCENT}};">{{WEBSITE_LABEL}}</a></td></tr>{{/WEBSITE}}
  {{#LOGO_URL}}<tr><td style="padding-top:8px;"><img src="{{LOGO_URL}}"{{#LOGO_W}} width="{{LOGO_W}}"{{/LOGO_W}}{{#LOGO_H}} height="{{LOGO_H}}"{{/LOGO_H}} alt="{{ORG}}" style="display:block;border:0;"></td></tr>{{/LOGO_URL}}
  {{#DISCLAIMER}}<tr><td style="padding-top:10px;font-size:11px;color:#777777;">{{DISCLAIMER}}</td></tr>{{/DISCLAIMER}}
</table>
