-- MANUEL : les regles qui valent pour TOUTES les cartes, ecrites en clair.
--
-- Defaut mesure le 2026-09-20 : quatre mecaniques decident des parties et ne sont expliquees
-- NULLE PART. L'elixir double dans le dernier tiers, une egalite ouvre une prolongation, casser
-- une tour OUVRE la moitie adverse de ce cote, et defendre chez soi pres d'une tour vivante
-- reduit les degats subis. Un joueur pouvait faire cent parties sans apprendre aucune des quatre :
-- rien a l'ecran ne les nommait, et elles ne tiennent pas sur une fiche de carte — elles seraient
-- repetees a l'identique sur les 40 cartes, ce qui serait du bruit et non de l'information.
--
-- Regle de conception, la meme que pour les fiches : chaque texte est CALCULE a partir des
-- constantes reelles du jeu, jamais recopie. Les valeurs sont FOURNIES par l'appelant (le hub lit
-- les modules et les passe), donc ce module ne depend de rien et reste verifiable hors Studio
-- (tools/test_manuel.py). Si un reglage change, le manuel change avec lui — il ne peut pas mentir.
local Manuel = {}

local function nombre(n)
	local v = tonumber(n) or 0
	if v == math.floor(v) then
		return tostring(math.floor(v))
	end
	-- DEUX decimales quand une seule ARRONDIRAIT le chiffre : 0,45 s affiche « 0,5 s » et 0,35 s
	-- affiche « 0,3 s » — le manuel annoncait alors des valeurs FAUSSES, l'une trop haute, l'autre
	-- trop basse (mesure du 2026-09-21, section LA POSE). Le manuel doit citer la regle exacte.
	if math.abs(v * 10 - math.floor(v * 10 + 0.5)) > 1e-9 then
		return (string.gsub(string.format("%.2f", v), "%.", ","))
	end
	return (string.gsub(string.format("%.1f", v), "%.", ","))
end

local function pourcent(part)
	return tostring(math.floor((tonumber(part) or 0) * 100 + 0.5)) .. " %"
end

-- Duree en secondes -> « 1 min 00 » : un joueur lit des minutes, pas 180 secondes.
function Manuel.duree(secondes)
	local s = math.max(0, math.floor(tonumber(secondes) or 0))
	local m = math.floor(s / 60)
	if m <= 0 then
		return s .. " s"
	end
	return string.format("%d min %02d", m, s % 60)
end

-- SECTIONS du manuel. `v` porte les valeurs reelles :
--   v.dureeMatch          : duree d'une partie, en secondes
--   v.doublePart          : part FINALE de la partie ou l'elixir double (Regles.DOUBLE_ELIXIR_PART)
--   v.multDouble          : multiplicateur d'elixir a ce moment (Regles.MULT_DOUBLE)
--   v.multProlongation    : multiplicateur en prolongation (Regles.MULT_PROLONGATION)
--   v.prolongationPart    : duree de la prolongation, en part du temps reglementaire
--   v.terrainRayon        : rayon de l'avantage de terrain, en studs (Terrain.RAYON)
--   v.terrainReduction    : degats en moins dans ce rayon (Terrain.REDUCTION)
--   v.elixirMax           : plafond d'elixir
--   v.cartesVues          : combien de cartes adverses restent affichees (Lecture.CARTES_VUES)
--   v.elixirParSeconde    : elixir gagne par seconde en rythme normal
-- Rend une liste de { titre = ..., texte = ... }, dans l'ordre ou le joueur les rencontre.
function Manuel.sections(v)
	v = v or {}
	local s = {}
	local duree = tonumber(v.dureeMatch) or 0
	local doublePart = tonumber(v.doublePart) or 0
	local instantDouble = duree * (1 - doublePart)

	table.insert(s, {
		titre = "ELIXIR",
		texte = "Tu gagnes de l'elixir en continu, jusqu'a " .. nombre(v.elixirMax or 10)
			.. " au maximum. Poser une carte coute son prix en elixir : c'est la seule ressource du jeu.",
	})
	table.insert(s, {
		titre = "ELIXIR DOUBLE",
		texte = "Apres " .. Manuel.duree(instantDouble) .. " de jeu (le dernier "
			.. pourcent(doublePart) .. " de la partie), l'elixir arrive "
			.. nombre(v.multDouble or 2) .. " fois plus vite pour les DEUX camps. C'est la que les grosses poussees deviennent possibles.",
	})
	table.insert(s, {
		titre = "ZONE DE POSE",
		texte = "Tu poses dans TA moitie de l'arene. Casser une tour ennemie OUVRE la moitie adverse"
			.. " de CE cote-la : une tour prise n'est pas qu'une couronne, c'est du terrain gagne.",
	})
	table.insert(s, {
		titre = "AVANTAGE DE TERRAIN",
		texte = "Tes unites subissent " .. pourcent(v.terrainReduction or 0)
			.. " de degats en moins quand elles sont dans ta moitie, a moins de "
			.. nombre(v.terrainRayon or 0) .. " studs d'une de TES tours encore debout."
			.. " Quand cette tour tombe, l'avantage tombe avec elle.",
	})
	-- LIRE L'ADVERSAIRE : le panneau en haut a gauche donne un chiffre d'elixir. Rien ne disait
	-- qu'il s'agit d'une ESTIMATION construite sur du visible, et un joueur qui le croit exact
	-- pousse au mauvais moment puis accuse le jeu. Le dire, c'est en faire une competence.
	table.insert(s, {
		titre = "LIRE L'ADVERSAIRE",
		texte = "En haut a gauche, son elixir est une ESTIMATION : elle part du temps ecoule et des"
			.. " cartes que tu l'as VU poser, jamais de son compteur. Elle derive si tu regardes"
			.. " ailleurs. Dessous, ses " .. nombre(v.cartesVues or 4) .. " dernieres cartes posees :"
			.. " de quoi compter son cycle. Une de TES tours en danger declenche une alerte, avec le"
			.. " cote a regarder.",
	})
	-- COURONNES. Defaut mesure le 2026-09-21 : le jeu compte les couronnes sur les TROIS tours de
	-- depart seulement, et rien ne le disait. Un joueur qui abat la tour de defense posee par
	-- l'adversaire voit son score inchange et ne comprend pas pourquoi. La regle vit dans
	-- Batiments.donneCouronne (appelee par l'ecran, qui la passe ici) : si elle changeait un jour,
	-- ce texte changerait avec elle au lieu de mentir.
	local batimentsComptent = v.batimentCouronne == true
	table.insert(s, {
		titre = "COURONNES",
		texte = "Une couronne se gagne en detruisant une des TROIS tours de depart de l'adversaire :"
			.. " les deux petites et celle du Roi."
			.. (batimentsComptent and " Les batiments poses en comptent aussi."
				or " Un batiment pose (pompe, tour de defense) n'en donne AUCUNE : l'abattre ouvre"
				.. " la voie, rien de plus."),
	})
	-- LA POSE N'EST PAS INSTANTANEE, dans les DEUX sens. Deux regles existent, toutes deux
	-- invisibles et jamais expliquees : l'unite posee met un temps a etre operationnelle, et elle
	-- est brievement intouchable en arrivant. Le joueur les subit sans les comprendre — « j'ai
	-- lance mon sort pile dessus et il n'a rien pris », « ma carte n'a pas repondu tout de suite ».
	if v.deploiement or v.invulnPose then
		local bouts = {}
		if v.deploiement then
			table.insert(bouts, "Une unite posee met " .. nombre(v.deploiement)
				.. " s a etre operationnelle : on ne pose pas une carte au contact pour frapper"
				.. " tout de suite.")
		end
		if v.invulnPose then
			table.insert(bouts, "En echange, elle est intouchable pendant " .. nombre(v.invulnPose)
				.. " s : un sort lance pile sur la pose ne la tue pas.")
		end
		table.insert(s, { titre = "LA POSE", texte = table.concat(bouts, " ") })
	end
	-- DERNIERE GARDE. Regle mesuree et implementee (module Garde), jamais expliquee : quand les
	-- deux tours de princesse d'un camp sont tombees, son Roi tire plus vite. L'attaquant voyait
	-- son unite fondre sans comprendre pourquoi.
	if v.gardeFacteur then
		table.insert(s, {
			titre = "DERNIERE GARDE",
			texte = "Quand les DEUX tours de princesse d'un camp sont tombees, son Roi defend "
				.. nombre(v.gardeFacteur) .. " fois plus vite. Le camp mene garde une chance de"
				.. " tenir, et l'attaquant sait qu'il doit finir maintenant.",
		})
	end
	table.insert(s, {
		titre = "FIN DE PARTIE",
		texte = "Une partie dure " .. Manuel.duree(duree)
			.. ". Le camp qui a le plus de couronnes gagne ; detruire la tour du Roi gagne sur-le-champ.",
	})
	table.insert(s, {
		titre = "PROLONGATION",
		texte = "A egalite de couronnes au chrono, on joue "
			.. Manuel.duree(duree * (tonumber(v.prolongationPart) or 0))
			.. " de plus, avec l'elixir " .. nombre(v.multProlongation or 3)
			.. " fois plus rapide. La PREMIERE tour prise termine la partie ;"
			.. " si personne n'en prend, la tour la plus entamee perd.",
	})
	-- PROGRESSION : le manuel ne parlait que du combat. Coffres, exemplaires, niveaux, gemmes et
	-- quetes n'etaient expliques NULLE PART (2026-09-21). Chiffres venus des modules qui les
	-- appliquent (v.emplacements, v.minutesParGemme, v.gemmesQuete), jamais recopies.
	if v.emplacements then
		table.insert(s, {
			titre = "PROGRESSION",
			texte = "Chaque victoire rapporte un coffre, s'il reste un des " .. nombre(v.emplacements)
				.. " emplacements ; un seul coffre s'ouvre a la fois. Les coffres donnent des pieces et des"
				.. " EXEMPLAIRES de cartes : assez d'exemplaires plus des pieces font monter une carte de"
				.. " niveau (plus de points de vie, plus de degats, sorts compris). Les GEMMES ouvrent tout de"
				.. " suite un coffre en cours (1 par " .. nombre(v.minutesParGemme) .. " min restantes) ;"
				.. " chaque quete du jour en rapporte " .. nombre(v.gemmesQuete) .. ".",
		})
	end
	return s
end

-- Combien de sections : sert a l'ecran pour dimensionner sa liste sans la compter lui-meme.
function Manuel.nombreSections(v)
	return #Manuel.sections(v)
end

return Manuel
