#!/bin/bash
# Legacy entry point, kept for backward compatibility. Prefer `make bundle`.
set -e
exec make bundle
