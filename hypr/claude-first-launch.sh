#!/bin/bash

# Toggle to the special workspace named "magic"
hyprctl dispatch togglespecialworkspace magic

# Launch Claude in the background so the script can continue
claude-desktop &

# Store the PID of claude-desktop
CLAUDE_PID=$!

# Wait for Claude window to appear
# This checks if any window with Claude class exists
while ! hyprctl clients | grep -q "class: Claude"; do
  # Check if the process is still running
  if ! kill -0 $CLAUDE_PID 2>/dev/null; then
    echo "Claude process terminated unexpectedly"
    exit 1
  fi
  sleep 0.1
done

# Give it a moment to apply window rules
sleep 0.5

# Toggle back to regular workspace
hyprctl dispatch togglespecialworkspace magic