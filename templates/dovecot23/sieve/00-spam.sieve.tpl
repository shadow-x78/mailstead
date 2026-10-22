# 00-spam.sieve - file Rspamd-flagged mail into Junk before user rules.
require ["fileinto"];
if header :contains "X-Spam-Flag" "YES" {
  fileinto "Junk";
  stop;
}