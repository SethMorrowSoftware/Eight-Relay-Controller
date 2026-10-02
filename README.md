# 8-Relay Control System for Raspberry Pi

**A production-ready web-based control system for managing an 8-channel relay module with comprehensive physical button support and audio playback capabilities.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/python-3.7+-blue.svg)](https://www.python.org/downloads/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-All%20Models-red.svg)](https://www.raspberrypi.org/)

**Author:** Seth Morrow  
**Version:** 2.0.0  
**Last Updated:** July 2025

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Hardware Setup](#hardware-setup)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Web Interface](#web-interface)
- [API Reference](#api-reference)
- [Physical Buttons](#physical-buttons)
- [Audio System](#audio-system)
- [Admin Dashboard](#admin-dashboard)
- [Service Management](#service-management)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Development](#development)
- [Safety Considerations](#safety-considerations)
- [Performance Optimization](#performance-optimization)
- [Backup and Recovery](#backup-and-recovery)
- [Monitoring and Alerts](#monitoring-and-alerts)
- [Integration Examples](#integration-examples)
- [Frequently Asked Questions](#frequently-asked-questions)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Quick Reference Card](#quick-reference-card)

---

## Overview

The 8-Relay Control System is a comprehensive solution for controlling relay modules via Raspberry Pi GPIO pins. It provides both web-based and physical button control interfaces, making it ideal for home automation, industrial control, or educational projects.

### Key Capabilities

- **8 Independent Relay Controls** - Each relay can be triggered individually with configurable durations
- **Physical Button Interface** - Hardware buttons for direct relay control without network access
- **Audio Feedback System** - Play custom sounds through 7 configurable audio buttons
- **Web Control Panel** - Modern, responsive interface accessible from any device
- **Real-time Monitoring** - Live status updates and system health monitoring
- **Extensive Configuration** - JSON-based configuration with runtime updates
- **Production Ready** - Systemd service integration, logging, and error recovery

---

## Features

### Core Features

- ✅ **8-Channel Relay Control**
  - Individual relay activation with configurable trigger durations
  - Support for both active-high and active-low relay modules
  - Concurrent trigger limiting to prevent power issues
  - Thread-safe operation with proper locking mechanisms

- ✅ **Web Interface**
  - Modern, responsive design with dark theme
  - Real-time status updates via AJAX
  - Mobile-friendly layout
  - Connection status indicator
  - Keyboard shortcuts (1-8 keys for relay control)

- ✅ **Physical Button Support**
  - Up to 8 relay control buttons (one per relay)
  - 7 audio playback buttons for sound effects
  - 1 reset button for emergency relay cancellation
  - Configurable debounce timing
  - Pull-up/pull-down resistor configuration

- ✅ **Audio Playback System**
  - Support for MP3, WAV, OGG, FLAC, and M4A formats
  - Individual volume control per button
  - Multiple audio driver support with automatic fallback
  - Audio file validation before playback

- ✅ **Admin Dashboard**
  - Configure relay names and trigger durations
  - Manage button assignments and GPIO pins
  - View system statistics and logs
  - Real-time configuration updates
  - Audio file management and testing
  - Scene and scheduling configuration via API (optional)

- ✅ **System Integration**
  - Runs as systemd service with automatic startup
  - Rotating log files with size management
  - Optional Nginx reverse proxy support
  - Health check endpoints for monitoring
  - Comprehensive error handling and recovery

### Technical Features

- **Multi-threaded Architecture** - Non-blocking relay and button operations
- **Configuration Management** - JSON-based with hot-reload support
- **GPIO Resource Management** - Proper initialization and cleanup
- **Statistics Tracking** - Usage metrics and error counting
- **API Endpoints** - RESTful API for integration
- **Scenes and Scheduling** - Batch triggers, scene orchestration, and delayed actions
- **Test Utilities** - Built-in GPIO and audio testing scripts

---

## System Requirements

### Hardware Requirements

- **Raspberry Pi** - Any model with GPIO header (Pi Zero, 2, 3, 4, 5)
- **8-Channel Relay Module** - 5V compatible (active-low recommended)
- **Power Supply** - Adequate for Pi and relay module
- **Optional Hardware:**
  - Momentary push buttons for physical control
  - Speaker or audio output device
  - Jumper wires and breadboard for connections

### Software Requirements

- **Operating System:** Raspberry Pi OS (Raspbian) Bullseye or later
- **Python:** 3.7 or higher
- **Network:** Internet connection for initial setup
- **Storage:** Minimum 100MB free space

---

## Hardware Setup

### Relay Module Wiring

Connect your 8-channel relay module to the Raspberry Pi according to this pinout:

| Relay | GPIO Pin | Physical Pin | Function |
|-------|----------|--------------|----------|
| Relay 1 | GPIO 17 | Pin 11 | Channel 1 Control |
| Relay 2 | GPIO 18 | Pin 12 | Channel 2 Control |
| Relay 3 | GPIO 27 | Pin 13 | Channel 3 Control |
| Relay 4 | GPIO 22 | Pin 15 | Channel 4 Control |
| Relay 5 | GPIO 23 | Pin 16 | Channel 5 Control |
| Relay 6 | GPIO 24 | Pin 18 | Channel 6 Control |
| Relay 7 | GPIO 25 | Pin 22 | Channel 7 Control |
| Relay 8 | GPIO 4  | Pin 7  | Channel 8 Control |

**Power Connections:**
- VCC → 5V (Pin 2 or 4)
- GND → Ground (Pin 6, 9, 14, 20, 25, 30, 34, or 39)
- JD-VCC → External 5V supply (for isolated relay modules)

### Physical Button Wiring

All buttons connect between their assigned GPIO pin and ground:

**Relay Control Buttons (Optional):**
| Button | GPIO Pin | Physical Pin | Controls |
|--------|----------|--------------|----------|
| Button 1 | GPIO 26 | Pin 37 | Relay 1 |
| Button 2 | GPIO 5  | Pin 29 | Relay 2 |
| Button 3 | GPIO 6  | Pin 31 | Relay 3 |
| Button 4 | GPIO 12 | Pin 32 | Relay 4 |
| Button 5 | GPIO 20 | Pin 38 | Relay 5 |
| Button 6 | GPIO 21 | Pin 40 | Relay 6 |
| Button 7 | GPIO 7  | Pin 26 | Relay 7 |
| Button 8 | GPIO 8  | Pin 24 | Relay 8 |

**Special Function Buttons:**
| Button | GPIO Pin | Physical Pin | Function |
|--------|----------|--------------|----------|
| Reset | GPIO 16 | Pin 36 | Cancel Relay 1 Operation |

**Audio Playback Buttons:**
| Button | GPIO Pin | Physical Pin | Default Sound |
|--------|----------|--------------|---------------|
| Audio 1 | GPIO 13 | Pin 33 | Doorbell |
| Audio 2 | GPIO 19 | Pin 35 | Notification |
| Audio 3 | GPIO 9  | Pin 21 | Chime |
| Audio 4 | GPIO 10 | Pin 19 | Alert |
| Audio 5 | GPIO 11 | Pin 23 | Melody |
| Audio 6 | GPIO 2  | Pin 3  | Warning (I2C SDA)* |
| Audio 7 | GPIO 3  | Pin 5  | Success (I2C SCL)* |

*Note: GPIO 2 and 3 have built-in pull-up resistors

### Wiring Diagram

```
Raspberry Pi                    8-Channel Relay Module
+-----------+                   +------------------+
|        5V |-------------------| VCC              |
|       GND |-------------------| GND              |
|   GPIO 17 |-------------------| IN1              |
|   GPIO 18 |-------------------| IN2              |
|   GPIO 27 |-------------------| IN3              |
|   GPIO 22 |-------------------| IN4              |
|   GPIO 23 |-------------------| IN5              |
|   GPIO 24 |-------------------| IN6              |
|   GPIO 25 |-------------------| IN7              |
|    GPIO 4 |-------------------| IN8              |
+-----------+                   +------------------+

Physical Buttons (Connect to Ground)
+-----------+
|   GPIO 26 |----[Button 1]----GND
|   GPIO 16 |----[Reset]-------GND
|   GPIO 13 |----[Audio 1]-----GND
|     ...   |
+-----------+
```

---

## Installation

### Quick Installation

1. **Clone the repository** (any directory works):
```bash
git clone https://github.com/SethMorrowSoftware/Eight-Relay-Controller.git
cd Eight-Relay-Controller
```

2. **Run the setup script:**
```bash
sudo ./setup.sh
```

The script installs everything (including audio support) and sets up the service to run from the directory you cloned into, as the user who ran `sudo`. Use `sudo ./setup.sh -y` to accept every prompt, or `sudo RELAY_USER=name ./setup.sh` to run the service as a different user. It is safe to run again, for example after a `git pull`.

### Manual Installation

If you prefer manual installation or need to customize the process:

1. **Install system dependencies:**
```bash
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv python3-dev python3-rpi.gpio nginx
```

2. **Create virtual environment:**
```bash
python3 -m venv venv
source venv/bin/activate
```

3. **Install Python packages:**
```bash
pip install flask RPi.GPIO pygame
```
On a Raspberry Pi 5, install `rpi-lgpio` instead of `RPi.GPIO` (RPi.GPIO does not support the Pi 5).

4. **Set up permissions:**
```bash
sudo usermod -a -G gpio,audio $USER
```

5. **Create systemd service** (edit `User`, `Group` and the paths in `relay-control.service` to match your user and checkout first):
```bash
sudo cp relay-control.service /etc/systemd/system/
sudo systemctl enable relay-control
sudo systemctl start relay-control
```

---

## Configuration

The system uses a JSON configuration file (`config.json`) for all settings.

### Basic Configuration

```json
{
    "relay_pins": {
        "1": 17, "2": 18, "3": 27, "4": 22,
        "5": 23, "6": 24, "7": 25, "8": 4
    },
    "relay_names": {
        "1": "Living Room Light",
        "2": "Kitchen Light",
        "3": "Bedroom Fan",
        "4": "Garage Door",
        "5": "Garden Sprinkler",
        "6": "Pool Pump",
        "7": "Security Light",
        "8": "Spare Relay"
    },
    "relay_settings": {
        "active_low": true,
        "trigger_durations": {
            "1": 0.5, "2": 0.5, "3": 0.5, "4": 1.0,
            "5": 10.0, "6": 30.0, "7": 0.5, "8": 0.5
        },
        "max_concurrent_triggers": 3
    }
}
```

### Button Configuration

```json
{
    "multi_button_settings": {
        "enabled": true,
        "buttons": {
            "1": {"pin": 26, "relay": 1, "enabled": true},
            "2": {"pin": 5, "relay": 2, "enabled": true},
            "3": {"pin": 6, "relay": 3, "enabled": true},
            "4": {"pin": 12, "relay": 4, "enabled": true}
        },
        "pull_up": true,
        "debounce_time": 0.3,
        "poll_interval": 0.01
    }
}
```

### Audio Configuration

```json
{
    "audio_buttons": {
        "enabled": true,
        "button1": {
            "pin": 13,
            "audio_file": "/home/tech/8-relay/audio/doorbell.mp3",
            "name": "Doorbell",
            "volume": 70,
            "pull_up": true,
            "debounce_time": 0.3
        }
    }
}
```

### Server Configuration

```json
{
    "server": {
        "host": "0.0.0.0",
        "port": 5000,
        "debug": false
    },
    "logging": {
        "log_dir": "/var/log/relay_control",
        "log_file": "relay_control.log",
        "max_size_mb": 10,
        "backup_count": 5,
        "log_level": "INFO"
    }
}
```

### Scenes and Scheduling Configuration

```json
{
    "scenes": {
        "enabled": false,
        "items": {
            "evening_routine": {
                "description": "Turn on key relays in sequence",
                "delay_between": 0.25,
                "actions": [
                    {"relay": 1, "duration": 0.5},
                    {"relay": 2, "duration": 1.0},
                    {"relay": 7, "duration": 0.5}
                ]
            }
        }
    },
    "scheduling": {
        "enabled": true,
        "max_jobs": 20,
        "max_delay_seconds": 86400
    },
    "api_controls": {
        "allow_duration_override": true,
        "max_override_seconds": 60,
        "allow_relay_cancel": true,
        "allow_scene_trigger": true
    }
}
```

---

## Usage

### Starting the Service

```bash
# Using systemctl
sudo systemctl start relay-control

# Using convenience script
./start.sh

# Check status
sudo systemctl status relay-control
```

### Accessing the Web Interface

Open a web browser and navigate to:
- **Direct access:** `http://YOUR_RASPBERRY_PI_IP:5000`
- **Via Nginx:** `http://YOUR_RASPBERRY_PI_IP`

### Using Physical Buttons

- **Relay Buttons:** Press any configured button to trigger its associated relay
- **Reset Button:** Press to cancel an active Relay 1 operation
- **Audio Buttons:** Press to play the configured sound file

### Command Line Testing

```bash
# Test all systems
# (stop the service first, the tests use the same GPIO pins)
cd ~/Eight-Relay-Controller
sudo venv/bin/python test_system.py

# Test GPIO only
sudo venv/bin/python test_gpio.py

# Test audio only
venv/bin/python test_audio.py
```

---

## Web Interface

### Main Control Panel

The web interface provides:
- **8 Relay Control Buttons** - Click to trigger each relay
- **Visual Feedback** - Active relays show orange color with pulsing animation
- **Connection Status** - Real-time connection indicator
- **Audio Controls** - Play sounds via web interface (if enabled)
- **Keyboard Shortcuts** - Press keys 1-8 to trigger relays

### Features

- **Responsive Design** - Works on desktop, tablet, and mobile devices
- **Dark Theme** - Easy on the eyes for low-light environments
- **Real-time Updates** - Status refreshes every 5 seconds
- **Error Handling** - Clear error messages for failed operations

---

## API Reference

### Relay Control

**Trigger Relay**
```http
POST /relay/{relay_number}
```

Response:
```json
{
    "status": "success",
    "relay": 1,
    "duration": 0.5
}
```

**Pulse Relay with Custom Duration**
```http
POST /relay/{relay_number}/pulse
Content-Type: application/json

{"duration": 1.5}
```

**Cancel Active Relay**
```http
POST /relay/{relay_number}/cancel
```

**Batch Trigger Relays**
```http
POST /relays/batch
Content-Type: application/json

{
  "relays": [
    {"relay": 1, "duration": 0.5, "delay": 0},
    {"relay": 2, "duration": 1.0, "delay": 0.25}
  ]
}
```

### Audio Playback

**Play Audio**
```http
POST /audio/play/{button_number}
```

Response:
```json
{
    "status": "success",
    "message": "Playing Doorbell"
}
```

### Status Endpoints

**Get System Status**
```http
GET /status
```

Response:
```json
{
    "relays": {
        "1": {
            "name": "Living Room Light",
            "state": "OFF",
            "locked": false,
            "gpio_pin": 17
        }
    },
    "system": {
        "active_triggers": 0,
        "max_concurrent": 3,
        "audio_enabled": true
    }
}
```

**Health Check**
```http
GET /health
```

**System Metrics**
```http
GET /metrics
```

### Scenes and Scheduling

**List Scenes**
```http
GET /scenes
```

**Trigger Scene**
```http
POST /scene/{scene_name}
```

**Schedule Relay or Scene**
```http
POST /schedule
Content-Type: application/json

{"type": "relay", "relay": 1, "delay": 60, "duration": 0.5}
```

**List Scheduled Jobs**
```http
GET /schedule
```

**Cancel Scheduled Job**
```http
DELETE /schedule/{job_id}
```

### Admin Endpoints

**Get Statistics**
```http
GET /admin/stats
```

**Update Configuration**
```http
POST /admin/config
Content-Type: application/json

{
    "section": "relay_names",
    "settings": {
        "1": "New Relay Name"
    }
}
```

---

## Physical Buttons

### Button Types

1. **Relay Control Buttons**
   - One button per relay (up to 8)
   - Momentary push buttons (normally open)
   - Connect between GPIO pin and ground
   - Internal pull-up resistors enabled by default

2. **Reset Button**
   - Cancels active Relay 1 operation
   - Useful for emergency stops
   - GPIO 16 by default

3. **Audio Playback Buttons**
   - Play pre-configured sound files
   - 7 available audio buttons
   - Each with individual volume control

### Button Configuration

Configure buttons in the admin dashboard or directly in `config.json`:

```json
{
    "multi_button_settings": {
        "enabled": true,
        "buttons": {
            "1": {
                "pin": 26,
                "relay": 1,
                "enabled": true
            }
        },
        "debounce_time": 0.3,
        "poll_interval": 0.01
    }
}
```

### Debouncing

The system implements software debouncing to prevent false triggers:
- **Debounce Time:** Minimum time between button presses (default: 0.3s)
- **Poll Interval:** How often to check button state (default: 0.01s)

---

## Audio System

### Supported Formats

- MP3 (.mp3)
- WAV (.wav)
- OGG (.ogg)
- FLAC (.flac)
- M4A (.m4a)

### Audio Configuration

Each audio button can be configured with:
- **GPIO Pin** - Physical button connection
- **Audio File** - Full path to sound file
- **Name** - Display name for the button
- **Volume** - Playback volume (0-100%)

### Creating Audio Files

1. **Using espeak (text-to-speech):**
```bash
espeak "Hello World" -w hello.wav
```

2. **Using sox (sound generation):**
```bash
# Create a beep
sox -n beep.wav synth 0.5 sine 1000

# Create a doorbell chime
sox -n doorbell.wav synth 0.5 sine 800 sine 1200
```

3. **Converting formats:**
```bash
ffmpeg -i input.mp3 -ar 44100 -ac 2 output.wav
```

### Audio Troubleshooting

1. **Set audio output:**
```bash
# For 3.5mm jack
sudo amixer cset numid=3 1

# For HDMI
sudo amixer cset numid=3 2

# For USB
sudo amixer cset numid=3 0
```

2. **Test audio:**
```bash
speaker-test -t sine -f 1000 -l 1
```

3. **Check volume:**
```bash
alsamixer
```

---

## Admin Dashboard

Access the admin dashboard at `http://YOUR_PI_IP:5000/admin`

### Features

#### System Statistics
- Uptime
- Total relay triggers
- Audio plays count
- Error count
- Active buttons

#### Configuration Tabs

1. **Relays Tab**
   - Set custom relay names
   - Configure trigger durations
   - Set active-low/high mode
   - Test individual relays

2. **Physical Buttons Tab**
   - Enable/disable multi-button mode
   - Assign GPIO pins to buttons
   - Configure debounce settings
   - Enable reset button

3. **Audio Buttons Tab**
   - Configure up to 7 audio buttons
   - Set audio file paths
   - Adjust volume levels
   - Validate audio files
   - Test playback

4. **System Tab**
   - Server configuration (host, port)
   - Logging settings
   - System information

5. **Logs Tab**
   - View recent log entries
   - Real-time log updates
   - Clear log display

### Making Configuration Changes

1. Navigate to the appropriate tab
2. Modify settings as needed
3. Click "Save" button
4. Restart the service to apply changes:
   ```bash
   sudo systemctl restart relay-control
   ```

---

## Service Management

### Systemd Commands

```bash
# Start service
sudo systemctl start relay-control

# Stop service
sudo systemctl stop relay-control

# Restart service
sudo systemctl restart relay-control

# Enable auto-start on boot
sudo systemctl enable relay-control

# Disable auto-start
sudo systemctl disable relay-control

# View service status
sudo systemctl status relay-control

# View service logs
sudo journalctl -u relay-control -f
```

### Convenience Scripts

The project includes helper scripts:

```bash
# Start service
./start.sh

# Stop service
./stop.sh

# View logs
./logs.sh
```

### Log Management

Logs are stored in `/var/log/relay_control/relay_control.log`

- Automatic rotation when size exceeds configured limit
- Configurable number of backup files
- Log levels: DEBUG, INFO, WARNING, ERROR

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Permission Denied Errors

**Problem:** GPIO access denied
```
Permission denied: '/dev/gpiomem'
```

**Solution:**
```bash
# Add user to gpio group
sudo usermod -a -G gpio $USER

# Logout and login again
logout
```

#### 2. Relays Not Working

**Problem:** Relays don't activate when triggered

**Solutions:**
1. Check wiring connections
2. Verify GPIO pin assignments in config.json
3. Test with GPIO test script:
   ```bash
   sudo python3 test_gpio.py
   ```
4. Check relay module power supply
5. Verify active-low/high setting matches your relay module

#### 3. Audio Not Playing

**Problem:** No sound when audio buttons pressed

**Solutions:**
1. Check audio output selection:
   ```bash
   sudo amixer cset numid=3 1  # 3.5mm jack
   ```
2. Verify audio file paths in config.json
3. Test audio system:
   ```bash
   python3 test_audio.py
   ```
4. Check file permissions:
   ```bash
   ls -la ~/Eight-Relay-Controller/audio/
   ```
5. Ensure audio files are in supported format

#### 4. Web Interface Not Loading

**Problem:** Cannot access web interface

**Solutions:**
1. Check if service is running:
   ```bash
   sudo systemctl status relay-control
   ```
2. Verify port is not blocked:
   ```bash
   sudo netstat -tlnp | grep 5000
   ```
3. Check firewall settings:
   ```bash
   sudo ufw status
   ```
4. Try accessing directly:
   ```bash
   curl http://localhost:5000
   ```

#### 5. Buttons Not Responding

**Problem:** Physical buttons don't trigger actions

**Solutions:**
1. Check button wiring (should connect to ground when pressed)
2. Verify GPIO pins in configuration
3. Test GPIO input:
   ```python
   import RPi.GPIO as GPIO
   GPIO.setmode(GPIO.BCM)
   GPIO.setup(26, GPIO.IN, pull_up_down=GPIO.PUD_UP)
   print(GPIO.input(26))  # Should show 1 normally, 0 when pressed
   ```
4. Check debounce settings (may be too short/long)

#### 6. Service Won't Start

**Problem:** Systemd service fails to start

**Solutions:**
1. Check service logs:
   ```bash
   sudo journalctl -u relay-control -n 50
   ```
2. Verify Python path:
   ```bash
   which python3
   ls -la ~/Eight-Relay-Controller/venv/bin/python
   ```
3. Check file permissions:
   ```bash
   ls -la ~/Eight-Relay-Controller/app.py
   ```
4. Run manually to see errors:
   ```bash
   cd ~/Eight-Relay-Controller
   source venv/bin/activate
   python app.py
   ```

### Debug Mode

Enable debug logging for more information:

1. Edit config.json:
   ```json
   {
       "logging": {
           "log_level": "DEBUG"
       }
   }
   ```

2. Restart service:
   ```bash
   sudo systemctl restart relay-control
   ```

3. Monitor debug logs:
   ```bash
   sudo journalctl -u relay-control -f
   ```

### GPIO Pin Testing

Test individual GPIO pins:

```python
#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time

# Test a specific pin
test_pin = 17
GPIO.setmode(GPIO.BCM)
GPIO.setup(test_pin, GPIO.OUT)

print(f"Testing GPIO {test_pin}")
GPIO.output(test_pin, GPIO.HIGH)
print("Pin HIGH (relay OFF for active-low)")
time.sleep(2)

GPIO.output(test_pin, GPIO.LOW)
print("Pin LOW (relay ON for active-low)")
time.sleep(2)

GPIO.output(test_pin, GPIO.HIGH)
print("Pin HIGH (relay OFF)")
GPIO.cleanup()
```

---

## Advanced Configuration

### Using Different GPIO Pins

To use different GPIO pins than the defaults:

1. Edit config.json:
   ```json
   {
       "relay_pins": {
           "1": 5,   // Changed from 17
           "2": 6,   // Changed from 18
           // ... etc
       }
   }
   ```

2. Update button pins if needed:
   ```json
   {
       "multi_button_settings": {
           "buttons": {
               "1": {"pin": 13, "relay": 1, "enabled": true}
           }
       }
   }
   ```

### Active-High Relay Modules

If your relay module is active-high (relay ON when GPIO is HIGH):

```json
{
    "relay_settings": {
        "active_low": false
    }
}
```

### Custom Trigger Durations

Set different activation times for each relay:

```json
{
    "relay_settings": {
        "trigger_durations": {
            "1": 0.5,   // Half second
            "2": 1.0,   // One second
            "3": 5.0,   // Five seconds
            "4": 0.1    // 100 milliseconds
        }
    }
}
```

### Nginx Reverse Proxy

To access without port number:

1. Install Nginx:
   ```bash
   sudo apt-get install nginx
   ```

2. Configure proxy:
   ```nginx
   server {
       listen 80;
       server_name _;
       
       location / {
           proxy_pass http://127.0.0.1:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

3. Enable site:
   ```bash
   sudo ln -s /etc/nginx/sites-available/relay-control /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

### SSL/HTTPS Setup

For secure access:

1. Install Certbot:
   ```bash
   sudo apt-get install certbot python3-certbot-nginx
   ```

2. Obtain certificate:
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```

### Remote Access

To access from outside your network:

1. **Port Forwarding:** Configure router to forward port 80/443 to Pi
2. **Dynamic DNS:** Use a service like DuckDNS or No-IP
3. **VPN:** Set up WireGuard or OpenVPN for secure access

---

## Development

### Project Structure

```
Eight-Relay-Controller/
├── app.py              # Main Flask application
├── config.json         # Configuration file
├── setup.sh            # Installation script
├── relay-control.service  # Reference systemd unit (setup.sh generates the real one)
├── templates/
│   ├── index.html      # Main control panel
│   └── admin.html      # Admin dashboard
├── audio/              # Audio files directory
│   ├── doorbell.mp3
│   ├── notification.mp3
│   └── ...
├── logs/               # Log files (created at runtime)
├── start.sh            # Start service script
├── stop.sh             # Stop service script
├── logs.sh             # View logs script
├── test_gpio.py        # GPIO test utility
├── test_audio.py       # Audio test utility
└── test_system.py      # Complete system test
```

### Code Architecture

The application follows a modular design:

- **Config Class** - Centralized configuration management
- **AudioPlayer Class** - Audio playback handling
- **ButtonHandler Class** - Physical button input processing
- **ResetButtonHandler Class** - Special reset button logic
- **AudioButtonHandler Class** - Audio button management

### Adding New Features

1. **New Relay Functions:**
   ```python
   @app.route('/relay/<int:relay_num>/toggle', methods=['POST'])
   def toggle_relay(relay_num):
       # Implementation
       pass
   ```

2. **Custom Button Actions:**
   ```python
   class CustomButtonHandler(ButtonHandler):
       def _poll_button(self):
           # Custom polling logic
           pass
   ```

3. **API Extensions:**
   ```python
   @app.route('/api/v1/relays', methods=['GET'])
   def get_all_relays():
       return jsonify(get_relay_states())
   ```

### Testing

Run the test suite:

```bash
# Complete system test
sudo python3 test_system.py

# Unit tests (if implemented)
python -m pytest tests/

# Manual API testing
curl -X POST http://localhost:5000/relay/1
```

### Performance Monitoring

Monitor system performance:

```bash
# CPU usage
top -u $USER

# Memory usage
free -h

# GPIO pin states
gpio readall

# Process information
ps aux | grep python
```

---

## Safety Considerations

⚠️ **WARNING: Mains Voltage Safety**

When using relays to control mains voltage (110V/220V AC):

1. **Use Proper Insulation** - Ensure all high-voltage connections are properly insulated
2. **Never Work Live** - Always disconnect power before making connections
3. **Use Rated Components** - Ensure relays are rated for your voltage and current
4. **Follow Local Codes** - Comply with electrical regulations in your area
5. **Consider Isolation** - Use optically isolated relay modules for safety
6. **Add Protection** - Include fuses or circuit breakers in your design

### GPIO Protection

Protect your Raspberry Pi:

1. **Use Current Limiting Resistors** - Add 220Ω-1kΩ resistors in series with inputs
2. **Voltage Limits** - Never exceed 3.3V on GPIO pins
3. **Avoid Static** - Use anti-static precautions when handling
4. **Power Supply** - Use adequate power supply for Pi and relays

---

## Performance Optimization

### System Tuning

1. **Reduce Poll Interval** for faster button response:
   ```json
   {
       "poll_interval": 0.005  // 5ms instead of 10ms
   }
   ```

2. **Adjust Concurrent Triggers** based on power supply:
   ```json
   {
       "max_concurrent_triggers": 5  // If power supply allows
   }
   ```

3. **Optimize Logging**:
   ```json
   {
       "log_level": "WARNING"  // Reduce to essential logs only
   }
   ```

### Resource Usage

Monitor and optimize:

```bash
# Check CPU temperature
vcgencmd measure_temp

# Monitor CPU frequency
watch -n 1 vcgencmd measure_clock arm

# Check throttling
vcgencmd get_throttled
```

---

## Backup and Recovery

### Configuration Backup

```bash
# Backup configuration
cp config.json config_backup_$(date +%Y%m%d_%H%M%S).json

# Backup entire project
tar -czf 8relay_backup_$(date +%Y%m%d).tar.gz ~/Eight-Relay-Controller/

# Backup to external drive
rsync -av ~/Eight-Relay-Controller/ /media/usb/8relay_backup/
```

### System Recovery

If the system fails:

1. **Restore from backup:**
   ```bash
   # Stop service
   sudo systemctl stop relay-control
   
   # Restore files
   tar -xzf 8relay_backup_20250130.tar.gz -C /
   
   # Restart service
   sudo systemctl start relay-control
   ```

2. **Reset to defaults:**
   ```bash
   # Remove config
   rm config.json
   
   # Restart (will create default config)
   sudo systemctl restart relay-control
   ```

3. **Complete reinstall:**
   ```bash
   cd ~/Eight-Relay-Controller
   sudo bash setup.sh
   ```

---

## Monitoring and Alerts

### System Monitoring

1. **Using systemd:**
   ```bash
   # Check service status
   systemctl status relay-control
   
   # View recent logs
   journalctl -u relay-control --since "1 hour ago"
   ```

2. **Custom monitoring script:**
   ```bash
   #!/bin/bash
   # monitor.sh
   
   SERVICE="relay-control"
   
   if systemctl is-active --quiet $SERVICE; then
       echo "$SERVICE is running"
   else
       echo "$SERVICE is down!"
       # Send alert (email, push notification, etc.)
   fi
   ```

3. **Health endpoint monitoring:**
   ```bash
   # Check health every 5 minutes
   */5 * * * * curl -f http://localhost:5000/health || echo "Relay system down" | mail -s "Alert" admin@example.com
   ```

### Performance Metrics

Track system performance:

```python
# Add to app.py for metrics collection
@app.route('/metrics')
def metrics():
    return jsonify({
        'uptime_seconds': (datetime.now() - stats['start_time']).total_seconds(),
        'total_requests': stats['total_triggers'],
        'error_rate': stats['errors'] / max(stats['total_triggers'], 1),
        'active_relays': len(active_triggers),
        'cpu_temp': get_cpu_temperature(),
        'memory_usage': get_memory_usage()
    })
```

---

## Integration Examples

### Home Assistant Integration

```yaml
# configuration.yaml
switch:
  - platform: rest
    name: Living Room Light
    resource: http://192.168.1.100:5000/relay/1
    method: POST
    is_on_template: "{{ value_json.state == 'ON' }}"
    
  - platform: rest
    name: Garden Sprinkler
    resource: http://192.168.1.100:5000/relay/5
    method: POST
```

### Node-RED Integration

```json
{
    "id": "relay_control",
    "type": "http request",
    "method": "POST",
    "url": "http://192.168.1.100:5000/relay/1",
    "name": "Trigger Relay 1"
}
```

### Python Script Integration

```python
import requests
import time

# Control relays from Python
def control_relay(relay_num, pi_ip="192.168.1.100"):
    response = requests.post(f"http://{pi_ip}:5000/relay/{relay_num}")
    return response.json()

# Example: Turn on lights at sunset
def sunset_automation():
    # Trigger outdoor lights
    control_relay(7)  # Security light
    time.sleep(2)
    control_relay(1)  # Front porch
```

### Shell Script Automation

```bash
#!/bin/bash
# relay_control.sh

PI_IP="192.168.1.100"

relay_on() {
    curl -X POST "http://${PI_IP}:5000/relay/$1"
}

# Morning routine
morning_routine() {
    relay_on 2  # Kitchen lights
    sleep 5
    relay_on 6  # Coffee maker
}

# Usage: ./relay_control.sh morning_routine
$1
```

### MQTT Bridge

```python
# mqtt_bridge.py
import paho.mqtt.client as mqtt
import requests

def on_message(client, userdata, message):
    topic = message.topic
    payload = message.payload.decode()
    
    if topic.startswith("home/relay/"):
        relay_num = topic.split("/")[-1]
        if payload == "ON":
            requests.post(f"http://localhost:5000/relay/{relay_num}")

client = mqtt.Client()
client.on_message = on_message
client.connect("mqtt_broker_ip", 1883)
client.subscribe("home/relay/+")
client.loop_forever()
```

---

## Frequently Asked Questions

### General Questions

**Q: Can I use this with a 16-channel relay module?**
A: The current version supports 8 channels, but you can modify the code to add more relays by updating the configuration and GPIO assignments.

**Q: What's the maximum trigger duration I can set?**
A: There's no hard limit, but be mindful of relay coil heating for extended activations. The practical limit is 3600 seconds (1 hour).

**Q: Can I control the relays remotely over the internet?**
A: Yes, with proper port forwarding or VPN setup. See the Remote Access section for details.

**Q: Does this work with Raspberry Pi Zero W?**
A: Yes, it works with all Raspberry Pi models that have GPIO headers.

### Technical Questions

**Q: Why do some relays activate when the Pi boots?**
A: GPIO pins may float during boot. The active-low relay configuration helps minimize this. You can add pull-up resistors for more control.

**Q: Can I use 12V or 24V relays?**
A: Yes, but you'll need appropriate relay modules and separate power supplies. The GPIO only provides 3.3V signals.

**Q: How do I add password protection?**
A: You can add Flask-Login for authentication or use Nginx basic auth:
```nginx
location / {
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://127.0.0.1:5000;
}
```

**Q: Can I schedule relay activations?**
A: Not built-in, but you can use cron jobs or integrate with Home Assistant for scheduling.

### Troubleshooting Questions

**Q: Why does my relay click but not switch?**
A: Check if your relay module needs separate power for the relay coils (JD-VCC jumper).

**Q: Audio plays but I can't hear it?**
A: Check audio output routing with `sudo amixer cset numid=3 1` for 3.5mm jack.

**Q: Buttons work intermittently?**
A: Increase debounce time in configuration or check for loose connections.

---

## License

This project is licensed under the MIT License:

```
MIT License

Copyright (c) 2024 Seth Morrow

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Acknowledgments

- **Raspberry Pi Foundation** - For creating an amazing platform
- **Flask Community** - For the excellent web framework
- **RPi.GPIO Contributors** - For reliable GPIO control
- **Open Source Community** - For inspiration and support

---

## Quick Reference Card

### Essential Commands

```bash
# Service Control
./start.sh                          # Start service
./stop.sh                           # Stop service
./logs.sh                           # View logs
sudo systemctl restart relay-control # Restart service

# Testing
sudo python3 test_gpio.py           # Test relays
python3 test_audio.py               # Test audio
sudo python3 test_system.py         # Full system test

# Configuration
nano config.json                    # Edit configuration
sudo systemctl restart relay-control # Apply changes

# Troubleshooting
sudo journalctl -u relay-control -f # Live logs
gpio readall                        # Check GPIO states
sudo systemctl status relay-control # Service status
```

### Default Pin Assignments

| Function | GPIO | Physical Pin |
|----------|------|--------------|
| Relay 1-8 | 17,18,27,22,23,24,25,4 | Various |
| Button 1-8 | 26,5,6,12,20,21,7,8 | Various |
| Reset | 16 | Pin 36 |
| Audio 1-7 | 13,19,9,10,11,2,3 | Various |

### Web Endpoints

- Main Interface: `http://[PI-IP]:5000/`
- Admin Panel: `http://[PI-IP]:5000/admin`
- API Status: `http://[PI-IP]:5000/status`
- Health Check: `http://[PI-IP]:5000/health`

---

**Thank you for using the 8-Relay Control System!**

*Built with ❤️ by Seth Morrow for the Raspberry Pi community*
