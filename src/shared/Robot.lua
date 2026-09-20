-- DIFFICULTE DU ROBOT : il joue comme un debutant contre un debutant, et serre le jeu contre un
-- joueur aguerri.
--
-- Defaut mesure avant ce module : le robot jouait EXACTEMENT pareil a 0 trophee et a 3000. Sa
-- FORCE suivait deja le joueur (`Economie.niveauRobot` monte le niveau de ses cartes), mais pas
-- son COMPORTEMENT : meme temps de reflexion, memes decisions, aucune erreur, des la premiere
-- partie. Monter la puissance des cartes sans toucher au comportement, c'est rendre le jeu plus
-- dur sans le rendre plus interessant — et c'est decourageant pour qui commence.
--
-- Ce module ne fait que CALCULER un profil a partir des trophees. Fonctions pures, verifiees hors
-- Studio (tools/test_robot.py) ; le serveur applique.
local Robot = {}

-- Paliers, du plus tendre au plus dur. `reflexe` = secondes entre deux decisions (plus c'est
-- grand, plus il est lent a reagir) ; `erreur` = probabilite de jouer une carte au hasard plutot
-- que la meilleure ; `gardeElixir` = elixir qu'il attend avant d'attaquer (plus bas = plus
-- agressif) ; `anticipe` = repond-il aux volants et defend-il la bonne voie.
-- `contre` : punit-il une attaque repoussee en relançant aussitot dans la voie defendue ?
-- C'est le geste qui separe un robot qui SUBIT d'un robot qui JOUE : il attaque au moment ou
-- l'adversaire vient de depenser son elixir et n'a plus rien pour repondre.
-- `economise` : garde-t-il son elixir en OUVERTURE de partie, au lieu d'ouvrir a l'aveugle ?
-- `ecart` : de combien de studs sa POSE peut-elle rater l'endroit vise ? Jusqu'ici le robot
-- posait au stud pres a tous les niveaux : seul son CHOIX de carte pouvait etre mauvais. Or la
-- faute la plus courante d'un debutant n'est pas de choisir la mauvaise carte, c'est de la poser
-- au mauvais endroit — trop loin du pont, du mauvais cote, hors de portee de la defense.
Robot.PALIERS = {
	{ seuil = 0,    nom = "debutant", reflexe = 3.2, erreur = 0.40, gardeElixir = 9, anticipe = false, contre = false, economise = false, ecart = 6 },
	{ seuil = 200,  nom = "normal",   reflexe = 2.4, erreur = 0.22, gardeElixir = 8, anticipe = true,  contre = true,  economise = true,  ecart = 3 },
	{ seuil = 600,  nom = "aguerri",  reflexe = 1.7, erreur = 0.10, gardeElixir = 7, anticipe = true,  contre = true,  economise = true,  ecart = 1.5 },
	{ seuil = 1200, nom = "expert",   reflexe = 1.1, erreur = 0.00, gardeElixir = 6, anticipe = true,  contre = true,  economise = true,  ecart = 0 },
}

-- Bornes : aucune valeur calculee ne sort de la, quoi qu'il arrive aux trophees.
Robot.REFLEXE_MIN, Robot.REFLEXE_MAX = 1.0, 3.5
Robot.ERREUR_MAX = 0.45

-- PROFIL correspondant a un nombre de trophees. Trophees absents, negatifs ou farfelus : on
-- retombe sur le palier le plus tendre, jamais sur une erreur de calcul.
function Robot.profil(trophees)
	local t = tonumber(trophees) or 0
	if t < 0 then
		t = 0
	end
	local choisi = Robot.PALIERS[1]
	for _, p in ipairs(Robot.PALIERS) do
		if t >= p.seuil then
			choisi = p
		end
	end
	return {
		nom = choisi.nom,
		contre = choisi.contre == true,
		economise = choisi.economise == true,
		ecart = choisi.ecart or 0,
		reflexe = math.clamp(choisi.reflexe, Robot.REFLEXE_MIN, Robot.REFLEXE_MAX),
		erreur = math.clamp(choisi.erreur, 0, Robot.ERREUR_MAX),
		gardeElixir = choisi.gardeElixir,
		anticipe = choisi.anticipe,
		trophees = t,
	}
end

-- Profil designe par son NOM (sert aux tests : la copie de test peut forcer un palier pour
-- verifier en moteur un comportement que les trophees d'un joueur neuf ne declenchent jamais).
function Robot.profilNomme(nom)
	for _, p in ipairs(Robot.PALIERS) do
		if p.nom == nom then
			return Robot.profil(p.seuil)
		end
	end
	return nil
end

-- Le robot se TROMPE-t-il sur ce coup-ci ? `tirage` est un nombre entre 0 et 1 fourni par
-- l'appelant (le serveur passe math.random()) : la fonction reste pure et rejouable au banc.
function Robot.seTrompe(profil, tirage)
	if not profil or (profil.erreur or 0) <= 0 then
		return false
	end
	return (tirage or 0) < profil.erreur
end

-- Delai avant la prochaine decision, avec un peu d'irregularite pour que le robot ne joue pas au
-- metronome. `tirage` entre 0 et 1 ; le resultat reste dans [reflexe, reflexe x 1,5].
function Robot.delai(profil, tirage)
	local base = (profil and profil.reflexe) or Robot.REFLEXE_MAX
	return base * (1 + 0.5 * math.clamp(tirage or 0, 0, 1))
end

-- ===== CONTRE-ATTAQUE =====
-- Defaut mesure : le robot DEFENDAIT bien mais ne punissait jamais. Une fois l'attaque repoussee,
-- il retournait a sa garde alors que l'adversaire venait de vider son elixir et n'avait plus rien
-- pour repondre. C'est precisement le moment ou une poussee passe.
Robot.FENETRE_CONTRE = 6      -- secondes pendant lesquelles la defense reste « fraiche »
Robot.MENACE_MINIMALE = 150   -- PV d'ennemis a avoir repousse pour parler de defense
Robot.RESERVE_CONTRE = 1      -- elixir garde en poche apres la carte de contre-attaque

-- Faut-il CONTRE-ATTAQUER maintenant ? `etat` :
--   menaceRepoussee : PV d'ennemis qui etaient dans sa moitie et n'y sont plus
--   survivants      : nombre de SES unites encore en vie dans sa moitie
--   depuisDefense   : secondes ecoulees depuis la fin de la defense
--   elixir / cout   : ce qu'il a, ce que couterait la carte
-- Une defense « reussie » = une vraie menace repoussee ET des survivants pour accompagner.
function Robot.contreAttaque(profil, etat)
	if not profil or not profil.contre or not etat then
		return false
	end
	if (etat.menaceRepoussee or 0) < Robot.MENACE_MINIMALE then
		return false -- il n'y avait rien a repousser : ce n'est pas une defense
	end
	if (etat.survivants or 0) <= 0 then
		return false -- echange perdu : relancer seul serait offrir la carte
	end
	local depuis = etat.depuisDefense
	if depuis == nil or depuis < 0 or depuis > Robot.FENETRE_CONTRE then
		return false -- trop tard : l'adversaire a eu le temps de refaire son elixir
	end
	return (etat.elixir or 0) >= (etat.cout or 0) + Robot.RESERVE_CONTRE
end

-- ===== OUVERTURE DE PARTIE =====
-- Defaut mesure : le robot attaquait des qu'il atteignait son seuil, y compris a la CINQUIEME
-- seconde, avec 5 elixir en tout et pour tout. Il offrait sa carte, l'adversaire repondait a
-- moindre cout, et la partie etait deja perdue pour lui. Dans ce genre de jeu, l'ouverture se
-- joue en GARDANT son elixir : on laisse l'autre s'engager le premier.
Robot.OUVERTURE_PART = 1 / 3  -- premier tiers du temps reglementaire
Robot.SUPPLEMENT_OUVERTURE = 2 -- elixir exige EN PLUS avant d'ouvrir soi-meme
Robot.ELIXIR_MAX = 10          -- plafond du jeu : un seuil au-dela rendrait le robot inerte

-- Sommes-nous encore en ouverture ? `ecoule` = secondes depuis le debut de la partie.
function Robot.enOuverture(ecoule, dureeMatch)
	local d = tonumber(dureeMatch) or 0
	local e = tonumber(ecoule) or 0
	if d <= 0 then
		return false
	end
	return e <= d * Robot.OUVERTURE_PART
end

-- ELIXIR exige avant de lancer une ATTAQUE (la defense, elle, n'est jamais bridee : un robot qui
-- economise pendant qu'on lui casse une tour serait absurde).
-- Le seuil ne depasse jamais le plafond du jeu, sinon le robot n'attaquerait plus JAMAIS.
function Robot.gardeAttaque(profil, enOuverture)
	local base = (profil and profil.gardeElixir) or Robot.ELIXIR_MAX
	if enOuverture and profil and profil.economise then
		base = base + Robot.SUPPLEMENT_OUVERTURE
	end
	return math.min(base, Robot.ELIXIR_MAX)
end

-- ===== ERREUR DE PLACEMENT =====
-- Ecart maximal, en studs, entre l'endroit vise et l'endroit reellement joue.
Robot.ECART_MAX = 8 -- plafond de securite : au-dela, la carte tomberait n'importe ou

function Robot.ecartPlacement(profil)
	local e = (profil and profil.ecart) or 0
	return math.clamp(e, 0, Robot.ECART_MAX)
end

-- DEVIATION appliquee a la pose. `tirageX` et `tirageZ` sont deux nombres entre 0 et 1 fournis
-- par l'appelant (le serveur passe math.random()) : la fonction reste pure et rejouable au banc.
-- Elle est CENTREE : un tirage a 0,5 ne devie pas du tout, et sur beaucoup de tirages la moyenne
-- tend vers zero. Sinon le robot ne ferait pas des erreurs, il aurait un BIAIS — il poserait
-- toujours du meme cote, ce qui se remarque et s'exploite.
function Robot.deviation(profil, tirageX, tirageZ)
	local ecart = Robot.ecartPlacement(profil)
	if ecart <= 0 then
		return 0, 0
	end
	local dx = (math.clamp(tirageX or 0.5, 0, 1) - 0.5) * 2 * ecart
	local dz = (math.clamp(tirageZ or 0.5, 0, 1) - 0.5) * 2 * ecart
	return dx, dz
end

return Robot
