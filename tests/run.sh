#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

sh tests/test-udhcpc-routing.sh
sh tests/test-daemon-safety.sh
sh tests/test-cli-validation.sh
