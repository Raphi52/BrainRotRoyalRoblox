-- TUTORIEL, en fonctions PURES (aucune API Roblox ici).
--
-- Pourquoi ce module existe : un joueur neuf arrivait directement en match contre le robot,
-- sans que rien ne lui explique la pose, l'elixir, ni pourquoi ses unites avancent toutes
-- seules. Il perdait sans comprendre. Le tutoriel est un MATCH SCENARISE, pas un ecran d'aide :
-- il reutilise le moteur existant (tryPlay, zone de pose, robot) et ne change AUCUNE regle.
--
-- Le principe, etape par etape : UNE SEULE carte est jouable, les autres sont grisees. Le joueur
-- n'a donc qu'un geste possible et le trouve sans qu'on lui ecrive quoi que ce soit. Rien n'est
-- explique par du TEXTE : chaque etape porte un `montrer` que le client joue visuellement
-- (doigt fantome, jauge qui pulse, camera qui se rapproche).
--
-- Verifiable hors Studio : tools/test_tutoriel.py.
local Tutoriel = {}

-- Le tutoriel est IMPOSE a la toute premiere partie, puis plus jamais : un joueur qui connait
-- le genre ne doit pas le subir deux fois.
function Tutoriel.obligatoire(profil)
	return profil ~= nil and (profil.parties or 0) == 0
end

-- Budget de temps : 60 s de contenu. Le plafond laisse de la marge au joueur qui traine, mais
-- une etape qui expire passe a la suivante — le tutoriel ne bloque jamais personne.
Tutoriel.DUREE_CIBLE = 60
Tutoriel.DUREE_MAX = 75
-- Le robot reste immobile tant que le joueur n'a pas compris la pose et l'elixir.
Tutoriel.ROBOT_SILENCE = 25

-- `carte`      : la SEULE carte jouable a cette etape (nil = toutes, pour la fin libre).
-- `elixir`     : elixir impose a l'ENTREE de l'etape (cree le manque volontairement).
-- `montrer`    : ce que le client met en scene, sans un mot.
-- `finQuand`   : "pose" | "delai" | "tourTombee" | "volantAbattu".
-- `duree`      : plafond de l'etape, en secondes.
-- `robot`      : carte posee par le robot au debut de l'etape (nil = il ne fait rien).
Tutoriel.ETAPES = {
	{
		id = "poser", carte = "Ballerina", elixir = 4, duree = 12,
		finQuand = "pose", montrer = "doigt", robot = nil,
	},
	{
		-- Elixir mis a 1 alors que la carte en coute 4 : il DOIT attendre, et il voit pourquoi.
		id = "elixir", carte = "Glorbo", elixir = 1, duree = 14,
		finQuand = "pose", montrer = "jauge", robot = nil,
	},
	{
		-- Personne ne pose rien : on regarde ses unites traverser et frapper la tour.
		id = "avancer", carte = nil, elixir = nil, duree = 10,
		finQuand = "delai", montrer = "camera_suit", robot = nil,
	},
	{
		id = "tour", carte = "Lirili", elixir = 6, duree = 14,
		finQuand = "tourTombee", montrer = "zone_etendue", robot = "Tralalero",
	},
	{
		-- Le robot envoie un VOLANT : la carte imposee est une tireuse, donc il apprend
		-- la regle « la melee ne touche pas les volants » en la contournant lui-meme.
		id = "volant", carte = "Bananita", elixir = 5, duree = 10,
		finQuand = "volantAbattu", montrer = "cible_air", robot = "Frulli",
	},
}

function Tutoriel.etape(index)
	return Tutoriel.ETAPES[index]
end

function Tutoriel.nombreEtapes()
	return #Tutoriel.ETAPES
end

-- Une carte est-elle jouable a cette etape ? C'est TOUTE la pedagogie : une seule porte ouverte.
function Tutoriel.carteJouable(index, cardId)
	local e = Tutoriel.ETAPES[index]
	if not e then
		return true -- hors tutoriel : le jeu normal reprend la main
	end
	if not e.carte then
		return true
	end
	return e.carte == cardId
end

-- Carte que le robot pose au debut de l'etape (nil = il reste immobile).
function Tutoriel.actionRobot(index)
	local e = Tutoriel.ETAPES[index]
	return e and e.robot or nil
end

-- Instant (secondes depuis le debut) ou commence l'etape `index`.
function Tutoriel.debutEtape(index)
	local t = 0
	for i = 1, index - 1 do
		t = t + Tutoriel.ETAPES[i].duree
	end
	return t
end

function Tutoriel.dureeTotale()
	return Tutoriel.debutEtape(#Tutoriel.ETAPES + 1)
end

-- Etape suivante : par la CONDITION remplie, ou par expiration du plafond. Rend nil a la fin.
function Tutoriel.suivante(index, conditionRemplie, tempsDansEtape)
	local e = Tutoriel.ETAPES[index]
	if not e then
		return nil
	end
	if conditionRemplie or tempsDansEtape >= e.duree then
		local n = index + 1
		return Tutoriel.ETAPES[n] and n or nil
	end
	return index
end

return Tutoriel
