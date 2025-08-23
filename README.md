# VLC Streaming Web Server

A Ruby-based web server that accepts video URLs and streams them back to clients using VLC. When a client disconnects, the VLC process is automatically terminated.

## Features

- **Dynamic streaming**: Accept any video URL via HTTP parameter
- **Automatic cleanup**: VLC processes are stopped when clients disconnect
- **Health monitoring**: Built-in health check endpoint
- **Multiple concurrent streams**: Support for multiple clients streaming different videos
- **Docker support**: Easy deployment with Docker and Docker Compose
- **Full test coverage**: RSpec tests for all components with 97%+ coverage
- **Rake tasks**: Convenient development and deployment tasks

## Technology Stack

- **Ruby 3.2.2** with Sinatra web framework
- **VLC Media Player** for video processing and streaming
- **Puma** web server for production
- **RSpec** for testing
- **Docker** for containerization

## Project Structure

```text
vlc-server/
├── bin/
│   └── vlc-streaming-server    # Executable application entry point
├── config/
│   └── puma.rb                 # Unified Puma configuration
├── docker/
│   └── healthcheck.sh          # Health check script for Docker
├── lib/
│   ├── vlc_streamer.rb         # VLC process management
│   ├── vlc_streaming_app.rb    # Sinatra application
│   └── vlc_process_manager.rb  # Process tracking and cleanup
├── views/
│   └── index.erb               # Homepage template
├── spec/                       # RSpec tests
├── config.ru                   # Rack configuration
├── Rakefile                    # Task definitions
├── Dockerfile                  # Container build
├── docker-compose.yml       # Docker Compose setup
└── .tool-versions           # Ruby version specification
```

## Quick Start

### Development Setup

```bash
# Install dependencies
rake setup:dev

# Start development server
rake server:dev

# Or with auto-reload
rake server:watch
```

### Docker Deployment

```bash
# Using Docker Compose (recommended)
rake docker:up

# With custom environment file
cp .env.example .env
# Edit .env with your settings
rake docker:up

# Or build manually
rake docker:build
docker run -p 8080:8080 vlc-streaming-server
```

### Testing

```bash
# Run all tests
rake spec

# Run tests with coverage report
rake spec:coverage

# Test server endpoints (requires running server)
rake test:endpoints

# View coverage summary
rake info:coverage
```

## Configuration

The server can be configured using environment variables or a `.env` file for Docker deployments.

### Environment Variables

#### Application Configuration
- `PORT` - Port to bind the server to (default: `8080`)
- `ALLOWED_HOSTS` - Comma-separated list of allowed hosts for host authorization (default: `localhost,127.0.0.1,0.0.0.0,example.org`)
- `RACK_ENV` - Application environment: `development`, `production`, or `test` (default: `production` in Docker)

#### Performance Tuning

- `PUMA_THREADS` - Number of threads per Puma process for concurrent requests (default: `2` dev, `5` prod, `10` Docker)
- `WEB_CONCURRENCY` - Number of Puma worker processes (default: `2` prod, `0` Docker for single-mode)

#### Streaming Configuration

- `STREAM_CHUNK_SIZE` - Chunk size for reading data from VLC in bytes (default: `8192`)
- `STREAM_SELECT_TIMEOUT` - Timeout for I/O select operations in seconds (default: `0.1`)

#### VLC Process Management

- `VLC_GRACEFUL_TIMEOUT` - Timeout for graceful VLC shutdown in seconds (default: `5`)
- `VLC_FORCE_TIMEOUT` - Timeout for forced VLC shutdown in seconds (default: `2`)

### Environment File

For Docker deployments, copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
# Edit .env with your configuration
```

### Examples

```bash
# Run on port 3000
PORT=3000 rake server:dev

# Allow additional hosts
ALLOWED_HOSTS="localhost,127.0.0.1,myserver.com" rake server:dev

# Increase concurrent connections for high load
PUMA_THREADS=20 rake server:puma

# Docker with custom configuration
PORT=3000 ALLOWED_HOSTS="localhost,127.0.0.1,docker.local" rake docker:up

# High-performance Docker deployment
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e PUMA_THREADS=15 \
  -e ALLOWED_HOSTS="myserver.com,www.myserver.com" \
  vlc-streaming-server

# Test custom port with Docker
docker run --rm -p 9000:9000 -e PORT=9000 vlc-streaming-server
```

## API Endpoints

### Stream Video

**Endpoint:** `GET /stream?video_url=<URL>`

**Parameters:**

- `video_url` (required): The URL of the video to stream

**Example:**

```bash
# Stream to file
curl "http://localhost:8080/stream?video_url=https://example.com/video.mp4" --output video.ts

# Play directly with VLC
vlc "http://localhost:8080/stream?video_url=https://example.com/video.mp4"

# Play with ffplay
ffplay "http://localhost:8080/stream?video_url=https://example.com/video.mp4"
```

### Health Check

**Endpoint:** `GET /health`

Returns JSON with server status and active stream count.

### Home Page

**Endpoint:** `GET /`

Returns an HTML page with usage instructions.

## How It Works

1. Client makes a request to `/stream` with a `video_url` parameter
2. Server spawns a VLC process to transcode the video to MPEG-TS format
3. Video data is streamed directly from VLC to the HTTP response
4. When the client disconnects, the VLC process is automatically terminated
5. Multiple clients can stream different videos simultaneously

## Available Rake Tasks

### Server Management

- `rake server:dev` - Start development server (Sinatra built-in)
- `rake server:puma` - Start development server with Puma
- `rake server:watch` - Start server with auto-reload
- `rake server:prod` - Start production server with Puma

### Testing

- `rake spec` - Run all RSpec tests
- `rake spec:unit` - Run unit tests only
- `rake spec:coverage` - Run tests with coverage report
- `rake test:endpoints` - Test server endpoints (requires running server)

### Docker

- `rake docker:build` - Build Docker image
- `rake docker:up` - Start with Docker Compose
- `rake docker:down` - Stop Docker Compose

### Setup

- `rake setup:install` - Install dependencies
- `rake setup:dev` - Complete development setup

### Information

- `rake info:project` - Show project information
- `rake info:tasks` - List all available tasks
- `rake info:coverage` - Show test coverage summary

## Web Server Architecture

This application uses the standard Ruby web stack:

- **Sinatra** - Web application framework
- **Rack** - Interface between Ruby web apps and web servers
- **Puma** - High-performance web server
- **config.ru** - Rack configuration file (required by Puma)

### Configuration Files

- **`config/puma.rb`** - Production Puma settings (multiple workers, optimized for performance)
- **`config/puma.development.rb`** - Development Puma settings (single worker, easier debugging)
- **`docker/puma.rb`** - Docker-optimized settings (container-specific logging and resource limits)

## Dependencies

- VLC Media Player (cvlc command)
- Ruby 3.2.2 (specified in .tool-versions)
- Bundler for dependency management

## Development

### Using Rake Tasks (Recommended)

```bash
# Setup development environment
rake setup:dev

# Start server with auto-reload
rake server:watch

# Run tests
rake spec
```

### Manual Setup

```bash
bundle install
ruby bin/vlc-streaming-server
```

## Performance & Scaling

This server is designed for home/small office use. For increased capacity:

**Increase concurrent connections:**

```bash
# Handle more clients (recommended for most use cases)
PUMA_THREADS=20 docker run -p 8080:8080 vlc-streaming-server
```

**Multiple containers:**

```bash
# Scale horizontally with load balancer
docker-compose up --scale vlc-server=3
```

**Resource limits:** Each VLC stream uses ~50-100MB RAM and moderate CPU. Monitor with `/health` endpoint.
