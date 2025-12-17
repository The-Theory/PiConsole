#!/usr/bin/env python3
import RPi.GPIO as GPIO  # type: ignore
import spidev  # type: ignore
import time
import os

# Config
BUTTONS = {
    'a': 17,     
    'b': 4,    
    'x': 27,    
    'y': 22,    
    'menu': 23,
    "stick": 26
}

JOYSTICK = {'x': 0, 'y': 1}  # MCP3008 channels
READ_INTERVAL = 0.05  # 20 Hz polling rate
DEBOUNCE_TIME = 0.05  # 50ms debounce time for buttons
OUTPUT_FILE = "/tmp/input.txt"
OUTPUT_FILE_TMP = "/tmp/input.txt.tmp"

# Initialize GPIO
GPIO.setmode(GPIO.BCM)
for pin in BUTTONS.values():
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

# Initialize SPI
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 1350000

# Debouncing state for buttons
button_debounce = {name: {'state': 0, 'last_change': 0.0, 'stable_state': 0} 
                   for name in BUTTONS.keys()}

# Read MCP3008 ADC
def read_adc(channel):
    adc = spi.xfer2([1, (8 + channel) << 4, 0])
    return ((adc[1] & 3) << 8) + adc[2]

# Debounced button read
def read_button_debounced(name, pin, current_time):
    raw_state = int(GPIO.input(pin) == GPIO.LOW)  # LOW = pressed
    debounce_data = button_debounce[name]
    
    # If state changed, record time
    if raw_state != debounce_data['state']:
        debounce_data['last_change'] = current_time
        debounce_data['state'] = raw_state
    
    # If state is stable for debounce time, update stable state
    time_since_change = current_time - debounce_data['last_change']
    if time_since_change >= DEBOUNCE_TIME:
        debounce_data['stable_state'] = raw_state
    
    return debounce_data['stable_state']

# Atomic file write (write to temp, then rename)
def write_atomic(content, filepath, temppath):
    try:
        with open(temppath, "w") as f:
            f.write(content)
        os.rename(temppath, filepath)  # Atomic on Linux
    except (IOError, OSError) as e:
        print(f"Warning: Failed to write input file: {e}")


# Main loop
last_output = None
try:
    print("GPIO reader started")
    while True:
        current_time = time.time()
        
        # Read all buttons w/ debouncing
        button_states = {name: read_button_debounced(name, pin, current_time) 
                         for name, pin in BUTTONS.items()}

        # Read joystick
        joy = {axis: read_adc(ch) for axis, ch in JOYSTICK.items()}
        
        # Output str
        output = ','.join([f"{k}:{v}" for k, v in button_states.items()])
        output += f",jx:{joy['x']},jy:{joy['y']}\n"
        
        # Only write if changed values
        if output != last_output:
            write_atomic(output, OUTPUT_FILE, OUTPUT_FILE_TMP)
            last_output = output
        
        time.sleep(READ_INTERVAL)

except KeyboardInterrupt:
    spi.close()
    GPIO.cleanup()
    print("\nGPIO reader stopped")

except Exception as e:
    spi.close()
    GPIO.cleanup()
    print(f"\nError: {e}")
    raise
