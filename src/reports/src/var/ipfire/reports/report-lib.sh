#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Librería compartida de informes (UTF-8)                        #
#                                                                             #
# Funciones comunes de presentación para los generadores de informes.        #
# Dos modos de salida controlados por la variable de entorno IPFR_MAIL:       #
#   - IPFR_MAIL no establecido / 0  -> modo WEB (CGI): diseño moderno con      #
#     gráficas SVG, flexbox, variables CSS y animaciones.                      #
#   - IPFR_MAIL=1 -> modo CORREO: HTML "email-safe" (tablas, estilos en        #
#     línea, colores sólidos, gráficas hechas con tablas; sin SVG, sin flex,   #
#     sin variables CSS, sin JavaScript) para que se vea bien en Gmail,        #
#     Outlook, Apple Mail y clientes móviles.                                  #
#                                                                             #
# Este archivo se "source-a", no se ejecuta directamente.                     #
###############################################################################

# ---------------------------------------------------------------------------
# Formateo de números con separador de miles (respeta el locale; con reserva)
# ---------------------------------------------------------------------------
ipfr_format_number() {
    local n="$1"
    LC_ALL=en_US.UTF-8 printf "%'d" "$n" 2>/dev/null || printf "%d" "$n" 2>/dev/null || echo "$n"
}

# ---------------------------------------------------------------------------
# Escape HTML mínimo para texto procedente de logs (anti-inyección)
# ---------------------------------------------------------------------------
ipfr_html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# ---------------------------------------------------------------------------
# i18n: el informe se genera en el idioma del GUI de IPFire
#   - Idioma desde /var/ipfire/main/settings (LANGUAGE=), reserva 'en'.
#   - Las cadenas se leen de /var/ipfire/addon-lang/reports.<lang>.pl.
#   - t 'clave' 'texto por defecto' -> traducción o el texto por defecto.
# ---------------------------------------------------------------------------
IPFR_MAIN_SETTINGS="${IPFR_MAIN_SETTINGS:-/var/ipfire/main/settings}"
IPFR_LANGDIR="${IPFR_LANGDIR:-/var/ipfire/addon-lang}"
declare -A IPFR_T
IPFR_LANG=""
IPFR_LANG_LOADED=""

ipfr_detect_lang() {
    local l=""
    [[ -f "$IPFR_MAIN_SETTINGS" ]] && \
        l=$(grep -a '^LANGUAGE=' "$IPFR_MAIN_SETTINGS" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d ' \r\n')
    case "$l" in
        en|es|de|fr|it) echo "$l" ;;
        *) echo "en" ;;
    esac
}

# Carga reports.<lang>.pl en IPFR_T. Debe llamarse UNA vez en el shell
# principal del generador (no dentro de $()), para que $(t ...) la herede.
ipfr_load_lang() {
    IPFR_LANG="${1:-$(ipfr_detect_lang)}"
    local f="$IPFR_LANGDIR/reports.${IPFR_LANG}.pl"
    [[ -f "$f" ]] || f="$IPFR_LANGDIR/reports.en.pl"
    IPFR_LANG_LOADED="1"
    [[ -f "$f" ]] || return
    local k v
    while IFS=$'\t' read -r k v; do
        [[ -n "$k" ]] && IPFR_T["$k"]="$v"
    done < <(awk -F"'" '/^\$tr\{/ && NF>=4 {print $2 "\t" $4}' "$f")
}

t() {
    [[ -n "$IPFR_LANG_LOADED" ]] || ipfr_load_lang
    local v="${IPFR_T[$1]}"
    if [[ -n "$v" ]]; then printf '%s' "$v"; else printf '%s' "$2"; fi
}

# Color sólido por nombre lógico (compartido por ambos modos)
_ipfr_hex() {
    case "$1" in
        red)    echo "#dc143c" ;;
        green)  echo "#22a559" ;;
        orange) echo "#f59e0b" ;;
        blue)   echo "#0d6efd" ;;
        purple) echo "#6f42c1" ;;
        cyan)   echo "#17a2b8" ;;
        *)      echo "#94a3b8" ;;
    esac
}

# Acento sólido por módulo (usado en modo correo)
_ipfr_accent() {
    case "$1" in
        fw)  echo "#dc143c" ;;
        ids) echo "#6f42c1" ;;
        url) echo "#0d6efd" ;;
        dns) echo "#0d9488" ;;
        *)   echo "#dc143c" ;;
    esac
}

###############################################################################
# RECOLECCIÓN DE LOGS (común a todos los generadores)
# Usan las variables globales que fija cada generador: LOG_FILE y TIME_SCOPE.
###############################################################################

# ¿El archivo fue modificado dentro del rango temporal del scope?
is_file_in_time_range() {
    local file="$1"
    local current_timestamp=$(date +%s)
    local file_timestamp=$(stat -c %Y "$file" 2>/dev/null)
    [[ -z "$file_timestamp" ]] && return 1
    local time_limit
    case "$TIME_SCOPE" in
        "hour")  time_limit=$((current_timestamp - 3600)) ;;
        "day")   time_limit=$((current_timestamp - 86400)) ;;
        "week")  time_limit=$((current_timestamp - 604800)) ;;
        "month") time_limit=$((current_timestamp - 2592000)) ;;
    esac
    [[ $file_timestamp -ge $time_limit ]]
}

# Lista de archivos de log (principal + rotados .gz en rango) para el scope.
get_log_files() {
    local log_dir=$(dirname "$LOG_FILE")
    local log_base=$(basename "$LOG_FILE")
    local files_to_process=()
    [[ -f "$LOG_FILE" ]] && files_to_process+=("$LOG_FILE")
    case "$TIME_SCOPE" in
        "hour")
            if [[ -f "${log_dir}/${log_base}.1.gz" ]] && is_file_in_time_range "${log_dir}/${log_base}.1.gz"; then
                files_to_process+=("${log_dir}/${log_base}.1.gz")
            fi ;;
        "day")
            for i in {1..2}; do
                local file="${log_dir}/${log_base}.${i}.gz"
                [[ -f "$file" ]] && is_file_in_time_range "$file" && files_to_process+=("$file")
            done ;;
        "week")
            for i in {1..7}; do
                local file="${log_dir}/${log_base}.${i}.gz"
                [[ -f "$file" ]] && is_file_in_time_range "$file" && files_to_process+=("$file")
            done ;;
        "month")
            for i in {1..30}; do
                local file="${log_dir}/${log_base}.${i}.gz"
                if [[ -f "$file" ]] && is_file_in_time_range "$file"; then
                    files_to_process+=("$file")
                else
                    break
                fi
            done ;;
    esac
    echo "${files_to_process[@]}"
}

###############################################################################
# HOJA DE ESTILOS
###############################################################################
ipfr_css() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        _ipfr_css_mail
    else
        _ipfr_css_web
    fi
}

# --- CSS WEB (scoped bajo .ipfr para no contaminar el panel de IPFire) ------
_ipfr_css_web() {
cat <<'CSS'
<style>
.ipfr *{box-sizing:border-box}
.ipfr{
  --accent:#dc143c; --accent-d:#8b0000; --ink:#1f2733; --muted:#6b7785;
  --line:#e6e9ef; --card:#ffffff; --bg:#f4f6fa;
  font-family:-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  color:var(--ink); background:var(--bg); line-height:1.5;
  max-width:980px; margin:0 auto; border-radius:14px; overflow:hidden;
  box-shadow:0 10px 30px rgba(15,23,42,.08); -webkit-font-smoothing:antialiased;
}
.ipfr--fw {--accent:#dc143c; --accent-d:#8b0000;}
.ipfr--ids{--accent:#6f42c1; --accent-d:#3a2475;}
.ipfr--url{--accent:#0d6efd; --accent-d:#0a3d91;}
.ipfr--dns{--accent:#0d9488; --accent-d:#0a6b62;}

.ipfr-hero{
  position:relative; padding:30px 28px; color:#fff;
  background:#dc143c; background:linear-gradient(135deg,var(--accent),var(--accent-d));
  display:flex; align-items:center; gap:18px; overflow:hidden;
}
.ipfr-hero::after{content:"";position:absolute;right:-60px;top:-60px;width:220px;height:220px;
  background:radial-gradient(circle,rgba(255,255,255,.18),transparent 70%);border-radius:50%}
.ipfr-hero__icon{font-size:40px;line-height:1;filter:drop-shadow(0 2px 4px rgba(0,0,0,.25));z-index:1}
.ipfr-hero__title{margin:0;font-size:24px;font-weight:800;letter-spacing:-.3px;z-index:1}
.ipfr-hero__sub{margin:4px 0 0;font-size:13px;opacity:.92;z-index:1}

.ipfr-main{padding:24px 28px 8px}

.ipfr-h2{
  display:flex;align-items:center;gap:9px;
  font-size:17px;font-weight:700;color:var(--ink);
  margin:30px 0 14px;padding-bottom:9px;border-bottom:2px solid var(--accent);
}
.ipfr-h2 .i{font-size:18px}
.ipfr-h2:first-child{margin-top:6px}

.ipfr-stats{display:flex;flex-wrap:wrap;gap:12px;margin:18px 0}
.ipfr-stat{
  flex:1 1 130px;background:var(--card);border:1px solid var(--line);
  border-radius:11px;border-top:4px solid #94a3b8;padding:14px 14px 13px;
  transition:transform .18s ease,box-shadow .18s ease;
}
.ipfr-stat:hover{transform:translateY(-3px);box-shadow:0 8px 20px rgba(15,23,42,.1)}
.ipfr-stat--red{border-top-color:#dc143c}
.ipfr-stat--green{border-top-color:#22a559}
.ipfr-stat--orange{border-top-color:#f59e0b}
.ipfr-stat--blue{border-top-color:#0d6efd}
.ipfr-stat--purple{border-top-color:#6f42c1}
.ipfr-stat--cyan{border-top-color:#17a2b8}
.ipfr-stat__lbl{font-size:10px;font-weight:700;letter-spacing:.6px;text-transform:uppercase;color:var(--muted)}
.ipfr-stat__val{font-size:25px;font-weight:800;color:var(--ink);margin:5px 0 2px;font-variant-numeric:tabular-nums}
.ipfr-stat__desc{font-size:10px;color:var(--muted);line-height:1.35}

.ipfr-grid{display:flex;flex-wrap:wrap;gap:16px;margin:8px 0 4px}
.ipfr-card{
  flex:1 1 280px;background:var(--card);border:1px solid var(--line);
  border-radius:13px;padding:16px 18px;
}
.ipfr-card__t{font-size:14px;font-weight:700;color:var(--ink);margin:0 0 2px}
.ipfr-card__s{font-size:11px;color:var(--muted);margin:0 0 12px}

.ipfr-donut{display:flex;align-items:center;gap:18px;flex-wrap:wrap}
.ipfr-donut__svg{width:160px;height:160px;flex:0 0 auto}
.ipfr-donut__ring{transform-origin:90px 90px;animation:ipfr-pop .8s cubic-bezier(.2,.8,.2,1) both}
.ipfr-seg{transition:stroke-width .15s ease;cursor:default}
.ipfr-seg:hover{stroke-width:30}
.ipfr-donut__num{font-size:30px;font-weight:800;fill:var(--ink);font-family:inherit;font-variant-numeric:tabular-nums}
.ipfr-donut__unit{font-size:11px;fill:var(--muted);text-transform:uppercase;letter-spacing:.5px;font-family:inherit}
.ipfr-legend{list-style:none;margin:0;padding:0;flex:1 1 150px;min-width:140px}
.ipfr-legend li{display:flex;align-items:center;gap:8px;padding:4px 0;font-size:12px}
.ipfr-legend__dot{width:11px;height:11px;border-radius:3px;flex:0 0 auto}
.ipfr-legend__lbl{flex:1;color:var(--ink)}
.ipfr-legend__val{font-weight:700;color:var(--ink);font-variant-numeric:tabular-nums}
.ipfr-legend__val em{font-style:normal;color:var(--muted);font-weight:500;margin-left:4px}

.ipfr-bars{width:100%;height:auto;display:block}
.ipfr-bar-row .ipfr-track{fill:#eef1f6}
.ipfr-bar{transform-box:fill-box;transform-origin:left center;animation:ipfr-grow .85s cubic-bezier(.2,.8,.2,1) both}
.ipfr-bar-lbl{font-size:12px;fill:var(--ink);font-family:inherit;font-weight:600}
.ipfr-bar-val{font-size:12px;fill:var(--ink);font-family:inherit;font-weight:700;font-variant-numeric:tabular-nums}
.ipfr-bar-rank{font-size:11px;fill:var(--muted);font-family:inherit;font-weight:700}

/* Mapa de calor (día x hora) */
.ipfr-hm{border-collapse:separate;border-spacing:2px}
.ipfr-hm td.c{border-radius:3px;transition:transform .1s ease}
.ipfr-hm td.c:hover{transform:scale(1.35)}
.ipfr-hm .hh{font-size:9px;color:var(--muted);text-align:center}
.ipfr-hm .dd{font-size:10px;color:var(--muted);text-align:right;padding-right:6px;white-space:nowrap}

.ipfr-table{width:100%;border-collapse:collapse;background:var(--card);
  border:1px solid var(--line);border-radius:11px;overflow:hidden;margin:8px 0 22px;font-size:13px}
.ipfr-table thead th{
  background:#2b313c;color:#fff;text-align:left;font-size:11px;font-weight:700;
  letter-spacing:.4px;text-transform:uppercase;padding:11px 12px;
}
.ipfr-table td{padding:10px 12px;border-top:1px solid var(--line);vertical-align:middle}
.ipfr-table tbody tr{transition:background .12s ease}
.ipfr-table tbody tr:nth-child(even){background:#fafbfd}
.ipfr-table tbody tr:hover{background:#fff4f5}
.ipfr--ids .ipfr-table tbody tr:hover{background:#f5f1fc}
.ipfr--url .ipfr-table tbody tr:hover{background:#eff5ff}
.ipfr--dns .ipfr-table tbody tr:hover{background:#eafaf7}
.ipfr-rank{display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;
  border-radius:8px;background:var(--accent);color:#fff;font-weight:800;font-size:12px}
.ipfr-mono{font-family:"SF Mono",Consolas,"Courier New",monospace;font-weight:700;color:var(--accent)}
.ipfr-num{font-weight:700;font-variant-numeric:tabular-nums}
.ipfr-tag{display:inline-block;padding:3px 8px;border-radius:20px;font-size:10px;font-weight:700;
  background:#eef1f6;color:#475569}
.ipfr-tag--blue{background:#0d6efd;color:#fff}
.ipfr-tag--cyan{background:#17a2b8;color:#fff}
.ipfr-badge{display:inline-block;padding:3px 9px;border-radius:20px;font-size:10px;font-weight:800;color:#fff}
.ipfr-badge--hi{background:#dc2626}
.ipfr-badge--md{background:#f59e0b}
.ipfr-badge--lo{background:#22a559}
.ipfr-rowhi{background:#fef2f2 !important}
.ipfr-rowmd{background:#fffbeb !important}

.ipfr-alerts{display:flex;flex-direction:column;gap:9px;margin:14px 0 4px}
.ipfr-alert{padding:11px 14px;border-radius:10px;font-size:13px;font-weight:600;border-left:4px solid}
.ipfr-alert small{display:block;font-weight:400;margin-top:3px;opacity:.9}
.ipfr-alert--danger{background:#fef2f2;border-color:#dc2626;color:#991b1b}
.ipfr-alert--warn{background:#fffbeb;border-color:#f59e0b;color:#92400e}
.ipfr-alert--ok{background:#f0fdf4;border-color:#22a559;color:#166534}

.ipfr-empty{text-align:center;color:var(--muted);font-style:italic;padding:22px}

.ipfr-foot{
  margin-top:18px;padding:18px 28px;background:#f7f9fc;border-top:1px solid var(--line);
  text-align:center;color:var(--muted);font-size:11px;line-height:1.6;
}
.ipfr-foot strong{color:var(--accent)}

@keyframes ipfr-pop{from{opacity:0;transform:scale(.85)}to{opacity:1;transform:scale(1)}}
@keyframes ipfr-grow{from{transform:scaleX(0)}to{transform:scaleX(1)}}
@media (max-width:600px){
  .ipfr-hero{padding:22px 18px}.ipfr-main{padding:18px}
  .ipfr-stat{flex:1 1 100%}.ipfr-donut__svg{width:140px;height:140px}
  .ipfr-table{font-size:12px}.ipfr-table td,.ipfr-table thead th{padding:8px}
}
@media (prefers-reduced-motion:reduce){
  .ipfr-donut__ring,.ipfr-bar{animation:none}
}
</style>
CSS
}

# --- CSS CORREO (email-safe: sin var/flex/svg/anim; clases con colores       -
#     sólidos para clientes que respetan <style>, p.ej. Gmail/Apple Mail) -----
_ipfr_css_mail() {
cat <<'CSS'
<style>
.ipfr-table{width:100%;border-collapse:collapse;border:1px solid #e6e9ef;margin:8px 0 18px;font-size:13px;font-family:Arial,Helvetica,sans-serif}
.ipfr-table th{background:#2b313c;color:#ffffff;text-align:left;font-size:11px;font-weight:bold;text-transform:uppercase;padding:10px 12px}
.ipfr-table td{padding:9px 12px;border-top:1px solid #e6e9ef;color:#1f2733}
.ipfr-table tr:nth-child(even) td{background:#fafbfd}
.ipfr-rank{display:inline-block;width:24px;height:24px;line-height:24px;text-align:center;border-radius:6px;background:#dc143c;color:#fff;font-weight:bold;font-size:12px}
.ipfr--ids .ipfr-rank{background:#6f42c1}
.ipfr--url .ipfr-rank{background:#0d6efd}
.ipfr--dns .ipfr-rank{background:#0d9488}
.ipfr-mono{font-family:Consolas,"Courier New",monospace;font-weight:bold;color:#1f2733}
.ipfr-num{font-weight:bold}
.ipfr-tag{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:bold;background:#eef1f6;color:#475569}
.ipfr-tag--blue{background:#0d6efd;color:#fff}
.ipfr-tag--cyan{background:#17a2b8;color:#fff}
.ipfr-badge{display:inline-block;padding:2px 9px;border-radius:12px;font-size:10px;font-weight:bold;color:#fff}
.ipfr-badge--hi{background:#dc2626}
.ipfr-badge--md{background:#f59e0b}
.ipfr-badge--lo{background:#22a559}
.ipfr-rowhi td{background:#fef2f2}
.ipfr-rowmd td{background:#fffbeb}
.ipfr-empty{text-align:center;color:#6b7785;font-style:italic;padding:18px}
</style>
CSS
}

###############################################################################
# APERTURA / CIERRE DEL DOCUMENTO
#   $1 module(fw|ids|url)  $2 icon(HTML)  $3 title  $4 subtitle
###############################################################################
ipfr_doc_open() {
    local module="$1" icon="$2" title="$3" subtitle="$4"
    IPFR_MOD="$module"
    IPFR_ACCENT="$(_ipfr_accent "$module")"

    cat <<HEAD
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
HEAD
    ipfr_css

    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        cat <<HEAD
</head>
<body style="margin:0;padding:0;background:#eef1f6;font-family:Arial,Helvetica,sans-serif">
<!--IPFR:BODY:START-->
<div class="ipfr ipfr--${module}">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#eef1f6"><tr><td align="center" style="padding:16px">
<table role="presentation" width="680" cellpadding="0" cellspacing="0" border="0" style="width:680px;max-width:680px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e9ef">
  <tr><td bgcolor="${IPFR_ACCENT}" style="background:${IPFR_ACCENT};padding:24px 26px;color:#ffffff">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
      <td style="font-size:34px;padding-right:14px;vertical-align:middle">${icon}</td>
      <td style="vertical-align:middle">
        <div style="font-size:22px;font-weight:bold;color:#ffffff">${title}</div>
        <div style="font-size:13px;color:#ffffff;opacity:.92">${subtitle}</div>
      </td>
    </tr></table>
  </td></tr>
  <tr><td style="padding:18px 24px 6px">
HEAD
    else
        cat <<HEAD
</head>
<body>
<!--IPFR:BODY:START-->
<div class="ipfr ipfr--${module}">
  <header class="ipfr-hero">
    <div class="ipfr-hero__icon">${icon}</div>
    <div>
      <h1 class="ipfr-hero__title">${title}</h1>
      <p class="ipfr-hero__sub">${subtitle}</p>
    </div>
  </header>
  <main class="ipfr-main">
HEAD
    fi
}

ipfr_doc_close() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        cat <<FOOT
  </td></tr>
  <tr><td bgcolor="#f7f9fc" style="background:#f7f9fc;padding:16px;text-align:center;color:#6b7785;font-size:11px;line-height:1.6">${1}</td></tr>
</table>
</td></tr></table>
</div>
<!--IPFR:BODY:END-->
</body>
</html>
FOOT
    else
        cat <<FOOT
  </main>
  <footer class="ipfr-foot">${1}</footer>
</div>
<!--IPFR:BODY:END-->
</body>
</html>
FOOT
    fi
}

###############################################################################
# SECCIÓN
###############################################################################
ipfr_section() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        printf '<div style="font-size:16px;font-weight:bold;color:#1f2733;border-bottom:2px solid %s;padding-bottom:8px;margin:22px 0 12px">%s %s</div>\n' "${IPFR_ACCENT:-#dc143c}" "$1" "$2"
    else
        printf '<h2 class="ipfr-h2"><span class="i">%s</span>%s</h2>\n' "$1" "$2"
    fi
}

###############################################################################
# TARJETAS DE ESTADÍSTICAS
###############################################################################
ipfr_stats_open() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        echo '<div style="margin:14px 0;font-size:0">'
    else
        echo '<div class="ipfr-stats">'
    fi
}
ipfr_stats_close() { echo '</div>'; }

# $1 color(red|green|orange|blue|purple|cyan) $2 label $3 value $4 desc
ipfr_stat() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        local hex; hex="$(_ipfr_hex "$1")"
        printf '<div style="display:inline-block;width:31%%;min-width:150px;vertical-align:top;margin:1%%;background:#ffffff;border:1px solid #e6e9ef;border-top:4px solid %s;border-radius:8px;padding:12px;font-size:13px;font-family:Arial,Helvetica,sans-serif"><div style="font-size:10px;font-weight:bold;letter-spacing:.5px;text-transform:uppercase;color:#6b7785">%s</div><div style="font-size:23px;font-weight:bold;color:#1f2733;margin:4px 0 2px">%s</div><div style="font-size:10px;color:#6b7785">%s</div></div>\n' \
            "$hex" "$2" "$3" "$4"
    else
        printf '<div class="ipfr-stat ipfr-stat--%s"><div class="ipfr-stat__lbl">%s</div><div class="ipfr-stat__val">%s</div><div class="ipfr-stat__desc">%s</div></div>\n' \
            "$1" "$2" "$3" "$4"
    fi
}

# Fila de gráficas (cards lado a lado en web; apiladas en correo)
ipfr_grid_open() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then echo '<div>'; else echo '<div class="ipfr-grid">'; fi
}
ipfr_grid_close() { echo '</div>'; }

###############################################################################
# DONUT
#   $1 título  $2 subtítulo  $3 unidad(centro)
#   stdin: etiqueta|valor|colorhex
###############################################################################
ipfr_donut() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        _ipfr_donut_mail "$1" "$2" "$3"
    else
        _ipfr_donut_web "$1" "$2" "$3"
    fi
}

_ipfr_donut_web() {
    awk -F'|' -v title="$1" -v subtitle="$2" -v unit="$3" -v nd="$(t 'reports lib nodata' 'Sin datos')" '
    function fmt(x,   s,o,l,i,c){ s=sprintf("%d",x+0); l=length(s); o=""; c=0;
        for(i=l;i>=1;i--){ o=substr(s,i,1) o; c++; if(c%3==0 && i>1) o="," o } return o }
    { lbl[NR]=$1; val[NR]=$2+0; col[NR]=($3==""?"#94a3b8":$3); tot+=$2 }
    END{
        n=NR; cx=90; cy=90; r=64; sw=26; PI=3.14159265358979; C=2*PI*r;
        print "<div class=\"ipfr-card\">";
        if(title!="")    print "<div class=\"ipfr-card__t\">" title "</div>";
        if(subtitle!="") print "<div class=\"ipfr-card__s\">" subtitle "</div>";
        print "<div class=\"ipfr-donut\">";
        print "<svg viewBox=\"0 0 180 180\" class=\"ipfr-donut__svg\" role=\"img\" aria-label=\"" title "\">";
        print "<g class=\"ipfr-donut__ring\"><g transform=\"rotate(-90 " cx " " cy ")\">";
        printf "<circle cx=\"%d\" cy=\"%d\" r=\"%d\" fill=\"none\" stroke=\"#edeff3\" stroke-width=\"%d\"/>\n",cx,cy,r,sw;
        cum=0;
        for(i=1;i<=n && tot>0;i++){
            frac=val[i]/tot; arc=frac*C; gap=C-arc;
            printf "<circle class=\"ipfr-seg\" cx=\"%d\" cy=\"%d\" r=\"%d\" fill=\"none\" stroke=\"%s\" stroke-width=\"%d\" stroke-linecap=\"butt\" stroke-dasharray=\"%.3f %.3f\" stroke-dashoffset=\"%.3f\"><title>%s: %s (%.1f%%)</title></circle>\n",cx,cy,r,col[i],sw,arc,gap,-cum,lbl[i],fmt(val[i]),frac*100;
            cum+=arc;
        }
        print "</g></g>";
        printf "<text x=\"90\" y=\"88\" class=\"ipfr-donut__num\" text-anchor=\"middle\">%s</text>\n",fmt(tot);
        if(unit!="") printf "<text x=\"90\" y=\"106\" class=\"ipfr-donut__unit\" text-anchor=\"middle\">%s</text>\n",unit;
        print "</svg>";
        print "<ul class=\"ipfr-legend\">";
        if(n==0 || tot<=0){ print "<li class=\"ipfr-empty\" style=\"padding:6px\">" nd "</li>"; }
        for(i=1;i<=n;i++){
            pct=(tot>0)?val[i]/tot*100:0;
            printf "<li><span class=\"ipfr-legend__dot\" style=\"background:%s\"></span><span class=\"ipfr-legend__lbl\">%s</span><span class=\"ipfr-legend__val\">%s<em>%.1f%%</em></span></li>\n",col[i],lbl[i],fmt(val[i]),pct;
        }
        print "</ul></div></div>";
    }'
}

# Donut en correo: barra apilada (tabla) + leyenda (tabla). Sin SVG.
_ipfr_donut_mail() {
    awk -F'|' -v title="$1" -v subtitle="$2" -v unit="$3" -v nd="$(t 'reports lib nodata' 'Sin datos')" '
    function fmt(x,   s,o,l,i,c){ s=sprintf("%d",x+0); l=length(s); o=""; c=0;
        for(i=l;i>=1;i--){ o=substr(s,i,1) o; c++; if(c%3==0 && i>1) o="," o } return o }
    { lbl[NR]=$1; val[NR]=$2+0; col[NR]=($3==""?"#94a3b8":$3); tot+=$2 }
    END{
        n=NR;
        print "<div style=\"background:#ffffff;border:1px solid #e6e9ef;border-radius:10px;padding:14px 16px;margin:8px 0 16px\">";
        if(title!="")    print "<div style=\"font-size:14px;font-weight:bold;color:#1f2733\">" title " <span style=\"color:#6b7785;font-weight:normal\">&middot; " fmt(tot) " " unit "</span></div>";
        if(subtitle!="") print "<div style=\"font-size:11px;color:#6b7785;margin-bottom:10px\">" subtitle "</div>";
        if(n==0 || tot<=0){ print "<div style=\"text-align:center;color:#6b7785;font-style:italic;padding:12px\">" nd "</div></div>"; exit }
        # Barra apilada
        print "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"border-radius:6px;overflow:hidden;margin-bottom:12px\"><tr>";
        for(i=1;i<=n;i++){
            pct=val[i]/tot*100; if(pct<1 && val[i]>0) pct=1;
            printf "<td width=\"%.1f%%\" bgcolor=\"%s\" style=\"background:%s;height:22px;font-size:0;line-height:0\">&nbsp;</td>",pct,col[i],col[i];
        }
        print "</tr></table>";
        # Leyenda
        print "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"font-size:12px\">";
        for(i=1;i<=n;i++){
            pct=val[i]/tot*100;
            printf "<tr><td width=\"16\" style=\"padding:3px 0\"><span style=\"display:inline-block;width:11px;height:11px;border-radius:3px;background:%s\"></span></td><td style=\"padding:3px 6px;color:#1f2733\">%s</td><td align=\"right\" style=\"padding:3px 0;font-weight:bold;color:#1f2733\">%s <span style=\"color:#6b7785;font-weight:normal\">%.1f%%</span></td></tr>\n",col[i],lbl[i],fmt(val[i]),pct;
        }
        print "</table></div>";
    }'
}

###############################################################################
# BARRAS HORIZONTALES
#   $1 título  $2 subtítulo  $3 colorhex acento
#   stdin: etiqueta|valor  (ya ordenadas; hasta 10)
###############################################################################
ipfr_hbars() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        _ipfr_hbars_mail "$1" "$2" "$3"
    else
        _ipfr_hbars_web "$1" "$2" "$3"
    fi
}

_ipfr_hbars_web() {
    awk -F'|' -v title="$1" -v subtitle="$2" -v accent="${3:-#dc143c}" -v ndp="$(t 'reports lib nodata period' 'Sin datos para el periodo')" '
    function fmt(x,   s,o,l,i,c){ s=sprintf("%d",x+0); l=length(s); o=""; c=0;
        for(i=l;i>=1;i--){ o=substr(s,i,1) o; c++; if(c%3==0 && i>1) o="," o } return o }
    function esc(t){ gsub(/&/,"\\&amp;",t); gsub(/</,"\\&lt;",t); gsub(/>/,"\\&gt;",t); return t }
    { if(NR<=10){ lbl[NR]=$1; val[NR]=$2+0; if(val[NR]>max)max=val[NR] } }
    END{
        n=(NR>10?10:NR);
        W=620; padL=18; rowH=38; barH=20; labelW=190; valW=70;
        barX=padL+labelW; barMax=W-barX-valW-padL;
        H=(n>0?n*rowH+12:60);
        print "<div class=\"ipfr-card\">";
        if(title!="")    print "<div class=\"ipfr-card__t\">" title "</div>";
        if(subtitle!="") print "<div class=\"ipfr-card__s\">" subtitle "</div>";
        if(n==0){ print "<div class=\"ipfr-empty\">" ndp "</div></div>"; exit }
        printf "<svg class=\"ipfr-bars\" viewBox=\"0 0 %d %d\" role=\"img\" aria-label=\"%s\">\n",W,H,title;
        for(i=1;i<=n;i++){
            y=(i-1)*rowH+6; cy=y+rowH/2; barY=cy-barH/2;
            w=(max>0?val[i]/max*barMax:0); if(w<2 && val[i]>0) w=2;
            lab=esc(lbl[i]); if(length(lbl[i])>24){ lab=esc(substr(lbl[i],1,23)) "\xe2\x80\xa6" }
            printf "<g class=\"ipfr-bar-row\">";
            printf "<text x=\"%d\" y=\"%.1f\" class=\"ipfr-bar-rank\" dominant-baseline=\"middle\">%d</text>",padL,cy,i;
            printf "<text x=\"%d\" y=\"%.1f\" class=\"ipfr-bar-lbl\" dominant-baseline=\"middle\">%s</text>",padL+18,cy,lab;
            printf "<rect class=\"ipfr-track\" x=\"%d\" y=\"%.1f\" width=\"%d\" height=\"%d\" rx=\"6\"/>",barX,barY,barMax,barH;
            printf "<rect class=\"ipfr-bar\" x=\"%d\" y=\"%.1f\" width=\"%.1f\" height=\"%d\" rx=\"6\" fill=\"%s\" style=\"animation-delay:%.2fs\"><title>%s: %s</title></rect>",barX,barY,w,barH,accent,(i-1)*0.06,esc(lbl[i]),fmt(val[i]);
            printf "<text x=\"%d\" y=\"%.1f\" class=\"ipfr-bar-val\" text-anchor=\"end\" dominant-baseline=\"middle\">%s</text>",W-padL,cy,fmt(val[i]);
            print "</g>";
        }
        print "</svg></div>";
    }'
}

# Barras en correo: tabla; cada fila etiqueta + barra (tabla anidada) + valor.
_ipfr_hbars_mail() {
    awk -F'|' -v title="$1" -v subtitle="$2" -v accent="${3:-#dc143c}" -v ndp="$(t 'reports lib nodata period' 'Sin datos para el periodo')" '
    function fmt(x,   s,o,l,i,c){ s=sprintf("%d",x+0); l=length(s); o=""; c=0;
        for(i=l;i>=1;i--){ o=substr(s,i,1) o; c++; if(c%3==0 && i>1) o="," o } return o }
    function esc(t){ gsub(/&/,"\\&amp;",t); gsub(/</,"\\&lt;",t); gsub(/>/,"\\&gt;",t); return t }
    { if(NR<=10){ lbl[NR]=$1; val[NR]=$2+0; if(val[NR]>max)max=val[NR] } }
    END{
        n=(NR>10?10:NR);
        print "<div style=\"background:#ffffff;border:1px solid #e6e9ef;border-radius:10px;padding:14px 16px;margin:8px 0 16px\">";
        if(title!="")    print "<div style=\"font-size:14px;font-weight:bold;color:#1f2733\">" title "</div>";
        if(subtitle!="") print "<div style=\"font-size:11px;color:#6b7785;margin-bottom:8px\">" subtitle "</div>";
        if(n==0){ print "<div style=\"text-align:center;color:#6b7785;font-style:italic;padding:12px\">" ndp "</div></div>"; exit }
        print "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"font-size:12px\">";
        for(i=1;i<=n;i++){
            pct=(max>0?val[i]/max*100:0); if(pct<2 && val[i]>0) pct=2; rest=100-pct;
            lab=esc(lbl[i]); if(length(lbl[i])>22) lab=esc(substr(lbl[i],1,21)) "&hellip;";
            print "<tr>";
            printf "<td width=\"170\" style=\"padding:4px 8px 4px 0;color:#1f2733;font-weight:bold;white-space:nowrap\">%d. %s</td>",i,lab;
            printf "<td style=\"padding:4px 0\"><table role=\"presentation\" width=\"100%%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"background:#eef1f6;border-radius:5px\"><tr><td width=\"%.1f%%\" bgcolor=\"%s\" style=\"background:%s;height:16px;border-radius:5px;font-size:0;line-height:0\">&nbsp;</td><td width=\"%.1f%%\" style=\"font-size:0;line-height:0\">&nbsp;</td></tr></table></td>",pct,accent,accent,rest;
            printf "<td align=\"right\" width=\"64\" style=\"padding:4px 0 4px 8px;font-weight:bold;color:#1f2733\">%s</td>",fmt(val[i]);
            print "</tr>";
        }
        print "</table></div>";
    }'
}

###############################################################################
# MAPA DE CALOR (día x hora)
#   $1 título  $2 leyenda  $3 colorhex acento  $4 lista de días "YYYY-MM-DD ..."
#   stdin: líneas "YYYY-MM-DD<TAB>HH" (una por evento)
#   Ligero: tabla de celdas con bgcolor (sin SVG, sin JS, válido en correo).
###############################################################################
ipfr_heatmap() {
    awk -F'\t' -v title="$1" -v caption="$2" -v accent="${3:-#dc143c}" -v days="$4" '
    function shade(c,  f,r,g,b){
        f=(c<=0)?0.05:(max>0?0.18+0.82*c/max:0.05); if(f>1)f=1;
        r=strtonum("0x" substr(accent,2,2)); g=strtonum("0x" substr(accent,4,2)); b=strtonum("0x" substr(accent,6,2));
        return sprintf("#%02x%02x%02x", int(255+(r-255)*f+0.5), int(255+(g-255)*f+0.5), int(255+(b-255)*f+0.5));
    }
    { d=$1; h=$2+0; cnt[d,h]++; if(cnt[d,h]>max) max=cnt[d,h] }
    END{
        nd=split(days,dl," ");
        print "<div style=\"background:#ffffff;border:1px solid #e6e9ef;border-radius:13px;padding:16px 18px;margin:8px 0 16px;overflow-x:auto\">";
        if(title!="")   print "<div style=\"font-size:14px;font-weight:bold;color:#1f2733\">" title "</div>";
        if(caption!="") print "<div style=\"font-size:11px;color:#6b7785;margin:2px 0 12px;line-height:1.5\">" caption "</div>";
        if(nd==0){ print "<div style=\"color:#6b7785;font-style:italic;padding:8px\">&mdash;</div></div>"; exit }
        print "<table class=\"ipfr-hm\" width=\"100%\" cellspacing=\"2\" cellpadding=\"0\" border=\"0\" style=\"width:100%;table-layout:fixed;border-collapse:separate\">";
        printf "<tr><td width=\"76\"></td>";
        for(h=0;h<24;h++) printf "<td class=\"hh\" style=\"font-size:9px;color:#6b7785;text-align:center\">%d</td>", h;
        print "</tr>";
        for(i=1;i<=nd;i++){
            d=dl[i];
            printf "<tr><td class=\"dd\" width=\"76\" style=\"font-size:10px;color:#6b7785;text-align:right;padding-right:6px;white-space:nowrap\">%s</td>", d;
            for(h=0;h<24;h++){ c=cnt[d,h]+0; printf "<td class=\"c\" height=\"15\" bgcolor=\"%s\" title=\"%s %02dh: %d\"></td>", shade(c), d, h, c; }
            print "</tr>";
        }
        print "</table></div>";
    }'
}

###############################################################################
# AVISOS
###############################################################################
ipfr_alerts_open() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then echo '<div style="margin:14px 0 4px">'; else echo '<div class="ipfr-alerts">'; fi
}
ipfr_alerts_close() { echo '</div>'; }

# $1 type(danger|warn|ok) $2 título $3 detalle
ipfr_alert() {
    if [[ "${IPFR_MAIL:-0}" == "1" ]]; then
        local bg bd col
        case "$1" in
            danger) bg="#fef2f2"; bd="#dc2626"; col="#991b1b" ;;
            warn)   bg="#fffbeb"; bd="#f59e0b"; col="#92400e" ;;
            *)      bg="#f0fdf4"; bd="#22a559"; col="#166534" ;;
        esac
        printf '<div style="background:%s;border-left:4px solid %s;color:%s;padding:11px 14px;border-radius:8px;margin:8px 0;font-size:13px;font-weight:bold">%s<div style="font-weight:normal;font-size:12px;margin-top:3px">%s</div></div>\n' \
            "$bg" "$bd" "$col" "$2" "$3"
    else
        printf '<div class="ipfr-alert ipfr-alert--%s">%s<small>%s</small></div>\n' "$1" "$2" "$3"
    fi
}
