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

