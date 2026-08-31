#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Generador de Informes del DNS Firewall (UTF-8)                 #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Informe del DNS Firewall (RPZ sobre knot-resolver/kresd). Analiza            #
# /var/log/messages buscando "kresd: ... local data applied, user: IP,        #
# name: dominio" e ignora las peticiones internas (127.0.0.1 / ::1). La        #
# categoría de cada dominio se obtiene de los ficheros de zona RPZ locales     #
# (/var/lib/knot-resolver/zones), sin consultar la red. Maquetación moderna    #
# y gráficas SVG vía report-lib.sh. Sin JavaScript ni dependencias.           #
#                                                                             #
###############################################################################

# Configuración por defecto
DEFAULT_LOG="/var/log/messages"
DEFAULT_OUTPUT="/var/ipfire/reports/reports/dnsfw-report.html"
DEFAULT_NUMBER=10
CONFIG_FILE="/var/ipfire/reports/settings"
DNSBL_FILE="/var/ipfire/dns/dnsbl"
# Zonas RPZ que descarga knot-resolver. Cada dominio bloqueado se almacena como
# "<dominio>.<categoría>.rpz.ipfire.org. CNAME ." (más su comodín "*.<dominio>…").
ZONES_DIR="/var/lib/knot-resolver/zones"

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

# Filtrar logs por tiempo y quedarnos con los bloqueos de kresd
# ("local data applied"), descartando las consultas internas del propio
# resolutor (127.0.0.1 / ::1) para no contar duplicados.
filter_logs_by_time() {
    local temp_log="/var/tmp/filtered_dnsfw_log.$$"
    local files_to_process date_pattern
    read -a files_to_process <<< "$(get_log_files)"
    date_pattern=$(generate_date_patterns)
    > "$temp_log"
    for log_file in "${files_to_process[@]}"; do
        if [[ "$log_file" == *.gz ]]; then
            zcat "$log_file" 2>/dev/null | grep -a -F 'local data applied' | grep -a -E "$date_pattern" | grep -avE 'user: (127\.0\.0\.1|::1),' >> "$temp_log"
        else
            grep -a -F 'local data applied' "$log_file" 2>/dev/null | grep -a -E "$date_pattern" | grep -avE 'user: (127\.0\.0\.1|::1),' >> "$temp_log"
        fi
    done
    [[ ! -s "$temp_log" ]] && echo "Advertencia: No se encontraron bloqueos del DNS Firewall en el periodo $TIME_DESCRIPTION"
    FILTERED_LOG="$temp_log"
}

# Parsear a:  categoria|ip_cliente|dominio
# 1) Extrae (cliente, dominio) de cada línea de bloqueo de kresd.
# 2) Determina la categoría de cada dominio buscándolo (y sus dominios padre,
#    para cubrir los comodines "*.dominio") en los ficheros de zona RPZ locales,
#    quedándose con la coincidencia más específica.
# 3) Solo se cuentan dominios presentes en alguna zona RPZ (bloqueos reales);
#    los overrides locales de DNS que no son listas RPZ se descartan.
parse_blocks() {
    PARSED="/var/tmp/dnsfw_parsed.$$"
    local pairs="/var/tmp/dnsfw_pairs.$$"
    local map="/var/tmp/dnsfw_catmap.$$"

    # (cliente | dominio) por cada línea de bloqueo (dominio sin punto final)
    sed -nE 's/.*local data applied, user: ([^,]+), name: ([^ ]+).*/\1|\2/p' "$FILTERED_LOG" \
        | awk -F'|' '{ c=$1; d=$2; gsub(/\r/,"",d); sub(/\.+$/,"",d); gsub(/ /,"",c); if(c!="" && d!="") print c"|"d }' > "$pairs"

    if [[ ! -s "$pairs" ]]; then
        : > "$PARSED"; rm -f "$pairs" "$map"; return
    fi

    # Dominios únicos -> categoría, con una sola pasada por cada zona RPZ local.
    local zones=( "$ZONES_DIR"/*.rpz.ipfire.org.zone )
    if [[ -e "${zones[0]}" ]]; then
        cut -d'|' -f2 "$pairs" | sort -u | awk '
            # Primer fichero (stdin): dominios consultados. Registra cada dominio
            # y todos sus dominios padre (para casar con los comodines).
            FNR==NR {
                q=$0; order[++nq]=q; want[q]=1;
                a=q; while((i=index(a,"."))>0){ a=substr(a,i+1); if(a!="") want[a]=1 }
                next
            }
            # Ficheros de zona: líneas "<owner> CNAME ."
            {
                owner=$1; sub(/\.$/,"",owner); sub(/^\*\./,"",owner);
                if(owner !~ /\.rpz\.ipfire\.org$/) next;
                sub(/\.rpz\.ipfire\.org$/,"",owner);   # -> "<dominio>.<categoría>"
                di=0; for(k=length(owner);k>=1;k--) if(substr(owner,k,1)=="."){ di=k; break }
                if(di==0) next;
                base=substr(owner,1,di-1); cat=substr(owner,di+1);
                if((base in want) && !(base in cat2)) cat2[base]=cat;
            }
            END {
                for(qi=1;qi<=nq;qi++){
                    q=order[qi]; a=q; bcat="";
                    do { if(a in cat2){ bcat=cat2[a]; break }
                         i=index(a,"."); if(i==0) break; a=substr(a,i+1) } while(a!="");
                    if(bcat!="") print q"|"bcat;
                }
            }
        ' - "${zones[@]}" > "$map"
    else
        : > "$map"
    fi

    # Unir: por cada (cliente, dominio) con categoría conocida -> categoria|cliente|dominio
    awk -F'|' '
        FNR==NR { cat[$1]=$2; next }
        ($2 in cat) { print cat[$2]"|"$1"|"$2 }
    ' "$map" "$pairs" > "$PARSED"

    rm -f "$pairs" "$map"
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

# Conjunto de dominios que sí son bloqueos RPZ reales (para el mapa de calor)
BLOCK_DOMAINS="/var/tmp/dnsfw_domains.$$"
cut -d'|' -f3 "$PARSED" 2>/dev/null | grep -v '^$' | sort -u > "$BLOCK_DOMAINS"

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

# Diccionario de nombres de categoría y función awk friendly() (compartidos con
# el URL Filter; definidos en report-lib.sh). Se pasan a awk con -v cats=…
CAT_KV="$(ipfr_cat_kv)"
DNS_FRIENDLY="$(ipfr_awk_friendly)"

# ----------------------- Generación del informe ----------------------------
SEC_TOPDOMAINS="TOP $NUMBER $(t 'reports dnsfw sec topdomains' 'dominios bloqueados')"
TH_BLOCKS="$(t 'reports th blocks' 'Bloqueos')"
TH_PCT="$(t 'reports th pct' '%')"
{
ipfr_doc_open "dns" "&#x1F6AB;" "$(t 'reports dnsfw title' 'Informe del DNS Firewall') &mdash; TOP $NUMBER" \
    "$(t 'reports generated on' 'Generado el') $(date '+%d/%m/%Y %H:%M') &middot; $(t 'reports period word' 'Periodo'): $TIME_DESCRIPTION &middot; DNS Firewall / kresd"

ipfr_stats_open
ipfr_stat red    "$(t 'reports dnsfw stat blocks' 'Bloqueos totales')"  "$FORMATTED_TOTAL"   "$(t 'reports dnsfw stat blocks d' 'Consultas DNS bloqueadas')"
ipfr_stat blue   "$(t 'reports dnsfw stat domains' 'Dominios únicos')"  "$FORMATTED_DOMAINS" "$(t 'reports dnsfw stat domains d' 'Dominios distintos bloqueados')"
ipfr_stat purple "$(t 'reports dnsfw stat clients' 'Clientes únicos')"  "$FORMATTED_CLIENTS" "$(t 'reports dnsfw stat clients d' 'Equipos que solicitaron')"
ipfr_stat green  "$(t 'reports dnsfw stat lists' 'Listas activas')"     "$ACTIVE_LISTS"      "$(t 'reports dnsfw stat lists d' 'Listas del DNS Firewall habilitadas')"
ipfr_stats_close

ipfr_section "&#x1F4CA;" "$(t 'reports sec overview' 'Visión general')"
ipfr_grid_open
echo "$LIST_COUNTS" | awk -v cats="$CAT_KV" "$DNS_FRIENDLY"'BEGIN{split("#dc143c #0d6efd #22a559 #f59e0b #6f42c1 #17a2b8",c," ")} NF>=2 && NR<=6 { print friendly($2)"|"$1"|"c[((NR-1)%6)+1] }' \
    | ipfr_donut "$(t 'reports dnsfw donut title' 'Bloqueos por lista')" "$(t 'reports dnsfw donut sub' 'Reparto por lista del DNS Firewall (TOP 6)')" "$(t 'reports dnsfw unit blocks' 'bloqueos')"
echo "$DOMAIN_COUNTS" | awk 'NF>=2{print $2"|"$1}' \
    | ipfr_hbars "$SEC_TOPDOMAINS" "$(t 'reports dnsfw bars sub' 'Dominios con más bloqueos')" "#0d9488"
ipfr_grid_close

# Mapa de calor día x hora (solo bloqueos RPZ reales, coherente con los conteos)
if [[ "$TIME_SCOPE" != "hour" ]]; then
    case "$TIME_SCOPE" in day) _HN=1 ;; week) _HN=7 ;; month) _HN=30 ;; *) _HN=7 ;; esac
    _HDAYS=""; for ((_i=_HN-1; _i>=0; _i--)); do _HDAYS+="$(date -d "$_i days ago" '+%Y-%m-%d') "; done
    ipfr_section "&#x1F4C5;" "$(t 'reports heatmap title' 'Actividad por hora y día')"
    awk -v year="$(date '+%Y')" '
        BEGIN{ split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec",mm," "); for(i=1;i<=12;i++) mn[mm[i]]=sprintf("%02d",i) }
        FNR==NR { bd[$0]=1; next }
        {
            if(!($1 in mn)) next;
            dom="";
            if(match($0,/name: [^ ]+/)){ dom=substr($0,RSTART+6,RLENGTH-6); sub(/\.+$/,"",dom) }
            if(dom!="" && (dom in bd)) printf "%s-%s-%02d\t%s\n",year,mn[$1],$2,substr($3,1,2);
        }' "$BLOCK_DOMAINS" "$FILTERED_LOG" \
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

ipfr_section "&#x1F6E1;&#xFE0F;" "$(t 'reports dnsfw sec listactivity' 'Actividad por lista del DNS Firewall')"
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

ipfr_doc_close "<strong>IPFire</strong> $(t 'reports footer system' 'Reports System') &middot; DNS Firewall (kresd) &middot; $(t 'reports footer period' 'periodo'): <strong>$TIME_DESCRIPTION</strong> &middot; $(t 'reports dnsfw footer lists' 'listas activas'): $ACTIVE_LISTS"
} > "$OUTPUT_FILE"

# Limpieza (solo nuestros temporales)
[[ -f "$FILTERED_LOG" ]] && rm -f "$FILTERED_LOG"
[[ -f "$PARSED" ]] && rm -f "$PARSED"
[[ -f "$BLOCK_DOMAINS" ]] && rm -f "$BLOCK_DOMAINS"
rm -f /var/tmp/filtered_dnsfw_log.$$ /var/tmp/dnsfw_parsed.$$ /var/tmp/dnsfw_pairs.$$ /var/tmp/dnsfw_catmap.$$ /var/tmp/dnsfw_domains.$$ 2>/dev/null

echo "Informe del DNS Firewall generado: $OUTPUT_FILE"
exit 0
