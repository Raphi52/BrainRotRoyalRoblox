-- DUEL A NIVEAUX EGALISES, en fonctions PURES.
--
-- Le defaut corrige : un duel se joue toujours avec les niveaux de cartes de chacun. Entre deux
-- amis dont l'un joue depuis six mois, l'ecart de statistiques decide la partie avant le premier
-- coup — +40 % de points de vie et de degats au niveau 5 contre un niveau 1. On ne peut donc
-- jamais savoir QUI JOUE LE MIEUX, ce qui est pourtant la seule question d'un duel entre amis.
--
-- Ce mode ramene TOUTES les cartes des DEUX camps au meme niveau. Il ne « boost » personne et ne
-- punit personne : il retire simplement la variable d'inventaire de l'equation.
local Egalise = {}

-- Niveau de reference. 3 et non 1 : au niveau 1 les parties trainent (les tours tiennent trop
-- longtemps) ; 3 est le milieu de l'echelle et garde le rythme mesure dans les simulations.
Egalise.NIVEAU = 3

-- Le mode est-il demande ? Une valeur absente ou autre chose qu'un vrai « oui » = duel normal :
-- on n'egalise jamais par accident, et surtout jamais une partie classee.
function Egalise.actif(demande)
	return demande == true
end

-- NIVEAUX A UTILISER pour un camp. `ids` : les cartes concernees (le deck, ou tout le catalogue).
-- Hors mode, on rend les niveaux du joueur tels quels — aucune surprise.
function Egalise.niveaux(niveauxJoueur, ids, actif, niveau)
	if not actif then
		return niveauxJoueur
	end
	local n = niveau or Egalise.NIVEAU
	local sortie = {}
	for _, id in ipairs(ids or {}) do
		sortie[id] = n
	end
	return sortie
end

-- ECART SUPPRIME, pour l'annoncer honnetement : combien de niveaux separaient les deux camps.
-- `niveauMoyen(niveaux, ids)` est fourni par l'appelant (il vit dans l'economie).
function Egalise.ecartSupprime(niveauxA, niveauxB, ids, niveauMoyen)
	if not niveauMoyen then
		return 0
	end
	return math.abs(niveauMoyen(niveauxA or {}, ids or {}) - niveauMoyen(niveauxB or {}, ids or {}))
end

-- Ce qui s'affiche en partie. nil hors mode : aucun bandeau inutile.
function Egalise.libelle(actif, niveau)
	if not actif then
		return nil
	end
	return string.format("NIVEAUX EGALISES — toutes les cartes au niveau %d", niveau or Egalise.NIVEAU)
end

-- UN DUEL EGALISE NE COMPTE PAS POUR LE CLASSEMENT. Les trophees mesurent une progression qui
-- inclut l'inventaire ; les melanger fausserait les deux. On le dit, plutot que de le cacher.
function Egalise.compteAuClassement(actif)
	return not actif
end

return Egalise
