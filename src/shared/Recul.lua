-- RECUL A L'IMPACT : des unites qui PROJETTENT ce qu'elles frappent.
--
-- Defaut mesure avant ce module : seul un SORT (le tronc, `Sorts.recul`) pouvait repousser. Aucune
-- unite ne le faisait, donc un corps a corps etait toujours un echange sur place — celui qui
-- frappait le plus fort gagnait, et la position ne changeait jamais rien. Le recul apporte la
-- chose qui manquait : gagner du TEMPS. Repousser une unite de 3 studs, c'est lui faire refaire
-- le chemin pendant que la tour tire.
--
-- La geometrie n'est PAS reecrite ici : la direction et la distance se calculent exactement comme
-- pour le sort du tronc (meme formule, verifiee identique au banc). Ce module ajoute les trois
-- choses qui manquaient pour l'appliquer a une unite :
--   * QUI repousse, et de combien ;
--   * le POIDS de la cible — une grosse unite recule moins qu'un petit ;
--   * l'ANTI-VERROUILLAGE — sans lui, deux cogneurs repousseraient la meme cible en boucle et
--     elle ne pourrait plus JAMAIS agir. Une unite injouable est pire qu'une unite trop forte.
--
-- Fonctions pures, verifiees hors Studio (tools/test_recul.py) ; le serveur applique.
local Recul = {}

-- AUDIT DES PROMESSES (2026-09-20) : chaque cogneur est relu contre le texte de sa carte.
-- Los Tralaleritos a ete RETIRE : trois bebes requins a 500 pv chacun, dont la carte ne promet
-- aucun poids, et qui projetaient 7,4 fois par pose — plus que l'elephant a 2400 pv (3,4).
-- Orcalero le remplace : sa carte dit « cogneuse solide » et ne cognait pas plus qu'une autre.
--
-- distance : studs de projection sur une cible de poids normal
-- periode  : secondes minimales entre deux reculs SUBIS par une meme cible
Recul.PROFILS = {
	Burbaloni    = { distance = 2.5 },   -- « encaisse »        1 unite, 950 pv
	Orcalero     = { distance = 2.0 },   -- « cogneuse solide »  1 unite, 1300 pv
	Cocofanto    = { distance = 3.5 },   -- « mur vivant »       1 unite, 2400 pv
}

Recul.DISTANCE_MAX = 5        -- borne dure : au-dela, une unite traverserait l'arene a reculons
Recul.PERIODE = 0.8           -- une meme cible ne peut pas etre repoussee plus souvent que ca
-- POIDS : au-dessus de ce nombre de points de vie, la cible est « lourde » et encaisse moins de
-- recul ; le facteur descend progressivement jusqu'au plancher.
Recul.PV_LEGER = 600
Recul.PV_LOURD = 2000
Recul.RESISTANCE_MIN = 0.3    -- meme le plus lourd bouge un peu : sinon le coup semble sans effet

function Recul.profil(id)
	local p = Recul.PROFILS[id]
	if not p then
		return nil
	end
	return {
		distance = math.clamp(p.distance or 0, 0, Recul.DISTANCE_MAX),
		periode = p.periode or Recul.PERIODE,
	}
end

function Recul.repousse(id)
	return Recul.PROFILS[id] ~= nil
end

-- COHERENCE d'une carte porteuse de recul, verifiee au banc sur tout le catalogue.
-- Le recul est une identite de POIDS : une unite qui projette ce qu'elle touche est une unite
-- qu'on sent passer. Deux refus, tous deux issus d'une mesure et non d'un gout :
--
--   * une carte de GROUPE (count > 1) ne repousse pas. Mesure sur les journaux recents, en
--     projections PAR POSE — l'unite que le joueur ressent, puisqu'il joue une carte, pas une
--     unite :
--         Cocofanto (1 unite)     226 projections / 67 poses = 3,4
--         Burbaloni (1 unite)     137 projections / 28 poses = 4,9
--         Tralaleritos (3 unites) 134 projections / 18 poses = 7,4
--     La carte la plus LEGERE du lot controlait donc le plus, parce que son effet est multiplie
--     par son nombre. Un groupe se defend en frappant vite, pas en bousculant.
--   * une unite LEGERE (pv <= PV_LEGER) ne repousse pas : elle-meme serait projetee par un
--     recul de meme force, ce que la resistance au poids dit deja dans l'autre sens.
--
-- Rend : ok, raison (raison = nil quand c'est coherent).
function Recul.coherente(id, carte)
	if not Recul.repousse(id) then
		return true, nil
	end
	if carte == nil then
		return true, nil
	end
	if (tonumber(carte.count) or 1) > 1 then
		return false, "carte de groupe : le recul serait multiplie par le nombre d'unites"
	end
	if (tonumber(carte.hp) or 0) <= Recul.PV_LEGER then
		return false, "unite legere : elle n'a pas le poids qu'un recul annonce"
	end
	return true, nil
end

-- FACTEUR de resistance au recul, entre RESISTANCE_MIN et 1, selon les points de vie MAXIMAUX de
-- la cible (ses PV courants ne doivent rien changer : une grosse unite blessee reste lourde).
function Recul.resistance(pvMax)
	local pv = tonumber(pvMax) or 0
	if pv <= Recul.PV_LEGER then
		return 1
	end
	if pv >= Recul.PV_LOURD then
		return Recul.RESISTANCE_MIN
	end
	local part = (pv - Recul.PV_LEGER) / (Recul.PV_LOURD - Recul.PV_LEGER)
	return 1 - part * (1 - Recul.RESISTANCE_MIN)
end

-- DISTANCE reellement subie. Les batiments ne bougent jamais : une tour projetee n'aurait aucun
-- sens, et le mur defensif perdrait tout son interet.
function Recul.distance(profil, cible)
	if not profil or not cible or cible.batiment then
		return 0
	end
	return profil.distance * Recul.resistance(cible.pvMax)
end

-- ANTI-VERROUILLAGE : la cible vient-elle d'etre repoussee ? `depuis` = secondes ecoulees depuis
-- le dernier recul subi (nil = jamais).
function Recul.permis(depuis, periode)
	if depuis == nil then
		return true
	end
	return depuis >= (periode or Recul.PERIODE)
end

-- VECTEUR de projection, de l'attaquant vers la cible. MEME formule que `Sorts.recul` (le banc
-- verifie que les deux donnent exactement le meme resultat) : une divergence entre les deux ferait
-- que le tronc et une unite ne repoussent pas dans le meme sens, ce qui serait illisible.
function Recul.vecteur(attaquantX, attaquantZ, cibleX, cibleZ, distance)
	local d = tonumber(distance) or 0
	if d <= 0 then
		return 0, 0
	end
	local dx, dz = (cibleX or 0) - (attaquantX or 0), (cibleZ or 0) - (attaquantZ or 0)
	local n = math.sqrt(dx * dx + dz * dz)
	if n < 1e-4 then
		return 0, 0 -- exactement superposes : aucune direction n'a de sens
	end
	return dx / n * d, dz / n * d
end

-- ===== LA RIVIERE =====
-- Defaut mesure apres coup : le recul deplacait l'unite librement en x/z, borne seulement par les
-- murs de l'arene. Une unite AU SOL projetee pres d'un pont pouvait donc finir DANS l'eau, ou
-- aucune unite terrestre n'a le droit d'etre — elle y restait le temps de revenir vers un pont.
-- Un volant, lui, survole : la regle ne le concerne pas.

-- Sommes-nous au-dessus d'un pont ? `ponts` : liste des x des ponts, `demiLargeur` : leur
-- demi-largeur en studs.
function Recul.surPont(x, ponts, demiLargeur)
	if not ponts then
		return false
	end
	for _, bx in ipairs(ponts) do
		if math.abs((x or 0) - bx) <= (demiLargeur or 0) then
			return true
		end
	end
	return false
end

-- Z corrige pour qu'une unite au sol ne soit pas deposee dans l'eau : elle est retenue sur la
-- BERGE du cote d'ou elle venait. Repousser quelqu'un ne doit jamais le faire changer de moitie
-- d'arene — ce serait un passage gratuit par-dessus la riviere.
function Recul.corrigeRiviere(zArrivee, zDepart, demiRiviere)
	local za, zd = tonumber(zArrivee) or 0, tonumber(zDepart) or 0
	local r = tonumber(demiRiviere) or 0
	if r <= 0 or math.abs(za) > r then
		return za -- hors de la bande d'eau : rien a corriger
	end
	-- cote d'origine ; si elle etait DEJA dans l'eau (impossible en principe), on la sort du cote
	-- vers lequel elle allait, plutot que de la bloquer au centre.
	local cote = zd >= 0 and 1 or -1
	if math.abs(zd) <= r then
		cote = za >= 0 and 1 or -1
	end
	return cote * r
end

return Recul
