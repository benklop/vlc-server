# Scaling Guide for VLC Streaming Server

## Current Configuration

### Single Container Capacity
- **Mode**: Single-mode Puma (1 process, multiple threads)
- **Default threads**: 10 concurrent connections
- **Suitable for**: Small to medium loads (1-10 concurrent streams)

## Scaling Strategies

### 1. Increase Thread Count (Quick Fix)

```bash
# Handle more concurrent clients in single container
docker run -e PUMA_THREADS=20 vlc-streaming-server
```

**Pros**: Simple, immediate
**Cons**: More memory usage, diminishing returns beyond ~20 threads

### 2. Container Scaling (Recommended)

```yaml
# docker-compose.yml
version: "3.8"
services:
  vlc-server:
    build: .
    deploy:
      replicas: 3  # Run 3 containers
    environment:
      - PUMA_THREADS=10
      
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

**Pros**: Better resource utilization, fault tolerance
**Cons**: Requires load balancer configuration

### 3. Kubernetes Auto-scaling

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vlc-streaming-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vlc-streaming-server
  template:
    spec:
      containers:
      - name: vlc-streaming-server
        image: vlc-streaming-server
        env:
        - name: PUMA_THREADS
          value: "15"
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vlc-streaming-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vlc-streaming-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Performance Expectations

### Single Container (10 threads)
- **Light streaming**: 10-15 concurrent clients
- **Heavy streaming**: 5-8 concurrent clients
- **Mixed load**: 8-12 concurrent clients

### Multiple Containers (3 × 10 threads)
- **Light streaming**: 30-45 concurrent clients
- **Heavy streaming**: 15-24 concurrent clients
- **Mixed load**: 24-36 concurrent clients

## Monitoring

```bash
# Check container resource usage
docker stats

# Monitor active connections
curl http://localhost:8080/health
```

## Load Balancer Configuration

For multiple containers, you'll need a load balancer. Example nginx config:

```nginx
upstream vlc_servers {
    server vlc-server-1:8080;
    server vlc-server-2:8080;
    server vlc-server-3:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://vlc_servers;
        proxy_set_header Host $host;
    }
}
```

## When to Scale

- **Scale threads** when CPU usage is low but connections are queuing
- **Scale containers** when CPU/memory usage is high (>70%)
- **Add load balancer** when running multiple containers
