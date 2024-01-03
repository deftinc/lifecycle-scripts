# Lifecycle scripts

# Architecture

1. Script steps should be bash functions
2. Script steps should describe what it did in the paste tense — "Installed npm dependencies."
3. Any step failing should stop the execution of any further steps being run

Scripts should start with the following header:

```bash
#!/usr/bin/env bash
# set -x # shows all run commands
set -eu # e exits on error; u exits if unassigned variable is used
cd "$(dirname "$0")/.."
source bin/functions.sh
```

# Workflow scripts

These are scripts that used in day-to-day work to make it easier and

## Bootstrap

This should install any environment dependencies — homebrew itself, homebrew packages, asdf itself, asdf plugins. Then it should run update.

## Down

This should stop the server and related services.

## Logs

This should tail the logs for the server.

## Repl

This should start a REPL in the context of the project.

## CI

This should run the test suite locally.

## Up

This should start the server and related services and tail the logs

## Update

Automatically run before up, repl, or ci. Automatically run after bootstrap. This installs the specified languages, updates to the latest version of the package manager, installs library dependencies, and migrates datastores.

# Deployment scripts

## Package

This should use buildpacks to create a container image tagged with the branch name and git sha. Used before deploy or shell.

## Deploy

This should deploy to the container to production.

## Shell

This should open a shell in the container.
