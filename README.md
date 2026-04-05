Flutter messenger app using Firebase Auth + Firestore and Cloudinary for media uploads.

## Cloudinary setup for chat media

1. Create a Cloudinary account (free tier).
2. Create an unsigned upload preset in Cloudinary settings.
3. Run the app with Cloudinary values:

```bash
flutter run \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

For release builds, pass the same `--dart-define` values to your build command.
Here's what's now in the app:

Chat list as home screen with unread counters and last message preview<br>
Typing indicator (live, auto-clears after 2s)
Online status + last seen timestamps
Reply to message with preview bar
Message reactions (❤️ 👍 😂 😮 😢 🙏) via long-press
Read receipts (✓ / ✓✓ with blue ticks)
Date dividers (Today / Yesterday / date)
Dark/light theme toggle in profile
Profile picture upload via Cloudinary
Emoji picker in chat
Cached network images for avatars
Edit/delete/copy from long-press menu
Install with adb install -r build/app/outputs/flutter-apk/app-debug.apk.
