# Elasticsearch & Kibana Local Stack with PowerScale Log Forwarding

A project running Elasticsearch and Kibana locally in Podman containers, with continuous log forwarding from a remote PowerScale cluster.

## Prerequisites

- Python 3 and pip installed
- Podman installed and running (for local containers)
- Git Bash (recommended for Windows users)
- SSH access to PowerScale cluster at 10.241.80.184:50019 (user: root) - for log forwarding only

### Installing Podman on Windows

1. Download Podman for Windows from: https://podman.io/docs/installation
2. Install Podman Desktop or use WSL2 backend
3. Initialize Podman: `podman machine init`
4. Start Podman machine: `podman machine start`
5. Verify installation: `podman version`

### Using Git Bash

Git Bash provides a Unix-like shell on Windows and is recommended for this project because:
- Native SSH client support
- Unix-style path handling with forward slashes
- Compatible with Podman commands
- Better for scripting and automation

## Local Stack Setup

### 1. Create Podman Network

```bash
podman network create es-network
```

### 2. Start Elasticsearch Container

```bash
podman run -d \
  --name elasticsearch \
  --network=es-network \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.11.0
```

Wait 30-60 seconds for Elasticsearch to start.

### 3. Start Kibana Container

```bash
bash scripts/start-kibana.sh
```

Or manually:

```bash
podman run -d \
  --name kibana \
  --network=es-network \
  -p 5601:5601 \
  -v "$(cygpath -w "$(pwd)/kibana/config/kibana.yml")":/usr/share/kibana/config/kibana.yml:ro \
  docker.elastic.co/kibana/kibana:8.11.0
```

### 4. Access Kibana

Open your browser and navigate to: http://localhost:5601

## Project Structure

```
.
├── kibana/
│   └── config/
│       └── kibana.yml             # Kibana configuration (connects to local ES)
├── requirements.txt                # Python dependencies
└── scripts/
    ├── setup.sh                   # Setup script to check prerequisites
    ├── test.sh                    # Test script to verify local setup
    ├── cleanup.sh                 # Cleanup script to remove containers and data
    ├── start-kibana.sh            # Script to start Kibana container
    ├── ingest_data.py             # Sample data ingestion script
    └── forward_powerscale_logs.py # Continuous log forwarding from PowerScale cluster
```

## Automated Scripts (Git Bash)

The project includes automated scripts to simplify setup, testing, and cleanup.

**Note:** In Git Bash, you can run scripts directly with `bash scripts/scriptname.sh` or make them executable with `chmod +x scripts/*.sh`

### Quick Start

For a complete automated setup and test:

```bash
# 1. Run setup script
bash scripts/setup.sh

# 2. Create Podman network
podman network create es-network

# 3. Start Elasticsearch
podman run -d --name elasticsearch --network=es-network -p 9200:9200 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:8.11.0

# 4. Start Kibana
bash scripts/start-kibana.sh

# 5. Run test script (verifies everything works)
bash scripts/test.sh
```

### Setup Script

The `setup.sh` script checks prerequisites and installs dependencies:

```bash
bash scripts/setup.sh
```

**What it does:**
- Checks Python and pip installation
- Checks Podman installation and machine status
- Installs Python dependencies from requirements.txt
- Reports any missing prerequisites

### Test Script

The `test.sh` script verifies that the local setup is working:

```bash
bash scripts/test.sh
```

**What it tests:**
- Elasticsearch container status
- Elasticsearch cluster health
- Kibana container status
- Kibana accessibility
- Python dependencies
- Data ingestion functionality
- Data verification in Elasticsearch
- Search functionality

**Output:** Shows which tests passed/failed with a summary

### Start Kibana Script

The `start-kibana.sh` script starts the Kibana container:

```bash
bash scripts/start-kibana.sh
```

**What it does:**
- Checks if Kibana is already running
- Starts existing container if stopped
- Creates new container if needed (on es-network)
- Waits for Kibana to be ready
- Provides access URL and management commands

### Cleanup Script

The `cleanup.sh` script removes containers and data:

```bash
bash scripts/cleanup.sh
```

**What it does:**
- Stops and removes Elasticsearch and Kibana containers
- Deletes the powerscale-logs index from Elasticsearch
- Optionally removes stopped containers and dangling images
- Cleans up Python cache files
- Requires confirmation before proceeding

**Warning:** This will delete all data from the powerscale-logs index.

## Data Ingestion (Git Bash)

Use the provided Python script to ingest sample data into the local Elasticsearch:

```bash
pip install -r requirements.txt
python scripts/ingest_data.py
```

The script is configured to connect to `http://elasticsearch:9200` (local container).

## PowerScale Log Forwarding

Stream logs from a remote PowerScale cluster to your local Elasticsearch:

```bash
pip install -r requirements.txt
python scripts/forward_powerscale_logs.py
```

**What it does:**
- SSHs into PowerScale cluster (10.241.80.184:50019)
- Tails `/var/log/messages` continuously
- Parses each log entry (timestamp, hostname, process, message)
- Sends to local Elasticsearch (`powerscale-logs` index)
- Flushes in batches of 100 logs or every 5 seconds

**Requirements:**
- SSH key authentication configured for PowerScale cluster
- Local Elasticsearch running

**Press Ctrl+C to stop** - it will flush remaining logs before exiting.

**Note:** The script assumes SSH key authentication. If you use password auth, set up keys first:
```bash
ssh-copy-id -p 50019 root@10.241.80.184
```

## Managing Containers

```bash
# List all containers
podman ps

# Stop Kibana container
podman stop kibana

# Start Kibana container
podman start kibana

# Stop Elasticsearch container
podman stop elasticsearch

# Start Elasticsearch container
podman start elasticsearch

# Remove container
podman rm -f kibana
podman rm -f elasticsearch

# View container logs
podman logs kibana
podman logs elasticsearch
```

## Troubleshooting

### Cannot connect to Elasticsearch

1. Ensure Elasticsearch container is running:
```bash
podman ps | grep elasticsearch
```

2. If not running, start it:
```bash
podman start elasticsearch
# Or recreate if missing:
podman run -d --name elasticsearch --network=es-network -p 9200:9200 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:8.11.0
```

3. Verify Elasticsearch is healthy:
```bash
curl http://localhost:9200/_cluster/health
```

### Kibana cannot connect to Elasticsearch

1. Ensure both containers are on the same network:
```bash
podman network inspect es-network
```

2. Check kibana.yml configuration:
```bash
cat kibana/config/kibana.yml
```
Should show: `elasticsearch.hosts: ["http://elasticsearch:9200"]`

3. Restart Kibana after config changes:
```bash
podman restart kibana
```

### Podman issues

**Podman machine not running:**
```bash
podman machine start
```

**Podman volume mount issues on Windows:**
The `start-kibana.sh` script uses `cygpath` to convert Unix paths to Windows paths for Podman volume mounts. This is the best practice for Git Bash on Windows.

If you encounter path errors:
1. Ensure cygpath is available (included with Git Bash)
2. The script will show the resolved path for debugging
3. If cygpath fails, the script uses a manual conversion fallback

**Manual Podman command (if script fails):**
```bash
cd /c/Users/chana13/Documents/New\ folder\ \(3\)
podman run -d \
  --name kibana \
  --network=es-network \
  -p 5601:5601 \
  -v "$(cygpath -w "$(pwd)/kibana/config/kibana.yml")":/usr/share/kibana/config/kibana.yml:ro \
  docker.elastic.co/kibana/kibana:8.11.0
```

**Alternative without config file (use environment variables):**
```bash
podman run -d \
  --name kibana \
  --network=es-network \
  -p 5601:5601 \
  -e ELASTICSEARCH_HOSTS=http://elasticsearch:9200 \
  docker.elastic.co/kibana/kibana:8.11.0
```

**Check Podman status:**
```bash
podman machine list
podman ps
```

## Security Notes

- This setup runs Elasticsearch and Kibana locally in development mode with security disabled
- For production, enable X-Pack Security on Elasticsearch and Kibana
- Configure authentication and encryption for container networks
- When using PowerScale log forwarding, ensure SSH keys are properly secured
- Use TLS/SSL for encrypted communications between components in production

## License

This project uses Elasticsearch and Kibana under the Elastic License.
# powerscale-ELK
