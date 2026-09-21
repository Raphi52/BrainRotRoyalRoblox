-- SAISONS DE CLASSEMENT, en fonctions PURES.
--
-- Le defaut corrige : les trophees montaient sans fin et ne redescendaient jamais d'eux-memes. Au
-- bout de quelques semaines, le haut du classement devient inatteignable pour un nouveau, et les
-- anciens n'ont plus rien a gagner : le duel ne raconte plus rien. Une saison remet tout le monde
-- en mouvement, sans effacer ce qui a ete acquis.
--
-- TROIS DECISIONS, et elles comptent plus que le code :
--  1. REMISE A ZERO PARTIELLE. Tout remettre a zero punit le joueur assidu ; ne rien remettre fige
--     le classement. On garde donc le PLANCHER, et on ramene de moitie ce qui depasse.
--  2. RECOMPENSE SUR LE SOMMET ATTEINT, pas sur le solde final : sinon perdre trois parties la
--     derniere heure efface un mois de progression.
--  3. AUCUNE PERTE SOUS LE PLANCHER : un debutant ne recule jamais a cause d'une saison.
local Saison = {}

Saison.DUREE_JOURS = 14
Saison.PLANCHER = 600          -- en dessous, la saison ne touche a rien
Saison.PART_CONSERVEE = 0.5    -- moitie de ce qui depasse le plancher
Saison.EPOQUE = 1735689600     -- 1er janvier 2025, 00:00 UTC : origine des numeros de saison

local JOUR = 86400

function Saison.duree()
	return Saison.DUREE_JOURS * JOUR
end

-- Numero de saison en cours (1 pour la premiere). Un numero, pas une date : il tient dans le
-- profil, se compare sans fuseau horaire et ne depend d'aucune horloge locale.
function Saison.numero(maintenant)
	return math.floor(((maintenant or 0) - Saison.EPOQUE) / Saison.duree()) + 1
end

function Saison.debut(numero)
	return Saison.EPOQUE + (numero - 1) * Saison.duree()
end

function Saison.fin(numero)
	return Saison.debut(numero + 1)
end

function Saison.resteSecondes(maintenant)
	return math.max(0, Saison.fin(Saison.numero(maintenant)) - maintenant)
end

-- Temps restant en clair : « 6 j 03 h » puis « 3 h 12 min » le dernier jour. Un compte a rebours
-- en secondes ne dit rien a personne ; un « dans 6 jours » fait revenir.
function Saison.texteReste(maintenant)
	local r = Saison.resteSecondes(maintenant)
	local jours = math.floor(r / JOUR)
	local heures = math.floor((r % JOUR) / 3600)
	if jours > 0 then
		return string.format("Saison %d : %d j %02d h", Saison.numero(maintenant), jours, heures)
	end
	local minutes = math.floor((r % 3600) / 60)
	return string.format("Saison %d : %d h %02d min", Saison.numero(maintenant), heures, minutes)
end

-- REMISE A ZERO de fin de saison. Rend les trophees de depart de la saison suivante.
function Saison.apresRemiseAZero(trophees)
	local t = trophees or 0
	if t <= Saison.PLANCHER then
		return t -- un debutant ne recule jamais
	end
	return math.floor(Saison.PLANCHER + (t - Saison.PLANCHER) * Saison.PART_CONSERVEE + 0.5)
end

-- RECOMPENSE : versee sur le SOMMET atteint dans la saison, par paliers de 100 trophees au-dessus
-- du plancher. Rien en dessous du plancher : la saison ne doit pas devenir un revenu automatique.
Saison.PIECES_PAR_PALIER = 25
function Saison.recompense(sommet)
	local s = sommet or 0
	if s <= Saison.PLANCHER then
		return 0
	end
	return math.floor((s - Saison.PLANCHER) / 100) * Saison.PIECES_PAR_PALIER
end

-- BILAN DE FIN DE SAISON. Defaut mesure le 2026-09-20 : la bascule de saison a lieu au
-- CHARGEMENT du profil. Les trophees sont ramenes vers le plancher et des pieces sont versees...
-- en silence. Le joueur rouvrait le jeu avec 300 trophees de moins et un solde de pieces different,
-- sans un mot : la punition se voyait, la recompense non.
-- `bilan` = { saison, sommet, pieces, avant, apres }. Rend une liste de lignes lisibles.
function Saison.lignesBilan(bilan)
	if not bilan then
		return {}
	end
	local l = {}
	table.insert(l, "Saison " .. tostring(bilan.saison or 0) .. " terminee")
	table.insert(l, "Ton sommet : " .. math.floor(tonumber(bilan.sommet) or 0) .. " trophees")
	local pieces = math.floor(tonumber(bilan.pieces) or 0)
	if pieces > 0 then
		table.insert(l, "Recompense : " .. pieces .. " pieces")
	else
		-- Sous le plancher, la saison ne recompense pas : le dire evite de croire a un oubli.
		table.insert(l, "Recompense : aucune (sommet sous " .. Saison.PLANCHER .. " trophees)")
	end
	table.insert(l, "Trophees : " .. math.floor(tonumber(bilan.avant) or 0) .. "  ->  "
		.. math.floor(tonumber(bilan.apres) or 0))
	return l
end

-- LIGNE DE SAISON AU MENU. Defaut mesure le 2026-09-20 : le numero de saison, le temps qui reste
-- avant la remise a zero ET le SOMMET atteint etaient calcules, envoyes au menu... et affiches
-- NULLE PART. Or c'est le sommet, pas le solde du moment, qui decide la recompense de fin de
-- saison (Saison.recompense) : le joueur ne savait donc ni qu'une saison tourne, ni quand elle se
-- termine, ni ce qu'il a deja verrouille. Il decouvrait la remise a zero de ses trophees.
function Saison.texteSaison(numero, reste, sommet)
	local bouts = {}
	if reste and reste ~= "" then
		table.insert(bouts, reste)
	else
		table.insert(bouts, "Saison " .. tostring(numero or 0))
	end
	local s = tonumber(sommet) or 0
	local gain = Saison.recompense(s)
	if gain > 0 then
		table.insert(bouts, "sommet " .. math.floor(s) .. " : " .. gain .. " pieces a la fin")
	else
		table.insert(bouts, "sommet " .. math.floor(s))
	end
	return table.concat(bouts, "   -   ")
end

-- LE PASSAGE DE SAISON a-t-il eu lieu depuis la derniere visite ? `saisonProfil` est le numero
-- garde dans le profil ; nil = profil d'avant les saisons, on l'aligne sans rien remettre a zero.
function Saison.doitTourner(saisonProfil, maintenant)
	if saisonProfil == nil then
		return false
	end
	return Saison.numero(maintenant) > saisonProfil
end

-- RANG d'un joueur dans un classement deja trie (le plus fort en tete). nil s'il n'y figure pas :
-- on n'invente jamais une position.
-- RANG MONDIAL. Il se cherchait par NOM D'AFFICHAGE, qui n'est pas unique sur Roblox : deux
-- joueurs homonymes recevaient le meme rang, et l'un d'eux lisait donc le classement de l'autre.
-- On compare desormais l'IDENTIFIANT de compte, qui l'est. Le nom ne sert plus que de repli, pour
-- une entree ancienne qui n'en porterait pas.
function Saison.rang(classement, nom, id)
	for _, e in ipairs(classement or {}) do
		if id ~= nil and e.id ~= nil then
			if e.id == id then
				return e.rang
			end
		elseif e.nom == nom then
			return e.rang
		end
	end
	return nil
end

-- Ce qu'on affiche pendant le duel : « 4e mondial » ou, hors du tableau, le nombre de trophees.
function Saison.texteRang(rang, trophees)
	if rang then
		return (rang == 1) and "1er mondial" or (tostring(rang) .. "e mondial")
	end
	return string.format("%d trophees", math.floor(trophees or 0))
end

return Saison
