# 10-auth.conf.tpl - authentication. Managed by Mailstead.
disable_plaintext_auth = yes
auth_mechanisms = plain login
auth_username_format = %Ln
!include auth-sql.conf.ext