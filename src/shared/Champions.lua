-- CHAMPIONS (2026-09-21) : cartes a CAPACITE ACTIVABLE, comme dans le jeu de reference.
-- Un champion pose sur l'arene donne a son joueur un bouton de capacite : elle coute de l'elixir,
-- puis se RECHARGE. Un seul champion par deck. Regles pures (tools/test_champions.py) ; le
-- serveur applique l'effet (GameServer, activerCapacite) et reste seul juge.
local Champions = {}

Champions.MAX_PAR_DECK = 1

-- effet "bouclier" : `valeur` points de bouclier poses sur le champion lui-meme.
-- effet "gel"      : gele les unites ADVERSES a moins de `rayon` studs du champion, `duree` s.
Champions.CAPACITES = {
	bouclierRoyal = { nom = "Bouclier royal", cout = 2, recharge = 12, effet = "bouclier", valeur = 500,
		texte = "Bouclier de 500 sur le champion" },
	rugissement = { nom = "Rugissement", cout = 2, recharge = 14, effet = "gel", rayon = 7, duree = 2.5,
		texte = "Gele les ennemis proches 2,5 s" },
}

function Champions.est(card)
	return type(card) == "table" and card.capacite ~= nil and Champions.CAPACITES[card.capacite] ~= nil
end

function Champions.capacite(card)
	return Champions.est(card) and Champions.CAPACITES[card.capacite] or nil
end

-- Nombre de champions dans une liste d'identifiants de cartes.
function Champions.compter(ids, byId)
	local n = 0
	for _, id in ipairs(ids or {}) do
		if Champions.est(byId[id]) then
			n = n + 1
		end
	end
	return n
end

function Champions.deckValide(ids, byId)
	if Champions.compter(ids, byId) > Champions.MAX_PAR_DECK then
		return false, "un seul champion par deck"
	end
	return true
end

-- Secondes avant la prochaine activation (0 = prete). `derniere` nil = jamais utilisee.
function Champions.reste(derniere, recharge, maintenant)
	if not derniere then
		return 0
	end
	return math.max(0, recharge - (maintenant - derniere))
end

-- etat = { capacite = id, vivant = bool, derniere = instant ou nil }
function Champions.peutActiver(etat, elixir, maintenant)
	local c = etat and Champions.CAPACITES[etat.capacite]
	if not c then
		return false, "pas de champion"
	end
	if not etat.vivant then
		return false, "ton champion est tombe"
	end
	local r = Champions.reste(etat.derniere, c.recharge, maintenant)
	if r > 0 then
		return false, string.format("recharge : %d s", math.ceil(r))
	end
	if (elixir or 0) < c.cout then
		return false, "il faut " .. c.cout .. " elixir"
	end
	return true
end

-- Ce que le bouton affiche : nom, cout, secondes restantes, pret ou non.
function Champions.vue(etat, elixir, maintenant)
	local c = etat and Champions.CAPACITES[etat.capacite]
	if not c or not etat.vivant then
		return nil
	end
	local r = Champions.reste(etat.derniere, c.recharge, maintenant)
	return { nom = c.nom, cout = c.cout, reste = math.ceil(r), recharge = c.recharge,
		pret = r <= 0 and (elixir or 0) >= c.cout, texte = c.texte }
end

return Champions
