#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A Linux Firewall                                              #
# Copyright (C) 2007-2024  IPFire Team                                       #
#                                                                             #
# This program is free software: you can redistribute it and/or modify        #
# it under the terms of the GNU General Public License as published by        #
# the Free Software Foundation, either version 3 of the License, or           #
# (at your option) any later version.                                         #
#                                                                             #
# This program is distributed in the hope that it will be useful,             #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
# GNU General Public License for more details.                               #
#                                                                             #
# You should have received a copy of the GNU General Public License           #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.       #
#                                                                             #
###############################################################################

# Deutsche Sprachdatei f�r Firewall Backup Addon

%tr = (
%tr,

# Haupttitel
'firewall backup title' => 'Firewall Backup',
'firewall backup manager' => 'Firewall Backup Manager',
'error messages' => 'Fehlermeldungen',
'success messages' => 'Erfolgsmeldungen',

# Statistiken
'statistic' => 'Statistik',
'value' => 'Wert',
'total backups' => 'Backups Gesamt',
'files per backup' => 'Dateien pro Backup',
'storage locations' => 'Speicherorte',

# Backup erstellen
'create new backup' => 'Neues Backup Erstellen',
'backup comment' => 'Backup-Kommentar',
'backup comment placeholder' => 'z.B. Backup vor NAT-Regeln-Update',
'create backup' => 'Backup Erstellen',

# Backup-Liste
'available backups' => 'Verfügbare Backups',
'backup name' => 'Backup-Name',
'timestamp' => 'Datum/Zeit',
'size' => 'Größe',
'comment' => 'Kommentar',
'actions' => 'Aktionen',
'restore' => 'Wiederherstellen',
'download' => 'Herunterladen',
'delete' => 'Löschen',
'no backups available' => 'Keine Backups verfügbar. Erstellen Sie Ihr erstes Backup mit dem obigen Formular.',

# Erfolgsmeldungen
'backup created successfully' => 'Backup erfolgreich erstellt',
'backup restored successfully' => 'Backup erfolgreich wiederhergestellt',
'current config saved as' => 'Aktuelle Konfiguration gespeichert als',
'backup deleted successfully' => 'Backup erfolgreich gelöscht',
'no automatic backup needed' => 'Kein automatisches Backup erforderlich - aktuelle Konfiguration war bereits gesichert',
'backup identical to current' => 'Das ausgewählte Backup ist identisch mit der aktuellen Konfiguration. Keine Änderungen vorgenommen.',
'firewall changes pending' => 'Firewall-Konfiguration geändert. Verwenden Sie die Schaltfläche Anwenden, um Änderungen zu aktivieren.',

# Fehlermeldungen
'error creating backup directory' => 'Fehler beim Erstellen des Backup-Verzeichnisses',
'error creating subdirectories' => 'Fehler beim Erstellen der Unterverzeichnisse',
'errors during backup' => 'Fehler während des Backups',
'errors during restoration' => 'Fehler während der Wiederherstellung',
'backup not found' => 'Backup nicht gefunden',
'error copying' => 'Fehler beim Kopieren',
'error restoring' => 'Fehler bei der Wiederherstellung',
'error deleting backup' => 'Fehler beim Löschen des Backups',
'failed to create download file' => 'Fehler beim Erstellen der Download-Datei',

# Best�tigungen
'restore confirm' => 'Sind Sie sicher, dass Sie dieses Backup wiederherstellen möchten?',
'delete confirm' => 'Sind Sie sicher, dass Sie dieses Backup löschen möchten?',

# Automatische Kommentare
'no comment' => 'Kein Kommentar',
'automatic backup comment' => 'Automatisches Backup vor Wiederherstellung',
'imported comment' => 'Importiertes Backup',

# Statistiken (neu)
'total size' => 'Gesamtgröße',
'last backup' => 'Letztes Backup',
'never' => 'Nie',
'backup includes' => 'Jedes Backup ist ein einzelnes komprimiertes Paket (.tar.gz) mit allen Firewall-Regeln, NAT, benutzerdefinierten Hosts, Netzwerken, Dienst- und Standortgruppen.',

# Export / Import
'export' => 'Exportieren',
'import backup' => 'Backup Importieren',
'import' => 'Importieren',
'import help' => 'Wählen Sie eine zuvor von diesem oder einem anderen IPFire-System exportierte .tar.gz-Backup-Datei aus.',
'select backup file' => 'Backup-Datei (.tar.gz)',
'backup imported successfully' => 'Backup erfolgreich importiert',
'no file selected' => 'Keine Datei zum Importieren ausgewählt',
'invalid backup file' => 'Die Datei ist kein gültiges Firewall-Backup',
'unsafe archive' => 'Das Archiv enthält unsichere Pfade und wurde abgelehnt',
'import error' => 'Fehler beim Importieren des Backups',
'failed to store backup' => 'Das importierte Backup konnte nicht gespeichert werden',

# Weitere neue Meldungen
'invalid backup name' => 'Ungültiger Backup-Name',
'backup already exists' => 'Ein Backup mit diesem Namen existiert bereits',
'failed to create archive' => 'Fehler beim Erstellen des komprimierten Archivs',
'error extracting backup' => 'Fehler beim Entpacken des Backups',
'failed to read backup' => 'Fehler beim Lesen der Backup-Datei',

);