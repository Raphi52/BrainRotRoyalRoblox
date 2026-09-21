-- SIGNALER UN JOUEUR, en fonctions PURES.
--
-- Le defaut corrige : aucun recours. Un adversaire qui spamme ses emotes, porte un nom insultant
-- ou exploite un defaut du jeu, on le subissait — et le seul geste possible etait de quitter, ce
-- qui coutait la partie. Couper les emotes (deja livre) soulage l'oreille ; cela ne SIGNALE rien.
--
-- DEUX CHOIX ASSUMES :
--  1. LISTE FERMEE de motifs, jamais de texte libre. Un champ libre dans un jeu pour enfants,
--     c'est un canal d'insultes de plus a moderer, et une promesse qu'on ne tient pas.
--  2. UN SEUL signalement par adversaire et par partie. Le bouton ne devient pas une arme :
--     marteler « signaler » ne pese pas plus lourd qu'un clic, et le dire evite d'y croire.
local Signalement = {}

-- Ordre d'affichage voulu : du plus frequent au plus rare.
Signalement.MOTIFS = {
	{ id = "emotes", libelle = "Spam d'emotes" },
	{ id = "nom", libelle = "Nom inapproprie" },
	{ id = "triche", libelle = "Triche ou defaut exploite" },
	{ id = "langage", libelle = "Langage deplace" },
}

function Signalement.motifConnu(id)
	for _, m in ipairs(Signalement.MOTIFS) do
		if m.id == id then
			return true
		end
	end
	return false
end

function Signalement.libelle(id)
	for _, m in ipairs(Signalement.MOTIFS) do
		if m.id == id then
			return m.libelle
		end
	end
	return nil
end

-- ACCEPTE-T-ON CE SIGNALEMENT ? Rend (true) ou (false, motif en clair pour le joueur).
--   cible : identifiant du joueur vise (nil = personne en face)
--   moi   : identifiant de l'auteur
--   deja  : vrai si ce joueur a deja signale CETTE cible dans CETTE partie
function Signalement.accepte(motifId, cible, moi, deja)
	if not Signalement.motifConnu(motifId) then
		return false, "Motif inconnu."
	end
	if cible == nil or cible == "" then
		return false, "Personne a signaler : tu joues contre le robot."
	end
	if tostring(cible) == tostring(moi) then
		return false, "On ne se signale pas soi-meme."
	end
	if deja then
		return false, "Deja signale pour cette partie : une fois suffit."
	end
	return true
end

-- CE QU'ON REPOND AU JOUEUR. Honnete : le signalement est ENREGISTRE, on ne promet aucune
-- sanction immediate — promettre une punition qu'on ne donne pas detruit la confiance plus
-- surement que l'absence de bouton.
function Signalement.confirmation(motifId)
	local l = Signalement.libelle(motifId)
	if not l then
		return "Motif inconnu."
	end
	return "Signalement enregistre (" .. string.lower(l) .. "). Merci : c'est relu, pas ignore."
end

-- LIGNE DE TRACE, format stable et lisible par un script. Les identifiants sont des NOMBRES de
-- compte (pas des pseudos) : un pseudo change, un identifiant non.
function Signalement.ligne(auteur, cible, motifId, horodatage, camp)
	return string.format("[SIGNALEMENT] t=%d auteur=%s cible=%s motif=%s camp=%s",
		math.floor(horodatage or 0), tostring(auteur), tostring(cible), tostring(motifId),
		tostring(camp or "-"))
end

-- CLE DE DEDOUBLONNAGE : un couple auteur -> cible, remis a zero a chaque partie.
function Signalement.cle(auteur, cible)
	return tostring(auteur) .. ">" .. tostring(cible)
end

return Signalement
