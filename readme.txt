I have been working on a script to transcode all of my GoPro MP4 files, TS files (from Rearview Camera in vehicle) and of course GoPro 360 files into .mov files so I can use them in Linux with Davinci Resolve. This script when run in the top directory, will search all sub directories for any files that match the criteria and then transcode them into a .mov file. For MP4 files, it isn't actually transcoding the content, it is actually just changing the container from .MP4 to .mov so that Davinici Resolve will open them. For the 360 files, it gives an option to transcode and remap which will make the resulting .mov file usable and flat with everything mapped to the right location. All of the files are put into a new directory with "- Processed" added to the end and the original files are left untouched.

If your interested, you can take a look here for the script.

https://github.com/atlasamerican/gopro-tools/blob/bash-script/transcode-videos

Now... a couple of caveats... I do not take credit for the ffmpeg filter_complex. I only made a small tweak to allow for encoding via h264 resulting in much more reasonable files sizes. The person responsible for the hard work, you can find their code here:

https://github.com/dawonn/gopro-max-video-tools

The second and most significant caveat... I am not a coder. I used ChatGPT to help me create this script. Quite a bit of trial and error. If anyone that is a real coder wants to take it from here and make improvements have at it. I am already at my limits and I am sure there is a lot of ways this could be made better.
