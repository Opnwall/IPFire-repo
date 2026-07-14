#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - A Linux Firewall                                               #
# Copyright (C) 2007-2024  IPFire Team                                        #
#                                                                             #
# This program is free software: you can redistribute it and/or modify         #
# it under the terms of the GNU General Public License as published by         #
# the Free Software Foundation, either version 3 of the License, or            #
# (at your option) any later version.                                          #
#                                                                             #
###############################################################################

# Traditional Chinese language file for Firewall Backup Addon

%tr = (
%tr,

# Main titles
'firewall backup title' => '防火牆備份',
'firewall backup manager' => '防火牆備份管理器',
'error messages' => '錯誤訊息',
'success messages' => '成功訊息',

# Statistics
'statistic' => '統計項目',
'value' => '值',
'total backups' => '備份總數',
'files per backup' => '每個備份的檔案數',
'storage locations' => '儲存位置',

# Create backup
'create new backup' => '建立新備份',
'backup comment' => '備份備註',
'backup comment placeholder' => '例如：更新 NAT 規則前的備份',
'create backup' => '建立備份',

# Backup list
'available backups' => '可用備份',
'backup name' => '備份名稱',
'timestamp' => '日期/時間',
'size' => '大小',
'comment' => '備註',
'actions' => '操作',
'restore' => '還原',
'download' => '下載',
'delete' => '刪除',
'no backups available' => '目前沒有可用備份。請使用上方表單建立第一個備份。',

# Success messages
'backup created successfully' => '備份已成功建立',
'backup restored successfully' => '備份已成功還原',
'current config saved as' => '目前設定已儲存為',
'backup deleted successfully' => '備份已成功刪除',
'no automatic backup needed' => '不需要自動備份 - 目前設定已經備份',
'backup identical to current' => '所選備份與目前設定相同，未進行任何變更。',
'firewall changes pending' => '防火牆設定已變更。請使用「套用」按鈕啟用變更。',

# Error messages
'error creating backup directory' => '建立備份目錄時發生錯誤',
'error creating subdirectories' => '建立子目錄時發生錯誤',
'errors during backup' => '備份期間發生錯誤',
'errors during restoration' => '還原期間發生錯誤',
'backup not found' => '找不到備份',
'error copying' => '複製時發生錯誤',
'error restoring' => '還原時發生錯誤',
'error deleting backup' => '刪除備份時發生錯誤',
'failed to create download file' => '建立下載檔案失敗',

# Confirmations
'restore confirm' => '確定要還原此備份嗎？',
'delete confirm' => '確定要刪除此備份嗎？',

# Automatic comments
'no comment' => '無備註',
'automatic backup comment' => '還原前自動備份',
'imported comment' => '匯入的備份',

# Statistics (new)
'total size' => '總大小',
'last backup' => '上次備份',
'never' => '從未',
'backup includes' => '每個備份都是單一壓縮套件（.tar.gz），包含所有防火牆規則、NAT、自訂主機、網路、服務群組和位置群組。',

# Export / Import
'export' => '匯出',
'import backup' => '匯入備份',
'import' => '匯入',
'import help' => '請選擇先前從本機或其他 IPFire 系統匯出的 .tar.gz 備份檔。',
'select backup file' => '備份檔案（.tar.gz）',
'backup imported successfully' => '備份已成功匯入',
'no file selected' => '未選擇要匯入的檔案',
'invalid backup file' => '此檔案不是有效的防火牆備份',
'unsafe archive' => '封存檔包含不安全路徑，已被拒絕',
'import error' => '匯入備份時發生錯誤',
'failed to store backup' => '儲存匯入的備份失敗',

# Other new messages
'invalid backup name' => '備份名稱無效',
'backup already exists' => '已存在同名備份',
'failed to create archive' => '建立壓縮封存失敗',
'error extracting backup' => '解壓縮備份時發生錯誤',
'failed to read backup' => '讀取備份檔案失敗',

);
