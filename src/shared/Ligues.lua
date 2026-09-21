-- LIGUES COMPETITIVES (2026-09-21). Les arenes s'arretent a 2000 trophees : au-dela, plus rien a
-- viser, et la remise a zero de saison (Saison.lua) tombait sans qu'on sache ce qu'elle retirait.
-- Une LIGUE nomme le niveau competitif, avec un BADGE (couleur + lettre) et un prochain palier.
-- Elles commencent au PLANCHER de saison : tout ce qui est en ligue est ce que la saison remet en jeu.
-- Module pur (teste par tools/test_ligues.py) : aucune instance Roblox.
local Ligues = {}

-- couleurs en { r, g, b } : le module reste executable hors Roblox
Ligues.LISTE = {
	{ seuil = 600,  nom = "Bronze",   lettre = "B", couleur = { 205, 127, 50 } },
	{ seuil = 1000, nom = "Argent",   lettre = "A", couleur = { 192, 200, 215 } },
	{ seuil = 1500, nom = "Or",       lettre = "O", couleur = { 255, 200, 60 } },
	{ seuil = 2200, nom = "Platine",  lettre = "P", couleur = { 90, 220, 200 } },
	{ seuil = 3000, nom = "Diamant",  lettre = "D", couleur = { 110, 170, 255 } },
	{ seuil = 4000, nom = "Maitre",   lettre = "M", couleur = { 190, 110, 255 } },
	{ seuil = 5000, nom = "Champion", lettre = "C", couleur = { 255, 90, 90 } },
	{ seuil = 6500, nom = "Legende",  lettre = "L", couleur = { 255, 235, 140 } },
}
Ligues.SANS = { seuil = 0, nom = "Sans ligue", lettre = "?", couleur = { 110, 118, 140 } }

-- 0 = sans ligue, sinon rang dans LISTE
function Ligues.index(trophees)
	local t = tonumber(trophees) or 0
	local i = 0
	for k, l in ipairs(Ligues.LISTE) do
		if t >= l.seuil then
			i = k
		end
	end
	return i
end

function Ligues.actuelle(trophees)
	local i = Ligues.index(trophees)
	return i == 0 and Ligues.SANS or Ligues.LISTE[i]
end

function Ligues.suivante(trophees)
	return Ligues.LISTE[Ligues.index(trophees) + 1]
end

-- Texte court du hub : « Ligue Or  1640 / 2200 », ou le seuil d'entree.
function Ligues.texte(trophees)
	local t = math.floor(tonumber(trophees) or 0)
	local i = Ligues.index(t)
	local s = Ligues.suivante(t)
	if i == 0 then
		-- court : le hub l'affiche sur une petite ligne (« Ligues a 600 trophees (0 / 600) » y
		-- devenait illisible, capture du 2026-09-21). Le nom et le palier sont separes par 2 espaces.
		return "Sans ligue  " .. t .. " / " .. s.seuil
	end
	local nom = "Ligue " .. Ligues.LISTE[i].nom
	return s and (nom .. "  " .. t .. " / " .. s.seuil) or (nom .. "  " .. t .. "  (sommet)")
end

-- Ligne d'ecran de fin : promotion ou relegation, rien si la ligue ne change pas.
function Ligues.changement(avant, apres)
	local a, b = Ligues.index(avant), Ligues.index(apres)
	if b > a then
		return "PROMOTION : Ligue " .. Ligues.LISTE[b].nom .. " !"
	elseif b < a then
		return "Relegation : " .. (b == 0 and "hors ligue" or ("Ligue " .. Ligues.LISTE[b].nom))
	end
	return nil
end

-- Ligne du bilan de saison : ce que la remise a zero a change a la ligue.
function Ligues.ligneSaison(avant, apres)
	local a, b = Ligues.actuelle(avant), Ligues.actuelle(apres)
	if a == b then
		return "Ligue : " .. a.nom .. " (conservee)"
	end
	return "Ligue : " .. a.nom .. "  ->  " .. b.nom
end

return Ligues
