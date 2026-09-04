# PocketVR Bridge

A working native prototype inspired by the mobile PC-VR tracking project in [the source video](https://www.youtube.com/watch?v=SumuUznu8xc).

## What is implemented

- **iOS:** native SwiftUI; live ARKit world tracking; TrueDepth face/eye tracking mode; split stereo test view; opt-in UDP pose stream; bundled full transcript.
- **Android:** native Java; live Camera2 preview; rotation-vector head orientation; split stereo overlay; opt-in UDP pose stream; bundled full transcript.
- **Linux:** UDP pose receiver and dashboard; OpenXR API layer that intercepts `xrLocateViews` and applies phone pose to an existing OpenXR runtime.

## OpenXR boundary

This is a real bridge prototype, not a replacement for Monado/SteamVR's compositor or graphics runtime. Run an existing OpenXR runtime on Linux, then load the PocketVR layer with `XR_API_LAYER_PATH=linux/build`. The app provides camera/sensor tracking and stereo viewing; the Linux bridge provides the phone-to-OpenXR pose path.

The complete transcript is bundled in both mobile targets as `transcript.txt`.
