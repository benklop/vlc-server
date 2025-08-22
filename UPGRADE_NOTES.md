# Sinatra 4.x Upgrade Notes

## Changes Made

This document outlines the changes required to upgrade from Sinatra 3.x to 4.x and resolve the test failures.

## Issues Encountered

### 1. Host Authorization (Primary Issue)
- **Problem**: Sinatra 4.x introduced stricter host authorization by default
- **Symptom**: Tests failing with "Host not permitted" (403 errors)
- **Root Cause**: Rack::Test doesn't automatically set proper host headers

### 2. Missing Dependencies
- **Problem**: Sinatra 4.x separated the `rackup` gem as a separate dependency
- **Symptom**: "required gems weren't found" error when starting

## Solutions Implemented

### 1. Added Missing Dependencies
```ruby
# Added to Gemfile
gem 'rackup', '~> 2.2'
```

### 2. Configured Host Authorization
```ruby
# In lib/vlc_streaming_app.rb
set :protection, :allowed_hosts => ["localhost", "127.0.0.1", "0.0.0.0", "example.org"]
```

### 3. Updated Test Suite
- Added helper method `get_with_host` that includes proper host headers
- Updated all test requests to use this helper
- Set `RACK_ENV = 'test'` in spec_helper.rb

```ruby
# Helper method in spec files
def get_with_host(path, params = {})
  get path, params, { 'HTTP_HOST' => 'localhost:8080' }
end
```

## Updated Dependencies

- **sinatra**: `~> 3.0` → `~> 4.1`
- **puma**: `~> 6.0` → `~> 6.6`
- **concurrent-ruby**: `~> 1.2` → `~> 1.3`
- **rake**: `~> 13.0` → `~> 13.3`
- **rspec**: `~> 3.12` → `~> 3.13`
- **rack-test**: `~> 2.1` → `~> 2.2`
- **Added**: `rackup ~> 2.2`

## Test Results

- ✅ All 19 test examples now pass
- ✅ VLCStreamer tests: 10 examples, 0 failures
- ✅ VLCStreamingApp tests: 9 examples, 0 failures
- ✅ Application starts correctly in all modes (dev, production, Docker)

## Production Considerations

The current configuration allows requests from common localhost/Docker hosts. For production deployment, you may want to:

1. **Restrict allowed hosts** to your actual domain(s):
   ```ruby
   set :protection, :allowed_hosts => ["yourdomain.com", "www.yourdomain.com"]
   ```

2. **Use environment variables** for host configuration:
   ```ruby
   allowed_hosts = ENV['ALLOWED_HOSTS']&.split(',') || ["localhost", "127.0.0.1"]
   set :protection, :allowed_hosts => allowed_hosts
   ```

3. **Enable other security features** as needed:
   ```ruby
   set :protection, {
     :allowed_hosts => your_hosts,
     :except => [:json_csrf]  # Example of other protection options
   }
   ```

## Files Modified

1. **Gemfile** - Added rackup dependency, updated gem versions
2. **lib/vlc_streaming_app.rb** - Added host authorization configuration
3. **spec/spec_helper.rb** - Set test environment
4. **spec/vlc_streaming_app_spec.rb** - Added host headers to all requests

## Compatibility

- ✅ Ruby 3.2.2
- ✅ Sinatra 4.1.1
- ✅ Puma 6.6.1
- ✅ RSpec 3.13
- ✅ Docker deployment
- ✅ All rake tasks
