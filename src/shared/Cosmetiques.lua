-- COSMETIQUES (2026-09-21) : skins de TOURS et emotes PREMIUM, achetes en GEMMES.
-- Regle d'or : AUCUN impact sur l'equilibre. Un skin ne change que l'APPARENCE (materiaux,
-- couleurs des ornements, liseres) ; le CORPS de la tour garde la couleur de son CAMP, sinon on
-- ne saurait plus qui est qui. Aucun champ de statistique ici (tools/test_cosmetiques.py le verifie).
-- Les emotes premium vivent dans Emotes.LISTE (source unique des emotes), avec `prix`.
-- Module pur : couleurs en { r, g, b }, materiaux en NOMS d'Enum.Material.
local Cosmetiques = {}

Cosmetiques.DEFAUT = "classique"

Cosmetiques.SKINS = {
	{ id = "classique", nom = "Classique", prix = 0,
		corps = "Brick", creneaux = { 200, 195, 185 }, creneauxMat = "Limestone",
		toit = nil, toitMat = "Slate", drapeau = nil, accent = nil },
	{ id = "glace", nom = "Citadelle de glace", prix = 60,
		corps = "Ice", creneaux = { 215, 240, 255 }, creneauxMat = "Glacier",
		toit = { 160, 215, 255 }, toitMat = "Ice", drapeau = { 200, 240, 255 }, accent = { 140, 225, 255 } },
	{ id = "bonbon", nom = "Chateau bonbon", prix = 80,
		corps = "SmoothPlastic", creneaux = { 255, 160, 215 }, creneauxMat = "SmoothPlastic",
		toit = { 255, 120, 200 }, toitMat = "SmoothPlastic", drapeau = { 255, 255, 255 }, accent = { 255, 240, 250 } },
	{ id = "or", nom = "Tours royales d'or", prix = 120,
		corps = "Marble", creneaux = { 255, 205, 60 }, creneauxMat = "Foil",
		toit = { 255, 190, 40 }, toitMat = "Foil", drapeau = { 255, 225, 90 }, accent = { 255, 215, 80 } },
	{ id = "lave", nom = "Forteresse de lave", prix = 150,
		corps = "Basalt", creneaux = { 70, 55, 50 }, creneauxMat = "Basalt",
		toit = { 255, 110, 30 }, toitMat = "Neon", drapeau = { 255, 140, 40 }, accent = { 255, 120, 30 } },
}

function Cosmetiques.skin(id)
	for _, s in ipairs(Cosmetiques.SKINS) do
		if s.id == id then
			return s
		end
	end
	return Cosmetiques.SKINS[1]
end

-- Catalogue complet (skins + emotes premium d'Emotes.LISTE), dans l'ordre d'affichage.
-- { id, type = "skin" | "emote", nom, prix }
function Cosmetiques.catalogue(Emotes)
	local l = {}
	for _, s in ipairs(Cosmetiques.SKINS) do
		if s.prix > 0 then
			table.insert(l, { id = s.id, type = "skin", nom = s.nom, prix = s.prix })
		end
	end
	for _, e in ipairs(Emotes and Emotes.LISTE or {}) do
		if e.prix then
			table.insert(l, { id = e.id, type = "emote", nom = e.texte, prix = e.prix })
		end
	end
	return l
end

function Cosmetiques.article(Emotes, id)
	for _, a in ipairs(Cosmetiques.catalogue(Emotes)) do
		if a.id == id then
			return a
		end
	end
	return nil
end

function Cosmetiques.neuf()
	return { possedes = { [Cosmetiques.DEFAUT] = true }, skin = Cosmetiques.DEFAUT }
end

-- Etat toujours complet (profil ancien, ou abime).
function Cosmetiques.normaliser(etat)
	if type(etat) ~= "table" then
		return Cosmetiques.neuf()
	end
	etat.possedes = type(etat.possedes) == "table" and etat.possedes or {}
	etat.possedes[Cosmetiques.DEFAUT] = true
	if not etat.possedes[etat.skin or ""] then
		etat.skin = Cosmetiques.DEFAUT
	end
	return etat
end

-- Achat possible ? true, ou false + motif lisible. Ne modifie rien.
function Cosmetiques.peutAcheter(Emotes, etat, gemmes, id)
	local a = Cosmetiques.article(Emotes, id)
	if not a then
		return false, "article inconnu"
	end
	if etat.possedes[id] then
		return false, "deja possede"
	end
	if (tonumber(gemmes) or 0) < a.prix then
		return false, "il faut " .. a.prix .. " gemmes"
	end
	return true
end

-- Equiper un skin POSSEDE. true, ou false + motif.
function Cosmetiques.peutEquiper(etat, id)
	local s = Cosmetiques.skin(id)
	if s.id ~= id then
		return false, "skin inconnu"
	end
	if not etat.possedes[id] then
		return false, "skin non possede"
	end
	return true
end

-- Emote utilisable : gratuite, ou premium POSSEDEE.
function Cosmetiques.emotePermise(Emotes, etat, id)
	for _, e in ipairs(Emotes.LISTE) do
		if e.id == id then
			return not e.prix or (etat and etat.possedes and etat.possedes[id] == true) or false
		end
	end
	return false
end

return Cosmetiques
