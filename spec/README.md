# Test Structure

The test structure now mirrors the `lib/` directory structure for easy navigation and maintenance.

## Structure Mapping

```text
lib/                          →  spec/
├── playlist_generator.rb     →  ├── playlist_generator_spec.rb
├── youtube_client.rb         →  ├── youtube_client_spec.rb
├── vlc_process_manager.rb    →  ├── vlc_process_manager_spec.rb
├── vlc_streamer.rb          →  ├── vlc_streamer_spec.rb
├── vlc_streaming_app.rb     →  ├── vlc_streaming_app_configuration_spec.rb
├── routes/                   →  ├── routes/
│   ├── health.rb            →  │   ├── health_spec.rb
│   ├── home.rb              →  │   ├── home_spec.rb
│   ├── streaming.rb         →  │   ├── streaming_spec.rb
│   └── youtube/             →  │   └── youtube/
│       ├── channel.rb       →  │       ├── channel_spec.rb
│       └── playlist.rb      →  │       └── playlist_spec.rb
└── spec_helper.rb           →  └── spec_helper.rb
```

## Benefits

1. **Easy Navigation**: Find tests for any lib file by following the same path in spec/
2. **Clear Organization**: Route tests are grouped under `spec/routes/`
3. **Maintainability**: When you modify a file in lib/, you know exactly where its tests are
4. **Scalability**: Adding new routes or modules automatically suggests where tests should go

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/playlist_generator_spec.rb

# Run all route tests
bundle exec rspec spec/routes/

# Run specific route tests
bundle exec rspec spec/routes/youtube/playlist_spec.rb
```

## Coverage

Current test coverage: **86.4% line coverage**, **76.19% branch coverage** with **95 examples, 0 failures**.
