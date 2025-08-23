# Environment Variables Documentation Update

## Added Documentation for Missing Variables

### Previously Documented
- `PORT`
- `ALLOWED_HOSTS`

### Now Added
- `PUMA_THREADS` - Controls concurrent connection capacity
- `WEB_CONCURRENCY` - Controls worker processes (mainly for production)
- `RACK_ENV` - Application environment setting
- `PORT` - Legacy/Heroku compatibility variable

## Organization

### Application Configuration
Core settings for the streaming server functionality.

### Performance Tuning
Variables that affect capacity and resource usage - critical for scaling.

### Legacy/Platform Variables
Compatibility variables for different deployment platforms.

## Default Values by Environment

| Variable | Development | Production | Docker |
|----------|-------------|------------|--------|
| `PUMA_THREADS` | 2 | 5 | 10 |
| `WEB_CONCURRENCY` | 0 | 2 | 0 |
| `PORT` | 8080 | 8080 | 8080 |
| `RACK_ENV` | development | production | production |

## Usage Examples Added

- Basic configuration examples
- High-performance Docker deployment
- Scaling for concurrent connections
- Multi-environment setups

## Files Updated

- `README.md` - Complete environment variables section
- `.env.example` - Added missing variables to all scenarios

This makes the configuration much more discoverable and usable! 🎯
