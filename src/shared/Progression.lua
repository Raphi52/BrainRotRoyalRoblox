-- COMBIEN DE VICTOIRES AVANT L'ARENE SUIVANTE, en fonctions PURES.
--
-- Defaut mesure le 2026-09-21 : l'accueil disait « Plage Tralalero dans 200 trophees ». Un nombre
-- de trophees ne dit pas combien de PARTIES il faut gagner — et depuis la regle posee le meme jour
-- dans Arenes (une victoire contre le robot ne rapporte que le TIERS), la reponse a triple selon
-- l'adversaire : 7 victoires contre des joueurs, 20 contre le robot. Le joueur ne le voyait pas.
--
-- Les deux reglages (gain d'une victoire, part contre le robot) sont LUS dans Arenes par l'ecran et
-- passes ici : ce module ne les recopie pas, il fait la division.
-- Approximation assumee et dite (« ~ ») : contre un joueur, l'enjeu varie avec l'ecart de trophees
-- (Arenes.facteur) ; on compte ici a enjeu de base, celui d'un adversaire de meme niveau.
local Progression = {}

-- Victoires necessaires pour combler `manque` trophees, a `gain` par victoire. Jamais 0 tant qu'il
-- manque quelque chose : un seul trophee manquant demande encore une victoire.
function Progression.victoires(manque, gain)
	local m = tonumber(manque) or 0
	local g = tonumber(gain) or 0
	if m <= 0 then
		return 0
	end
	if g <= 0 then
		return nil -- aucun gain : on ne promet pas un nombre infini
	end
	return math.ceil(m / g)
end

-- LA LIGNE AFFICHEE. `partRobot` : part des trophees contre le robot (1/3). Sans elle, on ne parle
-- que des joueurs. Rend « derniere arene » quand il n'y a plus rien a atteindre.
function Progression.texte(nomSuivante, manque, gain, partRobot)
	if not nomSuivante then
		return "derniere arene"
	end
	local m = math.max(0, math.floor(tonumber(manque) or 0))
	local base = nomSuivante .. " dans " .. m .. " trophees"
	local vJ = Progression.victoires(m, gain)
	if not vJ or vJ == 0 then
		return base
	end
	local mot = vJ > 1 and " victoires" or " victoire"
	local p = tonumber(partRobot)
	if p and p > 0 and p < 1 then
		local vR = Progression.victoires(m, (tonumber(gain) or 0) * p)
		if vR and vR ~= vJ then
			return base .. " (~" .. vJ .. mot .. ", " .. vR .. " contre le robot)"
		end
	end
	return base .. " (~" .. vJ .. mot .. ")"
end

return Progression
