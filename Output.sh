#!/bin/bash

determine_destination() {
    if [[ "$custom_destination" == true ]]; then
        echo "Please enter the destination folder path:"
        read -r custom_dest
        dest="$custom_dest"
    else
        dest="${input_folder}/Processed"
    fi
    mkdir -p "$dest"
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