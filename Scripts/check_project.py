"""Cross-platform structure checks. This is not an Xcode build or type check."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []
checks = []


def check(name, condition):
    checks.append({'name': name, 'passed': bool(condition)})
    if not condition: errors.append(name)


project = (ROOT/'Cuike.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
files = list(ROOT.glob('App/**/*.swift')) + list(ROOT.glob('Core/*.swift')) + list(ROOT.glob('Shared/*.swift')) + list(ROOT.glob('Widgets/*.swift')) + list(ROOT.glob('Tests/**/*.swift'))
check('Every Swift source is referenced by the Xcode project', all(str(p.relative_to(ROOT)).replace('\\','/') in project for p in files))
check('Four targets are present', project.count('"isa" = "PBXNativeTarget"') == 4)
for path in re.findall(r'"path" = "([^"]+)";', project):
    if '/' in path: check('File exists: '+path, (ROOT/path).exists())
for path in list(ROOT.rglob('*.plist')) + list(ROOT.rglob('*.entitlements')) + list(ROOT.rglob('*.xcprivacy')):
    with path.open('rb') as f: plistlib.load(f)
    check('Valid plist: '+str(path.relative_to(ROOT)), True)
app = plistlib.loads((ROOT/'App/Info.plist').read_bytes())
widget = plistlib.loads((ROOT/'Widgets/Info.plist').read_bytes())
check('Camera purpose is present', bool(app.get('NSCameraUsageDescription')))
check('Live Activities enabled', app.get('NSSupportsLiveActivities') is True)
check('App and widget use same group variable', app['CuikeAppGroup'] == widget['CuikeAppGroup'])
check('URL scheme is cuike', app['CFBundleURLTypes'][0]['CFBundleURLSchemes'] == ['cuike'])
check('Widget extension point', widget['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension')
for manifest in (ROOT/'Resources/Assets.xcassets').rglob('Contents.json'):
    data = json.loads(manifest.read_text(encoding='utf-8'))
    for item in data.get('images', []):
        if 'filename' in item: check('Asset exists: '+item['filename'], (manifest.parent/item['filename']).exists())
scheme = ET.parse(ROOT/'Cuike.xcodeproj/xcshareddata/xcschemes/Cuike.xcscheme')
check('Both test targets in shared scheme', len(scheme.findall('.//TestableReference')) == 2)
swift = '\n'.join(p.read_text(encoding='utf-8') for p in files)
check('No remote application dependencies', 'URLSession' not in swift and 'WKWebView' not in swift)
check('No fixed OCR response', 'VNRecognizeTextRequest' in swift and 'VNImageRequestHandler' in swift)
check('Brew has no pause action', 'func pause(' not in swift)
check('Atomic shared snapshot writes', '.write(to: url, options: .atomic)' in swift)
report = {'scope': 'Static structure only; not native compilation or execution', 'checks': checks,
          'swift_files': len(files), 'swift_lines_including_tests_and_blanks': sum(len(p.read_text(encoding='utf-8').splitlines()) for p in files),
          'errors': errors}
out = ROOT/'Verification'
out.mkdir(exist_ok=True)
(out/'project-checks.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'{len(checks)} structure checks; {len(errors)} failures; {len(files)} Swift sources.')
if errors: raise SystemExit('\n'.join(errors))
