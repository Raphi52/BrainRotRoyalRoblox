-- JOURNAL DES PARTIES : la liste des dernieres batailles du joueur, en fonctions PURES.
--
-- Defaut mesure le 2026-09-20 : le profil ne gardait que DEUX nombres, `parties` et `victoires`.
-- Le joueur ne pouvait donc pas repondre a la question la plus banale d'un jeu de duel : « ca va
-- mieux ou moins bien en ce moment ? ». Une serie de defaites se voyait seulement au compteur de
-- trophees qui descend, sans savoir CONTRE QUI ni COMBIEN de parties. Aucun ecran ne montrait la
-- derniere partie, pas meme celle qu'on vient de finir.
--
-- Choix assume : on garde peu (JOURNAL_MAX) et on garde le VISIBLE (issue, trophees gagnes ou
-- perdus, nom de l'adversaire, instant). Pas de rejeu, pas de statistiques savantes : le joueur
-- veut voir ses dernieres parties, pas un tableau de bord.
--
-- Aucune API Roblox ici : le banc tools/test_journal.py rejoue tout hors Studio.
local Journal = {}

Journal.MAX = 10 -- parties gardees ; au-dela, la plus ancienne sort

-- AJOUT d'une partie. La plus RECENTE est en tete : c'est celle qu'on vient de jouer, donc celle
-- qu'on cherche. Rend une NOUVELLE liste (le profil garde la sienne tant que l'ecriture n'a pas eu
-- lieu), jamais modifiee sur place.
function Journal.ajouter(liste, entree, maxi)
	local m = math.max(1, math.floor(tonumber(maxi) or Journal.MAX))
	local n = { entree }
	for _, e in ipairs(liste or {}) do
		if #n >= m then
			break
		end
		table.insert(n, e)
	end
	return n
end

-- UNE ENTREE, telle qu'elle est rangee. `issue` vaut "victoire", "defaite" ou "egalite".
function Journal.entree(issue, trophees, adversaire, quand)
	return {
		issue = issue,
		trophees = math.floor(tonumber(trophees) or 0),
		adversaire = (adversaire ~= nil and adversaire ~= "" and adversaire) or "Robot",
		quand = math.floor(tonumber(quand) or 0),
	}
end

local MOT = { victoire = "VICTOIRE", defaite = "DEFAITE", egalite = "EGALITE" }

-- DEPUIS QUAND : « a l'instant », « il y a 5 min », « il y a 2 h », « il y a 3 j ». Un horodatage
-- brut ne dit rien a un joueur ; le temps ECOULE, si.
function Journal.depuis(quand, maintenant)
	local d = math.max(0, math.floor((tonumber(maintenant) or 0) - (tonumber(quand) or 0)))
	if d < 60 then
		return "a l'instant"
	elseif d < 3600 then
		return "il y a " .. math.floor(d / 60) .. " min"
	elseif d < 86400 then
		return "il y a " .. math.floor(d / 3600) .. " h"
	end
	return "il y a " .. math.floor(d / 86400) .. " j"
end

-- UNE LIGNE LISIBLE : « VICTOIRE  +30  contre Robot  il y a 5 min ». Le signe des trophees est
-- TOUJOURS ecrit : « 30 » et « -15 » se confondent en diagonale, « +30 » et « -15 » non.
function Journal.ligne(e, maintenant)
	if not e then
		return ""
	end
	local signe = (e.trophees or 0) >= 0 and "+" or ""
	return string.format("%s   %s%d   contre %s   %s", MOT[e.issue] or "PARTIE", signe,
		math.floor(e.trophees or 0), tostring(e.adversaire or "Robot"),
		Journal.depuis(e.quand, maintenant))
end

-- BILAN de ce que la liste contient : c'est la reponse a « ca va mieux ou moins bien ? ».
function Journal.bilan(liste)
	local b = { parties = 0, victoires = 0, defaites = 0, egalites = 0, trophees = 0 }
	for _, e in ipairs(liste or {}) do
		b.parties = b.parties + 1
		b.trophees = b.trophees + math.floor(tonumber(e.trophees) or 0)
		if e.issue == "victoire" then
			b.victoires = b.victoires + 1
		elseif e.issue == "defaite" then
			b.defaites = b.defaites + 1
		else
			b.egalites = b.egalites + 1
		end
	end
	return b
end

-- RESUME en une ligne, affiche en tete de l'ecran.
function Journal.resume(liste)
	local b = Journal.bilan(liste)
	if b.parties == 0 then
		return "Aucune partie jouee pour l'instant"
	end
	local signe = b.trophees >= 0 and "+" or ""
	-- Accord : « 1 derniere partie », pas « 1 dernieres parties » (vu a l'ecran, cap-journal.png).
	local mot = b.parties > 1 and "dernieres parties" or "derniere partie"
	return string.format("%d %s : %d V / %d D   %s%d trophees",
		b.parties, mot, b.victoires, b.defaites, signe, b.trophees)
end

-- COULEUR d'une ligne, decidee ici (et non dans l'ecran) pour que le banc puisse la verifier :
-- vert = gagne, rouge = perdu, gris = egalite.
function Journal.teinte(issue)
	if issue == "victoire" then
		return { 120, 220, 140 }
	elseif issue == "defaite" then
		return { 235, 110, 110 }
	end
	return { 185, 190, 205 }
end

return Journal
