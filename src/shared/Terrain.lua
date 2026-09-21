-- TERRAIN : se battre CHEZ SOI vaut mieux que se battre chez l'autre.
--
-- Defaut mesure avant ce module : un echange donnait exactement le meme resultat au pied de ses
-- propres tours et au fond du camp adverse. Defendre n'etait donc jamais plus rentable
-- qu'attaquer, et la seule strategie raisonnable etait de pousser en permanence. Or le genre
-- repose sur l'alternance : on defend a moindre cout, on contre-attaque avec l'avantage.
--
-- La regle est volontairement MODESTE et defensive : une unite qui se bat dans sa moitie, a portee
-- d'une de ses tours ENCORE DEBOUT, encaisse un peu moins. Elle ne frappe pas plus fort — sinon
-- une defense bien placee deviendrait imprenable et les parties finiraient toutes a egalite.
--
-- Deux conditions, et elles comptent toutes les deux :
--   * etre dans SA moitie de l'arene (le terrain, pas la carte qu'on joue) ;
--   * avoir une tour ALLIEE VIVANTE a portee — quand la tour tombe, l'avantage tombe avec elle.
-- C'est ce qui donne a la perte d'une tour une consequence immediate et lisible.
--
-- Fonctions pures, verifiees hors Studio (tools/test_terrain.py) ; le serveur applique.
local Terrain = {}

Terrain.RAYON = 11            -- studs autour d'une tour alliee vivante
Terrain.REDUCTION = 0.15      -- 15 % de degats en moins, et pas un de plus
Terrain.REDUCTION_MAX = 0.25  -- borne dure : au-dela, la defense deviendrait imprenable

-- Suis-je dans MA moitie ? ATTENTION, la convention du jeu est l'inverse de l'intuition : le
-- camp 1 occupe les z NEGATIFS et le camp 2 les z positifs. C'est celle de `Regles.posePermise`
-- (`local s = camp == 1 and -1 or 1`), et elle est reprise telle quelle ici.
-- Erreur mesuree le 2026-09-20 : ecrit a l'envers, le banc restait vert (il testait la meme
-- convention fausse) et le moteur ne declenchait JAMAIS l'avantage — il l'aurait accorde a
-- l'attaquant. C'est le moteur, pas le banc, qui l'a montre.
function Terrain.chezSoi(camp, z)
	if camp ~= 1 and camp ~= 2 then
		return false
	end
	local s = camp == 1 and -1 or 1
	-- La RIVIERE (z = 0) n'appartient a personne : avec `>= 0`, les deux camps y etaient « chez
	-- eux » en meme temps, et deux unites face a face y auraient toutes deux ete protegees.
	return (tonumber(z) or 0) * s > 0
end

function Terrain.aPortee(dx, dz, rayon)
	local r = rayon or Terrain.RAYON
	return (dx * dx + dz * dz) <= r * r
end

-- REDUCTION appliquee a une unite. `moi` : { camp, x, z, estBatiment }.
-- `tours` : liste de { camp, x, z, vivante }.
-- Rend la part de degats EVITEE (0 = aucun avantage).
-- Non cumulative : deux tours a portee ne protegent pas deux fois.
function Terrain.reduction(moi, tours)
	if not moi or not tours then
		return 0
	end
	-- Les tours ne beneficient pas de leur propre protection : elles sont deja l'enjeu du match,
	-- les rendre plus dures a abattre allongerait toutes les parties sans rien apporter.
	if moi.estBatiment then
		return 0
	end
	if not Terrain.chezSoi(moi.camp, moi.z) then
		return 0
	end
	for _, t in ipairs(tours) do
		if t.camp == moi.camp and t.vivante ~= false then
			if Terrain.aPortee(t.x - moi.x, t.z - moi.z, Terrain.RAYON) then
				return math.clamp(Terrain.REDUCTION, 0, Terrain.REDUCTION_MAX)
			end
		end
	end
	return 0
end

-- DEGATS reellement encaisses, en nombre entier. Un coup ne tombe jamais a zero a cause du
-- terrain : une reduction qui annulerait le coup rendrait la defense invincible.
function Terrain.degatsSubis(base, reduction)
	local d = tonumber(base) or 0
	local r = math.clamp(reduction or 0, 0, Terrain.REDUCTION_MAX)
	if r <= 0 or d <= 0 then
		return d
	end
	return math.max(1, math.floor(d * (1 - r) + 0.5))
end

return Terrain
