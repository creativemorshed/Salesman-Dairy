#!/usr/bin/env python3
"""flutter create এর পর Android ফাইলগুলো প্যাচ করে (README-র ক, খ, গ ধাপ)।
ব্যবহার: python3 tool/patch_android.py  (retailer_manager ফোল্ডার থেকে)"""
import glob, os, re, sys

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

def write(p, s):
    with open(p, "w", encoding="utf-8") as f: f.write(s)

# ---- ক. AndroidManifest ----
man = "android/app/src/main/AndroidManifest.xml"
s = read(man)
if "POST_NOTIFICATIONS" not in s:
    perms = """    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
"""
    s = s.replace("<application", perms + "    <application", 1)
    receivers = """        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
    s = s.replace("</application>", receivers + "    </application>", 1)
    # tel / whatsapp লিংকের জন্য <queries> (flutter create এর queries ব্লকে যোগ)
    extra = """        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
"""
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>\n" + extra, 1)
    else:
        s = s.replace("<application", "    <queries>\n" + extra + "    </queries>\n    <application", 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="রিটেলার ম্যানেজার"', s, count=1)
    write(man, s)
    print("manifest patched")

# ---- খ. desugaring ----
for gp in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if not os.path.exists(gp): continue
    g = read(gp)
    if "coreLibraryDesugaring" in g:
        break
    if gp.endswith(".kts"):
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n'
    else:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
    if "oreLibraryDesugaring" not in g.split("compileOptions", 1)[1][:200]:
        sys.exit("compileOptions পাওয়া যায়নি: " + gp)
    write(gp, g)
    print("gradle patched:", gp)
    break
else:
    sys.exit("app build.gradle পাওয়া যায়নি")

# ---- গ. MainActivity -> FlutterFragmentActivity (local_auth) ----
for ma in glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True):
    m = read(ma)
    pkg = re.search(r"^package\s+\S+", m, re.M).group(0)
    write(ma, pkg + "\n\nimport io.flutter.embedding.android.FlutterFragmentActivity\n\nclass MainActivity : FlutterFragmentActivity()\n")
    print("MainActivity patched:", ma)

# ---- ঘ. পুরনো প্লাগইনগুলো (যেমন file_picker) নতুন compileSdk-তে কম্পাইল করানো ----
for rp, kts in (("android/build.gradle.kts", True), ("android/build.gradle", False)):
    if not os.path.exists(rp): continue
    r = read(rp)
    if "compileSdkVersion(36)" in r or "compileSdkVersion 36" in r: break
    if kts:
        hack = """subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder { "compileSdkVersion"(36) }
    }
    // lint-vital এর টুল ক্র্যাশ করে (NoSuchMethodError) — রিলিজ বিল্ডে এটা বন্ধ রাখি
    tasks.configureEach {
        if (name.startsWith("lintVital")) enabled = false
    }
}

"""
    else:
        hack = """subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) { p.android { compileSdkVersion 36 } }
    }
    tasks.configureEach { t ->
        if (t.name.startsWith('lintVital')) t.enabled = false
    }
}

"""
    # import লাইনগুলো (থাকলে) ফাইলের শুরুতে থাকতে হবে, তাই সেগুলোর পরে বসাই
    lines = r.split("\n"); i = 0
    while i < len(lines) and (lines[i].startswith("import ") or not lines[i].strip()): i += 1
    write(rp, "\n".join(lines[:i]) + ("\n" if i else "") + hack + "\n".join(lines[i:]))
    print("root gradle patched:", rp)
    break
