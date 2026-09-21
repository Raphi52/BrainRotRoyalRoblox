-- QUALITE DE LA CONNEXION, en fonctions PURES.
--
-- Le defaut corrige : rien ne disait au joueur que SA connexion decrochait. Une carte posee qui
-- n'apparait qu'une seconde plus tard, une unite qui saute d'un bout a l'autre — il en concluait
-- que le JEU est casse, ou pire, que l'adversaire triche. Un chiffre et un mot suffisent a lever
-- le doute, et a distinguer « mon wifi » de « leur serveur ».
--
-- Mesure honnete : un aller-retour reel (le client envoie un instant, le serveur le renvoie tel
-- quel). Pas d'estimation a partir du nombre d'images par seconde, qui melange la carte graphique
-- et le reseau.
local Reseau = {}

-- Seuils en millisecondes. Reperes : en dessous de 120 ms, une pose se sent immediate ; au-dela de
-- 250 ms, on voit son unite arriver en retard ; au-dela de 450 ms, le duel devient injouable.
Reseau.BON = 120
Reseau.MOYEN = 250
Reseau.MAUVAIS = 450
-- Au-dela de ce silence (secondes) sans nouvelle du serveur, on ne parle plus de latence mais de
-- coupure : l'etat arrive normalement 10 fois par seconde.
Reseau.SILENCE = 2
Reseau.ECHANTILLONS = 5 -- fenetre glissante

Reseau.COULEURS = {
	bon = { 120, 230, 150 },
	moyen = { 245, 205, 90 },
	mauvais = { 255, 95, 95 },
	perdu = { 255, 95, 95 },
}

function Reseau.qualite(ms)
	local m = ms or 0
	if m <= Reseau.BON then
		return "bon"
	elseif m <= Reseau.MOYEN then
		return "moyen"
	end
	return "mauvais"
end

function Reseau.couleur(qualite)
	return Reseau.COULEURS[qualite] or Reseau.COULEURS.moyen
end

-- MEDIANE et non moyenne : un seul aller-retour rate (300 ms sur cinq mesures a 40 ms) ferait
-- clignoter l'indicateur en rouge alors que la connexion va bien.
function Reseau.mediane(echantillons)
	local l = {}
	for _, v in ipairs(echantillons or {}) do
		if type(v) == "number" then
			table.insert(l, v)
		end
	end
	if #l == 0 then
		return nil
	end
	table.sort(l)
	local milieu = math.floor(#l / 2)
	if #l % 2 == 1 then
		return l[milieu + 1]
	end
	return (l[milieu] + l[milieu + 1]) / 2
end

-- La fenetre ne grossit jamais : on garde les N derniers echantillons, le plus recent en fin.
function Reseau.ajouter(echantillons, ms, combien)
	local n = combien or Reseau.ECHANTILLONS
	local l = {}
	for _, v in ipairs(echantillons or {}) do
		table.insert(l, v)
	end
	table.insert(l, ms)
	while #l > n do
		table.remove(l, 1)
	end
	return l
end

-- INSTABLE : ce n'est pas « lent », c'est « irregulier ». Un aller-retour qui passe de 40 a 400 ms
-- gene bien plus qu'un 200 ms constant, et c'est l'ECART qui le dit.
Reseau.ECART_INSTABLE = 150
function Reseau.instable(echantillons)
	local l = echantillons or {}
	if #l < 3 then
		return false -- trop peu de mesures : on n'accuse pas la connexion sans preuve
	end
	local mini, maxi = math.huge, -math.huge
	for _, v in ipairs(l) do
		mini = math.min(mini, v)
		maxi = math.max(maxi, v)
	end
	return (maxi - mini) >= Reseau.ECART_INSTABLE
end

-- SILENCE DU SERVEUR : plus aucun etat recu depuis trop longtemps.
function Reseau.perdu(depuisDernierEtat, seuil)
	return (depuisDernierEtat or 0) >= (seuil or Reseau.SILENCE)
end

function Reseau.texte(ms)
	if ms == nil then
		return "-- ms"
	end
	return string.format("%d ms", math.floor(ms + 0.5))
end

-- L'AVERTISSEMENT, en clair et sans accusation : le joueur doit savoir si ca vient de chez lui.
-- Rend nil quand tout va bien : pas de bandeau permanent qui inquiete pour rien.
function Reseau.avertissement(ms, instable, perdu)
	if perdu then
		return "Connexion perdue — tentative de reprise..."
	end
	if instable then
		return "Connexion instable : tes poses peuvent arriver en retard."
	end
	if ms and Reseau.qualite(ms) == "mauvais" then
		return "Connexion lente : verifie ton wifi."
	end
	return nil
end

return Reseau
