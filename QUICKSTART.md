# Quick Start Guide

This guide provides step-by-step instructions to set up, test, and clean up the Elasticsearch & Kibana Local Stack with PowerScale Log Forwarding.

## Prerequisites

- Git Bash installed on Windows
- Podman installed and running
- Python 3 and pip installed
- SSH access to 10.241.80.184:50019 (user: root) - for log forwarding only

## Step-by-Step Setup

### 1. Run Setup Script

```bash
bash scripts/setup.sh
```

This will:
- Check Python, pip, and Podman installations
- Verify Podman machine status
- Install Python dependencies
- Report any missing prerequisites

### 2. Create Podman Network

```bash
podman network create es-network
```

### 3. Start Elasticsearch

```bash
podman run -d \
  --name elasticsearch \
  --network=es-network \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.11.0
```

Wait 30-60 seconds for Elasticsearch to start.

### 4. Start Kibana

```bash
bash scripts/start-kibana.sh
```

### 5. Run Test Script

```bash
bash scripts/test.sh
```

This will:
- Verify Elasticsearch container status
- Check Elasticsearch cluster health
- Verify Kibana container status
- Test data ingestion
- Verify data in Elasticsearch
- Test search functionality

### 6. Access Kibana

Open your browser and navigate to: http://localhost:5601

## Common Workflows

### Initial Setup

```bash
# 1. Setup
bash scripts/setup.sh

# 2. Create network
podman network create es-network

# 3. Start Elasticsearch
podman run -d --name elasticsearch --network=es-network -p 9200:9200 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:8.11.0

# 4. Start Kibana
bash scripts/start-kibana.sh

# 5. Test
bash scripts/test.sh
```

### Daily Usage

```bash
# 1. Start Elasticsearch (if not running)
podman start elasticsearch

# 2. Start Kibana (if not running)
bash scripts/start-kibana.sh

# 3. Ingest sample data
python scripts/ingest_data.py

# 4. Or forward logs from PowerScale
python scripts/forward_powerscale_logs.py
```

### Cleanup

```bash
# Remove containers and data
bash scripts/cleanup.sh
```

## Script Reference

| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Check prerequisites and install dependencies |
| `scripts/test.sh` | Verify local setup is working |
| `scripts/start-kibana.sh` | Start Kibana container |
| `scripts/cleanup.sh` | Remove containers and data |
| `scripts/ingest_data.py` | Generate sample log data |
| `scripts/forward_powerscale_logs.py` | Stream logs from PowerScale cluster |

## Troubleshooting

### Setup Script Fails

- Ensure Podman is running: `podman machine start`
- Check Python installation: `python --version`
- Verify pip is installed: `pip --version`

### Test Script Fails

- Ensure Elasticsearch is running: `podman ps | grep elasticsearch`
- Check Elasticsearch connectivity: `curl http://localhost:9200/_cluster/health`
- Verify Kibana is running: `podman ps`
- Ensure both containers are on es-network: `podman network inspect es-network`

### Kibana Won't Start

- Check if port 5601 is already in use
- Remove existing container: `podman rm -f kibana`
- Check Podman logs: `podman logs kibana`
- Ensure Elasticsearch is running first

### Git Bash Path Issues

The `start-kibana.sh` script uses `cygpath` for reliable path conversion in Git Bash.

**If you see "invalid container path" errors:**
1. The script will display the resolved path for debugging
2. Ensure you're running from the project root directory
3. Try the manual command with cygpath:
```bash
podman run -d \
  --name kibana \
  --network=es-network \
  -p 5601:5601 \
  -v "$(cygpath -w "$(pwd)/kibana/config/kibana.yml")":/usr/share/kibana/config/kibana.yml:ro \
  docker.elastic.co/kibana/kibana:8.11.0
```

**Alternative: Use environment variables (no config file needed):**
```bash
podman run -d \
  --name kibana \
  --network=es-network \
  -p 5601:5601 \
  -e ELASTICSEARCH_HOSTS=http://elasticsearch:9200 \
  docker.elastic.co/kibana/kibana:8.11.0
```

### Cleanup Issues

- Ensure you type "yes" when prompted
- Check if Elasticsearch is running: `curl http://localhost:9200/_cluster/health`
- Manually delete index: `curl -X DELETE http://localhost:9200/powerscale-logs`

## Manual Commands

### Podman Container Management

```bash
# List containers
podman ps

# Stop containers
podman stop kibana
podman stop elasticsearch

# Start containers
podman start kibana
podman start elasticsearch

# Remove containers
podman rm -f kibana
podman rm -f elasticsearch

# View logs
podman logs kibana
podman logs elasticsearch
```

### Elasticsearch Commands

```bash
# Check cluster health
curl http://localhost:9200/_cluster/health

# List indices
curl http://localhost:9200/_cat/indices?v

# Search data
curl http://localhost:9200/powerscale-logs/_search?pretty

# Delete index
curl -X DELETE http://localhost:9200/powerscale-logs
```

### Kibana Access

- URL: http://localhost:5601
- Create index pattern: `powerscale-logs*`
- View data in Discover tab
- Create visualizations in Visualize tab
- Build dashboards in Dashboard tab
