-- TRAVERSEE : comment une unite au sol franchit la riviere par un pont.
--
-- Defaut MESURE en moteur (serie de 6 parties normales, journal du 2026-09-20) : quatre unites
-- restent BLOQUEES, et toutes les quatre au MEME endroit — `z = -4`, aux abords du pont droit
-- (x = 15 et 18, le pont etant a 17).
--
-- La cause se lit dans l'ancien code :
--     if math.abs(pos.X - bx) > 0.8 then
--         goal = Vector3.new(bx, pos.Y, sideOf(pos.Z) * 4)   -- point d'entree, SUR SA BERGE
-- Une unite MAL ALIGNEE visait un point situe sur sa PROPRE rive : tant qu'elle n'etait pas
-- alignee, son but n'avait aucune composante vers l'autre berge, donc elle ne progressait pas
-- d'un stud vers l'ennemi. Seule, elle s'alignait en une seconde et tout allait bien — mais la
-- FOULE la pousse lateralement en permanence, et la condition « mal alignee » restait alors
-- vraie indefiniment. L'unite ramait devant le pont.
--
-- Mesure de l'ancienne regle rejouee pas a pas, depart (15, -20), cible sur l'autre rive :
--     sans poussee      -> franchit en 3,5 s
--     poussee 2 studs/s -> BLOQUEE, z plafonne a -1,8 apres 25 s
--     poussee 4 studs/s -> BLOQUEE, z plafonne a -3,1
-- C'est pour cela que le defaut ne se voyait que par intermittence (4 cas sur une serie de six
-- parties) : il fallait que la foule pousse assez fort, assez longtemps.
--
-- La regle ici tient en une phrase : **le point vise n'est jamais la position courante**. Tant
-- qu'on est loin de l'eau on se dirige vers l'entree du pont ; des qu'on l'a atteinte on vise
-- l'autre rive, et l'alignement lateral se fait EN MARCHANT.
--
-- Fonctions pures, verifiees hors Studio (tools/test_traversee.py) ; le serveur applique.
local Traversee = {}

-- Distance, de part et d'autre de la riviere, a laquelle on considere qu'on est « a l'entree ».
Traversee.ENTREE = 4
-- Decalage lateral maximal d'une unite de groupe, pour que trois unites ne se superposent pas
-- sur le pont (le pont fait 4 studs de large).
Traversee.COULOIR_MAX = 1.2
Traversee.COULOIR_PART = 0.25

-- Signe de la rive : -1 pour les z negatifs, +1 pour les z positifs. Meme convention que le
-- serveur (`sideOf`).
function Traversee.rive(z)
	return ((tonumber(z) or 0) >= 0) and 1 or -1
end

-- Pont le plus proche, decale du couloir de l'unite.
function Traversee.pont(x, ponts, lane)
	local bx = nil
	for _, p in ipairs(ponts or {}) do
		if bx == nil or math.abs((x or 0) - p) < math.abs((x or 0) - bx) then
			bx = p
		end
	end
	if bx == nil then
		return nil
	end
	return bx + math.clamp((lane or 0) * Traversee.COULOIR_PART,
		-Traversee.COULOIR_MAX, Traversee.COULOIR_MAX)
end

-- POINT a viser pour franchir. Rend gx, gz.
--   x, z   : position courante
--   ponts  : liste des x des ponts
--   lane   : decalage de couloir (0 pour une unite seule)
-- Invariant garanti, et verifie au banc : le point rendu n'est JAMAIS egal a (x, z).
function Traversee.point(x, z, ponts, lane)
	local bx = Traversee.pont(x, ponts, lane)
	if bx == nil then
		return x, z -- aucun pont connu : l'appelant garde son but d'origine
	end
	local s = Traversee.rive(z)
	local entree = Traversee.ENTREE
	if math.abs(tonumber(z) or 0) > entree then
		-- Encore loin de l'eau : on se dirige vers l'entree du pont, de SON cote.
		return bx, s * entree
	end
	-- Deja dans la bande d'approche : on TRAVERSE. Viser l'autre rive garantit qu'il reste
	-- toujours du chemin a faire, meme si on est mal aligne — l'alignement se fait en marchant.
	return bx, -s * entree
end

-- Le point vise laisse-t-il vraiment du chemin ? Sert au banc a prouver l'absence de point fixe.
function Traversee.immobile(x, z, gx, gz, epsilon)
	local e = epsilon or 0.01
	local dx, dz = (gx or 0) - (x or 0), (gz or 0) - (z or 0)
	return math.sqrt(dx * dx + dz * dz) < e
end

return Traversee
