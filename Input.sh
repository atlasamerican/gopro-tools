#!/bin/bash

determine_input_folder() {
    current_input_folder="$PWD"
    echo "Current working folder: $current_input_folder"
    echo "Would you like to use this folder or specify another one?"
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
        echo "No files found in the specified folder."
        echo "Would you like to specify another folder or quit?"
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