-- DESCENDANCE : ce qu'une unite laisse derriere elle en mourant.
--
-- Defaut mesure avant ce module : une grosse unite mourait et il ne restait RIEN. Le joueur qui
-- avait paye 6 elixir perdait tout d'un coup, et l'adversaire qui venait de la tuer n'avait plus
-- aucun travail a faire. C'est ce qui manquait pour que les grosses cartes valent leur prix : la
-- mort du colosse doit encore couter quelque chose a celui qui l'a abattu.
--
-- Les cartes concernees sont declarees ICI, par identifiant, et non dans le catalogue : le
-- catalogue decrit ce qu'EST une carte, ce module decrit une REGLE de combat. Un identifiant
-- inconnu n'est pas une erreur, il ne laisse simplement rien.
--
-- Fonctions pures, verifiees hors Studio (tools/test_descendance.py) ; le serveur applique.
local Descendance = {}

-- fille   : identifiant de la carte pondue a la mort
-- nombre  : combien
-- ecart   : rayon, en studs, du cercle sur lequel elles apparaissent
-- Choix des meres : des grosses cartes que le joueur rencontre VRAIMENT. Les premieres retenues
-- etaient toutes payantes ou rares (Giraffa, Vacca) : sur une melee complete de 190 s, aucune
-- n'avait ete jouee une seule fois, donc la regle ne s'appliquait a personne (mesure 15:02).
Descendance.PROFILS = {
	Boneca   = { fille = "Trippi",      nombre = 2, ecart = 2.5 },  -- poupee gigogne
	Frigo    = { fille = "Bananita",    nombre = 2, ecart = 2.5 },
	Orcalero = { fille = "Trippi",      nombre = 2, ecart = 2.5 },  -- Trulimero rendait 50,7 % : au-dessus de PART_MAX
	Nuclearo = { fille = "Chimpanzini", nombre = 3, ecart = 3.0 },  -- le colosse, 6 elixir
}

-- Bornes de securite.
Descendance.NOMBRE_MAX = 4      -- au-dela, une seule mort remplirait l'arene
Descendance.ECART_MAX = 6
Descendance.PV_MERE_MIN = 1000   -- en dessous, ce n'est pas un colosse (la plus petite mere : 1300)
-- PROFONDEUR : une fille ne laisse JAMAIS de descendance a son tour. Sans cette regle, une carte
-- mal declaree (une fille qui se pond elle-meme) ferait tourner la partie a l'infini — et ce
-- serait invisible au banc de la carte, puisque chaque mort prise isolement est correcte.
Descendance.PROFONDEUR_MAX = 1
-- PART_MAX : ce que la descendance vaut, en points de vie, rapporte a la mere. Une mort ne doit
-- jamais rendre PLUS de la moitie de ce qu'on vient d'abattre, sinon tuer la carte ne recompense
-- plus. Mesure du catalogue au 2026-09-20 : Boneca 34 %, Frigo 29 %, Orcalero 50 %, Nuclearo 28 %.
Descendance.PART_MAX = 0.5

-- COHERENCE d'une carte porteuse de descendance, verifiee au banc sur tout le catalogue.
-- La descendance est le privilege d'un COLOSSE SEUL : c'est ce qui fait qu'abattre une grosse
-- carte reste du travail. Trois refus :
--   * une carte de GROUPE (count > 1) : chaque mort pondrait, et une seule carte remplirait
--     l'arene — exactement le defaut que PROFONDEUR_MAX evite dans l'autre sens ;
--   * une carte LEGERE : sa mort n'est pas un evenement, elle n'a rien a laisser ;
--   * une descendance qui vaut PLUS que PART_MAX de la mere : la carte rendrait trop en mourant.
-- Rend : ok, raison (raison = nil quand c'est coherent).
function Descendance.coherente(id, carte, fille)
	local p = Descendance.profil(id)
	if not p or carte == nil then
		return true, nil
	end
	if (tonumber(carte.count) or 1) > 1 then
		return false, "carte de groupe : chaque mort pondrait"
	end
	local pv = tonumber(carte.hp) or 0
	if pv < Descendance.PV_MERE_MIN then
		return false, "unite trop legere : sa mort n'est pas un evenement"
	end
	if fille ~= nil then
		local total = (tonumber(fille.hp) or 0) * p.nombre
		if pv > 0 and total > pv * Descendance.PART_MAX then
			return false, "la descendance rend plus que la moitie de la mere"
		end
	end
	return true, nil
end

function Descendance.profil(id)
	local p = Descendance.PROFILS[id]
	if not p then
		return nil
	end
	return {
		fille = p.fille,
		nombre = math.clamp(math.floor(p.nombre or 1), 1, Descendance.NOMBRE_MAX),
		ecart = math.clamp(p.ecart or 2, 0, Descendance.ECART_MAX),
	}
end

function Descendance.laisseQuelqueChose(id)
	return Descendance.PROFILS[id] ~= nil
end

-- L'unite morte a-t-elle le droit de pondre ? `profondeur` = 0 pour une unite posee par le
-- joueur, 1 pour une fille, etc.
function Descendance.autorisee(profondeur)
	return (tonumber(profondeur) or 0) < Descendance.PROFONDEUR_MAX
end

-- POSITIONS des filles, reparties en cercle autour de l'endroit de la mort. Rend une liste de
-- { x = , z = }. Le cercle evite qu'elles naissent toutes au meme point : elles se repousseraient
-- (Foule) pendant une seconde avant de pouvoir avancer.
function Descendance.positions(x, z, profil)
	local points = {}
	if not profil then
		return points
	end
	local n = profil.nombre
	for k = 1, n do
		local angle = (k - 1) * (2 * math.pi / n)
		table.insert(points, {
			x = x + math.cos(angle) * profil.ecart,
			z = z + math.sin(angle) * profil.ecart,
		})
	end
	return points
end

-- Decision complete, telle que le serveur l'appelle a la mort :
--   rend nil si rien ne doit naitre, sinon { fille, nombre, ecart, profondeur, positions }
function Descendance.aLaMort(id, profondeur, x, z)
	if not Descendance.autorisee(profondeur) then
		return nil
	end
	local profil = Descendance.profil(id)
	if not profil then
		return nil
	end
	profil.profondeur = (tonumber(profondeur) or 0) + 1
	profil.positions = Descendance.positions(x or 0, z or 0, profil)
	return profil
end

return Descendance
