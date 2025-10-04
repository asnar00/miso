# Connection
*Monitoring connectivity to the Firefly server*

The Firefly system continuously monitors connection status between client apps and the server.

Client apps periodically check if the server is alive by calling a health check endpoint. The server responds with a simple status message. This allows the app to detect when the server is unreachable due to network issues, server downtime, or other connectivity problems.

This feature helps developers verify that the server is running, network connectivity is working, and the app can communicate with backend services during development and testing.
