# build-and-deploy
*compiling iOS apps and getting them onto devices*

This section covers building iOS applications with Xcode command-line tools and deploying them to physical devices, simulators, and beta testers.

## Topics

### [build](build-and-deploy/build.md)
Compiling iOS apps using `xcodebuild`, managing derived data, and handling linker flags (LD="clang" for Homebrew compatibility).

### [usb-deploy](build-and-deploy/usb-deploy.md)
Deploying apps directly to USB-connected iPhones for rapid development (~8-10 second workflow).

### [simulator](build-and-deploy/simulator.md)
Running and debugging apps in the iOS Simulator.

### [testflight](build-and-deploy/testflight.md)
Distributing beta builds to testers via Apple's TestFlight service.

## Quick Workflow

The fastest development cycle for USB-connected devices:

```bash
# 1. Build and deploy
./install-device.sh        # ~8-10 seconds total

# 2. Run and monitor
./watch-logs.py           # Stream real-time logs

# 3. Iterate quickly
./restart-app.sh          # Restart without rebuild
./stop-app.sh            # Stop when done
```

See `development/tools/` for ready-to-use scripts.

## Key Concepts

**Derived Data**: Xcode builds to `~/Library/Developer/Xcode/DerivedData/` with a hash-based path. Use wildcards or `find` to locate built apps.

**Linker Flag**: Always use `LD="clang"` with xcodebuild to avoid Homebrew linker conflicts on macOS.

**Device Detection**: Use `xcodebuild -showdestinations` to find connected iPhones and extract device IDs.

**Provisioning**: Use `-allowProvisioningUpdates` flag to let Xcode automatically manage development profiles.

## Typical Timeline

- **First build**: ~5-10 seconds
- **Incremental builds**: ~1-2 seconds
- **USB installation**: ~1-2 seconds
- **App restart**: <1 second

Total USB deployment: **~8-10 seconds** from code change to running on device.

## Detailed Guides

See the subtopics above for complete documentation on each deployment method. For troubleshooting build and deployment issues, see `troubleshooting.md`.
