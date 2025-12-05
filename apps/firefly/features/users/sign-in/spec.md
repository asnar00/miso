# sign-in
*how users log in via the app*

The app stores (in local storage) an email address and a "logged in" flag. If "logged in" is True, then starting the app goes straight to the home screen for that user's email.

If not, then we go to the sign-in page. The sign-in page asks the user for their email address. If the email address exists in the database, then the user is known; otherwise, this is a new user, and we create a database record for them (see `new-user`).

In either case, we send a 4-digit one-time code to that email address, which is valid for ten minutes. The app prompts for the 4-digit code, and if the user enters it correctly, we record them as "logged in" on that device.

**Testing mode**: If the email ends with `@example.com`, the verification code is sent to `ash.nehru@gmail.com` instead (with the original email shown in the subject line). This allows testing the sign-up flow without needing real email addresses.

