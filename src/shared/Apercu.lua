-- APERCU DE POSE : ce que le joueur voit AVANT de lacher sa carte.
--
-- Pourquoi : jusqu'ici on cliquait a l'aveugle. Rien ne montrait ou la pose etait permise, ni la
-- taille de ce qu'on allait poser, ni la portee d'un sort — on apprenait le refus APRES le clic,
-- par un son. C'est le point de confort le plus cher du jeu, et il se decide par du calcul : tout
-- ce qui suit est PUR, donc verifiable hors Studio (tools/test_apercu.py).
local Apercu = {}

-- Couleurs du disque au sol : vert = je peux poser ici, rouge = non.
Apercu.VERT = Color3.fromRGB(80, 235, 120)
Apercu.ROUGE = Color3.fromRGB(240, 70, 70)
Apercu.TRANSPARENCE_FANTOME = 0.55 -- le fantome reste une silhouette, jamais une vraie unite
Apercu.MARGE_DISQUE = 1.2          -- studs ajoutes autour de l'emprise de l'unite
-- Le fantome n'est PAS en Neon : en neon, toutes les pieces se fondent en une seule tache.
Apercu.MATERIAU_FANTOME = "SmoothPlastic"

function Apercu.teinte(permise)
	if permise then
		return Apercu.VERT
	end
	return Apercu.ROUGE
end

-- RAYON du disque au sol.
--   sort   : son rayon d'effet REEL — le joueur voit exactement ce qu'il va toucher ;
--   unite  : l'emprise de la carte, plus une marge ;
--   groupe : elargi, car les `count` unites se posent en triangle autour du point vise.
function Apercu.rayonCercle(card)
	if card.sort then
		return card.sort.rayon or 3
	end
	local taille = card.size
	local base = math.max(taille and taille.X or 2, taille and taille.Z or 2) / 2
	local rayon = base + Apercu.MARGE_DISQUE
	local n = card.count or 1
	if n > 1 then
		rayon = rayon + 1.1 * (n - 1) -- le triangle de groupe deborde du point vise
	end
	return rayon
end

-- FANTOME : la liste des pieces a dessiner pour la silhouette, deduite des morceaux de la carte.
-- Rend une table vide pour un SORT (il n'y a pas d'unite a montrer : le cercle dit tout).
-- Chaque piece garde sa forme, sa position ET SA COULEUR, en transparence.
-- MESURE DU 2026-09-20 (capture --apercu) : teinter tout le fantome en vert neon donnait une
-- MASSE lumineuse ou l'on ne reconnaissait plus la carte. La silhouette garde donc ses couleurs
-- (on identifie ce qu'on pose) et c'est le DISQUE au sol qui dit oui ou non.
-- PORTEE D'ATTAQUE, MONTREE AVANT LA POSE. Defaut mesure le 2026-09-20 : l'apercu montrait ou la
-- pose est PERMISE et l'emprise de la carte, mais rien ne disait jusqu'ou elle FRAPPERA une fois
-- posee. On decouvrait apres coup qu'un tireur pose trois studs trop bas n'atteignait pas la tour,
-- et l'elixir etait deja parti. Le second cercle repond a la seule question qui compte a cet
-- instant : « de la, est-ce que ca touche ? ».
Apercu.COULEUR_PORTEE = Color3.fromRGB(255, 225, 120)
Apercu.TRANSPARENCE_PORTEE = 0.55
-- En dessous de ce rayon, la carte frappe au CORPS A CORPS (regle du catalogue, Cards.lua :
-- « range < 5 = melee ») : le cercle se confondrait avec le disque de pose et n'apprendrait rien.
Apercu.PORTEE_MINI = 5

-- Rend le rayon a tracer, ou nil quand il n'y a rien d'utile a montrer :
--   * un SORT : son rayon d'effet est DEJA le disque de pose, un second cercle ferait doublon ;
--   * un corps a corps : trop petit pour se distinguer de l'emprise ;
--   * une carte qui ne frappe pas (leurre, collecteur d'elixir) : elle n'a pas de portee.
function Apercu.rayonPortee(card)
	if not card or card.sort then
		return nil
	end
	local r = tonumber(card.range)
	if not r or r < Apercu.PORTEE_MINI then
		return nil
	end
	if (tonumber(card.dmg) or 0) <= 0 then
		return nil
	end
	return r
end

-- SEGMENTS DE L'ANNEAU DE PORTEE. Un disque PLEIN par-dessus le disque de pose donnait une seule
-- tache verdatre ou l'on ne distinguait plus rien (capture cap-portee.png du 2026-09-20) : la
-- portee se dessine donc en ANNEAU. Rend la liste des segments a poser : decalage au sol et angle
-- (en degres) de chacun, pour un cercle de `rayon` studs.
Apercu.SEGMENTS_ANNEAU = 28

function Apercu.segmentsAnneau(rayon, nombre)
	local n = math.max(6, math.floor(tonumber(nombre) or Apercu.SEGMENTS_ANNEAU))
	local r = math.max(0, tonumber(rayon) or 0)
	local l = {}
	for i = 1, n do
		local a = (i - 1) * (2 * math.pi / n)
		l[i] = {
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			-- Le segment est tangent au cercle : sa face longue suit le contour.
			angle = -math.deg(a),
			-- Longueur d'un segment : le tour du cercle divise par leur nombre, un peu allonge
			-- pour que les segments se touchent presque (sinon l'anneau fait des pointilles).
			longueur = (2 * math.pi * r / n) * 1.15,
		}
	end
	return l
end

function Apercu.piecesFantome(card, permise)
	local pieces = {}
	if card.sort or not card.morceaux then
		return pieces
	end
	local k = card.echelle or 1
	for _, m in ipairs(card.morceaux) do
		table.insert(pieces, {
			pos = m.pos * k,
			taille = m.taille * k,
			forme = m.forme,
			rot = m.rot,
			transparence = Apercu.TRANSPARENCE_FANTOME,
			couleur = m.couleur or card.color,
			-- la permission voyage quand meme avec la piece : le client s'en sert pour un liseré
			teinte = Apercu.teinte(permise),
			materiau = Apercu.MATERIAU_FANTOME,
		})
	end
	return pieces
end

-- Le fantome se pose au SOL, pas au centre du corps : sans ce recalage, une grande unite flottait
-- au-dessus du terrain pendant la visee.
function Apercu.hauteurAuSol(card, solY)
	local h = (card.size and card.size.Y or 2) / 2
	return (solY or 0.5) + h
end

return Apercu
