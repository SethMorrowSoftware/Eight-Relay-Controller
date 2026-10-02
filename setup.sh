#!/bin/bash
# Enhanced Setup script for 8-Relay Control Service with Audio Support
#
# Clone the repository anywhere and run this script from the checkout:
#   git clone https://github.com/SethMorrowSoftware/Eight-Relay-Controller.git
#   cd Eight-Relay-Controller
#   sudo ./setup.sh
#
# Options:
#   -y, --yes    Answer yes to every prompt (unattended install)
#
# The service runs from the directory this script lives in, as the user who
# invoked sudo. To run it as a different user: sudo RELAY_USER=name ./setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help)
            sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg (see --help)${NC}"
            exit 1
            ;;
    esac
done

# The project directory is wherever this script was cloned to
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
APP_DIR="$(dirname "$SCRIPT_PATH")"

# Re-run with sudo if needed
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &> /dev/null; then
        echo -e "${YELLOW}Root privileges are required, re-running with sudo...${NC}"
        exec sudo ${RELAY_USER:+RELAY_USER="$RELAY_USER"} bash "$SCRIPT_PATH" "$@"
    fi
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Run the service as the user who invoked sudo, falling back to whoever owns
# the checkout (e.g. when logged in as root)
if [[ -n "${RELAY_USER:-}" ]]; then
    USERNAME="$RELAY_USER"
elif [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    USERNAME="$SUDO_USER"
else
    USERNAME="$(stat -c '%U' "$APP_DIR")"
fi

# Configuration
SERVICE_NAME="relay-control"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOG_DIR="/var/log/relay_control"
NGINX_AVAILABLE="/etc/nginx/sites-available/relay-control"
NGINX_ENABLED="/etc/nginx/sites-enabled/relay-control"
AUDIO_DIR="${APP_DIR}/audio"
VENV_DIR="${APP_DIR}/venv"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          8-Relay Control Service Enhanced Setup Script          ║${NC}"
echo -e "${GREEN}║                     with Audio Support                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}User: ${USERNAME} | Project: ${APP_DIR}${NC}"
echo ""

if ! id "$USERNAME" &> /dev/null; then
    echo -e "${RED}User '${USERNAME}' does not exist (set RELAY_USER to choose another user)${NC}"
    exit 1
fi
USER_GROUP="$(id -gn "$USERNAME")"

# Check that we are inside the project checkout
if [[ ! -f "$APP_DIR/app.py" || ! -f "$APP_DIR/config.json" ]]; then
    echo -e "${RED}app.py and config.json not found in $APP_DIR${NC}"
    echo -e "${RED}Run setup.sh from inside the cloned repository${NC}"
    exit 1
fi
cd "$APP_DIR"

# Ask a yes/no question. $2 (Y or N) is used when the user just presses Enter
# or when there is no terminal to ask on.
ask() {
    local reply=""
    if [[ $ASSUME_YES -eq 1 ]]; then
        echo "$1 y"
        return 0
    fi
    if [[ -t 0 ]]; then
        read -r -p "$1 " reply || true
    else
        echo "$1 (no terminal, using default: $2)"
    fi
    [[ ${reply:-$2} =~ ^[Yy] ]]
}

# Check if running on Raspberry Pi
IS_PI=0
IS_PI5=0
if grep -qa "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    IS_PI=1
fi
# The Pi 5 family (BCM2712) is not supported by RPi.GPIO; rpi-lgpio is a
# drop-in replacement that is
if grep -qa "bcm2712" /proc/device-tree/compatible 2>/dev/null; then
    IS_PI5=1
fi

if [[ $IS_PI -eq 0 ]]; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi${NC}"
    if ! ask "Continue anyway? (y/N)" N; then
        exit 1
    fi
fi

# Function to print step headers
print_step() {
    echo -e "${BLUE}╭─────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BLUE}│ $1${NC}"
    echo -e "${BLUE}╰─────────────────────────────────────────────────────────────────╯${NC}"
}

# Succeeds if apt has an installable version of the package
pkg_available() {
    local candidate
    candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

pkg_installed() {
    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]
}

# Prints the first of the given packages that apt can install, if any
first_available() {
    local pkg
    for pkg in "$@"; do
        if pkg_available "$pkg"; then
            echo "$pkg"
            return 0
        fi
    done
}

# Runs a command as the service user
as_user() {
    if [[ "$USERNAME" == "root" ]]; then
        "$@"
    else
        sudo -H -u "$USERNAME" "$@"
    fi
}

print_step "Step 1: Installing system dependencies..."
apt-get update

PACKAGES=(python3 python3-venv python3-pip)

# Package names differ between releases, so anything not essential is only
# installed when apt has it instead of failing the whole install
for pkg in python3-dev gcc alsa-utils sox libsox-fmt-all ffmpeg; do
    if pkg_available "$pkg"; then
        PACKAGES+=("$pkg")
    else
        echo -e "${YELLOW}Package $pkg is not available, skipping${NC}"
    fi
done

# espeak-ng replaces espeak on newer releases
ESPEAK_PKG="$(first_available espeak-ng espeak)"
if [[ -n "$ESPEAK_PKG" ]]; then
    PACKAGES+=("$ESPEAK_PKG")
else
    echo -e "${YELLOW}espeak is not available, sample sounds will not be generated${NC}"
fi

# GPIO library, used by the virtual environment through system site-packages
if [[ $IS_PI5 -eq 1 ]] || pkg_installed python3-rpi-lgpio; then
    GPIO_PKG="$(first_available python3-rpi-lgpio)"
else
    GPIO_PKG="$(first_available python3-rpi.gpio python3-rpi-lgpio)"
fi
if [[ -n "$GPIO_PKG" ]]; then
    PACKAGES+=("$GPIO_PKG")
fi

apt-get install -y "${PACKAGES[@]}"

echo -e "${GREEN}✓ System dependencies installed${NC}"

print_step "Step 2: Creating required directories..."
mkdir -p "$AUDIO_DIR"
mkdir -p "$LOG_DIR"
chown -R "${USERNAME}:${USER_GROUP}" "$APP_DIR"
chown -R "${USERNAME}:${USER_GROUP}" "$LOG_DIR"

echo -e "${GREEN}✓ Directories created${NC}"

print_step "Step 3: Creating Python virtual environment..."
# --system-site-packages lets the venv use the GPIO library installed by apt
# (for /usr/bin/python3). Re-running this on an existing venv just updates it.
as_user /usr/bin/python3 -m venv --system-site-packages "$VENV_DIR"
echo -e "${GREEN}✓ Virtual environment ready${NC}"

print_step "Step 4: Installing Python dependencies..."
as_user "$VENV_DIR/bin/pip" install --upgrade pip
as_user "$VENV_DIR/bin/pip" install flask

if ! as_user "$VENV_DIR/bin/pip" install pygame; then
    echo -e "${YELLOW}pip could not install pygame, installing python3-pygame from apt instead${NC}"
    apt-get install -y python3-pygame
fi

if [[ $IS_PI5 -eq 1 ]]; then
    # A pip-installed RPi.GPIO (from older versions of this script) would
    # shadow rpi-lgpio, and it does not work on the Pi 5
    as_user "$VENV_DIR/bin/pip" uninstall -y RPi.GPIO &> /dev/null || true
    GPIO_PIP="rpi-lgpio"
else
    GPIO_PIP="RPi.GPIO"
fi
if ! as_user "$VENV_DIR/bin/python" -c "import RPi.GPIO" &> /dev/null; then
    echo -e "${CYAN}GPIO library not available from apt, installing ${GPIO_PIP} with pip...${NC}"
    as_user "$VENV_DIR/bin/pip" install "$GPIO_PIP" || true
fi

# Make sure the service will be able to import everything it needs
if ! as_user "$VENV_DIR/bin/python" -c "import flask, pygame" > /dev/null; then
    echo -e "${RED}✗ Flask/pygame could not be installed, see the errors above${NC}"
    exit 1
fi
if ! as_user "$VENV_DIR/bin/python" -c "import RPi.GPIO" > /dev/null; then
    if [[ $IS_PI -eq 1 ]]; then
        echo -e "${RED}✗ The RPi.GPIO library could not be installed, see the errors above${NC}"
        exit 1
    fi
    echo -e "${YELLOW}RPi.GPIO cannot be used on this machine, the service needs a Raspberry Pi to run${NC}"
fi

echo -e "${GREEN}✓ Python dependencies installed${NC}"

print_step "Step 5: Setting up GPIO and audio permissions..."
# Add user to required groups
SERVICE_GROUPS=()
for group in gpio audio; do
    if ! getent group "$group" > /dev/null; then
        echo -e "${YELLOW}Group '$group' does not exist on this system, skipping${NC}"
        continue
    fi
    SERVICE_GROUPS+=("$group")
    if [[ " $(id -nG "$USERNAME") " == *" $group "* ]]; then
        echo -e "${YELLOW}✓ User '${USERNAME}' already in '$group' group${NC}"
    else
        usermod -a -G "$group" "$USERNAME"
        echo -e "${GREEN}✓ Added user '${USERNAME}' to '$group' group${NC}"
    fi
done

print_step "Step 6: Setting up audio system..."

# Set audio output to 3.5mm jack by default
echo -e "${CYAN}Setting default audio output to 3.5mm jack...${NC}"
amixer cset numid=3 1 2>/dev/null || echo -e "${YELLOW}Could not set audio output (normal on some systems)${NC}"

# Test basic audio
echo -e "${CYAN}Testing audio system...${NC}"
if command -v speaker-test &> /dev/null; then
    echo -e "${CYAN}Running quick audio test...${NC}"
    timeout 3 speaker-test -t sine -f 1000 -l 1 -c 1 2>/dev/null || true
fi

ESPEAK_BIN="$(command -v espeak-ng || command -v espeak || true)"

# Test espeak
if [[ -n "$ESPEAK_BIN" ]]; then
    echo -e "${CYAN}Testing espeak...${NC}"
    "$ESPEAK_BIN" --stdout "Audio system ready" 2>/dev/null | aplay -q 2>/dev/null || \
        echo -e "${YELLOW}Espeak test failed - audio may need configuration${NC}"
fi

echo -e "${GREEN}✓ Audio system configured${NC}"

print_step "Step 7: Creating sample audio files..."

# Function to create audio file with espeak
create_audio_file() {
    local text="$1"
    local filename="$2"
    local voice_options="$3"
    local wav_file="${AUDIO_DIR}/${filename%.mp3}.wav"

    # Don't overwrite sounds the user has replaced
    if [[ -e "${AUDIO_DIR}/${filename}" ]]; then
        echo -e "${YELLOW}  Keeping existing: ${filename}${NC}"
        return 0
    fi

    echo -e "${CYAN}  Creating: ${filename}${NC}"

    # Create WAV file first
    # shellcheck disable=SC2086  # voice_options holds several arguments
    if ! "$ESPEAK_BIN" $voice_options -w "$wav_file" "$text" 2>/dev/null; then
        echo -e "${YELLOW}    Could not generate ${filename}${NC}"
        return 0
    fi

    # Convert to MP3 if ffmpeg is available
    if command -v ffmpeg &> /dev/null && \
       ffmpeg -loglevel error -y -i "$wav_file" "${AUDIO_DIR}/${filename}"; then
        rm -f "$wav_file"
    else
        echo -e "${YELLOW}    Using WAV format (ffmpeg not available for MP3 conversion)${NC}"
    fi
}

if [[ -n "$ESPEAK_BIN" ]]; then
    # Create sample audio files using espeak
    echo -e "${CYAN}Generating sample audio files with espeak...${NC}"

    # Create sample sounds with different voices and effects
    create_audio_file "Doorbell" "doorbell.mp3" "-s 150 -p 50"
    create_audio_file "You have a notification" "notification.mp3" "-s 160 -v en+f3"
    create_audio_file "Chime" "chime.mp3" "-s 140 -p 40"
    create_audio_file "Alert! Attention required" "alert.mp3" "-s 180 -p 60 -v en+m3"
    create_audio_file "Sweet melody" "melody.mp3" "-s 130 -p 30 -v en+f2"
    create_audio_file "Warning! Check system status" "warning.mp3" "-s 170 -p 70 -v en+m5"
    create_audio_file "Operation completed successfully" "success.mp3" "-s 160 -p 45 -v en+f4"
else
    echo -e "${YELLOW}espeak not installed, skipping spoken sample sounds${NC}"
fi

# Create more advanced sounds with sox if available
if command -v sox &> /dev/null; then
    echo -e "${CYAN}Creating additional sound effects with sox...${NC}"

    # Create a simple doorbell chime
    [[ -e "${AUDIO_DIR}/doorbell_chime.wav" ]] || \
        sox -n "${AUDIO_DIR}/doorbell_chime.wav" synth 0.5 sine 800 sine 1200 fade 0.1 0.5 0.1 2>/dev/null || true

    # Create notification beep
    [[ -e "${AUDIO_DIR}/notification_beep.wav" ]] || \
        sox -n "${AUDIO_DIR}/notification_beep.wav" synth 0.3 sine 1000 fade 0.05 0.3 0.05 2>/dev/null || true

    # Create alert sound
    [[ -e "${AUDIO_DIR}/alert_tone.wav" ]] || \
        sox -n "${AUDIO_DIR}/alert_tone.wav" synth 0.2 sine 1500 sine 2000 repeat 2 fade 0.05 0.2 0.05 2>/dev/null || true

    echo -e "${GREEN}✓ Created sox-generated sound effects${NC}"
fi

# Set proper permissions
chown -R "${USERNAME}:${USER_GROUP}" "$AUDIO_DIR"
chmod 755 "$AUDIO_DIR"
find "$AUDIO_DIR" -type f -exec chmod 644 {} +

echo -e "${GREEN}✓ Sample audio files created in ${AUDIO_DIR}${NC}"

# config.json ships with audio paths for a checkout at /home/tech/8-relay;
# point them at this one
LEGACY_AUDIO_DIR="/home/tech/8-relay/audio"
if [[ "$AUDIO_DIR" != "$LEGACY_AUDIO_DIR" ]] && grep -q "$LEGACY_AUDIO_DIR/" "$APP_DIR/config.json"; then
    ESCAPED_AUDIO_DIR="$(printf '%s' "$AUDIO_DIR" | sed 's/[|&\\]/\\&/g')"
    sed -i "s|${LEGACY_AUDIO_DIR}/|${ESCAPED_AUDIO_DIR}/|g" "$APP_DIR/config.json"
    echo -e "${GREEN}✓ Updated audio file paths in config.json to ${AUDIO_DIR}${NC}"
fi

print_step "Step 8: Creating systemd service..."
# app.py sets up GPIO, the buttons and audio in main(), so the service runs it
# directly. Under gunicorn, main() never runs (relays don't work) and several
# workers would fight over the same GPIO pins.
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=8-Relay Control Web Service
After=network.target sound.target

[Service]
Type=simple
User=${USERNAME}
Group=${USER_GROUP}
# GPIO and audio permissions
SupplementaryGroups=${SERVICE_GROUPS[*]}
WorkingDirectory=${APP_DIR}
ExecStart="${VENV_DIR}/bin/python" "${APP_DIR}/app.py"
Environment=PYTHONUNBUFFERED=1
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
# Grant write access to necessary directories
ReadWritePaths="${LOG_DIR}" "${APP_DIR}"

# Resource limits
CPUQuota=50%
MemoryMax=256M

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=relay-control

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

echo -e "${GREEN}✓ Systemd service created and enabled${NC}"

print_step "Step 9: Setting up Nginx reverse proxy (optional)..."
if ask "Do you want to set up Nginx reverse proxy? (Y/n)" Y; then
    apt-get install -y nginx
    cat > "$NGINX_AVAILABLE" <<'EOF'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Sound file uploads from the admin page (the app allows up to 25 MB)
    client_max_body_size 26M;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts (uploads in formats like M4A are converted to MP3, which
        # can take a while on slower Pis)
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;
    }
}
EOF

    # Remove default nginx site so it doesn't take over port 80
    rm -f /etc/nginx/sites-enabled/default

    ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    if nginx -t; then
        systemctl enable nginx
        systemctl restart nginx
        echo -e "${GREEN}✓ Nginx configured successfully${NC}"
    else
        echo -e "${RED}✗ Nginx configuration test failed, see the output above${NC}"
    fi
else
    echo -e "${YELLOW}✓ Skipping Nginx setup${NC}"
fi

print_step "Step 10: Creating convenience and test scripts..."

# Create start script
cat > "$APP_DIR/start.sh" <<'EOF'
#!/bin/bash
echo "Starting Relay Control service..."
sudo systemctl start relay-control
sleep 2
echo "Service status:"
sudo systemctl status relay-control --no-pager -l
EOF

# Create stop script
cat > "$APP_DIR/stop.sh" <<'EOF'
#!/bin/bash
echo "Stopping Relay Control service..."
sudo systemctl stop relay-control
echo "Service stopped"
EOF

# Create logs script
cat > "$APP_DIR/logs.sh" <<'EOF'
#!/bin/bash
echo "=== Recent Relay Control Service Logs ==="
sudo journalctl -u relay-control -n 50 --no-pager
echo ""
echo "=== Application Log ==="
if [ -f /var/log/relay_control/relay_control.log ]; then
    sudo tail -n 50 /var/log/relay_control/relay_control.log
else
    echo "No application log file found yet"
fi
EOF

# Create enhanced test script with audio testing
cat > "$APP_DIR/test_system.py" <<'EOF'
#!/usr/bin/env python3
"""
Enhanced system test for 8-Relay Control with Audio Support
Tests GPIO pins, audio system, and configuration
"""
import RPi.GPIO as GPIO
import time
import os
import sys
import json
import pygame

# Load configuration
try:
    with open('config.json', 'r') as f:
        config = json.load(f)
except Exception as e:
    print(f"Error loading config: {e}")
    sys.exit(1)

RELAY_PINS = [int(pin) for pin in config['relay_pins'].values()]
AUDIO_DIR = "./audio"

def test_gpio_relays():
    """Test GPIO pins for relay module"""
    print("\n" + "="*60)
    print("GPIO RELAY PIN TEST")
    print("="*60)
    print("This will turn each relay ON for 1 second")
    print("Press Ctrl+C to stop\n")

    try:
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)

        # Setup pins
        for i, pin in enumerate(RELAY_PINS):
            GPIO.setup(pin, GPIO.OUT)
            GPIO.output(pin, GPIO.HIGH)  # Start with relays OFF (active-low)
            print(f"✓ Initialized Relay {i+1} on GPIO {pin}")

        print("\nStarting relay tests...\n")

        # Test each relay
        for i, pin in enumerate(RELAY_PINS):
            relay_name = config['relay_names'].get(str(i+1), f'Relay {i+1}')
            print(f"Testing {relay_name} (GPIO {pin})... ", end='')
            GPIO.output(pin, GPIO.LOW)   # Turn ON
            time.sleep(1)
            GPIO.output(pin, GPIO.HIGH)  # Turn OFF
            print("✓ PASS")

        print(f"\n✓ All {len(RELAY_PINS)} relays tested successfully!")
        return True

    except KeyboardInterrupt:
        print("\n⚠ Test interrupted by user")
        return False
    except Exception as e:
        print(f"\n✗ Error: {e}")
        return False
    finally:
        try:
            GPIO.cleanup()
            print("✓ GPIO cleaned up")
        except:
            pass

def test_audio_system():
    """Test audio system and sample files"""
    print("\n" + "="*60)
    print("AUDIO SYSTEM TEST")
    print("="*60)

    # Test pygame audio initialization
    try:
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
        print("✓ Pygame audio initialized successfully")
    except Exception as e:
        print(f"✗ Pygame audio initialization failed: {e}")
        return False

    # Test audio files
    if not os.path.exists(AUDIO_DIR):
        print(f"✗ Audio directory {AUDIO_DIR} not found")
        return False

    audio_files = []
    for file in os.listdir(AUDIO_DIR):
        if file.endswith(('.mp3', '.wav', '.ogg')):
            audio_files.append(file)

    if not audio_files:
        print(f"✗ No audio files found in {AUDIO_DIR}")
        return False

    print(f"✓ Found {len(audio_files)} audio files")

    # Test playing a sample file
    try:
        test_file = os.path.join(AUDIO_DIR, audio_files[0])
        print(f"Testing playback of: {audio_files[0]}")
        pygame.mixer.music.load(test_file)
        pygame.mixer.music.play()
        time.sleep(2)  # Play for 2 seconds
        pygame.mixer.music.stop()
        print("✓ Audio playback test completed")
        return True
    except Exception as e:
        print(f"✗ Audio playback test failed: {e}")
        return False
    finally:
        try:
            pygame.mixer.quit()
        except:
            pass

def test_configuration():
    """Test configuration file completeness"""
    print("\n" + "="*60)
    print("CONFIGURATION TEST")
    print("="*60)

    required_sections = [
        'relay_pins', 'relay_names', 'relay_settings',
        'multi_button_settings', 'audio_buttons', 'server'
    ]

    for section in required_sections:
        if section in config:
            print(f"✓ {section} section present")
        else:
            print(f"✗ {section} section missing")

    # Test relay configuration
    relay_count = len(config.get('relay_pins', {}))
    print(f"✓ {relay_count} relays configured")

    # Test audio button configuration
    audio_buttons = config.get('audio_buttons', {})
    if audio_buttons.get('enabled'):
        audio_count = sum(1 for key in audio_buttons.keys()
                         if key.startswith('button') and audio_buttons[key].get('pin'))
        print(f"✓ {audio_count} audio buttons configured")
    else:
        print("⚠ Audio buttons disabled")

    return True

def main():
    """Main test function"""
    print("8-Relay Control System Test Suite")
    print("=" * 60)

    tests_passed = 0
    total_tests = 3

    # Test configuration
    if test_configuration():
        tests_passed += 1

    # Test GPIO relays
    if test_gpio_relays():
        tests_passed += 1

    # Test audio system
    if test_audio_system():
        tests_passed += 1

    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    print(f"Tests passed: {tests_passed}/{total_tests}")

    if tests_passed == total_tests:
        print("✓ All tests PASSED! System is ready.")
        return True
    else:
        print("⚠ Some tests FAILED. Check configuration and wiring.")
        return False

if __name__ == '__main__':
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        GPIO.cleanup()
        sys.exit(1)
EOF

# Create simple GPIO test script (legacy)
cat > "$APP_DIR/test_gpio.py" <<'EOF'
#!/usr/bin/env python3
"""Simple GPIO pin test for relay module"""
import RPi.GPIO as GPIO
import time
import json

# Load relay pins from config
try:
    with open('config.json', 'r') as f:
        config = json.load(f)
    RELAY_PINS = [int(pin) for pin in config['relay_pins'].values()]
except:
    RELAY_PINS = [17, 18, 27, 22, 23, 24, 25, 4]  # Default pins

print("GPIO Pin Test for Relay Module")
print("==============================")
print("This will turn each relay ON for 1 second")
print("Press Ctrl+C to stop")

try:
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)

    # Setup pins
    for pin in RELAY_PINS:
        GPIO.setup(pin, GPIO.OUT)
        GPIO.output(pin, GPIO.HIGH)  # Start with relays OFF (active-low)

    # Test each relay
    for i, pin in enumerate(RELAY_PINS):
        print(f"\nTesting Relay {i+1} (GPIO {pin})...")
        GPIO.output(pin, GPIO.LOW)   # Turn ON
        time.sleep(1)
        GPIO.output(pin, GPIO.HIGH)  # Turn OFF
        print(f"Relay {i+1} test complete")

    print("\nAll relays tested successfully!")

except KeyboardInterrupt:
    print("\nTest interrupted")
except Exception as e:
    print(f"Error: {e}")
finally:
    GPIO.cleanup()
    print("GPIO cleaned up")
EOF

# Create audio test script
cat > "$APP_DIR/test_audio.py" <<'EOF'
#!/usr/bin/env python3
"""Test audio system and sample files"""
import pygame
import os
import time
import sys

AUDIO_DIR = "./audio"

def test_audio():
    print("Audio System Test")
    print("================")

    try:
        pygame.mixer.init()
        print("✓ Audio system initialized")
    except Exception as e:
        print(f"✗ Audio initialization failed: {e}")
        return False

    if not os.path.exists(AUDIO_DIR):
        print(f"✗ Audio directory {AUDIO_DIR} not found")
        return False

    audio_files = [f for f in os.listdir(AUDIO_DIR) if f.endswith(('.mp3', '.wav', '.ogg'))]

    if not audio_files:
        print(f"✗ No audio files found in {AUDIO_DIR}")
        return False

    print(f"Found {len(audio_files)} audio files:")
    for i, file in enumerate(audio_files, 1):
        print(f"  {i}. {file}")

    print("\nTesting each file (press Ctrl+C to skip):")

    for file in audio_files:
        try:
            print(f"\nPlaying: {file}")
            pygame.mixer.music.load(os.path.join(AUDIO_DIR, file))
            pygame.mixer.music.play()
            time.sleep(3)  # Play for 3 seconds
            pygame.mixer.music.stop()
        except KeyboardInterrupt:
            print("\nSkipping remaining tests...")
            break
        except Exception as e:
            print(f"Error playing {file}: {e}")

    pygame.mixer.quit()
    print("\n✓ Audio test completed")
    return True

if __name__ == '__main__':
    test_audio()
EOF

echo -e "${GREEN}✓ Test and convenience scripts created${NC}"

print_step "Step 11: Setting final permissions..."
chown -R "${USERNAME}:${USER_GROUP}" "$APP_DIR"

# Make scripts executable
chmod +x "$APP_DIR"/start.sh "$APP_DIR"/stop.sh "$APP_DIR"/logs.sh "$APP_DIR"/test_*.py

echo -e "${GREEN}✓ Permissions set correctly${NC}"

print_step "Setup Complete!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         SETUP SUMMARY                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Installation Details:${NC}"
echo -e "  📁 Application directory: ${APP_DIR}"
echo -e "  👤 Service user: ${USERNAME}"
echo -e "  🔧 Service name: ${SERVICE_NAME}"
echo -e "  📝 Log directory: ${LOG_DIR}"
echo -e "  🔊 Audio directory: ${AUDIO_DIR}"
echo ""
echo -e "${CYAN}Generated Files:${NC}"
echo -e "  🎵 $(find "$AUDIO_DIR" -name "*.mp3" -o -name "*.wav" | wc -l) audio files"
echo -e "  📋 System test scripts"
echo -e "  ⚙️ Service management scripts"
echo ""
echo -e "${CYAN}Useful Commands:${NC}"
echo -e "  🚀 Start service:     ${APP_DIR}/start.sh"
echo -e "  🛑 Stop service:      ${APP_DIR}/stop.sh"
echo -e "  📊 View logs:         ${APP_DIR}/logs.sh"
echo -e "  🧪 Test system:      cd ${APP_DIR} && sudo venv/bin/python test_system.py"
echo -e "  🔌 Test GPIO only:   cd ${APP_DIR} && sudo venv/bin/python test_gpio.py"
echo -e "  🔊 Test audio only:  cd ${APP_DIR} && venv/bin/python test_audio.py"
echo -e "  (Stop the service before running the tests, they use the same pins)"
echo ""
echo -e "${CYAN}Manual Commands:${NC}"
echo -e "  📈 Service status:    sudo systemctl status ${SERVICE_NAME}"
echo -e "  📜 Live logs:         sudo journalctl -u ${SERVICE_NAME} -f"
echo -e "  🔄 Restart service:   sudo systemctl restart ${SERVICE_NAME}"
echo ""

if ask "🚀 Do you want to start the service now? (Y/n)" Y; then
    # restart so that re-running setup picks up any changes
    systemctl restart "$SERVICE_NAME" || true
    sleep 3

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ Service started successfully!${NC}"
        echo ""
        echo -e "${CYAN}🌐 Access the web interface at:${NC}"
        PI_IP=$(hostname -I | cut -d' ' -f1)
        echo -e "  🔗 Main interface:  http://${PI_IP}:5000"
        if [[ -f $NGINX_ENABLED ]]; then
            echo -e "  🔗 Nginx proxy:     http://${PI_IP}"
        fi
        echo -e "  ⚙️ Admin panel:     http://${PI_IP}:5000/admin"
        echo ""
        echo -e "${YELLOW}💡 Pro tip: Run the system test to verify everything works:${NC}"
        echo -e "   cd ${APP_DIR} && sudo venv/bin/python test_system.py"
    else
        echo -e "${RED}✗ Service failed to start. Check logs:${NC}"
        echo -e "   sudo journalctl -u ${SERVICE_NAME} -n 20"
    fi
else
    echo -e "${CYAN}You can start the service later with:${NC}"
    echo -e "   sudo systemctl start ${SERVICE_NAME}"
    echo -e "   or use: ${APP_DIR}/start.sh"
fi

echo ""
echo -e "${GREEN}🎉 Enhanced setup completed successfully!${NC}"
echo -e "${PURPLE}   Logout and login again for group changes to take effect${NC}"
echo ""
