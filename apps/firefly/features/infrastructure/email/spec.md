# email
*send any email to a user*

The `email` feature sends any email (any subject, body) from `admin@microclub.org` to any email address. In firefly, it's used only to send a one-time PIN so people can log in without remembering passwords.

`email` also has the ability to read email sent to `admin@microclub.org`. This lets us automatically test that email send/receive is working.