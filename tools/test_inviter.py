# -*- coding: utf-8 -*-
"""Bouton « INVITER » du hub : defier un ami via SocialService:PromptGameInvite.

Verifie dans Hub.client.lua : le service est obtenu, un bouton « INVITER » existe sur l'accueil,
son clic verifie d'abord CanSendGameInviteAsync puis appelle PromptGameInvite(player), le tout sous
pcall (ces appels echouent dans Studio et ne doivent pas casser le hub), et un refus est dit au joueur.
"""
import re, sys, pathlib
H = (pathlib.Path(__file__).resolve().parent.parent / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []
if 'game:GetService("SocialService")' not in H:
    e.append("hub : SocialService non obtenu")
if not re.search(r'local boutonInviter = bouton\(accueil, "INVITER"', H):
    e.append("hub : pas de bouton INVITER sur l'accueil")
c = re.search(r"boutonInviter\.MouseButton1Click:Connect\(function\(\).*?\nend\)", H, re.S)
if not c:
    e.append("hub : le bouton INVITER ne fait rien")
else:
    b = c.group(0)
    i, j = b.find("CanSendGameInviteAsync(player)"), b.find("PromptGameInvite(player)")
    if i < 0 or j < 0 or i > j:
        e.append("hub : il faut CanSendGameInviteAsync(player) puis PromptGameInvite(player)")
    if b.count("pcall(") < 2:
        e.append("hub : les appels SocialService ne sont pas proteges par pcall")
    if "message.Text" not in b:
        e.append("hub : un refus d'invitation n'est pas dit au joueur")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
