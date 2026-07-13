#!/usr/bin/env bash
# ARXOS Weapons menu generator. Builds the FULL arsenal menu from tools.db:
#   Weapons -> {Offensive, Bug Bounty, Defensive, Research} -> subcategory -> every tool.
# Each tool entry calls `arxos-run-tool <name>`: run it if installed, offer to install it if
# not. Each subcategory also gets an "Install all" entry (arx install weaponsCat <sub>), and
# the top level gets "Full Arsenal". Menu state is static (all tools); installed-vs-missing is
# decided at click time, so no refresh hook is needed. Idempotent; driven entirely by tools.db.
set -e
DB=/usr/share/arxos/tools.db
ICON="/usr/share/icons/ArxOS/arxos-menu.png"; [ -f "$ICON" ] || ICON="applications-system"
APP=/usr/share/applications; DIRD=/usr/share/desktop-directories
MENUFILE=/etc/xdg/menus/xfce-applications.menu
[ -f "$DB" ] || { echo "no tools.db - skipping weapons menu"; exit 0; }
sudo mkdir -p "$APP" "$DIRD"
sudo rm -f /etc/xdg/menus/xfce-applications-merged/arxos-weapons.menu 2>/dev/null || true

STAGE=$(mktemp -d /tmp/arxos-menu.XXXXXX)
mkdir -p "$STAGE/apps" "$STAGE/dirs"

python3 - "$DB" "$STAGE" "$ICON" <<'PY'
import sys, os, re
db, stage, icon = sys.argv[1], sys.argv[2], sys.argv[3]
apps, dirs = os.path.join(stage,"apps"), os.path.join(stage,"dirs")

MENU  = {"O":"Offensive","B":"Bug Bounty","D":"Defensive","R":"Research"}
MSLUG = {"O":"offensive","B":"bugbounty","D":"defensive","R":"research"}
NAME = {"af":"Anti-Forensics","ai":"AI / ML","audit":"Auditing","auto":"Automation",
  "bin":"Binary / Exploit Dev","blue":"Blue Team","bt":"Bluetooth","c2":"Command & Control",
  "crypt":"Cryptography","db":"Databases","dbg":"Debugging","dec":"Decompilation",
  "dis":"Disassembly","dos":"Denial of Service","drone":"Drones","eva":"Evasion",
  "exp":"Exploitation","for":"Forensics","fp":"Fingerprinting","fuzz":"Fuzzing",
  "fw":"Firmware","honey":"Honeypots","hw":"Hardware","ids":"IDS / IPS","key":"Keyloggers",
  "mal":"Malware","misc":"Miscellaneous","mob":"Mobile","net":"Networking","nfc":"NFC / RFID",
  "prox":"Proxies","pwd":"Passwords","recon":"Reconnaissance","rev":"Reverse Engineering",
  "scan":"Scanning","sdr":"SDR / Radio","se":"Social Engineering","sniff":"Sniffing",
  "spoof":"Spoofing","steg":"Steganography","threat":"Threat Intel","tun":"Tunneling",
  "voip":"VoIP","web":"Web / API","win":"Windows / AD","wire":"Wireless","wl":"Wordlists"}

def esc(s): return s.replace("\n"," ").strip()
def fn(s):  return re.sub(r"[^A-Za-z0-9._+-]","_",s)
def xesc(s): return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")   # for .menu XML <Name>s

subs = {}   # (M,sub) -> [(name,desc), ...]
row = re.compile(r"^([A-Za-z0-9._+-]+)\|([OBDR])\|([A-Za-z0-9]+)\|")
for line in open(db, encoding="utf-8", errors="replace"):
    if not row.match(line): continue
    p = line.rstrip("\n").split("|")
    if len(p) < 5: continue
    name, M, sub, desc = p[0], p[1], p[2].lower(), esc(p[4])
    subs.setdefault((M, sub), []).append((name, desc))

def wdesktop(path, name, comment, exec_, cats, icon_=icon):
    with open(path, "w", encoding="utf-8") as f:
        f.write("[Desktop Entry]\nVersion=1.0\nType=Application\n")
        f.write("Name=%s\nComment=%s\nExec=%s\nIcon=%s\nTerminal=false\nCategories=%s;\n"
                % (name, comment, exec_, icon_, cats))

def wdir(path, name, comment):
    with open(path, "w", encoding="utf-8") as f:
        f.write("[Desktop Entry]\nVersion=1.0\nType=Directory\nName=%s\nComment=%s\nIcon=%s\n"
                % (name, comment, icon))

# top-level Full Arsenal + Weapons directory
wdesktop(os.path.join(apps,"arxos-arsenal-00-full.desktop"), "Full Arsenal",
         "Install the entire ARXOS arsenal (large)",
         'xfce4-terminal --title="ARXOS Arsenal" -x bash -lc "arx install weaponsCat full; echo; read -rp \'press enter to close...\'"',
         "X-ARXOS-Weapons")
wdir(os.path.join(dirs,"arxos-weapons.directory"), "Weapons", "ARXOS Arsenal")

nmenus = set()
ntools = 0
for M in "OBDR":
    wdir(os.path.join(dirs,"arxos-cat-%s.directory"%MSLUG[M]), MENU[M], MENU[M]+" arsenal")
    for (mm, sub), tools in sorted(subs.items()):
        if mm != M: continue
        label = NAME.get(sub, sub.upper())
        cat = "X-ARXOS-%s-%s" % (M, sub)
        nmenus.add((M, sub, label))
        wdir(os.path.join(dirs,"arxos-sub-%s-%s.directory"%(MSLUG[M],sub)), label, "%s tools"%label)
        # "Install all" entry for the subcategory
        wdesktop(os.path.join(apps,"arxos-catall-%s-%s.desktop"%(MSLUG[M],sub)),
                 "＋ Install all %s"%label, "Install every %s tool"%label,
                 'xfce4-terminal --title="ARXOS Arsenal · %s" -x bash -lc "arx install weaponsCat %s; echo; read -rp \'press enter to close...\'"'%(label,sub),
                 cat)
        for name, desc in sorted(set(tools)):
            wdesktop(os.path.join(apps,"arxos-tool-%s.desktop"%fn(name)),
                     name, desc or (label+" tool"),
                     "arxos-run-tool %s"%name, cat)
            ntools += 1

# the nested menu XML block
buf = ['    <!-- ARXOS-WEAPONS-START -->',
       '    <Menu>',
       '        <Name>Weapons</Name>',
       '        <Directory>arxos-weapons.directory</Directory>',
       '        <Include><Category>X-ARXOS-Weapons</Category></Include>']
for M in "OBDR":
    buf.append('        <Menu><Name>%s</Name><Directory>arxos-cat-%s.directory</Directory>' % (xesc(MENU[M]), MSLUG[M]))
    for (mm, sub, label) in sorted(nmenus):
        if mm != M: continue
        buf.append('            <Menu><Name>%s</Name><Directory>arxos-sub-%s-%s.directory</Directory><Include><Category>X-ARXOS-%s-%s</Category></Include></Menu>'
                   % (xesc(label), MSLUG[M], sub, M, sub))
    buf.append('        </Menu>')
buf += ['    </Menu>', '    <!-- ARXOS-WEAPONS-END -->']
open(os.path.join(stage,"menu.block"), "w").write("\n".join(buf) + "\n")
print("staged %d tool entries across %d subcategories" % (ntools, len(nmenus)))
PY

# clean previous arsenal artifacts, then install the freshly staged ones in one shot
sudo rm -f "$APP"/arxos-arsenal-*.desktop "$APP"/arxos-tool-*.desktop "$APP"/arxos-catall-*.desktop \
           "$DIRD"/arxos-cat-*.directory "$DIRD"/arxos-sub-*.directory
sudo cp -f "$STAGE"/apps/*.desktop "$APP"/ 2>/dev/null
sudo cp -f "$STAGE"/dirs/*.directory "$DIRD"/ 2>/dev/null
sudo chmod 644 "$APP"/arxos-tool-*.desktop "$APP"/arxos-catall-*.desktop "$APP"/arxos-arsenal-*.desktop 2>/dev/null || true

# insert the nested Weapons menu into xfce-applications.menu (between markers; replaces any prior)
if [ -f "$MENUFILE" ]; then
  BLOCK=$(cat "$STAGE/menu.block")
  sudo python3 - "$MENUFILE" "$STAGE/menu.block" <<'PY'
import sys, re
f, bf = sys.argv[1], sys.argv[2]
s = open(f).read(); block = open(bf).read()
s = re.sub(r'[ \t]*<!-- ARXOS-WEAPONS-START -->.*?<!-- ARXOS-WEAPONS-END -->\n?', '', s, flags=re.S)
s = re.sub(r'[ \t]*<!-- ARXOS Weapons arsenal -->\s*<Menu>.*?</Menu>\n?', '', s, flags=re.S)
i = s.rfind('</Menu>')
s = s[:i] + block + s[i:]
open(f, 'w').write(s)
PY
  echo "inserted full Weapons menu into $MENUFILE"
fi

sudo update-desktop-database "$APP" 2>/dev/null || true
rm -rf "$STAGE"
echo "weapons menu rebuilt: every tool -> run if installed / install if missing"
