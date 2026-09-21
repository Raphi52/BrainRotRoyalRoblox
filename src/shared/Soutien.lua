-- SOUTIEN : des unites qui ne valent rien seules, et qui rendent les autres meilleures.
--
-- Defaut mesure avant ce module : toutes les cartes se jugeaient UNE PAR UNE. Poser deux cartes
-- ensemble ne valait jamais mieux que les poser separement, donc il n'existait aucune raison de
-- composer une poussee — juste d'empiler la carte la plus rentable. Le soutien cree la premiere
-- vraie combinaison : le soigneur existait deja, mais il repare les degats subis, il ne change
-- pas ce que les allies FONT.
--
-- Choix de conception : le bonus n'est JAMAIS stocke sur l'unite renforcee. Il est recalcule a
-- chaque image a partir des soutiens vivants et de leur distance. Consequence directe : sortir du
-- rayon, ou tuer le soutien, retire le bonus AU MEME INSTANT et sans aucun reste. C'est ce qui
-- rend la parade lisible — on tue le tambour, et la poussee retombe.
--
-- Les cartes concernees sont declarees ICI, par identifiant, et non dans le catalogue : c'est une
-- regle de combat. Fonctions pures, verifiees hors Studio (tools/test_soutien.py).
local Soutien = {}

-- rayon   : portee du renfort, en studs
-- degats  : multiplicateur des degats des allies dans le rayon
-- cadence : multiplicateur de la VITESSE d'attaque (1,25 = 25 % de coups en plus)
Soutien.PROFILS = {
	Lirili      = { rayon = 7.0, degats = 1.30, cadence = 1.00 },
	Spaghettino = { rayon = 6.0, degats = 1.00, cadence = 1.25 },
	Glorbo      = { rayon = 6.5, degats = 1.15, cadence = 1.10 },  -- remplace Zibra : elle chargeait a 9 studs pour une aura de 6,5
}

-- Plafond : meme entoure de trois soutiens, un allie ne depasse jamais ca. Sans plafond, un tas de
-- soutiens derriere une seule grosse unite deviendrait une combinaison imbattable.
Soutien.MAX = 1.5
Soutien.RAYON_MAX = 12
-- HYSTERESIS. Une unite qui marche a la FRONTIERE d'une aura entrait et sortait en permanence :
-- mesure du 2026-09-20 sur une partie entiere, une Bananita entre 13 fois dans un rayon au cours
-- de sa courte vie — donc elle en sort 12 fois. Ses degats oscillaient entre 95 et 124 sans que
-- rien de visible ne change, ce qui est illisible pour le joueur. Une fois renforcee, elle le
-- reste donc jusqu'a s'eloigner de cette marge en plus. C'est le meme remede que pour le
-- papillonnage de cible (Cible.MARGE_CHANGEMENT).
Soutien.MARGE_SORTIE = 1.5

-- COHERENCE d'une carte de soutien, verifiee au banc contre le catalogue ET contre les autres
-- regles de combat. Un soutien TIENT AVEC les siens : c'est toute son identite.
--   * il ne CHARGE pas. Une unite a charge s'elance vers l'ennemi ; si son elan depasse le rayon
--     de son aura, elle abandonne mathematiquement ceux qu'elle renforce. Mesure du 2026-09-20 :
--     Zibra s'elancait sur 9 studs avec une aura de 6,5 — 2,5 studs de trop, a chaque charge, et
--     son texte ne promet d'ailleurs que « charge rapide », jamais le renfort ;
--   * il n'est pas un GROUPE : deux porteurs de la meme aura se suivent et ne renforcent
--     personne de plus, tout en doublant les traces et le calcul ;
--   * il tient A DISTANCE (portee >= PORTEE_APPUI) : un soutien au contact meurt le premier, et
--     l'aura disparait avec lui au moment ou elle servait.
-- Rend : ok, raison (raison = nil quand c'est coherent).
Soutien.PORTEE_APPUI = 5

function Soutien.coherente(id, carte, elanCharge)
	local p = Soutien.PROFILS[id]
	if not p or carte == nil then
		return true, nil
	end
	if (tonumber(carte.count) or 1) > 1 then
		return false, "carte de groupe : deux porteurs de la meme aura ne renforcent personne de plus"
	end
	if (tonumber(carte.range) or 0) < Soutien.PORTEE_APPUI then
		return false, "soutien au contact : il meurt avant de servir"
	end
	if elanCharge and tonumber(elanCharge) and tonumber(elanCharge) > 0 then
		if tonumber(elanCharge) > (tonumber(p.rayon) or 0) then
			return false, "elle charge plus loin que son aura ne porte : elle abandonne ceux qu'elle renforce"
		end
	end
	return true, nil
end

function Soutien.profil(id)
	local p = Soutien.PROFILS[id]
	if not p then
		return nil
	end
	return {
		rayon = math.clamp(p.rayon or 0, 0, Soutien.RAYON_MAX),
		degats = math.clamp(p.degats or 1, 1, Soutien.MAX),
		cadence = math.clamp(p.cadence or 1, 1, Soutien.MAX),
	}
end

function Soutien.estSoutien(id)
	return Soutien.PROFILS[id] ~= nil
end

function Soutien.dansRayon(dx, dz, rayon)
	return (dx * dx + dz * dz) <= (rayon or 0) * (rayon or 0)
end

-- BONUS total recu par une unite. `soutiens` : liste de { id = , x = , z = , camp = , vivant = }.
-- `moi` : { x = , z = , camp = , estBatiment = }.
--
-- NON-CUMULATIF : deux tambours identiques ne doublent pas le bonus, on garde le MEILLEUR de
-- chaque effet. Sinon la strategie gagnante serait d'empiler six fois la meme carte, ce qui est
-- l'inverse de ce qu'on cherche — on veut des cartes qui se COMPLETENT.
-- `dejaRenforcee` : l'unite beneficiait-elle deja d'une aura a l'image precedente ? Si oui, le
-- rayon est elargi de MARGE_SORTIE — on entre au rayon, on ne sort qu'un peu plus loin.
-- Rend deux multiplicateurs : degats, cadence.
function Soutien.bonus(moi, soutiens, dejaRenforcee)
	local md, mc = 1, 1
	if not moi or not soutiens then
		return md, mc
	end
	for _, s in ipairs(soutiens) do
		if s.vivant ~= false and s.camp == moi.camp and s ~= moi then
			local p = Soutien.profil(s.id)
			-- un soutien ne se renforce pas lui-meme, et les batiments ne profitent de rien :
			-- une tour ne « suit » aucune poussee, elle ne doit pas en tirer avantage.
			if p and not moi.estBatiment and not (s.x == moi.x and s.z == moi.z and s.id == moi.id) then
				local portee = p.rayon
				if dejaRenforcee then
					portee = portee + Soutien.MARGE_SORTIE
				end
				if Soutien.dansRayon(s.x - moi.x, s.z - moi.z, portee) then
					md = math.max(md, p.degats)
					mc = math.max(mc, p.cadence)
				end
			end
		end
	end
	return math.min(md, Soutien.MAX), math.min(mc, Soutien.MAX)
end

-- Degats effectivement infliges, en nombre entier.
function Soutien.degats(base, multiplicateur)
	return math.floor((tonumber(base) or 0) * math.clamp(multiplicateur or 1, 1, Soutien.MAX) + 0.5)
end

-- DELAI entre deux coups : une meilleure cadence RACCOURCIT le delai, elle ne l'allonge pas.
function Soutien.delaiAttaque(base, multiplicateur)
	local m = math.clamp(multiplicateur or 1, 1, Soutien.MAX)
	return (tonumber(base) or 0) / m
end

return Soutien
