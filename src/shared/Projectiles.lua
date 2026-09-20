-- PROJECTILES : un tir met du TEMPS a arriver.
--
-- Defaut mesure avant ce module : les degats d'un tireur etaient appliques a l'instant meme de
-- l'attaque, et `Effets.projectile` dessinait une boule PUREMENT decorative, apres coup. Deux
-- consequences : une unite rapide ne pouvait pas esquiver, et l'archer d'en face frappait plus
-- vite que la vitesse de sa propre fleche a l'ecran — ce que l'oeil voit comme de la triche.
--
-- Ici, le tir est un OBJET qui vole. Il part d'un point, vise le point ou etait la cible, et
-- n'applique ses degats qu'a l'arrivee. Fonctions pures (tools/test_projectiles.py).
local Projectiles = {}

Projectiles.VITESSE_DEFAUT = 40   -- studs par seconde
Projectiles.VITESSE_MIN = 12
Projectiles.DUREE_MAX = 3         -- aucun tir ne vit plus longtemps : sinon un tir perdu reste a jamais

function Projectiles.vitesse(carte)
	local v = tonumber(carte and carte.vitesseTir) or Projectiles.VITESSE_DEFAUT
	return math.max(v, Projectiles.VITESSE_MIN)
end

-- Temps de vol pour une distance donnee, borne. Un tir de melee (distance quasi nulle) arrive
-- immediatement : on ne veut pas ralentir le corps a corps.
function Projectiles.duree(carte, distance)
	local d = math.max(0, tonumber(distance) or 0)
	local t = d / Projectiles.vitesse(carte)
	if t > Projectiles.DUREE_MAX then
		return Projectiles.DUREE_MAX
	end
	return t
end

-- Position du projectile a l'instant `ecoule`. Les tirs de ZONE partent en CLOCHE : la hauteur
-- suit une parabole, ce qui les distingue a l'oeil d'un tir tendu.
function Projectiles.position(depart, arrivee, ecoule, duree, cloche)
	local d = math.max(tonumber(duree) or 0, 1e-4)
	local k = math.clamp((tonumber(ecoule) or 0) / d, 0, 1)
	local x = depart.x + (arrivee.x - depart.x) * k
	local z = depart.z + (arrivee.z - depart.z) * k
	local y = (depart.y or 0) + ((arrivee.y or 0) - (depart.y or 0)) * k
	if cloche then
		y = y + 4 * (tonumber(cloche) or 1) * k * (1 - k)
	end
	return x, y, z
end

function Projectiles.arrive(ecoule, duree)
	return (tonumber(ecoule) or 0) >= (tonumber(duree) or 0)
end

-- QUI est touche a l'arrivee ?
--  - tir de ZONE : tout ennemi dans le rayon du POINT VISE, meme si la cible d'origine est morte
--    en vol (c'est ce qui permet de viser le sol derriere un groupe) ;
--  - tir SIMPLE : la cible d'origine, et seulement si elle est encore en vie ET encore a portee
--    d'un demi-stud de marge. Sinon le tir est PERDU — c'est l'esquive.
-- `objets` : liste de { camp, x, z, vivant }. Rend la liste des index touches.
function Projectiles.touches(objets, campTireur, visee, rayon, indexCible)
	local touches = {}
	if rayon and rayon > 0 then
		for i, o in ipairs(objets or {}) do
			if o.camp ~= campTireur and o.vivant ~= false then
				local dx, dz = o.x - visee.x, o.z - visee.z
				if math.sqrt(dx * dx + dz * dz) <= rayon then
					table.insert(touches, i)
				end
			end
		end
		return touches
	end
	local c = indexCible and (objets or {})[indexCible]
	if not c or c.vivant == false then
		return touches -- la cible est morte en vol : le tir se perd
	end
	local dx, dz = c.x - visee.x, c.z - visee.z
	if math.sqrt(dx * dx + dz * dz) <= Projectiles.MARGE_ESQUIVE then
		table.insert(touches, indexCible)
	end
	return touches
end

-- Marge au-dela de laquelle une cible a ESQUIVE un tir simple : elle s'est deplacee de plus de
-- cette distance depuis le depart du tir. Assez large pour qu'un tank ne « dodge » jamais par
-- accident, assez serree pour qu'une unite tres rapide y gagne quelque chose.
Projectiles.MARGE_ESQUIVE = 4

return Projectiles
