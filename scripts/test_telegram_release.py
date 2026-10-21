import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('telegram_release', Path(__file__).with_name('telegram_release.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseTests(unittest.TestCase):
    def release(self):
        return {'tag_name': 'v1.2.3', 'html_url': f'{module.BASE}/releases/tag/v1.2.3', 'draft': False, 'prerelease': False, 'body': '- Correção <script> & teste', 'assets': [{'name': 'TarginoLauncher-Recompilados-1.2.3-Setup.exe', 'browser_download_url': f'{module.BASE}/releases/download/v1.2.3/TarginoLauncher-Recompilados-1.2.3-Setup.exe'}]}

    def test_message_and_escape(self):
        message = module.build_message(self.release())
        self.assertIn('&lt;script&gt; &amp; teste', message)
        self.assertNotIn('<script>', message)
        self.assertIn('Baixar instalador completo', message)
        self.assertLess(len(message), 4096)

    def test_draft_preview_and_wrong_source(self):
        for change in ({'draft': True}, {'prerelease': True}, {'html_url': 'https://example.com'}, {'tag_name': 'v1.2.3-preview.1'}, {'assets': []}):
            release = self.release()
            release.update(change)
            with self.assertRaises(ValueError):
                module.build_message(release)

    def test_optional_bootstrap(self):
        release = self.release()
        release['assets'].append({'name': 'TarginoLauncher-Bootstrap.exe', 'browser_download_url': f'{module.BASE}/releases/download/v1.2.3/TarginoLauncher-Bootstrap.exe'})
        self.assertIn('Instalador leve', module.build_message(release))

    def test_missing_token_never_sends(self):
        with self.assertRaises(ValueError):
            module.send_message('', 'teste')


if __name__ == '__main__':
    unittest.main()
