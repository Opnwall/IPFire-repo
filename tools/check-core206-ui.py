import pathlib,subprocess,json,os,re,shutil
base=pathlib.Path('/root/core206-release-validation')
src=base/'src';report=[]
# All stateful UI checks use private copies of state, never live configurations.
for plugin,state in [('captive-enhanced','captive'),('reports','reports'),('backup','firewall_backup')]:
 target=base/'state'/state
 if pathlib.Path('/var/ipfire',state).is_dir():shutil.copytree('/var/ipfire/'+state,target,dirs_exist_ok=True)
 else:target.mkdir(parents=True,exist_ok=True)
 for f in (src/plugin/'src').rglob('*'):
  if f.is_file() and f.suffix in ('.cgi','.pl') and 'community-lang' not in f.parts:
   s=f.read_text();s=re.sub('/var/ipfire/'+state+r'(?=[/\'"\s])',str(target),s);f.write_text(s)
state=base/'state/captive'
for name in ('coupons','clients','settings','.state.lock','terms.txt','terms2.txt'):(state/name).touch(exist_ok=True)
if not (state/'.csrf-key').exists():(state/'.csrf-key').write_text('0123456789abcdef'*4)
loader='''BEGIN { *CORE::GLOBAL::require = sub {my $file=shift; my $candidate=$ENV{STAGE_ROOT}."/".$file; $file=$candidate if $file =~ m{^/} && -f $candidate; CORE::require($file);}; }
require '/var/ipfire/general-functions.pl';
my $read=\\&General::readhash;
{ no warnings 'redefine'; *General::readhash=sub {my $ret=$read->(@_); $_[1]->{'LANGUAGE'}=$ENV{TEST_LANGUAGE} if $_[0] eq '/var/ipfire/main/settings';return $ret;}; }
require '/var/ipfire/lang.pl';
'''
# Syntax check each CGI and library using Core 206's installed Perl modules.
for p in src.rglob('*'):
 if not p.is_file():continue
 if p.suffix=='.cgi' or (p.suffix=='.pl' and 'community-lang' not in p.parts and 'addon-lang' not in p.parts and p.name not in ('en.pl','zh.pl','tw.pl')):
  r=subprocess.run(['perl','-c',str(p)],capture_output=True,timeout=20);report.append({'kind':'syntax','file':str(p.relative_to(src)),'ok':r.returncode==0,'stderr':r.stderr.decode(errors='replace')[-700:]})
for plugin in sorted(p for p in src.iterdir() if p.is_dir()):
 resource=plugin/'src/var/ipfire/community-lang'/ (plugin.name+'.pl')
 if not resource.exists():continue
 static=set()
 for f in (plugin/'src').rglob('*'):
  if f.is_file() and f.suffix in ('.cgi','.menu'):
   static.update(re.findall(r'''\$Lang::tr\{\s*['"]([^'"]+)['"]\s*\}''',f.read_text()))
 for language in ('en','zh_CN','zh_TW'):
  env=dict(os.environ,STAGE_ROOT=str(plugin/'src'),TEST_LANGUAGE=language,DOCUMENT_ROOT='/srv/web/ipfire/html',REQUEST_METHOD='GET',CONTENT_LENGTH='0',QUERY_STRING='',REMOTE_USER='admin',REMOTE_ADDR='127.0.0.1',HTTPS='on',SERVER_PROTOCOL='HTTP/1.1',SERVER_NAME='ipfire.test',SERVER_PORT='444')
  code=loader+"require '/var/ipfire/community-lang/"+plugin.name+".pl'; use JSON::PP; my @missing=grep {!defined($Lang::tr{$_}) || !length($Lang::tr{$_})} @ARGV; print JSON::PP->new->encode(\\@missing);"
  r=subprocess.run(['perl','-e',code,*sorted(static)],env=env,capture_output=True,timeout=20)
  try:missing=json.loads(r.stdout)
  except Exception:missing=['LOADER ERROR']
  report.append({'kind':'translations','plugin':plugin.name,'language':language,'keys':len(static),'ok':r.returncode==0 and not missing,'missing':missing,'stderr':r.stderr.decode(errors='replace')[-700:]})
  pages=list((plugin/'src/srv/web/ipfire/cgi-bin').glob('*.cgi'))
  if plugin.name=='captive-enhanced':pages=[plugin/'src/srv/web/ipfire/cgi-bin/captive.cgi']
  for p in pages:
   env['SCRIPT_NAME']='/cgi-bin/'+p.name
   try:r=subprocess.run(['perl','-e',loader+'do $ARGV[0]; die $@ if $@;',str(p)],env=env,capture_output=True,timeout=20,cwd='/srv/web/ipfire/cgi-bin')
   except subprocess.TimeoutExpired:
    report.append({'kind':'page','plugin':plugin.name,'language':language,'ok':False,'error':'timeout'});continue
   html=r.stdout.decode(errors='replace');out=base/'html';out.mkdir(exist_ok=True);(out/(plugin.name+'-'+language+'.html')).write_text(html)
   report.append({'kind':'page','plugin':plugin.name,'language':language,'ok':r.returncode==0 and '<html' in html and 'Status: 500' not in html and 'Software error' not in html,'bytes':len(r.stdout),'exit':r.returncode,'stderr':r.stderr.decode(errors='replace')[-1000:]})
(base/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('CHECKS',len(report),'FAILURES',sum(not x['ok'] for x in report))
for x in report:
 if not x['ok']:print(json.dumps(x,ensure_ascii=False))
