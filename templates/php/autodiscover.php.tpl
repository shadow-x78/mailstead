<?php
header('Content-Type: text/xml; charset=utf-8');
$cfg = @parse_ini_file('@@APP_ETC@@/autodiscover.ini');
$domains = @file('@@APP_LIB@@/domains.list', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
if (!$cfg || !$domains) { http_response_code(500); exit; }
$body = (string) file_get_contents('php://input', false, null, 0, 8192);
if (!preg_match('~<EMailAddress>\s*([A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,253})\s*</EMailAddress>~i', $body, $m)) {
    http_response_code(400); exit;
}
$email  = strtolower($m[1]);
$domain = substr(strrchr($email, '@'), 1);
if (!in_array($domain, $domains, true)) { http_response_code(404); exit; }
$x = static fn(string $s): string => htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8');
$host = $x($cfg['mail_host']); $imap = (int)$cfg['imap_port']; $smtp = (int)$cfg['smtp_port'];
$mail = $x($email);
echo '<?xml version="1.0" encoding="utf-8"?>' . "\n";
?>
<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/responseschema/2006">
  <Response xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a">
    <Account>
      <AccountType>email</AccountType>
      <Action>settings</Action>
      <Protocol>
        <Type>IMAP</Type>
        <Server><?= $host ?></Server>
        <Port><?= $imap ?></Port>
        <DomainRequired>off</DomainRequired>
        <LoginName><?= $mail ?></LoginName>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
      </Protocol>
      <Protocol>
        <Type>SMTP</Type>
        <Server><?= $host ?></Server>
        <Port><?= $smtp ?></Port>
        <DomainRequired>off</DomainRequired>
        <LoginName><?= $mail ?></LoginName>
        <SPA>off</SPA>
        <Encryption>TLS</Encryption>
        <AuthRequired>on</AuthRequired>
        <UsePOPAuth>off</UsePOPAuth>
        <SMTPLast>off</SMTPLast>
      </Protocol>
    </Account>
  </Response>
</Autodiscover>