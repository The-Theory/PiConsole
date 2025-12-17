#!/bin/bash
clear

# Ensure Mesa shader cache is writable
CACHE_ROOT=${XDG_CACHE_HOME:-/tmp/${USER}-cache}
export XDG_CACHE_HOME="$CACHE_ROOT"
export MESA_SHADER_CACHE_DIR="$CACHE_ROOT/mesa_shader_cache"
mkdir -p "$MESA_SHADER_CACHE_DIR" 2>/dev/null || true

# Disable audio
export SDL_AUDIODRIVER=dummy
export ALSA_CARD=null
export ALSA_DEVICE=null

# Launch Python script
python3 /home/th/dev/TiPiL/GPIOinput.py &
echo "Recording inputs..."
PYTHON_PID=$!

# Launch LOVE2D
sleep 0.2
echo "--------------------------------"
echo "           RUNNING"
echo "--------------------------------"
love /home/th/dev


# When the game exits, kill the Python script
echo "Stopping GPIO listener..."
kill $PYTHON_PID

# Back to terminal
echo "Exited game at $(date)."
