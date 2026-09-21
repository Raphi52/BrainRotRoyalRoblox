-- PROGRESSION DE LA COLLECTION, en fonctions PURES.
--
-- Defaut mesure le 2026-09-21 : le jeu compte 40 cartes, et le joueur ne voyait NULLE PART
-- combien il en possede. L'ecran des cartes affiche une grille ou les cartes non possedees sont
-- ternes : pour savoir ou il en est, il fallait les compter a l'oeil. Le seul chiffre existant
-- (« X cartes sur 8 ») parle du DECK, pas de la collection — il entretenait meme la confusion.
--
-- Trois nombres suffisent, et ils ne disent pas la meme chose :
--   - POSSEDEES : ce qu'il a ;
--   - A ACHETER : ce qu'il peut prendre MAINTENANT, avec des pieces — une action possible ce soir ;
--   - PLUS HAUT : ce qui attend une arene, donc des trophees, pas des pieces. Melanger les deux
--     ferait croire a un mur d'argent la ou il n'y a qu'un palier a atteindre.
--
-- Aucune API Roblox, aucun require : tools/test_collection.py rejoue tout hors Studio. Les regles
-- d'arene arrivent par la fonction `debloqueeDe`, pour que ce module ne depende de rien.
local Collection = {}

function Collection.bilan(possedees, catalogue, debloqueeDe)
	local b = { possedees = 0, total = 0, aAcheter = 0, plusHaut = 0 }
	for _, c in ipairs(catalogue or {}) do
		b.total = b.total + 1
		if (possedees or {})[c.id] then
			b.possedees = b.possedees + 1
		elseif debloqueeDe and not debloqueeDe(c.id) then
			-- Verrouillee par l'arene : aucune somme de pieces ne l'ouvre aujourd'hui.
			b.plusHaut = b.plusHaut + 1
		elseif (tonumber(c.prix) or 0) > 0 then
			b.aAcheter = b.aAcheter + 1
		end
	end
	return b
end

-- PART POSSEDEE, entre 0 et 1 : sert a la barre. Un catalogue vide rend 0 et ne divise pas par 0.
function Collection.part(b)
	if not b or (b.total or 0) <= 0 then
		return 0
	end
	return math.max(0, math.min(1, b.possedees / b.total))
end

-- LA LIGNE AFFICHEE. Les deux restes ne sont cites que s'ils existent : « 0 a acheter » sur une
-- collection complete serait du bruit.
function Collection.texte(b)
	if not b or (b.total or 0) <= 0 then
		return ""
	end
	local l = "COLLECTION : " .. b.possedees .. " / " .. b.total
	if b.possedees >= b.total then
		return l .. " - collection complete !"
	end
	local bouts = {}
	if (b.aAcheter or 0) > 0 then
		table.insert(bouts, b.aAcheter .. " a acheter")
	end
	if (b.plusHaut or 0) > 0 then
		table.insert(bouts, b.plusHaut .. (b.plusHaut > 1 and " s'ouvrent plus haut" or " s'ouvre plus haut"))
	end
	if #bouts == 0 then
		return l
	end
	return l .. " - " .. table.concat(bouts, ", ")
end

-- ===== BOUTIQUE : CE QUI RESTE A PRENDRE, ET CE QUI ATTEND PLUS HAUT =====
--
-- Defaut mesure le 2026-09-21 : la boutique n'affichait que le solde. Devant une grille de 47
-- tuiles, le joueur ne savait ni combien de cartes il peut s'offrir MAINTENANT, ni combien il lui
-- manque pour la premiere, ni ce que la prochaine arene lui ouvrira. Il faisait le tour des tuiles
-- une par une pour comparer des prix.

-- CE QU'IL PEUT PRENDRE TOUT DE SUITE. `pieces` = son solde. Rend aussi le prix de la MOINS CHERE
-- des cartes hors de portee : c'est le seul chiffre qui dit « encore un effort ».
function Collection.aPortee(possedees, catalogue, debloqueeDe, pieces)
	local sous = tonumber(pieces) or 0
	local r = { abordables = 0, restantes = 0, prochainPrix = nil, manque = nil,
		enchainables = 0, coutEnchainables = 0, solde = sous }
	local prixRestants = {}
	for _, c in ipairs(catalogue or {}) do
		local prix = tonumber(c.prix) or 0
		local ouverte = (debloqueeDe == nil) or debloqueeDe(c.id)
		if not (possedees or {})[c.id] and ouverte and prix > 0 then
			r.restantes = r.restantes + 1
			table.insert(prixRestants, prix)
			if prix <= sous then
				r.abordables = r.abordables + 1
			elseif r.prochainPrix == nil or prix < r.prochainPrix then
				r.prochainPrix = prix
			end
		end
	end
	if r.prochainPrix then
		r.manque = r.prochainPrix - sous
	end
	-- COMBIEN IL PEUT EN PRENDRE D'AFFILEE, pas « combien sont abordables une par une ». Defaut vu
	-- a l'ecran le 2026-09-21 (cap-boutique-riche.png) : avec 2000 pieces, la boutique annoncait
	-- « 7 cartes a ta portee (5800 pieces en tout) » — un total que le joueur ne peut PAS payer.
	-- On part de la moins chere : c'est l'ordre qui en donne le plus.
	table.sort(prixRestants)
	local reste = sous
	for _, prix in ipairs(prixRestants) do
		if prix > reste then
			break
		end
		reste = reste - prix
		r.enchainables = r.enchainables + 1
		r.coutEnchainables = r.coutEnchainables + prix
	end
	return r
end

function Collection.texteBoutique(r)
	if not r or r.restantes == 0 then
		return "Tu as toutes les cartes ouvertes a ton arene"
	end
	if r.enchainables > 0 then
		local mot = r.enchainables > 1 and " cartes a ta portee" or " carte a ta portee"
		-- Le cout affiche est celui de CES cartes-la, donc une somme reellement payable.
		return r.enchainables .. mot .. " (" .. r.coutEnchainables .. " pieces sur "
			.. math.floor(tonumber(r.solde) or r.coutEnchainables) .. ")"
	end
	-- Aucune a portee : on donne l'effort restant, pas un simple « non ».
	return "Il te manque " .. math.max(0, math.floor(r.manque or 0)) .. " pieces pour la moins chere"
end

-- CE QUE LA PROCHAINE ARENE OUVRIRA. Rend une chaine vide dans la derniere arene : promettre une
-- suite qui n'existe pas serait pire que se taire.
function Collection.texteProchaineArene(nom, tropheesManquants, noms)
	if not nom then
		return ""
	end
	local t = "Arene suivante, " .. tostring(nom) .. " (dans "
		.. math.max(0, math.floor(tonumber(tropheesManquants) or 0)) .. " trophees)"
	if noms and #noms > 0 then
		return t .. " : " .. table.concat(noms, ", ")
	end
	return t .. " : aucune nouvelle carte"
end

-- ETAT D'UNE TUILE DE L'ECRAN DECK. Une carte possedee hors du deck n'affichait RIEN, et avec un
-- deck plein son clic etait ignore sans un mot (capture deck.png, 2026-09-21). Elle dit
-- maintenant ce que fera le clic — ou pourquoi il ne fera rien.
-- `manqueTrophees` / `prix` : POURQUOI elle est verrouillee. « verrouillee » seul ne disait ni
-- qu'elle s'achete, ni qu'il faut monter d'arene (capture bas-deck.png, 2026-09-21).
function Collection.etatDeck(possede, dansDeck, plein, manqueTrophees, prix)
	if not possede then
		if (tonumber(manqueTrophees) or 0) > 0 then
			return "encore " .. math.floor(manqueTrophees) .. " trophees"
		end
		if (tonumber(prix) or 0) > 0 then
			return "en boutique : " .. math.floor(prix) .. " pieces"
		end
		return "verrouillee"
	end
	if dansDeck then
		return "DANS LE DECK"
	end
	if plein then
		return "deck plein : retire une carte"
	end
	return "+ AJOUTER"
end

-- DECK MODIFIE ET NON ENREGISTRE ? `choix` : ensemble { [id] = true } de l'ecran, `deck` : liste
-- enregistree cote serveur. Le bouton restait vert sans changement, et un changement non
-- enregistre etait perdu EN SILENCE en quittant l'ecran (chargerChoix a la reouverture).
-- `taille` : sans deck choisi, le serveur renvoie TOUTES les cartes possedees et l'ecran n'en
-- retient que les `taille` premieres (chargerChoix) : on compare aux memes, pas a la liste entiere.
function Collection.deckModifie(choix, deck, taille)
	local n = 0
	for i, id in ipairs(deck or {}) do
		if taille and i > taille then
			break
		end
		if not (choix or {})[id] then
			return true
		end
		n = n + 1
	end
	local m = 0
	for _, oui in pairs(choix or {}) do
		if oui then
			m = m + 1
		end
	end
	return m ~= n
end

return Collection
