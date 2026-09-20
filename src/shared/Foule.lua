-- FOULE : les unites s'encombrent au lieu de se traverser.
--
-- Pourquoi : jusqu'ici deux unites pouvaient occuper EXACTEMENT le meme point. Un groupe de trois
-- se fondait en une seule silhouette, un tank et un assassin se superposaient, et « faire barrage »
-- — la defense de base du genre — ne voulait rien dire puisque rien ne bloquait rien.
--
-- Le choix : PAS de physique Roblox (tout est ancre et deplace a la main, y toucher casserait
-- l'animation et la replication). On calcule une POUSSEE de separation, ici, en fonctions pures,
-- donc verifiables hors Studio (tools/test_foule.py).
local Foule = {}

-- Encombrement au sol d'une carte, en studs. On prend la plus grande dimension horizontale : le
-- cube de contact est deja la boite de l'unite cote serveur.
function Foule.rayon(card)
	local t = card and card.size
	if not t then
		return 1
	end
	return math.max(t.X or 2, t.Z or 2) / 2
end

-- Vitesse maximale de la poussee, en studs par seconde. Bornee pour deux raisons mesurables :
-- une poussee non bornee TELEPORTE une unite coincee entre deux autres, et deux unites posees au
-- meme point partiraient a l'infini.
Foule.POUSSEE_MAX = 6
-- Un chevauchement plus petit que ceci est ignore : sinon les unites tremblent en permanence.
Foule.JEU = 0.05

-- Deux unites s'encombrent-elles ? Un volant passe AU-DESSUS du sol : il ne gene que les volants.
-- Un batiment (tour) encombre tout le monde, mais ne bouge pas.
function Foule.seGenent(a, b)
	if a.batiment and b.batiment then
		return false -- deux tours ne se poussent pas
	end
	local aVole, bVole = a.flying == true, b.flying == true
	if a.batiment or b.batiment then
		-- une tour ne gene pas un volant : il lui passe au-dessus
		if (a.batiment and bVole) or (b.batiment and aVole) then
			return false
		end
		return true
	end
	return aVole == bVole
end

-- POUSSEE subie par `moi` du fait de `voisins`, pendant `dt` secondes.
-- Chaque voisin qui chevauche pousse le long de l'axe qui les separe, d'autant plus fort que le
-- chevauchement est grand. Rend (dx, dz) en STUDS, deja bornes.
--   moi     : { x, z, rayon, flying, batiment, id }
--   voisins : liste de la meme forme (moi peut y figurer : on s'ignore par `id`)
-- Un batiment ne bouge jamais : on rend 0, 0.
function Foule.poussee(moi, voisins, dt)
	if moi.batiment then
		return 0, 0
	end
	local px, pz = 0, 0
	for _, v in ipairs(voisins) do
		if v.id ~= moi.id and Foule.seGenent(moi, v) then
			local dx, dz = moi.x - v.x, moi.z - v.z
			local d = math.sqrt(dx * dx + dz * dz)
			local mini = (moi.rayon or 1) + (v.rayon or 1)
			if d < mini - Foule.JEU then
				local chevauchement = mini - d
				if d < 1e-4 then
					-- EXACTEMENT au meme point : la direction est indefinie. On depart l'egalite
					-- avec les identifiants, sinon les deux unites tremblent au lieu de se separer.
					local sens = (moi.id or 0) < (v.id or 0) and -1 or 1
					dx, dz, d = sens, 0, 1
				end
				-- une TOUR ne recule pas : celui qui la touche encaisse toute la separation
				local part = v.batiment and 1 or 0.5
				px = px + (dx / d) * chevauchement * part
				pz = pz + (dz / d) * chevauchement * part
			end
		end
	end
	-- Borne : la poussee ne depasse jamais POUSSEE_MAX studs par seconde.
	local norme = math.sqrt(px * px + pz * pz)
	if norme < 1e-6 then
		return 0, 0
	end
	local plafond = Foule.POUSSEE_MAX * (dt or 0)
	if norme > plafond then
		px, pz = px / norme * plafond, pz / norme * plafond
	end
	return px, pz
end

-- L'unite AVANCE-t-elle encore ? Une unite dont le chemin est bouche par un allie tres proche
-- ralentit au lieu de pousser indefiniment : c'est ce qui donne l'impression d'une file qui avance.
-- Rend un facteur de vitesse entre 0,35 et 1.
function Foule.freinage(chevauchementTotal, rayon)
	if not chevauchementTotal or chevauchementTotal <= 0 then
		return 1
	end
	local k = math.min(chevauchementTotal / math.max(rayon or 1, 0.1), 1)
	return 1 - 0.65 * k
end

-- Chevauchement TOTAL avec les voisins (sert au freinage ci-dessus).
function Foule.chevauchement(moi, voisins)
	local total = 0
	for _, v in ipairs(voisins) do
		if v.id ~= moi.id and Foule.seGenent(moi, v) then
			local dx, dz = moi.x - v.x, moi.z - v.z
			local d = math.sqrt(dx * dx + dz * dz)
			local mini = (moi.rayon or 1) + (v.rayon or 1)
			if d < mini then
				total = total + (mini - d)
			end
		end
	end
	return total
end

return Foule
