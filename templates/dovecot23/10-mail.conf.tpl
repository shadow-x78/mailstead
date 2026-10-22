mail_location = maildir:~/Maildir
mail_uid = vmail
mail_gid = vmail
first_valid_uid = 5000
last_valid_uid = 5000
first_valid_gid = 5000
last_valid_gid = 5000
mail_privileged_group = vmail
mail_access_groups = vmail

namespace inbox {
  inbox = yes
  separator = .
  prefix =
  mailbox Drafts  { special_use = \Drafts  auto = subscribe }
  mailbox Junk    { special_use = \Junk    auto = subscribe }
  mailbox Sent    { special_use = \Sent    auto = subscribe }
  mailbox Trash   { special_use = \Trash   auto = subscribe }
  mailbox Archive { special_use = \Archive auto = no }
}