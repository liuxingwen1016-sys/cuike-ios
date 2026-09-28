"""Package source and verification notes; does not build an app or include credentials."""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=root.parent/'萃刻-iOS原生工程-v1.zip')
args = parser.parse_args()
excluded = {'.git', '.build', 'build', 'DerivedData', 'xcuserdata', '__pycache__'}
files = sorted(p for p in root.rglob('*') if p.is_file() and not excluded.intersection(p.relative_to(root).parts)
               and p.name not in {'Local.xcconfig', 'source-manifest.json'}
               and p.suffix.lower() not in {'.p12', '.p8', '.mobileprovision', '.ipa', '.zip'})
evidence_path = root/'Verification/cloud-build.json'
evidence = json.loads(evidence_path.read_text(encoding='utf-8')) if evidence_path.exists() else {}
manifest = {'version': '1.1-actions-source', 'date': '2026-09-28',
            'native_build_verified': evidence.get('conclusion') == 'success',
            'cloud_build_evidence': evidence,
            'files': {str(p.relative_to(root)).replace('\\','/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
manifest_path = root/'Verification/source-manifest.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
archive = args.output.resolve()
archive.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for path in files + [manifest_path]:
        package.write(path, 'Cuike-iOS/'+str(path.relative_to(root)).replace('\\','/'))
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    print(f'{archive.name}: {len(package.namelist())} files, {archive.stat().st_size:,} bytes; CRC verified.')
