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

# Simplified Chinese language file for Firewall Backup Addon

%tr = (
%tr,

# Main titles
'firewall backup title' => '备份恢复',
'firewall backup manager' => '备份管理',
'error messages' => '错误消息',
'success messages' => '成功消息',

# Statistics
'statistic' => '统计项',
'value' => '值',
'total backups' => '备份总数',
'files per backup' => '每个备份的文件数',
'storage locations' => '存储位置',

# Create backup
'create new backup' => '创建新备份',
'backup comment' => '备份备注',
'backup comment placeholder' => '例如：更新 NAT 规则前的备份',
'create backup' => '创建备份',

# Backup list
'available backups' => '备份列表',
'backup name' => '文件名称',
'timestamp' => '日期/时间',
'size' => '大小',
'comment' => '备注',
'actions' => '操作',
'restore' => '恢复',
'download' => '下载',
'delete' => '删除',
'no backups available' => '暂无可用备份。请使用上方表单创建第一个备份。',

# Success messages
'backup created successfully' => '备份创建成功',
'backup restored successfully' => '备份恢复成功',
'current config saved as' => '当前配置已保存为',
'backup deleted successfully' => '备份删除成功',
'no automatic backup needed' => '无需自动备份 - 当前配置已经备份',
'backup identical to current' => '所选备份与当前配置相同，未进行任何更改。',
'firewall changes pending' => '防火墙配置已更改。请使用“应用”按钮激活更改。',

# Error messages
'error creating backup directory' => '创建备份目录时出错',
'error creating subdirectories' => '创建子目录时出错',
'errors during backup' => '备份过程中发生错误',
'errors during restoration' => '恢复过程中发生错误',
'backup not found' => '未找到备份',
'error copying' => '复制时出错',
'error restoring' => '恢复时出错',
'error deleting backup' => '删除备份时出错',
'failed to create download file' => '创建下载文件失败',

# Confirmations
'restore confirm' => '确定要恢复此备份吗？',
'delete confirm' => '确定要删除此备份吗？',

# Automatic comments
'no comment' => '无备注',
'automatic backup comment' => '恢复前自动备份',
'imported comment' => '导入的备份',

# Statistics (new)
'total size' => '总大小',
'last backup' => '上次备份',
'never' => '从未',
'backup includes' => '每个备份都是一个压缩包（.tar.gz），包含所有防火墙规则、NAT、自定义主机、网络、服务组和位置组。',

# Export / Import
'export' => '导出',
'import backup' => '导入备份',
'import' => '导入',
'import help' => '请选择此前从本机或其他 IPFire 系统导出的 .tar.gz 备份文件。',
'select backup file' => '备份文件（.tar.gz）',
'backup imported successfully' => '备份导入成功',
'no file selected' => '未选择要导入的文件',
'invalid backup file' => '该文件不是有效的防火墙备份',
'unsafe archive' => '归档文件包含不安全路径，已被拒绝',
'import error' => '导入备份时出错',
'failed to store backup' => '保存导入的备份失败',

# Other new messages
'invalid backup name' => '备份名称无效',
'backup already exists' => '已存在同名备份',
'failed to create archive' => '创建压缩归档失败',
'error extracting backup' => '解压备份时出错',
'failed to read backup' => '读取备份文件失败',

);
