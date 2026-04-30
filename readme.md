# 📺 Raspberry Pi Video Playback System (Hollandplant)

Automatisch systeem voor het tonen van promotiemateriaal op een scherm via een Raspberry Pi. Video’s worden centraal beheerd, geconverteerd en periodiek gesynchroniseerd.

---

## ⚙️ Functionaliteit

- Automatisch afspelen van video’s bij opstart
- Periodiek vernieuwen van content (elke 3 uur)
- Synchronisatie met OneDrive
- Automatisch uitschakelen volgens schema
- Server-side video optimalisatie (1080p)

---

## 🧩 Componenten

| Onderdeel | Functie |
|----------|--------|
| cron | Scheduling (start/stop/shutdown) |
| play_video.sh | Download + afspelen |
| stop_video.sh | Stoppen van video |
| convert_videos.py | Video conversie |

---

## ⏱️ Cronjobs

### 🔐 Sudo crontab (shutdown schema)
'0 18 * * 1-5 /sbin/poweroff'
- 0 12 * * 6 /sbin/poweroff
- 0 6 * * 7 /sbin/poweroff


**Schema:**
- Ma–Vr → 18:00 uit  
- Zaterdag → 12:00 uit  
- Zondag → 06:00 uit  

---

### 👤 User crontab (video beheer)
@reboot /home/pi/play_video.sh >> /home/pi/play_video_cron.log 2>&1
0 */3 * * * /home/pi/stop_video.sh
1 */3 * * * /home/pi/play_video.sh


**Gedrag:**
- Bij opstart → start video
- Elke 3 uur:
  - minuut 0 → stop video
  - minuut 1 → start opnieuw (met nieuwe content)

---

## ▶️ play_video.sh

### Wat doet dit script?

1. Stuurt Pushover notificatie  
2. Synchroniseert video’s via rclone (OneDrive)  
3. Genereert playlist  
4. Zet display instellingen (geen screensaver)  
5. Start VLC fullscreen in loop  

### Belangrijke variabelen
REMOTE="onedrive:Hollandplant onedrive/Fotomateriaal/Fotos Hollandplant/Scherm"
LOCAL="/home/pi/videos"
PLAYLIST="/home/pi/playlist.m3u"


### Kenmerken

- Retry bij mislukte downloads  
- Ondersteunde formaten: `.mp4`, `.mov`, `.m4v`  
- Killt bestaande videoprocessen  
- Geen audio / geen UI  

---

## ⏹️ stop_video.sh
pkill vlc

Wordt gebruikt om playback netjes te resetten.

---

## ☁️ OneDrive structuur

| Locatie | Functie |
|--------|--------|
| OneDrive `Scherm` map | Bron van video’s |
| /home/pi/videos | Lokale opslag |

---

## 🎬 Video conversie (server-side)

Script: `convert_videos.py`

### Doel

Alle video’s geschikt maken voor schermweergave:

- Resolutie: **1920x1080**
- Codec: **H.264**
- Audio: **AAC**
- Correcte aspect ratio
- Padding (zwarte balken) waar nodig

---

### 📁 Mappen
input: ruwe pi filmpjes
output: Scherm


⚠️ Output map wordt eerst geleegd!

---

### 🔧 Werking

| Type video | Actie |
|----------|------|
| Staand | Geschaald naar hoogte 1080 + zwarte balken links/rechts |
| Liggend | Geschaald binnen 1920x1080 + padding |

---

### ▶️ Gebruik
python convert_videos.py <input_map> <output_map>


> Let op: in huidige script zijn paden hardcoded.

---

### 📦 Vereisten

- Python 3
- ffmpeg
- ffprobe

Installatie:
sudo apt install ffmpeg

---

## 🔔 Notificaties

Bij starten van video:

- Pushover notificatie wordt verstuurd
- Handig voor monitoring

---

## 🔗 Dependencies

- rclone → OneDrive sync  
- vlc → video playback  
- ffmpeg → conversie  
- cron → scheduling  

---

## 🔄 Workflow

1. Video’s worden geconverteerd op server  
2. Output wordt naar OneDrive (`Scherm`) geplaatst  
3. Raspberry Pi:
   - synchroniseert bestanden  
   - maakt playlist  
   - speelt af  
4. Elke 3 uur:
   - reset + refresh content  
5. Pi schakelt automatisch uit volgens schema  

---

## ⚠️ Aandachtspunten

- DISPLAY en XAUTHORITY moeten correct staan  
- rclone moet geconfigureerd zijn  
- Internetverbinding vereist  
- Rechten op `/home/pi/videos` controleren  

---

## 🚀 Mogelijke verbeteringen

- Logging uitbreiden  
- Health monitoring / watchdog  
- Remote beheer (webinterface)  
- Automatische power-on oplossing (RTC / smart plug)  

---

## 🌱 Gebruik

Ontworpen voor schermen binnen Hollandplant die automatisch visueel materiaal tonen zonder handmatige interactie.