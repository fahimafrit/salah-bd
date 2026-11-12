import re, glob
m = "android/app/src/main/AndroidManifest.xml"
s = open(m, encoding="utf-8").read()
perms = ''.join(f'<uses-permission android:name="android.permission.{p}"/>\n' for p in
  ["POST_NOTIFICATIONS","SCHEDULE_EXACT_ALARM","USE_EXACT_ALARM","RECEIVE_BOOT_COMPLETED","VIBRATE","WAKE_LOCK"])
s = s.replace("<application", perms + "<application", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="নামাজের সময়"', s, 1)
recv = '''<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
<intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/>
<action android:name="android.intent.action.MY_PACKAGE_REPLACED"/></intent-filter></receiver>
'''
s = s.replace("</application>", recv + "</application>", 1)
open(m, "w", encoding="utf-8").write(s)
g = glob.glob("android/app/build.gradle*")[0]
t = open(g).read()
if g.endswith(".kts"):
    t = t.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    t += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
else:
    t = t.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    t += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
open(g, "w").write(t)
