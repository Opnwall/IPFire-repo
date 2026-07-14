#!/bin/bash
###############################################################################
#                                                                             #
# IPFire.org - Envío por correo de los informes (UTF-8)                       #
# Copyright (C) 2007-2025  IPFire Team                                        #
#                                                                             #
# Envía un correo MIME multipart/mixed con:                                   #
#   1) CUERPO: versión "email-safe" (tablas, colores sólidos, sin SVG/JS) que #
#      se ve bien en la vista previa de cualquier cliente de correo.          #
#   2) ADJUNTO: informe completo e INTERACTIVO en HTML (donut/barras SVG,     #
#      animaciones, hover) que se abre en el navegador con un clic.           #
#                                                                             #
# El cuerpo email-safe se regenera ejecutando cada informe con IPFR_MAIL=1;   #
# el adjunto combina los HTML ricos ya generados en /var/ipfire/reports/...   #
#                                                                             #
###############################################################################

SETTINGS_FILE="/var/ipfire/reports/settings"
MAIL_CONF="/var/ipfire/dma/mail.conf"
SENDMAIL="/usr/sbin/sendmail"
GEN_DIR="/var/ipfire/reports"
HTML_DIR="/var/ipfire/reports/reports"

LIB="$(dirname "$(readlink -f "$0")")/report-lib.sh"
[[ -f "$LIB" ]] || LIB="/var/ipfire/reports/report-lib.sh"
# shellcheck source=/var/ipfire/reports/report-lib.sh
source "$LIB"

# Verificar sendmail
if [[ ! -x "$SENDMAIL" ]]; then
    echo "Error: no se encontró $SENDMAIL o no tiene permisos de ejecución" >&2
    exit 1
fi

# Remitente y destinatario
SENDER=$(grep -E '^SENDER=' "$MAIL_CONF" | head -n1 | cut -d'=' -f2- | tr -d ' ')
if [[ -z "$SENDER" ]]; then
    echo "Error: No se encontró SENDER en $MAIL_CONF" >&2
    exit 1
fi
RECIPIENT=$(grep -E '^RECIPIENT=' "$MAIL_CONF" | head -n1 | cut -d'=' -f2- | tr -d ' ')
if [[ -z "$RECIPIENT" ]]; then
    echo "Error: No se encontró RECIPIENT en $MAIL_CONF" >&2
    exit 1
fi

# Extraer el cuerpo del informe (entre centinelas). Reserva: documento completo.
extract_body() {
    local file="$1"
    if grep -q 'IPFR:BODY:START' "$file" 2>/dev/null; then
        sed -n '/IPFR:BODY:START/,/IPFR:BODY:END/p' "$file"
    else
        cat "$file"
    fi
}

# Informes: clave|html-rico|script-generador|título
ORDERED_REPORTS=(
    "FIREWALL|fw-report.html|fw-report.sh|Informe de Firewall"
    "IDS|ids-report.html|ids-report.sh|Informe IDS/IPS"
    "URL|url-report.html|url-report.sh|Informe de Filtro de URL"
    "DNSFW|dnsfw-report.html|dnsfw-report.sh|Informe DNS Firewall"
)

MAIL_BODY=""     # cuerpo email-safe (regenerado con IPFR_MAIL=1)
RICH_BODY=""     # cuerpo interactivo (HTML ricos ya generados)
ANY_ENABLED=0

for ENTRY in "${ORDERED_REPORTS[@]}"; do
    IFS="|" read -r KEY HTML SCRIPT TITLE <<< "$ENTRY"
    STATE=$(grep -E "^$KEY=" "$SETTINGS_FILE" | cut -d'=' -f2)
    [[ "$STATE" == "on" ]] || { echo "Informe deshabilitado: $TITLE (estado: ${STATE:-off})"; continue; }
    ANY_ENABLED=1

    # 1) Cuerpo email-safe: regenerar este informe en modo correo
    TMP_MAIL=$(mktemp /tmp/ipfr_mail.XXXXXX) || TMP_MAIL="/tmp/ipfr_mail.$$.$KEY"
    if IPFR_MAIL=1 bash "$GEN_DIR/$SCRIPT" -o "$TMP_MAIL" >/dev/null 2>&1 && [[ -s "$TMP_MAIL" ]]; then
        MAIL_BODY+="$(extract_body "$TMP_MAIL")"$'\n<div style="height:20px"></div>\n'
        echo "Informe incluido (cuerpo): $TITLE"
    else
        echo "Aviso: no se pudo regenerar la versión correo de $TITLE"
    fi
    rm -f "$TMP_MAIL"

    # 2) Adjunto interactivo: usar el HTML rico ya generado
    if [[ -f "$HTML_DIR/$HTML" && -s "$HTML_DIR/$HTML" ]]; then
        RICH_BODY+="$(extract_body "$HTML_DIR/$HTML")"$'\n'
        echo "Informe incluido (adjunto): $TITLE"
    else
        echo "Aviso: no existe el HTML interactivo $HTML_DIR/$HTML (¿genera primero los informes?)"
    fi
done

if [[ "$ANY_ENABLED" -eq 0 ]]; then
    echo "No hay informes habilitados para enviar." >&2
    exit 0
fi
if [[ -z "$MAIL_BODY" && -z "$RICH_BODY" ]]; then
    echo "No hay contenido de informes para enviar (genera los informes primero)." >&2
    exit 0
fi

# Hojas de estilo de cada modo
IPFR_MAIL=1; MAIL_CSS=$(ipfr_css)
IPFR_MAIL=0; WEB_CSS=$(ipfr_css)

# Documento del cuerpo (email-safe)
MAIL_DOC="<!DOCTYPE html>
<html lang=\"es\"><head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">${MAIL_CSS}</head>
<body style=\"margin:0;padding:20px;background:#eef1f6;font-family:Arial,Helvetica,sans-serif\">
<p style=\"max-width:680px;margin:0 auto 14px;color:#475569;font-size:13px\">Resumen del sistema IPFire. Para la versión <strong>interactiva</strong> (gráficas con detalle al pasar el ratón), abre el archivo HTML adjunto en tu navegador.</p>
${MAIL_BODY}
</body></html>"

# Documento adjunto (interactivo / web)
RICH_DOC="<!DOCTYPE html>
<html lang=\"es\"><head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Informe IPFire</title>${WEB_CSS}</head>
<body style=\"background:#f4f6fa;margin:0;padding:20px\">
${RICH_BODY}
</body></html>"

ATT_NAME="informe-ipfire-$(date '+%Y%m%d-%H%M').html"
BOUNDARY="=_ipfr_$(date +%s)_$$"

# Componer y enviar el correo MIME multipart
{
    echo "To: $RECIPIENT"
    echo "Subject: Informes del sistema IPFire"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\""
    echo ""
    echo "Este mensaje requiere un cliente compatible con MIME."
    echo ""
    # Parte 1: cuerpo HTML email-safe
    echo "--$BOUNDARY"
    echo "Content-Type: text/html; charset=UTF-8"
    echo "Content-Transfer-Encoding: base64"
    echo ""
    printf '%s' "$MAIL_DOC" | base64
    # Parte 2: adjunto HTML interactivo (si existe)
    if [[ -n "$RICH_BODY" ]]; then
        echo "--$BOUNDARY"
        echo "Content-Type: text/html; charset=UTF-8; name=\"$ATT_NAME\""
        echo "Content-Transfer-Encoding: base64"
        echo "Content-Disposition: attachment; filename=\"$ATT_NAME\""
        echo ""
        printf '%s' "$RICH_DOC" | base64
    fi
    echo "--$BOUNDARY--"
} | "$SENDMAIL" -f "$SENDER" -t

if [[ $? -eq 0 ]]; then
    echo "Informe enviado exitosamente a $RECIPIENT (adjunto: $ATT_NAME)"
else
    echo "Error al enviar el informe" >&2
    exit 1
fi
