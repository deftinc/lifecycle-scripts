#!/usr/bin/env bash

set -euo pipefail

describe() {
  echo "--- $1…"
}

stop_docker_services() {
  if [ -f docker-compose.yml ]; then
    describe ":docker: Stopping docker-compose services"
    docker-compose down -v --remove-orphans --timeout 30
  fi
}

stop_docker_services