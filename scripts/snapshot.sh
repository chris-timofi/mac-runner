#!/bin/bash
# snapshot.sh before|after — records the state of every place code likes to hide.
# Same ground Wazuh's file-integrity and rootcheck modules cover on macOS.
W="$1"
mkdir -p out

# --- general state ---
ls -laR "$HOME"                                   > "out/home.$W.txt"       2>/dev/null
ls -la /Applications /usr/local/bin /opt/homebrew/bin \
                                                  > "out/bins.$W.txt"       2>/dev/null
launchctl list                                    > "out/launchd.$W.txt"    2>/dev/null
crontab -l                                        > "out/cron.$W.txt"       2>/dev/null

# --- the hiding spots ---

# 1. startup items: the number one persistence trick on macOS
for d in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons \
         /System/Library/LaunchAgents /System/Library/LaunchDaemons; do
  echo "### $d"
  ls -la "$d" 2>/dev/null
  for f in "$d"/*.plist; do [ -f "$f" ] && { echo "--- $f"; plutil -p "$f" 2>/dev/null; }; done
done                                              > "out/startup.$W.txt"    2>/dev/null

# 2. login items — apps that open when the user logs in
osascript -e 'tell application "System Events" to get the name of every login item' \
                                                  > "out/loginitems.$W.txt" 2>/dev/null

# 3. hosts file — used to hijack or block domains
cat /etc/hosts                                    > "out/hosts.$W.txt"      2>/dev/null

# 4. sudoers — silent privilege escalation
sudo cat /etc/sudoers 2>/dev/null                 > "out/sudoers.$W.txt"
sudo ls -la /etc/sudoers.d 2>/dev/null           >> "out/sudoers.$W.txt"

# 5. privacy database — camera, mic, screen recording, full disk access grants
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "select service,client,auth_value from access" 2>/dev/null  > "out/tcc.$W.txt"
sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service,client,auth_value from access" 2>/dev/null >> "out/tcc.$W.txt"

# 6. configuration profiles — MDM-style control of the machine
sudo profiles -P                                  > "out/profiles.$W.txt"   2>/dev/null

# 7. shell startup files — the quietest persistence of all
for f in "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.bashrc" \
         "$HOME/.bash_profile" "$HOME/.profile" /etc/zshrc /etc/profile; do
  echo "### $f"; cat "$f" 2>/dev/null
done                                              > "out/shellrc.$W.txt"    2>/dev/null

# 8. keychain contents (names only, never values)
security dump-keychain 2>/dev/null | grep -E '"(svce|acct)"' \
                                                  > "out/keychain.$W.txt"   2>/dev/null

# 9. ssh keys and authorized_keys
ls -la "$HOME/.ssh" 2>/dev/null                   > "out/ssh.$W.txt"
cat "$HOME/.ssh/authorized_keys" 2>/dev/null     >> "out/ssh.$W.txt"

# 10. firewall + network settings
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps \
                                                  > "out/firewall.$W.txt"   2>/dev/null
scutil --dns                                     >> "out/firewall.$W.txt"   2>/dev/null

# 11. installed packages
pkgutil --pkgs                                    > "out/pkgs.$W.txt"       2>/dev/null

echo "snapshot '$W' done"
