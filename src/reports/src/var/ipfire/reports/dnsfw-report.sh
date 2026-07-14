#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Generador de Informes del DNS Firewall (UTF-8)                 #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Informe del DNS Firewall (RPZ de unbound). Analiza /var/log/messages        #
# buscando "info: rpz: applied [lista] ... IP@puerto dominio" e ignora las    #
# peticiones internas (127.0.0.1). Maquetación moderna y gráficas SVG vía     #
# report-lib.sh. Sin JavaScript ni dependencias.                              #
#                                                                             #
###############################################################################

# Configuración por defecto
DEFAULT_LOG="/var/log/messages"
DEFAULT_OUTPUT="/var/ipfire/reports/reports/dnsfw-report.html"
DEFAULT_NUMBER=10
CONFIG_FILE="/var/ipfire/reports/settings"
DNSBL_FILE="/var/ipfire/dns/dnsbl"

LOG_FILE="$DEFAULT_LOG"
OUTPUT_FILE="$DEFAULT_OUTPUT"
NUMBER="$DEFAULT_NUMBER"

LIB="$(dirname "$(readlink -f "$0")")/report-lib.sh"
[[ -f "$LIB" ]] || LIB="/var/ipfire/reports/report-lib.sh"
# shellcheck source=/var/ipfire/reports/report-lib.sh
source "$LIB"

# Cargar el idioma del GUI (debe hacerse en el shell principal para que $(t) lo herede)
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
    DNSFW_ENABLED=$(grep -a "^DNSFW=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_HOUR=$(grep -a "^SCOPE_HOUR=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_DAY=$(grep -a "^SCOPE_DAY=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_WEEK=$(grep -a "^SCOPE_WEEK=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_MONTH=$(grep -a "^SCOPE_MONTH=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)

    if [[ "$DNSFW_ENABLED" != "on" ]]; then
        echo "Error: Los informes del DNS Firewall están deshabilitados en la configuración"
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



# Patrones de fecha para /var/log/messages: "May 22"
generate_date_patterns() {
    case "$TIME_SCOPE" in
        "hour")
            echo "($(date '+%b %_d %H:')|$(date -d '1 hour ago' '+%b %_d %H:'))" ;;
        "day")
            echo "($(date '+%b %_d')|$(date -d '1 day ago' '+%b %_d'))" ;;
        "week")
            local pattern=""
            for i in {0..6}; do
                local d=$(date -d "$i days ago" '+%b %_d')
                pattern="${pattern:+$pattern|}$d"
            done
            echo "($pattern)" ;;
        "month")
            local pattern=""
            for i in {0..29}; do
                local d=$(date -d "$i days ago" '+%b %_d')
                pattern="${pattern:+$pattern|}$d"
            done
            echo "($pattern)" ;;
    esac
}

# Filtrar logs por tiempo y quedarnos con los bloqueos RPZ (sin 127.0.0.1)
filter_logs_by_time() {
    local temp_log="/var/tmp/filtered_dnsfw_log.$$"
    local files_to_process date_pattern
    read -a files_to_process <<< "$(get_log_files)"
    date_pattern=$(generate_date_patterns)
    > "$temp_log"
    for log_file in "${files_to_process[@]}"; do
        if [[ "$log_file" == *.gz ]]; then
            zcat "$log_file" 2>/dev/null | grep -a -F 'info: rpz: applied' | grep -a -E "$date_pattern" | grep -av '127\.0\.0\.1@' >> "$temp_log"
        else
            grep -a -F 'info: rpz: applied' "$log_file" 2>/dev/null | grep -a -E "$date_pattern" | grep -av '127\.0\.0\.1@' >> "$temp_log"
        fi
    done
    [[ ! -s "$temp_log" ]] && echo "Advertencia: No se encontraron bloqueos del DNS Firewall en el periodo $TIME_DESCRIPTION"
    FILTERED_LOG="$temp_log"
}

# Parsear a:  lista|ip_cliente|dominio
# Solo se cuentan BLOQUEOS reales (se excluye rpz-passthru / lista blanca) y
# solo de zonas RPZ marcadas como "on" en el archivo dnsbl (se ignoran zonas
# ajenas como "adGuard" o "allow" que no estén en la configuración).
parse_blocks() {
    PARSED="/var/tmp/dnsfw_parsed.$$"
    local on_lists
    on_lists=$(grep -aE '^[^,]+,on,' "$DNSBL_FILE" 2>/dev/null | cut -d',' -f1)
    # Campos extraídos: zona | acción | ip_cliente | dominio_consultado
    sed -nE 's/.*applied \[([^]]+)\] [^ ]+ ([^ ]+) ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)@[0-9]+ ([^ ]+).*/\1|\2|\3|\4/p' "$FILTERED_LOG" \
        | awk -F'|' -v ok="$on_lists" '
            BEGIN { n=split(ok,a,"\n"); for(i=1;i<=n;i++) if(a[i]!="") allow[a[i]]=1 }
            $2 !~ /passthru/ && ($1 in allow) { d=$4; sub(/\.$/,"",d); print $1"|"$3"|"d }
          ' > "$PARSED"
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
parse_blocks

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
[[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"

# Estadísticas
TOTAL_BLOCKS=$(wc -l < "$PARSED" 2>/dev/null || echo "0")
UNIQUE_DOMAINS=$(cut -d'|' -f3 "$PARSED" 2>/dev/null | sort -u | grep -vc '^$')
UNIQUE_CLIENTS=$(cut -d'|' -f2 "$PARSED" 2>/dev/null | sort -u | grep -vc '^$')
ACTIVE_LISTS=$(grep -cE '^[^,]+,on,' "$DNSBL_FILE" 2>/dev/null)

FORMATTED_TOTAL=$(ipfr_format_number "$TOTAL_BLOCKS")
FORMATTED_DOMAINS=$(ipfr_format_number "$UNIQUE_DOMAINS")
FORMATTED_CLIENTS=$(ipfr_format_number "$UNIQUE_CLIENTS")

# Conteos por lista, dominio y cliente
LIST_COUNTS=$(cut -d'|' -f1 "$PARSED" 2>/dev/null | sort | uniq -c | sort -nr)
DOMAIN_COUNTS=$(cut -d'|' -f3 "$PARSED" 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -nr)
CLIENT_COUNTS=$(cut -d'|' -f2 "$PARSED" 2>/dev/null | sort | uniq -c | sort -nr)

# Nombres descriptivos de categorías RPZ, localizados según el idioma del GUI.
# Se construye "id=Nombre;..." y se pasa a awk con -v cats=
CAT_KV=""
for _cid in porn ads dating doh gambling games malware phishing piracy shopping smart-tv social streaming violence; do
    case "$_cid" in
        porn)      _cdef="Pornografía";;
        ads)       _cdef="Publicidad";;
        dating)    _cdef="Citas";;
        doh)       _cdef="DNS-over-HTTPS público";;
        gambling)  _cdef="Apuestas";;
        games)     _cdef="Juegos";;
        malware)   _cdef="Malware";;
        phishing)  _cdef="Phishing";;
        piracy)    _cdef="Piratería";;
        shopping)  _cdef="Compras";;
        smart-tv)  _cdef="Smart TV";;
        social)    _cdef="Redes sociales";;
        streaming) _cdef="Streaming";;
        violence)  _cdef="Violencia";;
    esac
    CAT_KV+="${_cid}=$(t "reports cat ${_cid}" "$_cdef");"
done

# friendly(): traduce el ID de lista RPZ a su nombre localizado (lee la var awk "cats")
DNS_FRIENDLY='function friendly(id,  n,i,nc,arr,eq){
    if(!_cm_done){ nc=split(cats,arr,";"); for(i=1;i<=nc;i++){ if(arr[i]!=""){ eq=index(arr[i],"="); _cm[substr(arr[i],1,eq-1)]=substr(arr[i],eq+1) } } _cm_done=1 }
    n=id; sub(/\..*/,"",n); return (n in _cm)?_cm[n]:n }'

# ----------------------- Generación del informe ----------------------------
SEC_TOPDOMAINS="TOP $NUMBER $(t 'reports dnsfw sec topdomains' 'dominios bloqueados')"
TH_BLOCKS="$(t 'reports th blocks' 'Bloqueos')"
TH_PCT="$(t 'reports th pct' '%')"
{
ipfr_doc_open "dns" "&#x1F6AB;" "$(t 'reports dnsfw title' 'Informe del DNS Firewall') &mdash; TOP $NUMBER" \
    "$(t 'reports generated on' 'Generado el') $(date '+%d/%m/%Y %H:%M') &middot; $(t 'reports period word' 'Periodo'): $TIME_DESCRIPTION &middot; RPZ / unbound"

ipfr_stats_open
ipfr_stat red    "$(t 'reports dnsfw stat blocks' 'Bloqueos totales')"  "$FORMATTED_TOTAL"   "$(t 'reports dnsfw stat blocks d' 'Consultas DNS bloqueadas')"
ipfr_stat blue   "$(t 'reports dnsfw stat domains' 'Dominios únicos')"  "$FORMATTED_DOMAINS" "$(t 'reports dnsfw stat domains d' 'Dominios distintos bloqueados')"
ipfr_stat purple "$(t 'reports dnsfw stat clients' 'Clientes únicos')"  "$FORMATTED_CLIENTS" "$(t 'reports dnsfw stat clients d' 'Equipos que solicitaron')"
ipfr_stat green  "$(t 'reports dnsfw stat lists' 'Listas activas')"     "$ACTIVE_LISTS"      "$(t 'reports dnsfw stat lists d' 'Listas RPZ habilitadas')"
ipfr_stats_close

ipfr_section "&#x1F4CA;" "$(t 'reports sec overview' 'Visión general')"
ipfr_grid_open
echo "$LIST_COUNTS" | awk -v cats="$CAT_KV" "$DNS_FRIENDLY"'BEGIN{split("#dc143c #0d6efd #22a559 #f59e0b #6f42c1 #17a2b8",c," ")} NF>=2 && NR<=6 { print friendly($2)"|"$1"|"c[((NR-1)%6)+1] }' \
    | ipfr_donut "$(t 'reports dnsfw donut title' 'Bloqueos por lista')" "$(t 'reports dnsfw donut sub' 'Reparto por lista RPZ (TOP 6)')" "$(t 'reports dnsfw unit blocks' 'bloqueos')"
echo "$DOMAIN_COUNTS" | awk 'NF>=2{print $2"|"$1}' \
    | ipfr_hbars "$SEC_TOPDOMAINS" "$(t 'reports dnsfw bars sub' 'Dominios con más bloqueos')" "#0d9488"
ipfr_grid_close

# Mapa de calor día x hora (mismas reglas: listas "on" del dnsbl, sin passthru)
if [[ "$TIME_SCOPE" != "hour" ]]; then
    case "$TIME_SCOPE" in day) _HN=1 ;; week) _HN=7 ;; month) _HN=30 ;; *) _HN=7 ;; esac
    _HDAYS=""; for ((_i=_HN-1; _i>=0; _i--)); do _HDAYS+="$(date -d "$_i days ago" '+%Y-%m-%d') "; done
    _ON=$(grep -aE '^[^,]+,on,' "$DNSBL_FILE" 2>/dev/null | cut -d',' -f1)
    ipfr_section "&#x1F4C5;" "$(t 'reports heatmap title' 'Actividad por hora y día')"
    awk -v year="$(date '+%Y')" -v ok="$_ON" 'BEGIN{split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec",mm," ");for(i=1;i<=12;i++)mn[mm[i]]=sprintf("%02d",i); n=split(ok,a,"\n");for(i=1;i<=n;i++)if(a[i]!="")allow[a[i]]=1} { zone=$10; gsub(/^\[|\]$/,"",zone); if(($1 in mn) && (zone in allow) && $12 !~ /passthru/) printf "%s-%s-%02d\t%s\n",year,mn[$1],$2,substr($3,1,2) }' "$FILTERED_LOG" \
        | ipfr_heatmap "" "$(t 'reports heatmap caption' 'Cada celda es una hora de un día concreto; cuanto más oscuro, mayor actividad. Útil para ver si hay franjas más activas.')" "#0d9488" "$_HDAYS"
fi

ipfr_section "&#x1F310;" "$SEC_TOPDOMAINS"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports th domain' 'Dominio')</th><th>$TH_BLOCKS</th><th>$TH_PCT</th></tr></thead><tbody>"
if [[ "$TOTAL_BLOCKS" -gt 0 ]]; then
    echo "$DOMAIN_COUNTS" | head -n "$NUMBER" | awk -v total="$TOTAL_BLOCKS" 'BEGIN{pos=1} NF>=2 {
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        d=$2; gsub(/&/,"\\&amp;",d); gsub(/</,"\\&lt;",d); gsub(/>/,"\\&gt;",d);
        if(length(d)>40) d=substr(d,1,37) "...";
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", pos, d, formatted, percent;
        pos++;
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports dnsfw empty' 'Sin bloqueos para el periodo') ($TIME_DESCRIPTION)</td></tr>"
fi
echo '</tbody></table>'

ipfr_section "&#x1F4BB;" "TOP $NUMBER $(t 'reports dnsfw sec topclients' 'clientes con más bloqueos')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports th client ip' 'IP cliente')</th><th>$TH_BLOCKS</th><th>$TH_PCT</th></tr></thead><tbody>"
if [[ "$TOTAL_BLOCKS" -gt 0 ]]; then
    echo "$CLIENT_COUNTS" | head -n "$NUMBER" | awk -v total="$TOTAL_BLOCKS" 'BEGIN{pos=1} NF>=2 {
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", pos, $2, formatted, percent;
        pos++;
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_section "&#x1F6E1;&#xFE0F;" "$(t 'reports dnsfw sec listactivity' 'Actividad por lista RPZ')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports dnsfw th list' 'Lista')</th><th>$TH_BLOCKS</th><th>$TH_PCT</th></tr></thead><tbody>"
if [[ "$TOTAL_BLOCKS" -gt 0 ]]; then
    echo "$LIST_COUNTS" | awk -v total="$TOTAL_BLOCKS" -v cats="$CAT_KV" "$DNS_FRIENDLY"'BEGIN{pos=1} NF>=2 {
        percent=(total>0)?($1/total*100):0; formatted=sprintf("%\047d",$1);
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td><span class=\"ipfr-tag ipfr-tag--cyan\">%s</span> <span style=\"color:#6b7785;font-size:11px\">%s</span></td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", pos, friendly($2), $2, formatted, percent;
        pos++;
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_doc_close "<strong>IPFire</strong> $(t 'reports footer system' 'Reports System') &middot; DNS Firewall (RPZ / unbound) &middot; $(t 'reports footer period' 'periodo'): <strong>$TIME_DESCRIPTION</strong> &middot; $(t 'reports dnsfw footer lists' 'listas activas'): $ACTIVE_LISTS"
} > "$OUTPUT_FILE"

# Limpieza (solo nuestros temporales)
[[ -f "$FILTERED_LOG" ]] && rm -f "$FILTERED_LOG"
[[ -f "$PARSED" ]] && rm -f "$PARSED"
rm -f /var/tmp/filtered_dnsfw_log.$$ /var/tmp/dnsfw_parsed.$$ 2>/dev/null

echo "Informe del DNS Firewall generado: $OUTPUT_FILE"
exit 0
