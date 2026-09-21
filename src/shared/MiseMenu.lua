-- MISE EN PAGE DU MENU D'ACCUEIL, en donnees PURES.
--
-- Le defaut corrige (capture du 2026-09-21) : la rangee de coffres avait ete agrandie et remontee
-- « dans l'espace libre sous JOUER ». Cet espace n'etait PAS libre : le duel prive (DUEL PRIVE,
-- CODE AMI, REJOINDRE, NIVEAUX EGALISES) et « SI PERSONNE : ROBOT » y vivaient deja, et se sont
-- retrouves SOUS les coffres — a moitie caches, a peine cliquables. Les positions etaient ecrites
-- a la main, bloc par bloc : chaque ajout repoussait le voisin sans que rien ne le verifie.
--
-- Ici les positions sont une DONNEE, en fraction de l'ecran d'accueil (x, y, largeur, hauteur).
-- tools/test_menu.py les confronte a TOUT ce qui est pose sur l'accueil et refuse le moindre
-- recouvrement entre deux blocs visibles en meme temps. Le menu se contente d'appliquer.
--
-- Trois decisions, et leur raison :
--  - LE DUEL ENTRE AMIS devient UN bouton qui ouvre un panneau. Ses cinq controles, toujours
--    visibles au centre de l'accueil, n'y tenaient pas a cote de JOUER et des coffres. Ils ne
--    servent qu'a qui veut affronter un ami : ils peuvent attendre un clic.
--  - « SI PERSONNE : ROBOT » reste TOUJOURS visible, a droite de JOUER dont il est l'option. Premiere
--    idee ecartee en relisant le code : le montrer seulement pendant la recherche. Or ce choix est
--    lu AU CLIC sur JOUER (Hub.client.lua, `attendreHumain`) : le cacher au repos aurait supprime
--    la fonction elle-meme.
--  - Les lignes d'information (saison, arene, bilan, coffre gratuit) sont bornees a la colonne
--    centrale. Leur cadre allait de 0,10 a 0,90 et passait SOUS la colonne de boutons de droite :
--    invisible tant que le texte est court, mais un nom d'arene plus long s'y serait ecrit.
local MiseMenu = {}

local function r(x, y, l, h)
	return { x = x, y = y, l = l, h = h }
end

-- Colonne centrale : entre la colonne de gauche (0,02-0,20) et celle de droite (0,79-0,98).
MiseMenu.CENTRE_X, MiseMenu.CENTRE_L = 0.22, 0.56

MiseMenu.ACCUEIL = {
	-- lignes d'information, bornees a la colonne centrale
	saison = r(0.22, 0.192, 0.56, 0.03),
	arene = r(0.22, 0.222, 0.56, 0.035),
	info = r(0.22, 0.29, 0.56, 0.035),
	coffreLigne = r(0.22, 0.325, 0.56, 0.035),
	-- JOUER, et ce qui le remplace pendant la recherche (etats exclusifs : meme place)
	jouer = r(0.33, 0.37, 0.34, 0.12),
	annuler = r(0.33, 0.37, 0.165, 0.06),
	robotVite = r(0.505, 0.37, 0.165, 0.06),
	patience = r(0.69, 0.41, 0.22, 0.045), -- a droite de JOUER : visible au repos comme en recherche
	-- message ponctuel (refus, attente), juste sous JOUER
	message = r(0.22, 0.495, 0.56, 0.035),
	-- coffres : gardent l'essentiel de leur hauteur (0,265 contre 0,28), qui les rendait lisibles
	coffres = r(0.15, 0.535, 0.70, 0.265),
	-- LE PERSONNAGE VEDETTE, en grand, dans la colonne de gauche restee vide au-dessus du duel
	-- entre amis : c'est l'ecran qui doit donner envie, il montrait du texte et des boutons.
	vedette = r(0.02, 0.07, 0.18, 0.25),
	-- LIGUE (2026-09-21) : badge + nom + palier, sous la vedette (raccourcie de 0,31 a 0,25 pour
	-- lui faire place : la colonne centrale n'avait plus une ligne libre).
	ligue = r(0.02, 0.33, 0.18, 0.06),
	-- PASS DE SAISON : sous le duel entre amis, colonne de gauche (les coffres partent a 0,15)
	pass = r(0.02, 0.48, 0.12, 0.045),
	-- le bouton qui ouvre le panneau des amis, dans la colonne de gauche
	duelAmis = r(0.02, 0.40, 0.18, 0.07),
	-- le panneau lui-meme (une fenetre : il passe devant l'accueil quand il est ouvert). Il
	-- s'arrete AU-DESSUS de la ligne de message : c'est la que s'ecrit la reponse du serveur
	-- (« Code accepte », « Code refuse ») — couverte, le joueur ne saurait jamais si ca a marche.
	panneauAmis = r(0.29, 0.07, 0.42, 0.42),
}

-- Controles DANS le panneau des amis, en fraction du panneau.
MiseMenu.PANNEAU = {
	titre = r(0.05, 0.03, 0.78, 0.12),
	fermer = r(0.85, 0.03, 0.12, 0.12),
	prive = r(0.08, 0.20, 0.84, 0.13),
	codeAffiche = r(0.08, 0.36, 0.84, 0.10),
	code = r(0.08, 0.50, 0.52, 0.13),
	rejoindre = r(0.63, 0.50, 0.29, 0.13),
	egalise = r(0.08, 0.72, 0.84, 0.12),
	-- ce que le duel met en jeu : sous l'interrupteur, dans le bas du panneau reste vide
	aide = r(0.05, 0.86, 0.90, 0.12),
}

-- APPLIQUER un rectangle a un objet d'interface. Le constructeur UDim2 est PASSE en argument :
-- ce module reste pur (aucune fonction Roblox), donc lisible et verifiable hors du jeu.
function MiseMenu.placer(objet, b, fabrique)
	objet.Position = fabrique.new(b.x, 0, b.y, 0)
	objet.Size = fabrique.new(b.l, 0, b.h, 0)
end

return MiseMenu
