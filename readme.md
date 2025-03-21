# STROAD: Internet Radio Stream Recorder for Android via Termux

STROAD is a Bash script for Termux on Android that records internet radio streams, splits them into chunks, and applies fade-in/out effects. This guide walks you through installing and setting it up on your Android device (tested on a Pixel 8), including Termux widget integration for easy access.

## Prerequisites

*   **Android Device**: Any modern Android (e.g., Pixel 8 with Android 14/15).
*   **Termux**: Terminal emulator for Android.
*   **Termux:Widget**: Optional, for home screen widget access.
*   **Storage Access**: Granted via `termux-setup-storage`.
*   **FFmpeg**: For audio recording and processing.

## Installation Steps

### 1\. Install Termux

1.  Download Termux from [F-Droid](https://f-droid.org/packages/com.termux/) (Play Store version is outdated).
2.  Open Termux and update packages:
    
    ```
    pkg update && pkg upgrade
    ```
    

### 2\. Install Dependencies

STROAD needs `ffmpeg` for audio handling:

```
pkg install ffmpeg
```

*   Expect ~100-200 MB download; confirm with `y` when prompted.

Grant storage access (run once):

```
termux-setup-storage
```

*   If prompted “Do you want to continue? (y/n)”, type `y`.

### 3\. Create the Script Directory

STROAD lives in `~/.shortcuts/` for Termux:Widget compatibility:

```
mkdir /data/data/com.termux/files/home/.shortcuts
```

### 4\. Add the STROAD Script

Use `nano` to create and edit the script:

```
nano /data/data/com.termux/files/home/.shortcuts/STROAD.sh
```

Paste the following full script into `nano`:

```
#!/bin/bash

# Request storage access (run this once manually before using the script)
termux-setup-storage

# Keep device awake
termux-wake-lock

# Function to convert time format to seconds
convert_to_seconds() {
    local input="$1"
    local total=0

    # Extract hours, minutes, and seconds
    if [[ $input =~ ([0-9]+)h ]]; then total=$((total + ${BASH_REMATCH[1]} * 3600)); fi
    if [[ $input =~ ([0-9]+)m ]]; then total=$((total + ${BASH_REMATCH[1]} * 60)); fi
    if [[ $input =~ ([0-9]+)s ]]; then total=$((total + ${BASH_REMATCH[1]})); fi

    echo $total
}

# Ask for stream URL (default: Jazz24)
read -p "Enter stream URL [Default: Jazz24]: " STREAM_URL
STREAM_URL=${STREAM_URL:-"https://live.amperwave.net/direct/ppm-jazz24mp3-ibc1"}

# Ask for total recording time
read -p "Enter total recording time (e.g., 10h 20m 40s): " TOTAL_TIME
DURATION=$(convert_to_seconds "$TOTAL_TIME")

# Ask for chunk length
read -p "Enter chunk length (e.g., 10h 20m 40s): " CHUNK_TIME
CHUNK_LENGTH=$(convert_to_seconds "$CHUNK_TIME")

# Ask for fade duration (seconds only)
read -p "Enter fade-in/out duration (seconds): " FADE

# Ask for chunk filename prefix
read -p "Enter chunk name prefix (e.g., Jazz): " CHUNK_PREFIX
CHUNK_PREFIX=${CHUNK_PREFIX:-"Chunk"}  # Default if left blank

# Ask for saving location (default: /sdcard/download/termux)
read -p "Enter save location [Default: /sdcard/download/termux]: " OUTPUT_DIR
OUTPUT_DIR=${OUTPUT_DIR:-"/sdcard/download/termux"}

# Display summary for confirmation
echo ""
echo "----- Recording Settings -----"
echo " Stream URL:    $STREAM_URL"
echo " Total Time:    $TOTAL_TIME ($DURATION seconds)"
echo " Chunk Time:    $CHUNK_TIME ($CHUNK_LENGTH seconds)"
echo " Fade In/Out:   $FADE seconds"
echo " Chunk Prefix:  $CHUNK_PREFIX"
echo " Save Location: $OUTPUT_DIR"
echo "--------------------------------"

read -p "Confirm settings? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted!"
    termux-wake-unlock
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Start recording
echo "Recording stream for $TOTAL_TIME..."
ffmpeg -thread_queue_size 512 -i "$STREAM_URL" -t "$DURATION" -c copy "temp_stream.mp3"

# Check if recording succeeded
if [ ! -f "temp_stream.mp3" ]; then
    echo "Recording failed!"
    termux-wake-unlock
    exit 1
fi

# Split into chunks
echo "Splitting into $CHUNK_LENGTH-second chunks..."
ffmpeg -i "temp_stream.mp3" -f segment -segment_time "$CHUNK_LENGTH" -c copy "temp_chunk%03d.mp3"

# Apply fade in/out to each chunk
echo "Applying fade effect..."
COUNT=1
for FILE in temp_chunk*.mp3; do
    PADDED_COUNT=$(printf "%03d" $COUNT)
    ffmpeg -i "$FILE" -filter_complex "afade=t=in:ss=0:d=$FADE, areverse, afade=t=in:ss=0:d=$FADE, areverse" -c:a libmp3lame -q:a 2 "$OUTPUT_DIR/${CHUNK_PREFIX}_${PADDED_COUNT}.mp3"
    rm -f "$FILE"
    ((COUNT++))
done

# Clean up
rm -f "temp_stream.mp3"
termux-wake-unlock

echo "Done! Chunks saved in $OUTPUT_DIR"
```

Save and exit `nano`:

*   Press `Ctrl + O`, then `Enter` to save.
*   Press `Ctrl + X` to exit.

### 5\. Make the Script Executable

Set permissions so Termux can run it:

```
chmod +x /data/data/com.termux/files/home/.shortcuts/STROAD.sh
```

### 6\. Test the Script

Run it manually to verify:

```
/data/data/com.termux/files/home/.shortcuts/STROAD.sh
```

*   Example inputs:
    *   Stream URL: Press `Enter` for Jazz24 default.
    *   Total time: `1m` (1 minute).
    *   Chunk length: `30s` (30 seconds).
    *   Fade duration: `5` (5 seconds).
    *   Prefix: `Jazz`.
    *   Save location: Press `Enter` for default (`/sdcard/download/termux`).
*   Check `/sdcard/download/termux` for files like `Jazz_001.mp3`.

### 7\. Optional: Set Up Termux:Widget

For home screen access:

1.  Install Termux:Widget from [F-Droid](https://f-droid.org/packages/com.termux.widget/).
2.  Add the widget:
    *   Long-press home screen > “Widgets” > Termux:Widget.
    *   Select “STROAD” from the list (resizes as needed).
3.  Tap the widget to run the script.

## Usage

*   Run via command: `/data/data/com.termux/files/home/.shortcuts/STROAD.sh`.
*   Or tap the widget if set up.
*   Follow prompts to customize your recording:
    *   Stream URL: Any valid MP3 stream (defaults to Jazz24).
    *   Times: Use `h` (hours), `m` (minutes), `s` (seconds), e.g., `1h 30m`.
    *   Fade: Seconds for fade-in/out.
    *   Prefix: Filename prefix for chunks.
    *   Location: Save path (defaults to `/sdcard/download/termux`).

Output files will be named like `${CHUNK_PREFIX}_001.mp3`, with fades applied.

## Troubleshooting

*   **FFmpeg Missing**: Reinstall with `pkg install ffmpeg`.
*   **Permission Denied**: Check `chmod` ran correctly (`ls -l /data/data/com.termux/files/home/.shortcuts/STROAD.sh` should show `-rwxr-xr-x`).
*   **No Widget**: Ensure Termux:Widget is installed and `STROAD.sh` is in `~/.shortcuts/`.
*   **Storage Issues**: Rerun `termux-setup-storage` if files don’t save.

## Notes

*   Script keeps your device awake during recording (`termux-wake-lock`).
*   Temporary files (`temp_stream.mp3`, `temp_chunk*.mp3`) are cleaned up automatically.
*   Tested on Pixel 8 with Android 15 and Termux from F-Droid (March 2025).

Enjoy recording your streams with STROAD!
