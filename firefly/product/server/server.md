# Firefly Server
*Backend server for the Firefly application*

The Firefly server provides API endpoints for the mobile application and handles backend functionality.

## Technology Stack

- **Framework**: Flask (Python)
- **Protocol**: HTTP
- **Port**: 8080
- **Deployment**: Mac mini server

## API Endpoints

### Health Check

**Endpoint**: `/api/ping`  
**Method**: GET  
**Purpose**: Server health check for connection monitoring

**Response**:
```json
{
  "message": "Firefly server is alive!",
  "status": "ok"
}
```

**Status Code**: 200 OK

## Server Configuration

- **Host**: 185.96.221.52 (public IP)
- **Local Network**: 192.168.1.76
- **Port**: 8080
- **Access**: HTTP (no TLS currently)

## Running the Server

The server runs continuously on the Mac mini, accepting connections from both local network and internet.

**Note**: Currently configured for development/testing. Production deployment would require:
- HTTPS/TLS encryption
- Authentication/authorization
- Rate limiting
- Proper error handling
- Logging and monitoring
