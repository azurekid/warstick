#!/bin/bash
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export USB_ROOT="$ROOT_DIR"
source "$ROOT_DIR/command-core/lib/ui_common.sh"
source "$ROOT_DIR/command-core/lib/setup_common.sh"
initialize_warstick_setup
