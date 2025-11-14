#!/bin/bash
# Quick temperature check script for dev server

echo "=== System Temperatures ==="
echo ""
sensors | grep -E "(°C|RPM|W)" | grep -v "^$"
echo ""
echo "Current time: $(date)"
