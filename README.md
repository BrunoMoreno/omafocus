# Omafocus

A Pomodoro timer for the Omarchy bar: pick a focus or break duration from the panel, run a countdown, and get a desktop notification with a chime when time is up.

## Install

```sh
omarchy plugin add https://github.com/BrunoMoreno/pomodus.git --enable
```

## Usage

The bar shows the timer glyph, with the live countdown appended while a session is running. Click it to open the control panel.

- **Left-click** toggles the panel.
- **Right-click** toggles start/pause.
- **Middle-click** resets the timer.

In the panel you can pick a mode (Focus, Short break, Long break), start, pause, restart or reset the timer, adjust the three durations, and toggle the finish chime. When a session ends you get a desktop notification and a sound.

## Configure

Move the widget to another bar section:

```sh
omarchy bar move omafocus --section right
```

Durations, default mode and the chime toggle are edited in the panel and persist in your `shell.json`, so they survive a shell restart.

## Remove

```sh
omarchy plugin remove omafocus
```