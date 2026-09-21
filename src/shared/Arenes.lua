-- ARENES ET LIGUES : ce que les trophees veulent DIRE.
--
-- Defaut mesure avant ce module : les trophees n'etaient qu'un nombre. Aucun palier, aucun nom,
-- aucune recompense en les franchissant, aucune protection en bas de tableau — un joueur neuf
-- pouvait redescendre sous zero et ne voyait jamais de progression. Et le deblocage des cartes se
-- faisait UNIQUEMENT par le prix en pieces : une legendaire pouvait etre achetee des la premiere
-- partie si l'on avait assez d'or.
--
-- Fonctions PURES (tools/test_arenes.py). Le hub affiche, l'economie applique.
local Arenes = {}

-- Paliers, du premier au dernier. `deblocage` : cartes que l'arene rend ACHETABLES en boutique.
-- `coffre` : meilleur coffre que l'on peut y gagner. `recompense` : pieces versees une seule fois,
-- a la premiere arrivee dans l'arene.
Arenes.LISTE = {
	{ seuil = 0,    nom = "Cour des Brainrots", coffre = "bois",   recompense = 0,    deblocage = {} },
	{ seuil = 200,  nom = "Plage Tralalero",    coffre = "bois",   recompense = 150,  deblocage = { "FuriaBrainrot", "Bombardiro" } },
	{ seuil = 600,  nom = "Foret Patapim",      coffre = "argent", recompense = 400,  deblocage = { "Bicus", "Tigrullini" } },
	{ seuil = 1200, nom = "Usine Spaghetti",    coffre = "argent", recompense = 900,  deblocage = { "Patapim", "Giraffa" } },
	{ seuil = 2000, nom = "Cratere Nuclearo",   coffre = "or",     recompense = 1800, deblocage = { "Vacca", "Nuclearo" } },
}

-- PROTECTION : sous ce nombre de trophees, une defaite n'en retire plus. Sans elle, un debutant
-- qui enchaine trois defaites descend sous zero et n'a plus aucun repere.
Arenes.PLANCHER_PROTEGE = 100
Arenes.GAIN_VICTOIRE = 30
Arenes.PERTE_DEFAITE = 15

function Arenes.index(trophees)
	local t = tonumber(trophees) or 0
	local i = 1
	for k, a in ipairs(Arenes.LISTE) do
		if t >= a.seuil then
			i = k
		end
	end
	return i
end

function Arenes.actuelle(trophees)
	return Arenes.LISTE[Arenes.index(trophees)]
end

function Arenes.nom(trophees)
	return Arenes.actuelle(trophees).nom
end

-- PROGRESSION vers l'arene suivante, entre 0 et 1 (1 dans la derniere arene).
function Arenes.progression(trophees)
	local t = math.max(0, tonumber(trophees) or 0)
	local i = Arenes.index(trophees)
	local a, b = Arenes.LISTE[i], Arenes.LISTE[i + 1]
	if not b then
		return 1
	end
	return math.clamp((t - a.seuil) / (b.seuil - a.seuil), 0, 1)
end

function Arenes.suivante(trophees)
	return Arenes.LISTE[Arenes.index(trophees) + 1]
end

-- L'ENJEU D'UNE PARTIE. Defaut mesure le 2026-09-21 : une victoire rapportait +30 QUEL QUE SOIT
-- l'adversaire — le robot debutant (qui remplace l'adversaire apres 20 s d'attente) autant qu'un
-- humain, et un debutant autant qu'un joueur mille trophees au-dessus. Deux consequences :
--   - on pouvait GRIMPER AU CLASSEMENT MONDIAL en battant le robot en boucle, sans jamais
--     affronter personne ; le chiffre qui sert de classement ET d'appariement devenait faux ;
--   - battre plus fort que soi ne valait rien de plus : aucune raison de viser haut.
-- Desormais l'enjeu SUIT l'adversaire :
--   - contre le ROBOT, le tiers seulement : on progresse encore quand personne n'est en ligne (le
--     joueur n'y est pour rien), mais la voie rapide passe par les humains ;
--   - contre un HUMAIN, selon l'ecart de trophees : battre plus fort rapporte plus, perdre contre
--     plus faible coute plus. Borne des deux cotes, pour qu'une seule partie ne decide pas tout.
-- Les montants de base (+30 / -15) ne changent pas : c'est un reglage choisi, et on ne le
-- retouche pas ici.
Arenes.PART_ROBOT = 1 / 3      -- part de l'enjeu contre le robot
Arenes.ECART_REF = 1000        -- ecart de trophees qui fait varier l'enjeu de 100 %
Arenes.FACTEUR_MIN = 0.5       -- jamais moins de la moitie de l'enjeu de base
Arenes.FACTEUR_MAX = 1.5       -- jamais plus d'une fois et demie

-- Facteur pour l'issue vue par `moi` : un adversaire plus fort gonfle un gain, un adversaire plus
-- faible gonfle une perte. Adversaire inconnu -> facteur 1 (l'ancien comportement).
function Arenes.facteur(issue, mesTrophees, sesTrophees, contreHumain)
	if contreHumain == false then
		return Arenes.PART_ROBOT
	end
	local moi = tonumber(mesTrophees)
	local lui = tonumber(sesTrophees)
	if not moi or not lui then
		return 1
	end
	local ecart = (lui - moi) / Arenes.ECART_REF
	if issue == "defaite" then
		ecart = -ecart -- perdre contre plus FAIBLE doit couter plus, contre plus fort moins
	end
	return math.max(Arenes.FACTEUR_MIN, math.min(Arenes.FACTEUR_MAX, 1 + ecart))
end

-- Variation de trophees, avant le plancher protege.
function Arenes.variation(issue, mesTrophees, sesTrophees, contreHumain)
	local f = Arenes.facteur(issue, mesTrophees, sesTrophees, contreHumain)
	if issue == "victoire" then
		return math.floor(Arenes.GAIN_VICTOIRE * f + 0.5)
	elseif issue == "defaite" then
		return -math.floor(Arenes.PERTE_DEFAITE * f + 0.5)
	end
	return 0
end

-- TROPHEES APRES UNE PARTIE. `issue` : "victoire" | "defaite" | "egalite".
-- Le plancher protege s'applique a la DESCENTE uniquement : on peut toujours monter.
-- `sesTrophees` et `contreHumain` sont facultatifs : sans eux, l'enjeu de base s'applique.
function Arenes.apres(trophees, issue, sesTrophees, contreHumain)
	local t = tonumber(trophees) or 0
	local d = Arenes.variation(issue, t, sesTrophees, contreHumain)
	if d >= 0 then
		return t + d
	end
	if t <= Arenes.PLANCHER_PROTEGE then
		return t -- protege : on ne descend plus
	end
	return math.max(Arenes.PLANCHER_PROTEGE, t + d)
end

-- Une carte est-elle DEBLOQUEE par l'arene atteinte ? Une carte absente de toutes les listes de
-- deblocage est disponible des le depart (c'est le cas des cartes offertes).
function Arenes.carteDebloquee(id, trophees)
	local i = Arenes.index(trophees)
	for k, a in ipairs(Arenes.LISTE) do
		for _, c in ipairs(a.deblocage) do
			if c == id then
				return k <= i, Arenes.LISTE[k].nom
			end
		end
	end
	return true, nil
end

-- DISTANCE D'UNE CARTE VERROUILLEE : « a debloquer plus haut » ne disait pas COMBIEN. On rend
-- le nombre de trophees qui manquent (nil si la carte n'est pas verrouillee par une arene).
function Arenes.tropheesManquants(id, trophees)
	local t = tonumber(trophees) or 0
	for _, a in ipairs(Arenes.LISTE) do
		for _, c in ipairs(a.deblocage) do
			if c == id then
				return math.max(0, a.seuil - t)
			end
		end
	end
	return nil
end

function Arenes.texteVerrou(prix, id, trophees)
	local m = Arenes.tropheesManquants(id, trophees)
	if not m or m == 0 then
		return tostring(prix) .. " pieces"
	end
	return tostring(prix) .. " pieces - encore " .. m .. " trophees"
end

-- ARENES FRANCHIES entre deux totaux de trophees : sert a verser la recompense de palier UNE
-- SEULE FOIS, meme si le joueur saute deux paliers d'un coup.
function Arenes.franchies(avant, apres)
	local ia, ib = Arenes.index(avant), Arenes.index(apres)
	local l = {}
	for k = ia + 1, ib do
		table.insert(l, Arenes.LISTE[k])
	end
	return l
end

function Arenes.recompensePalier(avant, apres)
	local total = 0
	for _, a in ipairs(Arenes.franchies(avant, apres)) do
		total = total + (a.recompense or 0)
	end
	return total
end

-- MONTEE D'ARENE ANNONCEE. Defaut mesure le 2026-09-20 : franchir un palier changeait le profil
-- en SILENCE. Le serveur versait la recompense de palier (jusqu'a 1800 pieces) et debloquait des
-- cartes en boutique, mais l'ecran de fin de partie n'affichait que « +30 trophees   +12 pieces » :
-- les pieces de palier n'etaient meme pas comptees dans ce total, et rien ne disait qu'une nouvelle
-- arene et de nouvelles cartes venaient de s'ouvrir. Le joueur ne l'apprenait qu'en retournant de
-- lui-meme en boutique.
-- Rend nil quand aucune arene n'est franchie : l'ecran ne montre rien dans le cas ordinaire.
function Arenes.montee(avant, apres)
	local f = Arenes.franchies(avant, apres)
	if #f == 0 then
		return nil
	end
	local cartes = {}
	for _, a in ipairs(f) do
		for _, id in ipairs(a.deblocage) do
			table.insert(cartes, id)
		end
	end
	local derniere = f[#f]
	return {
		nom = derniere.nom,
		pieces = Arenes.recompensePalier(avant, apres),
		cartes = cartes,
		coffre = derniere.coffre,
	}
end

-- LIGNES AFFICHEES de cette montee. `nomDe` traduit un identifiant de carte en nom lisible ; sans
-- elle, l'identifiant brut est affiche (mieux que rien, et le banc peut le verifier).
function Arenes.lignesMontee(m, nomDe)
	if not m then
		return {}
	end
	local l = { "NOUVELLE ARENE : " .. tostring(m.nom) }
	if (m.pieces or 0) > 0 then
		table.insert(l, "Recompense d'arene : +" .. math.floor(m.pieces) .. " pieces")
	end
	if #(m.cartes or {}) > 0 then
		local noms = {}
		for _, id in ipairs(m.cartes) do
			table.insert(noms, (nomDe and nomDe(id)) or id)
		end
		local mot = #noms > 1 and "Nouvelles cartes en boutique : " or "Nouvelle carte en boutique : "
		table.insert(l, mot .. table.concat(noms, ", "))
	end
	table.insert(l, "Coffres jusqu'au niveau " .. tostring(m.coffre))
	return l
end

-- MEILLEUR COFFRE que l'arene autorise : un joueur d'arene 1 ne gagne pas de coffre d'or.
function Arenes.coffreMax(trophees)
	return Arenes.actuelle(trophees).coffre
end

return Arenes
