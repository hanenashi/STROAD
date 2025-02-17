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
