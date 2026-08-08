#!/bin/bash

# ============================================================
# Hollandplant videoscherm
#
# - Wacht 3 minuten na opstarten
# - Beperkt logbestanden tot 1000 regels
# - Bepaalt IP-adres van deze computer
# - Zoekt ClickUp-taak met exact hetzelfde IP-adres als naam
# - Zet de due date van die taak op morgen
# - Synchroniseert videobestanden vanuit OneDrive
# - Maakt playlist
# - Start VLC fullscreen en looping
# ============================================================


# ------------------------------------------------------------
# INSTELLINGEN
# ------------------------------------------------------------

REMOTE="onedrive:Hollandplant onedrive/Fotomateriaal/Fotos Hollandplant/Scherm"
LOCAL="$HOME/videos"
PLAYLIST="$HOME/playlist.m3u"

# ClickUp List:
# https://app.clickup.com/9015254614/v/l/li/901501857040?pr=90150750037
CLICKUP_LIST_ID="901501857040"


CLICKUP_TOKEN_FILE="pk_62455535_M8JYSUXE9W3NO2GD6W0WGGG9K2521E97"


# ------------------------------------------------------------
# FUNCTIE: schrijven naar log/stdout
# ------------------------------------------------------------

log()
{
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}


# ------------------------------------------------------------
# WACHTEN NA OPSTARTEN
# ------------------------------------------------------------

log "Script gestart. 180 seconden wachten..."

#sleep 180


# ------------------------------------------------------------
# LOGBESTANDEN BEPERKEN TOT 1000 REGELS
# ------------------------------------------------------------

log "Logbestanden controleren..."

find "$HOME" -type f -name "*.log" -print0 2>/dev/null |
while IFS= read -r -d '' logfile
do
    if [ -f "$logfile" ]; then

        LINES=$(wc -l < "$logfile" 2>/dev/null)

        if [ -n "$LINES" ] && [ "$LINES" -gt 1000 ]; then

            tail -n 1000 "$logfile" > "${logfile}.tmp"

            if mv "${logfile}.tmp" "$logfile"; then
                log "Ingekort: $logfile ($LINES regels)"
            else
                log "FOUT: kon logbestand niet inkorten: $logfile"
                rm -f "${logfile}.tmp"
            fi

        fi
    fi
done


# ------------------------------------------------------------
# DISPLAY INSTELLINGEN
# ------------------------------------------------------------

export DISPLAY=:0
export XAUTHORITY="$HOME/.Xauthority"


# ------------------------------------------------------------
# IP-ADRES BEPALEN
# ------------------------------------------------------------

IP=$(hostname -I 2>/dev/null | awk '{print $1}')

if [ -z "$IP" ]; then
    log "WAARSCHUWING: geen IP-adres gevonden."
else
    log "IP-adres van dit scherm: $IP"
fi


# ============================================================
# CLICKUP
# ============================================================

update_clickup()
{
    # Geen IP = ClickUp overslaan
    if [ -z "$IP" ]; then
        log "ClickUp overgeslagen omdat geen IP-adres gevonden is."
        return
    fi


    # --------------------------------------------------------
    # CONTROLEREN OF CURL AANWEZIG IS
    # --------------------------------------------------------

    if ! command -v curl >/dev/null 2>&1; then
        log "FOUT: curl is niet geïnstalleerd. ClickUp wordt overgeslagen."
        return
    fi


    # --------------------------------------------------------
    # CONTROLEREN OF JQ AANWEZIG IS
    # --------------------------------------------------------

    if ! command -v jq >/dev/null 2>&1; then
        log "FOUT: jq is niet geïnstalleerd. ClickUp wordt overgeslagen."
        return
    fi


    # --------------------------------------------------------
    # CLICKUP TOKEN LEZEN
    # --------------------------------------------------------

    if [ ! -f "$CLICKUP_TOKEN_FILE" ]; then
        log "FOUT: ClickUp tokenbestand bestaat niet:"
        log "$CLICKUP_TOKEN_FILE"
        return
    fi

    CLICKUP_TOKEN=$(tr -d '\r\n' < "$CLICKUP_TOKEN_FILE")

    if [ -z "$CLICKUP_TOKEN" ]; then
        log "FOUT: ClickUp tokenbestand is leeg."
        return
    fi


    # --------------------------------------------------------
    # TAAK ZOEKEN
    #
    # ClickUp geeft maximaal 100 taken per pagina.
    # Daarom zoeken we pagina voor pagina.
    # --------------------------------------------------------

    log "ClickUp taak zoeken met naam: $IP"

    PAGE=0
    TASK_ID=""
    MATCH_COUNT=0

    while true
    do

        RESPONSE_FILE=$(mktemp)

        HTTP_CODE=$(curl \
            --silent \
            --show-error \
            --connect-timeout 10 \
            --max-time 30 \
            --output "$RESPONSE_FILE" \
            --write-out "%{http_code}" \
            --request GET \
            --url "https://api.clickup.com/api/v2/list/${CLICKUP_LIST_ID}/task?include_closed=true&include_timl=true&page=${PAGE}" \
            --header "Authorization: ${CLICKUP_TOKEN}" \
            --header "Content-Type: application/json")

        CURL_RESULT=$?


        # ----------------------------------------------------
        # CURL FOUT
        # ----------------------------------------------------

        if [ "$CURL_RESULT" -ne 0 ]; then
            log "FOUT: verbinding met ClickUp mislukt."
            rm -f "$RESPONSE_FILE"
            return
        fi


        # ----------------------------------------------------
        # HTTP FOUT
        # ----------------------------------------------------

        if [[ ! "$HTTP_CODE" =~ ^2 ]]; then

            log "FOUT: ClickUp gaf HTTP status $HTTP_CODE"

            if [ -s "$RESPONSE_FILE" ]; then
                log "ClickUp antwoord:"
                cat "$RESPONSE_FILE"
                echo
            fi

            rm -f "$RESPONSE_FILE"
            return
        fi


        # ----------------------------------------------------
        # CONTROLEREN OF ANTWOORD GELDIGE JSON IS
        # ----------------------------------------------------

        if ! jq -e '.tasks | type == "array"' "$RESPONSE_FILE" >/dev/null 2>&1; then

            log "FOUT: onverwacht antwoord ontvangen van ClickUp."

            cat "$RESPONSE_FILE"
            echo

            rm -f "$RESPONSE_FILE"
            return
        fi


        # ----------------------------------------------------
        # AANTAL TAKEN OP DEZE PAGINA
        # ----------------------------------------------------

        TASKS_ON_PAGE=$(jq '.tasks | length' "$RESPONSE_FILE")


        # ----------------------------------------------------
        # EXACT IP-ADRES ZOEKEN
        # ----------------------------------------------------

        PAGE_MATCH_COUNT=$(jq \
            --arg IP "$IP" \
            '[.tasks[] | select(.name == $IP)] | length' \
            "$RESPONSE_FILE")


        if [ "$PAGE_MATCH_COUNT" -gt 0 ]; then

            MATCH_COUNT=$((MATCH_COUNT + PAGE_MATCH_COUNT))

            FOUND_TASK_ID=$(jq -r \
                --arg IP "$IP" \
                '.tasks[] | select(.name == $IP) | .id' \
                "$RESPONSE_FILE" |
                head -n 1)

            if [ -z "$TASK_ID" ]; then
                TASK_ID="$FOUND_TASK_ID"
            fi
        fi


        rm -f "$RESPONSE_FILE"


        # ----------------------------------------------------
        # MINDER DAN 100 TAKEN = LAATSTE PAGINA
        # ----------------------------------------------------

        if [ "$TASKS_ON_PAGE" -lt 100 ]; then
            break
        fi


        PAGE=$((PAGE + 1))


        # Veiligheidslimiet
        if [ "$PAGE" -gt 100 ]; then
            log "FOUT: ClickUp zoekactie afgebroken na 100 pagina's."
            return
        fi

    done


    # --------------------------------------------------------
    # GEEN TAAK GEVONDEN
    # --------------------------------------------------------

if [ -z "$TASK_ID" ]; then

    log "Geen ClickUp taak gevonden met naam: $IP"
    log "Nieuwe ClickUp taak aanmaken..."

    TOMORROW_MS="$(TZ=Europe/Amsterdam date -d 'tomorrow 04:00:00' +%s)000"
    TOMORROW_TEXT="$(TZ=Europe/Amsterdam date -d 'tomorrow' '+%Y-%m-%d')"

    CREATE_RESPONSE=$(mktemp)

    HTTP_CODE=$(curl \
        --silent \
        --show-error \
        --connect-timeout 10 \
        --max-time 30 \
        --output "$CREATE_RESPONSE" \
        --write-out "%{http_code}" \
        --request POST \
        --url "https://api.clickup.com/api/v2/list/${CLICKUP_LIST_ID}/task" \
        --header "Authorization: ${CLICKUP_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "{
            \"name\": \"${IP}\",
            \"due_date\": ${TOMORROW_MS},
            \"due_date_time\": false
        }")

    CURL_RESULT=$?

    if [ "$CURL_RESULT" -ne 0 ]; then
        log "FOUT: verbinding met ClickUp mislukt bij aanmaken taak."
        rm -f "$CREATE_RESPONSE"
        return
    fi

    if [[ "$HTTP_CODE" =~ ^2 ]]; then

        NEW_TASK_ID=$(jq -r '.id // empty' "$CREATE_RESPONSE")

        log "Nieuwe ClickUp taak aangemaakt: $IP"
        log "Due date: $TOMORROW_TEXT"

        if [ -n "$NEW_TASK_ID" ]; then
            log "Task ID: $NEW_TASK_ID"
        fi

    else

        log "FOUT: ClickUp taak aanmaken mislukt. HTTP $HTTP_CODE"

        if [ -s "$CREATE_RESPONSE" ]; then
            cat "$CREATE_RESPONSE"
            echo
        fi

    fi

    rm -f "$CREATE_RESPONSE"

    return
fi

    # --------------------------------------------------------
    # MEERDERE TAKEN MET HETZELFDE IP
    # --------------------------------------------------------

    if [ "$MATCH_COUNT" -gt 1 ]; then
        log "WAARSCHUWING: meerdere ClickUp taken gevonden met naam $IP."
        log "De eerste gevonden taak wordt aangepast."
    fi


    log "ClickUp taak gevonden: $IP"
    log "Task ID: $TASK_ID"


    # --------------------------------------------------------
    # MORGEN BEREKENEN
    #
    # ClickUp gebruikt milliseconden sinds Unix epoch.
    # 04:00 wordt gebruikt voor een datum zonder tijd.
    # --------------------------------------------------------

    TOMORROW_MS="$(TZ=Europe/Amsterdam date -d 'tomorrow 04:00:00' +%s)000"

    TOMORROW_TEXT="$(TZ=Europe/Amsterdam date -d 'tomorrow' '+%Y-%m-%d')"

    log "Nieuwe ClickUp due date: $TOMORROW_TEXT"


    # --------------------------------------------------------
    # CLICKUP TAAK UPDATEN
    # --------------------------------------------------------

    UPDATE_RESPONSE=$(mktemp)

    HTTP_CODE=$(curl \
        --silent \
        --show-error \
        --connect-timeout 10 \
        --max-time 30 \
        --output "$UPDATE_RESPONSE" \
        --write-out "%{http_code}" \
        --request PUT \
        --url "https://api.clickup.com/api/v2/task/${TASK_ID}" \
        --header "Authorization: ${CLICKUP_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "{
            \"due_date\": ${TOMORROW_MS},
            \"due_date_time\": false
        }")

    CURL_RESULT=$?


    # --------------------------------------------------------
    # RESULTAAT CONTROLEREN
    # --------------------------------------------------------

    if [ "$CURL_RESULT" -ne 0 ]; then

        log "FOUT: ClickUp taak kon niet worden bijgewerkt."

        rm -f "$UPDATE_RESPONSE"
        return

    fi


    if [[ "$HTTP_CODE" =~ ^2 ]]; then

        log "ClickUp OK: taak $IP staat nu op $TOMORROW_TEXT"

    else

        log "FOUT: ClickUp update mislukt. HTTP $HTTP_CODE"

        if [ -s "$UPDATE_RESPONSE" ]; then
            cat "$UPDATE_RESPONSE"
            echo
        fi

    fi


    rm -f "$UPDATE_RESPONSE"
}


# ------------------------------------------------------------
# CLICKUP UPDATE UITVOEREN
#
# Als ClickUp mislukt, gaat het videoscript gewoon verder.
# ------------------------------------------------------------

update_clickup


# ============================================================
# VIDEO'S SYNCHRONISEREN
# ============================================================

log "Videosynchronisatie starten..."

while true
do

    log "Download poging..."

    if /usr/bin/rclone sync "$REMOTE" "$LOCAL"; then

        log "Download gelukt!"
        break

    fi

    log "Download mislukt. Nieuwe poging over 60 seconden..."

    sleep 60

done


# ============================================================
# PLAYLIST MAKEN
# ============================================================

log "Playlist opnieuw opbouwen..."

rm -f "$PLAYLIST"

find "$LOCAL" \
    -maxdepth 1 \
    -type f \
    \( \
        -iname "*.mp4" \
        -o -iname "*.mov" \
        -o -iname "*.m4v" \
    \) \
    | sort > "$PLAYLIST"


# ------------------------------------------------------------
# CONTROLEREN OF ER VIDEO'S ZIJN
# ------------------------------------------------------------

if [ ! -s "$PLAYLIST" ]; then

    log "FOUT: geen video's gevonden in $LOCAL"

    exit 1

fi


VIDEO_COUNT=$(wc -l < "$PLAYLIST")

log "$VIDEO_COUNT video('s) gevonden."


# ============================================================
# OUDE VIDEOSPELERS STOPPEN
# ============================================================

log "Eventuele bestaande videospelers stoppen..."

pkill vlc 2>/dev/null || true
pkill mpv 2>/dev/null || true

sleep 2


# ============================================================
# SCHERMBEVEILIGING / ENERGIEBESPARING UITSCHAKELEN
# ============================================================

/usr/bin/xset s off 2>/dev/null || true
/usr/bin/xset -dpms 2>/dev/null || true
/usr/bin/xset s noblank 2>/dev/null || true


# ============================================================
# VLC STARTEN
# ============================================================

log "VLC fullscreen starten..."

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
    "$PLAYLIST" \
    >/dev/null 2>&1 &


VLC_PID=$!

log "VLC gestart. PID: $VLC_PID"
log "Script gereed."
