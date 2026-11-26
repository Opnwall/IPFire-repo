#!/usr/bin/env python3
"""Exercise installer and manager in a disposable filesystem with mocked downloads."""
import os
import re
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RepositoryClientTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for directory in ('opt/pakfire/db/core', 'usr/local/bin', 'usr/bin', 'tmp', 'mock'):
            (self.root / directory).mkdir(parents=True)
        (self.root / 'opt/pakfire/db/core/mine').write_text('206\n')
        self.env = {**os.environ, 'PATH': str(self.root / 'mock') + ':' + os.environ['PATH'],
                    'TEST_ROOT': str(self.root), 'TEST_ARCH': 'x86_64'}
        self.env.pop('IPFREPO_BASE_URL', None)
        self.mock('uname', 'echo "$TEST_ARCH"')
        self.mock('id', 'echo 0')
        self.mock('curl', '''while [ "$#" -gt 0 ]; do
case "$1" in http://*|https://*) url="$1";; -o) shift; output="$1";; esac
shift
done
printf '%s\\n' "$url" >> "$TEST_ROOT/downloads"
case "$url" in
*/ipfrepo) cp "$TEST_ROOT/manager" "$output";;
*/packages.db) printf '# Opnwall IPFire package catalog v1\\n' > "$output";;
*) exit 9;;
esac''')
        for source, target in [('ipfrepo', 'manager'), ('install-repo.sh', 'installer')]:
            content = (ROOT / source).read_text()
            content = re.sub(r'/opt/|/usr/local/|/usr/bin/|/tmp/',
                             lambda match: str(self.root) + match[0], content)
            (self.root / target).write_text(content)

    def mock(self, name, content):
        p = self.root / 'mock' / name
        p.write_text('#!/bin/sh\nset -eu\n' + content + '\n')
        p.chmod(0o755)

    def run_script(self, script, *args, ok=True):
        result = subprocess.run(['sh', str(self.root / script), *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_default_install_and_persisted_custom_reinstall(self):
        self.run_script('installer')
        config = self.root / 'opt/ipfrepo/repository.url'
        self.assertEqual(config.read_text().strip(), 'https://opnwall.github.io/IPFire-repo')
        self.env['IPFREPO_BASE_URL'] = 'https://mirror.example/repo/'
        self.run_script('installer')
        self.assertEqual(config.read_text().strip(), 'https://mirror.example/repo')
        del self.env['IPFREPO_BASE_URL']
        self.run_script('manager', 'update')
        self.run_script('installer')
        self.assertTrue((self.root / 'downloads').read_text().splitlines()[-1].startswith('https://mirror.example/repo/'))

    def test_environment_override_does_not_rewrite_saved_configuration(self):
        self.run_script('installer')
        self.env['IPFREPO_BASE_URL'] = 'https://temporary.example/repo'
        self.run_script('manager', 'update')
        self.assertIn('temporary.example', (self.root / 'downloads').read_text().splitlines()[-1])
        self.assertNotIn('temporary.example', (self.root / 'opt/ipfrepo/repository.url').read_text())

    def test_unsupported_platform_rejected_before_download_or_mutation(self):
        core = self.root / 'opt/pakfire/db/core/mine'
        for arch, version in [('aarch64', '206'), ('x86_64', '204'), ('x86_64', '205'), ('x86_64', '207')]:
            self.env['TEST_ARCH'] = arch
            core.write_text(version + '\n')
            self.run_script('installer', ok=False)
            for command in ('update', 'list', 'info', 'install', 'remove', 'upgrade'):
                self.run_script('manager', command, 'example', ok=False)
        self.assertFalse((self.root / 'downloads').exists())
        self.assertFalse((self.root / 'opt/ipfrepo').exists())

    def test_missing_core_file_rejected(self):
        (self.root / 'opt/pakfire/db/core/mine').unlink()
        self.run_script('installer', ok=False)
        self.run_script('manager', 'update', ok=False)
        self.run_script('manager', '--help')

    def test_invalid_urls_rejected_and_configuration_is_not_executed(self):
        for url in ('file:///tmp/repo', 'https://example/repo?x=1', 'https://example/#fragment', 'https://bad host/'):
            self.env['IPFREPO_BASE_URL'] = url
            self.run_script('installer', ok=False)
            self.run_script('manager', 'update', ok=False)
        del self.env['IPFREPO_BASE_URL']
        config = self.root / 'opt/ipfrepo/repository.url'
        config.parent.mkdir()
        config.write_text('$(touch ' + str(self.root / 'executed') + ')\n')
        self.run_script('manager', 'update', ok=False)
        self.assertFalse((self.root / 'executed').exists())


if __name__ == '__main__':
    unittest.main()
