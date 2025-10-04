# Product
*The runnable Firefly applications*

The `product/` folder contains complete, executable versions of Firefly for each platform. These are the actual programs that run on devices and servers.

## Product Structure

```
product/
├── app/
│   ├── ios/        Complete iOS Xcode project
│   └── eos/        Complete Android project
└── server/
    ├── py/         Complete Flask application
    ├── server.md   Server architecture and API
    ├── deployment.md
    └── network.md
```

## Relationship to Features

While `features/` contains modular specifications and code fragments, `product/` contains the integrated, runnable result. Think of it this way:

- **Features** = Recipe ingredients and instructions
- **Product** = The finished dish

Each product integrates code from multiple features. For example, the iOS app combines:
- Connection monitoring (from `features/connection/imp/ios/`)
- Logo display (from `features/logo/imp/ios/`)
- Status background (from `features/status-background/imp/ios/`)

## Development Workflow

1. **Specify**: Write feature specifications in `features/`
2. **Implement**: Create platform-specific code in feature `imp/` folders
3. **Integrate**: Patch feature code into product applications
4. **Run**: Execute and test from `product/`
5. **Deploy**: Ship products to users

## Products as Targets

Features specify which products need to implement them:
- **iOS target**: `product/app/ios/`
- **Android (eos) target**: `product/app/eos/`
- **Server (py) target**: `product/server/py/`

## Operational Documentation

Server operational docs (deployment, network configuration) live in `product/server/` because they describe how to run the server product, not individual features.

## Current State

The Firefly product currently includes:
- iOS app with connection monitoring and visual feedback
- Android app with the same capabilities
- Flask server providing health check API
