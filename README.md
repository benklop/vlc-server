# VLC Streaming Web Server

A Ruby-based web server that accepts video URLs and streams them back to clients using VLC. When a client disconnects, the VLC process is automatically terminated.

## Features

- **Dynamic streaming**: Accept any video URL via HTTP parameter
- **YouTube playlist support**: Convert YouTube playlists to M3U format for streaming
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
│   ├── routes/                 # Modular route definitions
│   │   ├── base.rb            # Shared route functionality
│   │   ├── streaming.rb       # Video streaming endpoint
│   │   ├── playlist.rb        # YouTube playlist endpoint
│   │   ├── health.rb          # Health check endpoint
│   │   └── home.rb            # Homepage endpoint
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
rake setup

# Start development server
rake server

# Start production server
rake prod
```

### Docker Deployment

```bash
# Using Docker Compose (recommended)
rake docker

# With custom environment file
cp .env.example .env
# Edit .env with your settings
rake docker

# Or build manually
rake docker:build
docker run -p 8080:8080 vlc-streaming-server
```

### Docker Compose Environment Variables

The `docker-compose.yml` works out of the box without any environment variables. To add configuration:

**Option 1: Use .env file (recommended for many variables)**
```bash
cp .env.example .env
# Edit .env with your actual values
docker-compose up
```

**Option 2: Use docker-compose.override.yml (recommended for custom setups)**
```bash
cp docker-compose.override.yml.example docker-compose.override.yml
# Edit the override file with your configuration
docker-compose up  # Automatically loads override file
```

**Option 3: Set host environment variables**
```bash
export YOUTUBE_API_KEY="your_key"
export PLAYLIST_FAVORITES="PL123..."
docker-compose up  # Inherits from host environment
```

**Option 4: Inline environment variables**
```bash
YOUTUBE_API_KEY="your_key" PLAYLIST_FAVORITES="PL123..." docker-compose up
```

**Configuration approaches:**

```yaml
# .env file approach (in docker-compose.override.yml)
env_file:
  - .env

# Direct environment variables
environment:
  - YOUTUBE_API_KEY=your_key_here
  - PLAYLIST_FAVORITES=PL123...

# Inherit from host environment
environment:
  - YOUTUBE_API_KEY
  - PLAYLIST_FAVORITES
```

For named playlists, set any `PLAYLIST_*` variable using any of the above methods:
```bash
PLAYLIST_FAVORITES=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L
PLAYLIST_ROCK=PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg
PLAYLIST_STUDY_MUSIC=PL123456789
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

#### YouTube Integration

- `YOUTUBE_API_KEY` - YouTube Data API v3 key for playlist functionality (required for `/playlist` endpoint)
  - Get your API key from [Google Cloud Console](https://console.cloud.google.com/)
  - Enable the YouTube Data API v3 for your project
- `PLAYLIST_*` - Named playlist environment variables (optional)
  - Use any name after `PLAYLIST_` - it becomes the endpoint path
  - Examples: `PLAYLIST_FAVORITES` → `/playlist/favorites`, `PLAYLIST_ROCK` → `/playlist/rock`
  - Can be playlist IDs (e.g., `PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L`) or full YouTube URLs

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

**Note:** All documented environment variables are properly passed through to the Docker container via `docker-compose.yml`. You can either:

- Set environment variables in your shell before running `docker-compose up`
- Create a `.env` file in the project root (recommended for persistent configuration)
- Override specific variables: `YOUTUBE_API_KEY=your_key docker-compose up`

### Examples

```bash
# Run on port 3000
PORT=3000 rake server:dev

# Allow additional hosts
ALLOWED_HOSTS="localhost,127.0.0.1,myserver.com" rake server:dev

# Increase concurrent connections for high load
PUMA_THREADS=20 rake server:puma

# With YouTube API key for playlist support
YOUTUBE_API_KEY="your_api_key_here" rake server:dev

# Docker with custom configuration
PORT=3000 ALLOWED_HOSTS="localhost,127.0.0.1,docker.local" rake docker:up

# High-performance Docker deployment with YouTube support
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e PUMA_THREADS=15 \
  -e ALLOWED_HOSTS="myserver.com,www.myserver.com" \
  -e YOUTUBE_API_KEY="your_api_key_here" \
  vlc-streaming-server

# Test custom port with Docker
docker run --rm -p 9000:9000 -e PORT=9000 vlc-streaming-server
```

## Getting YouTube API Key

To use the playlist functionality, you need a YouTube Data API v3 key:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the YouTube Data API v3:
   - Navigate to "APIs & Services" > "Library"
   - Search for "YouTube Data API v3"
   - Click on it and press "Enable"
4. Create credentials:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy the generated API key
5. Set the environment variable:

   ```bash
   export YOUTUBE_API_KEY="your_api_key_here"
   ```

**Note:** For production use, consider restricting your API key to specific IPs or referrers for security.

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

### YouTube Playlist to M3U

**Endpoint:** `GET /playlist?playlist=<PLAYLIST_ID_OR_URL>`

**Parameters:**

- `playlist` (required): YouTube playlist ID (e.g., `PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L`) or complete YouTube URL
- `url` (alternative): Complete YouTube URL containing playlist parameter

**Requirements:**

- `YOUTUBE_API_KEY` environment variable must be set with a valid YouTube Data API v3 key

**Example:**

```bash
# With playlist ID
curl "http://localhost:8080/playlist?playlist=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L" --output playlist.m3u

# With YouTube URL
curl "http://localhost:8080/playlist?url=https://www.youtube.com/watch?v=jfKfPfyJRdk&list=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L" --output playlist.m3u

# Play M3U playlist directly with VLC
vlc "http://localhost:8080/playlist?playlist=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L"

# Save and play locally
curl "http://localhost:8080/playlist?playlist=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L" -o playlist.m3u && vlc playlist.m3u
```

**Response:** Returns an M3U playlist file where each entry streams through the `/stream` endpoint. The playlist automatically handles:

- Pagination for large playlists
- Filtering out deleted/private videos
- Proper URL encoding for streaming

### Named Playlists

**Endpoints:** `GET /playlist/{name}` where `{name}` is any custom name you define

**Configuration:** Set environment variables `PLAYLIST_{NAME}` with playlist IDs or URLs

**Examples:**

```bash
# Set named playlists
export PLAYLIST_FAVORITES="PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L"
export PLAYLIST_ROCK="https://www.youtube.com/watch?v=test&list=PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg"
export PLAYLIST_STUDY_MUSIC="PLrCZV99gFgI_another_playlist_id"

# Access named playlists
curl "http://localhost:8080/playlist/favorites" -o favorites.m3u
curl "http://localhost:8080/playlist/rock" -o rock.m3u
curl "http://localhost:8080/playlist/study_music" -o study.m3u
vlc "http://localhost:8080/playlist/favorites"

# List all available playlists
curl "http://localhost:8080/playlists"

# Docker with named playlists (using .env file - recommended)
cp .env.example .env
# Edit .env with your configuration
docker-compose up

# Or pass variables directly
docker run -p 8080:8080 \
  -e YOUTUBE_API_KEY="your_api_key" \
  -e PLAYLIST_FAVORITES="PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L" \
  -e PLAYLIST_ROCK="PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg" \
  vlc-streaming-server
```

**Benefits:**

- Descriptive, memorable playlist names
- No limit on number of playlists
- No need to remember or look up playlist IDs
- Easier integration with media players and automation
- Clean, predictable URLs for bookmarking

### Health Check

**Endpoint:** `GET /health`

Returns JSON with server status and active stream count.

### Home Page

**Endpoint:** `GET /`

Returns an HTML page with usage instructions for all endpoints.

## How It Works

1. Client makes a request to `/stream` with a `video_url` parameter
2. Server spawns a VLC process to transcode the video to MPEG-TS format
3. Video data is streamed directly from VLC to the HTTP response
4. When the client disconnects, the VLC process is automatically terminated
5. Multiple clients can stream different videos simultaneously

## Available Rake Tasks

- `rake server` - Start development server
- `rake prod` - Start production server
- `rake spec` - Run tests
- `rake docker` - Start with Docker Compose
- `rake setup` - Install dependencies

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

## CI/CD & Docker Registry

This project includes GitHub Actions workflows for automated testing and Docker image publishing.

### Docker Image Registry

Pre-built Docker images are automatically published to GitHub Container Registry:

```bash
# Pull the latest image
docker pull ghcr.io/benklop/vlc-proxy:latest

# Run from registry
docker run -p 8080:8080 ghcr.io/benklop/vlc-proxy:latest

# Use in docker-compose.yml
services:
  vlc-server:
    image: ghcr.io/benklop/vlc-proxy:latest
    ports:
      - "8080:8080"
```

### Available Image Tags

- `latest` - Latest stable release from master branch
- `v1.0.0` - Specific version releases (semantic versioning)
- `master` - Latest commit from master branch
- `pr-123` - Pull request builds (for testing)

### GitHub Workflows

**CI Tests** (`.github/workflows/ci.yml`):

- Runs on all pushes and pull requests
- Tests with Ruby version specified in `.tool-versions`
- Uses mocked VLC dependencies (no actual VLC installation required)
- Uploads coverage reports

**Docker Build & Publish** (`.github/workflows/docker-build-publish.yml`):

- Builds multi-architecture images (amd64, arm64)
- Pushes to GitHub Container Registry on master branch
- Creates version tags for releases
- Includes security attestations and build provenance

### Contributing

When contributing:

1. All tests must pass on the Ruby version specified in `.tool-versions`
2. Docker builds must succeed
3. Coverage should remain above 95%
4. Follow existing code style and patterns

## Dependencies

- VLC Media Player (cvlc command)
- Ruby (version specified in `.tool-versions`)
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
