-- RAPPEL DU COFFRE GRATUIT, en fonctions PURES.
--
-- Defaut mesure le 2026-09-20 : un coffre est offert toutes les 4 h, mais RIEN ne le signalait.
-- L'information n'existait qu'au fond de l'onglet EVENEMENTS, sur une ligne qu'il faut penser a
-- aller lire. Un joueur qui enchaine des parties depuis l'accueil pouvait laisser passer plusieurs
-- coffres dans la meme session sans jamais savoir qu'ils l'attendaient — c'est pourtant le
-- rendez-vous court qui est cense faire revenir dans la journee.
--
-- Ici : l'accueil le dit, et l'onglet EVENEMENTS porte une pastille tant que le coffre est la.
-- Aucune API Roblox : tools/test_rappel.py rejoue tout hors Studio.
local Rappel = {}

Rappel.COULEUR_PRET = { 255, 190, 70 }
Rappel.COULEUR_ATTENTE = { 150, 158, 176 }

-- Le coffre est-il disponible MAINTENANT ? `reste` est le nombre de secondes d'attente rendu par
-- le serveur (Economie.attenteCoffreGratuit), 0 = disponible.
function Rappel.pret(reste)
	return (tonumber(reste) or 0) <= 0
end

-- ATTENTE LISIBLE. Les heures d'abord (« 3h07 »), puis les minutes, puis « moins d'une minute » :
-- « 0h00 » sur 30 secondes laisserait croire que le coffre est deja la.
function Rappel.attente(reste)
	local r = math.max(0, math.floor(tonumber(reste) or 0))
	if r >= 3600 then
		return string.format("%dh%02d", math.floor(r / 3600), math.floor((r % 3600) / 60))
	elseif r >= 60 then
		return math.floor(r / 60) .. " min"
	end
	return "moins d'une minute"
end

-- LA LIGNE AFFICHEE A L'ACCUEIL. Quand le coffre est la, elle dit OU aller le prendre : sans cela
-- le joueur sait qu'il a quelque chose, mais pas ou.
-- `plein` : les 4 emplacements sont occupes. Le serveur refuse alors le coffre gratuit
-- (« emplacements pleins ») : on ne peut pas envoyer le joueur le chercher (2026-09-21).
function Rappel.texte(reste, typeCoffre, plein)
	if Rappel.pret(reste) and plein then
		return "COFFRE GRATUIT pret, mais emplacements pleins : ouvre d'abord un coffre"
	end
	if Rappel.pret(reste) then
		return "COFFRE GRATUIT : un coffre d'" .. tostring(typeCoffre or "argent")
			.. " t'attend dans EVENEMENTS"
	end
	return "Coffre gratuit dans " .. Rappel.attente(reste)
end

function Rappel.teinte(reste)
	if Rappel.pret(reste) then
		return Rappel.COULEUR_PRET
	end
	return Rappel.COULEUR_ATTENTE
end

-- COMBIEN DE CHOSES A PRENDRE dans l'onglet EVENEMENTS : le coffre gratuit s'il est la, PLUS
-- chaque quete du jour terminee et pas encore reclamee, PLUS le bonus du jour s'il n'a pas ete
-- pris. Aucune de ces trois recompenses ne se verse toute seule — sans ce compte, le joueur
-- laissait des pieces sur place faute de savoir qu'elles l'attendaient.
-- `quetes` est la liste rendue par le serveur : chaque entree porte `finie` et `recue`.
-- `bonusDispo` est le champ du meme nom dans la vue du profil.
-- `plein` : 4 emplacements occupes. Le coffre gratuit est alors REFUSE : il ne compte pas.
function Rappel.aPrendre(reste, quetes, bonusDispo, plein)
	local n = (Rappel.pret(reste) and not plein) and 1 or 0
	if bonusDispo then
		n = n + 1
	end
	for _, q in ipairs(quetes or {}) do
		if q.finie and not q.recue then
			n = n + 1
		end
	end
	return n
end

-- PASTILLE sur l'onglet EVENEMENTS : elle n'apparait QUE quand il y a quelque chose a prendre.
-- Une pastille permanente ne veut plus rien dire.
function Rappel.pastille(reste, quetes, bonusDispo, plein)
	return Rappel.aPrendre(reste, quetes, bonusDispo, plein) > 0
end

-- CHIFFRE affiche dans la pastille. Un point d'exclamation disait « il y a quelque chose » ;
-- le chiffre dit COMBIEN, donc s'il vaut la peine d'aller voir maintenant. Plafonne a « 9+ »
-- pour tenir dans une pastille de 18 pixels.
function Rappel.compte(reste, quetes, bonusDispo, plein)
	local n = Rappel.aPrendre(reste, quetes, bonusDispo, plein)
	if n > 9 then
		return "9+"
	end
	return tostring(n)
end

return Rappel
