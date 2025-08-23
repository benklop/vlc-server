# Docker Port Configuration Fix

## Issue
When deploying with Docker using a custom port, Puma was failing with an "Address in use" error because:

1. The Sinatra application was configured with `set :port`
2. The Puma configuration also had both `port` and `bind` directives
3. This caused both Sinatra and Puma to try to bind to the same port, creating a conflict

## Root Cause
```
Error: Address in use - bind(2) for "0.0.0.0" port 8450 (Errno::EADDRINUSE)
```

The issue was having duplicate port binding configuration:
- **Sinatra app**: `set :port, ENV.fetch('HTTP_PORT', '8080').to_i`
- **Puma Docker config**: Both `port ENV.fetch('HTTP_PORT'...)` AND `bind "tcp://0.0.0.0:#{ENV.fetch('HTTP_PORT'...)}"`

## Solution
1. **Removed port configuration from Sinatra app** - When using Puma, the web server handles port binding, not the application
2. **Simplified Puma Docker config** - Removed the `port` directive and kept only `bind` for Docker
3. **Updated configuration hierarchy**:
   - **Docker**: Uses `bind` directive only (required for container networking)
   - **Development/Production**: Uses `port` directive (simpler for local development)

## Files Changed
- `lib/vlc_streaming_app.rb` - Removed Sinatra port configuration
- `docker/puma.rb` - Removed duplicate `port` directive
- `spec/vlc_streaming_app_configuration_spec.rb` - Updated tests for new configuration

## Verification
```bash
# Test custom port deployment
docker run --rm -p 9000:9000 -e HTTP_PORT=9000 vlc-streaming-server
curl http://localhost:9000/health  # Should return 200 OK
```

## Result
✅ Docker deployments now work correctly with custom ports
✅ No more port binding conflicts
✅ All tests still pass (26 examples, 0 failures)
