-- CHARGE : certaines unites prennent de l'ELAN. Plus elles courent longtemps en ligne droite, plus
-- leur premier coup fait mal.
--
-- Defaut mesure avant ce module : toutes les unites de melee frappaient exactement pareil, qu'elles
-- viennent de traverser l'arene ou qu'elles soient posees au contact. Il n'existait donc AUCUNE
-- raison de poser une unite loin derriere pour la lancer, ni aucun moyen de la contrer en la
-- BLOQUANT en route. La charge apporte les deux d'un coup : une menace qui se voit venir, et une
-- parade — un mur, un squelette, n'importe quoi qui l'arrete lui vole sa charge.
--
-- Les cartes concernees sont declarees ICI, par identifiant, et non dans le catalogue : le
-- catalogue decrit ce qu'est une carte, ce module decrit une REGLE de combat. Un identifiant
-- inconnu n'est pas une erreur, il n'a simplement pas de charge.
--
-- Fonctions pures, verifiees hors Studio (tools/test_charge.py) ; le serveur ne fait qu'appliquer.
local Charge = {}

-- distance      : studs a courir SANS s'arreter avant que la charge soit lancee
-- multiplicateur: degats du coup charge, par rapport au coup normal
-- vitesse       : acceleration pendant la course (1 = vitesse normale)
Charge.PROFILS = {
	Bobritto   = { distance = 10, multiplicateur = 2.0, vitesse = 1.5 },
	Tigrullini = { distance = 12, multiplicateur = 2.2, vitesse = 1.6 },
	Cocofanto  = { distance = 14, multiplicateur = 2.5, vitesse = 1.4 },
}

-- Bornes de securite : aucune valeur lue dans PROFILS ne sort de la, quoi qu'on y ecrive un jour.
Charge.MULTIPLICATEUR_MAX = 3
Charge.VITESSE_MAX = 2
-- Pas minimal, en studs, pour qu'une image compte comme « elle a couru ». En dessous, l'unite
-- pietine (elle est genee par la foule, ou elle tourne) : ce n'est pas de l'elan.
Charge.PAS_MINIMAL = 0.02

function Charge.profil(id)
	local p = Charge.PROFILS[id]
	if not p then
		return nil
	end
	return {
		distance = p.distance,
		multiplicateur = math.clamp(p.multiplicateur, 1, Charge.MULTIPLICATEUR_MAX),
		vitesse = math.clamp(p.vitesse, 1, Charge.VITESSE_MAX),
	}
end

-- L'unite a-t-elle une charge ? (sert au serveur pour ne rien calculer sur les autres)
function Charge.aUneCharge(id)
	return Charge.PROFILS[id] ~= nil
end

-- AVANCEMENT de la course. `parcouru` = studs deja courus sans interruption, `pas` = studs
-- parcourus pendant CETTE image. Un pas nul ou derisoire remet le compteur a zero : c'est toute la
-- parade. Rend le nouveau `parcouru`.
function Charge.maj(parcouru, pas)
	local p = tonumber(pas) or 0
	if p < Charge.PAS_MINIMAL then
		return 0
	end
	return (tonumber(parcouru) or 0) + p
end

-- La charge est-elle LANCEE (le prochain coup sera charge) ?
function Charge.lancee(parcouru, profil)
	if not profil then
		return false
	end
	return (tonumber(parcouru) or 0) >= profil.distance
end

-- Part de la course deja faite, entre 0 et 1 — sert a l'affichage (trainee, poussiere) sans que
-- le client ait a connaitre les distances.
function Charge.avancement(parcouru, profil)
	if not profil or profil.distance <= 0 then
		return 0
	end
	return math.clamp((tonumber(parcouru) or 0) / profil.distance, 0, 1)
end

-- VITESSE de deplacement : l'unite n'accelere que lorsque sa charge est lancee, pas avant. Sinon
-- elle serait simplement « une unite rapide », et le joueur ne verrait jamais le moment ou la
-- menace devient serieuse.
function Charge.vitesse(base, profil, lancee)
	local v = tonumber(base) or 0
	if not profil or not lancee then
		return v
	end
	return v * profil.vitesse
end

-- DEGATS du coup. Seul le PREMIER coup profite de l'elan : ensuite l'unite est au contact, elle ne
-- court plus, et elle frappe normalement. Le serveur remet le compteur a zero apres le coup.
function Charge.degats(base, profil, lancee)
	local d = tonumber(base) or 0
	if not profil or not lancee then
		return d
	end
	return math.floor(d * profil.multiplicateur + 0.5)
end

return Charge
