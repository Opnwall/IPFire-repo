#!/usr/bin/perl
###############################################################################
#                                                                             #
# IPFire.org - Sistema de Generación de Informes (Versión Limpia)            #
# Copyright (C) 2007-2025  IPFire Team  <info@ipfire.org>                     #
#                                                                             #
# Generador automático de informes - Versión compacta y optimizada           #
# Versión 5.3 - Código limpio y eficiente                                    #
#                                                                             #
###############################################################################

use strict;
use warnings;
use lib "/usr/lib/ipfire";
use CGI::Carp 'fatalsToBrowser';
use File::Basename;

require '/var/ipfire/general-functions.pl';
require "${General::swroot}/lang.pl";
require "${General::swroot}/header.pl";

# ============================================================================
# CONFIGURACIÓN Y CONSTANTES
# ============================================================================

our $VERSION = "5.3";

use constant {
    SETTINGS_FILE    => "/var/ipfire/reports/settings",
    REPORTS_DIR      => "/var/ipfire/reports", 
    REPORTS_HTML_DIR => "/var/ipfire/reports/reports",
    MAIL_SCRIPT      => "/var/ipfire/reports/send_mail.sh"
};

my %REPORT_TYPES = (
    'FIREWALL' => { 
        file   => 'fw-report.html',  
        label  => $Lang::tr{'reports firewall label'},
        script => '/var/ipfire/reports/fw-report.sh'
    },
    'IDS' => { 
        file   => 'ids-report.html', 
        label  => $Lang::tr{'reports ids label'},
        script => '/var/ipfire/reports/ids-report.sh'
    },
    'URL' => {
        file   => 'url-report.html',
        label  => $Lang::tr{'reports url label'},
        script => '/var/ipfire/reports/url-report.sh'
    },
    'DNSFW' => {
        file   => 'dnsfw-report.html',
        label  => $Lang::tr{'reports dnsfw label'},
        script => '/var/ipfire/reports/dnsfw-report.sh'
    },
);

my %SCOPE_OPTIONS = (
    'SCOPE_HOUR'  => $Lang::tr{'reports scope hour'},
    'SCOPE_DAY'   => $Lang::tr{'reports scope day'},
    'SCOPE_WEEK'  => $Lang::tr{'reports scope week'},
    'SCOPE_MONTH' => $Lang::tr{'reports scope month'}
);

my %cgiparams = ();
my ($errormessage, $successmessage) = ('', '');

# ============================================================================
# PUNTO DE ENTRADA
# ============================================================================

&Header::getcgihash(\%cgiparams);
initialize_system();
my %settings = process_form_actions();
display_interface(\%settings);

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

sub initialize_system {
    for my $dir (REPORTS_DIR, REPORTS_HTML_DIR) {
        warn "Directorio no existe: $dir" unless -d $dir;
    }
    
    eval { create_default_settings() unless -f SETTINGS_FILE; };
    warn "Error creando configuración: $@" if $@;
}

sub create_default_settings {
    my %defaults = map { $_ => 'off' } (keys %REPORT_TYPES, keys %SCOPE_OPTIONS, 'SCHEDULER');
    
    my $settings_dir = SETTINGS_FILE;
    $settings_dir =~ s{/[^/]*$}{} or $settings_dir = '/var/ipfire';
    
    unless (-d $settings_dir) {
        if (mkdir $settings_dir, 0755) {
            eval { chown 65534, 65534, $settings_dir; };
        } else {
            warn "Error creando directorio: $!";
            return;
        }
    }
    
    save_configuration(\%defaults);
}

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

sub load_configuration {
    my %config = map { $_ => 'off' } (keys %REPORT_TYPES, keys %SCOPE_OPTIONS, 'SCHEDULER');
    &General::readhash(SETTINGS_FILE, \%config) if -f SETTINGS_FILE;
    
    my @available_reports = get_available_reports();
    for my $report (keys %REPORT_TYPES) {
        unless (grep { $_ eq $report } @available_reports) {
            $config{$report} = 'off';
        }
    }
    
    return %config;
}

sub save_configuration {
    my ($config_ref) = @_;
    my @available_reports = get_available_reports();
    
    my $settings_dir = SETTINGS_FILE;
    $settings_dir =~ s{/[^/]*$}{} or $settings_dir = '/var/ipfire';
    
    unless (-d $settings_dir) {
        return unless mkdir $settings_dir, 0755;
        eval { chown 65534, 65534, $settings_dir; };
    }
    
    return if -d $settings_dir && !-w $settings_dir;
    
    for my $report (keys %REPORT_TYPES) {
        unless (grep { $_ eq $report } @available_reports) {
            $config_ref->{$report} = 'off';
        }
    }
    
    if (open my $fh, '>', SETTINGS_FILE) {
        for my $key (sort keys %$config_ref) {
            printf $fh "%s=%s\n", $key, ($config_ref->{$key} || 'off');
        }
        close $fh;
        eval { chmod 0644, SETTINGS_FILE; };
    } else {
        warn "Error escribiendo configuración: $!";
    }
}

# ============================================================================
# VERIFICACIÓN DE SERVICIOS
# ============================================================================

sub check_service_enabled {
    my ($config_file, $setting_key) = @_;
    
    return 0 unless -f $config_file && -r $config_file;
    
    if (open my $fh, '<', $config_file) {
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^\Q$setting_key\E=(.*)$/) {
                my $value = $1;
                $value =~ s/^['"]//;
                $value =~ s/['"]$//;
                close $fh;
                return $value eq 'on';
            }
        }
        close $fh;
    }
    
    return 0;
}

sub is_ids_enabled {
    return check_service_enabled('/var/ipfire/suricata/settings', 'ENABLE_IDS');
}

sub is_url_filter_enabled {
    return check_service_enabled('/var/ipfire/proxy/settings', 'ENABLE_FILTER');
}

sub is_dnsfw_enabled {
    # DNS Firewall disponible si alguna lista RPZ está en "on" en /var/ipfire/dns/dnsbl
    my $file = '/var/ipfire/dns/dnsbl';
    return 0 unless -f $file && -r $file;
    open my $fh, '<', $file or return 0;
    while (my $line = <$fh>) {
        if ($line =~ /^[^,]+,on,/) {
            close $fh;
            return 1;
        }
    }
    close $fh;
    return 0;
}

sub get_available_reports {
    my @available_reports = ('FIREWALL');

    push @available_reports, 'IDS' if is_ids_enabled();
    push @available_reports, 'URL' if is_url_filter_enabled();
    push @available_reports, 'DNSFW' if is_dnsfw_enabled();

    return @available_reports;
}

# ============================================================================
# UTILIDADES
# ============================================================================

sub get_selected_scope {
    my ($config_ref) = @_;
    for my $scope (keys %SCOPE_OPTIONS) {
        return $scope if $config_ref->{$scope} eq 'on';
    }
    return '';
}

sub has_selected_reports {
    my ($config_ref) = @_;
    my @available_reports = get_available_reports();
    return grep { $config_ref->{$_} eq 'on' } @available_reports;
}

sub reports_exist_check {
    return 0 unless -d REPORTS_HTML_DIR;
    
    opendir my $dh, REPORTS_HTML_DIR or return 0;
    my @html_files = grep { /\.html?$/i && -s REPORTS_HTML_DIR . "/$_" } readdir $dh;
    closedir $dh;
    
    return @html_files > 0;
}

sub cleanup_old_reports {
    return unless -d REPORTS_HTML_DIR && -w REPORTS_HTML_DIR;
    
    opendir my $dh, REPORTS_HTML_DIR or return;
    my @html_files = grep { /\.html?$/i } readdir $dh;
    closedir $dh;
    
    for my $file (@html_files) {
        my $file_path = REPORTS_HTML_DIR . "/$file";
        unlink $file_path or warn "Error borrando $file_path: $!";
    }
}

# ============================================================================
# PROCESAMIENTO DE ACCIONES
# ============================================================================

sub process_form_actions {
    my %config = load_configuration();
    my $action = $cgiparams{'ACTION'} || '';
    
    if (%cgiparams && $action) {
        update_config_from_cgi(\%config);
    }
    
    if ($action eq $Lang::tr{'save'}) {
        handle_save_action(\%config);
    } elsif ($action eq $Lang::tr{'reports generate'}) {
        handle_generate_action(\%config);
    } elsif ($action eq $Lang::tr{'reports delete'}) {
        handle_delete_action();
    } elsif ($action eq $Lang::tr{'reports send'}) {
        handle_send_action();
    }
    
    return %config;
}

sub update_config_from_cgi {
    my ($config_ref) = @_;
    my @available_reports = get_available_reports();
    
    # CORRECCIÓN: Primero establecer todos los informes disponibles a 'off'
    for my $report (@available_reports) {
        $config_ref->{$report} = 'off';
    }
    
    # Luego activar solo los que están marcados en el formulario
    for my $report (@available_reports) {
        if (defined $cgiparams{$report} && $cgiparams{$report} eq 'on') {
            $config_ref->{$report} = 'on';
        }
    }
    
    # Asegurar que los informes no disponibles estén desactivados
    for my $report (keys %REPORT_TYPES) {
        unless (grep { $_ eq $report } @available_reports) {
            $config_ref->{$report} = 'off';
        }
    }
    
    # CORRECCIÓN: Manejar scope (ámbito temporal) - NO resetear si no se envía
    # Solo actualizar el scope si hay uno seleccionado en el formulario
    if (defined $cgiparams{'SCOPE'} && exists $SCOPE_OPTIONS{$cgiparams{'SCOPE'}}) {
        # Primero desactivar todos los scopes
        $config_ref->{$_} = 'off' for keys %SCOPE_OPTIONS;
        # Luego activar el seleccionado
        $config_ref->{$cgiparams{'SCOPE'}} = 'on';
    }
    # Si no se envía ningún SCOPE en el formulario, mantener la configuración actual
    
    # Manejar scheduler
    $config_ref->{'SCHEDULER'} = (defined $cgiparams{'SCHEDULER'} && $cgiparams{'SCHEDULER'} eq 'on') ? 'on' : 'off';
}

sub handle_save_action {
    my ($config_ref) = @_;
    save_configuration($config_ref);
    $successmessage = $Lang::tr{'settings saved'};
}

sub handle_generate_action {
    my ($config_ref) = @_;
    my @selected_reports = has_selected_reports($config_ref);
    
    unless (@selected_reports) {
        $errormessage = $Lang::tr{'reports no selection error'};
        return;
    }
    
    save_configuration($config_ref);
    
    unless (-d REPORTS_DIR) {
        $errormessage = $Lang::tr{'reports dir error'} . ": " . REPORTS_DIR;
        return;
    }
    
    unless (-d REPORTS_HTML_DIR) {
        $errormessage = $Lang::tr{'reports html dir error'} . ": " . REPORTS_HTML_DIR;
        return;
    }
    
    unless (-w REPORTS_HTML_DIR) {
        $errormessage = $Lang::tr{'reports write permission error'} . " " . REPORTS_HTML_DIR;
        return;
    }
    
    cleanup_old_reports();
    execute_report_scripts($config_ref);
}

sub execute_report_scripts {
    my ($config_ref) = @_;
    my $success_count = 0;
    my @errors = ();
    my @available_reports = get_available_reports();
    
    for my $report (@available_reports) {
        next unless $config_ref->{$report} eq 'on';
        
        my $script_path = $REPORT_TYPES{$report}{'script'};
        my $report_file = REPORTS_HTML_DIR . "/" . $REPORT_TYPES{$report}{'file'};
        
        unless (-f $script_path && -x $script_path) {
            push @errors, $Lang::tr{'reports script not found'} . ": $script_path";
            next;
        }
        
        my $cmd = "cd " . REPORTS_DIR . " && ./" . basename($script_path) . " 2>&1";
        my $output = `$cmd`;
        my $result = $?;
        
        if ($result == 0) {
            if (-f $report_file && -s $report_file) {
                $success_count++;
            } else {
                push @errors, $Lang::tr{'reports script executed no file'} . " " . basename($script_path);
            }
        } else {
            my $exit_code = $result >> 8;
            push @errors, $Lang::tr{'reports script execution error'} . " " . basename($script_path) . " ($Lang::tr{'reports exit code'}: $exit_code)";
        }
    }
    
    my $total_selected = scalar(grep { $config_ref->{$_} eq 'on' } @available_reports);
    if ($success_count > 0) {
        $successmessage = $Lang::tr{'reports generated successfully'} . " ($success_count/$total_selected)";
        if (@errors) {
            $successmessage .= ". " . $Lang::tr{'reports some errors'} . ": " . join("; ", @errors);
        }
    } else {
        $errormessage = $Lang::tr{'reports generation error'} . ": " . join("; ", @errors);
    }
}

sub handle_delete_action {
    cleanup_old_reports();
    $successmessage = $Lang::tr{'reports files deleted'};
}

sub handle_send_action {
    unless (-x MAIL_SCRIPT) {
        $errormessage = $Lang::tr{'reports mail script not found'};
        return;
    }
    
    my $result = system(MAIL_SCRIPT . " >/dev/null 2>&1");
    if ($result == 0) {
        $successmessage = $Lang::tr{'reports sent successfully'};
    } else {
        $errormessage = $Lang::tr{'reports send error'};
    }
}

# ============================================================================
# INTERFAZ DE USUARIO
# ============================================================================

sub display_interface {
    my ($config_ref) = @_;
    
    &Header::showhttpheaders();
    &Header::openpage($Lang::tr{'reports generator'}, 1, '');
    &Header::openbigbox('100%', 'left', '', $errormessage);
    
    display_messages();
    render_styles_and_scripts();
    render_configuration_panel($config_ref);
    render_reports_panel($config_ref);
    
    &Header::closebox();
    &Header::closebigbox();
    &Header::closepage();
}

sub display_messages {
    if ($errormessage) {
        &Header::openbox('100%', 'left', $Lang::tr{'error messages'});
        print qq{<div class='alert-error'>$errormessage</div>\n};
        &Header::closebox();
    }
    
    if ($successmessage) {
        &Header::openbox('100%', 'left', $Lang::tr{'information'});
        print qq{<div class='alert-success'>$successmessage</div>\n};
        &Header::closebox();
    }
}

# ============================================================================
# ESTILOS Y SCRIPTS
# ============================================================================

sub render_styles_and_scripts {
    print <<'EOF';
<style>
/* Mensajes */
.alert-error {
    background-color: #f8d7da;
    border: 1px solid #f5c6cb;
    color: #721c24;
    padding: 6px 10px;
    border-radius: 3px;
    margin: 5px 0;
    font-weight: bold;
}

.alert-success {
    background-color: #d4edda;
    border: 1px solid #c3e6cb;
    color: #155724;
    padding: 6px 10px;
    border-radius: 3px;
    margin: 5px 0;
    font-weight: bold;
}

/* Contenedores */
.config-container, .reports-container {
    background-color: #ffffff;
    border: 1px solid #cccccc;
    border-radius: 3px;
    padding: 12px;
    margin: 6px 0;
    max-width: 95%;
    margin-left: auto;
    margin-right: auto;
}

.reports-container {
    max-height: 500px;
    overflow-y: auto;
    overflow-x: hidden;
}

/* Títulos */
.section-title {
    font-size: 22px;
    font-weight: bold;
    color: #333333;
    margin-bottom: 10px;
    padding-bottom: 5px;
    border-bottom: 2px solid #0066cc;
}

/* Grupos de opciones */
.option-group {
    background-color: #f8f9fa;
    border: 1px solid #dddddd;
    border-radius: 3px;
    padding: 10px;
    margin: 6px 0;
    transition: background-color 0.3s ease;
}

.option-group.no-reports-selected {
    background-color: #ffebee;
    border-color: #ffcdd2;
}

.option-group.scheduler-inactive {
    background-color: #ffebee;
    border-color: #ffcdd2;
}

.option-row {
    display: flex;
    align-items: center;
    padding: 5px 0;
}

.option-row input[type="checkbox"],
.option-row input[type="radio"] {
    margin-right: 8px;
    width: 14px;
    height: 14px;
    cursor: pointer;
    transition: opacity 0.3s ease;
}

.option-row input[type="checkbox"]:disabled,
.option-row input[type="radio"]:disabled {
    cursor: not-allowed;
}

.option-row label {
    flex: 1;
    font-weight: 500;
    color: #333333;
    cursor: pointer;
    transition: opacity 0.3s ease;
    font-size: 13px;
}

.option-row label.disabled {
    cursor: not-allowed;
}

.option-row input[type="checkbox"]:disabled + label,
.option-row input[type="radio"]:disabled + label {
    pointer-events: none;
}

/* Botones */
.button-area {
    text-align: center;
    padding: 12px 0;
    background-color: #f8f9fa;
    border: 1px solid #dddddd;
    border-radius: 3px;
    margin: 8px 0;
}

.classic-btn {
    background: linear-gradient(to bottom, #ffffff 0%, #e6e6e6 100%);
    border: 1px solid #999999;
    border-radius: 3px;
    padding: 6px 12px;
    margin: 0 4px;
    font-size: 12px;
    font-weight: bold;
    color: #333333;
    cursor: pointer;
    transition: all 0.2s ease;
    min-width: 100px;
    height: 28px;
}

.classic-btn:hover:not(:disabled) {
    background: linear-gradient(to bottom, #f0f0f0 0%, #d4d4d4 100%);
    border-color: #666666;
}

.classic-btn:active:not(:disabled) {
    background: linear-gradient(to bottom, #e6e6e6 0%, #cccccc 100%);
    box-shadow: inset 0 1px 2px rgba(0,0,0,0.1);
}

.classic-btn:disabled {
    cursor: not-allowed !important;
    background: #f5f5f5 !important;
    border-color: #cccccc !important;
    color: #999999 !important;
}

/* Separadores */
.separator {
    height: 1px;
    background-color: #dddddd;
    margin: 12px 0;
    border: none;
}

/* Informes */
.report-title {
    color: #333333;
    font-size: 13px;
    font-weight: bold;
    margin: 10px 0 5px 0;
    padding-bottom: 2px;
    border-bottom: 1px solid #dddddd;
}

.report-content {
    background-color: #ffffff;
    border: 1px solid #dddddd;
    border-radius: 3px;
    padding: 8px;
    margin: 5px 0;
}

.no-reports {
    text-align: center;
    padding: 25px 15px;
    color: #666666;
    font-style: italic;
    background-color: #ffffff;
    border: 2px dashed #cccccc;
    border-radius: 6px;
}

/* Responsive */
@media (max-width: 768px) {
    .config-container, .reports-container {
        padding: 10px;
        margin: 4px 0;
        max-width: 98%;
    }
    
    .classic-btn {
        display: block;
        width: 85%;
        margin: 4px auto;
    }
    
    .reports-container {
        max-height: 350px;
    }
    
    .section-title {
        font-size: 18px;
    }
}
</style>

<script>
function updateControlStates() {
    const availableReports = getAvailableReports();
    const scopeRadios = ['SCOPE_HOUR', 'SCOPE_DAY', 'SCOPE_WEEK', 'SCOPE_MONTH'];
    
    const hasReportsSelected = availableReports.some(id => {
        const checkbox = document.getElementById(id);
        return checkbox && checkbox.checked;
    });
    
    const reportsGroup = document.getElementById('reports-option-group');
    if (reportsGroup) {
        if (hasReportsSelected) {
            reportsGroup.classList.remove('no-reports-selected');
        } else {
            reportsGroup.classList.add('no-reports-selected');
        }
    }
    
    [...scopeRadios, 'SCHEDULER'].forEach(id => {
        const element = document.getElementById(id);
        const label = document.querySelector(`label[for="${id}"]`);
        
        if (element && label) {
            element.disabled = !hasReportsSelected;
            element.style.opacity = hasReportsSelected ? '1' : '0.5';
            label.style.opacity = hasReportsSelected ? '1' : '0.5';
            label.classList.toggle('disabled', !hasReportsSelected);
        }
    });
    
    const generateBtn = document.getElementById('generate-btn');
    if (generateBtn) {
        generateBtn.disabled = !hasReportsSelected;
        generateBtn.style.opacity = hasReportsSelected ? '1' : '0.5';
        generateBtn.style.cursor = hasReportsSelected ? 'pointer' : 'not-allowed';
    }
    
    updateSchedulerStatus();
}

function getAvailableReports() {
    const allReports = ['FIREWALL', 'IDS', 'URL', 'DNSFW'];
    return allReports.filter(id => document.getElementById(id) !== null);
}

function updateSchedulerStatus() {
    const schedulerCheckbox = document.getElementById('SCHEDULER');
    const schedulerGroup = document.getElementById('scheduler-option-group');
    
    if (!schedulerCheckbox || !schedulerGroup) return;
    
    if (schedulerCheckbox.checked) {
        schedulerGroup.classList.remove('scheduler-inactive');
    } else {
        schedulerGroup.classList.add('scheduler-inactive');
    }
}

function forceInitialColors() {
    const schedulerCheckbox = document.getElementById('SCHEDULER');
    const schedulerGroup = document.getElementById('scheduler-option-group');
    
    if (schedulerCheckbox && schedulerGroup && !schedulerCheckbox.checked) {
        schedulerGroup.classList.add('scheduler-inactive');
    }
}

document.addEventListener('DOMContentLoaded', function() {
    setTimeout(function() {
        forceInitialColors();
        updateSchedulerStatus();
        updateControlStates();
    }, 50);
    
    const availableReports = getAvailableReports();
    availableReports.forEach(id => {
        const checkbox = document.getElementById(id);
        if (checkbox) {
            checkbox.addEventListener('change', updateControlStates);
        }
    });
    
    const schedulerCheckbox = document.getElementById('SCHEDULER');
    const scopeRadios = ['SCOPE_HOUR', 'SCOPE_DAY', 'SCOPE_WEEK', 'SCOPE_MONTH'];
    
    if (schedulerCheckbox) {
        schedulerCheckbox.addEventListener('change', updateSchedulerStatus);
    }
    
    scopeRadios.forEach(id => {
        const radio = document.getElementById(id);
        if (radio) {
            radio.addEventListener('change', updateSchedulerStatus);
        }
    });
});
</script>
EOF
}

# ============================================================================
# PANEL DE CONFIGURACIÓN
# ============================================================================

sub render_configuration_panel {
    my ($config_ref) = @_;
    my $script_name = $ENV{'SCRIPT_NAME'} || '';
    
    print qq{<div class='config-container'>\n};
    print qq{<form method='post' action='$script_name'>\n};
    
    render_reports_selection($config_ref);
    render_scope_selection($config_ref);
    render_scheduler_section($config_ref);
    render_action_buttons($config_ref);
    
    print "</form>\n";
    print "</div>\n";
}

sub render_reports_selection {
    my ($config_ref) = @_;
    my @available_reports = get_available_reports();
    
    print qq{<div class='section-title'>} . $Lang::tr{'reports selection title'} . qq{</div>\n};
    print qq{<div class='option-group' id='reports-option-group'>\n};
    
    unless (@available_reports) {
        print qq{
            <div style='text-align: center; padding: 15px; color: #666666; font-style: italic;'>
                <p>} . $Lang::tr{'reports no services configured'} . qq{</p>
            </div>
        };
        print "</div>\n";
        print qq{<hr class='separator'>\n};
        return;
    }
    
    for my $report (@available_reports) {
        my $checked = $config_ref->{$report} eq 'on' ? 'checked' : '';
        my $label = $REPORT_TYPES{$report}{'label'};
        
        print qq{
            <div class='option-row'>
                <input type='checkbox' id='$report' name='$report' value='on' $checked>
                <label for='$report'>$label</label>
            </div>
        };
    }
    
    print "</div>\n";
    print qq{<hr class='separator'>\n};
}

sub render_scope_selection {
    my ($config_ref) = @_;
    my $current_scope = get_selected_scope($config_ref);
    
    print qq{<div class='section-title'>} . $Lang::tr{'reports scope title'} . qq{</div>\n};
    print qq{<div class='option-group'>\n};
    print qq{<div style='display: flex; justify-content: space-between; padding: 8px;'>\n};
    
    for my $scope (qw(SCOPE_HOUR SCOPE_DAY SCOPE_WEEK SCOPE_MONTH)) {
        my $checked = $current_scope eq $scope ? 'checked' : '';
        my $label = $SCOPE_OPTIONS{$scope};
        
        print qq{
            <div style='flex: 1; display: flex; align-items: center; justify-content: center;'>
                <input type='radio' id='$scope' name='SCOPE' value='$scope' $checked style='margin-right: 6px; width: 14px; height: 14px; cursor: pointer;'>
                <label for='$scope' style='font-weight: 500; color: #333333; cursor: pointer; font-size: 12px;'>$label</label>
            </div>
        };
    }
    
    print "</div>\n";
    print "</div>\n";
    print qq{<hr class='separator'>\n};
}

sub render_scheduler_section {
    my ($config_ref) = @_;
    my $checked = $config_ref->{'SCHEDULER'} eq 'on' ? 'checked' : '';
    my $group_class = $config_ref->{'SCHEDULER'} eq 'on' ? 'option-group' : 'option-group scheduler-inactive';
    
    print qq{<div class='section-title'>} . $Lang::tr{'reports scheduler title'} . qq{</div>\n};
    print qq{<div class='$group_class' id='scheduler-option-group'>\n};
    print qq{<div style='display: flex; align-items: center; justify-content: center; padding: 8px;'>\n};
    print qq{
        <div style='display: flex; align-items: center;'>
            <input type='checkbox' id='SCHEDULER' name='SCHEDULER' value='on' $checked style='margin-right: 8px; width: 14px; height: 14px; cursor: pointer;'>
            <label for='SCHEDULER' style='font-weight: bold; color: #333333; cursor: pointer; font-size: 13px;'><strong>} . $Lang::tr{'reports activate task'} . qq{</strong></label>
        </div>
    };
    print "</div>\n";
    print "</div>\n";
}

sub render_action_buttons {
    my ($config_ref) = @_;
    my $reports_exist = reports_exist_check();
    my $has_selected_reports = has_selected_reports($config_ref);
    
    my $generate_disabled = $has_selected_reports ? '' : 'disabled';
    my $generate_style = $has_selected_reports ? '' : 'style="opacity: 0.5; cursor: not-allowed;"';
    
    my $delete_disabled = $reports_exist ? '' : 'disabled';
    my $delete_style = $reports_exist ? '' : 'style="opacity: 0.5; cursor: not-allowed;"';
    
    my $send_disabled = $reports_exist ? '' : 'disabled';
    my $send_style = $reports_exist ? '' : 'style="opacity: 0.5; cursor: not-allowed;"';
    
    print qq{<div class='button-area'>\n};
    print qq{<input type='submit' name='ACTION' value='} . $Lang::tr{'save'} . qq{' class='classic-btn'>\n};
    print qq{<input type='submit' name='ACTION' value='} . $Lang::tr{'reports generate'} . qq{' class='classic-btn' id='generate-btn' $generate_disabled $generate_style>\n};
    print qq{<input type='submit' name='ACTION' value='} . $Lang::tr{'reports delete'} . qq{' class='classic-btn' id='delete-btn' $delete_disabled $delete_style>\n};
    print qq{<input type='submit' name='ACTION' value='} . $Lang::tr{'reports send'} . qq{' class='classic-btn' id='send-btn' $send_disabled $send_style>\n};
    print "</div>\n";
}

# ============================================================================
# PANEL DE INFORMES
# ============================================================================

sub render_reports_panel {
    my ($config_ref) = @_;
    my @available_reports = get_available_reports();
    
    print qq{<div class='reports-container'>\n};
    print qq{<div class='section-title'>} . $Lang::tr{'reports generated title'} . qq{</div>\n};
    
    my @active_reports = grep { $config_ref->{$_} eq 'on' } @available_reports;
    
    if (@active_reports) {
        for my $i (0 .. $#active_reports) {
            render_single_report($active_reports[$i]);
            print qq{<hr class='separator'>\n} if $i < $#active_reports;
        }
    } else {
        print qq{
            <div class='no-reports'>
                <h4>} . $Lang::tr{'reports no selection display'} . qq{</h4>
                <p>} . $Lang::tr{'reports check boxes message'} . qq{</p>
            </div>
        };
    }
    
    print "</div>\n";
}

sub render_single_report {
    my ($report_type) = @_;
    my $file_path = REPORTS_HTML_DIR . "/" . $REPORT_TYPES{$report_type}{'file'};
    my $label = $REPORT_TYPES{$report_type}{'label'};
    
    print qq{<h4 class='report-title'>$label</h4>\n};
    
    if (-f $file_path && -s $file_path) {
        print qq{<div class='report-content'>\n};
        
        if (open my $fh, '<', $file_path) {
            local $/;
            my $content = <$fh>;
            close $fh;
            
            # Sanitizar contenido
            $content =~ s/<script[^>]*>.*?<\/script>//gis;
            $content =~ s/<iframe[^>]*>.*?<\/iframe>//gis;
            $content =~ s/javascript:/removed-javascript:/gis;
            $content =~ s/on\w+\s*=\s*["'][^"']*["']//gis;
            
            if ($content =~ /<html|<table|<div|<h\d/i) {
                print $content;
            } else {
                $content =~ s/&/&amp;/g;
                $content =~ s/</&lt;/g;
                $content =~ s/>/&gt;/g;
                $content =~ s/\n/<br>\n/g;
                print qq{<div style="font-family: monospace; white-space: pre-wrap;">$content</div>};
            }
        } else {
            print qq{<p style='color: red;'>} . $Lang::tr{'reports file read error'} . qq{: $!</p>\n};
        }
        
        print "</div>\n";
    } else {
        print qq{
            <div style='background: #fff3cd; border: 1px solid #ffeaa7; padding: 8px; border-radius: 3px; margin: 6px 0;'>
                <p><em>} . $Lang::tr{'reports not generated yet'} . qq{</em></p>
            </div>
        };
    }
}

1;