# Features
*Modular capabilities that define Firefly's behavior*

Features are the building blocks of Firefly. Each feature describes a complete capability that may span multiple parts of the system (client apps and server).

## What is a Feature?

A feature defines:
- **Functions**: What code needs to exist
- **Integration points**: Where those functions are called or mounted
- **Targets**: Which platforms need to implement the feature (iOS, Android, Python)

For example, the `connection` feature specifies both the client-side `testConnection()` function (called every second from the main loop) and the server-side `/api/ping` endpoint.

## Feature Structure

Each feature is a folder containing:
- **Feature specification** (`.md` file): Natural language description of what the feature does
- **Implementation folder** (`imp/`): Platform-specific code organized by target (`ios/`, `eos/`, `py/`)

Features form a tree. A feature `A/B/C` means "subfeature C of subfeature B of feature A".

## Cross-Cutting Behavior

Unlike traditional architectures that separate "client" and "server", features describe the entire system behavior for one capability. The `connection` feature owns both:
- Client behavior: Ping the server every second
- Server behavior: Respond to ping requests

This makes features self-contained and easier to understand, enable, or disable.

## Implementation

Each platform implementation (`imp/ios/`, `imp/eos/`, `imp/py/`) contains:
- Code fragments for that feature
- Integration notes explaining how to patch the code into the main product

The complete runnable applications live in `product/`, assembled from all enabled features.

## Current Features

Firefly currently has these features:
- **connection**: Monitor client-server connectivity
- **logo**: Display the ᕦ(ツ)ᕤ character
- **status-background**: Visual feedback (turquoise/grey background)
- **icon**: App icon design and assets
