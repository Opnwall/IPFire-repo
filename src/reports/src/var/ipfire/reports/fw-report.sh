#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Generador de Informes de Firewall (UTF-8)                      #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Informe TOP del Firewall con maquetación moderna y gráficas SVG (donut +    #
# barras) servidas por report-lib.sh. Sin JavaScript ni dependencias.        #
#                                                                             #
###############################################################################

# Configuración por defecto
DEFAULT_LOG="/var/log/messages"
DEFAULT_OUTPUT="/var/ipfire/reports/reports/fw-report.html"
DEFAULT_NUMBER=10
CONFIG_FILE="/var/ipfire/reports/settings"

# Variables
LOG_FILE="$DEFAULT_LOG"
OUTPUT_FILE="$DEFAULT_OUTPUT"
NUMBER="$DEFAULT_NUMBER"

# Librería compartida de presentación
LIB="$(dirname "$(readlink -f "$0")")/report-lib.sh"
[[ -f "$LIB" ]] || LIB="/var/ipfire/reports/report-lib.sh"
# shellcheck source=/var/ipfire/reports/report-lib.sh
source "$LIB"

# Cargar el idioma del GUI (en el shell principal para que $(t) lo herede)
ipfr_load_lang

# Función de ayuda
show_help() {
    cat << EOF
Uso: $0 [opciones]

Opciones:
    -l, --log FILE      Especificar archivo de log (predeterminado: $DEFAULT_LOG)
    -o, --output FILE   Especificar archivo de salida (predeterminado: $DEFAULT_OUTPUT)
    -n, --number NUM    Número de IPs top a mostrar (predeterminado: $DEFAULT_NUMBER)
    -h, --help          Mostrar esta ayuda

EOF
}

# Función para leer configuración
read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Archivo de configuración no encontrado: $CONFIG_FILE"
        exit 1
    fi

    FIREWALL_ENABLED=$(grep -a "^FIREWALL=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_HOUR=$(grep -a "^SCOPE_HOUR=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_DAY=$(grep -a "^SCOPE_DAY=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_WEEK=$(grep -a "^SCOPE_WEEK=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    SCOPE_MONTH=$(grep -a "^SCOPE_MONTH=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)

    if [[ "$FIREWALL_ENABLED" != "on" ]]; then
        echo "Error: Los informes de firewall están deshabilitados en la configuración"
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



# Patrones de fecha optimizados para /var/log/messages
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

# Filtrar logs por tiempo
filter_logs_by_time() {
    local temp_log="/var/tmp/filtered_fw_log.$$"
    local files_to_process date_pattern
    read -a files_to_process <<< "$(get_log_files)"
    date_pattern=$(generate_date_patterns)
    > "$temp_log"
    for log_file in "${files_to_process[@]}"; do
        if [[ "$log_file" == *.gz ]]; then
            zcat "$log_file" 2>/dev/null | grep -a -E "kernel:.*(DROP|ACCEPT|REJECT)" | grep -a -E "$date_pattern" >> "$temp_log"
        else
            grep -a -E "kernel:.*(DROP|ACCEPT|REJECT)" "$log_file" 2>/dev/null | grep -a -E "$date_pattern" >> "$temp_log"
        fi
    done
    [[ ! -s "$temp_log" ]] && echo "Advertencia: No se encontraron eventos de firewall en el periodo $TIME_DESCRIPTION"
    FILTERED_LOG="$temp_log"
}

# Métricas correctas de IPs y puertos
calculate_correct_metrics() {
    local temp_ip="/var/tmp/ip_extractions.$$"
    local temp_port="/var/tmp/port_extractions.$$"
    grep -a "DROP" "$FILTERED_LOG" | grep -a -oE "SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sed 's/SRC=//' > "$temp_ip"
    TOTAL_IPS_EXTRACTED=$(wc -l < "$temp_ip" 2>/dev/null || echo "0")
    grep -a "DROP" "$FILTERED_LOG" | grep -a -oE "DPT=[0-9]+" | sed 's/DPT=//' > "$temp_port"
    TOTAL_PORTS_EXTRACTED=$(wc -l < "$temp_port" 2>/dev/null || echo "0")
    rm -f "$temp_ip" "$temp_port"
}

# Detección de patrones de ataque -> avisos (localizado)
detect_attack_patterns() {
    local out=""
    local LC="$(t 'reports fw lvl crit' 'Nivel crítico')"
    local LH="$(t 'reports fw lvl high' 'Nivel alto')"
    local LM="$(t 'reports fw lvl med' 'Nivel medio')"
    local AT="$(t 'reports fw attempts word' 'intentos')"

    local ssh=$(grep -a -E "DPT=(22|2222)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$ssh" -gt 100 ]; then
        out+=$(ipfr_alert danger "&#128308; SSH Brute Force: $(ipfr_format_number $ssh) $AT" "$LC &middot; $(t 'reports fw ssh1 desc' 'ataques automatizados de adivinación de contraseñas contra el servicio SSH.')")
    elif [ "$ssh" -gt 50 ]; then
        out+=$(ipfr_alert warn "&#128992; $(t 'reports fw ssh2 name' 'Ataque SSH'): $(ipfr_format_number $ssh) $AT" "$LH &middot; $(t 'reports fw ssh2 desc' 'múltiples intentos de conexión SSH; vigilar posible escalada de fuerza bruta.')")
    fi

    local rdp=$(grep -a "DPT=3389" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$rdp" -gt 50 ]; then
        out+=$(ipfr_alert danger "&#128308; $(t 'reports fw rdp1 name' 'Ataque RDP'): $(ipfr_format_number $rdp) $AT" "$LC &middot; $(t 'reports fw rdp1 desc' 'Remote Desktop Protocol; vector habitual de ransomware y robo de credenciales.')")
    elif [ "$rdp" -gt 20 ]; then
        out+=$(ipfr_alert warn "&#128992; $(t 'reports fw rdp2 name' 'Sondeo RDP'): $(ipfr_format_number $rdp) $AT" "$LH &middot; $(t 'reports fw rdp2 desc' 'descubrimiento de sistemas Windows expuestos.')")
    fi

    local telnet=$(grep -a -E "DPT=(23|2323|9999)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$telnet" -gt 30 ]; then
        local top=$(grep -a -E "DPT=(23|2323|9999)" "$FILTERED_LOG" | grep -a -oE "SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sed 's/SRC=//' | sort | uniq -c | sort -nr | head -3 | awk -v at="$AT" '{printf "&bull; %s: %s %s<br>", $2, $1, at}')
        out+=$(ipfr_alert danger "&#128308; $(t 'reports fw telnet name' 'Telnet/IoT Botnet'): $(ipfr_format_number $telnet) $AT" "$LC &middot; $(t 'reports fw telnet desc' 'actividad de botnet IoT buscando routers/cámaras con credenciales por defecto.')<br>$top")
    fi

    local db=$(grep -a -E "DPT=(1433|1521|3306|5432)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$db" -gt 20 ]; then
        local s1433=$(grep -a -c "DPT=1433" "$FILTERED_LOG"); local s1521=$(grep -a -c "DPT=1521" "$FILTERED_LOG")
        local s3306=$(grep -a -c "DPT=3306" "$FILTERED_LOG"); local s5432=$(grep -a -c "DPT=5432" "$FILTERED_LOG")
        local det=""
        [ "$s1433" -gt 0 ] && det+="&bull; SQL Server (1433): $s1433<br>"
        [ "$s1521" -gt 0 ] && det+="&bull; Oracle (1521): $s1521<br>"
        [ "$s3306" -gt 0 ] && det+="&bull; MySQL (3306): $s3306<br>"
        [ "$s5432" -gt 0 ] && det+="&bull; PostgreSQL (5432): $s5432<br>"
        out+=$(ipfr_alert danger "&#128308; $(t 'reports fw db name' 'Ataque a bases de datos'): $(ipfr_format_number $db) $AT" "$LC &middot; $(t 'reports fw db desc' 'ataques directos a servicios de bases de datos.')<br>$det")
    fi

    local web=$(grep -a -E "DPT=(80|443|8080|8443|8000|8888)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$web" -gt 200 ]; then
        out+=$(ipfr_alert warn "&#128992; $(t 'reports fw web name' 'Escaneo de servicios web'): $(ipfr_format_number $web) $AT" "$LM &middot; $(t 'reports fw web desc' 'sondeo de aplicaciones web, paneles de administración y vulnerabilidades conocidas.')")
    fi

    local vnc=$(grep -a -E "DPT=(5900|5901|5902|5903)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$vnc" -gt 10 ]; then
        out+=$(ipfr_alert danger "&#128308; $(t 'reports fw vnc name' 'Ataque VNC'): $(ipfr_format_number $vnc) $AT" "$LC &middot; $(t 'reports fw vnc desc' 'intentos de acceso remoto por VNC.')")
    fi

    local smb=$(grep -a -E "DPT=(445|139)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$smb" -gt 30 ]; then
        out+=$(ipfr_alert danger "&#128308; $(t 'reports fw smb name' 'Ataque SMB/NetBIOS'): $(ipfr_format_number $smb) $AT" "$LC &middot; $(t 'reports fw smb desc' 'alto riesgo de propagación de ransomware (estilo WannaCry).')")
    fi

    local back=$(grep -a -E "DPT=(12345|31337|54321|27374)" "$FILTERED_LOG" 2>/dev/null | wc -l)
    if [ "$back" -gt 5 ]; then
        out+=$(ipfr_alert danger "&#128308; $(t 'reports fw backdoor name' 'Actividad de backdoor/troyano'): $(ipfr_format_number $back) $AT" "$LC &middot; $(t 'reports fw backdoor desc' 'puertos de backdoor conocidos (NetBus, BackOrifice, Sub7).')")
    fi

    ipfr_alerts_open
    if [[ -n "$out" ]]; then
        echo "$out"
    else
        ipfr_alert ok "&#9989; $(t 'reports fw noattack title' 'Sin patrones de ataque relevantes')" "$(t 'reports fw noattack desc' 'No se han superado los umbrales de detección en el periodo analizado.') ($TIME_DESCRIPTION)"
    fi
    ipfr_alerts_close
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

# Estadísticas básicas del periodo
TOTAL_DROPS=$(grep -a -c "DROP" "$FILTERED_LOG" 2>/dev/null)
TOTAL_ACCEPTS=$(grep -a -c "ACCEPT" "$FILTERED_LOG" 2>/dev/null)
TOTAL_REJECTS=$(grep -a -c "REJECT" "$FILTERED_LOG" 2>/dev/null)
calculate_correct_metrics

FORMATTED_DROPS=$(ipfr_format_number "$TOTAL_DROPS")
FORMATTED_ACCEPTS=$(ipfr_format_number "$TOTAL_ACCEPTS")
FORMATTED_REJECTS=$(ipfr_format_number "$TOTAL_REJECTS")

# Capturar TOP IPs (para las barras)
TOP_IPS=$(grep -a "DROP" "$FILTERED_LOG" 2>/dev/null | \
    grep -a -oE "SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
    sed 's/SRC=//' | sort | uniq -c | sort -nr | head -n "$NUMBER")

# ----------------------- Generación del informe ----------------------------
{
ipfr_doc_open "fw" "&#x1F525;" "$(t 'reports fw title' 'Informe de Firewall') &mdash; TOP $NUMBER" \
    "$(t 'reports generated on' 'Generado el') $(date '+%d/%m/%Y %H:%M') &middot; $(t 'reports period word' 'Periodo'): $TIME_DESCRIPTION"

ipfr_stats_open
ipfr_stat red    "$(t 'reports fw stat drops' 'Paquetes bloqueados')"   "$FORMATTED_DROPS"   "$(t 'reports fw stat drops d' 'Conexiones descartadas (DROP)')"
ipfr_stat green  "$(t 'reports fw stat accepts' 'Paquetes aceptados')"  "$FORMATTED_ACCEPTS" "$(t 'reports fw stat accepts d' 'Conexiones permitidas (ACCEPT)')"
ipfr_stat orange "$(t 'reports fw stat rejects' 'Paquetes rechazados')" "$FORMATTED_REJECTS" "$(t 'reports fw stat rejects d' 'Conexiones rechazadas (REJECT)')"
ipfr_stats_close

ipfr_section "&#x1F4CA;" "$(t 'reports sec overview' 'Visión general')"
ipfr_grid_open
printf '%s\n' "DROP|$TOTAL_DROPS|#dc143c" "ACCEPT|$TOTAL_ACCEPTS|#22a559" "REJECT|$TOTAL_REJECTS|#f59e0b" \
    | ipfr_donut "$(t 'reports fw donut title' 'Tráfico del firewall')" "$(t 'reports fw donut sub' 'Reparto por veredicto')" "$(t 'reports fw unit packets' 'paquetes')"
echo "$TOP_IPS" | awk 'NF>=2{print $2"|"$1}' \
    | ipfr_hbars "TOP $NUMBER $(t 'reports fw sec topips' 'IPs bloqueadas')" "$(t 'reports fw bars sub' 'Direcciones de origen con más descartes')" "#dc143c"
ipfr_grid_close

# Mapa de calor día x hora (salvo en alcance de 1 hora)
if [[ "$TIME_SCOPE" != "hour" ]]; then
    case "$TIME_SCOPE" in day) _HN=1 ;; week) _HN=7 ;; month) _HN=30 ;; *) _HN=7 ;; esac
    _HDAYS=""; for ((_i=_HN-1; _i>=0; _i--)); do _HDAYS+="$(date -d "$_i days ago" '+%Y-%m-%d') "; done
    ipfr_section "&#x1F4C5;" "$(t 'reports heatmap title' 'Actividad por hora y día')"
    awk -v year="$(date '+%Y')" 'BEGIN{split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec",mm," ");for(i=1;i<=12;i++)mn[mm[i]]=sprintf("%02d",i)} ($1 in mn){printf "%s-%s-%02d\t%s\n",year,mn[$1],$2,substr($3,1,2)}' "$FILTERED_LOG" \
        | ipfr_heatmap "" "$(t 'reports heatmap caption' 'Cada celda es una hora de un día concreto; cuanto más oscuro, mayor actividad. Útil para ver si hay franjas más activas.')" "#dc143c" "$_HDAYS"
fi

ipfr_section "&#x26A0;&#xFE0F;" "$(t 'reports fw sec attacks' 'Análisis de patrones de ataque')"
detect_attack_patterns

ipfr_section "&#x1F3AF;" "TOP $NUMBER $(t 'reports fw sec topports' 'puertos más atacados')"
echo "<table class=\"ipfr-table\"><thead><tr><th>#</th><th>$(t 'reports th port' 'Puerto')</th><th>$(t 'reports fw th attempts' 'Intentos')</th><th>$(t 'reports th service' 'Servicio')</th></tr></thead><tbody>"
if grep -a -q "DPT=" "$FILTERED_LOG" 2>/dev/null; then
    grep -a "DROP" "$FILTERED_LOG" | grep -a -oE "DPT=[0-9]+" | sed 's/DPT=//' | \
    sort | uniq -c | sort -nr | head -n "$NUMBER" | \
    awk 'BEGIN{pos=1} {
        port=$2; count=$1; formatted=sprintf("%\047d",count);
        service="Unknown"; risk="";
        if(port==21)service="FTP";
        else if(port==22){service="SSH";risk="hi"}
        else if(port==23){service="Telnet";risk="hi"}
        else if(port==25)service="SMTP";
        else if(port==53)service="DNS";
        else if(port==80){service="HTTP";risk="md"}
        else if(port==110)service="POP3";
        else if(port==123)service="NTP";
        else if(port==135){service="RPC-Endpoint";risk="hi"}
        else if(port==137){service="NetBIOS-NS";risk="md"}
        else if(port==139){service="NetBIOS-SSN";risk="hi"}
        else if(port==143)service="IMAP";
        else if(port==161){service="SNMP";risk="md"}
        else if(port==389)service="LDAP";
        else if(port==443){service="HTTPS";risk="md"}
        else if(port==445){service="SMB";risk="hi"}
        else if(port==500)service="IKE/IPSec";
        else if(port==587)service="SMTP-Submit";
        else if(port==993)service="IMAP-SSL";
        else if(port==995)service="POP3-SSL";
        else if(port==1433){service="SQL-Server";risk="hi"}
        else if(port==1521){service="Oracle-DB";risk="hi"}
        else if(port==3306){service="MySQL";risk="hi"}
        else if(port==3389){service="RDP";risk="hi"}
        else if(port==5432){service="PostgreSQL";risk="hi"}
        else if(port==5900){service="VNC";risk="hi"}
        else if(port==8080){service="HTTP-Proxy";risk="md"}
        else if(port==12345){service="NetBus";risk="hi"}
        else if(port==31337){service="BackOrifice";risk="hi"}
        else if(port==54321){service="Bo2k";risk="hi"}
        rowcls=(risk=="hi"?" class=\"ipfr-rowhi\"":(risk=="md"?" class=\"ipfr-rowmd\"":""));
        icon=(risk=="hi"?"&#128308; ":(risk=="md"?"&#128992; ":""));
        printf "<tr%s><td><span class=\"ipfr-rank\">%d</span></td><td class=\"ipfr-mono\">%s</td><td class=\"ipfr-num\">%s</td><td><span class=\"ipfr-tag\">%s%s</span></td></tr>\n", rowcls,pos,port,formatted,icon,service;
        pos++;
    }'
else
    echo "<tr><td colspan=\"4\" class=\"ipfr-empty\">$(t 'reports nodata period' 'Sin datos para el periodo')</td></tr>"
fi
echo '</tbody></table>'

ipfr_doc_close "<strong>IPFire</strong> $(t 'reports footer system' 'Reports System') &middot; $(t 'reports fw foot desc' 'análisis de firewall') &middot; $(t 'reports footer period' 'periodo'): <strong>$TIME_DESCRIPTION</strong><br>&#128308; $(t 'reports fw foot crit' 'Riesgo crítico') &nbsp; &#128992; $(t 'reports fw foot med' 'Riesgo medio')"
} > "$OUTPUT_FILE"

# Limpieza (solo nuestros temporales)
[[ -f "$FILTERED_LOG" ]] && rm -f "$FILTERED_LOG"
rm -f /var/tmp/filtered_fw_log.$$ /var/tmp/ip_extractions.$$ /var/tmp/port_extractions.$$ 2>/dev/null

echo "Informe de firewall generado: $OUTPUT_FILE"
exit 0
