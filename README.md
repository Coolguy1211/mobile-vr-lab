# Mobile VR Lab

A native mobile companion app inspired by the YouTube project in [this video](https://www.youtube.com/watch?v=SumuUznu8xc).

The app turns the video's full transcript into a readable field guide covering:

- phone-powered PC VR and off-the-shelf phone headsets
- ARKit visual-inertial head tracking
- camera/depth-assisted hand tracking and gesture mapping
- pupil/eye-tracking calibration constraints
- frame-rate, battery, and comfort trade-offs
- a full timestamped transcript

## Deliverables

- **Android:** native Java APK, built by GitHub Actions on Ubuntu
- **iOS:** native SwiftUI, device-targeted unsigned IPA, built by GitHub Actions on macOS 26 and intended for LiveContainer

The iOS IPA is not Apple-signed. Normal physical-device installation requires Apple signing/provisioning; LiveContainer can use an unsigned device-targeted payload.
