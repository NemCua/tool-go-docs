#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
cd "$SCRIPT_DIR"

if [[ ! -x human-typer || HumanTyper.swift -nt human-typer ]]; then
  ./build.sh
fi

exec ./human-typer "$@"
