#!/usr/bin/env python3
"""Build reproducible community archives and update the package catalog hashes."""
from pathlib import Path
import gzip, hashlib, tarfile
root = Path(__file__).resolve().parents[1]
catalog = root / 'repo/x86_64/packages.db'
lines = catalog.read_text().splitlines()
output = root / 'repo/x86_64/All'
output.mkdir(parents=True, exist_ok=True)
keep = set()
checksums = []
def clean(path):
    return not any(x == '.DS_Store' or x.startswith('._') or x == '__pycache__' for x in path.parts) and path.suffix != '.pyc'
def metadata(info):
    info.uid = info.gid = 0
    info.uname = info.gname = 'root'
    info.mtime = 0
    info.mode &= 0o1777
    return info
for i, line in enumerate(lines):
    if not line or line.startswith('#'): continue
    fields = line.split('|')
    package = root / 'src' / fields[0]
    version = (package / 'VERSION').read_text().strip()
    # Check every declared source checksum before packaging.
    for entry in (package / 'MANIFEST.sha256').read_text().splitlines():
        digest, relative = entry.split('  ', 1)
        assert hashlib.sha256((package / relative).read_bytes()).hexdigest() == digest, relative
    filename = f'{fields[0]}-{version}-x86_64.tar.gz'
    with (output / filename).open('wb') as stream:
        with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as archive:
                for path in sorted(package.rglob('*')):
                    if clean(path.relative_to(package)):
                        archive.add(path, arcname=str(Path(fields[0]) / path.relative_to(package)), recursive=False, filter=metadata)
    with tarfile.open(output / filename) as verify:
        assert f'{fields[0]}/install.sh' in verify.getnames(), 'ipfrepo requires a named package root'
        assert verify.extractfile(f'{fields[0]}/VERSION').read().decode().strip() == version
    digest = hashlib.sha256((output / filename).read_bytes()).hexdigest()
    fields[1:4] = [version, filename, digest]
    fields[5] = fields[5].replace('Core 204','Core 206')
    fields[6] = fields[6].replace('Core 204','Core 206')
    if fields[0] == 'lang':
        fields[5] = 'Core 206 gettext 简繁汉化、远程下载与重定向缓存修复'
        fields[6] = 'Core 206 gettext Chinese localization with remote downloads and redirect cache bypass'
    lines[i] = '|'.join(fields)
    keep.add(filename)
    checksums.append(f'{digest}  {filename}\n')
    print(fields[0], version, digest, flush=True)
for path in output.glob('*.tar.gz'):
    if path.name not in keep: path.unlink()
catalog.write_text('\n'.join(lines) + '\n')
(root / 'SHA256SUMS.txt').write_text(''.join(sorted(checksums)))
