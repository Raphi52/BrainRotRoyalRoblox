-- LES COURONNES, MISES EN SCENE. Fonctions PURES.
--
-- Le defaut corrige : prendre une tour — le moment le plus important d'une partie — ne produisait
-- qu'un son et une secousse. Rien ne le NOMMAIT. Le joueur voyait un chiffre passer de 0 a 1 dans
-- un coin de l'ecran, au milieu d'une bataille : la moitie du temps, il ne s'en rendait pas compte.
-- Et le camp qui PERD une tour n'avait droit a aucun signal distinct : la meme secousse annoncait
-- la meilleure et la pire des nouvelles.
--
-- Ici, le camp qui gagne et le camp qui perd recoivent deux annonces DIFFERENTES, tirees du meme
-- changement de score — donc sans aucun evenement reseau supplementaire.
local Couronnes = {}

Couronnes.MAX = 3 -- trois couronnes : deux tours de cote, puis le Roi (qui vaut la partie)

Couronnes.COULEUR_GAIN = { 255, 205, 60 }   -- or
Couronnes.COULEUR_PERTE = { 255, 95, 95 }   -- rouge

-- TEXTE d'un gain. Deux couronnes d'un coup arrivent (double poussee, ou sort qui acheve) : le
-- dire change la sensation, et c'est gratuit.
function Couronnes.texteGain(nombre, total)
	if (total or 0) >= Couronnes.MAX then
		return "TOUR DU ROI DETRUITE !"
	end
	if (nombre or 1) >= 2 then
		return "DOUBLE COURONNE !"
	end
	return "COURONNE !"
end

function Couronnes.textePerte(nombre, total)
	if (total or 0) >= Couronnes.MAX then
		return "TON ROI EST TOMBE..."
	end
	if (nombre or 1) >= 2 then
		return "DEUX TOURS PERDUES..."
	end
	return "TOUR PERDUE..."
end

-- EVENEMENTS tires de la comparaison de deux etats. Rend une LISTE (les deux camps peuvent
-- marquer dans le meme rafraichissement), la sienne d'abord : c'est elle qu'on veut lire en premier.
-- Aucune annonce au premier etat recu (avant = nil) : sinon rejoindre une partie en cours
-- declencherait une pluie de couronnes deja acquises.
function Couronnes.evenements(avantMoi, avantLui, moi, lui)
	if avantMoi == nil or avantLui == nil then
		return {}
	end
	local l = {}
	local gain = (moi or 0) - avantMoi
	local perte = (lui or 0) - avantLui
	if gain > 0 then
		table.insert(l, { camp = "moi", nombre = gain, total = moi,
			texte = Couronnes.texteGain(gain, moi), couleur = Couronnes.COULEUR_GAIN })
	end
	if perte > 0 then
		table.insert(l, { camp = "lui", nombre = perte, total = lui,
			texte = Couronnes.textePerte(perte, lui), couleur = Couronnes.COULEUR_PERTE })
	end
	return l
end

-- Un compteur qui REDESCEND veut dire nouvelle partie, jamais une couronne rendue : on n'annonce
-- rien et on se resynchronise.
function Couronnes.remiseAZero(avantMoi, avantLui, moi, lui)
	return (avantMoi or 0) > (moi or 0) or (avantLui or 0) > (lui or 0)
end

-- JAUGE DE COURONNES, lisible d'un coup d'oeil : « ●●○ ».
function Couronnes.jauge(n)
	local pleines = math.max(0, math.min(Couronnes.MAX, math.floor(n or 0)))
	return string.rep("●", pleines) .. string.rep("○", Couronnes.MAX - pleines)
end

-- Force de la secousse : une tour du Roi ebranle plus qu'une tour de cote.
Couronnes.SECOUSSE = { tour = 1.6, roi = 2.4 }
function Couronnes.secousse(total)
	if (total or 0) >= Couronnes.MAX then
		return Couronnes.SECOUSSE.roi
	end
	return Couronnes.SECOUSSE.tour
end

-- VOL DE LA COURONNE (2026-09-21) : en 3D au-dessus d'une tour adverse, elle montait sous le score
-- et y restait a moitie cachee. Elle vole donc A L'ECRAN de la tour au compteur. t va de 0 a 1 :
-- `avance` = part du trajet (lente au depart, rapide a l'arrivee), `arc` = bosse vers le haut en
-- pixels-relatifs (0..1 de la distance), `echelle` = taille : jaillit, plane, puis se pose petite.
Couronnes.VOL_DUREE = 2.5
function Couronnes.vol(t)
	t = math.clamp and math.clamp(t, 0, 1) or math.max(0, math.min(1, t))
	local plane = 0.35 -- premier tiers : elle jaillit et reste sur la tour, bien visible
	local u = t <= plane and 0 or (t - plane) / (1 - plane)
	local avance = u * u * (3 - 2 * u)
	local echelle
	if t < 0.12 then
		echelle = 0.4 + (1.3 - 0.4) * (t / 0.12)
	elseif t <= plane then
		echelle = 1.3 - 0.2 * ((t - 0.12) / (plane - 0.12))
	else
		echelle = 1.1 - (1.1 - 0.45) * u
	end
	return { avance = avance, arc = 4 * u * (1 - u) * 0.25, echelle = echelle }
end

return Couronnes
