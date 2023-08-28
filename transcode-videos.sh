#!/bin/bash

total_files_processed=0  # Initializing a counter for processed files

use_time_format=false

determine_destination() {
    current_dir_name="${PWD##*/}"
    dest="${PWD%/*}/${current_dir_name} - Processed"
    mkdir -p "$dest"
}

get_new_file_name() {
    local input_file="$1"
    # Get the MediaCreateDate and convert it to the desired format
    media_create_date=$(exiftool -s -s -s -MediaCreateDate "$input_file")
    formatted_time=$(date -d "$media_create_date" +'%Y%m%d%H%M%S')
    echo "${formatted_time}.mov"
}

processed_name() {
    local input_file="$1"
    if [[ "$input_file" == *.360 ]]; then
        echo "$input_file"
    else
        echo "${input_file%.*}.mov"
    fi
}

prompt_user() {
    echo ""
    echo ""
    echo "This routine will process a directory and all sub-directories, looking for MP4 files, TS files and GoPro 360 files."
    echo "The MP4 files and TS files will be transcoded into a .mov file format using a lossy process. This is both fast and efficient"
    echo ""
    echo "The 360 files you have the following options:"
    echo "1. Copy only (will copy the .360 file into the Processed directory, this is fastest but least compatible with Linux video editors)"
    echo "2. Remap & Transcode only (will transcode the 360 file into a .mov and map the file so it is a flat image, this can be opened and used in Linux video editors)."
    echo "3. Copy and Transcode (performs both of the above procedures so both files appear in the folder structure)."
    echo ""
    echo "Please select one of the above choices:"
    read -r action

    # If the action is 2 (transcode) or 3 (both), then prompt for preset
    if [ "$action" -eq 2 ] || [ "$action" -eq 3 ]; then
        echo ""
        echo "When remapping and transcoding 360 files, you may select the following h264 presets:"
        echo ""
        echo "1. Ultra Fast"
        echo "2. Very Fast"
        echo "3. Medium"
        echo "4. Slow"
        echo ""
        echo "Please select one of the above choices:"
        read -r preset_choice

        # Based on the user's choice, set the preset variable accordingly
        case $preset_choice in
            1)
                preset="ultrafast"
                ;;
            2)
                preset="veryfast"
                ;;
            3)
                preset="medium"
                ;;
            4)
                preset="slow"
                ;;
            *)
                echo "Invalid choice. Defaulting to 'medium' preset."
                preset="medium"
                ;;
        esac
    fi
    
    #prompt the user if they would like to keep the original filenames or if they want to change to a date / time format based on GPS data.
    echo "Would you like to keep the original file names or change them to a new time-based format?"
    echo "1. Keep original names"
    echo "2. Change to time-based format"
    read -r name_choice
    case $name_choice in
        1)
            use_time_format=false
            ;;
        2)
            use_time_format=true
            ;;
        *)
            echo "Invalid choice. Keeping original names."
            use_time_format=false
            ;;
    esac
}

process_360_recursive() {
    #this function searches for 360 files to process
    local src="$1"
    local dest="$2"
    
    # Check and create destination directory if it doesn't exist
    [[ ! -d "$dest" ]] && mkdir -p "$dest"
    
    # Handle .360 files in the current directory
    process_360 "$src" "$dest"

    # Recursively handle subdirectories
    for subdir in "$src"/*/; do
        if [[ -d "$subdir" ]]; then
            # Compute the destination directory for this subdir
            local subdest="${dest}/${subdir#$src}"
            
            # Check and create subdestination directory if it doesn't exist
            [[ ! -d "$subdest" ]] && mkdir -p "$subdest"
            
            process_360_recursive "$subdir" "$subdest"
        fi
    done
}

process_360() {
    local src="$1"
    local dest="$2"

    pushd "$src" > /dev/null || return

    shopt -s nullglob

    files=(*.360)
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No .360 files found in $src."
    else
        echo "${#files[@]} .360 files found in $src."
        for file in *.360; do
            echo "Processing: $file"
            if [[ $action -eq 1 || $action -eq 3 ]]; then
                cp "$file" "$dest"
            fi
            if [[ $action -eq 2 || $action -eq 3 ]]; then
                media_create_date=$(exiftool -s -s -s -MediaCreateDate "$file")
                if [ -n "$media_create_date" ]; then
                    formatted_date=$(echo "$media_create_date" | awk -F'[: ]' '{print $1"y-"$2"m-"$3"d-"$4"h-"$5"m-"$6"s"}')
                else
                    modified_date=$(exiftool -s -s -s -"FileModifyDate" "$file")
                    if [ -n "$modified_date" ]; then
                        formatted_date=$(echo "$modified_date" | awk -F'[: ]' '{print $1"y-"$2"m-"$3"d-"$4"h-"$5"m-"$6"s"}')
                    else
                        echo "Both MediaCreateDate and FileModifyDate are not available. Using original filename."
                        formatted_date=""
                    fi
                fi
                original_filename_noext="${file%.*}"

                # If formatted_date is empty, use the original filename; otherwise, prepend it
                if [ -z "$formatted_date" ]; then
                    output_file="${original_filename_noext}.mov"
                else
                    output_file="${formatted_date}_${original_filename_noext}.mov"
                fi
                
                echo "Filename should be " $output_file
                
                ffmpeg_process360 "$file" "$dest" "$preset" "$output_file"
                exif_process "${dest}/${output_file}"
            fi
            ((total_files_processed++))
        done
    fi

    popd > /dev/null
}



ffmpeg_process360() {
    #this function reads a GoPro 360 file and remaps using ffmpeg so that it displays correctly on most video players.
    local input_file="$1"
    local destination="$2"
    local preset="$3"  # Preset parameter
    local output_file="$4"  # New parameter for the output file name

    # Check if the output file already exists
    if [[ -f "${destination}/${output_file}" ]]; then
        echo "${destination}/${output_file} already exists. Skipping..."
        return
    fi
    # Place your FFmpeg command here to do the actual processing.

##############################    
    # Use ffprobe to get stream information, looking only for video streams
    stream_info=$(ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$input_file")

    # Initialize variables to store stream indices
    local first_stream=""
    local second_stream=""

    # Loop through each line in stream_info to find the indices of the video streams
    while IFS= read -r line; do
        line=${line%,}  # Remove any trailing commas
        if [ -z "$first_stream" ]; then
            first_stream="$line"
        elif [ -z "$second_stream" ]; then
            second_stream="$line"
        else
            break
        fi
    done <<< "$stream_info"

    # Print the indices for debugging
    echo "First video stream: $first_stream"
    echo "Second video stream: $second_stream"

    # Return the indices
    echo "$first_stream-$second_stream"

################################################    
    
    div=65
    
    echo "Filename will be " $output_file
    
    # Your ffmpeg command here with the preset substitution
    ffmpeg -loglevel verbose -i "$input_file" -y -filter_complex "
    
    [0:$first_stream]crop=128:1344:x=624:y=0,format=yuvj420p,
    geq=
    lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    interpolation=b,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[crop],
    [0:$first_stream]crop=624:1344:x=0:y=0,format=yuvj420p[left], 
    [0:$first_stream]crop=624:1344:x=752:y=0,format=yuvj420p[right], 
    [left][crop]hstack[leftAll], 
    [leftAll][right]hstack[leftDone],

    [0:$first_stream]crop=1344:1344:1376:0[middle],

    [0:$first_stream]crop=128:1344:x=3344:y=0,format=yuvj420p,
    geq=
    lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    interpolation=b,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[cropRightBottom],
    [0:$first_stream]crop=624:1344:x=2720:y=0,format=yuvj420p[leftRightBottom], 
    [0:$first_stream]crop=624:1344:x=3472:y=0,format=yuvj420p[rightRightBottom], 
    [leftRightBottom][cropRightBottom]hstack[rightAll], 
    [rightAll][rightRightBottom]hstack[rightBottomDone],
    [leftDone][middle]hstack[leftMiddle],
    [leftMiddle][rightBottomDone]hstack[bottomComplete],

    [0:$second_stream]crop=128:1344:x=624:y=0,format=yuvj420p,
    geq=
    lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    interpolation=n,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[leftTopCrop],
    [0:$second_stream]crop=624:1344:x=0:y=0,format=yuvj420p[firstLeftTop], 
    [0:$second_stream]crop=624:1344:x=752:y=0,format=yuvj420p[firstRightTop], 
    [firstLeftTop][leftTopCrop]hstack[topLeftHalf], 
    [topLeftHalf][firstRightTop]hstack[topLeftDone],

    [0:$second_stream]crop=1344:1344:1376:0[TopMiddle],

    [0:$second_stream]crop=128:1344:x=3344:y=0,format=yuvj420p,
    geq=
    lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/"$div"))+(p(X,Y)*(("$div"-((X+1)))/"$div")), p(X,Y))':
    interpolation=n,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[TopcropRightBottom],
    [0:$second_stream]crop=624:1344:x=2720:y=0,format=yuvj420p[TopleftRightBottom], 
    [0:$second_stream]crop=624:1344:x=3472:y=0,format=yuvj420p[ToprightRightBottom], 
    [TopleftRightBottom][TopcropRightBottom]hstack[ToprightAll], 
    [ToprightAll][ToprightRightBottom]hstack[ToprightBottomDone],
    [topLeftDone][TopMiddle]hstack[TopleftMiddle],
    [TopleftMiddle][ToprightBottomDone]hstack[topComplete],

    [bottomComplete]crop=in_w:in_h-1:0:0[bottomCropped],
    [topComplete]crop=in_w:in_h-1:0:0[topCropped],
    [bottomCropped][topCropped]vstack[complete], 
    [complete]v360=eac:e:interp=cubic[v]" \
    -map "[v]" -map "0:a:0" -c:v libx264 -preset "$preset" -crf 23 -pix_fmt yuv420p -c:a pcm_s16le -strict -2 -f mov "${destination}/$output_file"
}

exif_process() {
    exiftool -api LargeFileSupport=1 -overwrite_original \
    -XMP-GSpherical:Spherical="true" -XMP-GSpherical:Stitched="true" \
    -XMP-GSpherical:StitchingSoftware=dummy \
    -XMP-GSpherical:ProjectionType=equirectangular \
    "$(processed_name "$1")"
}



transcode_mp4() {
    local dir="$1"
    local dest="$2"
    local file
    local input_file
    local original_file_name
    local output_file
    local formatted_time

    # Ensure the destination directory exists
    mkdir -p "$dest"
    echo "Debug: Destination directory set to $dest"

    shopt -s nullglob
    for file in "${dir}"/*.[Mm][Pp]4 "${dir}"/*.[Tt][Ss]; do
        input_file="$file"
        echo "Debug: Processing file $input_file"

        # Get original file name (without extension)
        original_file_name=$(basename -- "$input_file")
        original_file_name="${original_file_name%.*}"
        echo "Debug: Original file name is $original_file_name"

        if [[ "$use_time_format" == "false" ]]; then
            # Use the original filename
            output_file="${dest}/${original_file_name}.mov"
            echo "Debug: Using original filename, output_file set to $output_file"
        else
            # Get the MediaCreateDate and convert it to the desired format
            media_create_date=$(exiftool -s -s -s -MediaCreateDate "$input_file")
            echo "Debug: Media Created on $media_create_date"

            # Replace first 2 colons with dashes and keep the rest intact
            formatted_date_string=$(echo $media_create_date | sed 's/\:/-/;s/\:/-/')

            # Convert to date components
            IFS="- :"; read -ra DATE_PARTS <<< "$formatted_date_string"

            # Construct filename
            formatted_time="${DATE_PARTS[0]}y-${DATE_PARTS[1]}m-${DATE_PARTS[2]}d-${DATE_PARTS[3]}h-${DATE_PARTS[4]}m-${DATE_PARTS[5]}s_${original_file_name}.mov"

            echo "Debug: Formatted time is $formatted_time"

            output_file="${dest}/${formatted_time}"
            echo "Debug: Using time-based filename, output_file set to $output_file"
        fi

        # Check if the output file already exists
        if [[ -f "$output_file" ]]; then
            echo "$output_file already exists. Skipping..."
            continue
        fi

        # Place your FFmpeg command here
        ffmpeg -i "$input_file" -c:v copy -c:a pcm_s16le -strict experimental "$output_file"
    done

    shopt -u nullglob
}

prompt_user
determine_destination

process_360_recursive "$(pwd)" "$dest"  # First process the .360 files recursively
transcode_mp4 "$(pwd)" "$dest"  # Then transcode the MP4 files in the main directory

echo "Total files processed: $total_files_processed"  # Print the total number of processed files

