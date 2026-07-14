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

# English language file for Firewall Backup Addon

%tr = (
%tr,

# Main titles
'firewall backup title' => 'Firewall Backup',
'firewall backup manager' => 'Firewall Backup Manager',
'error messages' => 'Error Messages',
'success messages' => 'Success Messages',

# Statistics
'statistic' => 'Statistic',
'value' => 'Value',
'total backups' => 'Total Backups',
'files per backup' => 'Files per Backup',
'storage locations' => 'Storage Locations',

# Create backup
'create new backup' => 'Create New Backup',
'backup comment' => 'Backup comment',
'backup comment placeholder' => 'e.g., Backup before updating NAT rules',
'create backup' => 'Create Backup',

# Backup list
'available backups' => 'Available Backups',
'backup name' => 'Backup Name',
'timestamp' => 'Date/Time',
'size' => 'Size',
'comment' => 'Comment',
'actions' => 'Actions',
'restore' => 'Restore',
'download' => 'Download',
'delete' => 'Delete',
'no backups available' => 'No backups available. Create your first backup using the form above.',

# Success messages
'backup created successfully' => 'Backup created successfully',
'backup restored successfully' => 'Backup restored successfully',
'current config saved as' => 'Current config saved as',
'backup deleted successfully' => 'Backup deleted successfully',
'no automatic backup needed' => 'No automatic backup needed - current config was already backed up',
'backup identical to current' => 'The selected backup is identical to the current configuration. No changes made.',
'firewall changes pending' => 'Firewall configuration changed. Use the Apply button to activate changes.',

# Error messages
'error creating backup directory' => 'Error creating backup directory',
'error creating subdirectories' => 'Error creating subdirectories',
'errors during backup' => 'Errors during backup',
'errors during restoration' => 'Errors during restoration',
'backup not found' => 'Backup not found',
'error copying' => 'Error copying',
'error restoring' => 'Error restoring',
'error deleting backup' => 'Error deleting backup',
'failed to create download file' => 'Failed to create download file',

# Confirmations
'restore confirm' => 'Are you sure you want to restore this backup?',
'delete confirm' => 'Are you sure you want to delete this backup?',

# Automatic comments
'no comment' => 'No comment',
'automatic backup comment' => 'Automatic backup before restoration',
'imported comment' => 'Imported backup',

# Statistics (new)
'total size' => 'Total Size',
'last backup' => 'Last Backup',
'never' => 'Never',
'backup includes' => 'Each backup is a single compressed package (.tar.gz) with all firewall rules, NAT, custom hosts, networks, service and location groups.',

# Export / Import
'export' => 'Export',
'import backup' => 'Import Backup',
'import' => 'Import',
'import help' => 'Select a .tar.gz backup file previously exported from this or another IPFire system.',
'select backup file' => 'Backup file (.tar.gz)',
'backup imported successfully' => 'Backup imported successfully',
'no file selected' => 'No file selected for import',
'invalid backup file' => 'The file is not a valid firewall backup',
'unsafe archive' => 'The archive contains unsafe paths and was rejected',
'import error' => 'Error importing backup',
'failed to store backup' => 'Failed to store the imported backup',

# Other new messages
'invalid backup name' => 'Invalid backup name',
'backup already exists' => 'A backup with this name already exists',
'failed to create archive' => 'Failed to create compressed archive',
'error extracting backup' => 'Error extracting backup',
'failed to read backup' => 'Failed to read backup file',

);