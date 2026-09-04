# PocketVR Linux OpenXR bridge

This is the PC side of PocketVR. It is two small pieces:

1. `pocketvr_bridge.py` receives opt-in JSON pose packets from the mobile app on UDP `9000`, writes `/tmp/pocketvr_pose.json`, and exposes a live dashboard at HTTP `8790`.
2. `libpocketvr_openxr_layer.so` is an OpenXR API layer. It intercepts `xrLocateViews` in an **existing** OpenXR runtime and applies the latest phone orientation/position while preserving a 64 mm stereo eye separation.

## Run

```bash
python3 pocketvr_bridge.py --udp-port 9000 --http-port 8790
make
POCKETVR_STATE_FILE=/tmp/pocketvr_pose.json XR_API_LAYER_PATH="$PWD/build" <your-openxr-app>
```

Or install the layer for implicit loading:

```bash
make install-local
```

An existing OpenXR runtime such as Monado or SteamVR OpenXR is still required. This layer intentionally does not implement a compositor, graphics backend, or SteamVR video encoder; those are separate runtime responsibilities. The mobile app provides camera/sensor capture, stereo test display, and the network pose source.

The dashboard endpoints are `/api/state`, `/api/openxr`, and `/healthz`.
