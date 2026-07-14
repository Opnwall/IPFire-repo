# Fichier de langue Français pour Reports Generator
# /var/ipfire/lang/fr.pl (section reports)
# Base : reports.es.pl · accents en entités HTML (indépendant de l'encodage)
# Contribution française d'origine : @steph78630

# Titres principaux
$tr{'Reports'} = 'Rapports';
$tr{'reports generator'} = 'G&eacute;n&eacute;rateur de rapports';
$tr{'reports selection title'} = 'S&eacute;lection des rapports';
$tr{'reports scope title'} = 'Port&eacute;e du rapport / T&acirc;che planifi&eacute;e';
$tr{'reports scheduler title'} = 'Planificateur de t&acirc;ches de rapports';
$tr{'reports generated title'} = 'Rapports g&eacute;n&eacute;r&eacute;s';

# &Eacute;tiquettes des types de rapports
$tr{'reports firewall label'} = 'TOP 10 Rapport - Pare-feu';
$tr{'reports ids label'} = 'TOP 10 Rapport - IDS/IPS';
$tr{'reports url label'} = 'TOP 10 Rapport - Filtre URL';
$tr{'reports dnsfw label'} = 'TOP 10 Rapport - DNS Firewall';

# Options de p&eacute;riode
$tr{'reports scope hour'} = 'Heure';
$tr{'reports scope day'} = 'Jour';
$tr{'reports scope week'} = 'Semaine';
$tr{'reports scope month'} = 'Mois';

# Planificateur de t&acirc;ches
$tr{'reports activate task'} = 'Activer la t&acirc;che d&#39;envoi';
$tr{'reports scheduler active'} = 'Planificateur actif';
$tr{'reports scheduler inactive'} = 'Planificateur inactif';
$tr{'reports scheduler no scope'} = 'Planificateur activ&eacute; mais aucune p&eacute;riode s&eacute;lectionn&eacute;e';

# Boutons d&#39;action
$tr{'reports generate'} = 'Générer les rapports';
$tr{'reports delete'} = 'Supprimer les rapports';
$tr{'reports send'} = 'Envoyer les rapports';

# Messages d&#39;&eacute;tat
$tr{'reports generated successfully'} = 'Rapports g&eacute;n&eacute;r&eacute;s avec succ&egrave;s';
$tr{'reports sent successfully'} = 'Rapports envoy&eacute;s avec succ&egrave;s';
$tr{'reports files deleted'} = 'Fichiers supprim&eacute;s';
$tr{'reports some errors'} = 'Quelques erreurs';

# Messages d&#39;erreur
$tr{'reports no selection error'} = 'Aucun rapport s&eacute;lectionn&eacute; &agrave; g&eacute;n&eacute;rer';
$tr{'reports dir error'} = 'Erreur : le r&eacute;pertoire de base n&#39;existe pas';
$tr{'reports html dir error'} = 'Erreur : le r&eacute;pertoire des rapports n&#39;existe pas';
$tr{'reports write permission error'} = 'Erreur : pas de permission d&#39;&eacute;criture dans';
$tr{'reports script not found'} = 'Script introuvable ou non ex&eacute;cutable';
$tr{'reports script executed no file'} = 'Script ex&eacute;cut&eacute; mais aucun fichier g&eacute;n&eacute;r&eacute;';
$tr{'reports script execution error'} = 'Erreur lors de l&#39;ex&eacute;cution de';
$tr{'reports exit code'} = 'code';
$tr{'reports generation error'} = 'Erreur lors de la g&eacute;n&eacute;ration des rapports';
$tr{'reports mail script not found'} = 'Script d&#39;envoi introuvable';
$tr{'reports send error'} = 'Erreur lors de l&#39;envoi des rapports';
$tr{'reports file read error'} = 'Erreur de lecture du fichier';

# Messages d&#39;information
$tr{'reports no selection display'} = 'Aucun rapport s&eacute;lectionn&eacute; &agrave; afficher';
$tr{'reports check boxes message'} = 'Cochez les cases pour voir les rapports';
$tr{'reports not generated yet'} = 'Rapport pas encore g&eacute;n&eacute;r&eacute;';

# >>> reports auto-i18n (generado; no editar a mano) >>>
$tr{'reports period hour'} = 'dernière heure';
$tr{'reports period day'} = 'dernier jour';
$tr{'reports period week'} = '7 derniers jours';
$tr{'reports period month'} = 'dernier mois (30 jours)';
$tr{'reports generated on'} = 'Généré le';
$tr{'reports period word'} = 'Période';
$tr{'reports sec overview'} = 'Vue d&#39;ensemble';
$tr{'reports th blocks'} = 'Blocages';
$tr{'reports th client ip'} = 'IP client';
$tr{'reports th domain'} = 'Domaine';
$tr{'reports th pct'} = '%';
$tr{'reports nodata'} = 'Aucune donnée';
$tr{'reports nodata period'} = 'Aucune donnée pour la période';
$tr{'reports footer system'} = 'Système de rapports';
$tr{'reports footer period'} = 'période';
$tr{'reports dnsfw title'} = 'Rapport du pare-feu DNS';
$tr{'reports dnsfw stat blocks'} = 'Blocages totaux';
$tr{'reports dnsfw stat blocks d'} = 'Requêtes DNS bloquées';
$tr{'reports dnsfw stat domains'} = 'Domaines uniques';
$tr{'reports dnsfw stat domains d'} = 'Domaines distincts bloqués';
$tr{'reports dnsfw stat clients'} = 'Clients uniques';
$tr{'reports dnsfw stat clients d'} = 'Appareils ayant demandé';
$tr{'reports dnsfw stat lists'} = 'Listes actives';
$tr{'reports dnsfw stat lists d'} = 'Listes RPZ activées';
$tr{'reports dnsfw donut title'} = 'Blocages par liste';
$tr{'reports dnsfw donut sub'} = 'Répartition par liste RPZ (TOP 6)';
$tr{'reports dnsfw unit blocks'} = 'blocages';
$tr{'reports dnsfw sec topdomains'} = 'domaines bloqués';
$tr{'reports dnsfw bars sub'} = 'Domaines les plus bloqués';
$tr{'reports dnsfw sec topclients'} = 'clients les plus bloqués';
$tr{'reports dnsfw sec listactivity'} = 'Activité par liste RPZ';
$tr{'reports dnsfw th list'} = 'Liste';
$tr{'reports dnsfw empty'} = 'Aucun blocage pour la période';
$tr{'reports dnsfw footer lists'} = 'listes actives';
$tr{'reports cat porn'} = 'Pornographie';
$tr{'reports cat ads'} = 'Publicité';
$tr{'reports cat dating'} = 'Rencontres';
$tr{'reports cat doh'} = 'DNS-over-HTTPS public';
$tr{'reports cat gambling'} = 'Jeux d&#39;argent';
$tr{'reports cat games'} = 'Jeux';
$tr{'reports cat malware'} = 'Logiciels malveillants';
$tr{'reports cat phishing'} = 'Hameçonnage';
$tr{'reports cat piracy'} = 'Piratage';
$tr{'reports cat shopping'} = 'Achats';
$tr{'reports cat smart-tv'} = 'Smart TV';
$tr{'reports cat social'} = 'Réseaux sociaux';
$tr{'reports cat streaming'} = 'Streaming';
$tr{'reports cat violence'} = 'Violence';
$tr{'reports lib nodata'} = 'Aucune donnée';
$tr{'reports lib nodata period'} = 'Aucune donnée pour la période';
$tr{'reports fw title'} = 'Rapport du pare-feu';
$tr{'reports fw stat drops'} = 'Paquets bloqués';
$tr{'reports fw stat drops d'} = 'Connexions rejetées (DROP)';
$tr{'reports fw stat accepts'} = 'Paquets acceptés';
$tr{'reports fw stat accepts d'} = 'Connexions autorisées (ACCEPT)';
$tr{'reports fw stat rejects'} = 'Paquets refusés';
$tr{'reports fw stat rejects d'} = 'Connexions refusées (REJECT)';
$tr{'reports fw donut title'} = 'Trafic du pare-feu';
$tr{'reports fw donut sub'} = 'Répartition par verdict';
$tr{'reports fw unit packets'} = 'paquets';
$tr{'reports fw sec topips'} = 'IP bloquées';
$tr{'reports fw bars sub'} = 'Adresses source les plus rejetées';
$tr{'reports fw sec attacks'} = 'Analyse des schémas d&#39;attaque';
$tr{'reports fw sec topports'} = 'ports les plus attaqués';
$tr{'reports th port'} = 'Port';
$tr{'reports fw th attempts'} = 'Tentatives';
$tr{'reports th service'} = 'Service';
$tr{'reports fw attempts word'} = 'tentatives';
$tr{'reports fw lvl crit'} = 'Niveau critique';
$tr{'reports fw lvl high'} = 'Niveau élevé';
$tr{'reports fw lvl med'} = 'Niveau moyen';
$tr{'reports fw ssh1 desc'} = 'attaques automatisées de devinette de mots de passe contre le service SSH.';
$tr{'reports fw ssh2 name'} = 'Attaque SSH';
$tr{'reports fw ssh2 desc'} = 'plusieurs tentatives de connexion SSH ; surveiller une escalade en force brute.';
$tr{'reports fw rdp1 name'} = 'Attaque RDP';
$tr{'reports fw rdp1 desc'} = 'Remote Desktop Protocol ; vecteur courant de rançongiciels et de vol d&#39;identifiants.';
$tr{'reports fw rdp2 name'} = 'Sondage RDP';
$tr{'reports fw rdp2 desc'} = 'découverte de systèmes Windows exposés.';
$tr{'reports fw telnet name'} = 'Botnet Telnet/IoT';
$tr{'reports fw telnet desc'} = 'activité de botnet IoT recherchant routeurs/caméras avec identifiants par défaut.';
$tr{'reports fw db name'} = 'Attaque de bases de données';
$tr{'reports fw db desc'} = 'attaques directes sur des services de bases de données.';
$tr{'reports fw web name'} = 'Analyse de services web';
$tr{'reports fw web desc'} = 'sondage d&#39;applications web, de panneaux d&#39;administration et de vulnérabilités connues.';
$tr{'reports fw vnc name'} = 'Attaque VNC';
$tr{'reports fw vnc desc'} = 'tentatives d&#39;accès distant via VNC.';
$tr{'reports fw smb name'} = 'Attaque SMB/NetBIOS';
$tr{'reports fw smb desc'} = 'risque élevé de propagation de rançongiciel (style WannaCry).';
$tr{'reports fw backdoor name'} = 'Activité de porte dérobée/cheval de Troie';
$tr{'reports fw backdoor desc'} = 'ports de portes dérobées connus détectés (NetBus, BackOrifice, Sub7).';
$tr{'reports fw noattack title'} = 'Aucun schéma d&#39;attaque pertinent';
$tr{'reports fw noattack desc'} = 'Les seuils de détection n&#39;ont pas été dépassés sur la période analysée.';
$tr{'reports fw foot desc'} = 'analyse du pare-feu';
$tr{'reports fw foot crit'} = 'Risque critique';
$tr{'reports fw foot med'} = 'Risque moyen';
$tr{'reports ids title'} = 'Rapport IDS/IPS';
$tr{'reports ids engine'} = 'Moteur';
$tr{'reports ids stat alerts'} = 'Alertes totales';
$tr{'reports ids stat alerts d'} = 'Toutes les détections';
$tr{'reports ids stat drops'} = 'Paquets rejetés';
$tr{'reports ids stat drops d'} = 'Bloqués par l&#39;IPS';
$tr{'reports ids prio crit'} = 'Critiques';
$tr{'reports ids prio crit d'} = 'Priorité 1-3 (risque élevé)';
$tr{'reports ids prio med'} = 'Moyennes';
$tr{'reports ids prio med d'} = 'Priorité 4-6 (risque moyen)';
$tr{'reports ids prio low'} = 'Faibles';
$tr{'reports ids prio low d'} = 'Priorité 7-9 (risque faible)';
$tr{'reports ids donut title'} = 'Alertes par priorité';
$tr{'reports ids donut sub'} = 'Gravité des détections';
$tr{'reports ids unit alerts'} = 'alertes';
$tr{'reports ids sec sources'} = 'sources d&#39;attaque';
$tr{'reports ids geo suffix'} = '(géolocalisés)';
$tr{'reports ids bars sub'} = 'IP source avec le plus d&#39;alertes';
$tr{'reports ids sec rules'} = 'règles les plus déclenchées';
$tr{'reports ids sec cats'} = 'catégories d&#39;attaque';
$tr{'reports ids th srcip'} = 'IP source';
$tr{'reports ids th alerts'} = 'Alertes';
$tr{'reports ids th location'} = 'Emplacement';
$tr{'reports ids th ruleid'} = 'ID règle';
$tr{'reports ids th desc'} = 'Description';
$tr{'reports ids th triggers'} = 'Déclenchements';
$tr{'reports ids th priority'} = 'Priorité';
$tr{'reports ids th category'} = 'Catégorie';
$tr{'reports th total'} = 'Total';
$tr{'reports ids th attacks'} = 'Attaques';
$tr{'reports ids geo unknown'} = 'Inconnu';
$tr{'reports ids geo private'} = 'Privée RFC1918';
$tr{'reports ids geo noloc'} = 'Non localisé';
$tr{'reports ids empty'} = 'Aucune alerte IDS/IPS pour la période';
$tr{'reports url title'} = 'Rapport du filtre d&#39;URL';
$tr{'reports url stat total'} = 'Total bloqué';
$tr{'reports url stat total d'} = 'URL bloquées';
$tr{'reports url stat ips'} = 'IP uniques';
$tr{'reports url stat ips d'} = 'Clients distincts';
$tr{'reports url stat malware'} = 'Logiciels malveillants';
$tr{'reports url stat malware d'} = 'Contenu malveillant';
$tr{'reports url stat phishing'} = 'Hameçonnage';
$tr{'reports url stat phishing d'} = 'Tentatives d&#39;hameçonnage';
$tr{'reports url stat crypto'} = 'Cryptojacking';
$tr{'reports url stat crypto d'} = 'Scripts de minage';
$tr{'reports url stat tracking'} = 'Pistage';
$tr{'reports url stat tracking d'} = 'Traqueurs';
$tr{'reports url donut title'} = 'Catégories bloquées';
$tr{'reports url donut sub'} = 'Répartition par catégorie (TOP 6)';
$tr{'reports url unit blocks'} = 'blocages';
$tr{'reports url sec topdomains'} = 'domaines bloqués';
$tr{'reports url bars sub'} = 'Domaines les plus bloqués';
$tr{'reports url sec hourly'} = 'Répartition horaire';
$tr{'reports url hourly title'} = 'Tranches horaires les plus bloquées';
$tr{'reports url rate label'} = 'Taux moyen de la période';
$tr{'reports url rate min'} = 'blocages/min';
$tr{'reports url rate hour'} = 'blocages/heure';
$tr{'reports url rate day'} = 'blocages/jour';
$tr{'reports url sec topips'} = 'IP les plus bloquées';
$tr{'reports url sec methods'} = 'Méthodes HTTP';
$tr{'reports url th method'} = 'Méthode';
$tr{'reports url sec security'} = 'Résumé de sécurité';
$tr{'reports url hack title'} = 'Tentatives de piratage bloquées';
$tr{'reports url hack desc'} = 'Accès aux ressources de piratage/exploits filtrés par le proxy.';
$tr{'reports url adult title'} = 'Contenu pour adultes bloqué';
$tr{'reports url adult desc'} = 'Demandes de contenu pour adultes refusées.';
$tr{'reports url eff title'} = 'Efficacité de la sécurité';
$tr{'reports url eff desc'} = 'Pourcentage de blocages correspondant à des menaces (cryptojacking + malware + hameçonnage) sur le total.';
$tr{'reports url foot module'} = 'Filtre d&#39;URL (SquidGuard)';
$tr{'reports url foot files'} = 'fichiers traités';
$tr{'reports heatmap title'} = 'Activité par heure et jour';
$tr{'reports heatmap caption'} = 'Chaque case correspond à une heure d&#39;un jour donné ; plus c&#39;est foncé, plus il y a d&#39;activité. Utile pour repérer les tranches horaires les plus actives.';
# <<< reports auto-i18n <<<
