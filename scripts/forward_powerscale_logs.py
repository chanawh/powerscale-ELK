#!/usr/bin/env python3
"""
Continuous log forwarder from PowerScale cluster to local Elasticsearch.

This script connects to the PowerScale cluster via SSH, tails /var/log/messages,
and forwards each log entry to the local Elasticsearch instance.

Usage:
    python scripts/forward_powerscale_logs.py

Requirements:
    - SSH access to PowerScale cluster
    - Local Elasticsearch running (localhost:9200)
    - paramiko package: pip install paramiko
"""

import json
import re
import sys
import time
from datetime import datetime
from elasticsearch import Elasticsearch
import paramiko

# Configuration
ES_HOST = "http://localhost:9200"
ES_INDEX = "powerscale-logs"
POWERSCALE_HOST = "10.241.80.184"
POWERSCALE_PORT = 50019
POWERSCALE_USER = "root"
LOG_FILE = "/var/log/messages"
BATCH_SIZE = 100
FLUSH_INTERVAL = 5  # seconds

# SSH key or password (use key-based auth in production)
# For now, assumes SSH key is configured or passwordless sudo


def create_ssh_client():
    """Create SSH client to PowerScale cluster."""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    # Try key-based auth first, fall back to interactive if needed
    try:
        client.connect(
            hostname=POWERSCALE_HOST,
            port=POWERSCALE_PORT,
            username=POWERSCALE_USER,
            look_for_keys=True,
            allow_agent=True,
            timeout=30
        )
    except paramiko.AuthenticationException:
        print("SSH key authentication failed. Please ensure your SSH key is configured.")
        print("You may need to manually SSH first to add the host to known_hosts.")
        sys.exit(1)
    
    return client


def parse_syslog_message(line):
    """Parse syslog format message."""
    # Typical format: Apr  9 12:34:56 hostname process[pid]: message
    pattern = r'^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(.*)$'
    match = re.match(pattern, line)
    
    if match:
        timestamp_str, hostname, message = match.groups()
        # Add current year since syslog doesn't include it
        current_year = datetime.now().year
        try:
            timestamp = datetime.strptime(
                f"{current_year} {timestamp_str}", 
                "%Y %b %d %H:%M:%S"
            )
        except ValueError:
            timestamp = datetime.now()
        
        # Extract process name if present
        process_match = re.match(r'^(\S+)\[(\d+)\]:', message)
        if process_match:
            process_name = process_match.group(1)
            process_pid = int(process_match.group(2))
            message_content = message[process_match.end():].strip()
        else:
            colon_pos = message.find(": ")
            if colon_pos > 0:
                process_name = message[:colon_pos]
                message_content = message[colon_pos + 2:]
            else:
                process_name = "unknown"
                message_content = message
        
        return {
            "@timestamp": timestamp.isoformat(),
            "hostname": hostname,
            "process_name": process_name,
            "message": message_content,
            "raw_message": line.strip(),
            "source_file": LOG_FILE,
            "source_host": POWERSCALE_HOST
        }
    
    # If parsing fails, return raw message
    return {
        "@timestamp": datetime.now().isoformat(),
        "hostname": POWERSCALE_HOST,
        "process_name": "unknown",
        "message": line.strip(),
        "raw_message": line.strip(),
        "source_file": LOG_FILE,
        "source_host": POWERSCALE_HOST,
        "parse_error": True
    }


def ensure_index_exists(es):
    """Create Elasticsearch index if it doesn't exist."""
    if not es.indices.exists(index=ES_INDEX):
        es.indices.create(
            index=ES_INDEX,
            body={
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0
                },
                "mappings": {
                    "properties": {
                        "@timestamp": {"type": "date"},
                        "hostname": {"type": "keyword"},
                        "process_name": {"type": "keyword"},
                        "message": {"type": "text"},
                        "raw_message": {"type": "text"},
                        "source_file": {"type": "keyword"},
                        "source_host": {"type": "keyword"}
                    }
                }
            }
        )
        print(f"Created index: {ES_INDEX}")


def bulk_index_logs(es, log_buffer):
    """Bulk index logs to Elasticsearch."""
    if not log_buffer:
        return
    
    actions = []
    for log_entry in log_buffer:
        actions.append({"index": {"_index": ES_INDEX}})
        actions.append(log_entry)
    
    try:
        es.bulk(body=actions)
        print(f"Indexed {len(log_buffer)} logs")
    except Exception as e:
        print(f"Error indexing logs: {e}")


def tail_log_stream(ssh_client, es):
    """Tail log file and stream to Elasticsearch."""
    print(f"Starting log stream from {POWERSCALE_HOST}:{LOG_FILE}")
    print(f"Forwarding to Elasticsearch at {ES_HOST}")
    print("Press Ctrl+C to stop...")
    
    # Start tailing the log file
    stdin, stdout, stderr = ssh_client.exec_command(f"tail -f {LOG_FILE}")
    
    log_buffer = []
    last_flush = time.time()
    
    try:
        for line in iter(stdout.readline, ''):
            if not line:
                continue
            
            # Parse and buffer the log entry
            log_entry = parse_syslog_message(line)
            log_buffer.append(log_entry)
            
            # Flush buffer periodically or when it reaches batch size
            current_time = time.time()
            if len(log_buffer) >= BATCH_SIZE or (current_time - last_flush) >= FLUSH_INTERVAL:
                bulk_index_logs(es, log_buffer)
                log_buffer = []
                last_flush = current_time
                
    except KeyboardInterrupt:
        print("\nStopping log forwarder...")
        # Flush remaining logs
        if log_buffer:
            bulk_index_logs(es, log_buffer)
        
        stdout.channel.close()
        ssh_client.close()
        print("Log forwarder stopped.")


def main():
    """Main entry point."""
    print("PowerScale Log Forwarder")
    print("=" * 50)
    
    # Check Elasticsearch connection
    print(f"Connecting to Elasticsearch at {ES_HOST}...")
    es = Elasticsearch([ES_HOST])
    
    if not es.ping():
        print("Error: Cannot connect to Elasticsearch")
        print("Make sure Elasticsearch is running: podman ps | grep elasticsearch")
        sys.exit(1)
    
    print("Connected to Elasticsearch")
    ensure_index_exists(es)
    
    # Connect to PowerScale via SSH
    print(f"Connecting to PowerScale cluster at {POWERSCALE_HOST}:{POWERSCALE_PORT}...")
    try:
        ssh_client = create_ssh_client()
        print("SSH connection established")
    except Exception as e:
        print(f"SSH connection failed: {e}")
        print("\nMake sure you can SSH manually:")
        print(f"ssh -p {POWERSCALE_PORT} {POWERSCALE_USER}@{POWERSCALE_HOST}")
        sys.exit(1)
    
    # Start streaming
    tail_log_stream(ssh_client, es)


if __name__ == "__main__":
    main()
