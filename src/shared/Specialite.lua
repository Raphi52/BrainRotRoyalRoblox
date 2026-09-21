-- SPECIALITES : des cartes faites pour repondre a UNE menace precise.
--
-- Defaut mesure avant ce module : une unite faisait les memes degats a tout le monde. Un volant se
-- repoussait donc avec n'importe quel tireur, et un essaim avec n'importe quelle unite de zone —
-- il n'y avait aucune raison de GARDER une carte pour la menace qu'elle contre. Or c'est de la que
-- vient la decision interessante du genre : « je garde ma tourelle anti-air, il a des volants ».
--
-- Deux specialites, pas plus, pour rester lisibles :
--   * "air"    : degats majores contre ce qui VOLE ;
--   * "groupe" : degats majores contre les unites qui arrivent a PLUSIEURS (count > 1).
--
-- Regle de coherence, verifiee au banc : une carte anti-air doit pouvoir VISER les volants. Une
-- carte qui ne cible que les batiments, ou qui frappe au corps a corps, ne peut pas etre anti-air —
-- ce serait une promesse que le jeu ne tient pas.
--
-- Declarees ICI, par identifiant, pas dans le catalogue : c'est une regle de combat.
-- Fonctions pures, verifiees hors Studio (tools/test_specialite.py) ; le serveur applique.
local Specialite = {}

Specialite.PROFILS = {
	-- anti-air : les deux petites defenses a longue portee, faites pour ca
	Ballerina   = { contre = "air", multiplicateur = 2.0 },
	Bananita    = { contre = "air", multiplicateur = 2.0 },
	-- anti-groupe : les frappes de zone, faites pour nettoyer un essaim
	TungSahur   = { contre = "groupe", multiplicateur = 1.8 },
	Bombombini  = { contre = "groupe", multiplicateur = 1.8 },
}

Specialite.MULTIPLICATEUR_MAX = 2.5
Specialite.CATEGORIES = { air = true, groupe = true }

function Specialite.profil(id)
	local p = Specialite.PROFILS[id]
	if not p or not Specialite.CATEGORIES[p.contre] then
		return nil
	end
	return {
		contre = p.contre,
		multiplicateur = math.clamp(p.multiplicateur or 1, 1, Specialite.MULTIPLICATEUR_MAX),
	}
end

function Specialite.estSpecialiste(id)
	return Specialite.profil(id) ~= nil
end

-- CATEGORIES d'une cible. Une meme cible peut en porter plusieurs (un essaim volant est les deux) :
-- on rend une table, pas une seule etiquette, sinon il faudrait arbitrer entre deux specialistes
-- qui la contrent tous les deux legitimement.
--   cible : { flying = bool, count = nombre d'unites posees par la carte, isBuilding = bool }
function Specialite.categories(cible)
	local c = {}
	if not cible or cible.isBuilding then
		return c -- un batiment n'est ni un volant ni un essaim : rien ne le « contre »
	end
	if cible.flying then
		c.air = true
	end
	if (tonumber(cible.count) or 1) > 1 then
		c.groupe = true
	end
	return c
end

-- MULTIPLICATEUR de degats de l'attaquant contre cette cible. 1 = coup normal.
function Specialite.multiplicateur(idAttaquant, cible)
	local p = Specialite.profil(idAttaquant)
	if not p then
		return 1
	end
	if Specialite.categories(cible)[p.contre] then
		return p.multiplicateur
	end
	return 1
end

-- DEGATS effectivement infliges, en nombre entier.
function Specialite.degats(base, multiplicateur)
	local m = math.clamp(multiplicateur or 1, 1, Specialite.MULTIPLICATEUR_MAX)
	return math.floor((tonumber(base) or 0) * m + 0.5)
end

-- COHERENCE : cette carte peut-elle tenir la promesse de sa specialite ?
-- `carte` : { targets = "any"|"buildings", range = n, splash = n|nil }
-- Un anti-air doit pouvoir viser autre chose que des batiments. Un anti-groupe doit frapper en
-- ZONE — majorer les degats d'un tireur mono-cible contre un essaim ne le nettoierait pas.
function Specialite.coherente(id, carte)
	local p = Specialite.profil(id)
	if not p then
		return true -- aucune promesse, rien a tenir
	end
	if not carte then
		return false
	end
	if p.contre == "air" then
		return carte.targets ~= "buildings"
	end
	return (carte.splash or 0) > 0
end

return Specialite
