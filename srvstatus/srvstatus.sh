#!/usr/bin/env sh

SCRIPT_DIR=$(dirname $0)

exec $SCRIPT_DIR/venv/bin/python $SCRIPT_DIR/service.py "$@"
