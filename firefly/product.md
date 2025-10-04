# Product
*Runnable Firefly applications*

The Firefly product consists of mobile apps and a server, assembled from the features in `features/`.

## Current Products

### App
- **iOS**: Native SwiftUI application (`product/app/imp/ios/`)
- **Android**: Native Jetpack Compose application (`product/app/imp/eos/`)

### Server
- **Python**: Flask HTTP server (`product/server/imp/py/`)

## Current Capabilities

The Firefly product currently implements:
- Server connection monitoring with visual feedback
- Nøøb logo display and app icon
- Development/testing deployment on Mac mini

## Product Documentation

- `app.md` - Mobile app specification
- `server.md` - Server specification and API
- `server/deployment.md` - Server deployment configuration
- `server/network.md` - Network setup for public access

See `miso/products.md` for how products work in the miso system.
