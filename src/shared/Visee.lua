-- VISEE : un tireur vise ou la cible SERA, pas ou elle etait.
--
-- Defaut mesure avant ce module : `attack` visait la position COURANTE de la cible, et le tir
-- mettait ensuite son temps de vol a arriver (Projectiles). Comme un tir dont la cible s'est
-- deplacee de plus de MARGE_ESQUIVE est perdu, un tireur ratait systematiquement toute unite
-- rapide qui traversait son champ — meme en ligne droite, meme sans que le joueur fasse quoi que
-- ce soit. L'esquive est une bonne regle ; rater une cible qui avance TOUT DROIT n'en est pas une.
--
-- Ce module ajoute l'anticipation, et elle est VOLONTAIREMENT imparfaite :
--   * une unite qui va tout droit est touchee — le tireur fait son travail ;
--   * une unite qui CHANGE de direction, qui est repoussee, gelee ou ralentie pendant le vol,
--     esquive encore — le jeu garde ses coups de theatre.
-- Une anticipation parfaite (part = 1 pour tous) rendrait l'esquive impossible et retirerait tout
-- interet aux unites rapides ; c'est pour cela que la part se regle par carte.
--
-- Fonctions pures, verifiees hors Studio (tools/test_visee.lua -> tools/test_visee.py).
local Visee = {}

-- Part du deplacement anticipee, entre 0 (vise la position actuelle, comme avant) et 1 (vise
-- exactement le point d'arrivee). Par defaut les tireurs sont BONS mais pas infaillibles.
Visee.PART_DEFAUT = 0.85
Visee.PART_MAX = 1
-- Ecart maximal, en studs, entre la cible et le point vise : sans lui, une vitesse aberrante
-- (unite qui vient d'etre repoussee, ou premiere image apres la pose) enverrait le tir a l'autre
-- bout de l'arene.
Visee.AVANCE_MAX = 14
-- En dessous de cette vitesse, on ne corrige rien : une unite quasi immobile n'a pas besoin
-- d'anticipation, et le bruit de mesure ferait rater un tir qui serait parti juste.
Visee.VITESSE_MORTE = 0.5

-- Certaines cartes visent mieux que d'autres. Une tourelle fixe (un batiment) prend le temps de
-- calculer ; un lanceur en pleine course, beaucoup moins.
Visee.PARTS = {
	TorreCannoli = 1.0,   -- tourelle : elle ne fait que ca
	Giraffa      = 0.95,  -- tres longue portee, tir tendu
	Tigrullini   = 0.95,
	Lirili       = 0.9,
	Ballerina    = 0.9,
	Bananita     = 0.9,
}

-- Seuil au-dela duquel une carte est un TIREUR. Meme valeur que Cible.PORTEE_TIREUR : c'est
-- deja le seuil que le jeu utilise pour decider qui est un tireur (l'assassin s'en sert pour
-- choisir ses proies). En reprendre un autre ici ferait deux definitions du meme mot.
Visee.PORTEE_TIREUR = 5

-- COHERENCE d'une carte declaree dans PARTS. Une part superieure au defaut est un PRIVILEGE de
-- tireur d'elite : elle n'a aucun sens sur une unite qui frappe au contact, dont la cible est par
-- definition deja sur elle. Et une carte dont le texte promet la longue portee doit etre au-dessus
-- de la portee mediane des tireurs, sinon le texte ment.
--
-- A noter, verifie dans le serveur : une carte ABSENTE de PARTS anticipe quand meme, a
-- PART_DEFAUT (0,85). PARTS n'est donc pas la liste de ceux qui visent, c'est le reglage fin des
-- meilleurs. J'ai d'abord cru a un trou (Glorbo, Frigo, Regina sans visee) : c'etait faux.
-- Rend : ok, raison (raison = nil quand c'est coherent).
function Visee.coherente(id, carte)
	if Visee.PARTS[id] == nil or carte == nil then
		return true, nil
	end
	if carte.batiment then
		return true, nil -- une tourelle fixe vise, c'est tout ce qu'elle fait
	end
	if (tonumber(carte.range) or 0) < Visee.PORTEE_TIREUR then
		return false, "elle frappe au contact : il n'y a rien a anticiper"
	end
	return true, nil
end

function Visee.part(id, estBatiment)
	local p = Visee.PARTS[id]
	if p == nil then
		p = estBatiment and 1.0 or Visee.PART_DEFAUT
	end
	return math.clamp(p, 0, Visee.PART_MAX)
end

-- VITESSE OBSERVEE d'une cible, deduite de deux positions successives. Le serveur ne garde pas de
-- vecteur vitesse : il deplace les unites a la main, image par image. On la mesure donc ici.
-- `dt` nul ou negatif : aucune vitesse (et surtout aucune division par zero).
function Visee.vitesseObservee(x, z, xPrec, zPrec, dt)
	local d = tonumber(dt) or 0
	if d <= 0 or xPrec == nil or zPrec == nil then
		return 0, 0
	end
	return ((x or 0) - xPrec) / d, ((z or 0) - zPrec) / d
end

-- POINT VISE. `duree` = temps de vol du projectile (Projectiles.duree).
-- Rend les coordonnees du point ou le tir doit etre envoye.
function Visee.point(x, z, vx, vz, duree, part)
	local cx, cz = x or 0, z or 0
	local t = tonumber(duree) or 0
	if t <= 0 then
		return cx, cz -- arrivee immediate : rien a anticiper
	end
	local p = math.clamp(part or Visee.PART_DEFAUT, 0, Visee.PART_MAX)
	if p <= 0 then
		return cx, cz
	end
	local sx, sz = vx or 0, vz or 0
	if math.sqrt(sx * sx + sz * sz) < Visee.VITESSE_MORTE then
		return cx, cz -- elle ne bouge pas vraiment
	end
	local ax, az = sx * t * p, sz * t * p
	-- borne : on n'envoie jamais le tir a plus de AVANCE_MAX studs devant la cible
	local n = math.sqrt(ax * ax + az * az)
	if n > Visee.AVANCE_MAX then
		ax, az = ax / n * Visee.AVANCE_MAX, az / n * Visee.AVANCE_MAX
	end
	return cx + ax, cz + az
end

-- Le tir serait-il PERDU sans anticipation ? Sert au banc a mesurer ce que le module apporte :
-- c'est exactement le test applique a l'arrivee (ecart au point vise contre la marge d'esquive).
function Visee.rate(viseX, viseZ, arriveeX, arriveeZ, marge)
	local dx, dz = (arriveeX or 0) - (viseX or 0), (arriveeZ or 0) - (viseZ or 0)
	return math.sqrt(dx * dx + dz * dz) > (marge or 0)
end

return Visee
