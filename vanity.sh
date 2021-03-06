gource --seconds-per-day 1 --max-file-lag 0.5 --camera-mode overview \
       --disable-bloom --hide filenames \
       --auto-skip-seconds 0.5 --key --title "NDP" -o - \
| \
ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 -preset veryslow \
       -pix_fmt yuv420p -crf 23 -threads 8 -bf 0 $1
