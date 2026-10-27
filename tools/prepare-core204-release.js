// Prepare local release artifacts only. Does not commit, push, or deploy.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const cp = require('child_process');
const root = path.resolve(__dirname, '..');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const catalog = path.join(root, 'repo/x86_64/packages.db');
const rows = fs.readFileSync(catalog, 'utf8').trim().split('\n');
const output = path.join(root, 'work/core204/release');
fs.mkdirSync(output, {recursive:true});
const versions = [];
const sums = [];
const walk = dir => fs.readdirSync(dir, {withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name)).flatMap(e => {
  if (e.name === '.DS_Store' || e.name.startsWith('._') || e.name === 'MANIFEST.sha256') return [];
  const p = path.join(dir,e.name);
  return e.isDirectory() ? walk(p) : e.isFile() ? [p] : [];
});
const nextRows = rows.map(line => {
  if (line.startsWith('#')) return line;
  const fields = line.split('|');
  const [name,old] = fields;
  const parts = old.split('.').map(Number); parts[2]++;
  const version = parts.join('.');
  const source = path.join(root,'src',name);
  fs.writeFileSync(path.join(source,'VERSION'),version+'\n');
  for (const entry of fs.readdirSync(source).filter(n=>/^README.*\.md$/i.test(n))) {
    const p=path.join(source,entry); let doc=fs.readFileSync(p,'utf8');
    if (name === 'captive-enhanced') doc=doc.replaceAll('**'+old+'**','**'+version+'**').replaceAll('Core Update 203','Core Update 204').replaceAll('Core 203','Core 204');
    fs.writeFileSync(p,doc);
  }
  fs.writeFileSync(path.join(source,'MANIFEST.sha256'),walk(source).map(p=>hash(p)+'  '+path.relative(source,p)).join('\n')+'\n');
  const file = `${name}-${version}-x86_64.tar.gz`;
  cp.execFileSync('tar',['--no-xattrs','--exclude=.DS_Store','--exclude=._*','-czf',path.join(output,file),'-C',path.join(root,'src'),name],{env:{...process.env,COPYFILE_DISABLE:'1'}});
  fields[1]=version; fields[2]=file; fields[3]=hash(path.join(output,file));
  fields[5]=fields[5].replaceAll('203','204'); fields[6]=fields[6].replaceAll('203','204');
  sums.push(fields[3]+'  '+file); versions.push([name,old,version]);
  return fields.join('|');
});
fs.writeFileSync(path.join(output,'packages.db'),nextRows.join('\n')+'\n');
fs.writeFileSync(path.join(output,'SHA256SUMS.txt'),sums.join('\n')+'\n');
for (const file of ['README.md','README.US.md','index.html']) {
  const p=path.join(root,file); let text=fs.readFileSync(p,'utf8');
  text=text.replaceAll('Core Update 203','Core Update 204').replaceAll('Core_Update-203','Core_Update-204').replaceAll('Core 203','Core 204');
  for (const [name,old,version] of versions) {
    text=text.replaceAll('`'+name+'` | '+old,'`'+name+'` | '+version);
    text=text.replaceAll('<code>'+name+'</code></td><td>'+old,'<code>'+name+'</code></td><td>'+version);
  }
  for (const [old,version] of [['1.19.29','1.19.33'],['1.13.14','1.14.4'],['0.107.78','0.107.79'],['2.1.3','2.1.7'],['1.102.2','1.104.2'],['1.7.10','1.8.3']]) text=text.replaceAll(old,version);
  text=text.replaceAll('安装时从官方版本下载','软件包内置').replaceAll('安装时从官方稳定版下载','软件包内置');
  text=text.replaceAll('Downloaded from the official release during installation','Bundled').replaceAll('Downloaded from the official stable release during installation','Bundled');
  fs.writeFileSync(p,text);
}
console.log(versions.map(v=>v.join(' ')).join('\n'));
