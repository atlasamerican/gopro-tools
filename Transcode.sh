#!/bin/bash

# **************************************************
# Title: Davinci Resolve On Linux Media Prepper
# **************************************************

# Introduction:
# I have been working on a script to transcode all of my GoPro MP4 files, TS files 
# (from Rearview Camera in vehicle), and of course, GoPro 360 files into .mov files 
# so I can use them in Linux with Davinci Resolve. This script, when run in the top 
# directory, will search all subdirectories for any files that match the criteria 
# and then transcode them into a .mov file. For MP4 files, it isn't actually transcoding 
# the content; it is simply changing the container from .MP4 to .mov so that Davinci Resolve 
# will open them. For the 360 files, it gives an option to transcode and remap, which 
# will make the resulting .mov file usable and flat, with everything mapped to the right location. 
# All of the files are put into a new directory with "- Processed" added to the end, and the 
# original files are left untouched.
#
# If you're interested, you can take a look here for the script:
#
# https://github.com/atlasamerican/gopro-tools/blob/bash-script/transcode-videos
#
# Now... a couple of caveats... I do not take credit for the ffmpeg filter_complex. 
# I only made a small tweak to allow for encoding via h264, resulting in much more 
# reasonable file sizes. The person responsible for the hard work, you can find their code here:
#
# https://github.com/dawonn/gopro-max-video-tools
#
# The second and most significant caveat... I am not a coder. I used ChatGPT to help me create 
# this script. Quite a bit of trial and error. If anyone that is a real coder wants to take it 
# from here and make improvements, have at it. I am already at my limits, and I am sure there 
# are a lot of ways this could be made better.
#
# **************************************************

# Function to generate processed file name
processed_name() {
    local input_file="$1"
    echo "${input_file%.*}.mov"
}

use_time_format=false
overwrite_files=false
hardware_acceleration=""
video_encoder=""
cpu_cores=""
copy_non_media_files=false
custom_destination=false
custom_input=false

media_files_processed=0
files_360_processed=0
media_files_total=0
files_360_total=0

status_temp_dir=$(mktemp -d)

# Get the parent directory of the current working directory
parent_dir="$(dirname "$PWD")"

# Get the current working directory name
current_dir_name="${PWD##*/}"

# Set the default dest to be the parent directory with the current folder name and " - Processed" added to the end
destination="${parent_dir}/${current_dir_name} - Processed"

input_folder=""

# Trap for CTRL+C (SIGINT)
trap 'cleanup' SIGINT

cleanup() {
    echo "CTRL+C detected! Cleaning up..."
    # Remove temporary status directory
    rm -rf "$status_temp_dir"
    exit 1
}

determine_input_folder() {
    current_input_folder="$PWD"
    echo ""
    echo "Current working folder: $current_input_folder"
    echo ""
    echo "Would you like to use this folder or specify another one?"
    echo ""
    echo "  1. Use this folder"
    echo "  2. Specify another folder"
    echo ""
    echo "Please select one of the above choices:"
    read -r input_choice
    case $input_choice in
        1)
            input_folder="$current_input_folder"
            ;;
        2)
            echo "Please enter the folder path to process:"
            read -r custom_input_folder
            input_folder="$custom_input_folder"
            ;;
        *)
            echo "Invalid choice. Defaulting to the current folder."
            input_folder="$current_input_folder"
            ;;
    esac
    search_and_confirm_files
}

search_and_confirm_files() {
    echo ""
    echo "Searching for files in $input_folder..."
    shopt -s nullglob
    files_found=($(find "$input_folder" -type f \( -name "*.mp4" -o -name "*.MP4" -o -name "*.ts" -o -name "*.TS" -o -name "*.mkv" -o -name "*.MKV" -o -name "*.avi" -o -name "*.AVI" -o -name "*.mov" -o -name "*.MOV" -o -name "*.flv" -o -name "*.FLV" -o -name "*.wmv" -o -name "*.WMV" -o -name "*.360" \)))
    
    if [ ${#files_found[@]} -eq 0 ]; then
        echo ""
        echo "No files found in the specified folder."
        echo "Would you like to specify another folder or quit?"
        echo ""
        echo "  1. Specify another folder"
        echo "  2. Quit"
        echo ""
        echo "Please select one of the above choices:"
        read -r folder_choice
        case $folder_choice in
            1)
                determine_input_folder
                ;;
            2)
                exit 0
                ;;
            *)
                echo "Invalid choice. Exiting the script."
                exit 1
                ;;
        esac
    else
        echo "Files found:"
        for file in "${files_found[@]}"; do
            echo "$file"
        done
        
        # Counting total media and 360 files
        media_files_total=$(find "$input_folder" -type f \( -name "*.mp4" -o -name "*.MP4" -o -name "*.ts" -o -name "*.TS" -o -name "*.mkv" -o -name "*.MKV" -o -name "*.avi" -o -name "*.AVI" -o -name "*.mov" -o -name "*.MOV" -o -name "*.flv" -o -name "*.FLV" -o -name "*.wmv" -o -name "*.WMV" \) | wc -l)
        files_360_total=$(find "$input_folder" -type f -name "*.360" | wc -l)
        
        echo ""
        echo "Would you like to continue with this folder, specify another folder, or quit?"
        echo ""
        echo "  1. Continue"
        echo "  2. Specify another folder"
        echo "  3. Quit"
        echo ""
        echo "Please select one of the above choices:"
        read -r continue_choice
        case $continue_choice in
            1)
                ;;
            2)
                determine_input_folder
                ;;
            3)
                exit 0
                ;;
            *)
                echo "Invalid choice. Exiting the script."
                exit 1
                ;;
        esac
    fi
    shopt -u nullglob
}

determine_destination() {
    if [[ "$custom_destination" == true ]]; then
        echo "Please enter the destination folder path:"
        read -r custom_dest
        destination="$custom_dest"
    else
        destination="${input_folder}/Processed"
    fi
    mkdir -p "$destination"
}

prompt_user() {
    determine_input_folder
    
    echo ""
    echo "Current output directory location: $destination"
    echo "Would you like to specify a different destination folder?"
    echo ""
    echo "  1. Yes"
    echo "  2. No"
    echo ""
    echo "Please select one of the above choices:"
    read -r destination_choice
    case $destination_choice in
        1)
            custom_destination=true
            determine_destination
            ;;
        2)
            # Default to the already set destination
            ;;
        *)
            echo "Invalid choice. Defaulting to the default output directory."
            ;;
    esac
    
    echo ""
    echo "This routine will process a directory and all sub-directories, looking for Media files including GoPro 360 files to process."
    echo ""
    echo "There are two options that you may choose from:"
    echo ""
    echo "Option 1: All compatible Media files will be transcoded into a .mov file format using the FFMPEG copy function to change the container"
    echo "          type to .mov and the audio codec with to pcm_s16le format without recompressing the file. This is both fast and efficient but"
    echo "          does not help with 360 files in video editors." 
    echo ""
    echo "Option 2: Will change all compatible Media formats as above but for 360 files it will remap them into an Equirectangular format that"
    echo "          can be used inside of video editors. You will need some sort of plugin (Davinici Resolve KartaVR has kvrReframe360Ultra"  
    echo "          plugin to display the video correctly and allow for reframing of the video.)"
    echo ""
    echo "          Note: This process can be very time consuming as it most likely will need to be performed on the CPU rather than GPU due to the"
    echo "          odd pixel dimensions generated from the remapping process."

    # The below two lines where disabled as I don't believe this option actually does anything different than option 2. 
    #    echo "  3. Copy and Transcode"
    #    echo "     (performs both of the above procedures so both files appear in the folder structure)"


    echo ""
    echo "Please select one of the above choices by typing a 1 or a 2:"
    read -r action

    if [ "$action" -eq 2 ] || [ "$action" -eq 3 ]; then
        echo ""
        echo "When remapping and transcoding 360 files, you may select the following h264 presets:"
        echo ""
        echo "  1. Ultra Fast (low quality, large file size, e.g., 1GB input -> ~800MB output)"
        echo "  2. Very Fast (medium-low quality, medium-large file size, e.g., 1GB input -> ~600MB output)"
        echo "  3. Medium (medium quality, medium file size, e.g., 1GB input -> ~400MB output)"
        echo "  4. Slow (high quality, small file size, e.g., 1GB input -> ~200MB output)"
        echo ""
        echo "Please select one of the above choices:"
        read -r preset_choice

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
    
    echo ""
    echo "Would you like to keep the original file names or change them to a new time-based format?"
    echo ""
    echo "  1. Keep original names"
    echo "  2. Change to time-based format"
    echo "     (this will create a filename using the yyyy-mm-dd-hh-ss_originalname.mov format"
    echo "      with date and time pulled from the GPS data in the file if available)"
    echo "     This allows sorting of files by name to get the sequence of files in the order they were captured."
    echo ""
    echo "Please select one of the above choices:"
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
    
    echo ""
    echo "Would you like to overwrite existing files in the output directory or skip them?"
    echo ""
    echo "  1. Overwrite"
    echo "  2. Skip"
    echo ""
    echo "Please select one of the above choices:"
    read -r overwrite_choice
    case $overwrite_choice in
        1)
            overwrite_files=true
            ;;
        2)
            overwrite_files=false
            ;;
        *)
            echo "Invalid choice. Defaulting to skipping existing files."
            overwrite_files=false
            ;;
    esac

    echo ""
    echo "Would you like to copy non-media files (e.g., text files, images, etc.) to the destination folder?"
    echo "" 
    echo "  1. Yes"
    echo "  2. No"
    echo ""
    echo "Please select one of the above choices:"
    read -r copy_choice
    case $copy_choice in
        1)
            copy_non_media_files=true
            ;;
        2)
            copy_non_media_files=false
            ;;
        *)
            echo "Invalid choice. Defaulting to not copying non-media files."
            copy_non_media_files=false
            ;;
    esac
}

select_hardware_acceleration() {
    echo ""
    echo "***************************************************"
    echo "Please select the hardware acceleration method:"
    echo ""
    available_hwaccels=$(ffmpeg -hide_banner -hwaccels | tail -n +2 | awk '{print tolower($0)}')
    echo "Detected hardware acceleration options:"
    echo ""
    echo  $available_hwaccels
    echo ""
    echo "  1. NVIDIA/CUDA"
    echo "  2. AMD/AMF"
    echo "  3. Intel/VAAPI"
    echo "  4. CPU"
    echo ""
    echo "Please select one of the above choices:"
    read -r hw_choice

    case $hw_choice in
        1)
            if echo "$available_hwaccels" | grep -q "cuda"; then
                hardware_acceleration="cuda"
                video_encoder="h264_nvenc"
                echo "Using NVIDIA CUDA for hardware acceleration."
            else
                echo "NVIDIA/CUDA not detected. It might fail."
                video_encoder="h264_nvenc"
            fi
            ;;
        2)
            if echo "$available_hwaccels" | grep -q "amf"; then
                hardware_acceleration="amf"
                video_encoder="h264_amf"
                echo "Using AMD AMF for hardware acceleration."
            elif echo "$available_hwaccels" | grep -q "vaapi"; then
                hardware_acceleration="vaapi"
                video_encoder="h264_vaapi"
                echo "Using AMD VAAPI for hardware acceleration."
            else
                echo "AMD/AMF not detected. It might fail."
                video_encoder="h264_amf"
            fi
            ;;
        3)
            if echo "$available_hwaccels" | grep -q "vaapi"; then
                hardware_acceleration="vaapi"
                video_encoder="h264_vaapi"
                echo "Using Intel VAAPI for hardware acceleration."
            else
                echo "Intel/VAAPI not detected. It might fail."
                video_encoder="h264_vaapi"
            fi
            ;;
        4)
            hardware_acceleration=""
            video_encoder="libx264"
            echo ""
            echo "Using CPU cores for processing."
            echo ""
            echo "Please enter the number of CPU cores to use for processing (default: half of available cores):"
            read -r cpu_cores
            if [ -z "$cpu_cores" ]; then
                cpu_cores=$(( $(nproc) / 2 ))
                echo "Defaulting to $cpu_cores cores."
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to CPU processing."
            hardware_acceleration=""
            video_encoder="libx264"
            echo "Using CPU cores for processing."
            cpu_cores=$(( $(nproc) / 2 ))
            echo "Defaulting to $cpu_cores cores."
            ;;
    esac
    echo ""
}

fallback_to_cpu() {
    echo ""
    echo "***************************************************"
    echo "The selected hardware acceleration method ($hardware_acceleration) is not recognized or failed."
    echo "Possible reasons:"
    echo "  - Your system does not support the selected hardware acceleration."
    echo "  - The required drivers or libraries are not installed."
    echo "Supported hardware accelerations include: vdpau, cuda, vaapi, qsv, drm, opencl, vulkan."
    echo ""
    echo "Would you like to fall back to CPU encoding?"
    echo "  1. Yes"
    echo "  2. No"
    echo ""
    echo "Please select one of the above choices:"
    read -r fallback_choice

    case $fallback_choice in
        1)
            hardware_acceleration=""
            video_encoder="libx264"
            echo "Using CPU cores for processing."
            echo "Please enter the number of CPU cores to use for processing:"
            read -r cpu_cores
            ;;
        2)
            echo "Exiting the script."
            exit 1
            ;;
        *)
            echo "Invalid choice. Exiting the script."
            exit 1
            ;;
    esac
    echo ""
}

increment_media_counter() {
    media_files_processed=$((media_files_processed + 1))
    echo "$media_files_processed" > "$status_temp_dir/media_processed.txt"
}

increment_360_counter() {
    files_360_processed=$((files_360_processed + 1))
    echo "$files_360_processed" > "$status_temp_dir/360_processed.txt"
}

process_360_recursive() {
    local src="$1"
    local dest="$2"
    
    [[ ! -d "$dest" ]] && mkdir -p "$dest"
    
    process_360 "$src" "$dest"

    for subdir in "$src"/*/; do
        if [[ -d "$subdir" && "$(basename "$subdir")" != "Processed" ]]; then
            local subdest="${dest}/${subdir#$src}"
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

            current_file="$file"
            current_file_size=$(du -h "$file" | cut -f1)

            if [[ $use_time_format == true ]]; then
                media_create_date=$(exiftool -s -s -s -MediaCreateDate "$file")
                # if [ -n "$media_create_date" ]; then
                #     formatted_date=$(date +'%Y-%m-%d-%H-%M-%S')
                # else
                #     modified_date=$(exiftool -s -s -s -"FileModifyDate" "$file")
                #     if [ -n "$modified_date" ]; then
                #         formatted_date=$(date +'%Y-%m-%d-%H-%M-%S')
                #     else
                #         echo "Both MediaCreateDate and FileModifyDate are not available. Using original filename."
                #         formatted_date=""
                #     fi
                # fi
                formatted_date=$(date +'%Y-%m-%d-%H-%M-%S')
            else
                formatted_date=""
            fi

            original_filename_noext="${file%.*}"

            if [ -z "$formatted_date" ]; then
                output_file="${original_filename_noext}.mov"
            else
                output_file="${formatted_date}_${original_filename_noext}.mov"
            fi

            if [[ $action -eq 1 || $action -eq 3 ]]; then
                if [[ -f "${dest}/${output_file}" && "$overwrite_files" == false ]]; then
                    echo "${dest}/${output_file} already exists. Skipping..."
                else
                    cp "$file" "${dest}/${output_file}"
                fi
            fi

            if [[ $action -eq 2 || $action -eq 3 ]]; then
                echo "Filename should be $output_file"
                if ! ffmpeg_process360 "$file" "$dest" "$preset" "$output_file"; then
                    fallback_to_cpu
                    ffmpeg_process360 "$file" "$dest" "$preset" "$output_file"
                fi
                exif_process "${dest}/${output_file}"
            fi
            
            touch -r "$file" "${dest}/${output_file}"

            increment_360_counter
        done
    fi

    popd > /dev/null
}

ffmpeg_process360() {
    local input_file="$1"
    local destination="$2"
    local preset="$3"
    local output_file="$4"

    if [[ -f "${destination}/${output_file}" && "$overwrite_files" == false ]]; then
        echo "${destination}/${output_file} already exists. Skipping..."
        return
    fi

    stream_info=$(ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$input_file")

    local first_stream=""
    local second_stream=""

    while IFS= read -r line; do
        line=${line%,}
        if [ -z "$first_stream" ]; then
            first_stream="$line"
        elif [ -z "$second_stream" ]; then
            second_stream="$line"
        else
            break
        fi
    done <<< "$stream_info"

    echo "First video stream: $first_stream"
    echo "Second video stream: $second_stream"

    div=65
    
    echo "Filename will be $output_file"
    
    if [ -n "$hardware_acceleration" ]; then
        if ! ffmpeg -loglevel verbose -y -hwaccel $hardware_acceleration -i "$input_file" -filter_complex "
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
        -map "[v]" -map "0:a:0" -c:v $video_encoder -preset "$preset" -crf 23 -pix_fmt yuv420p -c:a pcm_s16le -strict -2 -f mov "${destination}/$output_file"; then
            return 1
        fi
    else
        if ! ffmpeg -loglevel verbose -y -i "$input_file" -filter_complex "
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
        -map "[v]" -map "0:a:0" -c:v libx264 -preset "$preset" -crf 23 -pix_fmt yuv420p -c:a pcm_s16le -strict -2 -f mov "${destination}/$output_file"; then
            return 1
        fi
    fi

    touch -r "$input_file" "${destination}/${output_file}"
}

exif_process() {
    exiftool -api LargeFileSupport=1 -overwrite_original \
    -XMP-GSpherical:Spherical="true" -XMP-GSpherical:Stitched="true" \
    -XMP-GSpherical:StitchingSoftware=dummy \
    -XMP-GSpherical:ProjectionType=equirectangular \
    "$(processed_name "$1")"
}

transcode_mp4_recursive() {
    local src="$1"
    local dest="$2"
    
    [[ ! -d "$dest" ]] && mkdir -p "$dest"
    
    transcode_mp4 "$src" "$dest"

    for subdir in "$src"/*/; do
        if [[ -d "$subdir" && "$(basename "$subdir")" != "Processed" ]]; then
            local subdest="${dest}/${subdir#$src}"
            [[ ! -d "$subdest" ]] && mkdir -p "$subdest"
            transcode_mp4_recursive "$subdir" "$subdest"
        fi
    done
}

transcode_mp4() {
    local dir="$1"
    local dest="$2"
    local file
    local input_file
    local original_file_name
    local output_file
    local formatted_time

    mkdir -p "$dest"

    shopt -s nullglob
    for file in "${dir}"/*.{mp4,MP4,ts,TS,mkv,MKV,avi,AVI,mov,MOV,flv,FLV,wmv,WMV}; do

        input_file="$file"

        original_file_name=$(basename -- "$input_file")
        original_file_name="${original_file_name%.*}"

        if [[ "$use_time_format" == "false" ]]; then
            output_file="${dest}/${original_file_name}.mov"
        else
            media_create_date=$(exiftool -s -s -s -MediaCreateDate "$input_file")

            formatted_date_string=$(echo $media_create_date | sed 's/\:/-/;s/\:/-/')
            IFS="- :"; read -ra DATE_PARTS <<< "$formatted_date_string"

            formatted_time="${DATE_PARTS[0]}y-${DATE_PARTS[1]}m-${DATE_PARTS[2]}d-${DATE_PARTS[3]}h-${DATE_PARTS[4]}m-${DATE_PARTS[5]}s_${original_file_name}.mov"

                        output_file="${dest}/${formatted_time}"
        fi

        if [[ -f "$output_file" && "$overwrite_files" == false ]]; then
            echo "$output_file already exists. Skipping..."
            continue
        fi

        current_file="$input_file"
        current_file_size=$(du -h "$input_file" | cut -f1)

        if [ -n "$hardware_acceleration" ]; then
            if ! ffmpeg -loglevel verbose -y -hwaccel $hardware_acceleration -i "$input_file" -c:v $video_encoder -c:a pcm_s16le -strict experimental "$output_file"; then
                fallback_to_cpu
                ffmpeg -loglevel verbose -y -i "$input_file" -c:v libx264 -c:a pcm_s16le -threads "$cpu_cores" -strict experimental "$output_file"
            fi
        else
            if [ -n "$cpu_cores" ]; then
                ffmpeg -loglevel verbose -y -i "$input_file" -c:v copy -c:a pcm_s16le -threads "$cpu_cores" -strict experimental "$output_file"
            else
                ffmpeg -loglevel verbose -y -i "$input_file" -c:v copy -c:a pcm_s16le -strict experimental "$output_file"
            fi
        fi

        touch -r "$input_file" "$output_file"
        increment_media_counter
    done

    shopt -u nullglob
}

copy_non_media_files_recursive() {
    local src="$1"
    local dest="$2"
    
    [[ ! -d "$dest" ]] && mkdir -p "$dest"
    
    copy_non_media_files "$src" "$dest"

    for subdir in "$src"/*/; do
        if [[ -d "$subdir" && "$(basename "$subdir")" != "Processed" ]]; then
            local subdest="${dest}/${subdir#$src}"
            [[ ! -d "$subdest" ]] && mkdir -p "$subdest"
            copy_non_media_files_recursive "$subdir" "$subdest"
        fi
    done
}

copy_non_media_files() {
    local dir="$1"
    local dest="$2"

    mkdir -p "$dest"

    shopt -s nullglob
    for file in "${dir}"/*.{txt,jpg,jpeg,png,gif,pdf,doc,docx,xls,xlsx,ppt,pptx,html,htm}; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        echo "Copying non-media file: $file to $dest"
        cp "$file" "$dest"
    done

    shopt -u nullglob
}

# Main script execution
clear
select_hardware_acceleration
prompt_user

# Run the processes sequentially with the correct destination directory
process_360_recursive "$input_folder" "$destination"
transcode_mp4_recursive "$input_folder" "$destination"

if [[ "$copy_non_media_files" == true ]]; then
    copy_non_media_files_recursive "$input_folder" "$destination"  # Copy non-media files if the option was selected
fi

# Clean up the temporary directory
rm -rf "$status_temp_dir"

echo "Processing completed."
