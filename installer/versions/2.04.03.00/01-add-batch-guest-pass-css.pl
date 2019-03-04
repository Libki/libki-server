$dbh->do(q|
INSERT IGNORE INTO settings ( instance, name, value ) SELECT DISTINCT(instance), 'BatchGuestPassCustomCSS',  'body { /* default body style emulates a pre tag */
    font-family: monospace;
    white-space: pre;
    display: block;
    unicode-bidi: embed;
}
.guest-pass { /* each username and password is in a guest-pass span */
    /* page-break-before: always; */ /* This will cause each pass to have a page break, good for use with receipt printers */
}
.guest-pass-username {} /* span containing the username label and the username itself */
.guest-pass-username-label {} /* span containing the username label */
.guest-pass-username-content {} /* span containing the username itself */
.guest-pass-password {} /* span containing the password label and the password itself */
.guest-pass-password-label {} /* span containing the password label */
.guest-pass-password-content {} /* span containing the password itself */
'
FROM settings;
|);
