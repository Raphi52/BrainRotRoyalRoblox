#!/bin/sh
# Mesure l'effet d'UN seul defaut du debutant : le debutant devient une copie du normal, sauf la
# caracteristique testee, puis affronte le normal sur 60 parties. Robot.lua est TOUJOURS restaure.
cd /d/BrainRotRoyale || exit 1
mkdir -p .duels
REF=.robot_reference.lua
cp src/shared/Robot.lua "$REF"   # reference prise AU DEPART : le script est autonome
NORMAL='reflexe = 2.4, erreur = 0.22, gardeElixir = 7, anticipe = true,  contre = true,  economise = true,  ecart = 3,   lecture = 0'
for VAR in temoin erreur anticipe contre economise ecart garde; do
  case $VAR in
    temoin)    L="$NORMAL" ;;
    erreur)    L='reflexe = 2.4, erreur = 0.40, gardeElixir = 7, anticipe = true,  contre = true,  economise = true,  ecart = 3,   lecture = 0' ;;
    anticipe)  L='reflexe = 2.4, erreur = 0.22, gardeElixir = 7, anticipe = false, contre = true,  economise = true,  ecart = 3,   lecture = 0' ;;
    contre)    L='reflexe = 2.4, erreur = 0.22, gardeElixir = 7, anticipe = true,  contre = false, economise = true,  ecart = 3,   lecture = 0' ;;
    economise) L='reflexe = 2.4, erreur = 0.22, gardeElixir = 7, anticipe = true,  contre = true,  economise = false, ecart = 3,   lecture = 0' ;;
    ecart)     L='reflexe = 2.4, erreur = 0.22, gardeElixir = 7, anticipe = true,  contre = true,  economise = true,  ecart = 6,   lecture = 0' ;;
    garde)     L='reflexe = 2.4, erreur = 0.22, gardeElixir = 6, anticipe = true,  contre = true,  economise = true,  ecart = 3,   lecture = 0' ;;
  esac
  cp "$REF" src/shared/Robot.lua
  python - "$L" <<'PY'
import io,re,sys
p='src/shared/Robot.lua'; s=io.open(p,encoding='utf-8').read()
s2=re.sub(r'(nom = "debutant", )reflexe = [^}]*?lecture = [\d.]+', lambda m: m.group(1)+sys.argv[1], s, count=1)
assert s2!=s, "ligne du debutant introuvable"
io.open(p,'w',encoding='utf-8').write(s2)
PY
  echo "=== $VAR : $(grep -o 'nom = "debutant".*' src/shared/Robot.lua)"
  sh tools/duel_paliers.sh debutant:normal ".duels/sonde_$VAR.log" 60
done
cp "$REF" src/shared/Robot.lua
rm -f "$REF"
echo "Robot.lua restaure"
