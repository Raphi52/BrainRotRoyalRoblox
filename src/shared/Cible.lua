-- CHOIX DE CIBLE : qui frappe-t-on, et pourquoi on ne change pas d'avis toutes les images.
--
-- Deux defauts mesures dans `findTarget` avant ce module :
--  1. AUCUNE PERSISTANCE — la cible etait recalculee a chaque image. Deux ennemis a distance
--     presque egale faisaient PAPILLONNER la tour : elle repartageait ses degats en permanence et
--     n'achevait jamais personne. C'est le pire cas pour un defenseur.
--  2. AUCUNE MENACE — seule la distance comptait. Une unite ANTI-TOURS qui fonce droit sur la tour
--     passait apres n'importe quel passant plus proche d'un demi-stud, alors que c'est elle, et
--     elle seule, qui va faire tomber la tour.
--
-- Tout se decide ici, en fonctions pures (tools/test_cibles.py) ; le serveur ne fait que fournir
-- les distances et appliquer le resultat.
local Cible = {}

-- Un ennemi qui ne vise QUE les batiments est traite comme s'il etait ce nombre de studs plus
-- proche : a distance comparable, c'est lui qu'on abat d'abord.
Cible.BONUS_ANTI_TOUR = 6
-- Marge d'hysteresis : on ne change de cible que si la nouvelle est MEILLEURE de cette marge.
-- Sans elle, deux ennemis a egalite se volent la cible a chaque image.
Cible.MARGE_CHANGEMENT = 3
-- Portee a partir de laquelle une cible compte comme un TIREUR, pour les unites qui les chassent
-- (voir Assassin.lua, qui porte la meme valeur et la carte concernee).
Cible.PORTEE_TIREUR = 5

-- PRIORITE d'une cible : plus le nombre est PETIT, plus elle passe en premier.
-- C'est une distance CORRIGEE par la menace, donc elle reste lisible en studs.
--   defenseur : { isBuilding = bool }
--   cible     : { targets = "any"|"buildings", isBuilding = bool }
function Cible.priorite(defenseur, cible, distance)
	local p = distance or 0
	if defenseur and defenseur.isBuilding then
		-- Seules les TOURS raisonnent en menace : une unite, elle, frappe ce qu'elle a devant.
		if cible and cible.targets == "buildings" and not cible.isBuilding then
			p = p - Cible.BONUS_ANTI_TOUR
		end
	elseif defenseur and (tonumber(defenseur.chasseTireurs) or 0) > 0 then
		-- ASSASSIN : il traverse le mur de melee pour aller chercher ce qui tire de loin. C'est un
		-- simple bonus de priorite, donc il herite de la persistance et de l'hysteresis ci-dessous
		-- au lieu d'ouvrir un second chemin de ciblage.
		if cible and not cible.isBuilding
			and (tonumber(cible.range) or 0) >= Cible.PORTEE_TIREUR then
			p = p - defenseur.chasseTireurs
		end
	end
	return p
end

-- Faut-il GARDER la cible actuelle ? Oui tant que la meilleure alternative n'est pas franchement
-- meilleure. `marge` permet au banc de figer la valeur sans dependre de la constante.
function Cible.garder(prioriteActuelle, prioriteMeilleure, marge)
	if prioriteActuelle == nil then
		return false
	end
	return prioriteActuelle <= (prioriteMeilleure or math.huge) + (marge or Cible.MARGE_CHANGEMENT)
end

-- Choix complet, sur une liste deja filtree (ennemis vivants et atteignables) :
--   candidats : liste de { ref = <ce que rend la fonction>, distance = n, targets = ..., isBuilding = ... }
--   actuelle  : l'element de `candidats` deja vise (ou nil)
-- Rend l'element choisi, ou nil si la liste est vide.
function Cible.choisir(defenseur, candidats, actuelle)
	local meilleur, meilleurP = nil, math.huge
	for _, c in ipairs(candidats) do
		local p = Cible.priorite(defenseur, c, c.distance)
		if p < meilleurP then
			meilleur, meilleurP = c, p
		end
	end
	if actuelle then
		local pa = Cible.priorite(defenseur, actuelle, actuelle.distance)
		if Cible.garder(pa, meilleurP) then
			return actuelle
		end
	end
	return meilleur
end

return Cible
