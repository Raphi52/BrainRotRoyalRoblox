-- HABILLAGE DE L'ARENE, en fonctions PURES.
--
-- Le defaut corrige : tous les duels se jouaient sur EXACTEMENT le meme terrain, avec le meme
-- decor, la meme lumiere et les memes arbres aux memes endroits. Au bout de dix parties, on ne
-- voit plus l'arene — et rien ne distingue un duel d'un autre dans le souvenir.
--
-- LA REGLE ABSOLUE DE CE MODULE, ET LE BANC LA FAIT RESPECTER : il ne decrit QUE de l'apparence.
-- Aucune dimension, aucune position, aucune portee, aucune vitesse. Une arene qui change de
-- GEOMETRIE d'un duel a l'autre serait injouable : les reperes de pose, les couloirs et la portee
-- des tours font partie des regles. Ici on ne change que ce qui se REGARDE.
local Decor = {}

-- CLES AUTORISEES dans un theme. Le banc verifie qu'aucune autre n'apparait : c'est le garde-fou
-- qui empeche, dans six mois, d'y glisser « largeurPont » sans s'en rendre compte.
Decor.CLES = {
	id = true, nom = true, herbeProche = true, herbeLoin = true, exterieur = true,
	eau = true, pierre = true, bois = true, allee = true, feuillage = true, rocher = true,
	heure = true, brume = true, teinte = true, brumeCouleur = true, brumeFond = true,
}

-- PLAFOND DE BRUME. Mesure a l'ecran (capture du 2026-09-20) : a 0,55 de densite, l'atmosphere
-- NOIE toute la scene — sol, tours et unites prenaient la teinte de la brume, et le decor
-- « Terres brulees » sortait bleu pale. Au-dela de cette valeur, on ne montre plus un decor, on
-- pose un voile.
Decor.BRUME_MAX = 0.4

-- `heure` : ClockTime de Roblox (position du soleil). `brume` : densite d'atmosphere.
-- `teinte` : saturation ajoutee. Trois reglages de lumiere, zero effet sur le jeu.
Decor.THEMES = {
	{
		id = "prairie", nom = "Prairie",
		herbeProche = { 90, 170, 80 }, herbeLoin = { 80, 150, 70 }, exterieur = { 55, 105, 50 },
		eau = { 60, 140, 220 }, pierre = { 150, 145, 135 }, bois = { 110, 75, 45 },
		allee = { 170, 135, 90 }, feuillage = { 60, 145, 60 }, rocher = { 125, 125, 130 },
		brumeCouleur = { 210, 220, 235 }, brumeFond = { 160, 175, 200 },
		heure = 15.5, brume = 0.26, teinte = 0.18,
	},
	{
		id = "couchant", nom = "Vallee du couchant",
		herbeProche = { 120, 150, 75 }, herbeLoin = { 105, 130, 65 }, exterieur = { 85, 95, 45 },
		eau = { 90, 130, 205 }, pierre = { 175, 150, 120 }, bois = { 125, 80, 40 },
		allee = { 195, 150, 95 }, feuillage = { 150, 130, 55 }, rocher = { 150, 135, 120 },
		brumeCouleur = { 245, 215, 180 }, brumeFond = { 200, 150, 110 },
		heure = 17.4, brume = 0.30, teinte = 0.26,
	},
	{
		id = "neige", nom = "Plateau gele",
		herbeProche = { 215, 228, 240 }, herbeLoin = { 195, 210, 228 }, exterieur = { 170, 190, 210 },
		eau = { 120, 200, 235 }, pierre = { 190, 195, 205 }, bois = { 95, 80, 70 },
		allee = { 200, 205, 215 }, feuillage = { 200, 215, 225 }, rocher = { 165, 175, 190 },
		brumeCouleur = { 235, 244, 252 }, brumeFond = { 190, 210, 230 },
		heure = 13.0, brume = 0.34, teinte = 0.05,
	},
	{
		id = "volcan", nom = "Terres brulees",
		herbeProche = { 105, 85, 70 }, herbeLoin = { 90, 70, 58 }, exterieur = { 70, 52, 45 },
		eau = { 220, 110, 50 }, pierre = { 95, 85, 85 }, bois = { 80, 55, 40 },
		allee = { 130, 95, 70 }, feuillage = { 120, 75, 50 }, rocher = { 85, 78, 78 },
		brumeCouleur = { 235, 180, 150 }, brumeFond = { 150, 95, 75 },
		heure = 19.2, brume = 0.32, teinte = 0.3,
	},
	{
		id = "nuit", nom = "Arene de nuit",
		herbeProche = { 60, 95, 85 }, herbeLoin = { 50, 82, 75 }, exterieur = { 35, 55, 55 },
		eau = { 70, 130, 200 }, pierre = { 110, 115, 130 }, bois = { 75, 60, 50 },
		allee = { 115, 105, 90 }, feuillage = { 55, 100, 85 }, rocher = { 95, 100, 115 },
		brumeCouleur = { 120, 150, 200 }, brumeFond = { 60, 80, 120 },
		heure = 4.6, brume = 0.30, teinte = 0.12,
	},
}

function Decor.nombre()
	return #Decor.THEMES
end

-- CHOIX DETERMINISTE. Les deux joueurs doivent voir la MEME arene : le theme se deduit d'une
-- graine choisie par le serveur (une seule fois par partie), jamais d'un hasard local.
function Decor.choisir(graine)
	local n = #Decor.THEMES
	local g = math.floor(math.abs(tonumber(graine) or 0))
	return Decor.THEMES[(g % n) + 1]
end

function Decor.parId(id)
	for _, t in ipairs(Decor.THEMES) do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- EVITER LA REPETITION : deux duels de suite sur le meme decor annulent tout l'interet. Rend une
-- graine qui donne un theme DIFFERENT du precedent (nil = aucun precedent).
function Decor.graineSuivante(graine, idPrecedent)
	local n = #Decor.THEMES
	local g = math.floor(math.abs(tonumber(graine) or 0))
	for pas = 0, n - 1 do
		local t = Decor.THEMES[((g + pas) % n) + 1]
		if t.id ~= idPrecedent then
			return g + pas
		end
	end
	return g
end

-- VERIFICATION DE NEUTRALITE, utilisable a l'execution comme au banc : un theme ne doit porter que
-- des cles d'apparence. Rend (ok, cleFautive).
function Decor.neutre(theme)
	for cle in pairs(theme or {}) do
		if not Decor.CLES[cle] then
			return false, cle
		end
	end
	return true
end

return Decor
