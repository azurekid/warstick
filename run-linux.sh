#!/bin/bash
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec bash "$ROOT_DIR/command-core/runtime/linux.sh" "$ROOT_DIR"
