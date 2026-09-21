-- EMPLACEMENT : ou le robot pose un BATIMENT.
--
-- Defaut MESURE en moteur (melee du 2026-09-20, journal 191212Z) : sur une partie entiere,
-- `[BOT] ... raison=pose_refusee` apparait **31 fois**, et les 31 concernent la meme carte —
-- Muro Spaghetti, un batiment. Le robot lui calculait une position prevue pour des UNITES
-- (x = axe de la voie, z tire au hasard), sans jamais regarder ou se trouvent ses propres
-- batiments. La regle du jeu refuse un batiment a moins de 4 studs d'un autre (Batiments.
-- ECART_MINIMAL), donc il reproposait le meme point et se faisait refuser en boucle : environ
-- 10 % de ses decisions partaient a la poubelle, et la carte restait coincee dans sa main.
--
-- Ce module ne REDECRIT pas la regle de pose : on lui passe la fonction de validation du jeu
-- (`estPermise`). C'est ce qui garantit qu'il ne peut pas diverger de `Batiments.posePermise`.
--
-- Fonctions pures, verifiees hors Studio (tools/test_emplacement.py) ; le serveur applique.
local Emplacement = {}

-- Un batiment defensif se pose ENTRE la riviere et ses tours : assez avance pour intercepter,
-- assez en retrait pour etre couvert. Ces distances sont comptees depuis la riviere, dans la
-- moitie du camp.
Emplacement.Z_MIN = 6
Emplacement.Z_MAX = 16
-- Decalages lateraux essayes autour de la voie visee, du plus proche au plus loin : on prefere
-- rester dans la voie menacee, et on ne s'en ecarte que si la place est prise.
Emplacement.ECARTS_X = { 0, 3, -3, 6, -6, 9, -9 }
Emplacement.PAS_Z = 3

-- CANDIDATS, dans l'ordre de preference. `voieX` = axe de la voie a couvrir, `s` = signe de la
-- moitie du camp (-1 pour le camp 1, +1 pour le camp 2, meme convention que Regles.posePermise).
-- `largeurMax` borne l'arene.
function Emplacement.candidats(voieX, s, largeurMax)
	local liste = {}
	local z = Emplacement.Z_MIN
	while z <= Emplacement.Z_MAX do
		for _, dx in ipairs(Emplacement.ECARTS_X) do
			local x = (voieX or 0) + dx
			if math.abs(x) <= (largeurMax or math.huge) then
				table.insert(liste, { x = x, z = z * (s or -1) })
			end
		end
		z = z + Emplacement.PAS_Z
	end
	return liste
end

-- PREMIER candidat accepte par la regle du jeu. `estPermise(x, z)` vient de l'appelant : ce
-- module ne connait pas la regle, il ne fait que chercher.
-- Rend x, z — ou nil si AUCUNE place ne convient. Dans ce cas le serveur doit passer son tour :
-- insister sur une position refusee, c'est exactement le defaut qu'on corrige.
function Emplacement.pourBatiment(voieX, s, largeurMax, estPermise)
	if type(estPermise) ~= "function" then
		return nil
	end
	for _, c in ipairs(Emplacement.candidats(voieX, s, largeurMax)) do
		if estPermise(c.x, c.z) then
			return c.x, c.z
		end
	end
	return nil
end

return Emplacement
