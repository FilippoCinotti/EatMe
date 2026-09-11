"""Generate missing native runners with the installed stable Flutter SDK.

Never overwrites the supplied Dart source, pubspec or existing native runners.
Run from any directory: python scripts/bootstrap_mobile.py
"""
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

root=Path(__file__).resolve().parents[1]
mobile=root/'apps/mobile'
flutter=shutil.which('flutter')
if not flutter:
    raise SystemExit('Install Flutter stable and add flutter to PATH, then run this command again.')
with tempfile.TemporaryDirectory(prefix='eatme-native-') as directory:
    generated=Path(directory)/'native'
    subprocess.run([flutter,'create','--empty','--no-pub','--project-name','eatme','--org','dev.eatme',
                    '--platforms','android,ios',str(generated)],check=True)
    created=[]
    for platform in ['android','ios']:
        if not (mobile/platform).exists():
            shutil.copytree(generated/platform,mobile/platform)
            created.append(platform)
    if not (mobile/'.metadata').exists():
        shutil.copy2(generated/'.metadata',mobile/'.metadata')

if 'android' in created:
    android='http://schemas.android.com/apk/res/android'
    ET.register_namespace('android',android)
    manifest=mobile/'android/app/src/main/AndroidManifest.xml'
    tree=ET.parse(manifest)
    node=tree.getroot()
    if not any(p.get('{'+android+'}name')=='android.permission.INTERNET' for p in node.findall('uses-permission')):
        ET.SubElement(node,'uses-permission',{'{'+android+'}name':'android.permission.INTERNET'})
    application=node.find('application')
    application.set('{'+android+'}label','EatMe')
    application.set('{'+android+'}allowBackup','false')
    application.set('{'+android+'}fullBackupContent','false')
    activity=application.find('activity')
    intent=ET.SubElement(activity,'intent-filter')
    ET.SubElement(intent,'action',{'{'+android+'}name':'android.intent.action.VIEW'})
    for category in ['DEFAULT','BROWSABLE']:
        ET.SubElement(intent,'category',{'{'+android+'}name':'android.intent.category.'+category})
    ET.SubElement(intent,'data',{'{'+android+'}scheme':'dev.eatme.app','{'+android+'}host':'login-callback'})
    tree.write(manifest,encoding='unicode')
    debug=mobile/'android/app/src/debug/AndroidManifest.xml'
    debug.parent.mkdir(parents=True,exist_ok=True)
    debug.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:usesCleartextTraffic="true"/></manifest>')

if 'ios' in created:
    path=mobile/'ios/Runner/Info.plist'
    info=plistlib.loads(path.read_bytes())
    info['CFBundleDisplayName']='EatMe'
    info['CFBundleURLTypes']=[{'CFBundleURLSchemes':['dev.eatme.app']}]
    info['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
    path.write_bytes(plistlib.dumps(info))
    entitlements=mobile/'ios/Runner/Runner.entitlements'
    entitlements.write_bytes(plistlib.dumps({'keychain-access-groups':['$(AppIdentifierPrefix)$(CFBundleIdentifier)']}))
    project=mobile/'ios/Runner.xcodeproj/project.pbxproj'
    source=project.read_text()
    source=source.replace('PRODUCT_BUNDLE_IDENTIFIER = dev.eatme.eatme;',
        'PRODUCT_BUNDLE_IDENTIFIER = dev.eatme.eatme;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
    project.write_text(source)

subprocess.run([flutter,'pub','get'],cwd=mobile,check=True)
print('Native runners ready. Review generated files and commit pubspec.lock after verification.')
