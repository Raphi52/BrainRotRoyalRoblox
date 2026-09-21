-- DEFENSE : ne repondre qu'a ce qui n'est pas DEJA couvert.
--
-- Defaut MESURE le 2026-09-21, duel normal contre expert, 60 parties (alternance des cotes
-- reparee) : l'expert ne gagnait que 40 %. La cause se lisait dans deux colonnes :
--     normal :  3,8 defenses par attaque, elixir median a la pose 6,0
--     expert :  9,0 defenses par attaque, elixir median a la pose 4,1, et 139 attaques contre 289
-- Le code decidait « defendre » des qu'une menace existait (`elseif enDanger then`), SANS regarder
-- ce qui la couvrait deja. Tant que l'unite ennemie vivait dans sa moitie, CHAQUE cycle de
-- reflexion reposait une carte. L'expert reflechit deux fois plus vite que le normal : il posait
-- donc deux fois plus de defenses contre la meme menace, vidait son elixir, et n'attaquait plus.
-- Sa qualite (la vitesse) devenait son defaut.
--
-- La regle ici tient en une phrase : **on ne defend pas une menace que ses propres unites
-- tiennent deja**. La force engagee se compte en points de vie, comme la menace elle-meme (c'est
-- deja l'unite que le serveur utilise pour la mesurer) : c'est une approximation, mais c'est la
-- MEME des deux cotes de la comparaison.
--
-- Une defense qui vient d'etre posee compte aussi, meme si elle n'est pas encore arrivee : sans
-- cela, le robot reposerait pendant qu'elle marche vers la menace — exactement le defaut corrige.
--
-- Fonctions pures, verifiees hors Studio (tools/test_defense.py) ; le serveur applique.
local Defense = {}

-- Part de la menace que ses defenseurs doivent egaler pour qu'elle soit « couverte ».
-- 1,0 = autant de points de vie engages que la menace. En dessous, la defense se ferait deborder.
Defense.COUVERTURE = 1.0
Defense.COUVERTURE_MIN = 0.5 -- borne basse : sous la moitie, ce n'est plus couvrir, c'est esperer
Defense.COUVERTURE_MAX = 2.0 -- borne haute : au-dela, le robot sur-defendrait de nouveau

-- La menace est-elle deja tenue par ce qui est engage contre elle ?
--   menace     : points de vie ennemis dans la voie menacee, dans sa moitie
--   engages    : points de vie de SES unites dans cette meme voie (y compris celles qui arrivent)
--   couverture : exigence (Defense.COUVERTURE par defaut)
-- Une menace nulle est toujours couverte : il n'y a rien a repondre.
function Defense.couverte(menace, engages, couverture)
	local m = tonumber(menace) or 0
	if m <= 0 then
		return true
	end
	local c = math.clamp(tonumber(couverture) or Defense.COUVERTURE,
		Defense.COUVERTURE_MIN, Defense.COUVERTURE_MAX)
	return (tonumber(engages) or 0) >= m * c
end

-- Faut-il reposer une defense ? C'est le contraire de « couverte », avec une nuance : sans menace,
-- on ne defend jamais — la fonction ne doit pas servir d'excuse pour poser n'importe quand.
function Defense.doitRepondre(menace, engages, couverture)
	if (tonumber(menace) or 0) <= 0 then
		return false
	end
	return not Defense.couverte(menace, engages, couverture)
end

-- Combien manque-t-il pour couvrir la menace ? Sert au journal : « il manque 400 PV » est lisible.
function Defense.manque(menace, engages, couverture)
	local m = tonumber(menace) or 0
	local c = math.clamp(tonumber(couverture) or Defense.COUVERTURE,
		Defense.COUVERTURE_MIN, Defense.COUVERTURE_MAX)
	return math.max(0, m * c - (tonumber(engages) or 0))
end

return Defense
