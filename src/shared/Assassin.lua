-- ASSASSIN : une unite qui va chercher les TIREURS, pas ce qu'elle a devant elle.
--
-- Deux defauts mesures, et ils se repondent :
--  1. AUDIT DU CATALOGUE (tools/audit_identite.py) : sur 47 cartes, Cappuccino Assassino etait
--     l'une des deux seules sans AUCUNE particularite. Sa description promet « assassin ultra
--     rapide » ; le jeu ne tenait que la moitie de la promesse — elle etait juste rapide, et elle
--     tapait le premier venu comme tout le monde.
--  2. Rien ne contrait specifiquement un TIREUR bien protege. Une unite a distance placee derriere
--     un mur de melee etait intouchable : les attaquants s'arretaient sur le mur, exactement comme
--     elle le voulait. Il manquait la carte qui passe DERRIERE.
--
-- La regle n'est pas un chemin de ciblage parallele : c'est un BONUS DE PRIORITE, exactement comme
-- la menace anti-tour d'une tour (Cible.BONUS_ANTI_TOUR). Elle profite donc de toute la machinerie
-- deja verifiee : persistance de la cible, hysteresis, pas de papillonnage.
--
-- Fonctions pures, verifiees hors Studio (tools/test_assassin.py) ; le serveur applique.
local Assassin = {}

-- bonus : de combien de studs le tireur ennemi est traite comme « plus proche ». Il doit etre
-- assez grand pour passer devant un mur de melee colle a l'assassin, sans etre si grand que
-- l'assassin traverse toute l'arene en ignorant ce qui le tue.
Assassin.PROFILS = {
	Cappuccino = { bonus = 9 },
}

Assassin.BONUS_MAX = 12
-- Une cible compte comme TIREUR a partir de cette portee. Le corps a corps du jeu est a 3 a 3,5
-- studs ; au-dela, l'unite frappe sans s'exposer, et c'est precisement ce qu'on veut punir.
Assassin.PORTEE_TIREUR = 5

-- COHERENCE d'un assassin, verifiee au banc contre le catalogue. Sa carte promet « ultra
-- rapide » : trois exigences, toutes tirees de ce que le mot veut dire au combat.
--   * il frappe AU CONTACT (portee < PORTEE_TIREUR) : un assassin qui tirerait de loin n'aurait
--     aucune raison de contourner un mur, il tirerait par-dessus ;
--   * il est RAPIDE — au moins VITESSE_MIN. Sans vitesse, il meurt en chemin : le bonus de
--     priorite l'envoie traverser la ligne ennemie, c'est sa vitesse qui l'y fait survivre ;
--   * il est FRAGILE (pv <= PV_MAX). C'est le contrat de la carte : elle passe derriere et tue un
--     tireur, mais elle ne survit pas a son erreur. Un colosse avec ce bonus serait imparable.
-- Rend : ok, raison (raison = nil quand c'est coherent).
Assassin.VITESSE_MIN = 14
Assassin.PV_MAX = 600

function Assassin.coherente(id, carte)
	if not Assassin.estAssassin(id) or carte == nil then
		return true, nil
	end
	if (tonumber(carte.range) or 0) >= Assassin.PORTEE_TIREUR then
		return false, "il tire de loin : il n'a aucune raison de contourner un mur"
	end
	if (tonumber(carte.speed) or 0) < Assassin.VITESSE_MIN then
		return false, "trop lent : il mourra en chemin"
	end
	if (tonumber(carte.hp) or 0) > Assassin.PV_MAX then
		return false, "trop resistant : un assassin doit payer son erreur"
	end
	return true, nil
end

function Assassin.profil(id)
	local p = Assassin.PROFILS[id]
	if not p then
		return nil
	end
	return { bonus = math.clamp(p.bonus or 0, 0, Assassin.BONUS_MAX) }
end

function Assassin.estAssassin(id)
	return Assassin.PROFILS[id] ~= nil
end

-- Cette cible est-elle un tireur ? Un BATIMENT n'en est jamais un, meme avec une grande portee :
-- une tour est l'enjeu du match, pas une proie d'assassin — sinon l'assassin foncerait sur les
-- tours et ne serait qu'une carte anti-tours de plus.
function Assassin.estTireur(cible)
	if not cible or cible.isBuilding then
		return false
	end
	return (tonumber(cible.range) or 0) >= Assassin.PORTEE_TIREUR
end

-- BONUS de priorite applique par le defenseur `moi` contre la cible donnee. 0 = aucun changement.
function Assassin.bonus(moi, cible)
	if not moi or not moi.chasseTireurs or (tonumber(moi.chasseTireurs) or 0) <= 0 then
		return 0
	end
	if not Assassin.estTireur(cible) then
		return 0
	end
	return math.clamp(moi.chasseTireurs, 0, Assassin.BONUS_MAX)
end

return Assassin
