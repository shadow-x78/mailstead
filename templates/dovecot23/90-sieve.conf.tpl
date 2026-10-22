# 90-sieve.conf.tpl - sieve plugin. Managed by Mailstead.
plugin {
  sieve = file:~/sieve;active=~/.dovecot.sieve
  sieve_before = /etc/dovecot/sieve/before.d
  sieve_dir = ~/sieve
}