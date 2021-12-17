INSERT IGNORE INTO settings ( name, value ) VALUES ( 'BatchGuestPassTemplate', '<html>
  <head>
    <style type="text/css">[% batch_guest_pass_custom_css %]</style>
  </head>
  <body>
    [% FOREACH g IN guests %]
      <p class="guest-pass">
        <p class="guest-pass-username">
          <span class="guest-pass-username-label">[% batch_guest_pass_username_label %]</span><span class="guest-pass-username-content">[% g.username %]</span>
        </p>
        <p class="guest-pass-password">
          <span class="guest-pass-password-label">[% batch_guest_pass_password_label %]</span><span class="guest-pass-password-content">[%g. password %]</span>
        </p>
      </p>
      <br/>
    [% END %]
  </body>
</html>');
