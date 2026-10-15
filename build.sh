#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
swiftc -O "$SCRIPT_DIR/HumanTyper.swift" -o "$SCRIPT_DIR/human-typer"
print "Đã tạo: $SCRIPT_DIR/human-typer"
