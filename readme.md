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
