-- REGARDER UN DUEL, en fonctions PURES.
--
-- Trois manques de l'audit : le spectateur ne pouvait SUIVRE personne (vue neutre figée), ne voyait
-- AUCUNE main (donc rien à anticiper, donc rien à commenter), et son pronostic disparaissait sans
-- jamais dire s'il avait eu raison.
--
-- LE PIEGE, ET LA RAISON DU RETARD. Montrer la main d'un joueur EN DIRECT ouvre un canal de triche
-- evident : un complice regarde la partie et dicte a l'adversaire les cartes qui arrivent. On
-- montre donc la main telle qu'elle etait il y a RETARD secondes. Le spectateur garde de quoi
-- comprendre et commenter ; l'information n'a plus aucune valeur pour tricher, puisqu'elle est
-- deja perimee quand elle arrive.
local Spectateur = {}

Spectateur.RETARD = 3        -- secondes de decalage sur la main montree
Spectateur.MEMOIRE = 10      -- secondes d'historique gardees (au-dela, inutile)

-- CE QU'ON DIT AU SPECTATEUR QUI ESSAIE DE JOUER.
--
-- Defaut mesure le 2026-09-21 : un spectateur qui clique dans l'arene n'obtenait RIEN — ni son,
-- ni message. Cote serveur, sa demande de pose etait jetee sans un mot (« spectateur : il regarde,
-- il ne pose pas de carte »). Il ne peut pas deviner s'il a mal clique, si le jeu rame ou s'il n'a
-- pas le droit : il re-clique, et s'agace. La phrase dit l'etat ET ce qu'il peut faire a la place.
Spectateur.REFUS_POSE = "Tu regardes cette partie : tu ne peux pas poser de carte"

function Spectateur.texteRefusPose(peutParier)
	if peutParier then
		return Spectateur.REFUS_POSE .. " — mais tu peux parier sur le gagnant"
	end
	return Spectateur.REFUS_POSE
end

-- CAMP SUIVI : on tourne entre les deux camps. `demande` nil = simple bascule.
function Spectateur.campSuivant(campActuel, demande)
	if demande == 1 or demande == 2 then
		return demande
	end
	return (campActuel == 1) and 2 or 1
end

-- HISTORIQUE DES MAINS : une entree { t, main }. Borne dans le temps, jamais dans l'infini.
function Spectateur.ajouter(historique, main, maintenant, memoire)
	local garde = memoire or Spectateur.MEMOIRE
	local l = {}
	for _, e in ipairs(historique or {}) do
		if maintenant - e.t <= garde then
			table.insert(l, e)
		end
	end
	local copie = {}
	for i, id in ipairs(main or {}) do
		copie[i] = id
	end
	table.insert(l, { t = maintenant, main = copie })
	return l
end

-- CE QUE LE SPECTATEUR A LE DROIT DE VOIR : l'entree la plus recente qui a DEJA RETARD secondes.
-- nil au debut de la partie : on ne montre rien plutot que de montrer le present.
function Spectateur.instantane(historique, maintenant, retard)
	local r = retard or Spectateur.RETARD
	local vu = nil
	for _, e in ipairs(historique or {}) do
		if (maintenant - e.t) >= r then
			vu = e
		end
	end
	return vu and vu.main or nil
end

-- RESULTAT DU PRONOSTIC, dit en fin de partie. Le spectateur pariait puis n'apprenait jamais s'il
-- avait vu juste — le pari ne servait donc a rien.
-- QUAND LES PARIS FERMENT. Defaut mesure le 2026-09-21 : le serveur refusait bien un pari APRES la
-- fin, mais rien n'empechait de parier a la derniere seconde — 2-0 a dix secondes du terme, ou une
-- tour du Roi a 1 % de vie. Le spectateur n'avait alors plus rien a deviner : il encaissait des
-- pieces a tous les coups, a chaque partie. Un pronostic qui ne risque rien n'est pas un pronostic.
--
-- Deux fermetures, et la premiere des deux suffit :
--   - le TEMPS : passe le premier tiers, on a deja vu le debut du duel ;
--   - la PREMIERE COURONNE : des qu'une tour tombe, la partie a penche, et cela se voit.
Spectateur.PART_PARIS = 1 / 3 -- part du temps reglementaire pendant laquelle on peut parier

function Spectateur.parisOuverts(timeLeft, dureeMatch, couronnes1, couronnes2)
	local restant = tonumber(timeLeft) or 0
	local duree = tonumber(dureeMatch) or 0
	if duree <= 0 then
		return false
	end
	if (tonumber(couronnes1) or 0) > 0 or (tonumber(couronnes2) or 0) > 0 then
		return false -- une tour est tombee : l'issue penche deja
	end
	return restant >= duree * (1 - Spectateur.PART_PARIS)
end

-- Ce qu'on dit au spectateur arrive en retard, pour qu'il ne cherche pas un bouton disparu.
function Spectateur.texteParisFermes()
	return "Paris fermes : la partie est deja engagee"
end

-- PARTIE ANNULEE : les deux joueurs ont saute, personne n'a gagne et la partie repart a neuf
-- (voir Reprise.partieAbandonnee). Le pari du spectateur s'evaporait alors SANS UN MOT : la partie
-- disparaissait de son ecran, et il ne savait jamais ce qu'il etait devenu.
-- Et le texte MENTAIT : `vainqueur == nil` (partie non finie ou annulee) rendait « Egalite »,
-- exactement comme un vrai match nul ou les deux joueurs sont alles au bout. Ce n'est pas la meme
-- chose, et le spectateur a le droit de savoir laquelle il vit.
Spectateur.ANNULEE = "Partie annulee : les deux joueurs ont quitte, ton pari est sans effet"

function Spectateur.texteAnnulee()
	return Spectateur.ANNULEE
end

function Spectateur.resultatPronostic(choisi, vainqueur, gain, annulee)
	if annulee == true then
		return Spectateur.ANNULEE -- avant tout le reste : meme sans pari, il doit savoir pourquoi
	end
	if choisi == nil then
		return "Tu n'avais pas parie."
	end
	if vainqueur == 0 then
		return "Egalite : aucun pari ne gagne."
	end
	if vainqueur == nil then
		return nil -- partie pas terminee : il n'y a encore rien a dire
	end
	if choisi == vainqueur then
		return string.format("Pronostic gagne ! +%d pieces", gain or 0)
	end
	return "Pronostic perdu."
end

-- Nom du camp, vu d'un spectateur (aucun « toi » : il ne joue pas).
function Spectateur.nomCamp(camp)
	return (camp == 1) and "Bleu" or "Rouge"
end

-- Le libelle du bouton de suivi : il annonce ce qu'on VERRA au prochain clic, pas l'etat courant.
function Spectateur.libelleSuivi(campActuel)
	return "Suivre " .. Spectateur.nomCamp(Spectateur.campSuivant(campActuel))
end

return Spectateur
