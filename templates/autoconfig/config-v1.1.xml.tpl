<?xml version="1.0" encoding="UTF-8"?>
<!-- Mailstead - Thunderbird Autoconfiguration Profile https://github.com/shadow-x78/mailstead -->

<clientConfig version="1.1">
  <emailProvider id="@@DOMAIN@@">
    <domain>@@DOMAIN@@</domain>
    <displayName>@@DISPLAY_NAME@@</displayName>
    <displayShortName>@@SHORT_NAME@@</displayShortName>
    <incomingServer type="imap">
      <hostname>@@MAIL_HOSTNAME@@</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>@@MAIL_HOSTNAME@@</hostname>
      <port>587</port>
      <socketType>STARTTLS</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
  </emailProvider>
</clientConfig>
