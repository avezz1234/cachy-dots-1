#!/usr/bin/env bash

# Paths
cache_dir="$HOME/.cache/quickshell/weather"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"

# Config: set WTTR_CITY to override auto-detect (e.g. "London" or "New+York")
CITY="${WTTR_CITY:-Charleston+WV}"
UNIT="${WTTR_UNIT:-imperial}"  # metric or imperial

mkdir -p "${cache_dir}"

get_icon() {
    local code=$1
    if   [[ $code == 113 ]]; then                              echo "☀|Sunny"
    elif [[ $code =~ ^(116)$ ]]; then                          echo "|Partly Cloudy"
    elif [[ $code =~ ^(119|122)$ ]]; then                      echo "|Cloudy"
    elif [[ $code =~ ^(143|248|260)$ ]]; then                  echo "|Mist"
    elif [[ $code =~ ^(200|386|389|392|395)$ ]]; then          echo "|Storm"
    elif [[ $code =~ ^(179|182|185|227|230|323|326|329|332|335|338|350|368|371|374|377)$ ]]; then echo "|Snow"
    elif [[ $code =~ ^(176|263|266|281|284|293|296|299|302|305|308|311|314|317|320|353|356|359|362|365)$ ]]; then echo "|Rain"
    else echo "|Unknown"
    fi
}

get_hex() {
    local code=$1
    if   [[ $code == 113 ]]; then                              echo "#f9e2af"
    elif [[ $code =~ ^(116)$ ]]; then                          echo "#bac2de"
    elif [[ $code =~ ^(119|122)$ ]]; then                      echo "#bac2de"
    elif [[ $code =~ ^(143|248|260)$ ]]; then                  echo "#84afdb"
    elif [[ $code =~ ^(200|386|389|392|395)$ ]]; then          echo "#f9e2af"
    elif [[ $code =~ ^(179|182|185|227|230|323|326|329|332|335|338|350|368|371|374|377)$ ]]; then echo "#cdd6f4"
    else                                                        echo "#74c7ec"
    fi
}

temp_unit_flag() {
    [[ "$UNIT" == "imperial" ]] && echo "u" || echo "m"
}

get_data() {
    local flag; flag=$(temp_unit_flag)
    local url="https://wttr.in/${CITY}?format=j1&${flag}"
    local raw; raw=$(curl -sf --max-time 10 "$url") || return 1

    [[ -z "$raw" ]] && return 1

    local deg; [[ "$UNIT" == "imperial" ]] && deg="°F" || deg="°C"
    local temp_key; [[ "$UNIT" == "imperial" ]] && temp_key="tempF" || temp_key="tempC"
    local feels_key; [[ "$UNIT" == "imperial" ]] && feels_key="FeelsLikeF" || feels_key="FeelsLikeC"
    local max_key; [[ "$UNIT" == "imperial" ]] && max_key="maxtempF" || max_key="maxtempC"
    local min_key; [[ "$UNIT" == "imperial" ]] && min_key="mintempF" || min_key="mintempC"

    local final_json="["
    local num_days; num_days=$(echo "$raw" | jq '.weather | length')

    for i in $(seq 0 $((num_days - 1))); do
        local day_data; day_data=$(echo "$raw" | jq ".weather[$i]")
        local date_str; date_str=$(echo "$day_data" | jq -r '.date')

        local f_max; f_max=$(echo "$day_data" | jq -r ".$max_key")
        local f_min; f_min=$(echo "$day_data" | jq -r ".$min_key")
        local f_wind; f_wind=$(echo "$day_data" | jq -r '.hourly | map(.windspeedKmph | tonumber) | max | round')
        local f_hum; f_hum=$(echo "$day_data" | jq -r '.hourly | map(.humidity | tonumber) | add / length | round')
        local f_uv; f_uv=$(echo "$day_data" | jq -r '.uvIndex')

        # Midday slot for icon/desc
        local mid_idx; mid_idx=$(echo "$day_data" | jq '.hourly | length / 2 | floor')
        local f_code; f_code=$(echo "$day_data" | jq -r ".hourly[$mid_idx].weatherCode")
        local f_desc; f_desc=$(echo "$day_data" | jq -r ".hourly[$mid_idx].weatherDesc[0].value")
        local icon_data; icon_data=$(get_icon "$f_code")
        local f_icon; f_icon=$(echo "$icon_data" | cut -d'|' -f1)
        local f_hex; f_hex=$(get_hex "$f_code")
        local f_day; f_day=$(date -d "$date_str" "+%a")
        local f_full_day; f_full_day=$(date -d "$date_str" "+%A")
        local f_date_num; f_date_num=$(date -d "$date_str" "+%d %b")
        local f_feels; f_feels=$(echo "$day_data" | jq -r ".hourly[$mid_idx].$feels_key")

        # Build hourly
        local hourly_json="["
        local num_slots; num_slots=$(echo "$day_data" | jq '.hourly | length')
        for j in $(seq 0 $((num_slots - 1))); do
            local slot; slot=$(echo "$day_data" | jq ".hourly[$j]")
            local s_temp; s_temp=$(echo "$slot" | jq -r ".$temp_key")
            local s_time_raw; s_time_raw=$(echo "$slot" | jq -r '.time')
            # wttr time is "0","300","600"... convert to HH:MM
            local s_hour; s_hour=$(( s_time_raw / 100 ))
            local s_min; s_min=$(printf "%02d" $(( s_time_raw % 100 )))
            local s_time; s_time=$(printf "%02d:%s" "$s_hour" "$s_min")
            local s_code; s_code=$(echo "$slot" | jq -r '.weatherCode')
            local s_hex; s_hex=$(get_hex "$s_code")
            local s_icon; s_icon=$(get_icon "$s_code" | cut -d'|' -f1)
            [[ $j -gt 0 ]] && hourly_json="${hourly_json},"
            hourly_json="${hourly_json}{\"time\":\"${s_time}\",\"temp\":\"${s_temp}\",\"icon\":\"${s_icon}\",\"hex\":\"${s_hex}\"}"
        done
        hourly_json="${hourly_json}]"

        [[ $i -gt 0 ]] && final_json="${final_json},"
        final_json="${final_json}{
            \"id\":\"${i}\",
            \"day\":\"${f_day}\",
            \"day_full\":\"${f_full_day}\",
            \"date\":\"${f_date_num}\",
            \"max\":\"${f_max}\",
            \"min\":\"${f_min}\",
            \"feels_like\":\"${f_feels}\",
            \"wind\":\"${f_wind}\",
            \"humidity\":\"${f_hum}\",
            \"pop\":\"${f_uv}\",
            \"icon\":\"${f_icon}\",
            \"hex\":\"${f_hex}\",
            \"desc\":\"${f_desc}\",
            \"hourly\":${hourly_json}
        }"
    done
    final_json="${final_json}]"

    echo "{\"forecast\":${final_json}}" > "${json_file}"
}

ensure_cache() {
    local limit=900  # 15 min
    if [ -f "$json_file" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$json_file") ))
        [[ $age -gt $limit ]] && get_data &
    else
        get_data
    fi
}

case "$1" in
    --getdata)
        get_data ;;
    --json)
        ensure_cache
        cat "$json_file" 2>/dev/null ;;
    --view-listener)
        [ ! -f "$view_file" ] && echo "0" > "$view_file"
        tail -F "$view_file" ;;
    --nav)
        [ ! -f "$view_file" ] && echo "0" > "$view_file"
        cur=$(cat "$view_file"); max=2
        if [[ "$2" == "next" && $cur -lt $max ]]; then echo $((cur+1)) > "$view_file"
        elif [[ "$2" == "prev" && $cur -gt 0 ]]; then echo $((cur-1)) > "$view_file"
        fi ;;
    --icon)
        cat "$json_file" 2>/dev/null | jq -r '.forecast[0].icon' ;;
    --temp)
        t=$(cat "$json_file" 2>/dev/null | jq -r '.forecast[0].max')
        [[ "$UNIT" == "imperial" ]] && echo "${t}°F" || echo "${t}°C" ;;
    --hex)
        cat "$json_file" 2>/dev/null | jq -r '.forecast[0].hex' ;;
    --current-icon)
        ensure_cache
        cur=$(date +%H%M | sed 's/^0//')
        jq -r --argjson ct "${cur:-0}" \
            '(.forecast[0].hourly | map(select( (.time | split(":") | .[0] + .[1] | tonumber) <= $ct )) | last) // .forecast[0].hourly[0] | .icon' \
            "$json_file" 2>/dev/null ;;
    --current-temp)
        ensure_cache
        cur=$(date +%H%M | sed 's/^0//')
        t=$(jq -r --argjson ct "${cur:-0}" \
            '(.forecast[0].hourly | map(select( (.time | split(":") | .[0] + .[1] | tonumber) <= $ct )) | last) // .forecast[0].hourly[0] | .temp' \
            "$json_file" 2>/dev/null)
        [[ "$UNIT" == "imperial" ]] && echo "${t}°F" || echo "${t}°C" ;;
    --current-hex)
        ensure_cache
        cur=$(date +%H%M | sed 's/^0//')
        jq -r --argjson ct "${cur:-0}" \
            '(.forecast[0].hourly | map(select( (.time | split(":") | .[0] + .[1] | tonumber) <= $ct )) | last) // .forecast[0].hourly[0] | .hex' \
            "$json_file" 2>/dev/null ;;
esac
