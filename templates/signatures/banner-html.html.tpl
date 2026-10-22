<!-- Mailstead - Signature Banner Block https://github.com/shadow-x78/mailstead -->

<table cellpadding="0" cellspacing="0" border="0" dir="{{DIR}}" style="font-family:{{FONT_STACK}};font-size:13px;line-height:1.4;color:#333333;{{DIR_CSS}}">
  <tr>
    {{#LOGO_URL}}<td valign="top" style="padding-right:14px;"><img src="{{LOGO_URL}}" width="{{LOGO_W}}" height="{{LOGO_H}}" alt="{{ORG}}" style="display:block;border:0;"></td>{{/LOGO_URL}}
    <td valign="top" style="{{#LOGO_URL}}border-left:2px solid {{ACCENT}};padding-left:14px;{{/LOGO_URL}}">
      <div style="font-size:15px;font-weight:bold;color:#111111;">{{NAME}}</div>
      <div>{{TITLE}}{{#ORG}} &middot; {{ORG}}{{/ORG}}</div>
      <div>{{#PHONE}}<a href="tel:{{PHONE_RAW}}" style="color:#333333;text-decoration:none;">{{PHONE}}</a> &middot; {{/PHONE}}<a href="mailto:{{EMAIL}}" style="color:{{ACCENT}};">{{EMAIL}}</a></div>
      {{#WEBSITE}}<div><a href="{{WEBSITE}}" style="color:{{ACCENT}};">{{WEBSITE_LABEL}}</a></div>{{/WEBSITE}}
    </td>
  </tr>
  {{#BANNER_URL}}<tr><td colspan="2" style="padding-top:12px;"><a href="{{BANNER_LINK}}" rel="noopener noreferrer" target="_blank"><img src="{{BANNER_URL}}" width="{{BANNER_W}}" height="{{BANNER_H}}" alt="{{BANNER_ALT}}" style="display:block;border:0;max-width:600px;"></a></td></tr>{{/BANNER_URL}}
  {{#DISCLAIMER}}<tr><td colspan="2" style="padding-top:10px;font-size:11px;color:#777777;">{{DISCLAIMER}}</td></tr>{{/DISCLAIMER}}
</table>
