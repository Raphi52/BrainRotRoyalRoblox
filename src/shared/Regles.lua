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

-- PREAVIS DE DOUBLE ELIXIR. Defaut mesure le 2026-09-20 : le passage au double elixir etait
-- annonce A L'INSTANT OU IL ARRIVE (« DOUBLE ELIXIR ! »). Or toute la decision se prend AVANT :
-- garder son elixir quelques secondes pour partir en poussee des le basculement, ou depenser
-- maintenant. Sans preavis, l'annonce n'apprend rien — elle constate.
-- Le joueur le voyait venir seulement s'il calculait de tete le dernier tiers du chrono.
-- GEOMETRIE DU TERRAIN et RYTHME DE L'ELIXIR. Elles vivaient en variables locales du serveur,
-- alors que ce sont des regles de jeu — et le serveur touchait la limite Luau de 200 variables
-- locales. Ici, elles sont aussi lisibles par un banc.
Regles.LARGEUR_PONT = 4
Regles.DEMI_RIVIERE = 2.2
Regles.ELIXIR_PAR_SEC = 1 / 2.8 -- une goutte toutes les 2,8 s en elixir simple

Regles.PREAVIS = 10 -- secondes de compte a rebours avant le basculement

-- Secondes restantes avant le double elixir, ou nil s'il est deja la (ou en prolongation).
function Regles.avantDouble(tempsRestant, dureeMatch, enProlongation)
	if enProlongation then
		return nil
	end
	local reste = (tonumber(tempsRestant) or 0) - Regles.seuilDouble(dureeMatch)
	if reste <= 0 then
		return nil
	end
	return reste
end

-- Texte du preavis, ou nil quand il n'y a rien a annoncer : « DOUBLE ELIXIR DANS 7 ».
-- Arrondi au SUPERIEUR, comme un compte a rebours : on annonce 1 tant qu'il reste une fraction.
function Regles.texteAvantDouble(tempsRestant, dureeMatch, enProlongation)
	local reste = Regles.avantDouble(tempsRestant, dureeMatch, enProlongation)
	if not reste or reste > Regles.PREAVIS then
		return nil
	end
	return "DOUBLE ELIXIR DANS " .. math.ceil(reste)
end

-- PREAVIS DE FIN DU TEMPS REGLEMENTAIRE. Meme defaut que pour le double elixir, en pire : on
-- DECOUVRAIT la prolongation en y entrant. Or les dernieres secondes ne se jouent pas pareil selon
-- qu'on va vers une prolongation (garder son elixir, la premiere tour prise gagne) ou vers la fin
-- seche (tout envoyer, ou au contraire tout defendre). Le joueur devait comparer les couronnes ET
-- surveiller le chrono lui-meme, au moment ou il a le moins de temps pour le faire.
-- Le texte DIT laquelle des deux arrive, parce que ce sont deux jeux differents.
function Regles.texteAvantFin(tempsRestant, couronnes1, couronnes2, enProlongation)
	if enProlongation then
		return nil -- la prolongation est deja la : plus rien a annoncer
	end
	local reste = tonumber(tempsRestant) or 0
	if reste <= 0 or reste > Regles.PREAVIS then
		return nil
	end
	local n = math.ceil(reste)
	-- Egalite de couronnes = prolongation (Regles.finDuTemps rend nil). Une seule source de
	-- verite : on l'INTERROGE au lieu de recopier sa regle.
	if Regles.finDuTemps(couronnes1 or 0, couronnes2 or 0) == nil then
		return "PROLONGATION DANS " .. n
	end
	return "FIN DANS " .. n
end

-- RAPPEL PERMANENT DE LA PROLONGATION. Defaut mesure le 2026-09-20 : l'entree en prolongation
-- etait annoncee par un « PROLONGATION ! » de deux secondes et demie, puis plus rien. Or la
-- prolongation ne se joue PAS comme le reste de la partie : la premiere tour prise gagne
-- sur-le-champ. Un joueur qui n'a pas lu le manuel defendait comme d'habitude, et perdait sans
-- comprendre pourquoi une seule tour avait suffi. La regle doit rester SOUS LES YEUX tant qu'elle
-- s'applique, pas passer en coup de vent.
Regles.RAPPEL_PROLONGATION = "MORT SUBITE : LA PREMIERE TOUR PRISE GAGNE"

function Regles.rappelProlongation(enProlongation)
	if not enProlongation then
		return nil
	end
	return Regles.RAPPEL_PROLONGATION
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

-- ACCELERATION des series de simulation : le temps de jeu avance SIM_ACCEL fois plus vite qu'en
-- temps reel. Deplacee ici depuis GameServer le 2026-09-21 — le fichier principal du serveur est
-- a la limite des 200 variables locales de Luau. C'est aussi sa place : tout depouillement doit
-- pouvoir lire ce facteur pour convertir un temps mural en temps de JEU (voir tools/depouille.py,
-- ou l'oublier avait fausse une mesure d'un facteur 8).
Regles.SIM_ACCEL = 8

return Regles
