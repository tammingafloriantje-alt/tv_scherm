#!/bin/bash

REMOTE="onedrive:Hollandplant onedrive/Fotomateriaal/Fotos Hollandplant/Scherm"
LOCAL="/home/pi/videos"

export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority
PLAYLIST="/home/pi/playlist.m3u"

echo "$(date '+%H:%M:%S')"


# Pushover melding
curl -s \
  --form-string "token=abqnbzxtpf26gcbznvewn9p12wmv7o" \
  --form-string "user=utwc5pwgfvxk9qtmqrnzkghi95bxoo" \
  --form-string "message=Filmpje is gestart" \
  https://api.pushover.net/1/messages.json


while true
do
    echo "Download poging..."
    /usr/bin/rclone sync "$REMOTE" "$LOCAL" && break
    echo "Mislukt, opnieuw proberen over 60 sec..."
    sleep 60
done

echo "Download gelukt!"

rm -f "$PLAYLIST"

find "$LOCAL" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.m4v" \) | sort > "$PLAYLIST"

if [ ! -s "$PLAYLIST" ]; then
    echo "Geen video's gevonden!"
    exit 1
fi

pkill vlc 2>/dev/null
pkill mpv 2>/dev/null

/usr/bin/xset s off
/usr/bin/xset -dpms 
/usr/bin/xset s noblank

nohup /usr/bin/vlc \
    --fullscreen \
    --avcodec-hw=any \
    --playlist-autostart \
    --loop \
    --no-osd \
    --skip-frames \
    --drop-late-frames \
    --no-video-title-show \
    --quiet \
    --file-caching=3000 \
    --no-audio \
    "$PLAYLIST" >/dev/null 2>&1 &