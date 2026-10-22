<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Mailstead - Apple Mobile Configuration Profile https://github.com/shadow-x78/mailstead -->

<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>EmailAccountDescription</key>
      <string>@@DISPLAY_NAME@@</string>
      <key>EmailAccountName</key>
      <string>@@EMAIL@@</string>
      <key>EmailAccountType</key>
      <string>EmailTypeIMAP</string>
      <key>EmailAddress</key>
      <string>@@EMAIL@@</string>
      <key>IncomingMailServerAuthentication</key>
      <string>EmailAuthPassword</string>
      <key>IncomingMailServerHostName</key>
      <string>@@MAIL_HOSTNAME@@</string>
      <key>IncomingMailServerPortNumber</key>
      <integer>993</integer>
      <key>IncomingMailServerUseSSL</key>
      <true/>
      <key>IncomingMailServerUsername</key>
      <string>@@EMAIL@@</string>
      <key>OutgoingMailServerAuthentication</key>
      <string>EmailAuthPassword</string>
      <key>OutgoingMailServerHostName</key>
      <string>@@MAIL_HOSTNAME@@</string>
      <key>OutgoingMailServerPortNumber</key>
      <integer>587</integer>
      <key>OutgoingMailServerUseSSL</key>
      <true/>
      <key>OutgoingMailServerUsername</key>
      <string>@@EMAIL@@</string>
      <key>OutgoingPasswordSameAsIncomingPassword</key>
      <true/>
      <key>PayloadDescription</key>
      <string>Mail account for @@EMAIL@@</string>
      <key>PayloadDisplayName</key>
      <string>@@DISPLAY_NAME@@</string>
      <key>PayloadIdentifier</key>
      <string>@@PAYLOAD_ID@@</string>
      <key>PayloadType</key>
      <string>com.apple.mail.managed</string>
      <key>PayloadUUID</key>
      <string>@@PAYLOAD_UUID@@</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
    </dict>
  </array>
  <key>PayloadDescription</key>
  <string>@@DISPLAY_NAME@@ mail configuration</string>
  <key>PayloadDisplayName</key>
  <string>@@DISPLAY_NAME@@</string>
  <key>PayloadIdentifier</key>
  <string>@@PAYLOAD_ID@@</string>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>@@PAYLOAD_UUID@@</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
