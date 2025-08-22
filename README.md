# VLC Streaming Web Server

A Ruby-based web server that accepts video URLs and streams them back to clients using VLC. When a client disconnects, the VLC process is automatically terminated.

## Features

- **Dynamic streaming**: Accept any video URL via HTTP parameter
- **Automatic cleanup**: VLC processes are stopped when clients disconnect
- **Health monitoring**: Built-in health check endpoint
- **Multiple concurrent streams**: Support for multiple clients streaming different videos
- **Docker support**: Easy deployment with Docker and Docker Compose
- **Full test coverage**: RSpec tests for all components
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
│   └── vlc-streaming-server # Executable application entry point
├── config/
│   ├── puma.rb              # Production Puma configuration
│   └── puma.development.rb  # Development Puma configuration
├── docker/
│   └── puma.rb              # Docker-optimized Puma configuration
├── lib/
│   ├── vlc_streamer.rb      # VLC process management
│   └── vlc_streaming_app.rb # Sinatra application
├── spec/                    # RSpec tests
├── config.ru                # Rack configuration
├── Rakefile                 # Task definitions
├── Dockerfile               # Container build
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

# Or build manually
rake docker:build
docker run -p 8080:8080 vlc-streaming-server
```

### Testing

```bash
# Run all tests
rake spec

# Test server endpoints (requires running server)
rake test:endpoints
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

### Task Testing

- `rake spec` - Run all RSpec tests
- `rake spec:unit` - Run unit tests only
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

## Configuration

The server listens on port 8080 by default. You can modify this in `lib/vlc_streaming_app.rb` if needed.

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
