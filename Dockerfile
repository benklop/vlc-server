FROM ruby:3.2.2-alpine

ARG UID="1000"
ARG GID="1000"

# Install system dependencies
RUN apk update && \
    apk add --no-cache \
    build-base \
    vlc \
    vlc-dev \
    && rm -rf /var/cache/apk/*

# Create user and app directory
RUN addgroup --g "${GID}" -S appuser && \
    adduser -h /app -s /bin/sh -u "${UID}" -G appuser -S appuser && \
    mkdir -p /app && \
    chown appuser:appuser -R /app

# Set working directory
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile* ./
RUN bundle install --without development

# Copy application code
COPY . .

# Ensure proper ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Start the application
CMD ["bundle", "exec", "puma", "-C", "docker/puma.rb"]
