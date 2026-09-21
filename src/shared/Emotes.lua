-- EMOTES RAPIDES, en fonctions PURES.
--
-- Pourquoi ce module : la liste des emotes existait EN DEUX EXEMPLAIRES — une dans le serveur,
-- une dans le client. Deux sources de verite pour la meme chose : ajouter une emote d'un seul cote
-- donnait un bouton que le serveur refuse, ou une emote inatteignable. Elles vivent ici.
--
-- Deux manques de l'audit traites ici :
--  1. AUCUN SALUT D'OUVERTURE. Le duel commencait sans un mot : deux inconnus, aucun echange,
--     aucune raison de se souvenir de l'autre. Une fenetre de salut au coup d'envoi suffit.
--  2. LA BULLE MOURAIT AVEC LA TOUR DU ROI. Elle y etait accrochee : Roi detruit, plus aucune
--     emote — exactement au moment ou l'on veut dire « bien joue ». La regle d'ancrage est ici.
local Emotes = {}

Emotes.DELAI = 3 -- secondes minimum entre deux emotes du meme joueur

-- LISTE FERMEE, dans l'ordre d'affichage. Le client envoie un IDENTIFIANT, jamais du texte : rien
-- a moderer, et aucune surprise possible.
Emotes.LISTE = {
	{ id = "salut", libelle = "Salut", texte = "Salut !" },
	{ id = "gg", libelle = "GG", texte = "GG !" },
	{ id = "rire", libelle = "HAHA", texte = "HAHA" },
	{ id = "bravo", libelle = "Bravo", texte = "Bien joue" },
	{ id = "oups", libelle = "Oups", texte = "Oups !" },
	-- PREMIUM (2026-09-21) : achetees en gemmes dans l'ecran COSMETIQUES (module Cosmetiques).
	-- Le serveur refuse une emote premium que le joueur ne possede pas.
	{ id = "tralalero", libelle = "TRA", texte = "TRALALERO TRALALA !", prix = 40 },
	{ id = "tungtung", libelle = "TUNG", texte = "TUNG TUNG TUNG SAHUR !", prix = 40 },
	{ id = "roi", libelle = "ROI", texte = "Le roi, c'est moi !", prix = 60 },
}

Emotes.SALUT = "salut"
-- Fenetre pendant laquelle le jeu INVITE a saluer, en secondes de jeu. Au-dela, on ne propose plus
-- rien : un rappel permanent serait du harcelement, pas une politesse.
Emotes.FENETRE_SALUT = 8

function Emotes.connue(id)
	return Emotes.texte(id) ~= nil
end

function Emotes.texte(id)
	for _, e in ipairs(Emotes.LISTE) do
		if e.id == id then
			return e.texte
		end
	end
	return nil
end

function Emotes.libelle(id)
	for _, e in ipairs(Emotes.LISTE) do
		if e.id == id then
			return e.libelle
		end
	end
	return nil
end

-- COMBIEN DE TEMPS RESTE-T-IL AVANT DE POUVOIR EN RENVOYER UNE ?
--
-- Defaut mesure le 2026-09-21 : le serveur refusait l'emote trop rapprochee EN SILENCE (aucun
-- retour, aucun son, aucune bulle). Le joueur voyait un bouton qui ne fait rien et re-cliquait,
-- en croyant le jeu casse. La regle du delai existait ici, mais l'ecran ne la connaissait pas.
--
-- Rend 0 quand l'emote est possible tout de suite.
function Emotes.resteAvant(derniere, maintenant)
	if derniere == nil then
		return 0
	end
	local d = (tonumber(maintenant) or 0) - (tonumber(derniere) or 0)
	local reste = Emotes.DELAI - d
	if reste <= 0 then
		return 0
	end
	return reste
end

-- CE QU'ON DIT AU JOUEUR quand il insiste. Arrondi au SUPERIEUR : annoncer « 0 s » alors que le
-- bouton refuse encore serait pire que ne rien dire.
function Emotes.texteAttente(reste)
	local r = math.ceil(tonumber(reste) or 0)
	if r <= 0 then
		return ""
	end
	return "Encore " .. r .. " s avant la prochaine emote"
end

-- Emote connue ET delai respecte. `derniere` = instant de la precedente (nil = jamais).
function Emotes.autorisee(id, derniere, maintenant)
	if type(id) ~= "string" or not Emotes.connue(id) then
		return false
	end
	return derniere == nil or (maintenant - derniere) >= Emotes.DELAI
end

-- INVITATION A SALUER : seulement au tout debut, seulement face a un HUMAIN (saluer une machine
-- n'a aucun sens), et seulement si l'on n'a pas deja salue.
function Emotes.inviteSalut(tempsDeJeu, adversaireHumain, dejaSalue)
	if not adversaireHumain or dejaSalue then
		return nil
	end
	if (tempsDeJeu or 0) > Emotes.FENETRE_SALUT then
		return nil
	end
	return "Dis bonjour a ton adversaire !"
end

-- OU ACCROCHER LA BULLE. La tour du Roi disparait quand elle tombe, et la bulle avec elle : plus
-- aucune emote au moment exact ou l'on veut dire « bien joue ». On accroche donc a une ancre qui
-- SURVIT, et la tour ne sert que de repere de position.
Emotes.ANCRE = "AncreEmote"
function Emotes.ancrePermise(ancreExiste, tourVivante)
	-- vrai = on peut afficher. Seule l'absence des DEUX interdit l'emote.
	return ancreExiste == true or tourVivante == true
end

return Emotes
