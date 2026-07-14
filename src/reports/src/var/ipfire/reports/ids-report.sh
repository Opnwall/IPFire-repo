#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Generador de Informes de IDS/IPS (UTF-8)                       #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Informe TOP del IDS/IPS (Suricata) con maquetación moderna y gráficas SVG   #
# (donut + barras) servidas por report-lib.sh. Geolocalización con el comando #
# 'location' de IPFire. Sin JavaScript ni dependencias.                       #
#                                                                             #
###############################################################################

# Configuración por defecto
DEFAULT_LOG="/var/log/suricata/fast.log"
DEFAULT_OUTPUT="/var/ipfire/reports/reports/ids-report.html"
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
    IDS_ENABLED=$(grep -a "^IDS=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_HOUR=$(grep -a "^SCOPE_HOUR=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_DAY=$(grep -a "^SCOPE_DAY=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_WEEK=$(grep -a "^SCOPE_WEEK=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_MONTH=$(grep -a "^SCOPE_MONTH=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)

    if [[ "$IDS_ENABLED" != "on" ]]; then
        echo "Error: Los informes de IDS/IPS están deshabilitados en la configuración"
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



# Patrones de fecha para Suricata: MM/DD/YYYY-HH:
generate_date_patterns() {
    case "$TIME_SCOPE" in
        "hour")
            echo "($(date '+%m/%d/%Y-%H:')|$(date -d '1 hour ago' '+%m/%d/%Y-%H:'))" ;;
        "day")
            echo "($(date '+%m/%d/%Y')|$(date -d '1 day ago' '+%m/%d/%Y'))" ;;
        "week")
            local pattern=""
            for i in {0..6}; do
                local d=$(date -d "$i days ago" '+%m/%d/%Y')
                pattern="${pattern:+$pattern|}$d"
            done
            echo "($pattern)" ;;
        "month")
            local pattern=""
            for i in {0..29}; do
                local d=$(date -d "$i days ago" '+%m/%d/%Y')
                pattern="${pattern:+$pattern|}$d"
            done
            echo "($pattern)" ;;
    esac
}

filter_logs_by_time() {
    local temp_log="/var/tmp/filtered_ids_log.$$"
    local files_to_process date_pattern
    read -a files_to_process <<< "$(get_log_files)"
    date_pattern=$(generate_date_patterns)
    > "$temp_log"
    for log_file in "${files_to_process[@]}"; do
        if [[ "$log_file" == *.gz ]]; then
            zcat "$log_file" 2>/dev/null | grep -a -E "\[Drop\]|\[Alert\]" | grep -a -E "$date_pattern" >> "$temp_log"
        else
            grep -a -E "\[Drop\]|\[Alert\]" "$log_file" 2>/dev/null | grep -a -E "$date_pattern" >> "$temp_log"
        fi
    done
    [[ ! -s "$temp_log" ]] && echo "Advertencia: No se encontraron eventos IDS/IPS en el periodo $TIME_DESCRIPTION"
    FILTERED_LOG="$temp_log"
}

calculate_correct_metrics() {
    local temp_ip="/var/tmp/ip_extractions.$$"
    grep -a -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+ -> [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" "$FILTERED_LOG" | \
        cut -d' ' -f1 | cut -d':' -f1 > "$temp_ip"
    TOTAL_IPS_EXTRACTED=$(wc -l < "$temp_ip" 2>/dev/null || echo "0")
    rm -f "$temp_ip"
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
TOTAL_ALERTS=$(wc -l < "$FILTERED_LOG" 2>/dev/null || echo "0")
HIGH_PRIORITY=$(grep -a -c "\[Priority: [123]\]" "$FILTERED_LOG" 2>/dev/null)
MEDIUM_PRIORITY=$(grep -a -c "\[Priority: [456]\]" "$FILTERED_LOG" 2>/dev/null)
LOW_PRIORITY=$(grep -a -c "\[Priority: [789]\]" "$FILTERED_LOG" 2>/dev/null)
TOTAL_DROPS=$(grep -a -c "\[Drop\]" "$FILTERED_LOG" 2>/dev/null)
calculate_correct_metrics

# Categorías de ataque
classification_count=$(grep -a -c '\[Classification:' "$FILTERED_LOG")
if [ "$classification_count" -gt 0 ]; then
    attack_categories=$(grep -a -o '\[Classification: [^]]*\]' "$FILTERED_LOG" | \
        sed 's/\[Classification: \(.*\)\]/\1/' | sort | uniq -c | sort -nr | head -10)
else
    attack_categories=$(grep -a -o 'ET [A-Z][A-Z_]* [^]]*' "$FILTERED_LOG" | \
        sed 's/ET \([A-Z][A-Z_]*\) .*/\1/' | sort | uniq -c | sort -nr | head -10)
fi

FORMATTED_ALERTS=$(ipfr_format_number "$TOTAL_ALERTS")
FORMATTED_DROPS=$(ipfr_format_number "$TOTAL_DROPS")
FORMATTED_HIGH=$(ipfr_format_number "$HIGH_PRIORITY")
FORMATTED_MEDIUM=$(ipfr_format_number "$MEDIUM_PRIORITY")
FORMATTED_LOW=$(ipfr_format_number "$LOW_PRIORITY")

# TOP IPs de origen (para barras)
TOP_SRC=$(grep -a -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+ -> [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" "$FILTERED_LOG" | \
    cut -d' ' -f1 | cut -d':' -f1 | sort | uniq -c | sort -nr | head -n "$NUMBER")

# ----------------------- Generación del informe ----------------------------
{
PRIO_CRIT="$(t 'reports ids prio crit' 'Críticas')"
PRIO_MED="$(t 'reports ids prio med' 'Medias')"
PRIO_LOW="$(t 'reports ids prio low' 'Bajas')"
SEC_SOURCES="TOP $NUMBER $(t 'reports ids sec sources' 'orígenes de ataque')"
ipfr_doc_open "ids" "&#x1F6E1;&#xFE0F;" "$(t 'reports ids title' 'Informe IDS/IPS') &mdash; TOP $NUMBER" \
    "$(t 'reports generated on' 'Generado el') $(date '+%d/%m/%Y %H:%M') &middot; $(t 'reports period word' 'Periodo'): $TIME_DESCRIPTION &middot; $(t 'reports ids engine' 'Motor'): Suricata"

ipfr_stats_open
ipfr_stat purple "$(t 'reports ids stat alerts' 'Alertas totales')" "$FORMATTED_ALERTS"  "$(t 'reports ids stat alerts d' 'Todas las detecciones')"
ipfr_stat red    "$(t 'reports ids stat drops' 'Paquetes drop')"     "$FORMATTED_DROPS"   "$(t 'reports ids stat drops d' 'Bloqueados por el IPS')"
ipfr_stat red    "$PRIO_CRIT"                                        "$FORMATTED_HIGH"    "$(t 'reports ids prio crit d' 'Prioridad 1-3 (alto riesgo)')"
ipfr_stat orange "$PRIO_MED"                                         "$FORMATTED_MEDIUM"  "$(t 'reports ids prio med d' 'Prioridad 4-6 (riesgo medio)')"
ipfr_stat green  "$PRIO_LOW"                                         "$FORMATTED_LOW"     "$(t 'reports ids prio low d' 'Prioridad 7-9 (bajo riesgo)')"
ipfr_stats_close

ipfr_section "&#x1F4CA;" "$(t 'reports sec overview' 'Visión general')"
ipfr_grid_open
printf '%s\n' "$PRIO_CRIT|$HIGH_PRIORITY|#dc2626" "$PRIO_MED|$MEDIUM_PRIORITY|#f59e0b" "$PRIO_LOW|$LOW_PRIORITY|#22a559" \
    | ipfr_donut "$(t 'reports ids donut title' 'Alertas por prioridad')" "$(t 'reports ids donut sub' 'Severidad de las detecciones')" "$(t 'reports ids unit alerts' 'alertas')"
echo "$TOP_SRC" | awk 'NF>=2{print $2"|"$1}' \
    | ipfr_hbars "$SEC_SOURCES" "$(t 'reports ids bars sub' 'IPs de origen con más alertas')" "#6f42c1"
ipfr_grid_close

# Mapa de calor día x hora (salvo en alcance de 1 hora)
if [[ "$TIME_SCOPE" != "hour" ]]; then
    case "$TIME_SCOPE" in day) _HN=1 ;; week) _HN=7 ;; month) _HN=30 ;; *) _HN=7 ;; esac
    _HDAYS=""; for ((_i=_HN-1; _i>=0; _i--)); do _HDAYS+="$(date -d "$_i days ago" '+%Y-%m-%d') "; done
    ipfr_section "&#x1F4C5;" "$(t 'reports heatmap title' 'Actividad por hora y día')"
    grep -a -oE '^[0-9]{2}/[0-9]{2}/[0-9]{4}-[0-9]{2}' "$FILTERED_LOG" | awk -F'[/-]' '{print $3"-"$1"-"$2"\t"$4}' \
        | ipfr_heatmap "" "$(t 'reports heatmap caption' 'Cada celda es una hora de un día concreto; cuanto más oscuro, mayor actividad. Útil para ver si hay franjas más activas.')" "#6f42c1" "$_HDAYS"
fi

# TOP orígenes con geolocalización (tabla detallada)
ipfr_section "&#x1F30D;" "$SEC_SOURCES $(t 'reports ids geo suffix' '(geolocalizados)')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports ids th srcip' 'IP origen')</th><th>$(t 'reports ids th alerts' 'Alertas')</th><th>$(t 'reports th pct' '%')</th><th>$(t 'reports ids th location' 'Ubicación')</th></tr></thead><tbody>"
if [[ "$TOTAL_ALERTS" -gt 0 ]]; then
    echo "$TOP_SRC" | \
    awk -v total="$TOTAL_IPS_EXTRACTED" -v gu="$(t 'reports ids geo unknown' 'Desconocido')" -v gp="$(t 'reports ids geo private' 'Privada RFC1918')" -v gn="$(t 'reports ids geo noloc' 'Sin localizar')" 'BEGIN{pos=1} NF>=2 {
        count=$1; ip=$2; formatted=sprintf("%\047d",count);
        percent=(total>0)?(count/total*100):0;
        country=gu;
        n=split(ip,p,".");
        if(n==4){
            ip1=int(p[1]); ip2=int(p[2]);
            if(ip1==192&&ip2==168) country=gp;
            else if(ip1==10) country=gp;
            else if(ip1==172&&ip2>=16&&ip2<=31) country=gp;
            else if(ip1==127) country="Localhost";
            else {
                cmd="timeout 3 location lookup " ip " 2>/dev/null | grep Country | cut -d: -f2 | sed \"s/^[[:space:]]*//\" | sed \"s/[[:space:]]*$//\"";
                cmd | getline dc; close(cmd);
                if(dc!="" && dc!="Unknown"){
                    cc="";
                    if(dc=="Netherlands")cc="nl"; else if(dc=="United States")cc="us"; else if(dc=="Germany")cc="de";
                    else if(dc=="United Kingdom")cc="gb"; else if(dc=="France")cc="fr"; else if(dc=="China")cc="cn";
                    else if(dc=="Russia")cc="ru"; else if(dc=="Japan")cc="jp"; else if(dc=="Brazil")cc="br";
                    else if(dc=="Canada")cc="ca"; else if(dc=="Australia")cc="au"; else if(dc=="Spain")cc="es";
                    else if(dc=="Italy")cc="it"; else if(dc=="India")cc="in";
                    if(cc!=""){
                        fp="/srv/web/ipfire/html/images/flags/" cc ".png";
                        if((getline _ < fp)>=0){ close(fp);
                            country="<img src=\"/images/flags/" cc ".png\" alt=\"" dc "\" style=\"width:16px;height:12px;vertical-align:middle;margin-right:5px\">" dc;
                        } else country=dc;
                    } else country=dc;
                } else country=gn;
            }
        }
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td><td><span class=\"ipfr-tag ipfr-tag--blue\">%s</span></td></tr>\n", pos, ip, formatted, percent, country;
        pos++;
    }'
else
    echo "<tr><td colspan=\"5\" class=\"ipfr-empty\">$(t 'reports ids empty' 'Sin alertas IDS/IPS para el periodo') ($TIME_DESCRIPTION)</td></tr>"
fi
echo '</tbody></table>'

# TOP reglas activadas
ipfr_section "&#x1F6A8;" "TOP $NUMBER $(t 'reports ids sec rules' 'reglas más activadas')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports ids th ruleid' 'ID regla')</th><th>$(t 'reports ids th desc' 'Descripción')</th><th>$(t 'reports ids th triggers' 'Activaciones')</th><th>$(t 'reports ids th priority' 'Prioridad')</th></tr></thead><tbody>"
if [[ "$TOTAL_ALERTS" -gt 0 ]]; then
    grep -a -oE "\[[0-9]+:[0-9]+:[0-9]+\].*\[Priority: [0-9]+\]" "$FILTERED_LOG" | \
    sed 's/\[\([0-9]*:[0-9]*:[0-9]*\)\] \(.*\) \[Priority: \([0-9]*\)\]/\1|\2|\3/' | \
    sort | uniq -c | sort -nr | head -n "$NUMBER" | \
    awk 'BEGIN{pos=1} {
        count=$1; gsub(/^ *[0-9]+ /,"",$0); split($0,parts,"|");
        rule_id=parts[1]; description=parts[2]; priority=parts[3];
        formatted=sprintf("%\047d",count);
        gsub(/^\s+|\s+$/,"",description);
        gsub(/&/,"\\&amp;",description); gsub(/</,"\\&lt;",description); gsub(/>/,"\\&gt;",description);
        if(length(description)>52) description=substr(description,1,49) "...";
        cls="ipfr-badge--lo"; lab=priority;
        if(priority ~ /^[0-9]+$/){ pn=int(priority);
            if(pn<=3) cls="ipfr-badge--hi"; else if(pn<=6) cls="ipfr-badge--md"; else cls="ipfr-badge--lo";
        } else { cls="ipfr-badge--lo"; lab="N/A" }
        printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td>%s</td><td class=\"ipfr-num\">%s</td><td><span class=\"ipfr-badge %s\">%s</span></td></tr>\n", pos, rule_id, description, formatted, cls, lab;
        pos++;
    }'
else
    echo "<tr><td colspan=\"5\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

# TOP categorías
ipfr_section "&#x1F50D;" "TOP $NUMBER $(t 'reports ids sec cats' 'categorías de ataque')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports ids th category' 'Categoría')</th><th>$(t 'reports th total' 'Total')</th><th>$(t 'reports th pct' '%')</th></tr></thead><tbody>"
if [ -n "$attack_categories" ]; then
    echo "$attack_categories" | awk -v total="$TOTAL_ALERTS" 'BEGIN{pos=1} {
        count=$1; category="";
        for(i=2;i<=NF;i++){ if(i>2) category=category " "; category=category $i }
        gsub(/[^a-zA-Z0-9 ]/," ",category); gsub(/  +/," ",category); gsub(/^ +| +$/,"",category);
        if(category!="" && count ~ /^[0-9]+$/ && count>0){
            formatted=sprintf("%\047d",count);
            percent=(total ~ /^[0-9]+$/ && total>0)?(count/total*100):0;
            printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td><span class=\"ipfr-tag ipfr-tag--cyan\">%s</span></td><td class=\"ipfr-num\">%s</td><td>%.1f%%</td></tr>\n", pos, category, formatted, percent;
            pos++;
        }
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

# TOP puertos destino
ipfr_section "&#x1F3AF;" "TOP $NUMBER $(t 'reports fw sec topports' 'puertos más atacados')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports th port' 'Puerto')</th><th>$(t 'reports ids th attacks' 'Ataques')</th><th>$(t 'reports th service' 'Servicio')</th></tr></thead><tbody>"
if [[ "$TOTAL_ALERTS" -gt 0 ]]; then
    grep -a -oE " -> [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+" "$FILTERED_LOG" | \
    sed 's/.*://' | sort | uniq -c | sort -nr | head -n "$NUMBER" | \
    awk 'BEGIN{pos=1} {
        port=$2; count=$1;
        if(port ~ /^[0-9]+$/ && count ~ /^[0-9]+$/){
            formatted=sprintf("%\047d",count); service="Unknown"; pn=int(port);
            if(pn==21)service="FTP-Control"; else if(pn==22)service="SSH"; else if(pn==23)service="Telnet";
            else if(pn==25)service="SMTP"; else if(pn==53)service="DNS"; else if(pn==80)service="HTTP";
            else if(pn==110)service="POP3"; else if(pn==143)service="IMAP"; else if(pn==443)service="HTTPS";
            else if(pn==445)service="SMB"; else if(pn==993)service="IMAPS"; else if(pn==995)service="POP3S";
            else if(pn==1433)service="SQL-Server"; else if(pn==1521)service="Oracle-DB"; else if(pn==1723)service="PPTP";
            else if(pn==3306)service="MySQL"; else if(pn==3389)service="RDP"; else if(pn==5432)service="PostgreSQL";
            else if(pn==5900)service="VNC"; else if(pn==8080)service="HTTP-Proxy"; else if(pn==8443)service="HTTPS-Alt";
            printf "<tr><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td><span class=\"ipfr-tag\">%s</span></td></tr>\n", pos, port, formatted, service;
            pos++;
        }
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_doc_close "<strong>IPFire</strong> $(t 'reports footer system' 'Reports System') &middot; IDS/IPS (Suricata) &middot; $(t 'reports footer period' 'periodo'): <strong>$TIME_DESCRIPTION</strong>"
} > "$OUTPUT_FILE"

# Limpieza (solo nuestros temporales)
[[ -f "$FILTERED_LOG" ]] && rm -f "$FILTERED_LOG"
rm -f /var/tmp/filtered_ids_log.$$ /var/tmp/ip_extractions.$$ 2>/dev/null

echo "Informe de IDS/IPS generado: $OUTPUT_FILE"
exit 0
