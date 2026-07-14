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

# File di lingua Italiana per Firewall Backup Addon

%tr = (
%tr,

# Main titles
'firewall backup title' => 'Backup Firewall',
'firewall backup manager' => 'Firewall Backup Manager',
'error messages' => 'Messaggio Errore',
'success messages' => 'Messaggi di successo',

# Statistics
'statistic' => 'Statistica',
'value' => 'Valore',
'total backups' => 'Backup totale',
'files per backup' => 'File per backup',
'storage locations' => 'Locazione del disco',

# Create backup
'create new backup' => 'Crea un nuovo backup',
'backup comment' => 'Commenti per Backup',
'backup comment placeholder' => 'Ad esempio, eseguire un backup prima di aggiornare le regole NAT.',
'create backup' => 'Crea Backup',

# Backup list
'available backups' => 'Backup disponibili',
'backup name' => 'Nome Backup',
'timestamp' => 'Data/Ora',
'size' => 'Dimensione',
'comment' => 'Commenti',
'actions' => 'Azione',
'restore' => 'Ripristina',
'download' => 'Download',
'delete' => 'Cancella',
'no backups available' => 'Nessun backup disponibile. Crea il tuo primo backup utilizzando il modulo qui sopra.',

# Success messages
'backup created successfully' => 'Backup creato correttamente',
'backup restored successfully' => 'Backup ripristinato correttamente',
'current config saved as' => 'Configurazione corrente salvata come',
'backup deleted successfully' => 'Backup eliminato correttamente',
'no automatic backup needed' => 'Non è necessario alcun backup automatico: la configurazione corrente è già stata salvata.',
'backup identical to current' => 'Il backup selezionato è identico alla configurazione corrente. Nessuna modifica apportata.',
'firewall changes pending' => 'La configurazione del firewall è stata modificata. Utilizzare il pulsante Applica per attivare le modifiche.',

# Error messages
'error creating backup directory' => 'Errore durante la creazione della directory di backup',
'error creating subdirectories' => 'Errore durante la creazione delle sottocartelle',
'errors during backup' => 'Errori durante il backup',
'errors during restoration' => 'Errori durante il ripristino',
'backup not found' => 'Backup non trovato',
'error copying' => 'Errore durante la copia',
'error restoring' => 'Errore durante il ripristino',
'error deleting backup' => 'Errore durante l\'eliminazione del backup',
'failed to create download file' => 'Impossibile creare il file di download',

# Confirmations
'restore confirm' => 'Sei sicuro di voler ripristinare questo backup?',
'delete confirm' => 'Sei sicuro di voler eliminare questo backup?',

# Automatic comments
'no comment' => 'Nessun commento',
'automatic backup comment' => 'Backup automatico prima del ripristino',
'imported comment' => 'Backup importato',

# Statistics (new)
'total size' => 'Dimensione totale',
'last backup' => 'Ultimo backup',
'never' => 'Mai',
'backup includes' => 'Ogni backup è un singolo pacchetto compresso (.tar.gz) con tutte le regole del firewall, NAT, host, reti, gruppi di servizi e di posizione personalizzati.',

# Export / Import
'export' => 'Esporta',
'import backup' => 'Importa Backup',
'import' => 'Importa',
'import help' => 'Seleziona un file di backup .tar.gz esportato in precedenza da questo o da un altro sistema IPFire.',
'select backup file' => 'File di backup (.tar.gz)',
'backup imported successfully' => 'Backup importato correttamente',
'no file selected' => 'Nessun file selezionato per l\'importazione',
'invalid backup file' => 'Il file non è un backup del firewall valido',
'unsafe archive' => 'L\'archivio contiene percorsi non sicuri ed è stato rifiutato',
'import error' => 'Errore durante l\'importazione del backup',
'failed to store backup' => 'Impossibile salvare il backup importato',

# Other new messages
'invalid backup name' => 'Nome del backup non valido',
'backup already exists' => 'Esiste già un backup con questo nome',
'failed to create archive' => 'Impossibile creare l\'archivio compresso',
'error extracting backup' => 'Errore durante l\'estrazione del backup',
'failed to read backup' => 'Impossibile leggere il file di backup',

);