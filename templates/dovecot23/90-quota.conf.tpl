mail_plugins = $mail_plugins quota

plugin {
  quota = maildir:User quota
  quota_status_success = DUNNO
  quota_status_nouser = DUNNO
  quota_status_overquota = "552 5.2.2 Mailbox is full"
}