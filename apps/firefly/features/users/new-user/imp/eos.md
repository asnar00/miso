# new-user Android/e/OS implementation
*welcome screen for first-time users*

## File Structure

Create new file:
- `apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/NewUserView.kt`

## NewUserView.kt

Jetpack Compose welcome screen:

```kotlin
package com.miso.noobtest

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun NewUserView(
    email: String,
    onGetStarted: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF40E0D0)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(40.dp)
        ) {
            Spacer(modifier = Modifier.weight(1f))

            // Logo
            Text(
                text = "ᕦ(ツ)ᕤ",
                fontSize = 80.sp,
                color = Color.Black
            )

            // Welcome text
            Text(
                text = "welcome",
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
                color = Color.Black
            )

            // User email
            Text(
                text = email,
                fontSize = 20.sp,
                color = Color.Black.copy(alpha = 0.8f)
            )

            Spacer(modifier = Modifier.weight(1f))

            // Get Started button
            Button(
                onClick = {
                    Logger.log("[NewUser] User tapped Get Started")
                    onGetStarted()
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 60.dp)
            ) {
                Text(
                    text = "Get Started",
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(8.dp)
                )
            }
        }
    }
}
```

## Integration

This view is shown after sign-in when `isNewUser` is true and `hasSeenWelcome` is false.

See `sign-in/imp/eos.md` for the complete MainActivity.kt implementation showing the three-state navigation:
1. Not authenticated → SignInView
2. Authenticated + new user + hasn't seen welcome → NewUserView
3. Authenticated (or has seen welcome) → MainContentView

## Testing

Build and deploy:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Manual test:
1. Clear login state: `curl http://localhost:8081/test/clear-login` (requires USB forwarding: `adb forward tcp:8081 tcp:8081`)
2. Restart app: `adb shell am force-stop com.miso.noobtest && adb shell am start -n com.miso.noobtest/.MainActivity`
3. Sign in with a new email address (one not in the database)
4. After entering the verification code, should see welcome screen
5. Tap "Get Started"
6. Should transition to main content view
7. If you sign out and sign in again with the same account, you won't see the welcome screen (device already registered)

## UI Design Notes

- Background: Turquoise (#40E0D0) matching iOS and main app
- Logo: ᕦ(ツ)ᕤ larger than sign-in (size 100sp)
- Welcome text: Large, bold, black
- Email: Smaller, slightly transparent black
- Button: Black background with white text, full width with padding
- Centered layout with generous spacing using weights
- Uses Jetpack Compose with Material 3
