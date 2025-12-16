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
