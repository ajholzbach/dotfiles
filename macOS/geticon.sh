#!/bin/bash

# Check if App ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <APP_ID>"
  exit 1
fi

APP_ID=$1

# Check if required tools are installed
if ! command -v curl &> /dev/null; then
  echo "Error: curl is not installed."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed."
  exit 1
fi

if ! command -v magick &> /dev/null; then
  echo "Error: ImageMagick (magick) is not installed."
  exit 1
fi

if ! command -v iconutil &> /dev/null; then
  echo "Error: iconutil is not installed."
  exit 1
fi

# Fetch app metadata from iTunes API
echo "Fetching app data for App ID: $APP_ID"
response=$(curl -s "https://itunes.apple.com/lookup?id=${APP_ID}")

# Check if the app was found
if [[ $(echo "$response" | jq '.resultCount') -eq 0 ]]; then
  echo "No app found with App ID: $APP_ID"
  exit 1
fi

# Extract the artwork URL (max resolution, usually 512x512 or 1024x1024)
icon_url=$(echo "$response" | jq -r '.results[0].artworkUrl512')

# Check if artworkUrl512 is available
if [ "$icon_url" == "null" ]; then
  echo "No artwork URL found for App ID: $APP_ID"
  exit 1
fi

# Replace 512x512 in URL with 1024x1024 for higher resolution (if available)
icon_url=${icon_url/512x512/1024x1024}

# Extract app name for saving the file
app_name=$(echo "$response" | jq -r '.results[0].trackName' | tr ' ' '_' | tr -cd '[:alnum:]_')

# Download the icon
output_file="${app_name}_icon.png"
echo "Downloading app icon: $output_file"
curl -o "$output_file" "$icon_url"

# Check if the download was successful
if [ $? -eq 0 ]; then
  echo "Download complete. Saved as $output_file."
else
  echo "Failed to download the icon."
  exit 1
fi

# Round the corners of the icon
rounded_output_file="${app_name}_icon_rounded.png"
echo "Rounding corners of the icon: $rounded_output_file"
magick "$output_file" \
  \( +clone -alpha extract -draw 'fill black polygon 0,0 0,200 200,0 fill white circle 200,200 200,0' \
  \( +clone -flip \) -compose Multiply -composite \
  \( +clone -flop \) -compose Multiply -composite \) \
  -alpha off -compose CopyOpacity -composite "$rounded_output_file"

# Resize the icon to fit within a 1024x1024 canvas
resized_output_file="${app_name}_icon_resized.png"
echo "Resizing the icon to fit within 1024x1024: $resized_output_file"
magick "$rounded_output_file" -resize 1024x1024 "$resized_output_file"

# Function to calculate icon size and padding
calculate_icon_size() {
    local canvas_size=$1
    local icon_size=$(echo "scale=0; $canvas_size * 0.8039215686" | bc)
    local padding=$(echo "scale=0; ($canvas_size - $icon_size) / 2" | bc)
    echo "$icon_size $padding"
}

# Create .iconset directory
iconset_dir="${app_name}.iconset"
mkdir "$iconset_dir"

# Generate different sizes for the .iconset
sizes=(16 32 64 128 256 512 1024)
for size in "${sizes[@]}"; do
    read icon_size padding < <(calculate_icon_size $size)

    # Create icon with padding
    magick "$resized_output_file" -resize "${icon_size}x${icon_size}" \
        -background none -gravity center -extent "${size}x${size}" \
        "$iconset_dir/icon_${size}x${size}.png"

    if [ $size -ne 1024 ]; then
        read icon_size_2x padding_2x < <(calculate_icon_size $((size * 2)))

        # Create @2x icon with padding
        magick "$resized_output_file" -resize "${icon_size_2x}x${icon_size_2x}" \
            -background none -gravity center -extent "$((size * 2))x$((size * 2))" \
            "$iconset_dir/icon_${size}x${size}@2x.png"
    fi
done

# Convert the .iconset to .icns
icns_file="${app_name}.icns"
echo "Converting to .icns format: $icns_file"
iconutil -c icns "$iconset_dir"

# Remove the intermediate files
rm "$output_file" "$rounded_output_file" "$resized_output_file"

# Clean up
rm -r "$iconset_dir"
echo "Conversion complete. Saved as $icns_file."
