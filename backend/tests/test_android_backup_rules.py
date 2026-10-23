"""Secure-storage ciphertext must not be restored without its device key."""
from pathlib import Path
from xml.etree import ElementTree as ET


ANDROID = Path(__file__).resolve().parents[2] / 'frontend/android/app/src/main'
NS = '{http://schemas.android.com/apk/res/android}'
SECURE_FILES = {'FlutterSecureStorage.xml', 'FlutterSecureKeyStorage.xml'}


def test_secure_storage_is_excluded_from_legacy_and_modern_backup():
    app = ET.parse(ANDROID / 'AndroidManifest.xml').getroot().find('application')
    assert app.get(NS + 'fullBackupContent') == '@xml/backup_rules'
    assert app.get(NS + 'dataExtractionRules') == '@xml/data_extraction_rules'
    legacy = ET.parse(ANDROID / 'res/xml/backup_rules.xml').getroot()
    modern = ET.parse(ANDROID / 'res/xml/data_extraction_rules.xml').getroot()
    for section in (legacy, modern.find('cloud-backup'), modern.find('device-transfer')):
        assert section is not None
        excluded = {item.get('path') for item in section.findall('exclude') if item.get('domain') == 'sharedpref'}
        assert SECURE_FILES <= excluded
        assert section.find('include') is None, 'keep unrelated backup data enabled'
