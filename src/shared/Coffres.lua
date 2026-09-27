-- CE QU'IL Y A DANS UN COFFRE, en fonctions PURES.
--
-- Defaut mesure le 2026-09-21 : la rangee de coffres affiche « Coffre en bois / DEMARRER », puis
-- un compte a rebours. Nulle part le joueur ne voit ce qu'il contient — ni les pieces, ni les
-- exemplaires, ni la chance d'y trouver une carte encore verrouillee. Or il doit CHOISIR : une
-- seule ouverture tourne a la fois, et les durees vont de 15 minutes a 3 heures. Il decide donc
-- a l'aveugle quel coffre lancer avant d'aller dormir.
--
-- Les chiffres vivent cote serveur (Economie.COFFRES, Economie.EXEMPLAIRES_COFFRE) : ce module ne
-- les recopie PAS, il les met en mots. Un reglage change change la ligne affichee avec lui.
local Coffres = {}

-- DUREE lisible : « 15 min », « 1 h », « 3 h ». Les heures d'abord, parce que c'est ce qui decide
-- si on lance ce coffre maintenant ou plus tard.
function Coffres.duree(secondes)
	local s = math.max(0, math.floor(tonumber(secondes) or 0))
	if s >= 3600 then
		local h = math.floor(s / 3600)
		local reste = math.floor((s % 3600) / 60)
		if reste == 0 then
			return h .. " h"
		end
		return string.format("%d h %02d", h, reste)
	end
	return math.floor(s / 60) .. " min"
end

-- FOURCHETTE DE PIECES : « 20-40 ». Une fourchette plate (20-20) se dit d'un seul chiffre.
function Coffres.pieces(bornes)
	local a = tonumber(bornes and bornes[1]) or 0
	local b = tonumber(bornes and bornes[2]) or a
	if b <= a then
		return tostring(math.floor(a))
	end
	return math.floor(a) .. "-" .. math.floor(b)
end

-- CHANCE DE CARTE, en pourcentage entier. `1.0` devient « garantie » : « 100 % » se lit comme un
-- chiffre parmi d'autres, alors que c'est LA raison d'ouvrir un coffre d'or.
function Coffres.chance(part)
    local p = tonumber(part) or 0
	if p >= 1 then
		return "carte garantie"
	end
	if p <= 0 then
		return nil
	end
	-- Libelle COURT : la tuile de coffre fait un huitieme d'ecran, et « 10 % de nouvelle carte »
	-- y etait coupe en plein milieu (capture cap-coffres2.png du 2026-09-21).
	return math.floor(p * 100 + 0.5) .. " % carte"
end

-- LA LIGNE AFFICHEE sous le coffre. `info` = { pieces = {a, b}, exemplaires = n, chanceCarte = p,
-- duree = secondes }. Rend une chaine vide si on ne sait rien : l'ecran n'invente pas.
function Coffres.ligne(info)
	if not info then
		return ""
	end
	local bouts = { Coffres.pieces(info.pieces) .. " pieces" }
	local ex = math.floor(tonumber(info.exemplaires) or 0)
	if ex > 0 then
		-- « ex. » et non « exemplaires » : meme raison de place. Ce sont des exemplaires d'UNE
		-- carte, pas des cartes : « 3 cartes » serait faux.
		table.insert(bouts, ex .. " ex.")
	end
	local ch = Coffres.chance(info.chanceCarte)
	if ch then
		table.insert(bouts, ch)
	end
	return table.concat(bouts, " - ")
end

-- ===== EMPLACEMENTS PLEINS =====
-- Defaut mesure le 2026-09-21 : avec les 4 emplacements occupes, une victoire ne rapportait AUCUN
-- coffre (Economie.gagnerCoffre rend nil), et rien ne le disait — ni avant la partie, ni apres. Le
-- commentaire du serveur parlait d'« inciter a ouvrir ceux qu'on a » : une incitation que le joueur
-- ignore n'incite a rien, elle lui retire une recompense en silence.
function Coffres.plein(nombre, maxi)
	return (tonumber(nombre) or 0) >= (tonumber(maxi) or 4)
end

-- APRES la partie : la victoire dit ce qu'elle n'a pas rapporte, et pourquoi.
function Coffres.textePerdu()
	return "pas de coffre : emplacements pleins"
end

-- AVANT la partie, au menu : ce qu'il faut faire pour ne pas perdre le prochain.
function Coffres.alertePlein(nombre, maxi)
	if not Coffres.plein(nombre, maxi) then
		return ""
	end
	return "Emplacements pleins : ouvre un coffre, sinon ta prochaine victoire n'en rapportera pas"
end

-- UN SEUL COFFRE S'OUVRE A LA FOIS (Economie.demarrerCoffre refuse sinon « un coffre s'ouvre
-- deja »). Le bouton disait pourtant DEMARRER sur les autres : clic refuse. On dit « EN FILE ».
function Coffres.unEnCours(coffres, maintenant)
	for _, c in ipairs(coffres or {}) do
		if (c.fin or 0) ~= 0 and c.fin > maintenant then return true end
	end
	return false
end
function Coffres.etatAttente(occupe) if occupe then return "EN FILE" end return "DEMARRER" end
-- LES GEMMES SERVENT ENFIN : elles s'achetaient en Robux sans aucun usage (2026-09-21). Un coffre
-- EN COURS s'ouvre tout de suite contre 1 gemme par tranche de 10 min restante (3 h = 18).
Coffres.MINUTES_PAR_GEMME = 10
function Coffres.coutGemmes(reste)
	reste = tonumber(reste) or 0
	if reste <= 0 then return 0 end
	return math.max(1, math.ceil(reste / (Coffres.MINUTES_PAR_GEMME * 60)))
end
-- `sansGemmes` : pays ou l'ouverture contre des gemmes (article aleatoire payant) est interdite ;
-- on n'affiche alors que le temps restant, sans prix.
function Coffres.texteEnCours(reste, sansGemmes)
	local t = reste >= 3600 and string.format("%dh%02d", reste // 3600, (reste % 3600) // 60)
		or string.format("%d:%02d", reste // 60, reste % 60)
	if sansGemmes then
		return t
	end
	return t .. "  |  " .. Coffres.coutGemmes(reste) .. " gemmes"
end
-- Ce que dit le coffre EN COURS touche la ou l'ouverture contre des gemmes est interdite.
function Coffres.texteAttendre(reste)
	return "Ce coffre s'ouvre dans " .. Coffres.texteEnCours(reste, true)
		.. " (ouverture contre des gemmes indisponible dans ton pays)"
end
-- CONFIRMATION AVANT DE DEPENSER DES GEMMES : le 1er clic affiche le prix, seul un 2e clic sur le
-- MEME coffre dans les CONFIRMATION_S secondes achete. Evite l'achat par clic accidentel.
Coffres.CONFIRMATION_S = 4
function Coffres.doitConfirmer(attente, index, maintenant)
	return not (attente and attente.index == index and maintenant <= attente.jusqua)
end
function Coffres.texteConfirmer(reste) return "CONFIRMER : " .. Coffres.coutGemmes(reste) .. " gemmes" end
-- A QUOI SERVENT LES GEMMES : le jeton du bandeau affichait un chiffre sans rien expliquer.
-- `parQuete` vient de Quetes.GEMMES : la bulle dit la vraie regle, pas un texte fige.
function Coffres.texteGemmes(n, parQuete, sansOuverture)
	if sansOuverture then
		return string.format("%d gemmes : elles achetent les cosmetiques (skins, emotes). "
			.. "Gagne-en %d par quete du jour.", tonumber(n) or 0, tonumber(parQuete) or 0)
	end
	return string.format("%d gemmes : ouvrent tout de suite un coffre en cours (1 par %d min). "
		.. "Gagne-en %d par quete du jour.", tonumber(n) or 0, Coffres.MINUTES_PAR_GEMME, tonumber(parQuete) or 0)
end
-- CARTES QU'UN EXEMPLAIRE PEUT ENCORE FAIRE PROGRESSER : les exemplaires d'un coffre tombaient
-- sur n'importe quelle carte du deck, MEME au niveau maximum — gain perdu en silence
-- (Economie.ouvrirCoffre, 2026-09-21). On ne tire plus que parmi celles-ci.
function Coffres.cartesUtiles(ids, niveaux, niveauMax)
	local out = {}
	for _, id in ipairs(ids or {}) do
		if ((niveaux or {})[id] or 1) < (tonumber(niveauMax) or 5) then
			table.insert(out, id)
		end
	end
	return out
end
-- Tout le deck au maximum : les exemplaires deviennent des pieces (PIECES_PAR_EXEMPLAIRE chacun).
Coffres.PIECES_PAR_EXEMPLAIRE = 5
return Coffres
