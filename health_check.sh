#!/bin/bash
set -e

# Wait for a response from the health check endpoint
curl --fail http://localhost:8000/health/ || exit 1 