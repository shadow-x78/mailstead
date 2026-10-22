# 20-lmtp.conf.tpl - LMTP protocol (delivery from Postfix). Managed by Mailstead.
protocol lmtp {
  mail_plugins = $mail_plugins sieve
}