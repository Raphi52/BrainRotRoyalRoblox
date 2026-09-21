-- QUI EST A MOI, QUI EST EN FACE : regles PURES de lisibilite des deux camps.
--
-- Le defaut corrige : les couleurs etaient ABSOLUES (camp 1 bleu, camp 2 rouge). Le joueur du
-- camp 2 voyait donc SES unites en rouge et celles d'en face en bleu — l'inverse de tout le reste
-- du genre, et l'inverse de son propre reflexe. En duel, la moitie des joueurs lisait le terrain
-- a l'envers.
-- Ici, la couleur est RELATIVE a celui qui regarde : les miennes toujours bleues, celles d'en face
-- toujours rouges. Le spectateur, lui, garde les couleurs du camp 1 et du camp 2.
--
-- Et la couleur ne suffit pas : un joueur sur dix confond rouge et vert-bleu. La FORME de la
-- marque au-dessus de la tete change donc aussi — boule pour les miennes, cube pour celles d'en
-- face —, ce qui se lit meme sans couleur.
local Camps = {}

-- Couleurs en RGB simples (pas de Color3 : ce module ne connait pas Roblox).
Camps.AMI = { 60, 140, 255 }      -- bleu franc
Camps.ENNEMI = { 255, 70, 70 }    -- rouge franc
Camps.CAMP1 = { 60, 140, 255 }    -- vue du spectateur : camp 1
Camps.CAMP2 = { 255, 70, 70 }     -- vue du spectateur : camp 2

Camps.FORME_AMI = "boule"
Camps.FORME_ENNEMI = "cube"

function Camps.estAmi(campObjet, monCamp)
	if not monCamp or monCamp == 0 then
		return nil -- spectateur : personne n'est « a lui »
	end
	return campObjet == monCamp
end

-- COULEUR A AFFICHER pour un objet du camp `campObjet`, vu par le joueur du camp `monCamp`.
-- monCamp nil ou 0 (spectateur) : on rend la couleur du camp, pas une couleur relative.
function Camps.couleur(campObjet, monCamp)
	local ami = Camps.estAmi(campObjet, monCamp)
	if ami == nil then
		return (campObjet == 1) and Camps.CAMP1 or Camps.CAMP2
	end
	return ami and Camps.AMI or Camps.ENNEMI
end

-- FORME de la marque de camp : lisible sans distinguer les couleurs.
function Camps.forme(campObjet, monCamp)
	local ami = Camps.estAmi(campObjet, monCamp)
	if ami == nil then
		return (campObjet == 1) and Camps.FORME_AMI or Camps.FORME_ENNEMI
	end
	return ami and Camps.FORME_AMI or Camps.FORME_ENNEMI
end

-- CONTOUR de silhouette : meme teinte, assombrie, pour que la decoupe reste lisible sur l'herbe.
function Camps.contour(campObjet, monCamp)
	local c = Camps.couleur(campObjet, monCamp)
	return { math.floor(c[1] * 0.35), math.floor(c[2] * 0.35), math.floor(c[3] * 0.35) }
end

-- LE SON DIT AUSSI A QUI C'EST. Meme banque de bruitages, deux lectures : ce qui m'arrive sonne
-- plus GRAVE et plus FORT (c'est ce qui compte pour moi), ce qui arrive en face sonne plus clair
-- et plus discret. Sans cette difference, une unite qui meurt sonnait pareil qu'elle soit a moi ou
-- a l'adversaire : l'oreille n'apprenait rien, et en melee on ne savait plus qui perdait.
Camps.VOLUME_AMI = 1.0
Camps.VOLUME_ENNEMI = 0.72
Camps.VITESSE_AMI = 0.88   -- plus grave
Camps.VITESSE_ENNEMI = 1.18 -- plus clair

function Camps.volumeSon(campObjet, monCamp)
	local ami = Camps.estAmi(campObjet, monCamp)
	if ami == nil then
		return 1 -- spectateur : aucun camp n'est « le sien », on ne favorise personne
	end
	return ami and Camps.VOLUME_AMI or Camps.VOLUME_ENNEMI
end

function Camps.vitesseSon(campObjet, monCamp)
	local ami = Camps.estAmi(campObjet, monCamp)
	if ami == nil then
		return 1
	end
	return ami and Camps.VITESSE_AMI or Camps.VITESSE_ENNEMI
end

-- LIRE LES CAMPS SANS LES COULEURS. Un joueur sur douze confond le rouge et le vert-bleu ; pour
-- lui, le duel entier reposait sur une distinction qu'il ne voit pas. La FORME de la marque le
-- reglait deja pour les unites — mais ni les TOURS ni les BARRES DE VIE n'avaient de repere.
--
-- Langage retenu, le meme partout : ce qui est A MOI est ROND et PLEIN, ce qui est EN FACE est
-- ANGULEUX et SEGMENTE. Aucune couleur n'entre dans cette lecture.
-- LISIBILITE A DISTANCE. Defaut mesure sur les captures du 2026-09-20 : la marque posee au-dessus
-- des tours avait une taille FIXE (1,8 stud). Au-dessus de SES tours, a une dizaine de studs, elle
-- se lisait ; au-dessus des tours d'en face, a plus de 60 studs, elle tombait a quelques pixels —
-- la boule et le cube devenaient le meme point, et la seule information qui restait etait la
-- couleur. Exactement ce qu'on avait corrige pour les daltoniens, perdu par la distance.
--
-- Une taille FIXE en studs rétrecit a l'ecran comme 1/distance. Pour garder une taille constante
-- A L'ECRAN, la marque doit donc GRANDIR proportionnellement a la distance.
-- Valeur choisie au banc : a 85 studs (une tour d'en face vue depuis son propre camp), elle donne
-- une marque 2,4 fois plus grosse que l'ancienne taille fixe de 1,8 stud, sans coiffer la tour
-- (a 0,055 elle mangeait le haut des tours d'en face sur la capture du 2026-09-21).
Camps.ANGLE_MARQUE = 0.05   -- fraction de la distance : taille angulaire visee
Camps.MARQUE_MIN = 1.8       -- de pres, on ne grossit pas au point de masquer la tour
-- Plafond : une tour fait environ 7 studs de large. Au-dela de ~4,5 la marque la coiffe au lieu
-- de la surmonter (mesure a l'ecran le 2026-09-21).
Camps.MARQUE_MAX = 4.5

function Camps.tailleMarque(distance)
	local d = math.max(0, tonumber(distance) or 0)
	return math.max(Camps.MARQUE_MIN, math.min(Camps.MARQUE_MAX, d * Camps.ANGLE_MARQUE))
end

-- SILHOUETTE : une marque coloree posee sur un ciel clair ou sur l'herbe perd ses bords. On lui
-- donne un liseré, d'epaisseur proportionnelle — sinon il disparait lui aussi de loin. Il est
-- SOMBRE sous une marque claire et CLAIR sous une marque sombre : un liseré de teinte fixe
-- s'effacerait sous l'une des deux.
Camps.LISERE_SOMBRE = { 8, 9, 14 }
Camps.LISERE_CLAIR = { 245, 246, 250 }
-- Pas d'epaisseur de liseré ici : elle etait donnee en studs, et un bord epais de plusieurs studs
-- AVALAIT la marque (capture du 2026-09-21). Le contour est desormais trace par le moteur, d'une
-- epaisseur constante a l'ecran — ce qui est precisement ce qu'on veut a toute distance.

-- CONTRASTE (rapport de luminance, comme sur le web : de 1 = identique a 21 = noir sur blanc).
-- Sert a PROUVER au banc que les deux marques se distinguent l'une de l'autre et se detachent de
-- leur liseré, au lieu de s'en remettre a l'oeil sur une capture.
local function canal(v)
	local c = math.max(0, math.min(255, v)) / 255
	if c <= 0.03928 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

function Camps.luminance(c)
	return 0.2126 * canal(c[1]) + 0.7152 * canal(c[2]) + 0.0722 * canal(c[3])
end

function Camps.contraste(a, b)
	local la, lb = Camps.luminance(a), Camps.luminance(b)
	local haut, bas = math.max(la, lb), math.min(la, lb)
	return (haut + 0.05) / (bas + 0.05)
end

Camps.CONTRASTE_MIN = 3.0 -- en dessous, deux teintes se confondent des qu'elles sont petites

-- COULEUR DE LA MARQUE, et sa CLARTE. Premier essai, mesure au banc : eclaircir les DEUX marques
-- donnait un bleu clair et un rouge clair de meme luminance — contraste 1,08. Deux points de la
-- meme clarte a 80 studs, c'est un seul et meme point gris : le defaut daltonien qu'on avait
-- corrige de pres revenait avec la distance.
-- Donc les deux marques different AUSSI par la clarte : la mienne est claire, celle d'en face est
-- sombre. Trois signaux qui tiennent de loin : la forme, la teinte, la clarte.
Camps.ECLAIRCIR_AMI = 0.55
Camps.ASSOMBRIR_ENNEMI = 0.62

function Camps.couleurMarque(campObjet, monCamp)
	local c = Camps.couleur(campObjet, monCamp)
	local ami = Camps.estAmi(campObjet, monCamp)
	if ami == nil then
		ami = (campObjet == 1) -- spectateur : camp 1 clair, camp 2 sombre
	end
	local out = {}
	for i = 1, 3 do
		if ami then
			out[i] = math.floor(c[i] + (255 - c[i]) * Camps.ECLAIRCIR_AMI)
		else
			out[i] = math.floor(c[i] * (1 - Camps.ASSOMBRIR_ENNEMI))
		end
	end
	return out
end

-- Le liseré prend le contrepied de la marque, pour que le bord existe dans les deux cas.
function Camps.lisere(campObjet, monCamp)
	local marque = Camps.couleurMarque(campObjet, monCamp)
	if Camps.luminance(marque) > 0.18 then
		return Camps.LISERE_SOMBRE
	end
	return Camps.LISERE_CLAIR
end

Camps.SEGMENTS_ENNEMI = 3 -- barre d'en face coupee en trois : lisible en noir et blanc

-- Combien de traits de separation sur une barre de vie (0 = barre pleine, donc alliee).
function Camps.segmentsBarre(campObjet, monCamp)
	local ami = Camps.estAmi(campObjet, monCamp)
	if ami == nil then
		-- spectateur : il n'a pas de camp, mais il doit quand meme distinguer les deux. On segmente
		-- le camp 2, comme pour un joueur du camp 1.
		return (campObjet == 2) and Camps.SEGMENTS_ENNEMI or 0
	end
	return ami and 0 or Camps.SEGMENTS_ENNEMI
end

-- La TOUR porte la meme marque que les unites : boule a moi, cube en face.
function Camps.formeTour(campObjet, monCamp)
	return Camps.forme(campObjet, monCamp)
end

-- Verification de lisibilite, utilisable au banc : deux camps doivent differer par au moins DEUX
-- signaux (couleur + forme, ou couleur + segments). Rend le nombre de signaux distincts.
function Camps.signauxDistincts(monCamp)
	local n = 0
	local a, b = 1, 2
	if Camps.couleur(a, monCamp)[1] ~= Camps.couleur(b, monCamp)[1]
		or Camps.couleur(a, monCamp)[2] ~= Camps.couleur(b, monCamp)[2] then
		n = n + 1
	end
	if Camps.forme(a, monCamp) ~= Camps.forme(b, monCamp) then
		n = n + 1
	end
	if Camps.segmentsBarre(a, monCamp) ~= Camps.segmentsBarre(b, monCamp) then
		n = n + 1
	end
	return n
end

-- LE NOM DE L'ADVERSAIRE SE POSE SUR SON COTE. `monCamp` joue en z negatif quand il vaut 1 ; la
-- tour du Roi d'en face est donc du signe oppose. Rend le SIGNE de z ou ecrire le nom, jamais une
-- position toute faite (l'arene peut changer de taille).
function Camps.coteAdverse(monCamp)
	if not monCamp or monCamp == 0 then
		return nil
	end
	return (monCamp == 1) and 1 or -1
end

-- Le nom affiche : celui de l'adversaire s'il y en a un, sinon la machine. Jamais vide, sinon une
-- etiquette sans texte flotte au-dessus de la tour.
function Camps.nomAdverse(nom)
	if type(nom) ~= "string" or nom == "" then
		return "Robot"
	end
	return nom
end

return Camps
