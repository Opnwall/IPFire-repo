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

# Archivo de idioma espa�ol para Firewall Backup Addon

%tr = (
%tr,

# T�tulos principales
'firewall backup title' => 'Backup de Firewall',
'firewall backup manager' => 'Gestor de Backups de Firewall',
'error messages' => 'Mensajes de Error',
'success messages' => 'Mensajes de &Eacute;xito',

# Estad�sticas
'statistic' => 'Estad&iacute;stica',
'value' => 'Valor',
'total backups' => 'Backups Totales',
'files per backup' => 'Archivos por Backup',
'storage locations' => 'Ubicaciones de Almacenamiento',

# Crear backup
'create new backup' => 'Crear Nuevo Backup',
'backup comment' => 'Comentario del backup',
'backup comment placeholder' => 'ej., Backup antes de actualizar reglas NAT',
'create backup' => 'Crear Backup',

# Lista de backups
'available backups' => 'Backups Disponibles',
'backup name' => 'Nombre del Backup',
'timestamp' => 'Fecha/Hora',
'size' => 'Tama&ntilde;o',
'comment' => 'Comentario',
'actions' => 'Acciones',
'restore' => 'Restaurar',
'download' => 'Descargar',
'delete' => 'Eliminar',
'no backups available' => 'No hay backups disponibles. Cree su primer backup usando el formulario de arriba.',

# Mensajes de �xito
'backup created successfully' => 'Backup creado exitosamente',
'backup restored successfully' => 'Backup restaurado exitosamente',
'current config saved as' => 'Configuraci&oacute;n actual guardada como',
'backup deleted successfully' => 'Backup eliminado exitosamente',
'no automatic backup needed' => 'No se necesita backup autom&aacute;tico - la configuraci&oacute;n actual ya estaba respaldada',
'backup identical to current' => 'El backup seleccionado es id&eacute;ntico a la configuraci&oacute;n actual. No se realizaron cambios.',
'firewall changes pending' => 'Configuraci&oacute;n del firewall modificada. Use el bot&oacute;n Aplicar para activar los cambios.',

# Mensajes de error
'error creating backup directory' => 'Error creando directorio de backup',
'error creating subdirectories' => 'Error creando subdirectorios',
'errors during backup' => 'Errores durante el backup',
'errors during restoration' => 'Errores durante la restauraci&oacute;n',
'backup not found' => 'Backup no encontrado',
'error copying' => 'Error copiando',
'error restoring' => 'Error restaurando',
'error deleting backup' => 'Error eliminando backup',
'failed to create download file' => 'Error creando archivo de descarga',

# Confirmaciones
'restore confirm' => '&iquest;Est&aacute; seguro de restaurar este backup?',
'delete confirm' => '&iquest;Est&aacute; seguro de eliminar este backup?',

# Comentarios autom�ticos
'no comment' => 'Sin comentario',
'automatic backup comment' => 'Backup autom&aacute;tico antes de restauraci&oacute;n',
'imported comment' => 'Backup importado',

# Estad�sticas (nuevas)
'total size' => 'Tama&ntilde;o Total',
'last backup' => '&Uacute;ltimo Backup',
'never' => 'Nunca',
'backup includes' => 'Cada backup es un &uacute;nico paquete comprimido (.tar.gz) con todas las reglas del firewall, NAT, hosts, redes, grupos de servicios y de localizaci&oacute;n personalizados.',

# Exportar / Importar
'export' => 'Exportar',
'import backup' => 'Importar Backup',
'import' => 'Importar',
'import help' => 'Seleccione un archivo de backup .tar.gz exportado previamente desde este u otro sistema IPFire.',
'select backup file' => 'Archivo de backup (.tar.gz)',
'backup imported successfully' => 'Backup importado exitosamente',
'no file selected' => 'No se seleccion&oacute; ning&uacute;n archivo para importar',
'invalid backup file' => 'El archivo no es un backup de firewall v&aacute;lido',
'unsafe archive' => 'El archivo contiene rutas no seguras y fue rechazado',
'import error' => 'Error al importar el backup',
'failed to store backup' => 'No se pudo almacenar el backup importado',

# Otros mensajes nuevos
'invalid backup name' => 'Nombre de backup no v&aacute;lido',
'backup already exists' => 'Ya existe un backup con este nombre',
'failed to create archive' => 'Error al crear el archivo comprimido',
'error extracting backup' => 'Error al extraer el backup',
'failed to read backup' => 'Error al leer el archivo de backup',

);