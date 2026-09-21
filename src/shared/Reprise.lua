-- REPRISE APRES COUPURE, en fonctions PURES.
--
-- Le defaut corrige : le serveur traitait un depart et une COUPURE RESEAU de la meme facon —
-- forfait immediat, victoire a l'autre. Deux secondes de wifi perdues valaient donc une defaite
-- definitive, trophees compris. C'est la punition la plus injuste qu'un jeu en ligne puisse
-- infliger, et elle tombait sur le joueur le moins bien connecte.
--
-- Principe : un joueur qui SAUTE garde son camp pendant un delai de grace. Personne ne prend sa
-- place — ni robot, ni adversaire — et sa partie l'attend telle qu'il l'a laissee. Passe le delai,
-- alors seulement le forfait tombe.
-- PREMIERE VERSION, INCOMPLETE : « pendant son absence, l'adversaire joue seul ». Mesure le
-- 2026-09-21 en relisant la boucle de partie : le chrono continuait de tourner et les unites deja
-- posees continuaient de frapper les tours de l'absent. Au retour, il retrouvait donc une partie
-- ou il avait pris 45 secondes de degats sans pouvoir se defendre — la reprise lui rendait une
-- partie deja perdue, c'est-a-dire une promesse vide.
-- Desormais la partie se MET EN PAUSE pendant l'absence. Et parce qu'une pause est exploitable
-- (couper son reseau quand on est en difficulte), chaque joueur n'y a droit qu'UNE FOIS par
-- partie : la seconde coupure laisse la partie tourner.
local Reprise = {}

Reprise.DELAI = 45 -- secondes de grace : large pour une coupure, trop court pour aller diner

-- QUAND ouvrir une reprise plutot qu'un forfait : la partie court encore, il y a bien un
-- adversaire humain en face, et le depart n'est PAS volontaire (le bouton MENU reste un abandon).
function Reprise.permise(partieFinie, adversaireHumain, volontaire)
	if partieFinie or not adversaireHumain or volontaire then
		return false
	end
	return true
end

function Reprise.ouvrir(camp, userId, maintenant)
	return { camp = camp, userId = tostring(userId), t = maintenant }
end

function Reprise.reste(jeton, maintenant, delai)
	if not jeton then
		return 0
	end
	return math.max(0, (delai or Reprise.DELAI) - (maintenant - jeton.t))
end

function Reprise.expire(jeton, maintenant, delai)
	return Reprise.reste(jeton, maintenant, delai) <= 0
end

-- LE MEME JOUEUR, et seulement lui : un autre compte ne recupere pas un camp qui n'est pas le sien.
function Reprise.correspond(jeton, userId, maintenant, delai)
	if not jeton or Reprise.expire(jeton, maintenant, delai) then
		return false
	end
	return jeton.userId == tostring(userId)
end

-- Dans quel camp ce joueur revient-il ? nil s'il n'a rien a reprendre.
function Reprise.campDe(jetons, userId, maintenant, delai)
	for camp, jeton in pairs(jetons or {}) do
		if Reprise.correspond(jeton, userId, maintenant, delai) then
			return camp
		end
	end
	return nil
end

-- PENDANT L'ABSENCE, personne ne joue ce camp. Laisser le robot le reprendre serait pire que tout :
-- le joueur reviendrait dans une partie ou une machine a depense SON elixir et sorti SES cartes.
function Reprise.robotAutorise(jeton)
	return jeton == nil
end

-- Texte montre a l'adversaire : il doit savoir POURQUOI plus rien n'arrive en face.
-- LES DEUX EN MEME TEMPS. Cas tres ordinaire : un serveur qui tombe, une box qui redemarre, deux
-- joueurs sur le meme reseau. Mesure le 2026-09-21 en relisant le serveur, il produisait DEUX
-- injustices :
--   1. le SECOND a sauter n'avait droit a aucune reprise, parce qu'on exigeait un adversaire
--      PRESENT — or le premier venait justement de partir. Il perdait donc son camp alors qu'il
--      avait sauté exactement comme l'autre, souvent pour la meme cause ;
--   2. a l'expiration, la victoire n'etait donnee que s'il restait quelqu'un. Personne n'etant la,
--      aucune fin n'etait declenchee : la partie restait gelee indefiniment, occupant le serveur.
-- Ce qui compte n'est donc pas « l'autre est-il la MAINTENANT », mais « ce duel est-il un duel
-- entre humains » — present OU lui-meme en train de revenir.
function Reprise.duelHumain(adversairePresent, adversaireEnReprise)
	return adversairePresent == true or adversaireEnReprise == true
end

-- QUI GAGNE quand le delai d'un absent expire. Personne en face : la partie n'a pas de vainqueur.
-- On ne peut pas savoir qui l'aurait emporte, et c'est souvent le reseau — pas un joueur — qui a
-- lache : donner la victoire a l'un des deux serait tirer au sort, lui attribuer une defaite
-- serait pire.
function Reprise.vainqueurApres(campAbsent, adversairePresent)
	if adversairePresent ~= true then
		return nil -- partie annulee : aucun vainqueur, aucun trophee
	end
	return 3 - campAbsent
end

-- La partie n'a plus personne : elle doit etre rendue au serveur, sinon elle reste gelee et
-- aucun autre joueur ne peut l'utiliser.
function Reprise.partieAbandonnee(camp1Vide, camp2Vide)
	return camp1Vide == true and camp2Vide == true
end

Reprise.PAUSES_MAX = 1 -- par joueur et par partie : au-dela, couper son reseau devient une tactique

-- La partie se met en pause pour cette coupure ? Oui tant que le joueur n'a pas deja use son
-- droit. Ensuite la partie continue sans lui — son camp reste garde, mais le temps court.
function Reprise.pausePermise(dejaUtilisees)
	return (tonumber(dejaUtilisees) or 0) < Reprise.PAUSES_MAX
end

-- CE QU'ON DIT PENDANT LA PAUSE. « Adversaire deconnecte » ne suffit pas : sans le mot PAUSE, on
-- croit que son propre jeu a gele, et on quitte.
function Reprise.textePause(secondes)
	if not secondes or secondes <= 0 then
		return nil
	end
	return string.format("Partie en pause — ton adversaire a %d s pour revenir", math.ceil(secondes))
end

function Reprise.texteAbsence(secondes)
	if not secondes or secondes <= 0 then
		return nil
	end
	return string.format("Adversaire deconnecte — il a %d s pour revenir", math.ceil(secondes))
end

return Reprise
