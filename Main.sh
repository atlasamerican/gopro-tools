#!/bin/bash

source ./Input.sh
source ./Processing.sh
source ./Output.sh

# Function to generate processed file name
processed_name() {
    local input_file="$1"
    echo "${input_file%.*}.mov"
}

use_time_format=false
overwrite_files=false
hwaccel=""
encoder=""
num_cores=""
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
dest="${parent_dir}/${current_dir_name} - Processed"

input_folder=""

# Trap for CTRL+C (SIGINT)
trap 'cleanup' SIGINT

cleanup() {
    echo "CTRL+C detected! Cleaning up..."
    # Remove temporary status directory
    rm -rf "$status_temp_dir"
    exit 1
}

select_hardware_acceleration() {
    echo ""
    echo "***************************************************"
    echo "Please select the hardware acceleration method:"
    available_hwaccels=$(ffmpeg -hide_banner -hwaccels | tail -n +2 | awk '{print tolower($0)}')
    echo "Detected hardware acceleration options: $available_hwaccels"
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
                hwaccel="cuda"
                encoder="h264_nvenc"
                echo "Using NVIDIA CUDA for hardware acceleration."
            else
                echo "NVIDIA/CUDA not detected. It might fail."
                encoder="h264_nvenc"
            fi
            ;;
        2)
            if echo "$available_hwaccels" | grep -q "amf"; then
                hwaccel="amf"
                encoder="h264_amf"
                echo "Using AMD AMF for hardware acceleration."
            elif echo "$available_hwaccels" | grep -q "vaapi"; then
                hwaccel="vaapi"
                encoder="h264_vaapi"
                echo "Using AMD VAAPI for hardware acceleration."
            else
                echo "AMD/AMF not detected. It might fail."
                encoder="h264_amf"
            fi
            ;;
        3)
            if echo "$available_hwaccels" | grep -q "vaapi"; then
                hwaccel="vaapi"
                encoder="h264_vaapi"
                echo "Using Intel VAAPI for hardware acceleration."
            else
                echo "Intel/VAAPI not detected. It might fail."
                encoder="h264_vaapi"
            fi
            ;;
        4)
            hwaccel=""
            encoder="libx264"
            echo "Using CPU cores for processing."
            echo "Please enter the number of CPU cores to use for processing (default: half of available cores):"
            read -r num_cores
            if [ -z "$num_cores" ]; then
                num_cores=$(( $(nproc) / 2 ))
                echo "Defaulting to $num_cores cores."
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to CPU processing."
            hwaccel=""
            encoder="libx264"
            echo "Using CPU cores for processing."
            num_cores=$(( $(nproc) / 2 ))
            echo "Defaulting to $num_cores cores."
            ;;
    esac
    echo ""
}

prompt_user() {
    determine_input_folder
    
    echo ""
    echo "Current output directory location: $dest"
    echo "Would you like to specify a different destination folder?"
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
            # Default to the already set dest
            ;;
        *)
            echo "Invalid choice. Defaulting to the default output directory."
            ;;
    esac
    
    echo ""
    echo "This routine will process a directory and all sub-directories,"
    echo "looking for MP4 files, TS files, and GoPro 360 files."
    echo "The MP4 files and TS files will be transcoded into a .mov"
    echo "file format using a lossy process. This is both fast and efficient."
    echo ""
    echo "For the 360 files, you have the following options:"
    echo "  1. Copy only"
    echo "     (will copy the .360 file into the Processed directory,"
    echo "      this is fastest but least compatible with Linux video editors)"
    echo "  2. Remap & Transcode only"
    echo "     (will transcode the 360 file into a .mov and map the file"
    echo "      so it is a flat image, this can be opened and used in Linux video editors)"
    echo "  3. Copy and Transcode"
    echo "     (performs both of the above procedures so both files appear in the folder structure)"
    echo ""
    echo "Please select one of the above choices:"
    read -r action

    if [ "$action" -eq 2 ] || [ "$action" -eq 3 ]; then
        echo ""
        echo "When remapping and transcoding 360 files, you may select the following h264 presets:"
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

# Main script execution
clear
select_hardware_acceleration
prompt_user

# Run the processes sequentially with the correct destination directory
process_360_recursive "$input_folder" "$dest"
transcode_mp4_recursive "$input_folder" "$dest"

if [[ "$copy_non_media_files" == true ]]; then
    copy_non_media_files_recursive "$input_folder" "$dest"  # Copy non-media files if the option was selected
fi

# Clean up the temporary directory
rm -rf "$status_temp_dir"

echo "Processing completed."