#!/usr/bin/env bash

set -euo pipefail

describe() {
  echo "--- $1…"
}

asdf_add_to_shell() {
  if [ -f .tool-versions ]; then
    describe "Install asdf tool versions"
    . $HOME/.asdf/asdf.sh
  fi
}

bash_source_profile() {
  describe "Sourcing .profile to shell"
  source $HOME/.profile
}

start_docker_services() {
  if [ -f docker-compose.yml ]; then
    describe ":docker: Starting docker-compose services"
    docker-compose up -d -V --remove-orphans
  fi
}

case $BUILDKITE_STEP_KEY in
  test)
    asdf_add_to_shell
    start_docker_services
    ;;
  deploy)
    bash_source_profile
    ;;
  *)
    describe "Skipping pre-command hook"
    ;;
esac