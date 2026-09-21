-- PORTRAIT D'UN PERSONNAGE DANS LE MENU, en calcul PUR.
--
-- Le defaut corrige (2026-09-21) : le menu n'affichait AUCUNE image. Les cartes du deck etaient des
-- aplats de couleur portant un nom — rien qui donne envie, sur l'ecran meme qui doit vendre le jeu.
--
-- D'OU VIENT L'IMAGE — et pourquoi pas du catalogue. Les personnages existent deja dans le jeu : leurs
-- modeles 3D sont ECRITS dans la place par build.py (ReplicatedStorage.Modeles), et le serveur s'en
-- sert pour les unites. Cards.lua consigne une decision explicite : ne dependre d'AUCUN element du
-- catalogue Roblox au moment de jouer, « pour que rien ne disparaisse si son auteur le retire ».
-- Afficher la vignette du catalogue (rbxthumb) aurait reintroduit exactement cette dependance, et
-- n'aurait rien montre hors ligne. On rend donc le MODELE DU JEU lui-meme, en 3D, dans la carte.
--
-- Ce module ne fait que le CADRAGE : a quelle distance et sous quel angle placer la camera pour que
-- le personnage remplisse le portrait sans en deborder. Le client applique.
local Portrait = {}

Portrait.CHAMP = 30        -- champ vertical de la camera, en degres : peu de deformation
-- Mesure a l'ecran le 2026-09-21 : a 1,12 dans une demi-carte, le personnage ne faisait qu'une
-- vingtaine de pixels. Plein cadre et marge serree, il remplit la carte sans en toucher les bords.
Portrait.MARGE = 1.03
Portrait.TROIS_QUARTS = 25 -- degres : de trois quarts plutot que de face, plus vivant
Portrait.PLONGEE = 0.12    -- la camera un peu au-dessus, en fraction de la distance

-- Distance a laquelle placer la camera pour que le personnage TIENNE dans le cadre.
-- On prend la plus grande dimension vue de face (largeur ou hauteur) ; la profondeur s'ajoute a
-- moitie, sinon l'avant d'un modele tres long viendrait toucher l'objectif.
function Portrait.distance(largeur, hauteur, profondeur, champ)
	local l = math.max(0, tonumber(largeur) or 0)
	local h = math.max(0, tonumber(hauteur) or 0)
	local p = math.max(0, tonumber(profondeur) or 0)
	local grand = math.max(l, h)
	if grand <= 0 then
		return nil -- modele vide : rien a cadrer
	end
	local demiChamp = math.rad((tonumber(champ) or Portrait.CHAMP) / 2)
	return (grand / 2) * Portrait.MARGE / math.tan(demiChamp) + p / 2
end

-- Position de la camera, RELATIVE au centre du personnage. Le serveur tourne chaque modele pour que
-- son « avant » regarde vers -Z (GameServer, `habiller`) ; le client fait la meme correction, donc la
-- camera se place du cote -Z pour voir le visage, decalee de trois quarts et legerement au-dessus.
function Portrait.oeil(distance)
	local d = tonumber(distance)
	if not d or d <= 0 then
		return nil
	end
	local a = math.rad(Portrait.TROIS_QUARTS)
	return math.sin(a) * d, Portrait.PLONGEE * d, -math.cos(a) * d
end

-- Une carte a-t-elle un personnage a montrer ? Sinon la carte garde son aplat de couleur : on ne
-- fabrique pas d'image pour les cartes qui n'ont pas de modele.
function Portrait.disponible(id, noms)
	return id ~= nil and type(noms) == "table" and noms[id] == true
end

-- EMBLEME DES SORTS. Les huit cartes de sort n'ont ni modele ni silhouette : elles ne marchent pas
-- sur le terrain, elles y tombent. Sans rien, leur carte restait un aplat de couleur au milieu des
-- personnages. On leur dessine un EMBLEME par effet, avec les memes pieces simples que les
-- silhouettes (bloc, boule, cylindre), dans la couleur du sort.
-- Coordonnees en studs, centre au sol ; `rot` en degres. Un cylindre Roblox est couche sur l'axe X :
-- `rot.z = 90` le met debout. `clair` eclaircit la piece (0 = couleur du sort, 1 = blanc).
local function p(forme, x, y, z, lx, ly, lz, rx, ry, rz, clair)
	return {
		forme = forme,
		pos = { x = x, y = y, z = z },
		taille = { x = lx, y = ly, z = lz },
		rot = { x = rx or 0, y = ry or 0, z = rz or 0 },
		clair = clair or 0,
	}
end

Portrait.EMBLEMES = {
	-- bombe : une boule, sa meche, l'etincelle
	degats = {
		p("boule", 0, 1.1, 0, 2.2, 2.2, 2.2),
		p("cylindre", 0.35, 2.35, 0, 0.9, 0.28, 0.28, 0, 0, 60, 0.35),
		p("boule", 0.75, 2.75, 0, 0.55, 0.55, 0.55, 0, 0, 0, 0.9),
	},
	-- eclair qui frappe plusieurs cibles
	eclair = {
		p("bloc", -0.35, 2.3, 0, 0.5, 1.4, 0.35, 0, 0, -25),
		p("bloc", 0.2, 1.3, 0, 0.5, 1.4, 0.35, 0, 0, 25, 0.25),
		p("bloc", -0.2, 0.3, 0, 0.45, 1.2, 0.35, 0, 0, -25, 0.5),
	},
	-- tronc qui repousse : couche, avec ses deux faces claires
	tronc = {
		p("cylindre", 0, 0.7, 0, 3.2, 1.4, 1.4),
		p("cylindre", 1.62, 0.7, 0, 0.06, 1.2, 1.2, 0, 0, 0, 0.55),
		p("cylindre", -1.62, 0.7, 0, 0.06, 1.2, 1.2, 0, 0, 0, 0.55),
	},
	-- cristal de glace : un bloc sur la pointe, deux eclats
	gel = {
		p("bloc", 0, 1.3, 0, 1.4, 1.4, 1.4, 45, 0, 45, 0.3),
		p("bloc", 0.95, 0.5, 0.2, 0.6, 0.6, 0.6, 30, 20, 45, 0.6),
		p("bloc", -0.9, 0.55, -0.1, 0.5, 0.5, 0.5, 20, 40, 35, 0.6),
	},
	-- fiole de poison : panse, col, bouchon
	poison = {
		p("boule", 0, 1, 0, 2, 2, 2),
		p("cylindre", 0, 2.25, 0, 0.8, 0.6, 0.6, 0, 0, 90, 0.25),
		p("cylindre", 0, 2.75, 0, 0.3, 0.75, 0.75, 0, 0, 90, 0.7),
	},
	-- croix de soin
	soin = {
		p("bloc", 0, 1.3, 0, 0.8, 2.4, 0.5, 0, 0, 0, 0.15),
		p("bloc", 0, 1.3, 0, 2.4, 0.8, 0.5, 0, 0, 0, 0.15),
	},
	-- flamme de rage : trois langues, de plus en plus claires vers le haut
	rage = {
		p("bloc", 0, 0.8, 0, 1.5, 1.5, 1.5, 0, 45, 0),
		p("bloc", 0, 1.9, 0, 1, 1, 1, 0, 45, 0, 0.3),
		p("bloc", 0, 2.7, 0, 0.55, 0.8, 0.55, 0, 45, 0, 0.65),
	},
}

-- Quel embleme pour quel sort. Les champs du sort le disent : `cibles` (plusieurs frappes) est un
-- eclair, `recul` (repousse au sol) un tronc ; sinon l'effet choisit. Inconnu -> la bombe.
function Portrait.embleme(sort)
	if type(sort) ~= "table" then
		return nil
	end
	if sort.cibles then
		return Portrait.EMBLEMES.eclair
	end
	if sort.recul then
		return Portrait.EMBLEMES.tronc
	end
	return Portrait.EMBLEMES[sort.effet] or Portrait.EMBLEMES.degats
end

-- CE QUE LA CARTE MONTRE. Une seule regle, pour les cinq endroits ou une carte s'affiche :
-- son modele 3D s'il existe, sinon sa silhouette en morceaux (celle que le serveur pose en jeu),
-- sinon l'embleme de son sort. Rien de plus : une carte sans aucun des trois reste un aplat.
function Portrait.source(carte, aModele)
	if type(carte) ~= "table" then
		return nil
	end
	if aModele == true then
		return "modele"
	end
	if type(carte.morceaux) == "table" and #carte.morceaux > 0 then
		return "morceaux"
	end
	if type(carte.sort) == "table" then
		return "embleme"
	end
	return nil
end

return Portrait
