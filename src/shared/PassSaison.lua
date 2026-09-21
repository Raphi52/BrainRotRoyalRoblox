-- PASS DE SAISON (2026-09-21) : paliers debloques en JOUANT, une piste GRATUITE et une piste
-- PREMIUM (pass Roblox, Economie.PASS_SAISON). Branche sur :
--  * Saison.lua : le pass appartient a UNE saison ; au changement de numero il repart a zero ;
--  * les LIGUES : chaque partie rapporte +1 point par rang de ligue (Bronze +1 ... Legende +8),
--    le haut du classement avance plus vite dans son pass.
-- Module pur (tools/test_pass_saison.py) : aucune instance Roblox.
local PassSaison = {}

PassSaison.PALIERS = 20
PassSaison.POINTS_PALIER = 30
PassSaison.POINTS_ISSUE = { victoire = 10, egalite = 6, defaite = 4 }

-- Points d'une partie : issue + bonus de ligue (indexLigue = Ligues.index, 0 hors ligue).
function PassSaison.pointsPartie(issue, indexLigue)
	return (PassSaison.POINTS_ISSUE[issue] or 0) + math.max(0, math.floor(tonumber(indexLigue) or 0))
end

-- Palier ATTEINT (0 .. PALIERS) pour un total de points.
function PassSaison.palier(points)
	return math.min(PassSaison.PALIERS, math.floor((tonumber(points) or 0) / PassSaison.POINTS_PALIER))
end

-- Avancee dans le palier en cours : points faits, points a faire (0, 0 au sommet).
function PassSaison.progression(points)
	local p = math.max(0, math.floor(tonumber(points) or 0))
	if PassSaison.palier(p) >= PassSaison.PALIERS then
		return 0, 0
	end
	return p % PassSaison.POINTS_PALIER, PassSaison.POINTS_PALIER
end

-- Recompense du palier i sur une piste ("gratuit" | "premium").
-- { type = "pieces" | "gemmes" | "coffre", valeur = nombre ou type de coffre, texte = court }
function PassSaison.recompense(i, piste)
	if type(i) ~= "number" or i < 1 or i > PassSaison.PALIERS or i % 1 ~= 0 then
		return nil
	end
	if piste == "gratuit" then
		if i % 5 == 0 then
			return { type = "coffre", valeur = "argent", texte = "Coffre d'argent" }
		end
		local n = 20 + 10 * i
		return { type = "pieces", valeur = n, texte = n .. " pieces" }
	elseif piste == "premium" then
		if i == PassSaison.PALIERS then
			return { type = "gemmes", valeur = 150, texte = "150 gemmes" }
		elseif i % 5 == 0 then
			return { type = "coffre", valeur = "or", texte = "Coffre d'or" }
		elseif i % 2 == 0 then
			return { type = "gemmes", valeur = 15, texte = "15 gemmes" }
		end
		local n = 60 + 25 * i
		return { type = "pieces", valeur = n, texte = n .. " pieces" }
	end
	return nil
end

function PassSaison.neuf(saison)
	return { saison = saison, points = 0, reclames = { gratuit = {}, premium = {} } }
end

-- Etat a jour pour la saison `numero` : un pass d'une autre saison repart a zero.
-- Rend l'etat et true s'il vient d'etre remis a zero.
function PassSaison.aJour(etat, numero)
	if type(etat) ~= "table" or etat.saison ~= numero then
		return PassSaison.neuf(numero), true
	end
	etat.reclames = etat.reclames or { gratuit = {}, premium = {} }
	etat.reclames.gratuit = etat.reclames.gratuit or {}
	etat.reclames.premium = etat.reclames.premium or {}
	return etat, false
end

-- Peut-on reclamer le palier i sur cette piste ? Rend true, ou false + motif lisible.
-- Cles des reclames en CHAINE (tostring(i)) : un DataStore transforme un tableau troue en objet.
function PassSaison.peutReclamer(etat, i, piste, premium)
	if not PassSaison.recompense(i, piste) then
		return false, "palier inconnu"
	end
	if piste == "premium" and not premium then
		return false, "piste premium verrouillee"
	end
	if PassSaison.palier(etat.points) < i then
		return false, "palier " .. i .. " pas encore atteint"
	end
	if etat.reclames[piste][tostring(i)] then
		return false, "deja reclame"
	end
	return true
end

-- Nombre de recompenses a prendre (pastille du bouton).
function PassSaison.aPrendre(etat, premium)
	local n = 0
	for i = 1, PassSaison.palier(etat.points) do
		if not etat.reclames.gratuit[tostring(i)] then
			n = n + 1
		end
		if premium and not etat.reclames.premium[tostring(i)] then
			n = n + 1
		end
	end
	return n
end

-- ECRAN DE FIN : « +14 pass (palier 3/20) ». Chaque partie fait visiblement avancer le pass ;
-- sans cette ligne, les points ne se voyaient qu'en ouvrant l'ecran du pass.
function PassSaison.texteFin(points, palier)
	points = math.floor(tonumber(points) or 0)
	if points <= 0 then
		return nil
	end
	palier = math.floor(tonumber(palier) or 0)
	if palier >= PassSaison.PALIERS then
		return "+" .. points .. " pass (palier MAX)"
	end
	return "+" .. points .. " pass (palier " .. palier .. "/" .. PassSaison.PALIERS .. ")"
end

return PassSaison
