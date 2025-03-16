#!/bin/bash

# Request storage access (run this once manually before using the script)
termux-setup-storage

# Keep device awake
termux-wake-lock

# Function to convert time format to seconds
convert_to_seconds() {
    local input="$1"
    local total=0
    if [[ $input =~ ([0-9]+)h ]]; then total=$((total + ${BASH_REMATCH[1]} * 3600)); fi
    if [[ $input =~ ([0-9]+)m ]]; then total=$((total + ${BASH_REMATCH[1]} * 60)); fi
    if [[ $input =~ ([0-9]+)s ]]; then total=$((total + ${BASH_REMATCH[1]})); fi
    echo $total
}

# Silent mode with defaults
if [[ "$1" == "-s" ]]; then
    STREAM_URL="https://live.amperwave.net/direct/ppm-jazz24mp3-ibc1"
    DURATION=3600  # 1 hour
    CHUNK_LENGTH=600  # 10 minutes
    FADE=5
    CHUNK_PREFIX="SilentChunk"
    OUTPUT_DIR="/sdcard/download/termux"
    CONFIRM="y"
    TIMESTAMP=$(date +"%Y%m%d_%H%M")
else
    # Preset stream selection
    echo "Pick a stream:"
    select STREAM in "Jazz24" "BBC Radio 1" "SomaFM Groove Salad" "Custom"; do
        case $STREAM in
            "Jazz24") STREAM_URL="https://live.amperwave.net/direct/ppm-jazz24mp3-ibc1"; break;;
            "BBC Radio 1") STREAM_URL="http://bbcmedia.ic.llnwd.net/stream/bbcmedia_radio1_mf_p"; break;;
            "SomaFM Groove Salad") STREAM_URL="https://somafm.com/groovesalad256.pls"; break;;
            "Custom") read -p "Enter custom URL: " STREAM_URL; break;;
        esac
    done

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
    CHUNK_PREFIX=${CHUNK_PREFIX:-"Chunk"}

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
    TIMESTAMP=$(date +"%Y%m%d_%H%M")
fi

if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted!"
    termux-wake-unlock
    exit 1
fi

# Calculate total number of chunks (round up)
TOTAL_CHUNKS=$(((DURATION + CHUNK_LENGTH - 1) / CHUNK_LENGTH))

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Progress bar function with chunk info
progress_bar() {
    local duration=$1
    local chunk_length=$2
    local total_chunks=$3
    local elapsed=0
    local bar_length=20
    while [ $elapsed -lt $duration ]; do
        elapsed=$((elapsed + 1))
        percent=$((elapsed * 100 / duration))
        filled=$((elapsed * bar_length / duration))
        empty=$((bar_length - filled))
        current_chunk=$(((elapsed + chunk_length - 1) / chunk_length))
        bar=""
        for i in $(seq 1 $filled); do bar="$bar#"; done
        for i in $(seq 1 $empty); do bar="$bar-"; done
        echo -ne "\rRecording: [$bar] $percent% ($elapsed/$duration s) - Chunk $current_chunk/$total_chunks"
        sleep 1
    done
    echo -ne "\rRecording: [####################] 100% ($duration/$duration s) - Chunk $total_chunks/$total_chunks\n"
}

# Start recording with progress bar
echo "Recording stream for $TOTAL_TIME..."
ffmpeg -loglevel quiet -thread_queue_size 512 -i "$STREAM_URL" -t "$DURATION" -c copy "temp_stream.mp3" &
FFMPEG_PID=$!
progress_bar "$DURATION" "$CHUNK_LENGTH" "$TOTAL_CHUNKS" &
PROGRESS_PID=$!
wait $FFMPEG_PID
kill $PROGRESS_PID 2>/dev/null

# Check if recording succeeded
if [ ! -f "temp_stream.mp3" ]; then
    echo "Recording failed!"
    termux-wake-unlock
    exit 1
fi

# Split into chunks with progress
echo "Splitting into $CHUNK_LENGTH-second chunks..."
ffmpeg -loglevel quiet -i "temp_stream.mp3" -f segment -segment_time "$CHUNK_LENGTH" -c copy "temp_chunk%03d.mp3"

# Apply fade in/out to each chunk with progress
echo "Applying fade effect..."
COUNT=1
for FILE in temp_chunk*.mp3; do
    PADDED_COUNT=$(printf "%03d" $COUNT)
    echo "Processing chunk $COUNT/$TOTAL_CHUNKS: $PADDED_COUNT.mp3"
    ffmpeg -loglevel quiet -i "$FILE" -filter_complex "afade=t=in:ss=0:d=$FADE,areverse,afade=t=in:ss=0:d=$FADE,areverse" -c:a libmp3lame -q:a 2 "$OUTPUT_DIR/${CHUNK_PREFIX}_${TIMESTAMP}_${PADDED_COUNT}.mp3"
    rm -f "$FILE"
    ((COUNT++))
done

# Clean up
rm -f "temp_stream.mp3"
termux-wake-unlock

echo "Done! Chunks saved in $OUTPUT_DIR"
