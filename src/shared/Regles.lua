-- REGLES DE PARTIE, en fonctions PURES (aucune API Roblox ici).
--
-- Pourquoi ce module existe : jusqu'ici la partie etait plate — meme rythme d'elixir du debut a la
-- fin, egalite possible au chrono, et une zone de pose qui ne bougeait jamais meme apres avoir
-- casse une tour. Ces trois regles font tout le sel d'un jeu de ce genre, et elles se decident par
-- du calcul : les ecrire ici les rend verifiables hors Studio (tools/test_regles.py), la ou le
-- serveur ne se teste qu'en lancant Roblox.
local Regles = {}

-- Temps (secondes). La copie de test raccourcit la partie ; les seuils suivent, en PROPORTION,
-- pour que le banc et le jeu parlent de la meme chose.
Regles.DOUBLE_ELIXIR_PART = 1 / 3 -- dernier tiers du temps reglementaire
Regles.PROLONGATION_PART = 1 / 3  -- duree de la prolongation, en part du temps reglementaire
Regles.MULT_DOUBLE = 2
Regles.MULT_PROLONGATION = 3

-- Instant (en secondes RESTANTES) a partir duquel l'elixir double.
function Regles.seuilDouble(dureeMatch)
	return dureeMatch * Regles.DOUBLE_ELIXIR_PART
end

function Regles.dureeProlongation(dureeMatch)
	return dureeMatch * Regles.PROLONGATION_PART
end

-- Multiplicateur d'elixir : 1 en debut de partie, 2 dans le dernier tiers, 3 en prolongation.
function Regles.multiplicateurElixir(tempsRestant, dureeMatch, enProlongation)
	if enProlongation then
		return Regles.MULT_PROLONGATION
	end
	if tempsRestant <= Regles.seuilDouble(dureeMatch) then
		return Regles.MULT_DOUBLE
	end
	return 1
end

-- Nom de la phase, tel qu'il est envoye au client (il en fait une banniere).
function Regles.phase(tempsRestant, dureeMatch, enProlongation)
	if enProlongation then
		return "prolongation"
	end
	if tempsRestant <= Regles.seuilDouble(dureeMatch) then
		return "double"
	end
	return "normale"
end

-- FIN DU TEMPS REGLEMENTAIRE. Rend le vainqueur (1 ou 2), ou nil s'il faut jouer la prolongation.
-- Une partie ne se termine plus sur une egalite de couronnes : elle se joue.
function Regles.finDuTemps(couronnes1, couronnes2)
	if couronnes1 > couronnes2 then
		return 1
	elseif couronnes2 > couronnes1 then
		return 2
	end
	return nil
end

-- FIN DE LA PROLONGATION (personne n'a pris de tour entre-temps : une tour prise y met fin tout de
-- suite, cote serveur). Depart : la tour la plus entamee. `pvBas1` / `pvBas2` = proportion de points
-- de vie de la tour la plus faible encore debout de chaque camp (0 a 1).
-- Rend 1, 2, ou 0 pour une egalite parfaite — le seul cas ou la partie reste nulle.
function Regles.finProlongation(pvBas1, pvBas2)
	local ecart = pvBas1 - pvBas2
	if ecart > 0.001 then
		return 1
	elseif ecart < -0.001 then
		return 2
	end
	return 0
end

-- ZONE DE POSE. Par defaut chacun pose dans SA moitie. Casser une tour de cote OUVRE la moitie
-- adverse de CE cote : c'est la recompense qui rend une tour prise decisive, au lieu d'un simple
-- compteur de couronnes.
--   camp        : 1 (pose en z negatif) ou 2 (z positif)
--   voieOuverte : fonction(x) -> vrai si la tour ennemie de ce cote est tombee
-- La zone reste bornee par l'appelant (bords de l'arene) ; ici on ne decide que du COTE.
function Regles.posePermise(camp, x, z, voieGaucheOuverte, voieDroiteOuverte)
	local s = camp == 1 and -1 or 1
	if z * s >= 3 then
		return true -- sa propre moitie, comme avant
	end
	-- PIEGE Lua : `(x < 0) and gauche or droite` rend `droite` des que `gauche` est FAUX —
	-- une tour droite cassee ouvrait alors aussi le cote gauche (vu au banc, 2026-09-20).
	local ouverte
	if x < 0 then
		ouverte = voieGaucheOuverte
	else
		ouverte = voieDroiteOuverte
	end
	if not ouverte then
		return false
	end
	-- moitie adverse, mais seulement du cote de la tour tombee
	return z * s < 3
end

-- Une carte peut-elle TOUCHER un volant ? Meme regle que `canHit` cote serveur : les anti-tours
-- ne visent que les batiments, et une melee (portee < 5) au sol ne monte pas jusqu'a un volant.
-- Sert au robot, qui posait jusqu'ici des melees sous un bombardier sans pouvoir le toucher.
function Regles.peutViserVolant(card)
	if card.targets == "buildings" then
		return false
	end
	return card.flying == true or (card.range or 0) >= 5
end

return Regles
