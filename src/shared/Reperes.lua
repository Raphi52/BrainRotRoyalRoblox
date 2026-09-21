-- CE QUI DISTINGUE UNE CARTE DES AUTRES, en fonctions PURES.
--
-- Defaut mesure le 2026-09-21 : quatre cartes du catalogue (Tralalero, Patapim, Tigrullini,
-- Giraffa) n'ont AUCUNE regle speciale — ni sort, ni bouclier, ni specialite, ni charge. Ce n'est
-- pas un defaut en soi (un jeu a besoin de cartes simples), mais leur fiche n'affiche alors que
-- des nombres bruts : « PV 760 · Degats 210 · Portee 15 ». Pour savoir si 15 studs, c'est loin, il
-- fallait ouvrir les 46 autres fiches et comparer de tete. La description promet « portee record »
-- et rien ne le CONFIRME.
--
-- Ici, le chiffre est SITUE par rapport au catalogue reel : « la plus longue portee du jeu »,
-- « parmi les plus rapides ». Rien n'est ecrit a la main — ajouter une carte plus rapide retire
-- la mention a l'ancienne, toute seule.
--
-- Choix assumes :
--   * on ne compare QUE des unites entre elles. Un batiment ne se deplace pas, un sort n'a ni PV
--     ni vitesse : les melanger produirait des « records » qui n'ont aucun sens ;
--   * DEUX mentions au maximum, et seulement ce qui est vraiment saillant. Une carte « dans la
--     moyenne partout » n'affiche rien plutot qu'une ligne tiede ;
--   * le record se dit autrement que le haut du panier : « la plus longue portee » est une
--     information differente de « parmi les plus longues portees ».
local Reperes = {}

-- Part du catalogue qui donne droit a une mention (0,15 = les 15 % du haut).
Reperes.PART_HAUT = 0.15
Reperes.MAX_MENTIONS = 2

-- Criteres compares, dans l'ordre d'interet pour le joueur.
Reperes.CRITERES = {
	{ champ = "range", record = "la plus longue portee du jeu", haut = "longue portee" },
	{ champ = "hp", record = "la carte la plus resistante", haut = "tres resistante" },
	{ champ = "dmg", record = "les plus gros degats du jeu", haut = "gros degats" },
	{ champ = "speed", record = "la carte la plus rapide", haut = "tres rapide" },
}

-- Une carte entre-t-elle dans la comparaison ? Les sorts et les batiments en sortent.
function Reperes.comparable(carte)
	if not carte then
		return false
	end
	return carte.sort == nil and carte.batiment == nil
end

-- Valeurs triees du catalogue pour un champ, de la plus grande a la plus petite.
local function valeurs(catalogue, champ)
	local l = {}
	for _, c in ipairs(catalogue or {}) do
		if Reperes.comparable(c) then
			table.insert(l, tonumber(c[champ]) or 0)
		end
	end
	table.sort(l, function(a, b)
		return a > b
	end)
	return l
end

-- Rang d'une carte sur un critere : 1 = la meilleure. Rend nil si elle n'est pas comparable.
function Reperes.rang(carte, catalogue, champ)
	if not Reperes.comparable(carte) then
		return nil
	end
	local v = tonumber(carte[champ]) or 0
	local l = valeurs(catalogue, champ)
	for i, x in ipairs(l) do
		if v >= x then
			return i, #l
		end
	end
	return #l, #l
end

-- LES MENTIONS d'une carte, au plus MAX_MENTIONS. Une egalite au sommet donne le record aux deux :
-- deux cartes a 15 studs sont toutes les deux « la plus longue portee », et c'est vrai.
function Reperes.points(carte, catalogue)
	local out = {}
	if not Reperes.comparable(carte) then
		return out
	end
	for _, crit in ipairs(Reperes.CRITERES) do
		local rang, total = Reperes.rang(carte, catalogue, crit.champ)
		if rang and total and total > 1 then
			if rang == 1 then
				table.insert(out, crit.record)
			elseif rang <= math.max(1, math.floor(total * Reperes.PART_HAUT)) then
				table.insert(out, crit.haut)
			end
		end
		if #out >= Reperes.MAX_MENTIONS then
			break
		end
	end
	return out
end

-- LA LIGNE AFFICHEE. Vide quand la carte n'a rien de saillant : mieux vaut aucune ligne qu'une
-- ligne tiede sur une carte moyenne.
function Reperes.texte(points)
	if not points or #points == 0 then
		return ""
	end
	return "POINT FORT : " .. table.concat(points, ", ")
end

return Reperes
