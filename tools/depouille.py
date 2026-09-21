# -*- coding: utf-8 -*-
"""DEPOUILLEMENT d'un journal de partie : sort les indicateurs et SIGNALE les anomalies.

Pourquoi cet outil existe. Cinq defauts reels du jeu ont ete trouves a la main, en lisant des
journaux de partie et en comparant des comptes :
  * `pose_refusee` x31 sur une partie -> le robot reproposait une case interdite (Emplacement) ;
  * `defense_voie1` 123 contre 10     -> il attaquait toujours le meme cote (Voie) ;
  * trois cartes de soutien a 0 pose  -> une regle de notation les rendait injouables (Reponse) ;
  * 5,8 entrees d'aura par unite      -> le bonus de soutien clignotait (Soutien, hysteresis) ;
  * 4 unites bloquees a z = -4        -> elles ramaient devant le pont (Traversee).
Chacun se voyait dans un simple COMPTE. Cet outil fait ces comptes automatiquement, avec des
seuils nommes, pour que le prochain defaut du meme genre se voie en une commande.

Il ne remplace pas la lecture : il dit ou regarder. Un indicateur VERT ne prouve pas que la partie
est saine, il prouve seulement que ces defauts-la ne sont pas revenus.

Usage :
    python tools/depouille.py                # le journal de partie le plus recent
    python tools/depouille.py <chemin.log>   # un journal precis
"""
import glob
import io
import os
import re
import sys
from collections import Counter

# Seuils, tous issus d'une mesure reelle citee ci-dessus.
SEUIL_DESEQUILIBRE_VOIE = 3.0   # au-dela, le robot devient previsible (mesure : 12,3)
SEUIL_ENTREES_AURA = 2.5        # entrees d'aura par unite posee (mesure du papillonnage : 5,8)


def journaux():
    dossier = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
    return sorted(glob.glob(os.path.join(dossier, "*.log")), key=os.path.getmtime, reverse=True)


def choisir_journal():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for f in journaux():
        try:
            d = io.open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if "[BOT]" in d and "action=" in d:
            return f
    return None


def parties_sim(texte):
    """Les parties d'une serie de simulation presentes dans le journal."""
    return re.findall(
        r"\[SIM\] \d+-\d+ partie=(\d+) gagnant=(\w+) couronnes_fort=(\d+) couronnes_faible=(\d+)",
        texte)


def main():
    chemin = choisir_journal()
    if not chemin or not os.path.exists(chemin):
        print("ROUGE : aucun journal de partie trouve")
        return 1
    d = io.open(chemin, encoding="utf-8", errors="ignore").read()
    print("journal : %s" % os.path.basename(chemin))

    anomalies = []

    def verdict(ok, titre, detail):
        print(("  OK      " if ok else "  ANOMALIE ") + titre + " : " + detail)
        if not ok:
            anomalies.append(titre)

    # 1. erreurs de script — rien ne doit jamais casser
    erreurs = len(re.findall(r"attempt to |Script error", d))
    verdict(erreurs == 0, "erreurs de script", "%d" % erreurs)

    # 2. poses refusees — le robot perd son tour sur une case interdite
    refus = Counter(re.findall(r"action=refus carte=(\w+)", d))
    verdict(sum(refus.values()) == 0, "poses refusees",
            "%d%s" % (sum(refus.values()),
                      (" (" + ", ".join("%s x%d" % (k, v) for k, v in refus.most_common(3)) + ")")
                      if refus else ""))

    # 3. unites bloquees — elles ne font plus rien du tout
    bloquees = re.findall(r"BLOQUE (.+?) (-?\d+) (-?\d+)", d)
    lieux = Counter("(%s, %s)" % (x, z) for _, x, z in bloquees)
    verdict(len(bloquees) == 0, "unites bloquees",
            "%d%s" % (len(bloquees),
                      (" au meme endroit " + lieux.most_common(1)[0][0]) if lieux else ""))

    # 3 bis. UN CAMP MUET invalide TOUT le reste. Defaut mesure le 2026-09-20 : une serie de
    # 20 parties donnait « camp 1 : 0 victoire sur 20, p = 0,00 » et 20 scores 3-0 — de quoi
    # croire a un desequilibre grave du jeu. En realite le camp 1 avait pose 3 cartes contre 721,
    # parce que le mode « bot contre bot » ne s'active que si AUCUN joueur n'est present, et
    # qu'en Studio un joueur local existe toujours. Ce controle passe AVANT les indicateurs
    # d'equilibre : sans lui, le banc accuse le jeu d'un defaut qui est le sien.
    par_camp = Counter(re.findall(r"\[BOT\] camp=(\d) version=\w+ action=", d))
    if sum(par_camp.values()) >= 20:
        c1, c2 = par_camp.get("1", 0), par_camp.get("2", 0)
        faible, fort = min(c1, c2), max(c1, c2)
        muet = faible == 0 or fort > faible * 10
        verdict(not muet, "les deux camps jouent",
                "camp 1 : %d decisions, camp 2 : %d%s"
                % (c1, c2, " — UN CAMP NE JOUE PAS, la serie ne mesure rien" if muet else ""))
        if muet:
            print("     (mode 'bot contre bot' absent ? il exige qu'AUCUN joueur ne soit present)")

    # 3 ter. DANS UN DUEL DE PALIERS, LES DEUX COTES DOIVENT ALTERNER.
    # Defaut mesure le 2026-09-21 : le profil du robot n'etait assigne qu'aux camps SANS joueur,
    # or en Studio un joueur local en occupe toujours un. Ce camp gardait donc le palier de la
    # premiere partie pendant que l'autre alternait : on mesurait la force du palier ET
    # l'avantage de cote dans le meme chiffre, sans pouvoir les separer.
    profils = re.findall(r"\[BOT\] camp=(\d) difficulte=(\w+)", d)
    if profils:
        vus = {}
        for camp, nom in profils:
            vus.setdefault(camp, set()).add(nom)
        distincts = {c: len(v) for c, v in vus.items()}
        if len(set(n for _, n in profils)) > 1:  # c'est bien un duel de paliers
            fige = [c for c, n in distincts.items() if n < 2]
            verdict(not fige, "alternance des cotes dans le duel",
                    "camp 1 : %s | camp 2 : %s%s"
                    % (sorted(vus.get("1", [])), sorted(vus.get("2", [])),
                       " — UN CAMP GARDE TOUJOURS LE MEME PALIER, la mesure melange palier et cote"
                       if fige else ""))

    # 4. equilibre des voies — un robot previsible n'est pas un adversaire
    v1 = len(re.findall(r"raison=defense_voie1", d))
    v2 = len(re.findall(r"raison=defense_voie2", d))
    if v1 + v2 >= 20:
        rapport = max(v1, v2) / max(1, min(v1, v2))
        verdict(rapport <= SEUIL_DESEQUILIBRE_VOIE, "equilibre des voies",
                "%d contre %d (rapport %.1f, seuil %.1f)" % (v1, v2, rapport, SEUIL_DESEQUILIBRE_VOIE))
    else:
        print("  (peu de defenses : %d, equilibre des voies non evalue)" % (v1 + v2))

    # 5. papillonnage des auras — le bonus clignote a la frontiere du rayon
    poses = Counter(re.findall(r"action=joue carte=(\w+)", d))
    # On ne compte QUE les vraies entrees dans une aura. Passer d'une aura a une autre
    # (x1,15 -> x1,30) est legitime : le compter faisait croire a un papillonnage inexistant.
    entrees = Counter()
    for nom in re.findall(r"\[SOUTIEN\] ENTRE (.+?) degats", d):
        entrees[nom.strip()] += 1
    pires = []
    for nom_complet, n in entrees.items():
        court = nom_complet.split()[0]
        p = sum(v for k, v in poses.items() if k.startswith(court))
        if p >= 5:
            pires.append((n / p, nom_complet, n, p))
    pires.sort(reverse=True)
    if pires:
        r, nom, n, p = pires[0]
        verdict(r <= SEUIL_ENTREES_AURA, "papillonnage des auras",
                "%s : %d entrees pour %d poses (%.1f par unite, seuil %.1f)"
                % (nom, n, p, r, SEUIL_ENTREES_AURA))
    else:
        print("  (aucune aura mesurable dans cette partie)")

    # 6. cartes jamais jouees alors qu'elles portent une regle du jeu
    regles = {}
    for fichier, cle in (("Soutien", "Soutien.PROFILS"), ("Charge", "Charge.PROFILS"),
                         ("Recul", "Recul.PROFILS"), ("Specialite", "Specialite.PROFILS"),
                         ("Assassin", "Assassin.PROFILS"), ("Descendance", "Descendance.PROFILS")):
        p = os.path.join(os.path.dirname(__file__), "..", "src", "shared", fichier + ".lua")
        if not os.path.exists(p):
            continue
        s = io.open(p, encoding="utf-8").read()
        m = re.search(cle + r"\s*=\s*\{(.*?)\n\}", s, re.S)
        if m:
            for ident in re.findall(r"^\s*(\w+)\s*=", m.group(1), re.M):
                regles.setdefault(ident, []).append(fichier)
    # On ne juge que les cartes REELLEMENT distribuees : le deck ne fait que 8 cartes par camp,
    # et le robot ne joue QUE les cartes gratuites. Une carte payante absente n'est pas un defaut ;
    # une carte GRATUITE porteuse de regle jamais vue sur une longue serie, si.
    chemin_cartes = os.path.join(os.path.dirname(__file__), "..", "src", "shared", "Cards.lua")
    payantes = set()
    if os.path.exists(chemin_cartes):
        cat = io.open(chemin_cartes, encoding="utf-8").read()
        for bloc in cat.split("	{")[1:]:
            m = re.search(r'id = "(\w+)"', bloc)
            if m and re.search(r"prix = \d+", bloc[:1200]):
                payantes.add(m.group(1))
    distribuees = set(poses)
    absentes = [i for i in regles if i not in distribuees]
    gratuites_absentes = [i for i in absentes if i not in payantes]
    print("  (cartes a regle vues : %d sur %d ; %d absente(s) payante(s), donc hors paquet du robot)"
          % (len(regles) - len(absentes), len(regles),
             len([i for i in absentes if i in payantes])))
    if len(parties_sim(d)) >= 15 and gratuites_absentes:
        verdict(False, "cartes gratuites a regle jamais vues",
                ", ".join(sorted(gratuites_absentes)))

    # 6 bis. RYTHME DU ROBOT, rapporte au TEMPS DE JEU et non au nombre de decisions.
    # Lecon du 2026-09-21, payee par une conclusion fausse : le compteur « menace_sans_carte »
    # vaut 16,6 % des decisions en aguerri et 21,8 % en expert. J'en ai conclu que l'ecart venait
    # de la cadence d'observation — un robot qui reflechit plus souvent constate plus souvent
    # qu'il est a sec. C'etait FAUX pour les deux tiers : rapporte a la seconde de JEU, l'ecart
    # ne se reduit pas, il TRIPLE (0,066/s en normal, 0,232/s en expert). Un taux « par
    # decision » melange deux choses ; seule la mesure par seconde separe la cadence de la
    # situation reelle. Cet outil affiche donc les deux.
    accel = 1.0
    chemin_serveur = os.path.join(os.path.dirname(__file__), "..", "src", "server",
                                  "GameServer.server.lua")
    if os.path.exists(chemin_serveur):
        m = re.search(r"SIM_ACCEL\s*=\s*(\d+)", io.open(chemin_serveur, encoding="utf-8").read())
        if not m:
            # la constante vit desormais dans Regles.lua (le serveur etait a la limite des
            # 200 variables locales de Luau) : on la cherche la, sinon la mesure serait fausse
            # d'un facteur 8 — erreur deja commise une fois.
            regles = os.path.join(os.path.dirname(__file__), "..", "src", "shared", "Regles.lua")
            if os.path.exists(regles):
                m = re.search(r"SIM_ACCEL\s*=\s*(\d+)", io.open(regles, encoding="utf-8").read())
        if m:
            accel = float(m.group(1))
    horodates = [(float(m.group(1)), l) for l in d.splitlines()
                 for m in [re.match(r"[^,]+,([\d.]+),", l)] if m]
    decisions = [(t, l) for t, l in horodates if "[BOT] camp=" in l and "action=" in l]
    if len(decisions) >= 50:
        # temps de JEU = temps mural x acceleration de la simulation
        duree = (decisions[-1][0] - decisions[0][0]) * accel
        # on retire les inter-parties : on somme par partie plutot que de prendre les extremes
        par_partie, courant = [], []
        for t, l in horodates:
            if "[BOT] camp=" in l and "action=" in l:
                courant.append(t)
            elif "[SIM] " in l and "partie=" in l:
                if len(courant) >= 2:
                    par_partie.append((max(courant) - min(courant)) * accel)
                courant = []
        if par_partie:
            duree = sum(par_partie)
        if duree > 0:
            n_dec = len(decisions)
            menaces = sum(1 for _, l in decisions if "raison=menace_sans_carte" in l)
            poses = sum(1 for _, l in decisions if "action=joue" in l)
            print("  (rythme, en secondes de JEU : %.0f s | %.2f decisions/s | %.3f cartes/s | "
                  "menace sans carte %.3f/s soit %.1f %% des decisions)"
                  % (duree, n_dec / duree, poses / duree, menaces / duree,
                     100 * menaces / max(1, n_dec)))

    # 7. rythme : combien de temps le terrain est-il vide ?
    unites = [int(n) for n in re.findall(r"\[BRR\] t=\d+ unites=(\d+)", d)]
    if unites:
        vide = sum(1 for u in unites if u == 0)
        print("  (terrain vide sur %d releves sur %d, mediane %d unites)"
              % (vide, len(unites), sorted(unites)[len(unites) // 2]))

    # 8. EQUILIBRE DE LA SERIE, quand le journal contient plusieurs parties (--sim).
    # Une seule partie ne dit rien d'un desequilibre : il faut du volume. C'est precisement ce qui
    # manquait a cet outil — j'ai cru voir un biais sur 8 parties (6 scores 3-0) qui a disparu
    # sur 20. On affiche donc la probabilite qu'un ecart vienne du simple hasard.
    parties = parties_sim(d)
    if len(parties) >= 10:
        from math import comb

        def hasard(k, n):
            if n <= 0:
                return 1.0
            return sum(comb(n, i) for i in range(n + 1) if abs(i - n / 2) >= abs(k - n / 2)) / 2 ** n

        n = len(parties)
        fort = sum(1 for _, g, _, _ in parties if g == "fort")
        egalites = sum(1 for _, g, _, _ in parties if g == "egalite")
        # le camp « fort » ALTERNE (camp 1 aux parties impaires) : on remonte au camp reel
        camp1 = 0
        for k, g, _, _ in parties:
            cf = 1 if int(k) % 2 == 1 else 2
            if (g == "fort" and cf == 1) or (g == "faible" and cf == 2):
                camp1 += 1
        decisives = n - egalites
        print("  serie de %d parties : etiquette 'fort' %d (p=%.2f), camp 1 %d (p=%.2f), %d egalite(s)"
              % (n, fort, hasard(fort, n), camp1, hasard(camp1, decisives), egalites))
        # une etiquette arbitraire qui gagne trop souvent, ou un cote, c'est un vrai desequilibre
        verdict(hasard(fort, n) > 0.05, "equilibre entre les deux camps",
                "'fort' %d/%d, p=%.2f (un ecart est suspect sous 0,05)" % (fort, n, hasard(fort, n)))
        verdict(hasard(camp1, decisives) > 0.05, "equilibre des cotes",
                "camp 1 %d/%d, p=%.2f" % (camp1, decisives, hasard(camp1, decisives)))
        # des parties qui finissent TOUTES pareil signalent un jeu sans variete
        scores = Counter("%s-%s" % (max(a, b), min(a, b)) for _, _, a, b in parties)
        domine, combien = scores.most_common(1)[0]
        verdict(combien <= n * 0.6, "variete des scores",
                "%s revient %d fois sur %d (%s)"
                % (domine, combien, n, ", ".join("%s x%d" % (k, v) for k, v in scores.most_common(4))))

    print()
    if anomalies:
        print("ANOMALIES A REGARDER : " + ", ".join(anomalies))
        return 1
    print("VERT : aucun des defauts deja rencontres ne s'est reproduit sur cette partie")
    return 0


if __name__ == "__main__":
    sys.exit(main())
