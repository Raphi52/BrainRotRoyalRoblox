-- PHOTO DE PROFIL DES DEUX JOUEURS, en regles PURES.
--
-- Le defaut corrige : en duel, l'adversaire n'etait qu'un NOM. Rien ne donnait le sentiment de
-- jouer contre quelqu'un — c'est la plainte de fond de tout l'audit PvP : on affronte une chaine
-- de caracteres. Le visage est ce qui transforme un pseudo en personne.
--
-- CE QUE CE MODULE NE FAIT PAS : telecharger l'image. Recuperer une photo Roblox est un appel
-- RESEAU qui peut etre lent, echouer, ou ne rien rendre du tout hors ligne (c'est le cas dans
-- Studio). Ici on decide seulement CE QU'IL FAUT AFFICHER, y compris quand la photo n'arrive
-- pas — le cas le plus frequent, et justement celui qu'on oublie de traiter.
local Profil = {}

-- Ce qu'on demande a Roblox. Trois cas seulement, et le robot n'en est PAS un : il n'a pas de
-- compte, donc aucune image a chercher. Lui inventer un identifiant d'image serait inventer un
-- contrat externe.
function Profil.demande(userId, estRobot)
	if estRobot then
		return { type = "robot" }
	end
	local id = tonumber(userId)
	if not id or id <= 0 then
		return { type = "aucun" } -- joueur parti, ou identifiant absent
	end
	return { type = "joueur", userId = math.floor(id) }
end

-- REPLI : tant que la photo n'est pas la (ou ne viendra jamais), on montre une pastille avec
-- l'initiale. Un carre vide, lui, ressemble a un bug ; et un carre gris ne dit pas QUI c'est.
function Profil.initiale(nom)
	local s = tostring(nom or "")
	local lettre = string.match(s, "%a")
	if not lettre then
		lettre = string.match(s, "%w")
	end
	return lettre and string.upper(lettre) or "?"
end

-- Couleur de la pastille de repli. Elle doit etre STABLE (le meme joueur garde la meme) et
-- NEUTRE : surtout pas bleu ni rouge, qui disent deja le camp ailleurs a l'ecran. On tire donc
-- dans une petite palette sourde, indexee par le nom.
Profil.PALETTE = {
	{ 92, 88, 120 }, { 84, 104, 96 }, { 120, 100, 76 },
	{ 96, 92, 84 }, { 76, 96, 116 }, { 112, 84, 100 },
}

function Profil.couleurRepli(nom)
	local s = tostring(nom or "")
	local somme = 0
	for i = 1, #s do
		somme = somme + string.byte(s, i) * i
	end
	return Profil.PALETTE[(somme % #Profil.PALETTE) + 1]
end

-- LE ROBOT a sa propre pastille, et il ne doit pas passer pour un humain : une initiale de plus
-- laisserait croire a un pseudo. On affiche un signe, et la couleur ne vient pas du nom.
Profil.SIGNE_ROBOT = "\u{2699}" -- rouage
Profil.COULEUR_ROBOT = { 70, 78, 92 }

function Profil.replis(nom, estRobot)
	if estRobot then
		return { texte = Profil.SIGNE_ROBOT, couleur = Profil.COULEUR_ROBOT }
	end
	return { texte = Profil.initiale(nom), couleur = Profil.couleurRepli(nom) }
end

-- CE QUI EST AFFICHE, une fois qu'on sait si la photo est arrivee. C'est la seule fonction que le
-- client appelle pour decider : elle garantit qu'il y a TOUJOURS quelque chose a montrer.
function Profil.vue(nom, estRobot, image)
	local utilisable = type(image) == "string" and image ~= ""
	local repli = Profil.replis(nom, estRobot)
	return {
		image = utilisable and image or nil,
		texte = utilisable and "" or repli.texte,
		couleur = repli.couleur,
		-- Le contour reste visible meme avec une photo : c'est lui qui detache la pastille du
		-- decor 3D, qui peut etre clair comme sombre selon l'arene.
		contour = true,
	}
end

-- TAILLE ET PLACE. Les portraits encadrent la ligne de score : le mien a gauche, celui d'en face
-- a droite, du cote ou son nom est deja ecrit. Sur un ecran serre, ils disparaissent — la ligne
-- de score, elle, ne se laisse jamais recouvrir (lecon de src/shared/Mise.lua).
Profil.TAILLE_MIN = 26
Profil.LARGEUR_UTILE = 260 -- en dessous, la bande centrale ne peut plus rien porter d'autre

function Profil.taille(hauteurScore)
	local h = math.floor(tonumber(hauteurScore) or 0)
	return math.max(Profil.TAILLE_MIN, math.min(44, h + 10))
end

function Profil.affichables(largeurCentre, hauteurScore)
	local l = tonumber(largeurCentre) or 0
	local h = tonumber(hauteurScore) or 0
	return l >= Profil.LARGEUR_UTILE and h > 0
end

return Profil
