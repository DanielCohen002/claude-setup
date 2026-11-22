# Ideas

## Move Android's "Copied to clipboard" popup to the top
- Phone: Motorola edge 2025, Android 17 (SDK 37), connected over adb.
- The popup is a SystemUI clipboard preview, not a normal toast, so it has no position setting.
- Tried `cmd overlay fabricate` on `android:integer/config_toastDefaultGravity` (49 = top|center_horizontal). It failed with "must be root to fabricate overlays through the shell".
- Possible routes:
  - Look for a setting that turns the popup off (Settings → Display or Accessibility), checked via adb.
  - Root the phone and use a SystemUI overlay or Magisk module.
  - Use a third-party app that shows its own top notification on copy.
