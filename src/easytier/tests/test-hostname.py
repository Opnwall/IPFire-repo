import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

path = Path(__file__).resolve().parents[1] / 'src/usr/local/sbin/easytierctrl'
loader = importlib.machinery.SourceFileLoader('et_hostname_test', str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
et = importlib.util.module_from_spec(spec)
loader.exec_module(et)

class HostnameTests(unittest.TestCase):
    def data(self, **changes):
        return dict(et.DEFAULT, network_name='test', network_secret='test-secret', **changes)

    def test_serialization(self):
        for name in ('ipfire-office', 'node1', 'office.example.test', 'A' * 63):
            data = dict(self.data(), hostname=name)
            self.assertEqual(et.validate(data, et.DEFAULT)['hostname'], name)
            self.assertIn('hostname = "' + name + '"', et.config(data))

    def test_blank_defaults(self):
        self.assertEqual(et.validate(dict(self.data(), hostname=' '), et.DEFAULT)['hostname'], 'ipfire-easytier')

    def test_legacy_preserves_name(self):
        data = self.data()
        del data['hostname']
        self.assertEqual(et.validate(data, dict(et.DEFAULT, hostname='custom-node'))['hostname'], 'custom-node')

    def test_invalid(self):
        for name in ('-host', 'host-', 'bad name', 'a..b', 'a' * 64, 'a\n[flags]', 'a"', None):
            with self.subTest(name=name), self.assertRaises(ValueError):
                et.validate(dict(self.data(), hostname=name), et.DEFAULT)

    def test_dynamic_wan(self):
        values = {'/var/ipfire/ethernet/settings': 'RED_DEV=red0\nRED_ADDRESS=192.0.2.8\n',
                  '/var/ipfire/red/iface': 'ppp0\n', '/var/ipfire/red/local-ipaddress': '198.51.100.8\n'}
        def path(name):
            return Mock(exists=Mock(return_value=name in values), read_text=Mock(return_value=values.get(name, '')))
        with patch.object(et, 'Path', side_effect=path):
            self.assertEqual(et.wan_endpoint(), ('ppp0', '198.51.100.8'))

    def test_dynamic_wan_fallback(self):
        def path(name):
            return Mock(exists=Mock(return_value=False), read_text=Mock(return_value='RED_DEV=wan0\nRED_ADDRESS=192.0.2.9\n'))
        with patch.object(et, 'Path', side_effect=path):
            self.assertEqual(et.wan_endpoint(), ('wan0', '192.0.2.9'))

if __name__ == '__main__':
    unittest.main()
