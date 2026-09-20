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

-- TROPHEES APRES UNE PARTIE. `issue` : "victoire" | "defaite" | "egalite".
-- Le plancher protege s'applique a la DESCENTE uniquement : on peut toujours monter.
function Arenes.apres(trophees, issue)
	local t = tonumber(trophees) or 0
	if issue == "victoire" then
		return t + Arenes.GAIN_VICTOIRE
	elseif issue == "defaite" then
		if t <= Arenes.PLANCHER_PROTEGE then
			return t -- protege : on ne descend plus
		end
		return math.max(Arenes.PLANCHER_PROTEGE, t - Arenes.PERTE_DEFAITE)
	end
	return t
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

-- MEILLEUR COFFRE que l'arene autorise : un joueur d'arene 1 ne gagne pas de coffre d'or.
function Arenes.coffreMax(trophees)
	return Arenes.actuelle(trophees).coffre
end

return Arenes
