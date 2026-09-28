"""Regenerate the checked-in, dependency-free Xcode project using Python 3."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def uid(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()


def obj(key, isa, **values):
    identity = uid(key)
    objects[identity] = dict(isa=isa, **values)
    return identity


def serialize(value, indent=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t' * (indent + 1) + f'{serialize(k)} = {serialize(v, indent+1)};\n' for k, v in value.items()) + '\t' * indent + '}'
    if isinstance(value, list):
        return '(' + ', '.join(serialize(v, indent + 1) for v in value) + (',' if value else '') + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


def file_ref(path, kind=None):
    suffix = Path(path).suffix
    kind = kind or {'.swift': 'sourcecode.swift', '.xcassets': 'folder.assetcatalog', '.png': 'image.png',
                    '.xcprivacy': 'text.xml', '.xcconfig': 'text.xcconfig', '.plist': 'text.plist.xml',
                    '.entitlements': 'text.plist.entitlements'}.get(suffix, 'text')
    return obj('file:' + path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')


def phase(target, isa, paths):
    builds = [obj(f'build:{target}:{p}', 'PBXBuildFile', fileRef=refs[p]) for p in paths]
    return obj(f'phase:{target}:{isa}', isa, buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0)


def configurations(key, settings):
    configs = []
    for name in ['Debug', 'Release']:
        options = dict(settings)
        if key == 'Project':
            options.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if name == 'Debug' else '-O',
                           DEBUG_INFORMATION_FORMAT='dwarf' if name == 'Debug' else 'dwarf-with-dsym',
                           ENABLE_TESTABILITY='YES' if name == 'Debug' else 'NO',
                           SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if name == 'Debug' else '')
        configs.append(obj(f'config:{key}:{name}', 'XCBuildConfiguration', name=name,
                           baseConfigurationReference=refs['Config/Base.xcconfig'], buildSettings=options))
    return obj('configs:' + key, 'XCConfigurationList', buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Release')


def plist(path, content):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(plistlib.dumps(content, sort_keys=False))


plist('App/Info.plist', {
    'CFBundleDisplayName': '萃刻', 'CFBundleName': '$(PRODUCT_NAME)', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '$(MARKETING_VERSION)', 'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)',
    'LSRequiresIPhoneOS': True, 'UILaunchScreen': {},
    'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False},
    'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'NSCameraUsageDescription': '用于扫描咖啡豆袋上的文字，识别后由你核对并保存豆档案。',
    'NSSupportsLiveActivities': True, 'CuikeAppGroup': '$(CUIKE_APP_GROUP)',
    'CFBundleURLTypes': [{'CFBundleURLName': 'com.cuike.routing', 'CFBundleURLSchemes': ['cuike']}]})
plist('Widgets/Info.plist', {
    'CFBundleDisplayName': '萃刻小组件', 'CFBundleName': '$(PRODUCT_NAME)', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundlePackageType': 'XPC!',
    'CFBundleShortVersionString': '$(MARKETING_VERSION)', 'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)',
    'CuikeAppGroup': '$(CUIKE_APP_GROUP)', 'NSExtension': {'NSExtensionPointIdentifier': 'com.apple.widgetkit-extension'}})
for path in ['App/Cuike.entitlements', 'Widgets/CuikeWidgets.entitlements']:
    plist(path, {'com.apple.security.application-groups': ['$(CUIKE_APP_GROUP)']})
plist('Resources/PrivacyInfo.xcprivacy', {
    'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [], 'NSPrivacyCollectedDataTypes': [],
    'NSPrivacyAccessedAPITypes': [
        {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults', 'NSPrivacyAccessedAPITypeReasons': ['CA92.1']},
        {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategorySystemBootTime', 'NSPrivacyAccessedAPITypeReasons': ['35F9.1']}]
})

app_sources = sorted(str(p.relative_to(ROOT)).replace('\\', '/') for folder in ['App', 'Core', 'Shared'] for p in (ROOT/folder).rglob('*.swift'))
widget_sources = ['Widgets/CuikeWidgets.swift', 'Shared/BrewActivityAttributes.swift', 'Shared/SharedSnapshot.swift']
unit_sources = sorted(str(p.relative_to(ROOT)).replace('\\', '/') for folder in ['Tests/CoreTests', 'Tests/AppTests'] for p in (ROOT/folder).glob('*.swift'))
ui_sources = ['Tests/UITests/CuikeUITests.swift']
resources = ['Resources/Assets.xcassets', 'Resources/PrivacyInfo.xcprivacy']
other = ['Config/Base.xcconfig', 'App/Info.plist', 'Widgets/Info.plist', 'App/Cuike.entitlements', 'Widgets/CuikeWidgets.entitlements']
refs = {p: file_ref(p) for p in sorted(set(app_sources + widget_sources + unit_sources + ui_sources + resources + other + ['Resources/sample-bean.png']))}
project_id = uid('project')
products = {}
for name, ext, kind in [('Cuike', 'app', 'wrapper.application'), ('CuikeWidgets', 'appex', 'wrapper.app-extension'),
                         ('CuikeTests', 'xctest', 'wrapper.cfbundle'), ('CuikeUITests', 'xctest', 'wrapper.cfbundle')]:
    products[name] = obj('product:' + name, 'PBXFileReference', explicitFileType=kind, includeInIndex=0, path=name+'.'+ext, sourceTree='BUILT_PRODUCTS_DIR')
product_group = obj('products', 'PBXGroup', children=list(products.values()), name='Products', sourceTree='<group>')
groups = []
for folder in ['App', 'Core', 'Shared', 'Widgets', 'Resources', 'Tests', 'Config']:
    groups.append(obj('group:'+folder, 'PBXGroup', children=[v for p, v in refs.items() if p.startswith(folder+'/')], name=folder, sourceTree='<group>'))
main_group = obj('main', 'PBXGroup', children=groups + [product_group], sourceTree='<group>')


def dependency(name):
    proxy = obj('proxy:'+name, 'PBXContainerItemProxy', containerPortal=project_id, proxyType=1,
                remoteGlobalIDString=uid('target:'+name), remoteInfo=name)
    return obj('dependency:'+name, 'PBXTargetDependency', target=uid('target:'+name), targetProxy=proxy)


targets = []
for name, sources, res, kind in [
    ('Cuike', app_sources, resources + ['Resources/sample-bean.png'], 'application'),
    ('CuikeWidgets', widget_sources, resources, 'app-extension'),
    ('CuikeTests', unit_sources, [], 'bundle.unit-test'),
    ('CuikeUITests', ui_sources, [], 'bundle.ui-testing')]:
    phases = [phase(name, 'PBXSourcesBuildPhase', sources), phase(name, 'PBXFrameworksBuildPhase', []), phase(name, 'PBXResourcesBuildPhase', res)]
    dependencies = []
    settings = {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': '$(BUNDLE_PREFIX)' + ('' if name == 'Cuike' else '.' + name),
                'GENERATE_INFOPLIST_FILE': 'NO' if name in ['Cuike', 'CuikeWidgets'] else 'YES'}
    if name == 'Cuike':
        embed = obj('embed-widgets', 'PBXBuildFile', fileRef=products['CuikeWidgets'], settings={'ATTRIBUTES': ['RemoveHeadersOnCopy']})
        phases.append(obj('copy-widgets', 'PBXCopyFilesBuildPhase', buildActionMask=2147483647, dstPath='', dstSubfolderSpec=13,
                          files=[embed], name='Embed App Extensions', runOnlyForDeploymentPostprocessing=0))
        dependencies.append(dependency('CuikeWidgets'))
        settings.update(INFOPLIST_FILE='App/Info.plist', CODE_SIGN_ENTITLEMENTS='App/Cuike.entitlements',
                        ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks')
    elif name == 'CuikeWidgets':
        settings.update(INFOPLIST_FILE='Widgets/Info.plist', CODE_SIGN_ENTITLEMENTS='Widgets/CuikeWidgets.entitlements',
                        APPLICATION_EXTENSION_API_ONLY='YES', SKIP_INSTALL='YES',
                        LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks')
    else:
        dependencies.append(dependency('Cuike'))
        if name == 'CuikeTests': settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/Cuike.app/Cuike', BUNDLE_LOADER='$(TEST_HOST)')
        else: settings.update(TEST_TARGET_NAME='Cuike')
    targets.append(obj('target:'+name, 'PBXNativeTarget', name=name, productName=name, productReference=products[name],
                       productType='com.apple.product-type.'+kind, buildConfigurationList=configurations(name, settings),
                       buildPhases=phases, buildRules=[], dependencies=dependencies))
objects[project_id] = dict(isa='PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1600',
    'TargetAttributes': {uid('target:Cuike'): {'CreatedOnToolsVersion': '16.0'}, uid('target:CuikeWidgets'): {'CreatedOnToolsVersion': '16.0'}}},
    buildConfigurationList=configurations('Project', {'SWIFT_VERSION': '5.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
        'SDKROOT': 'iphoneos', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'}),
    compatibilityVersion='Xcode 14.0', developmentRegion='zh-Hans', hasScannedForEncodings=0,
    knownRegions=['zh-Hans', 'en', 'Base'], mainGroup=main_group, productRefGroup=product_group,
    projectDirPath='', projectRoot='', targets=targets)
project = ROOT/'Cuike.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n' + serialize({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project_id})+'\n', encoding='utf-8')
scheme_dir = project/'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)


def reference(name):
    suffix = 'app' if name == 'Cuike' else 'xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{suffix}" BlueprintName="{name}" ReferencedContainer="container:Cuike.xcodeproj"/>'


scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference('Cuike')}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
  <TestableReference skipped="NO">{reference('CuikeTests')}</TestableReference>
  <TestableReference skipped="NO">{reference('CuikeUITests')}</TestableReference>
 </Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('Cuike')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('Cuike')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(scheme_dir/'Cuike.xcscheme').write_text(scheme, encoding='utf-8')
print(f'Generated {project.name}: {len(app_sources)} app sources; {len(targets)} targets; {len(objects)} objects.')
