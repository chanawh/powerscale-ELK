#!/usr/bin/env python3
"""
Sample data ingestion script for Elasticsearch.
This script generates and indexes sample log data.

Note: Ensure SSH tunnel is active in Git Bash before running:
ssh -p 50019 -L 0.0.0.0:9200:localhost:9200 root@10.241.80.184
"""

import random
import time
from datetime import datetime, timedelta
from elasticsearch import Elasticsearch
import json

# Elasticsearch connection
ES_HOST = "http://localhost:9200"
INDEX_NAME = "powerscale-logs"

# Sample log messages
LOG_MESSAGES = [
    "File system operation completed successfully",
    "NFS mount point accessed",
    "Snapshot created on PowerScale cluster",
    "Data replication in progress",
    "Storage pool rebalancing started",
    "SmartQuota threshold warning",
    "Connection established to PowerScale node",
    "Backup job completed",
    "Data integrity check passed",
    "Network latency detected on cluster"
]

LOG_LEVELS = ["INFO", "WARNING", "ERROR", "DEBUG"]
NODES = ["node-1", "node-2", "node-3"]


def generate_log_entry():
    """Generate a random log entry."""
    timestamp = datetime.now() - timedelta(
        seconds=random.randint(0, 86400)
    )
    
    return {
        "@timestamp": timestamp.isoformat(),
        "level": random.choice(LOG_LEVELS),
        "message": random.choice(LOG_MESSAGES),
        "node": random.choice(NODES),
        "cluster": "powerscale-cluster",
        "file_size_mb": random.randint(1, 1000),
        "operation_time_ms": random.randint(10, 5000)
    }


def create_index(es):
    """Create the index with mapping if it doesn't exist."""
    if not es.indices.exists(index=INDEX_NAME):
        mapping = {
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "level": {"type": "keyword"},
                    "message": {"type": "text"},
                    "node": {"type": "keyword"},
                    "cluster": {"type": "keyword"},
                    "file_size_mb": {"type": "long"},
                    "operation_time_ms": {"type": "long"}
                }
            }
        }
        es.indices.create(index=INDEX_NAME, body=mapping)
        print(f"Index '{INDEX_NAME}' created with mapping.")
    else:
        print(f"Index '{INDEX_NAME}' already exists.")


def ingest_data(es, count=100):
    """Ingest sample data into Elasticsearch."""
    print(f"Ingesting {count} log entries...")
    
    for i in range(count):
        log_entry = generate_log_entry()
        es.index(index=INDEX_NAME, document=log_entry)
        
        if (i + 1) % 10 == 0:
            print(f"Ingested {i + 1}/{count} entries")
            time.sleep(0.1)  # Small delay to avoid overwhelming
    
    print(f"Successfully ingested {count} log entries.")


def verify_data(es):
    """Verify the data was ingested correctly."""
    count = es.count(index=INDEX_NAME)
    print(f"\nTotal documents in '{INDEX_NAME}': {count['count']}")
    
    # Get a sample document
    search_result = es.search(index=INDEX_NAME, size=1)
    if search_result['hits']['hits']:
        print("\nSample document:")
        print(json.dumps(search_result['hits']['hits'][0]['_source'], indent=2))


def main():
    """Main function."""
    print("Connecting to Elasticsearch...")
    es = Elasticsearch(ES_HOST)
    
    # Check connection
    if not es.ping():
        print("Error: Could not connect to Elasticsearch.")
        print("Make sure SSH tunnel is active in Git Bash:")
        print("ssh -p 50019 -L 0.0.0.0:9200:localhost:9200 root@10.241.80.184")
        return
    
    print("Connected successfully.")
    
    # Create index
    create_index(es)
    
    # Ingest data
    ingest_data(es, count=100)
    
    # Refresh index to make data searchable
    es.indices.refresh(index=INDEX_NAME)
    
    # Verify
    verify_data(es)
    
    print("\nData ingestion complete!")
    print("View data in Kibana at http://localhost:5601")


if __name__ == "__main__":
    main()
