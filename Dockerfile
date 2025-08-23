# Build stage
FROM ruby:3.4.3-alpine AS builder

ARG UID="1000"
ARG GID="1000"

# Install build dependencies
RUN apk update && \
    apk add --no-cache \
    build-base \
    vlc-dev \
    wget \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy Gemfile and .tool-versions for bundle install
COPY Gemfile* .tool-versions ./

# Install gems
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Copy application code
COPY . .

# Production stage
FROM ruby:3.4.3-alpine AS production

ARG UID="1000"
ARG GID="1000"

# Install only runtime dependencies
RUN apk update && \
    apk add --no-cache \
    vlc \
    && rm -rf /var/cache/apk/*

# Create user and app directory
RUN addgroup --g "${GID}" -S appuser && \
    adduser -h /app -s /bin/sh -u "${UID}" -G appuser -S appuser && \
    mkdir -p /app && \
    chown appuser:appuser -R /app

# Set working directory
WORKDIR /app

# Copy the installed gems from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code from builder stage
COPY --from=builder --chown=appuser:appuser /app /app

# Copy and setup healthcheck script
COPY --chown=appuser:appuser docker/healthcheck.sh /usr/local/bin/healthcheck
RUN chmod +x /usr/local/bin/healthcheck

# Switch to non-root user
USER appuser

# Set container environment variable
ENV CONTAINER=docker

# Expose port
EXPOSE 8080

# Start the application
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
