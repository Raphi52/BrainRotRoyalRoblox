-- DUEL PRIVE : un code a partager, en fonctions PURES.
--
-- Pourquoi : on ne pouvait affronter QUE l'inconnu tire par la file d'attente. Jouer contre un ami
-- assis a cote de soi etait impossible — c'est pourtant la premiere chose qu'on essaie a deux.
--
-- Le code doit survivre au canal le plus pourri qui soit : lu a voix haute, tape sur un telephone,
-- recopie d'une capture d'ecran. D'ou l'alphabet de Crockford (ni I, ni L, ni O, ni U) et une
-- lecture TOLERANTE : « o » devient 0, « l » devient 1, les espaces et tirets sautent. Un ami qui
-- dit « o-deux-elle » tombe quand meme sur le bon duel.
local Prive = {}

Prive.ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ" -- 32 signes, sans I L O U
Prive.LONGUEUR = 5        -- 32^5 = 33 millions de codes : aucune collision a craindre
Prive.DUREE = 300         -- secondes de validite d'un code (5 minutes)

-- Le code n'est JAMAIS tire ici : `tirage(n)` est fourni par l'appelant (math.random cote serveur,
-- suite deterministe au banc). Ce module ne fait aucun hasard.
function Prive.code(tirage)
	local n = #Prive.ALPHABET
	local s = {}
	for i = 1, Prive.LONGUEUR do
		local k = math.max(1, math.min(math.floor(tirage(n)), n))
		s[i] = string.sub(Prive.ALPHABET, k, k)
	end
	return table.concat(s)
end

-- LECTURE TOLERANTE d'une saisie humaine. Rend le code propre, ou "" si rien d'exploitable.
function Prive.normaliser(saisie)
	if type(saisie) ~= "string" then
		return ""
	end
	local s = string.upper(saisie)
	-- confusions de lecture les plus frequentes, dans le sens de l'alphabet retenu
	s = string.gsub(s, "[IL]", "1")
	s = string.gsub(s, "O", "0")
	s = string.gsub(s, "U", "V")
	-- tout le reste (espaces, tirets, ponctuation, accents) disparait
	s = string.gsub(s, "[^0-9A-Z]", "")
	if #s > Prive.LONGUEUR then
		s = string.sub(s, 1, Prive.LONGUEUR)
	end
	return s
end

function Prive.valide(code)
	if type(code) ~= "string" or #code ~= Prive.LONGUEUR then
		return false
	end
	for i = 1, #code do
		if not string.find(Prive.ALPHABET, string.sub(code, i, i), 1, true) then
			return false
		end
	end
	return true
end

-- AFFICHAGE : coupe en deux groupes, plus facile a lire a voix haute (« K7R - 4M »).
function Prive.joli(code)
	if not Prive.valide(code) then
		return code or ""
	end
	return string.sub(code, 1, 3) .. "-" .. string.sub(code, 4)
end

-- Un code perime ne doit jamais renvoyer vers un serveur qui n'existe plus.
function Prive.expire(creeA, maintenant, duree)
	return (maintenant - creeA) > (duree or Prive.DUREE)
end

-- MOTIF DE REFUS, en clair pour le joueur (le hub l'affiche tel quel).
function Prive.motif(cas)
	if cas == "invalide" then
		return "Code invalide : 5 signes attendus."
	elseif cas == "inconnu" then
		return "Aucun duel avec ce code."
	elseif cas == "expire" then
		return "Ce code a expire : demande-lui d'en creer un autre."
	elseif cas == "studio" then
		return "Le duel prive ne marche qu'en ligne."
	elseif cas == "soi" then
		return "C'est ton propre code : partage-le a quelqu'un d'autre."
	end
	return "Duel prive indisponible pour l'instant."
end

return Prive
