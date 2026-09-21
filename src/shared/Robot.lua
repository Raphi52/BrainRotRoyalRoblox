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
-- que la meilleure ; `gardeElixir` = elixir qu'il attend avant d'attaquer. ATTENTION au sens :
-- plus bas = plus agressif, mais l'agressivite est une FAIBLESSE mesuree (r = +0,98 entre ce
-- seuil et les victoires) — un robot qui engage tot descend a sec et subit la riposte. Ce seuil
-- MONTE donc avec le niveau ; `anticipe` = repond-il aux volants et defend-il la bonne voie.
-- `contre` : punit-il une attaque repoussee en relançant aussitot dans la voie defendue ?
-- C'est le geste qui separe un robot qui SUBIT d'un robot qui JOUE : il attaque au moment ou
-- l'adversaire vient de depenser son elixir et n'a plus rien pour repondre.
-- `economise` : garde-t-il son elixir en OUVERTURE de partie, au lieu d'ouvrir a l'aveugle ?
-- `ecart` : de combien de studs sa POSE peut-elle rater l'endroit vise ? Jusqu'ici le robot
-- posait au stud pres a tous les niveaux : seul son CHOIX de carte pouvait etre mauvais. Or la
-- faute la plus courante d'un debutant n'est pas de choisir la mauvaise carte, c'est de la poser
-- au mauvais endroit — trop loin du pont, du mauvais cote, hors de portee de la defense.
-- GARDE-ELIXIR : ATTENTION, ce reglage etait INVERSE, et il dominait tous les autres.
-- Mesure du 2026-09-21, 120 parties, les six duels de paliers deux a deux :
--     debutant 35 victoires | normal 33 | aguerri 27 | expert 25   (sur 60 chacun)
-- soit l'INVERSE EXACT de l'ordre voulu, et le palier « superieur » ne gagnait que 43 % de ses
-- parties. La cause tient en une correlation : entre le seuil d'attaque et les victoires,
-- r = +0,98. Plus un robot attaque TOT, plus il PERD — il descend a sec et subit la riposte
-- (voir Reserve.lua). L'ancienne progression donnait 9 au debutant et 6 a l'expert : on croyait
-- rendre l'expert « plus agressif », on le rendait imprudent, et cette imprudence annulait son
-- meilleur temps de reflexion et son absence d'erreurs.
-- Depuis : le seuil MONTE avec le niveau. L'imprudence appartient au debutant (6), la patience
-- a l'expert (9) — ce qui decrit aussi bien mieux ce que fait un joueur qui progresse.
-- LECTURE DE L'ELIXIR ADVERSE (`lecture`, de 0 a 1). Ajoutee le 2026-09-21 apres mesure : une
-- fois le seuil d'attaque remis a l'endroit, les trois paliers hauts se valaient TOUJOURS
-- (aguerri 32 victoires, normal 31, expert 30 sur 60 parties chacun). Normal, ce sont les memes
-- capacites : `anticipe`, `contre` et `economise` sont a `true` pour les trois, et le temps de
-- reflexion ne change rien — les trois posent le meme nombre de cartes par seconde, parce que le
-- jeu est limite par l'ELIXIR, pas par la vitesse de decision.
-- Il fallait donc une COMPETENCE que les faibles n'ont pas : lire l'elixir adverse et pousser
-- quand il est a sec (Fenetre.lua). Le jeu offre deja cette lecture au JOUEUR ; le robot ne la
-- regardait pas. 0 = ne regarde pas · 0,6 = se trompe de deux elixir · 1 = lit juste.
-- LA VITESSE NE SEPARE PLUS LES PALIERS — c'est elle qui faisait perdre l'expert.
-- Experience decisive du 2026-09-21, duel normal contre expert, 60 parties par reglage, alternance
-- des cotes verifiee :
--     expert PATIENT   (seuil 9), reflexion 1,1 s  -> 35 % de victoires
--     expert AGRESSIF  (seuil 5), reflexion 1,1 s  -> 42 %   (ecart avec le precedent : p = 0,57)
--     expert           (seuil 9), reflexion 2,4 s  -> **67 %**, p = 0,013
-- Le seuil d'attaque ne decidait donc RIEN : patient ou agressif, l'expert perdait. La seule chose
-- constante dans ses defaites etait sa vitesse — et la ramener a celle du normal suffit a le rendre
-- nettement superieur. Un robot qui reflechit trop vite reagit a tout, se disperse, et perd.
-- Attention, une conclusion anterieure etait FAUSSE : « la patience gagne, r = +0,98 ». Elle
-- reposait sur des duels mesures AVANT la reparation de l'alternance des cotes, donc biaises.
-- Les paliers hauts partagent desormais la meme reflexion (2,4 s) et se separent par ce qui
-- rapporte vraiment : moins d'erreurs, un placement plus juste, et la lecture de l'adversaire.
-- ECONOMISER EN OUVERTURE : GARDE pour les paliers hauts, apres un essai de retrait MESURE.
-- La sonde a une variable disait : un debutant qui n'economise pas bat le normal 41-19. Mais
-- retirer ce trait aux TROIS paliers hauts (2026-09-21, 60 parties par duel) a donne :
--     debutant vs normal : le normal passe de 45 % a 53 %   (p = 0,70, gain non etabli)
--     normal vs expert   : l'expert CHUTE de 67 % a 37 %     (p = 0,052)
-- Le retrait profite surtout au palier dont le seuil est bas (le normal) ; l'expert, lui, reste
-- borne par sa lecture de l'adversaire et le plafond d'elixir. Effet d'une variable sur UN palier
-- ne predit pas l'effet de la meme variable retiree a tous. Reglage d'origine restaure.
Robot.PALIERS = {
	{ seuil = 0,    nom = "debutant", reflexe = 3.2, erreur = 0.40, gardeElixir = 6, anticipe = false, contre = false, economise = false, ecart = 6,   lecture = 0 },
	{ seuil = 200,  nom = "normal",   reflexe = 2.4, erreur = 0.22, gardeElixir = 7, anticipe = true,  contre = true,  economise = true,  ecart = 3,   lecture = 0 },
	{ seuil = 600,  nom = "aguerri",  reflexe = 2.4, erreur = 0.10, gardeElixir = 8, anticipe = true,  contre = true,  economise = true,  ecart = 1.5, lecture = 0.6 },
	{ seuil = 1200, nom = "expert",   reflexe = 2.4, erreur = 0.00, gardeElixir = 9, anticipe = true,  contre = true,  economise = true,  ecart = 0,   lecture = 1 },
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
		lecture = choisi.lecture or 0,
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

-- ===== DUEL DE PALIERS (banc de mesure) =====
-- Pour verifier que les quatre paliers sont bien CLASSES PAR FORCE, il faut les faire s'affronter
-- deux a deux : un palier par camp. `BRR_ROBOT` acceptait un seul nom, donc les deux camps
-- jouaient toujours au meme niveau et le classement n'avait jamais ete verifie.
--
-- Forme acceptee : "normal:expert" — le premier nom pour un camp, le second pour l'autre.
-- Un nom seul ("expert") garde l'ancien comportement : les deux camps au meme palier.
--
-- ALTERNANCE. Le camp qui porte le premier palier CHANGE a chaque partie, exactement comme le
-- camp « fort » de la simulation de niveaux. Sans cela on mesurerait la force du palier ET
-- l'avantage du cote dans le meme chiffre, sans pouvoir les separer — c'est precisement l'erreur
-- que la serie du 2026-09-20 a failli faire dire au jeu.
-- Rend : nom du palier pour ce camp (ou nil si la valeur ne decrit pas un duel).
function Robot.paliersDuel(valeur, camp, partie)
	if type(valeur) ~= "string" then
		return nil
	end
	local a, b = string.match(valeur, "^(%w+):(%w+)$")
	if not a or not b then
		return nil
	end
	-- partie impaire : le palier `a` tient le camp 1 ; partie paire : il passe au camp 2.
	local premierCamp = ((tonumber(partie) or 1) % 2 == 1) and 1 or 2
	if camp == premierCamp then
		return a
	end
	return b
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
