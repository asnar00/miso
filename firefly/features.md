# Features
*Current features implemented in Firefly*

Firefly currently implements the following features:

## Core Features

- **connection** - Monitor client-server connectivity via health check endpoint
- **logo** - Display the nøøb character (ᕦ(ツ)ᕤ) in the app
- **logo/icon** - App icon using the nøøb character
- **background** - Visual connection status feedback (turquoise when connected, grey when disconnected)

## Feature Documentation

Each feature has:
- A specification file (e.g., `connection.md`) describing what it does
- Implementation code in `connection/imp/{ios,eos,py}/` for each platform

See `miso/features.md` for detailed information about how features work in the miso system.
