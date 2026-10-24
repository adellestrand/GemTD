"""Host-independent packaging checks; no engine or network needed."""
import json
from pathlib import Path
import tempfile
import unittest

from prepare_web_beta import FILES, ROOT, prepare


class PublicBetaChecks(unittest.TestCase):
    def setUp(self):
        parent = ROOT/'output/web-beta-tests'
        parent.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=parent)
        assert Path(self.temp.name).resolve().is_relative_to(parent.resolve())
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name)/'web'
        self.destination = Path(self.temp.name)/'public'
        self.source.mkdir()
        for name in FILES:
            (self.source/name).write_bytes(b'fixture')
        (self.source/'index.html').write_text('<html><head><title>Old</title></head></html>', encoding='utf8')

    def test_campaign_and_explicit_profiles(self):
        original = (self.source/'index.html').read_bytes()
        metadata = prepare(self.source, self.destination, 'a'*40)
        text = (self.destination/'index.html').read_text(encoding='utf8')
        self.assertIn("if (!betaURL.searchParams.has('profile'))", text)
        self.assertIn("betaURL.searchParams.set('profile', 'campaign')", text)
        self.assertEqual(original, (self.source/'index.html').read_bytes())
        self.assertEqual(metadata['content_version'], 10)
        self.assertEqual(metadata['commit'], 'a'*40)
        self.assertEqual(len(metadata['files']), len(FILES))
        self.assertEqual(json.loads((self.destination/'build.json').read_text())['profile'], 'campaign')

    def test_source_extras_not_published(self):
        (self.source/'private.txt').write_text('not part of a web export')
        prepare(self.source, self.destination, 'b'*40)
        self.assertFalse((self.destination/'private.txt').exists())

    def test_incomplete_export_rejected(self):
        (self.source/'index.pck').unlink()
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            prepare(self.source, self.destination, 'c'*40)

    def test_source_and_stale_public_files_protected(self):
        with self.assertRaisesRegex(ValueError, 'separate'):
            prepare(self.source, self.source, 'd'*40)
        self.destination.mkdir()
        (self.destination/'unrelated.txt').write_text('preserve this')
        with self.assertRaisesRegex(ValueError, 'unexpected'):
            prepare(self.source, self.destination, 'd'*40)


if __name__ == '__main__':
    unittest.main()
