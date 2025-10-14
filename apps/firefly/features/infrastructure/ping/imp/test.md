# ping test
*verify client-server connectivity*

Tests that the client can successfully connect to the server's `/api/ping` endpoint.

**Server requirement**: Server running at 185.96.221.52:8080, responding to `/api/ping` with 200 OK

**Test logic**:
1. Make HTTP GET request to server's `/api/ping` endpoint
2. Check response status code
3. Return success if 200 OK, failure with reason otherwise

**Success criteria**:
- Server responds with 200 OK within 2 seconds
- No network errors occur

**Running the test**:
```bash
cd apps/firefly/features/testing/imp
./test-feature.sh ping
```

**Implementation**: See `ping/imp/ios/test.md` and `ping/imp/eos/test.md` for platform-specific test code.
