#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Generador de Informes de Filtro de URL (UTF-8)                 #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Informe del Filtro de URL (SquidGuard). Las listas provienen de la DBL de   #
# IPFire (mismas categorías que el DNS Firewall) más las listas "custom"      #
# (lista negra personalizada). Maquetación moderna y gráficas SVG (donut +    #
# barras) servidas por report-lib.sh. Sin JavaScript.                         #
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

# Diccionario de nombres de categoría y función awk friendly() (report-lib.sh)
CAT_KV="$(ipfr_cat_kv)"
AWK_FRIENDLY="$(ipfr_awk_friendly)"

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

# Parsea el log filtrado a:  categoria|cliente|dominio|metodo
#   Formato SquidGuard: "FECHA HORA [PID] Request(origen/categoría/-) HOST:PUERTO
#   IP_cliente/IP - MÉTODO ACCIÓN". Con HTTPS el destino es host:puerto (no URL),
#   por eso el dominio se toma del campo de destino, no de "http://…".
parse_requests() {
    PARSED="/var/tmp/url_parsed.$$"
    awk '
    {
        cat="";
        if (match($4, /Request\([^)]*\)/)) {
            inside = substr($4, RSTART+8, RLENGTH-9);   # origen/categoría/-
            nc = split(inside, p, "/");
            if (nc>=2) cat=p[2];
        }
        dom=$5;
        sub(/^[a-zA-Z]+:\/\//,"",dom);   # quitar http:// https://
        sub(/\/.*$/,"",dom);             # quitar ruta
        sub(/:[0-9]+$/,"",dom);          # quitar :puerto
        cli=$6; sub(/\/.*$/,"",cli);     # IP_cliente/IP -> IP_cliente
        met=$8;
        if (cat!="" && dom!="") print cat"|"cli"|"dom"|"met;
    }' "$FILTERED_LOG" > "$PARSED"
}

# Nº de bloqueos de una categoría concreta
count_cat() { awk -F'|' -v c="$1" '$1==c{n++} END{print n+0}' "$PARSED"; }

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
parse_requests

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
[[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"

# Estadísticas básicas
TOTAL_BLOCKED=$(wc -l < "$PARSED" 2>/dev/null || echo "0")
UNIQUE_IPS=$(cut -d'|' -f2 "$PARSED" 2>/dev/null | sort -u | grep -vc '^$')

# Conteos por categoría, dominio, cliente y método
CATEGORY_STATS=$(cut -d'|' -f1 "$PARSED" 2>/dev/null | sort | uniq -c | sort -nr)
DOMAIN_STATS=$(cut -d'|' -f3 "$PARSED" 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -nr)
CLIENT_STATS=$(cut -d'|' -f2 "$PARSED" 2>/dev/null | sort | uniq -c | sort -nr)
METHOD_STATS=$(cut -d'|' -f4 "$PARSED" 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -nr)
HOURLY_STATS=$(grep -a -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:' "$FILTERED_LOG" 2>/dev/null | cut -d' ' -f2 | cut -d':' -f1 | sort | uniq -c | sort -nr)

# Categorías destacadas (existen en la DBL de IPFire)
MALWARE_BLOCKED=$(count_cat malware)
PHISHING_BLOCKED=$(count_cat phishing)
PORN_BLOCKED=$(count_cat porn)
ADS_BLOCKED=$(count_cat ads)

# Tasa media del periodo
case "$TIME_SCOPE" in
    hour)  BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 60" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate min' 'bloqueos/min')" ;;
    day)   BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 24" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate hour' 'bloqueos/hora')" ;;
    week)  BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 7"  | bc -l 2>/dev/null || echo 0) $(t 'reports url rate day' 'bloqueos/día')" ;;
    month) BLOCKS_RATE="$(echo "scale=1; $TOTAL_BLOCKED / 30" | bc -l 2>/dev/null || echo 0) $(t 'reports url rate day' 'bloqueos/día')" ;;
esac

FORMATTED_TOTAL=$(ipfr_format_number "$TOTAL_BLOCKED")
FORMATTED_UNIQUE_IPS=$(ipfr_format_number "$UNIQUE_IPS")
FORMATTED_MALWARE=$(ipfr_format_number "$MALWARE_BLOCKED")
FORMATTED_PHISHING=$(ipfr_format_number "$PHISHING_BLOCKED")
FORMATTED_PORN=$(ipfr_format_number "$PORN_BLOCKED")
FORMATTED_ADS=$(ipfr_format_number "$ADS_BLOCKED")

# Amenazas (malware + phishing). El color de sus tarjetas es verde cuando no ha
# habido bloqueos (situación buena) y de aviso cuando sí los ha habido.
THREATS=$(( MALWARE_BLOCKED + PHISHING_BLOCKED ))
MW_COLOR=$([[ "$MALWARE_BLOCKED" -gt 0 ]] && echo orange || echo green)
PH_COLOR=$([[ "$PHISHING_BLOCKED" -gt 0 ]] && echo purple || echo green)
FORMATTED_THREATS=$(ipfr_format_number "$THREATS")

# ----------------------- Generación del informe ----------------------------
{
ipfr_doc_open "url" "&#x1F310;" "$(t 'reports url title' 'Informe de Filtro de URL')" \
    "$(t 'reports generated on' 'Generado el') $(date '+%d/%m/%Y %H:%M') &middot; $(t 'reports period word' 'Periodo'): $TIME_DESCRIPTION &middot; SquidGuard / IPFire DBL"

ipfr_stats_open
ipfr_stat red    "$(t 'reports url stat total' 'Total bloqueado')" "$FORMATTED_TOTAL"      "$(t 'reports url stat total d' 'URLs bloqueadas')"
ipfr_stat blue   "$(t 'reports url stat ips' 'IPs únicas')"        "$FORMATTED_UNIQUE_IPS" "$(t 'reports url stat ips d' 'Clientes distintos')"
ipfr_stat "$MW_COLOR" "$(t 'reports url stat malware' 'Malware')"       "$FORMATTED_MALWARE"    "$(t 'reports url stat malware d' 'Contenido malicioso')"
ipfr_stat "$PH_COLOR" "$(t 'reports url stat phishing' 'Phishing')"     "$FORMATTED_PHISHING"   "$(t 'reports url stat phishing d' 'Intentos de phishing')"
ipfr_stat green  "$(t 'reports cat porn' 'Pornografía')"           "$FORMATTED_PORN"       "$(t 'reports url stat porn d' 'Contenido para adultos')"
ipfr_stat cyan   "$(t 'reports cat ads' 'Publicidad')"            "$FORMATTED_ADS"        "$(t 'reports url stat ads d' 'Publicidad y rastreadores')"
ipfr_stats_close

ipfr_section "&#x1F4CA;" "$(t 'reports sec overview' 'Visión general')"
ipfr_grid_open
echo "$CATEGORY_STATS" | head -n 6 | awk -v cats="$CAT_KV" "$AWK_FRIENDLY"'BEGIN{split("#dc143c #0d6efd #22a559 #f59e0b #6f42c1 #17a2b8",c," ")} NF>=2{print friendly($2)"|"$1"|"c[((NR-1)%6)+1]}' | \
    ipfr_donut "$(t 'reports url donut title' 'Categorías bloqueadas')" "$(t 'reports url donut sub' 'Reparto por categoría (TOP 6)')" "$(t 'reports url unit blocks' 'bloqueos')"
echo "$DOMAIN_STATS" | head -n "$NUMBER" | awk 'NF>=2{print $2"|"$1}' | \
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
echo "$HOURLY_STATS" | head -n 10 | awk 'NF>=2{printf "%s:00|%s\n",$2,$1}' | \
    ipfr_hbars "$(t 'reports url hourly title' 'Franjas horarias con más bloqueos')" "$(t 'reports url rate label' 'Tasa media del periodo'): ${BLOCKS_RATE:-n/d}" "#0d6efd"

# Bloqueos por categoría (coherente con la tabla del DNS Firewall)
ipfr_section "&#x1F5C2;&#xFE0F;" "$(t 'reports url sec bycategory' 'Bloqueos por categoría')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports ids th category' 'Categoría')</th><th>$(t 'reports th total' 'Total')</th><th>$(t 'reports th pct' '%')</th></tr></thead><tbody>"
if [[ "$TOTAL_BLOCKED" -gt 0 ]]; then
    echo "$CATEGORY_STATS" | awk -v total="$TOTAL_BLOCKED" -v cats="$CAT_KV" "$AWK_FRIENDLY"'BEGIN{pos=1} NF>=2 {
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td><span class=\"ipfr-tag ipfr-tag--cyan\">%s</span> <span style=\"color:#6b7785;font-size:11px\">%s</span></td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", pos, friendly($2), $2, formatted, percent;
        pos++;
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'
echo "<p style=\"font-size:11px;color:#6b7785;margin:4px 2px 14px\"><em>$(t 'reports url custom note' 'Las listas blancas personalizadas permiten el acceso y no se registran como bloqueos.')</em></p>"

ipfr_section "&#x1F4BB;" "TOP $NUMBER $(t 'reports url sec topips' 'IPs con más bloqueos')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports th client ip' 'IP cliente')</th><th>$(t 'reports th blocks' 'Bloqueos')</th><th>$(t 'reports th pct' '%')</th></tr></thead><tbody>"
if [[ "$TOTAL_BLOCKED" -gt 0 ]]; then
    echo "$CLIENT_STATS" | head -n "$NUMBER" | awk -v total="$TOTAL_BLOCKED" 'BEGIN{pos=1} NF>=2 {
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
if [[ -n "$METHOD_STATS" ]]; then
    echo "$METHOD_STATS" | head -n 10 | awk -v total="$TOTAL_BLOCKED" 'NF>=2 {
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        printf "<tr><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", $2, formatted, percent;
    }'
else
    echo "<tr><td colspan=\"3\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_section "&#x1F512;" "$(t 'reports url sec security' 'Resumen de seguridad')"
ipfr_alerts_open
if [[ "$THREATS" -gt 0 ]]; then
    ipfr_alert danger "&#128308; $(t 'reports url sec threats' 'Amenazas bloqueadas'): $FORMATTED_THREATS" \
        "$(t 'reports url stat malware' 'Malware'): $FORMATTED_MALWARE &middot; $(t 'reports url stat phishing' 'Phishing'): $FORMATTED_PHISHING. $(t 'reports url threat desc' 'Accesos a contenido malicioso o de phishing bloqueados por el filtro.')"
else
    ipfr_alert ok "&#9989; $(t 'reports url sec nothreat' 'Sin amenazas detectadas')" \
        "$(t 'reports url sec nothreat d' 'No se ha bloqueado ningún acceso a malware ni phishing en el periodo.') ($TIME_DESCRIPTION)"
fi
ipfr_alerts_close

ipfr_doc_close "<strong>IPFire</strong> $(t 'reports footer system' 'Reports System') &middot; $(t 'reports url foot module' 'Filtro de URL (SquidGuard)') &middot; $(t 'reports footer period' 'periodo'): <strong>$TIME_DESCRIPTION</strong> &middot; $(t 'reports url foot files' 'archivos procesados'): $(get_log_files | wc -w)"
} > "$OUTPUT_FILE"

# Limpieza (solo nuestros temporales)
[[ -f "$FILTERED_LOG" ]] && rm -f "$FILTERED_LOG"
[[ -f "$PARSED" ]] && rm -f "$PARSED"
rm -f /var/tmp/filtered_url_log.$$ /var/tmp/url_parsed.$$ 2>/dev/null

echo "Informe de URL Filter generado: $OUTPUT_FILE"
echo "Periodo analizado: $TIME_DESCRIPTION"
exit 0
