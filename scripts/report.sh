#!/bin/bash
# report.sh — turns the before/after snapshots and the live recordings
# into one plain-English CHANGES.txt.
cd out || exit 0
R=CHANGES.txt
: > $R

section () {   # section "TITLE" file-stem
  echo ""                                  >> $R
  echo "=== $1 ==="                        >> $R
  if [ -f "$2.before.txt" ] || [ -f "$2.after.txt" ]; then
    if diff "$2.before.txt" "$2.after.txt" >> $R 2>&1; then
      echo "(no change)"                   >> $R
    fi
  else
    echo "(not captured)"                  >> $R
  fi
}

echo "WHAT THE SCRIPT CHANGED ON THIS MAC"  >> $R

section "FILES IN THE HOME FOLDER"          home
section "PROGRAMS AND APPS"                 bins
section "BACKGROUND SERVICES (launchd)"     launchd
section "STARTUP ITEMS (the #1 persistence trick)" startup
section "LOGIN ITEMS"                       loginitems
section "SCHEDULED JOBS (cron)"             cron
section "HOSTS FILE (domain hijacking)"     hosts
section "SUDOERS (silent root access)"      sudoers
section "PRIVACY GRANTS (camera/mic/screen/disk)" tcc
section "CONFIGURATION PROFILES (MDM control)"    profiles
section "SHELL STARTUP FILES"               shellrc
section "KEYCHAIN ENTRIES (names only)"     keychain
section "SSH KEYS"                          ssh
section "FIREWALL AND DNS"                  firewall
section "INSTALLED PACKAGES"                pkgs

echo ""                                     >> $R
echo "=== EVERY DOMAIN AND IP CONTACTED ===" >> $R
sudo tcpdump -r traffic.pcap -n 2>/dev/null | awk '{print $3, $5}' | sort -u >> $R || true

echo ""                                     >> $R
echo "=== EVERY URL FETCHED (decrypted) ===" >> $R
mitmdump --quiet -nr https.flows 2>/dev/null | head -500 >> $R || true

echo ""                                     >> $R
echo "=== EVERY PROGRAM LAUNCHED ==="       >> $R
grep -vE 'ps -Ao|/bin/sleep|fs_usage|tcpdump|mitmdump|cloudflared' processes.live.log 2>/dev/null \
  | awk '{$1="";$2="";$3="";print}' | sort -u | head -500 >> $R || true

echo ""                                     >> $R
echo "=== FILES WRITTEN (live trace) ==="   >> $R
grep -iE 'WrData|open|unlink|rename|mkdir' files.live.log 2>/dev/null \
  | awk '{print $NF}' | sort -u | head -1000 >> $R || true

cat $R
