-- RESERVE DEFENSIVE : ne pas tout depenser en attaque, garder de quoi repondre.
--
-- Ce que dit la MESURE (serie de 60 parties, robots aguerris, journal du 2026-09-20) :
--     menace_sans_carte : 1352 fois — elixir median 1,9, et JAMAIS plus de 4,0
--     aucune_jouable    :  689 fois — meme profil
--     garde_elixir      : 2482 fois — elixir median 4,9
-- Le robot est donc regulierement attaque alors qu'il ne peut rien payer. Premier reflexe :
-- chercher un bug. Il n'y en a pas — la liste des cartes candidates ne contient QUE les cartes
-- payables (`t.elixir >= c.cost`), et la defense passe avant tout le reste des qu'il est en
-- danger. Ces 1352 cas sont litteralement « il n'a plus d'elixir ».
--
-- Le vrai defaut est en AMONT : rien ne l'empechait de descendre a sec EN ATTAQUANT. Il attaque
-- des qu'il atteint son seuil (7 pour un aguerri), pose une carte, tombe vers 2 ou 3, et la
-- contre-attaque le trouve les mains vides. Un joueur qui progresse apprend exactement l'inverse :
-- on n'engage pas une poussee si l'on ne garde pas de quoi parer la riposte.
--
-- La regle : une carte d'ATTAQUE ne se joue que s'il reste, apres l'avoir payee, de quoi jouer
-- une carte de defense. Le montant n'est pas invente — c'est le cout MEDIAN des cartes
-- disponibles (3 elixir sur les 32 cartes gratuites : 7 cartes a 2, 13 a 3, 10 a 4, 2 a 5).
-- Garder 3 laisse donc 20 cartes sur 32 jouables en reponse.
--
-- Ce que la regle ne fait JAMAIS, et c'est ce qui l'empeche de figer le robot :
--   * elle ne s'applique pas a la DEFENSE ni a la CONTRE-ATTAQUE — repondre a une menace prime
--     toujours sur la reserve, sinon on garderait de l'elixir pour un danger deja la ;
--   * elle ne s'applique pas au palier DEBUTANT : son imprevoyance fait partie de son niveau,
--     c'est elle qui rend une premiere partie gagnable ;
--   * elle est BORNEE (RESERVE_MAX) : au-dela, plus aucune attaque ne partirait.
--
-- Fonctions pures, verifiees hors Studio (tools/test_reserve.py) ; le serveur applique.
local Reserve = {}

-- Cout median des cartes gratuites, mesure sur le catalogue. Le banc le RELIT dans Cards.lua :
-- si le catalogue change, il le dira au lieu de laisser ce chiffre vieillir en silence.
Reserve.MEDIANE = 3
Reserve.RESERVE_MAX = 4 -- au-dela, meme une carte a 3 ne partirait plus avant 7 d'elixir

-- Reserve exigee d'un profil de robot. Un profil qui n'anticipe pas (debutant) ne garde rien.
function Reserve.pour(profil)
	if profil == nil then
		return Reserve.MEDIANE -- cas de test : la regle s'applique par defaut
	end
	if profil.anticipe ~= true then
		return 0
	end
	return math.clamp(Reserve.MEDIANE, 0, Reserve.RESERVE_MAX)
end

-- Peut-on engager cette ATTAQUE sans se retrouver sans reponse ?
--   elixir  : ce qu'il a maintenant
--   cout    : ce que coute la carte
--   reserve : ce qu'il doit garder (Reserve.pour)
-- Rend vrai quand il reste au moins `reserve` apres avoir paye.
function Reserve.attaquePermise(elixir, cout, reserve)
	local e = tonumber(elixir) or 0
	local c = tonumber(cout) or 0
	local r = math.clamp(tonumber(reserve) or 0, 0, Reserve.RESERVE_MAX)
	return (e - c) >= r
end

-- Elixir minimal a atteindre pour pouvoir engager cette carte en attaque. Sert au journal : dire
-- « il attend 8 » est lisible, « reserve insuffisante » ne l'est pas.
function Reserve.seuil(cout, reserve)
	local c = tonumber(cout) or 0
	local r = math.clamp(tonumber(reserve) or 0, 0, Reserve.RESERVE_MAX)
	return c + r
end

return Reserve
