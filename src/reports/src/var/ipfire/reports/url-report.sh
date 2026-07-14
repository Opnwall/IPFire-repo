#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Generador de Informes de Filtro de URL (UTF-8)                 #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Informe del Filtro de URL (SquidGuard) con maquetación moderna y gráficas   #
# SVG (donut + barras) servidas por report-lib.sh. Sin JavaScript.            #
#                                                                             #
###############################################################################

# Configuración por defecto
DEFAULT_LOG="/var/log/squidGuard/urlfilter.log"
DEFAULT_OUTPUT="/var/ipfire/reports/reports/url-report.html"
DEFAULT_NUMBER=10
CONFIG_FILE="/var/ipfire/reports/settings"

LOG_FILE="$DEFAULT_LOG"
OUTPUT_FILE="$DEFAULT_OUTPUT"
NUMBER="$DEFAULT_NUMBER"

LIB="$(dirname "$(readlink -f "$0")")/report-lib.sh"
[[ -f "$LIB" ]] || LIB="/var/ipfire/reports/report-lib.sh"
# shellcheck source=/var/ipfire/reports/report-lib.sh
source "$LIB"

# Cargar el idioma del GUI (en el shell principal para que $(t) lo herede)
ipfr_load_lang

show_help() {
    cat << EOF
Uso: $0 [opciones]

Opciones:
    -l, --log FILE      Especificar archivo de log (predeterminado: $DEFAULT_LOG)
    -o, --output FILE   Especificar archivo de salida (predeterminado: $DEFAULT_OUTPUT)
    -n, --number NUM    Número de elementos top a mostrar (predeterminado: $DEFAULT_NUMBER)
    -h, --help          Mostrar esta ayuda

EOF
}

read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Archivo de configuración no encontrado: $CONFIG_FILE"
        exit 1
    fi
    URLFILTER_ENABLED=$(grep -a "^URL=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_HOUR=$(grep -a "^SCOPE_HOUR=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_DAY=$(grep -a "^SCOPE_DAY=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_WEEK=$(grep -a "^SCOPE_WEEK=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_MONTH=$(grep -a "^SCOPE_MONTH=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)

    if [[ "$URLFILTER_ENABLED" != "on" ]]; then
        echo "Error: Los informes de URL Filter están deshabilitados en la configuración"
        exit 1
    fi

    if [[ "$SCOPE_HOUR" == "on" ]]; then
        TIME_SCOPE="hour";  TIME_DESCRIPTION="$(t 'reports period hour' 'última 1 hora')"
    elif [[ "$SCOPE_DAY" == "on" ]]; then
        TIME_SCOPE="day";   TIME_DESCRIPTION="$(t 'reports period day' 'último 1 día')"
    elif [[ "$SCOPE_WEEK" == "on" ]]; then
        TIME_SCOPE="week";  TIME_DESCRIPTION="$(t 'reports period week' 'últimos 7 días')"
    elif [[ "$SCOPE_MONTH" == "on" ]]; then
        TIME_SCOPE="month"; TIME_DESCRIPTION="$(t 'reports period month' 'último mes (30 días)')"
    else
        echo "Error: No se ha configurado ningún periodo de tiempo válido"
        exit 1
    fi
}



# Patrones de fecha para SquidGuard: YYYY-MM-DD (anclado al inicio)
generate_date_patterns() {
    case "$TIME_SCOPE" in
        "hour")
            echo "^($(date '+%Y-%m-%d %H:')|$(date -d '1 hour ago' '+%Y-%m-%d %H:'))" ;;
        "day")
            echo "^($(date '+%Y-%m-%d')|$(date -d '1 day ago' '+%Y-%m-%d'))" ;;
        "week")
            local pattern=""
            for i in {0..6}; do
                local d=$(date -d "$i days ago" '+%Y-%m-%d')
                pattern="${pattern:+$pattern|}$d"
            done
            echo "^($pattern)" ;;
        "month")
            local pattern=""
            for i in {0..29}; do
                local d=$(date -d "$i days ago" '+%Y-%m-%d')
                pattern="${pattern:+$pattern|}$d"
            done
            echo "^($pattern)" ;;
    esac
}

filter_logs_by_time() {
    local temp_log="/var/tmp/filtered_url_log.$$"
    local files_to_process date_pattern
    read -a files_to_process <<< "$(get_log_files)"
    date_pattern=$(generate_date_patterns)
    > "$temp_log"
    for log_file in "${files_to_process[@]}"; do
        if [[ "$log_file" == *.gz ]]; then
            zcat "$log_file" 2>/dev/null | grep -a -E "Request\(" | grep -a -E "$date_pattern" >> "$temp_log"
        else
            grep -a -E "Request\(" "$log_file" 2>/dev/null | grep -a -E "$date_pattern" >> "$temp_log"
        fi
    done
    [[ ! -s "$temp_log" ]] && echo "Advertencia: No se encontraron bloqueos URL en el periodo $TIME_DESCRIPTION"
    FILTERED_LOG="$temp_log"
}

get_category_stats() {
    local t="/var/tmp/category_stats.$$"
    # La categoría es el componente central de Request(origen/categoría/...)
    grep -a -oE 'Request\([^)]*\)' "$FILTERED_LOG" | \
        sed -E 's#Request\(([^/]*)/([^/]*)/.*#\2#' | \
        grep -vE '^$|^-$' | sort | uniq -c | sort -nr > "$t"
    CATEGORY_STATS_FILE="$t"
}
get_hourly_stats() {
    local t="/var/tmp/hourly_stats.$$"
    grep -a -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:' "$FILTERED_LOG" | cut -d' ' -f2 | cut -d':' -f1 | sort | uniq -c | sort -nr > "$t"
    HOURLY_STATS_FILE="$t"
}
get_domain_stats() {
    local t="/var/tmp/domain_stats.$$"
    grep -a -oE 'https?://[^/]+' "$FILTERED_LOG" | sed 's|https\?://||' | sort | uniq -c | sort -nr > "$t"
    DOMAIN_STATS_FILE="$t"
}
get_method_stats() {
    local t="/var/tmp/method_stats.$$"
    grep -a -oE '(GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH|CONNECT)' "$FILTERED_LOG" | sort | uniq -c | sort -nr > "$t"
    METHOD_STATS_FILE="$t"
}

calculate_performance_stats() {
    if [[ "$TIME_SCOPE" == "hour" ]]; then
        BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 60" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate min' 'bloqueos/min')"
    elif [[ "$TIME_SCOPE" == "day" ]]; then
        BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 24" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate hour' 'bloqueos/hora')"
    elif [[ "$TIME_SCOPE" == "week" ]]; then
        BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 7" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate day' 'bloqueos/día')"
    elif [[ "$TIME_SCOPE" == "month" ]]; then
        BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 30" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate day' 'bloqueos/día')"
    fi
}

calculate_correct_metrics() {
    local ti="/var/tmp/ip_extractions.$$"
    local td="/var/tmp/domain_extractions.$$"
    grep -a -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$FILTERED_LOG" > "$ti"
    TOTAL_IPS_EXTRACTED=$(wc -l < "$ti" 2>/dev/null || echo "0")
    grep -a -oE 'https?://[^/]+' "$FILTERED_LOG" | sed 's|https\?://||' > "$td"
    TOTAL_DOMAINS_EXTRACTED=$(wc -l < "$td" 2>/dev/null || echo "0")
    rm -f "$ti" "$td"
}

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--log) LOG_FILE="$2"; shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -n|--number) NUMBER="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Opción desconocida: $1"; show_help; exit 1 ;;
    esac
done

read_config

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Archivo de log no encontrado: $LOG_FILE"
    exit 1
fi

filter_logs_by_time

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
[[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"

# Estadísticas básicas
TOTAL_BLOCKED=$(wc -l < "$FILTERED_LOG" 2>/dev/null || echo "0")
CRYPTOJACKING_BLOCKED=$(grep -a -c "/cryptojacking/" "$FILTERED_LOG" 2>/dev/null)
HACKING_BLOCKED=$(grep -a -c "/hacking/" "$FILTERED_LOG" 2>/dev/null)
ADULT_BLOCKED=$(grep -a -c "/adult/" "$FILTERED_LOG" 2>/dev/null)
MALWARE_BLOCKED=$(grep -a -c "/malware/" "$FILTERED_LOG" 2>/dev/null)
PHISHING_BLOCKED=$(grep -a -c "/phishing/" "$FILTERED_LOG" 2>/dev/null)
TRACKING_BLOCKED=$(grep -a -c "/tracking/" "$FILTERED_LOG" 2>/dev/null)
calculate_correct_metrics
get_category_stats
get_hourly_stats
get_domain_stats
get_method_stats
calculate_performance_stats

FORMATTED_TOTAL=$(ipfr_format_number "$TOTAL_BLOCKED")
FORMATTED_CRYPTO=$(ipfr_format_number "$CRYPTOJACKING_BLOCKED")
FORMATTED_HACKING=$(ipfr_format_number "$HACKING_BLOCKED")
FORMATTED_ADULT=$(ipfr_format_number "$ADULT_BLOCKED")
FORMATTED_MALWARE=$(ipfr_format_number "$MALWARE_BLOCKED")
FORMATTED_PHISHING=$(ipfr_format_number "$PHISHING_BLOCKED")
FORMATTED_TRACKING=$(ipfr_format_number "$TRACKING_BLOCKED")
UNIQUE_IPS=$(grep -a -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$FILTERED_LOG" | sort -u | wc -l)
FORMATTED_UNIQUE_IPS=$(ipfr_format_number "$UNIQUE_IPS")

# Efectividad de seguridad (% de bloqueos crypto+malware+phishing)
if [[ "$TOTAL_BLOCKED" -gt 0 ]]; then
    EFFECTIVENESS=$(echo "scale=1; ($CRYPTOJACKING_BLOCKED + $MALWARE_BLOCKED + $PHISHING_BLOCKED) / $TOTAL_BLOCKED * 100" | bc -l 2>/dev/null || echo "0")
else
    EFFECTIVENESS="0"
fi

# ----------------------- Generación del informe ----------------------------
{
ipfr_doc_open "url" "&#x1F310;" "$(t 'reports url title' 'Informe de Filtro de URL')" \
    "$(t 'reports generated on' 'Generado el') $(date '+%d/%m/%Y %H:%M') &middot; $(t 'reports period word' 'Periodo'): $TIME_DESCRIPTION &middot; SquidGuard"

ipfr_stats_open
ipfr_stat red    "$(t 'reports url stat total' 'Total bloqueado')" "$FORMATTED_TOTAL"      "$(t 'reports url stat total d' 'URLs bloqueadas')"
ipfr_stat blue   "$(t 'reports url stat ips' 'IPs únicas')"        "$FORMATTED_UNIQUE_IPS" "$(t 'reports url stat ips d' 'Clientes distintos')"
ipfr_stat orange "$(t 'reports url stat malware' 'Malware')"       "$FORMATTED_MALWARE"    "$(t 'reports url stat malware d' 'Contenido malicioso')"
ipfr_stat purple "$(t 'reports url stat phishing' 'Phishing')"     "$FORMATTED_PHISHING"   "$(t 'reports url stat phishing d' 'Intentos de phishing')"
ipfr_stat green  "$(t 'reports url stat crypto' 'Cryptojacking')"  "$FORMATTED_CRYPTO"     "$(t 'reports url stat crypto d' 'Scripts de minería')"
ipfr_stat cyan   "$(t 'reports url stat tracking' 'Tracking')"     "$FORMATTED_TRACKING"   "$(t 'reports url stat tracking d' 'Rastreadores')"
ipfr_stats_close

ipfr_section "&#x1F4CA;" "$(t 'reports sec overview' 'Visión general')"
ipfr_grid_open
head -n 6 "$CATEGORY_STATS_FILE" 2>/dev/null | \
    awk 'BEGIN{split("#dc143c #0d6efd #22a559 #f59e0b #6f42c1 #17a2b8",c," ")} NF>=2{print $2"|"$1"|"c[((NR-1)%6)+1]}' | \
    ipfr_donut "$(t 'reports url donut title' 'Categorías bloqueadas')" "$(t 'reports url donut sub' 'Reparto por categoría (TOP 6)')" "$(t 'reports url unit blocks' 'bloqueos')"
head -n "$NUMBER" "$DOMAIN_STATS_FILE" 2>/dev/null | awk 'NF>=2{print $2"|"$1}' | \
    ipfr_hbars "TOP $NUMBER $(t 'reports url sec topdomains' 'dominios bloqueados')" "$(t 'reports url bars sub' 'Dominios con más bloqueos')" "#0d6efd"
ipfr_grid_close

# Mapa de calor día x hora (salvo en alcance de 1 hora)
if [[ "$TIME_SCOPE" != "hour" ]]; then
    case "$TIME_SCOPE" in day) _HN=1 ;; week) _HN=7 ;; month) _HN=30 ;; *) _HN=7 ;; esac
    _HDAYS=""; for ((_i=_HN-1; _i>=0; _i--)); do _HDAYS+="$(date -d "$_i days ago" '+%Y-%m-%d') "; done
    ipfr_section "&#x1F4C5;" "$(t 'reports heatmap title' 'Actividad por hora y día')"
    grep -a -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}' "$FILTERED_LOG" | awk '{print $1"\t"$2}' \
        | ipfr_heatmap "" "$(t 'reports heatmap caption' 'Cada celda es una hora de un día concreto; cuanto más oscuro, mayor actividad. Útil para ver si hay franjas más activas.')" "#0d6efd" "$_HDAYS"
fi

ipfr_section "&#x1F557;" "$(t 'reports url sec hourly' 'Distribución horaria')"
head -n 10 "$HOURLY_STATS_FILE" 2>/dev/null | awk 'NF>=2{printf "%s:00|%s\n",$2,$1}' | \
    ipfr_hbars "$(t 'reports url hourly title' 'Franjas horarias con más bloqueos')" "$(t 'reports url rate label' 'Tasa media del periodo'): ${BLOCKS_RATE:-n/d}" "#0d6efd"

ipfr_section "&#x1F4BB;" "TOP $NUMBER $(t 'reports url sec topips' 'IPs con más bloqueos')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports th client ip' 'IP cliente')</th><th>$(t 'reports th blocks' 'Bloqueos')</th><th>$(t 'reports th pct' '%')</th></tr></thead><tbody>"
if [[ -s "$FILTERED_LOG" ]]; then
    grep -a -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$FILTERED_LOG" | sort | uniq -c | sort -nr | head -n "$NUMBER" | \
    awk -v total="$TOTAL_IPS_EXTRACTED" 'BEGIN{pos=1} {
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", pos, $2, formatted, percent;
        pos++;
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_section "&#x1F4E1;" "$(t 'reports url sec methods' 'Métodos HTTP')"
echo "<table class=\"ipfr-table\"><thead><tr><th>$(t 'reports url th method' 'Método')</th><th>$(t 'reports th total' 'Total')</th><th>$(t 'reports th pct' '%')</th></tr></thead><tbody>"
if [[ -s "$METHOD_STATS_FILE" ]]; then
    head -n 10 "$METHOD_STATS_FILE" | awk -v total="$TOTAL_BLOCKED" '{
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        printf "<tr><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", $2, formatted, percent;
    }'
else
    echo "<tr><td colspan=\"3\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_section "&#x1F512;" "$(t 'reports url sec security' 'Resumen de seguridad')"
ipfr_alerts_open
ipfr_alert danger "&#128308; $(t 'reports url hack title' 'Intentos de hacking bloqueados'): $FORMATTED_HACKING" "$(t 'reports url hack desc' 'Accesos a recursos de hacking/exploits filtrados por el proxy.')"
ipfr_alert warn   "&#128992; $(t 'reports url adult title' 'Contenido adulto bloqueado'): $FORMATTED_ADULT" "$(t 'reports url adult desc' 'Solicitudes a contenido para adultos denegadas.')"
ipfr_alert ok     "&#9989; $(t 'reports url eff title' 'Efectividad de seguridad'): ${EFFECTIVENESS}%" "$(t 'reports url eff desc' 'Porcentaje de bloqueos correspondientes a amenazas (cryptojacking + malware + phishing) sobre el total.')"
ipfr_alerts_close

ipfr_doc_close "<strong>IPFire</strong> $(t 'reports footer system' 'Reports System') &middot; $(t 'reports url foot module' 'Filtro de URL (SquidGuard)') &middot; $(t 'reports footer period' 'periodo'): <strong>$TIME_DESCRIPTION</strong> &middot; $(t 'reports url foot files' 'archivos procesados'): $(get_log_files | wc -w)"
} > "$OUTPUT_FILE"

# Limpieza (solo nuestros temporales)
[[ -f "$FILTERED_LOG" ]] && rm -f "$FILTERED_LOG"
rm -f "$CATEGORY_STATS_FILE" "$HOURLY_STATS_FILE" "$DOMAIN_STATS_FILE" "$METHOD_STATS_FILE" 2>/dev/null
rm -f /var/tmp/filtered_url_log.$$ /var/tmp/ip_extractions.$$ /var/tmp/domain_extractions.$$ 2>/dev/null

echo "Informe de URL Filter generado: $OUTPUT_FILE"
echo "Periodo analizado: $TIME_DESCRIPTION"
exit 0
