#!/bin/bash
# ==============================================================================
# Helper Script to monitor PM2 process list continuously with 0.5s intervals
# ==============================================================================
export TERM="${TERM:-xterm-256color}"
exec watch -n 0.5 -d pm2 ls
