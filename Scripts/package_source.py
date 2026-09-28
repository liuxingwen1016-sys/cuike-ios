"""Package source and verification notes; does not build an app or include credentials."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
excluded = {'.git', '.build', 'build', 'DerivedData', 'xcuserdata', '__pycache__'}
files = sorted(p for p in root.rglob('*') if p.is_file() and not excluded.intersection(p.relative_to(root).parts)
               and p.name not in {'Local.xcconfig', 'source-manifest.json'})
manifest = {'version': '1.0-source', 'date': '2026-09-28', 'native_build_verified': False,
            'files': {str(p.relative_to(root)).replace('\\','/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
manifest_path = root/'Verification/source-manifest.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
archive = root.parent/'萃刻-iOS原生工程-v1.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for path in files + [manifest_path]:
        package.write(path, 'Cuike-iOS/'+str(path.relative_to(root)).replace('\\','/'))
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    print(f'{archive.name}: {len(package.namelist())} files, {archive.stat().st_size:,} bytes; CRC verified.')
