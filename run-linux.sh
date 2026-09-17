#!/bin/bash
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export USB_ROOT="$ROOT_DIR"
source "$ROOT_DIR/command-core/lib/ui_common.sh"
play_install_tank_animation
exec bash "$ROOT_DIR/command-core/runtime/linux.sh" "$ROOT_DIR"
