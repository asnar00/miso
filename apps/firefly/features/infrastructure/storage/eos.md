# Storage Implementation - Android/e/OS

*Android-specific local storage using SharedPreferences, Room, and File APIs*

## Key-Value Storage: SharedPreferences

Use `SharedPreferences` for simple login state:

```kotlin
package com.miso.noobtest

import android.content.Context
import android.content.SharedPreferences
import java.util.UUID

class Storage private constructor(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("firefly_storage", Context.MODE_PRIVATE)

    companion object {
        @Volatile
        private var instance: Storage? = null

        fun getInstance(context: Context): Storage {
            return instance ?: synchronized(this) {
                instance ?: Storage(context).also { instance = it }
            }
        }
    }

    // Login state
    fun saveLoginState(email: String, isLoggedIn: Boolean) {
        prefs.edit()
            .putString("user_email", email)
            .putBoolean("is_logged_in", isLoggedIn)
            .apply()
    }

    fun getLoginState(): Pair<String?, Boolean> {
        val email = prefs.getString("user_email", null)
        val isLoggedIn = prefs.getBoolean("is_logged_in", false)
        return Pair(email, isLoggedIn)
    }

    fun clearLoginState() {
        prefs.edit()
            .remove("user_email")
            .remove("is_logged_in")
            .apply()
    }

    // Device ID
    fun getDeviceID(): String {
        val existingID = prefs.getString("device_id", null)
        if (existingID != null) {
            return existingID
        }

        val newID = UUID.randomUUID().toString()
        prefs.edit().putString("device_id", newID).apply()
        return newID
    }
}
```

## Using in MainActivity

In `MainActivity.kt`:

```kotlin
class MainActivity : ComponentActivity() {
    private lateinit var storage: Storage

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        storage = Storage.getInstance(applicationContext)

        setContent {
            FireflyApp()
        }
    }

    @Composable
    fun FireflyApp() {
        var isLoggedIn by remember { mutableStateOf(false) }
        var userEmail by remember { mutableStateOf<String?>(null) }

        // Check storage on startup
        LaunchedEffect(Unit) {
            val (email, loggedIn) = storage.getLoginState()
            userEmail = email
            isLoggedIn = loggedIn
        }

        if (isLoggedIn && userEmail != null) {
            MainScreen(email = userEmail!!)
        } else {
            LoginScreen(onLogin = { email ->
                userEmail = email
                isLoggedIn = true
                storage.saveLoginState(email, true)
            })
        }
    }
}
```

## Future: Structured Storage with Room

For cached posts and complex data:

```kotlin
// 1. Define entity
@Entity(tableName = "posts")
data class PostEntity(
    @PrimaryKey val id: Int,
    val title: String,
    val body: String,
    val userId: Int
)

// 2. Define DAO
@Dao
interface PostDao {
    @Query("SELECT * FROM posts WHERE userId = :userId")
    suspend fun getPostsByUser(userId: Int): List<PostEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPost(post: PostEntity)
}

// 3. Define Database
@Database(entities = [PostEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun postDao(): PostDao
}
```

## Future: File Storage

For images and media:

```kotlin
fun saveImage(context: Context, bitmap: Bitmap, filename: String) {
    val file = File(context.filesDir, filename)
    FileOutputStream(file).use { out ->
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
    }
}

fun loadImage(context: Context, filename: String): Bitmap? {
    val file = File(context.filesDir, filename)
    if (!file.exists()) return null

    return BitmapFactory.decodeFile(file.absolutePath)
}
```

## Testing

Add to TestRegistry:

```kotlin
fun testStorage(context: Context): TestResult {
    val storage = Storage.getInstance(context)
    val testEmail = "test@example.com"

    // Save
    storage.saveLoginState(testEmail, true)

    // Load
    val (email, isLoggedIn) = storage.getLoginState()

    return if (email == testEmail && isLoggedIn) {
        // Clean up
        storage.clearLoginState()
        TestResult(success = true)
    } else {
        TestResult(success = false, error = "Storage read/write failed")
    }
}
```

## Important Notes

- SharedPreferences is automatically synced to disk (in background)
- Use `apply()` instead of `commit()` for async writes (better performance)
- Don't store sensitive data (like passwords) - use EncryptedSharedPreferences for that
- SharedPreferences persists across app updates but is deleted on uninstall or clear data
- Maximum practical size: ~1MB
- Thread-safe for concurrent reads/writes
