#!/bin/bash
# tvfzf - Updated for Terminal & GitHub Actions Workflow

VERSION="1.0.0"

# --- NEW: Export Logic for GitHub Actions ---
# Jab GitHub Actions is script ko chalayega, toh ye bina menu dikhaye links export kar degi.
if [[ "$1" == "--export" ]]; then
    echo "#EXTM3U"
    # Doms9 ki main list se direct links nikalna
    curl -L -s "https://s.id/d9Base" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ ^#EXTINF ]]; then
            # Channel ka naam nikalna
            name=$(echo "$line" | sed -n 's/.*tvg-name="\([^"]*\)".*/\1/p')
            read -r url
            if [[ -n "$url" && ! "$url" =~ ^# ]]; then
                echo "#EXTINF:-1, ST-TV: ${name:-Channel}"
                echo "$url"
            fi
        fi
    done
    exit 0
fi

# --- Yahan se aapka original terminal code start hota hai ---

# Configuration
CONFIG_DIR="$HOME/.config/tvfzf"
CACHE_DIR="$HOME/.cache/tvfzf"
FAVORITES_FILE="$CONFIG_DIR/favorites"
HISTORY_FILE="$CONFIG_DIR/history"
EPG_CACHE="$CONFIG_DIR/epg.xml"

# Create directories
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
touch "$FAVORITES_FILE" "$HISTORY_FILE"

update_epg_cache() {
    local epg_url="https://raw.githubusercontent.com/doms9/iptv/refs/heads/default/EPG/TV.xml"
    
    # Check if cache exists and is less than 12 hours old
    if [[ -f "$EPG_CACHE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$EPG_CACHE" 2>/dev/null || echo 0))) -lt 43200 ]]; then
        return 0  # Cache is fresh
    fi
    
    echo "🔄 Downloading EPG data (17MB)..."
    if curl -s --progress-bar "$epg_url" > "$EPG_CACHE.tmp" 2>/dev/null && [[ -s "$EPG_CACHE.tmp" ]]; then
        mv "$EPG_CACHE.tmp" "$EPG_CACHE"
        echo "✅ EPG data updated"
    else
        rm -f "$EPG_CACHE.tmp"
        echo "❌ Failed to update EPG data"
        return 1
    fi
}

get_epg_info() {
    local channel_name="$1"
    if [[ ! -f "$EPG_CACHE" ]]; then update_epg_cache; fi
    
    if [[ -f "$EPG_CACHE" ]]; then
        local current_time=$(date -u +"%Y%m%d%H%M%S")
        local channel_id=$(grep -i "display-name.*$channel_name" "$EPG_CACHE" | head -1 | grep -o 'channel id="[^"]*"' | sed 's/.*id="//;s/"//')
        
        if [[ -n "$channel_id" ]]; then
            local program_info=$(awk -v ch="$channel_id" -v now="$current_time" '
            /<programme.*channel="'"$channel_id"'"/ {
                match($0, /start="([^"]*)"/, start_arr); match($0, /stop="([^"]*)"/, stop_arr)
                start_time = start_arr[1]; stop_time = stop_arr[1]
                gsub(/ [+-][0-9]{4}/, "", start_time); gsub(/ [+-][0-9]{4}/, "", stop_time)
                if (start_time <= now && stop_time > now) {
                    getline title_line
                    if (match(title_line, /<title[^>]*>([^<]*)<\/title>/, title_arr)) {
                        print "🎬 Now Playing: " title_arr[1]
                        print "🕒 " substr(start_time, 9, 2) ":" substr(start_time, 11, 2) " - " substr(stop_time, 9, 2) ":" substr(stop_time, 11, 2)
                        exit
                    }
                }
            }' "$EPG_CACHE")
            echo "${program_info:-📺 Live Programming\n🕒 $(date +"%H:%M") - Current Show}"
        else
            echo "📺 Live Programming\n🕒 $(date +"%H:%M") - Current Show"
        fi
    else
        echo "📺 Live Programming\n🕒 EPG data unavailable"
    fi
    echo -e "\n📡 Live TV Stream from doms9/iptv"
}

show_help() {
    cat << EOF
tvfzf - TV Channel streaming interface (v$VERSION)
USAGE: tvfzf [OPTIONS] [SEARCH_QUERY]
OPTIONS: -h Help, -v Version, --clear-cache, -c Categories, -f Favorites
KEYS: Enter (Play), Alt+f (Fav), Alt+c (Cats), Alt+q (Quit)
EOF
}

CHANNELS_CACHE="$CACHE_DIR/channels"

get_iptv_channels() {
    local current_time=$(date -u +"%Y%m%d%H%M%S")
    if [[ -f "$CHANNELS_CACHE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$CHANNELS_CACHE" 2>/dev/null || echo 0))) -lt 3600 ]]; then
        cat "$CHANNELS_CACHE"; return
    fi

    declare -A epg
    if [[ -f "$EPG_CACHE" ]]; then
        while IFS='=' read -r id program; do epg["$id"]="$program"; done < <(awk -v now="$current_time" '/<programme / { match($0, /channel="([^"]+)"/, ch); match($0, /start="([0-9]+)/, st); match($0, /stop="([0-9]+)/, sp); if (ch[1] != "" && st[1] <= now && sp[1] > now) { getline; match($0, /<title[^>]*>([^<]+)</, t); if (t[1] != "") { gsub(/\&amp;/, "\&", t[1]); print ch[1] "=" t[1] } } }' "$EPG_CACHE" 2>/dev/null)
    fi

    curl -L -s "https://s.id/d9Base" 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" =~ ^#EXTINF ]]; then
            channel_name=$(echo "$line" | sed -n 's/.*tvg-name="\([^"]*\)".*/\1/p')
            tvg_id=$(echo "$line" | sed -n 's/.*tvg-id="\([^"]*\)".*/\1/p')
            read -r url
            if [[ -n "$channel_name" && -n "$url" && ! "$url" =~ ^# ]]; then
                emoji="🎬"; [[ "$channel_name" =~ Sports|ESPN|NFL ]] && emoji="⚽"
                program="${epg[$tvg_id]:-Live Programming}"
                printf "%s %s - %s\t%s\t%s\t%s\n" "$emoji" "$channel_name" "$program" "$url" "$tvg_id" "$channel_name"
            fi
        fi
    done | tee "$CHANNELS_CACHE"
}

get_fallback_channels() {
    echo -e "📺 France 24\thttps://static.france24.com/live/F24_EN_LO_HLS/live_web.m3u8\tNews"
}

show_categories() {
    echo -e "📺 All\ttv\tTV.m3u8\n🎭 Entertainment\tbase\tbase.m3u8\n🏆 Live Events\tevents\tevents.m3u8"
}

STREAMED_BASE="https://raw.githubusercontent.com/doms9/iptv/default/M3U8"

parse_m3u() {
    local url="$1" emoji="$2"
    local m3u_content=$(curl -s "$url" 2>/dev/null)
    local name="" tvg_id=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^#EXTINF ]]; then
            name="${line##*,}"; [[ "$line" =~ tvg-id=\"([^\"]+)\" ]] && tvg_id="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^http ]] && [[ -n "$name" ]]; then
            printf "%s %s\t%s\t%s\t%s\n" "$emoji" "$name" "$line" "$tvg_id" "$name"
            name="" tvg_id=""
        fi
    done <<< "$m3u_content"
}

get_events() { parse_m3u "$STREAMED_BASE/events.m3u8" "🏆"; }
get_tv() { parse_m3u "$STREAMED_BASE/TV.m3u8" "📺"; }
get_base() { parse_m3u "$STREAMED_BASE/base.m3u8" "📺"; }

add_to_favorites() {
    local url=$(echo "$1" | cut -f2)
    if grep -q $'\t'"$url"$'\t' "$FAVORITES_FILE" 2>/dev/null; then
        grep -v $'\t'"$url"$'\t' "$FAVORITES_FILE" > "$FAVORITES_FILE.tmp" && mv "$FAVORITES_FILE.tmp" "$FAVORITES_FILE"
    else
        echo "$1" | sed 's/^[^ ]* /🎬 /' >> "$FAVORITES_FILE"
    fi
}

PLAYER_PID=""
play_channel() {
    local channel_url=$(echo "$1" | cut -f2)
    [[ -n "$PLAYER_PID" ]] && kill "$PLAYER_PID" 2>/dev/null
    if command -v mpv >/dev/null; then mpv "$channel_url" >/dev/null 2>&1 & PLAYER_PID=$!;
    elif command -v vlc >/dev/null; then vlc "$channel_url" >/dev/null 2>&1 & PLAYER_PID=$!; fi
}

main() {
    local query="" fav=false cats=false
    while [[ $# -gt 0 ]]; do
        case $1 in -h|--help) show_help; exit 0 ;; -v|--version) echo "$VERSION"; exit 0 ;; --clear-cache) rm -rf "$CACHE_DIR"/*; exit 0 ;; -f|--favorites) fav=true; shift ;; -c|--categories) cats=true; shift ;; *) query="$1"; shift ;; esac
    done

    update_epg_cache
    if ! command -v fzf >/dev/null; then echo "Error: fzf is required"; exit 1; fi

    local channels=""
    while true; do
        if [[ -z "$channels" ]]; then
            if $cats; then
                local sel=$(show_categories | fzf --prompt="📂 Categories > " --delimiter=$'\t' --with-nth=1)
                [[ -z "$sel" ]] && exit 0
                case $(echo "$sel" | cut -f2) in events) channels=$(get_events) ;; tv) channels=$(get_tv) ;; base) channels=$(get_base) ;; esac
                cats=false
            elif $fav; then
                channels=$(cat "$FAVORITES_FILE" 2>/dev/null | sed 's/^[^ ]* /❤️ /')
            else
                channels=$(get_iptv_channels)
            fi
        fi

        local res=$(echo "$channels" | fzf --prompt="📺 TV > " --query="$query" --expect="alt-F,alt-f,alt-c,alt-q,enter" --delimiter=$'\t' --with-nth=1 --preview='echo "Loading info for {1}..."')
        local key=$(echo "$res" | sed -n '2p')
        local line=$(echo "$res" | tail -1)

        case "$key" in
            "alt-q") clear; exit 0 ;;
            "alt-F") add_to_favorites "$line"; channels="" ;;
            "alt-f") fav=$([[ "$fav" == true ]] && echo false || echo true); channels="" ;;
            "alt-c") cats=true; channels="" ;;
            "enter"|"") [[ -n "$line" ]] && play_channel "$line" || exit 0 ;;
        esac
    done
}

main "$@"
