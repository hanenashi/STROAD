```html
<h1>STROAD: Internet Radio Stream Recorder for Android via Termux</h1>
<p>STROAD is a Bash script for Termux on Android that records internet radio streams, splits them into chunks, and applies fade-in/out effects. This guide walks you through installing and setting it up on your Android device (tested on a Pixel 8), including Termux widget integration for easy access.</p>

<h2>Prerequisites</h2>
<ul>
    <li><strong>Android Device</strong>: Any modern Android (e.g., Pixel 8 with Android 14/15).</li>
    <li><strong>Termux</strong>: Terminal emulator for Android.</li>
    <li><strong>Termux:Widget</strong>: Optional, for home screen widget access.</li>
    <li><strong>Storage Access</strong>: Granted via <code>termux-setup-storage</code>.</li>
    <li><strong>FFmpeg</strong>: For audio recording and processing.</li>
</ul>

<h2>Installation Steps</h2>

<h3>1. Install Termux</h3>
<ol>
    <li>Download Termux from <a href="https://f-droid.org/packages/com.termux/">F-Droid</a> (Play Store version is outdated).</li>
    <li>Open Termux and update packages:
        <pre><code>pkg update && pkg upgrade</code></pre>
    </li>
</ol>

<h3>2. Install Dependencies</h3>
<p>STROAD needs <code>ffmpeg</code> for audio handling:</p>
<pre><code>pkg install ffmpeg</code></pre>
<ul>
    <li>Expect ~100-200 MB download; confirm with <code>y</code> when prompted.</li>
</ul>
<p>Grant storage access (run once):</p>
<pre><code>termux-setup-storage</code></pre>
<ul>
    <li>If prompted “Do you want to continue? (y/n)”, type <code>y</code>.</li>
</ul>

<h3>3. Create the Script Directory</h3>
<p>STROAD lives in <code>~/.shortcuts/</code> for Termux:Widget compatibility:</p>
<pre><code>mkdir /data/data/com.termux/files/home/.shortcuts</code></pre>

<h3>4. Add the STROAD Script</h3>
<p>Use <code>nano</code> to create and edit the script:</p>
<pre><code>nano /data/data/com.termux/files/home/.shortcuts/STROAD.sh</code></pre>
<p>Paste the following full script into <code>nano</code>:</p>
<pre><code>#!/bin/bash

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
</code></pre>
<p>Save and exit <code>nano</code>:</p>
<ul>
    <li>Press <code>Ctrl + O</code>, then <code>Enter</code> to save.</li>
    <li>Press <code>Ctrl + X</code> to exit.</li>
</ul>

<h3>5. Make the Script Executable</h3>
<p>Set permissions so Termux can run it:</p>
<pre><code>chmod +x /data/data/com.termux/files/home/.shortcuts/STROAD.sh</code></pre>

<h3>6. Test the Script</h3>
<p>Run it manually to verify:</p>
<pre><code>/data/data/com.termux/files/home/.shortcuts/STROAD.sh</code></pre>
<ul>
    <li>Example inputs:
        <ul>
            <li>Stream URL: Press <code>Enter</code> for Jazz24 default.</li>
            <li>Total time: <code>1m</code> (1 minute).</li>
            <li>Chunk length: <code>30s</code> (30 seconds).</li>
            <li>Fade duration: <code>5</code> (5 seconds).</li>
            <li>Prefix: <code>Jazz</code>.</li>
            <li>Save location: Press <code>Enter</code> for default (<code>/sdcard/download/termux</code>).</li>
        </ul>
    </li>
    <li>Check <code>/sdcard/download/termux</code> for files like <code>Jazz_001.mp3</code>.</li>
</ul>

<h3>7. Optional: Set Up Termux:Widget</h3>
<p>For home screen access:</p>
<ol>
    <li>Install Termux:Widget from <a href="https://f-droid.org/packages/com.termux.widget/">F-Droid</a>.</li>
    <li>Add the widget:
        <ul>
            <li>Long-press home screen > “Widgets” > Termux:Widget.</li>
            <li>Select “STROAD” from the list (resizes as needed).</li>
        </ul>
    </li>
    <li>Tap the widget to run the script.</li>
</ol>

<h2>Usage</h2>
<ul>
    <li>Run via command: <code>/data/data/com.termux/files/home/.shortcuts/STROAD.sh</code>.</li>
    <li>Or tap the widget if set up.</li>
    <li>Follow prompts to customize your recording:
        <ul>
            <li>Stream URL: Any valid MP3 stream (defaults to Jazz24).</li>
            <li>Times: Use <code>h</code> (hours), <code>m</code> (minutes), <code>s</code> (seconds), e.g., <code>1h 30m</code>.</li>
            <li>Fade: Seconds for fade-in/out.</li>
            <li>Prefix: Filename prefix for chunks.</li>
            <li>Location: Save path (defaults to <code>/sdcard/download/termux</code>).</li>
        </ul>
    </li>
</ul>
<p>Output files will be named like <code>${CHUNK_PREFIX}_001.mp3</code>, with fades applied.</p>

<h2>Troubleshooting</h2>
<ul>
    <li><strong>FFmpeg Missing</strong>: Reinstall with <code>pkg install ffmpeg</code>.</li>
    <li><strong>Permission Denied</strong>: Check <code>chmod</code> ran correctly (<code>ls -l /data/data/com.termux/files/home/.shortcuts/STROAD.sh</code> should show <code>-rwxr-xr-x</code>).</li>
    <li><strong>No Widget</strong>: Ensure Termux:Widget is installed and <code>STROAD.sh</code> is in <code>~/.shortcuts/</code>.</li>
    <li><strong>Storage Issues</strong>: Rerun <code>termux-setup-storage</code> if files don’t save.</li>
</ul>

<h2>Notes</h2>
<ul>
    <li>Script keeps your device awake during recording (<code>termux-wake-lock</code>).</li>
    <li>Temporary files (<code>temp_stream.mp3</code>, <code>temp_chunk*.mp3</code>) are cleaned up automatically.</li>
    <li>Tested on Pixel 8 with Android 15 and Termux from F-Droid (March 2025).</li>
</ul>

<p>Enjoy recording your streams with STROAD!</p>
