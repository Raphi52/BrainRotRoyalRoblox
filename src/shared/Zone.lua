-- ZONE DE POSE SURLIGNEE, en fonctions PURES.
--
-- Le defaut corrige : une carte armee, et rien a l'ecran ne disait OU elle pouvait atterrir. Le
-- joueur decouvrait la limite en se faisant refuser — au pire moment, celui ou il croyait poser.
-- Pire : casser une tour OUVRE la moitie adverse de ce cote-la, la regle la plus valorisante du
-- jeu, et elle etait totalement invisible. Beaucoup de joueurs ne l'ont jamais decouverte.
--
-- Ce module ne dessine rien : il rend des RECTANGLES (centre, taille, genre). Le client en fait
-- des dalles. Les memes bornes que Regles/Batiments/Sorts, pour que le surlignage ne mente jamais.
local Zone = {}

Zone.BANDE_PROPRE = 3        -- meme valeur que Regles.posePermise (z * s >= 3)
Zone.BANDE_RIVIERE = 5       -- meme valeur que Batiments.BANDE_RIVIERE (verifiee par le banc)
Zone.MARGE_BORD = 1          -- les bords de l'arene sont refuses par le serveur

-- Couleurs par genre de zone, en RGB simples (aucune API Roblox ici).
Zone.COULEURS = {
	propre = { 80, 200, 255 },  -- sa moitie : bleu calme
	ouverte = { 255, 190, 70 },  -- moitie adverse ouverte par une tour tombee : or, ca se merite
	totale = { 190, 140, 255 },  -- sort ou carte qui se pose partout : violet
}

function Zone.couleur(genre)
	return Zone.COULEURS[genre] or Zone.COULEURS.propre
end

local function rect(genre, x, z, largeur, longueur)
	return { genre = genre, x = x, z = z, largeur = largeur, longueur = longueur }
end

-- RECTANGLES A SURLIGNER.
--   camp       : 1 (pose en z negatif) ou 2
--   carte      : { sort = ..., poseLibre = ..., batiment = ... } (les champs du catalogue)
--   gauche/droite : la tour ennemie de ce cote est-elle TOMBEE ?
--   demiL, demiLong : demi-dimensions de l'arene
function Zone.rectangles(camp, carte, gauche, droite, demiL, demiLong)
	local s = (camp == 1) and -1 or 1
	local L = (demiL or 32) - Zone.MARGE_BORD
	local P = (demiLong or 44) - Zone.MARGE_BORD
	local c = carte or {}

	-- Un SORT (ou une carte qui se pose partout) vise toute l'arene : un seul rectangle.
	if c.sort or c.poseLibre then
		return { rect("totale", 0, 0, L * 2, P * 2) }
	end

	-- Un BATIMENT : sa moitie, MOINS la bande de la riviere (il boucherait le pont).
	if c.batiment then
		local proche = Zone.BANDE_RIVIERE
		local longueur = P - proche
		if longueur <= 0 then
			return {}
		end
		return { rect("propre", 0, s * (proche + longueur / 2), L * 2, longueur) }
	end

	-- Cas normal : sa moitie, plus la moitie adverse du cote d'une tour tombee.
	local longueur = P - Zone.BANDE_PROPRE
	local out = {}
	if longueur > 0 then
		table.insert(out, rect("propre", 0, s * (Zone.BANDE_PROPRE + longueur / 2), L * 2, longueur))
	end
	-- La moitie adverse s'ouvre par MOITIE DE LARGEUR (cote gauche = x negatif).
	local avant = P + Zone.BANDE_PROPRE -- de -BANDE_PROPRE (chez lui) jusqu'au fond adverse
	if gauche then
		table.insert(out, rect("ouverte", -L / 2, -s * (avant / 2 - Zone.BANDE_PROPRE / 2), L, avant))
	end
	if droite then
		table.insert(out, rect("ouverte", L / 2, -s * (avant / 2 - Zone.BANDE_PROPRE / 2), L, avant))
	end
	return out
end

-- Y a-t-il quelque chose de NOUVEAU a montrer ? Sert au client a ne pas reconstruire les dalles a
-- chaque image : elles ne changent qu'au changement de carte ou de tour tombee.
function Zone.signature(camp, carte, gauche, droite)
	local c = carte or {}
	return table.concat({ tostring(camp), tostring(c.id or "-"), tostring(gauche == true),
		tostring(droite == true) }, "|")
end

-- Phrase montree la PREMIERE fois qu'une voie s'ouvre : la regle la plus valorisante du jeu etait
-- invisible, l'annoncer une fois suffit a la faire comprendre.
function Zone.annonceOuverture(gauche, droite)
	if not (gauche or droite) then
		return nil
	end
	if gauche and droite then
		return "Les deux voies sont ouvertes : tu peux poser chez lui !"
	end
	return "Voie ouverte : tu peux poser dans sa moitie, " .. (gauche and "a gauche" or "a droite") .. " !"
end

return Zone
