#!/bin/bash

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

    div=65
    
    echo "Filename will be $output_file"
    
    if [ -n "$hwaccel" ]; then
        if ! ffmpeg -loglevel verbose -y -hwaccel $hwaccel -i "$input_file" -filter_complex "
        [0:$first_stream]crop=128:1344:x=624:y=0,format=yuvj420p,
        geq=lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        interpolation=b,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[crop],
        [0:$first_stream]crop=624:1344:x=0:y=0,format=yuvj420p[left], 
        [0:$first_stream]crop=624:1344:x=752:y=0,format=yuvj420p[right], 
        [left][crop]hstack[leftAll], 
        [leftAll][right]hstack[leftDone],
        [0:$first_stream]crop=1344:1344:1376:0[middle],
        [0:$first_stream]crop=128:1344:x=3344:y=0,format=yuvj420p,
        geq=lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        interpolation=b,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[cropRightBottom],
        [0:$first_stream]crop=624:1344:x=2720:y=0,format=yuvj420p[leftRightBottom], 
        [0:$first_stream]crop=624:1344:x=3472:y=0,format=yuvj420p[rightRightBottom], 
        [leftRightBottom][cropRightBottom]hstack[rightAll], 
        [rightAll][rightRightBottom]hstack[rightBottomDone],
        [leftDone][middle]hstack[leftMiddle],
        [leftMiddle][rightBottomDone]hstack[bottomComplete],
        [0:$second_stream]crop=128:1344:x=624:y=0,format=yuvj420p,
        geq=lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        interpolation=n,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[leftTopCrop],
        [0:$second_stream]crop=624:1344:x=0:y=0,format=yuvj420p[firstLeftTop], 
        [0:$second_stream]crop=624:1344:x=752:y=0,format=yuvj420p[firstRightTop], 
        [firstLeftTop][leftTopCrop]hstack[topLeftHalf], 
        [topLeftHalf][firstRightTop]hstack[topLeftDone],
        [0:$second_stream]crop=1344:1344:1376:0[TopMiddle],
        [0:$second_stream]crop=128:1344:x=3344:y=0,format=yuvj420p,
        geq=lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/$div))+(p(X,Y)*(($div-((X+1)))/$div)), p(X,Y))':
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

        if [ -n "$hwaccel" ]; then
            if ! ffmpeg -loglevel verbose -y -hwaccel $hwaccel -i "$input_file" -c:v $encoder -c:a pcm_s16le -strict experimental "$output_file"; then
                fallback_to_cpu
                ffmpeg -loglevel verbose -y -i "$input_file" -c:v libx264 -c:a pcm_s16le -threads "$num_cores" -strict experimental "$output_file"
            fi
        else
            if [ -n "$num_cores" ]; then
                ffmpeg -loglevel verbose -y -i "$input_file" -c:v copy -c:a pcm_s16le -threads "$num_cores" -strict experimental "$output_file"
            else
                ffmpeg -loglevel verbose -y -i "$input_file" -c:v copy -c:a pcm_s16le -strict experimental "$output_file"
            fi
        fi

        touch -r "$input_file" "$output_file"
        increment_media_counter
    done

    shopt -u nullglob
}