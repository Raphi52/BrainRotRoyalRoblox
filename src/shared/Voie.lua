-- VOIE : par quel cote le robot attaque, et quel cote il defend.
--
-- Defaut MESURE puis confirme dans le code. Sur une melee complete (journal du 2026-09-20),
-- `raison=defense_voie1` apparait **123 fois** contre **10** pour la voie 2. Un robot qui defend
-- douze fois plus un cote que l'autre n'est pas un adversaire : il est previsible, et la moitie
-- de l'arene ne sert plus a rien.
--
-- La cause tient en un signe. Le robot visait « la tour adverse la plus faible » :
--     if tw.hp < pvMin then faible = tw end
-- La comparaison est STRICTE. Or au debut d'une partie les deux tours de princesse ont
-- EXACTEMENT les memes points de vie : la premiere de la liste gagne donc toujours, et c'est
-- toujours la meme (celle posee en premier). Les deux robots attaquaient ainsi le meme cote,
-- et defendaient par consequent le meme cote. Meme piege pour la voie menacee :
--     voieMenace = menace[1] >= menace[2] and 1 or 2
-- qui rend 1 des que les deux menaces sont egales — y compris quand elles valent zero.
--
-- La correction n'est pas de « mettre du hasard partout » : une egalite doit se departager, une
-- difference doit etre respectee. C'est exactement ce que ce module garantit, et le banc le
-- verifie dans les deux sens.
--
-- Fonctions pures, verifiees hors Studio (tools/test_voie.py) ; le serveur applique.
local Voie = {}

Voie.GAUCHE, Voie.DROITE = 1, 2

-- Ecart de points de vie en dessous duquel deux tours sont considerees comme EQUIVALENTES. Sans
-- cette tolerance, un seul point de degat sur une tour suffirait a rendre le robot previsible a
-- nouveau — il faut une vraie difference pour qu'il choisisse vraiment.
Voie.EGALITE_PV = 150

-- VOIE de la tour adverse la plus faible.
--   tours  : liste de { x, pv, vivante, roi }
--   tirage : nombre entre 0 et 1 fourni par l'appelant (le serveur passe math.random()), utilise
--            UNIQUEMENT pour departager une egalite. La fonction reste pure et rejouable.
-- Rend Voie.GAUCHE ou Voie.DROITE, ou nil si aucune tour de princesse n'est debout.
function Voie.tourLaPlusFaible(tours, tirage)
	local meilleures, pvMin = {}, math.huge
	for _, t in ipairs(tours or {}) do
		if t.vivante ~= false and not t.roi then
			local pv = tonumber(t.pv) or 0
			if pv < pvMin - Voie.EGALITE_PV then
				meilleures, pvMin = { t }, pv
			elseif pv <= pvMin + Voie.EGALITE_PV then
				table.insert(meilleures, t)
				if pv < pvMin then
					pvMin = pv
				end
			end
		end
	end
	if #meilleures == 0 then
		return nil
	end
	local choisie = meilleures[1]
	if #meilleures > 1 then
		local k = math.floor((tonumber(tirage) or 0) * #meilleures) + 1
		if k > #meilleures then
			k = #meilleures
		end
		choisie = meilleures[k]
	end
	return (choisie.x or 0) < 0 and Voie.GAUCHE or Voie.DROITE
end

-- VOIE la plus menacee. `gauche` et `droite` : points de vie ennemis presents dans chaque voie.
-- A egalite STRICTE (y compris zero contre zero), on departage par le tirage : sinon le robot
-- regarde toujours du meme cote quand il ne se passe rien, et il y pose ses defenses.
function Voie.menacee(gauche, droite, tirage)
	local g, d = tonumber(gauche) or 0, tonumber(droite) or 0
	if g > d then
		return Voie.GAUCHE
	elseif d > g then
		return Voie.DROITE
	end
	return ((tonumber(tirage) or 0) < 0.5) and Voie.GAUCHE or Voie.DROITE
end

-- Axe x correspondant a une voie, pour une largeur de voie donnee.
function Voie.axe(voie, voieX)
	return voie == Voie.DROITE and (voieX or 0) or -(voieX or 0)
end

return Voie
