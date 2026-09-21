#!/bin/sh
# Joue UN duel de paliers (20 parties) dans le bureau cache et range le journal dans .duels/.
# Usage : sh tools/duel_paliers.sh <a:b> <fichier_sortie>
PAIR="$1"; OUT="$2"; N="${3:-20}"   # 3e argument : nombre de parties (defaut 20)
cd /d/BrainRotRoyale || exit 1
# on ne tue QUE notre propre Studio (une autre session peut en avoir un)
if [ -f /tmp/pid_cur ]; then
  powershell -NoProfile -Command "Stop-Process -Id $(cat /tmp/pid_cur) -Force -ErrorAction SilentlyContinue" 2>/dev/null
fi
python -c "import time;time.sleep(12)"
rm -f BrainRotRoyale.conv729.rbxlx.lock
python build.py --autotest --partie --sim="1-1:$N" --robot="$PAIR" >/dev/null 2>&1 || { echo "BUILD ECHOUE $PAIR"; exit 1; }
cp BrainRotRoyale.autotest.rbxlx BrainRotRoyale.conv729.rbxlx
# LE PLUGIN EST INDISPENSABLE : sans lui Studio ouvre la place mais ne lance JAMAIS la partie.
# Oubli constate le 2026-09-21 : 10 minutes d'attente pour 0 partie, Studio ouvert et inerte.
cp tools/BRR_AutoRun.lua "$LOCALAPPDATA/Roblox/Plugins/BRR_AutoRun_conv729.lua" || { echo "PLUGIN NON INSTALLE"; exit 1; }
# le duel doit VRAIMENT etre dans la place, sinon la mesure ne vaut rien
grep -q "BRR_ROBOT</string><string name=\"Value\">$PAIR" BrainRotRoyale.conv729.rbxlx || { echo "PLACE SANS DUEL $PAIR"; exit 1; }
R=$(powershell -NoProfile -File ../AutoWinOS/scripts/hdesk-lancer.ps1 -Id chat-conv-729 -Executable "C:\Program Files (x86)\Roblox\Versions\version-55808de4b1914919\RobloxStudioBeta.exe" -Arguments "\"D:\BrainRotRoyale\BrainRotRoyale.conv729.rbxlx\"" -Travail "duel $PAIR" -Conversation conv-729 -AttenteSecondes 60)
echo "$R" | grep -oP '"pid":\d+' | grep -oP '\d+' > /tmp/pid_cur
for i in $(seq 1 90); do
  python -c "import time;time.sleep(20)"
  L=$(powershell -NoProfile -Command "ls \$env:LOCALAPPDATA\Roblox\logs\*.log | sort LastWriteTime -Desc | select -f 1 -ExpandProperty FullName" | tr -d '\r')
  FAIT=$(grep -c "\[SIM\] 1-1 partie=" "$L" 2>/dev/null)
  if [ "$FAIT" -ge "$N" ] 2>/dev/null; then cp "$L" "$OUT"; echo "OK $PAIR : $FAIT parties"; exit 0; fi
done
echo "INCOMPLET $PAIR : $FAIT/$N parties"
exit 2
