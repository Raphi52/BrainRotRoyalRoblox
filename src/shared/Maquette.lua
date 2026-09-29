-- L'ILE MAQUETTE : tout ce qui entoure le terrain, decrit en fonctions PURES.
--
-- Le defaut corrige (captures du 2026-09-21, relues le 2026-09-29 face aux jeux Roblox les mieux
-- notes et a Clash Royale) : autour du terrain, un plan d'herbe uni et 26 arbres « sucette » (une
-- boule sur un baton) semes au hasard. L'arene FLOTTAIT dans le vide, et le sol n'etait que deux
-- dalles d'une seule couleur. Clash Royale pose son terrain comme une MAQUETTE : un plateau borde
-- de falaises, de l'eau tout autour, un sol en damier qui donne l'echelle, un decor dense qui
-- cadre l'image.
--
-- CE MODULE NE DECRIT QUE CE QUI SE REGARDE. Il rend une liste de pieces (nom, forme, taille,
-- position, rotation, couleur, matiere) que le serveur pose TOUTES en decor : non collisionnables
-- et invisibles aux clics (CanQuery = false, donc ignorees par le rayon de pose du client). Il ne
-- touche a AUCUNE piece qui porte une regle : GroundPlayer, GroundEnemy, River, Bridge et
-- DeployZone restent poses par buildArena, a la meme taille et au meme endroit. Le banc
-- tools/test_maquette.py le fait respecter :
--   * aucune piece ne mord sur le terrain, sauf le damier (0,03 stud pose SUR l'herbe), les traces
--     qui y etaient deja (allees, rambardes, berges, gardees a l'identique) et ce qui reste cache
--     SOUS l'herbe ;
--   * la geometrie de l'ile est la MEME pour tous les themes : seules couleurs et matieres changent ;
--   * l'ile est symetrique par DEMI-TOUR : les deux joueurs voient exactement le meme paysage.
local Maquette = {}

Maquette.DALLE = 4 -- cote d'une case du damier : 16 cases sur la largeur (Clash Royale en a 18)
-- Epaisseur du damier. Il est pose SUR l'herbe (dessus a 0,5) : a 0,03, son dessus reste sous
-- celui des allees (0,56) et de la zone de pose (0,555), et au-dessus de l'herbe — trois
-- surfaces espacees, donc pas de scintillement entre elles.
Maquette.DALLE_EPAISSEUR = 0.03
Maquette.MARGE_COTE = 16 -- herbe entre le muret lateral et le bord de la falaise
Maquette.MARGE_BOUT = 14 -- herbe derriere les tours du roi
Maquette.SOL_Y = 0.1 -- dessus du plateau (l'herbe du terrain, elle, affleure a 0,5)
Maquette.MER_Y = -9 -- surface de l'eau au pied des falaises
-- PLAFOND DE PIECES. L'arene est reconstruite a CHAQUE duel et doit tourner sur mobile : le
-- banc refuse une ile qui depasserait ce compte.
Maquette.MAX_PIECES = 1000
Maquette.LIQUIDES = { eau = true, lave = true }

local NOIR, BLANC = { 0, 0, 0 }, { 255, 255, 255 }
local LUEUR = { 255, 210, 110 } -- croute incandescente de la lave

local function melange(a, b, t)
	return {
		math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
		math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
		math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
	}
end
Maquette.melange = melange

-- HASARD REPRODUCTIBLE, identique en Luau et au banc : Park-Miller (16807 modulo 2^31 - 1). Le
-- produit reste sous 2^53, donc aucun arrondi de flottant ne fait diverger le serveur du banc.
-- Le decor est donc le MEME a chaque partie, et le meme pour les deux joueurs.
local function generateur(graine)
	local etat = (graine % 2147483646) + 1
	return function(a, b)
		etat = (etat * 16807) % 2147483647
		return a + (b - a) * ((etat - 1) / 2147483646)
	end
end

local function poser(liste, nom, forme, taille, pos, couleur, matiere, role, extra)
	local p = {
		nom = nom, forme = forme, taille = taille, pos = pos, rot = { 0, 0, 0 },
		couleur = couleur, matiere = matiere, transparence = 0, reflet = 0, ombre = true, role = role,
	}
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	liste[#liste + 1] = p
	return p
end

-- DEMI-TOUR autour de l'axe vertical : (x, z) -> (-x, -z). CFrame.Angles applique Z, puis Y, puis
-- X, donc Ry(180) * Rx(a) * Ry(b) * Rz(c) = Rx(-a) * Ry(b + 180) * Rz(c).
local function demiTour(p)
	local q = {}
	for k, v in pairs(p) do
		q[k] = v
	end
	q.pos = { -p.pos[1], p.pos[2], -p.pos[3] }
	q.rot = { -p.rot[1], p.rot[2] + 180, p.rot[3] }
	return q
end

-- Apparence du liquide selon le theme. Seule la MATIERE change : la lave du volcan n'est pas une
-- autre geometrie, c'est une autre surface.
local function aspectLiquide(theme)
	local eau = theme.eau
	if theme.liquide == "lave" then
		return {
			surface = { couleur = eau, matiere = "CrackedLava", transparence = 0, reflet = 0 },
			chute = { couleur = melange(eau, LUEUR, 0.3), matiere = "Glass", transparence = 0.15 },
			remous = { couleur = melange(eau, LUEUR, 0.6), matiere = "Neon", transparence = 0.15 },
			liseret = { couleur = melange(eau, LUEUR, 0.45), matiere = "SmoothPlastic", transparence = 0.35 },
		}
	end
	return {
		surface = { couleur = eau, matiere = "Glass", transparence = 0.25, reflet = 0.08 },
		chute = { couleur = melange(eau, BLANC, 0.25), matiere = "Glass", transparence = 0.15 },
		remous = { couleur = melange(eau, BLANC, 0.8), matiere = "SmoothPlastic", transparence = 0.3 },
		liseret = { couleur = melange(eau, BLANC, 0.75), matiere = "SmoothPlastic", transparence = 0.5 },
	}
end

-- LE DAMIER : une case sur deux, un ton plus sombre, posee sur l'herbe du terrain. Il donne
-- l'echelle au premier coup d'oeil (combien de cases jusqu'au pont ?) sans rien changer au sol
-- qui porte les regles. La bande de la riviere n'en recoit pas : les cases s'arretent a la berge.
local function damier(liste, dim, theme)
	local T, e = Maquette.DALLE, Maquette.DALLE_EPAISSEUR
	local W, L = dim.demiLargeur, dim.demiLongueur
	local berge = dim.demiRiviere + 0.5 -- les berges (z = +/- 2,2, epaisseur 0,6) finissent la
	local fonce = { melange(theme.herbeProche, NOIR, 0.085), melange(theme.herbeLoin, NOIR, 0.085) }
	local i = 0
	local x0 = -W
	while x0 < W - 1e-6 do
		local x1 = math.min(x0 + T, W)
		local j = 0
		local z0 = -L
		while z0 < L - 1e-6 do
			local z1 = math.min(z0 + T, L)
			if (i + j) % 2 == 0 then
				local a, b = z0, z1
				if b > -berge and a < berge then
					if a < -berge then
						b = -berge
					elseif b > berge then
						a = berge
					else
						a = nil -- case entierement dans la riviere
					end
				end
				if a then
					local cz = (a + b) / 2
					-- SOUS UNE ALLEE, LA CASE EST COUPEE. Les deux surfaces n'etaient qu'a 0,03 stud
					-- l'une de l'autre : vue de 120 studs, la carte graphique ne sait plus laquelle
					-- est devant, et l'allee scintillait en pointilles (apercu du 2026-09-29).
					local morceaux = { { x0, x1 } }
					for _, bx in ipairs(dim.voies) do
						local g, d = bx - 1.6, bx + 1.6 -- l'allee fait 3,2 de large (traces)
						local suite = {}
						for _, m in ipairs(morceaux) do
							if m[2] <= g or m[1] >= d then
								suite[#suite + 1] = m
							else
								if m[1] < g then
									suite[#suite + 1] = { m[1], g }
								end
								if m[2] > d then
									suite[#suite + 1] = { d, m[2] }
								end
							end
						end
						morceaux = suite
					end
					for _, m in ipairs(morceaux) do
						poser(liste, "Dalle", "Block", { m[2] - m[1], e, b - a }, { (m[1] + m[2]) / 2, dim.dessus + e / 2, cz },
							fonce[cz < 0 and 1 or 2], "Grass", "damier", { ombre = false })
					end
				end
			end
			z0 = z1
			j = j + 1
		end
		x0 = x1
		i = i + 1
	end
end

-- LES TRACES DEJA PRESENTES SUR LE TERRAIN (allees vers les ponts, rambardes, berges) : reprises
-- a l'identique de l'ancien decor. Le banc verifie qu'elles n'ont pas bouge.
local function traces(liste, dim, theme)
	local W, L = dim.demiLargeur, dim.demiLongueur
	for _, bx in ipairs(dim.voies) do
		poser(liste, "Allee", "Block", { 3.2, 0.06, L * 2 - 4 }, { bx, 0.53, 0 }, theme.allee, "Ground", "trace", { ombre = false })
		for _, s in ipairs({ -1, 1 }) do
			poser(liste, "Rambarde", "Block", { 0.4, 1, 6 }, { bx + s * 2.1, 1.1, 0 }, theme.bois, "Wood", "trace")
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		poser(liste, "Berge", "Block", { W * 2, 0.7, 0.6 }, { 0, 0.55, s * 2.2 }, theme.pierre, "Slate", "trace")
	end
end

-- L'ENCEINTE : le muret de pierre autour du terrain, OUVERT sur les cotes la ou la riviere file
-- vers la cascade, et des piliers aux coins et aux sorties d'eau. Tout est pose A L'EXTERIEUR de
-- la ligne du terrain.
local function enceinte(liste, dim, theme)
	local W, L = dim.demiLargeur, dim.demiLongueur
	local pierre = theme.pierre
	local passe = dim.demiRiviere + 0.5
	for _, s in ipairs({ -1, 1 }) do
		poser(liste, "Muret", "Block", { W * 2 + 3, 1.6, 1.5 }, { 0, 0.8, s * (L + 0.75) }, pierre, "Cobblestone", "bord")
	end
	local long = (L + 1.5) - passe
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			poser(liste, "Muret", "Block", { 1.5, 1.6, long }, { sx * (W + 0.75), 0.8, sz * (passe + long / 2) }, pierre, "Cobblestone", "bord")
		end
	end
	local corps, sommet = melange(pierre, NOIR, 0.12), melange(pierre, BLANC, 0.18)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- { cote, centre x, centre z } : le chapiteau (cote + 0,4) affleure la ligne du terrain
			for _, c in ipairs({ { 2.6, "coin" }, { 1.9, "passe" } }) do
				local t = c[1]
				local demi = (t + 0.4) / 2
				local cz = (c[2] == "coin") and (L + demi) or (passe + demi)
				local pos = { sx * (W + demi), t / 2, sz * cz }
				poser(liste, "Pilier", "Block", { t, t, t }, pos, corps, "Cobblestone", "bord")
				poser(liste, "Chapiteau", "Block", { t + 0.4, 0.45, t + 0.4 }, { pos[1], t + 0.2, pos[3] }, sommet, "Slate", "bord")
			end
		end
	end
end

-- LE PLATEAU ET LA MER. Le plateau est une dalle d'herbe (son bord vert fait la levre de la
-- falaise), posee sur un socle de roche ; la mer l'entoure a perte de vue, avec un haut-fond clair
-- au pied des falaises et un liseret d'ecume.
local function plateauEtMer(liste, dim, theme, liq)
	local W, L = dim.demiLargeur, dim.demiLongueur
	local PX, PZ = W + Maquette.MARGE_COTE, L + Maquette.MARGE_BOUT
	local SOL, MER = Maquette.SOL_Y, Maquette.MER_Y
	poser(liste, "Plateau", "Block", { 2 * PX, 1, 2 * PZ }, { 0, SOL - 0.5, 0 }, theme.exterieur, "Grass", "nature", { ombre = false })
	local haut, bas = SOL - 1, MER - 3
	poser(liste, "Socle", "Block", { 2 * PX - 1.2, haut - bas, 2 * PZ - 1.2 }, { 0, (haut + bas) / 2, 0 },
		melange(theme.rocher, NOIR, 0.25), "Slate", "nature", { ombre = false })
	local s = liq.surface
	poser(liste, "Mer", "Block", { 900, 1, 900 }, { 0, MER - 0.5, 0 }, s.couleur, s.matiere, "eau",
		{ transparence = s.transparence, reflet = s.reflet, ombre = false })
	poser(liste, "Fond", "Block", { 900, 1, 900 }, { 0, MER - 4.5, 0 }, melange(theme.eau, NOIR, 0.55), "SmoothPlastic", "eau", { ombre = false })
	poser(liste, "HautFond", "Block", { 2 * PX + 22, 1, 2 * PZ + 22 }, { 0, MER - 1.9, 0 },
		melange(melange(theme.eau, theme.allee, 0.5), BLANC, 0.1), "SmoothPlastic", "eau", { ombre = false })
	-- liseret d'ecume, en quatre bandes qui ne se recouvrent pas (sinon les coins seraient plus opaques)
	local e1, e2 = 1.7, 4.7
	local l = liq.liseret
	local opts = { transparence = l.transparence, ombre = false }
	for _, sg in ipairs({ -1, 1 }) do
		poser(liste, "Liseret", "Block", { 2 * (PX + e2), 0.1, e2 - e1 }, { 0, MER + 0.05, sg * (PZ + (e1 + e2) / 2) }, l.couleur, l.matiere, "eau", opts)
		poser(liste, "Liseret", "Block", { e2 - e1, 0.1, 2 * (PZ + e1) }, { sg * (PX + (e1 + e2) / 2), MER + 0.05, 0 }, l.couleur, l.matiere, "eau", opts)
	end
end

-- LA CASCADE (un cote ; le demi-tour pose l'autre) : la riviere sort du terrain par l'ouverture du
-- muret, suit un canal borde de pierre jusqu'au bord du plateau, et tombe dans la mer.
local function cascade(moitie, dim, theme, liq)
	local W = dim.demiLargeur
	local PX = W + Maquette.MARGE_COTE
	local r = dim.demiRiviere
	local long = PX - W
	-- Meme eau que la riviere du terrain (Glass, transparence 0,2) : le canal la PROLONGE.
	poser(moitie, "Canal", "Block", { long, 1.1, 2 * r }, { W + long / 2, 0.05, 0 }, theme.eau, "Glass", "eau", { transparence = 0.2 })
	for _, s in ipairs({ -1, 1 }) do
		poser(moitie, "Quai", "Block", { long, 0.7, 0.6 }, { W + long / 2, 0.55, s * (r + 0.2) }, theme.pierre, "Slate", "bord")
	end
	local haut, MER = 0.6, Maquette.MER_Y
	local c = liq.chute
	poser(moitie, "Cascade", "Block", { 1.2, haut - MER, 2 * r - 0.4 }, { PX + 0.6, (haut + MER) / 2, 0 }, c.couleur, c.matiere, "eau",
		{ transparence = c.transparence, ombre = false })
	local m = liq.remous
	for k = -1, 1 do
		local t = 3.2 - math.abs(k) * 0.7
		poser(moitie, "Remous", "Ball", { t, t, t }, { PX + 2 + math.abs(k) * 0.4, MER + 0.2, k * 1.3 }, m.couleur, m.matiere, "eau",
			{ transparence = m.transparence, ombre = false })
	end
end

-- LES FALAISES (une moitie du pourtour ; le demi-tour pose l'autre) : des blocs de roche serres,
-- un peu tournes et de hauteurs inegales, a moitie enfonces dans le plateau. Des recifs au ras de
-- l'eau cassent la ligne du pied. Une encoche reste libre devant chaque cascade.
local function falaises(moitie, dim, theme, alea)
	local W, L = dim.demiLargeur, dim.demiLongueur
	local PX, PZ = W + Maquette.MARGE_COTE, L + Maquette.MARGE_BOUT
	local SOL, MER = Maquette.SOL_Y, Maquette.MER_Y
	local bas = MER - 1.5
	local encoche = dim.demiRiviere + 0.2
	local function bloc(x, z, nx, nz, largeur)
		local d = alea(3, 5)
		local haut = SOL + alea(-0.9, 0.35)
		local sortie = d / 2 - alea(0.6, 1.4)
		local sx, sz = largeur, d
		if nx ~= 0 then
			sx, sz = d, largeur
		end
		local teinte = melange(melange(theme.rocher, theme.pierre, alea(0, 0.5)), NOIR, alea(0, 0.18))
		local matiere = (alea(0, 1) < 0.5) and "Rock" or "Slate"
		local p = poser(moitie, "Falaise", "Block", { sx, haut - bas, sz }, { x + nx * sortie, (haut + bas) / 2, z + nz * sortie }, teinte, matiere, "nature")
		p.rot = { alea(-3, 3), alea(-7, 7), alea(-3, 3) }
		local recif = alea(0, 1) < 0.45
		local t = { alea(2.5, 4.5), alea(2, 3.5), alea(2.5, 4.5) }
		local o = sortie + d / 2 + alea(0.3, 1.2)
		local y = MER + alea(-0.4, 0.5)
		local rot = { alea(-15, 15), alea(0, 90), alea(-15, 15) }
		if recif then
			local q = poser(moitie, "Recif", "Block", t, { x + nx * o, y, z + nz * o }, melange(theme.rocher, NOIR, 0.3), "Rock", "nature")
			q.rot = rot
		end
	end
	-- bout du camp 1 (z = -PZ), d'un coin a l'autre
	local x = -PX
	while x < PX do
		local w = alea(5.5, 7.5)
		bloc(math.min(x + w / 2, PX), -PZ, 0, -1, w)
		x = x + alea(4.2, 5.4)
	end
	-- les deux cotes, de z = -PZ jusqu'a l'encoche de la cascade
	for _, sx in ipairs({ -1, 1 }) do
		local z = -PZ
		while z < -(encoche + 2.5) do
			local w = math.min(alea(5.5, 7.5), -encoche - z)
			bloc(sx * PX, z + w / 2, sx, 0, w)
			z = z + alea(4.2, 5.4)
		end
	end
	-- coins : un gros bloc tourne a 45 degres ferme l'angle
	for _, sx in ipairs({ -1, 1 }) do
		local h = SOL + alea(-0.4, 0.4) - bas
		local p = poser(moitie, "Falaise", "Block", { 7, h, 7 }, { sx * (PX + 0.6), bas + h / 2, -(PZ + 0.6) },
			melange(theme.rocher, NOIR, alea(0.05, 0.2)), "Rock", "nature")
		p.rot = { 0, 45 + alea(-6, 6), 0 }
	end
end

-- VEGETATION DENSE. Des arbres « cartoon » (un tronc, une grosse cime et deux plus petites), des
-- buissons et des rochers, sur une grille tremblee : dense sans jamais s'empiler. Rien a moins de
-- `garde` studs du terrain : aucune cime ne deborde sur le jeu.
local function arbre(liste, x, z, sol, s, theme, alea)
	local h = alea(2.2, 3.4) * s
	local tronc = poser(liste, "Tronc", "Cylinder", { h + 0.6, 0.9 * s, 0.9 * s }, { x, sol + h / 2, z },
		melange(theme.bois, NOIR, alea(0, 0.15)), "Wood", "nature")
	tronc.rot = { 0, 0, 90 } -- un cylindre Roblox est couche sur X : on le redresse
	local cime = sol + h + 1.3 * s
	local d = 4.4 * s
	poser(liste, "Feuillage", "Ball", { d, d, d }, { x, cime, z }, melange(theme.feuillage, BLANC, alea(0, 0.12)), "LeafyGrass", "nature")
	local a = alea(0, 6.2832)
	for k = 0, 1 do
		local ang = a + k * 3.1416
		local ds = 3.1 * s * alea(0.9, 1.1)
		poser(liste, "Feuillage", "Ball", { ds, ds, ds }, { x + math.cos(ang) * 1.35 * s, cime - 0.7 * s, z + math.sin(ang) * 1.35 * s },
			melange(theme.feuillage, NOIR, alea(0.04, 0.16)), "LeafyGrass", "nature")
	end
end

local function buisson(liste, x, z, sol, s, theme, alea)
	local d1, d2 = 2.3 * s, 1.6 * s
	poser(liste, "Buisson", "Ball", { d1, d1, d1 }, { x, sol + d1 * 0.3, z }, melange(theme.feuillage, NOIR, alea(0.1, 0.22)), "LeafyGrass", "nature")
	local a = alea(0, 6.2832)
	poser(liste, "Buisson", "Ball", { d2, d2, d2 }, { x + math.cos(a) * 1.1 * s, sol + d2 * 0.3, z + math.sin(a) * 1.1 * s },
		melange(theme.feuillage, BLANC, alea(0, 0.1)), "LeafyGrass", "nature")
end

local function rocher(liste, x, z, sol, s, theme, alea)
	local t = { alea(1.8, 3) * s, alea(1.2, 2) * s, alea(1.8, 3) * s }
	local p = poser(liste, "Rocher", "Block", t, { x, sol + t[2] * 0.3, z }, melange(theme.rocher, BLANC, alea(0, 0.12)), "Rock", "nature")
	p.rot = { alea(-12, 12), alea(0, 90), alea(-12, 12) }
	local u = { t[1] * 0.5, t[2] * 0.6, t[3] * 0.5 }
	local a = alea(0, 6.2832)
	local q = poser(liste, "Rocher", "Block", u, { x + math.cos(a) * t[1] * 0.6, sol + u[2] * 0.3, z + math.sin(a) * t[3] * 0.6 },
		melange(theme.rocher, NOIR, alea(0.05, 0.2)), "Rock", "nature")
	q.rot = { alea(-15, 15), alea(0, 90), alea(-15, 15) }
end

local function vegetation(moitie, dim, theme, alea)
	local W, L = dim.demiLargeur, dim.demiLongueur
	local PX, PZ = W + Maquette.MARGE_COTE, L + Maquette.MARGE_BOUT
	local SOL = Maquette.SOL_Y
	local pas, garde, bord = 4.6, 4.5, 2.4
	local nx = math.floor(2 * (PX - 2.6) / pas)
	local nz = math.floor((PZ - 2.6) / pas)
	local depart = -nx * pas / 2 -- grille centree : autant de colonnes a gauche qu'a droite
	for i = 0, nx do
		for j = 0, nz do
			-- quatre tirages par case, toujours : la suite du hasard ne depend pas de ce qui est pose
			local cx = depart + i * pas + alea(-1.2, 1.2)
			local cz = -(PZ - 2.6) + j * pas + alea(-1.2, 1.2)
			local tirage = alea(0, 1)
			local s = alea(0.8, 1.25)
			local horsTerrain = math.abs(cx) > W + garde or cz < -(L + garde)
			local horsCanal = not (math.abs(cx) > W and math.abs(cz) < 6)
			local surPlateau = math.abs(cx) < PX - bord and cz > -(PZ - bord) and cz < -0.5
			if horsTerrain and horsCanal and surPlateau then
				if tirage < 0.4 then
					arbre(moitie, cx, cz, SOL, s, theme, alea)
				elseif tirage < 0.66 then
					buisson(moitie, cx, cz, SOL, s, theme, alea)
				elseif tirage < 0.8 then
					rocher(moitie, cx, cz, SOL, s, theme, alea)
				end
			end
		end
	end
end

-- ILOTS AU LARGE : la profondeur de champ que donnent les paysages de Morning Light ou Deepwoken.
-- Sans eux, la mer est un aplat ; avec eux, l'oeil mesure la distance.
local function ilots(moitie, dim, theme, alea)
	local W, L = dim.demiLargeur, dim.demiLongueur
	local PX, PZ = W + Maquette.MARGE_COTE, L + Maquette.MARGE_BOUT
	local MER = Maquette.MER_Y
	local poses, essais = {}, 0
	while #poses < 5 and essais < 80 do
		essais = essais + 1
		local x, z, d = alea(-160, 160), alea(-190, -10), alea(9, 17)
		local libre = math.abs(x) > PX + 20 + d / 2 or z < -(PZ + 20 + d / 2)
		for _, q in ipairs(poses) do
			local ecart = (q[3] + d) / 2 + 12
			-- ni pres d'un ilot deja pose, ni pres de son double (le demi-tour le posera en (-x, -z))
			if (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < ecart ^ 2 or (x + q[1]) ^ 2 + (z + q[2]) ^ 2 < ecart ^ 2 then
				libre = false
			end
		end
		if libre then
			poses[#poses + 1] = { x, z, d }
		end
	end
	for _, q in ipairs(poses) do
		local x, z, d = q[1], q[2], q[3]
		poser(moitie, "Ilot", "Ellipsoide", { d, d * 0.55, d }, { x, MER - 0.3, z }, melange(theme.rocher, NOIR, alea(0, 0.15)), "Rock", "nature")
		poser(moitie, "IlotHerbe", "Ellipsoide", { d * 0.82, d * 0.2, d * 0.82 }, { x, MER + d * 0.19, z }, theme.exterieur, "Grass", "nature")
		local n = (d > 13) and 2 or 1
		for k = 1, n do
			local a = alea(0, 6.2832)
			local r = (n == 1) and 0 or d * 0.18
			arbre(moitie, x + math.cos(a) * r, z + math.sin(a) * r, MER + d * 0.26, alea(0.9, 1.3), theme, alea)
		end
	end
end

-- LA LISTE COMPLETE. `dim` vient du serveur : demiLargeur / demiLongueur (HALF_W / HALF_L), voies
-- (BRIDGES), dessus (hauteur de l'herbe du terrain) et demiRiviere (moitie de la largeur d'eau).
-- `theme` vient de Decor : il ne fournit que des couleurs, et le type de liquide.
function Maquette.pieces(dim, theme)
	local liq = aspectLiquide(theme)
	local liste, moitie = {}, {}
	local alea = generateur(20260929)
	damier(liste, dim, theme)
	traces(liste, dim, theme)
	enceinte(liste, dim, theme)
	plateauEtMer(liste, dim, theme, liq)
	cascade(moitie, dim, theme, liq)
	falaises(moitie, dim, theme, alea)
	vegetation(moitie, dim, theme, alea)
	ilots(moitie, dim, theme, alea)
	for _, p in ipairs(moitie) do
		liste[#liste + 1] = p
		liste[#liste + 1] = demiTour(p)
	end
	return liste
end

return Maquette
