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
    subprocess.run([flutter,'create','--empty','--no-pub','--project-name','eatme','--org','com.filippocinotti',
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
    ET.SubElement(intent,'data',{'{'+android+'}scheme':'com.filippocinotti.eatme','{'+android+'}host':'login-callback'})
    ET.SubElement(node,'uses-permission',{'{'+android+'}name':'android.permission.CAMERA'})
    ET.SubElement(node,'uses-feature',{'{'+android+'}name':'android.hardware.camera','{'+android+'}required':'false'})
    ET.SubElement(node,'uses-permission',{'{'+android+'}name':'android.permission.POST_NOTIFICATIONS'})
    ET.SubElement(node,'uses-permission',{'{'+android+'}name':'android.permission.RECEIVE_BOOT_COMPLETED'})
    receiver = ET.SubElement(application,'receiver',{'{'+android+'}name':'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver','{'+android+'}exported':'false'})
    receiver = ET.SubElement(application,'receiver',{'{'+android+'}name':'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver','{'+android+'}exported':'false'})
    boot = ET.SubElement(receiver,'intent-filter')
    for action in ['android.intent.action.BOOT_COMPLETED','android.intent.action.MY_PACKAGE_REPLACED']:
        ET.SubElement(boot,'action',{'{'+android+'}name':action})
    tree.write(manifest,encoding='unicode')
    gradle = mobile/'android/app/build.gradle.kts'
    source = gradle.read_text().replace('targetSdk = flutter.targetSdkVersion', 'targetSdk = 36')
    source = source.replace('signingConfig = signingConfigs.getByName("debug")', '// Release signing is configured through CI environment variables.')
    source = source.replace('    compileOptions {', '    compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
    source += '\ndependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }\n'
    source = source.replace('    buildTypes {', """    signingConfigs {
        create("release") {
            val keystore = System.getenv("ANDROID_KEYSTORE_PATH")
            if (keystore != null) {
                storeFile = file(keystore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }
    buildTypes {""")
    source = source.replace('// Release signing is configured through CI environment variables.', 'signingConfig = signingConfigs.getByName("release")')
    gradle.write_text(source)
    debug=mobile/'android/app/src/debug/AndroidManifest.xml'
    debug.parent.mkdir(parents=True,exist_ok=True)
    debug.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:usesCleartextTraffic="true"/></manifest>')

if 'ios' in created:
    path=mobile/'ios/Runner/Info.plist'
    info=plistlib.loads(path.read_bytes())
    info['CFBundleDisplayName']='EatMe'
    info['CFBundleURLTypes']=[{'CFBundleURLSchemes':['com.filippocinotti.eatme']}]
    info['NSCameraUsageDescription']='Scan product barcodes and photograph food you choose to add.'
    info['NSPhotoLibraryUsageDescription']='Select food or receipt images for a reviewable import.'
    info['ITSAppUsesNonExemptEncryption']=False
    info['NSAppTransportSecurity']={'NSAllowsLocalNetworking':True}
    path.write_bytes(plistlib.dumps(info))
    privacy = mobile/'ios/Runner/PrivacyInfo.xcprivacy'
    privacy.write_bytes(plistlib.dumps({'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[]}))
    entitlements=mobile/'ios/Runner/Runner.entitlements'
    entitlements.write_bytes(plistlib.dumps({'keychain-access-groups':['$(AppIdentifierPrefix)$(CFBundleIdentifier)']}))
    project=mobile/'ios/Runner.xcodeproj/project.pbxproj'
    source=project.read_text()
    source=source.replace('PRODUCT_BUNDLE_IDENTIFIER = com.filippocinotti.eatme;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.filippocinotti.eatme;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
    project.write_text(source)

from native_assets import generate
generate(mobile)

subprocess.run([flutter,'pub','get'],cwd=mobile,check=True)
print('Native runners ready. Review generated files and commit pubspec.lock after verification.')
