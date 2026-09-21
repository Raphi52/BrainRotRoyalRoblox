-- ANNONCE D'UNE QUETE TERMINEE, en fonctions PURES.
--
-- Defaut mesure le 2026-09-20 : les quetes du jour s'avancaient en SILENCE. Une quete atteinte en
-- pleine partie (« Detruire 4 tours », « Poser 25 cartes ») ne produisait rien du tout : ni son,
-- ni texte, ni marque. Pire, la recompense n'est pas versee toute seule — elle se RECLAME au menu.
-- Un joueur qui ne rouvrait pas l'ecran des evenements finissait sa session avec des pieces gagnees
-- qu'il n'avait jamais vues. Le seul retour existant etait la ligne de progression dans un ecran
-- qu'il faut penser a ouvrir.
--
-- Ici : le moment ou la quete se finit est NOMME a l'ecran, et il dit ce qu'il faut faire ensuite
-- (aller la reclamer). Aucune API Roblox : tools/test_quete_finie.py rejoue tout hors Studio.
local Quetes = {}

-- Duree d'affichage de l'annonce, en secondes. Assez longue pour etre lue en pleine partie sans
-- rester en travers de l'ecran.
Quetes.DUREE = 6
Quetes.COULEUR = { 255, 215, 90 }

-- LA QUETE VIENT-ELLE DE SE FINIR ? Strictement au FRANCHISSEMENT : sans le « avant < cible », une
-- quete deja finie serait re-annoncee a chaque carte posee ensuite.
function Quetes.vientDeFinir(avant, apres, cible)
	local a = tonumber(avant) or 0
	local b = tonumber(apres) or 0
	local c = tonumber(cible) or 0
	return a < c and b >= c
end

-- TEXTE DE LA QUETE, son gabarit « Gagner %d parties » rempli. Ecrit ici pour que l'annonce et
-- l'ecran des evenements ne puissent pas diverger.
function Quetes.intitule(gabarit, cible)
	local g = tostring(gabarit or "")
	if string.find(g, "%%d") then
		return string.format(g, math.floor(tonumber(cible) or 0))
	end
	return g
end

-- LES DEUX LIGNES AFFICHEES. La seconde dit QUOI FAIRE : la recompense n'est pas automatique,
-- une annonce qui se contenterait de feliciter laisserait les pieces sur place.
function Quetes.titre()
	return "QUETE TERMINEE"
end

function Quetes.lignes(gabarit, cible, gain)
	return {
		Quetes.titre(),
		Quetes.intitule(gabarit, cible),
		"+" .. math.floor(tonumber(gain) or 0) .. " pieces +" .. Quetes.GEMMES .. " gemmes a reclamer au menu",
	}
end

-- L'ANNONCE EST-ELLE ENCORE VIVANTE ? Elle s'eteint TOUTE SEULE apres Quetes.DUREE : le serveur
-- n'attend aucun accuse de reception du client, qui pourrait ne jamais venir.
function Quetes.encoreVisible(pose, maintenant)
	if not pose then
		return false
	end
	local d = (tonumber(maintenant) or 0) - (tonumber(pose) or 0)
	return d >= 0 and d < Quetes.DUREE
end

-- LES GEMMES SANS PAYER : avant le 2026-09-21 elles ne venaient QUE des Robux. Chaque quete
-- du jour en rapporte GEMMES (3 quetes = 6/jour : un coffre d'argent accelere par jour).
Quetes.GEMMES = 2
function Quetes.recompense(pieces, gemmes)
	local t = "+" .. math.floor(tonumber(pieces) or 0)
	if (tonumber(gemmes) or 0) > 0 then t = t .. "  +" .. math.floor(gemmes) .. " gemmes" end
	return t
end
return Quetes
