-- CE QUI MANQUE POUR POSER UNE CARTE, en fonctions PURES.
--
-- Defaut mesure le 2026-09-20 (capture cap-son-partie.png) : une carte trop chere etait simplement
-- PALIE. Rien ne disait POURQUOI ni COMBIEN il manquait : le joueur voyait quatre cartes, deux
-- ternes, et devait soustraire lui-meme le cout de son elixir courant — en pleine partie, a la
-- seconde. Pire, la carte interdite par le tutoriel etait palie de la MEME facon, avec une nuance
-- differente : deux causes opposees (« attends deux secondes » et « pas maintenant, suis l'etape »)
-- se lisaient pareil.
--
-- Regle : chaque carte dit son etat en toutes lettres, et une jauge montre le chemin qui reste.
-- Aucune API Roblox ici : tools/test_cout.py rejoue tout hors Studio.
local Cout = {}

-- ETATS. « jouable » : on peut la poser. « manque » : il faut attendre l'elixir. « bloquee » : le
-- tutoriel impose une autre carte, attendre ne servira a rien.
Cout.JOUABLE = "jouable"
Cout.MANQUE = "manque"
Cout.BLOQUEE = "bloquee"

-- Transparence du fond selon l'etat : la carte bloquee s'efface PLUS que celle qui attend
-- seulement de l'elixir, parce que le joueur n'a rien a en attendre.
Cout.OPACITE_JOUABLE = 0
Cout.OPACITE_MANQUE = 0.55
Cout.OPACITE_BLOQUEE = 0.85

function Cout.etat(cout, elixir, bloquee)
	if bloquee then
		return Cout.BLOQUEE
	end
	if (tonumber(elixir) or 0) >= (tonumber(cout) or 0) then
		return Cout.JOUABLE
	end
	return Cout.MANQUE
end

-- COMBIEN IL MANQUE, jamais negatif, ARRONDI AU SUPERIEUR. L'elixir du serveur est un nombre a
-- virgule (il monte en continu) : sans arrondi, la carte affichait « IL MANQUE 0.8746849303799 »
-- (capture cap-cout-main.png du 2026-09-20). Vers le HAUT, parce qu'a 0,9 il manque bien un point
-- d'elixir entier pour payer la carte.
function Cout.manque(cout, elixir)
	return math.ceil(math.max(0, (tonumber(cout) or 0) - (tonumber(elixir) or 0)))
end

-- PART DU COUT DEJA PAYEE (0 a 1) : sert a la jauge sous la carte. Une carte jouable est pleine.
function Cout.part(cout, elixir)
	local c = tonumber(cout) or 0
	if c <= 0 then
		return 1
	end
	return math.max(0, math.min(1, (tonumber(elixir) or 0) / c))
end

function Cout.opacite(etat)
	if etat == Cout.BLOQUEE then
		return Cout.OPACITE_BLOQUEE
	elseif etat == Cout.MANQUE then
		return Cout.OPACITE_MANQUE
	end
	return Cout.OPACITE_JOUABLE
end

-- LIGNE AFFICHEE SOUS LE NOM. Elle REMPLACE le cout nu quand la carte n'est pas jouable : un
-- « 5 elixir » sur une carte terne n'apprend rien, « IL MANQUE 2 » dit quoi faire (attendre).
function Cout.libelle(cout, elixir, bloquee)
	local etat = Cout.etat(cout, elixir, bloquee)
	if etat == Cout.BLOQUEE then
		return "PAS CETTE CARTE"
	elseif etat == Cout.MANQUE then
		return "IL MANQUE " .. Cout.manque(cout, elixir)
	end
	return (tonumber(cout) or 0) .. " elixir"
end

-- COULEUR de cette ligne : orange tant qu'il manque quelque chose, gris quand la carte est
-- interdite, blanc quand elle est jouable. Decidee ICI pour que le banc puisse la verifier.
function Cout.teinte(etat)
	if etat == Cout.MANQUE then
		return { 255, 190, 90 }
	elseif etat == Cout.BLOQUEE then
		return { 170, 175, 190 }
	end
	return { 255, 255, 255 }
end

-- REPERES SUR LA JAUGE D'ELIXIR. Defaut mesure le 2026-09-20 : la jauge etait une barre lisse
-- avec un chiffre. Le joueur voyait « 3 » mais ne voyait pas OU s'arrete le prochain palier utile :
-- « encore un cran et je peux poser ma Torre ». Il devait relire ses quatre cartes et comparer.
-- Ici : un trait par cout DIFFERENT de sa main, a sa place sur la jauge, du moins cher au plus
-- cher. Les doublons sont fondus (deux cartes a 3 ne font qu'un trait, sinon la jauge se salit),
-- et un cout hors jauge est ignore.
function Cout.reperes(couts, maxi)
	local m = tonumber(maxi) or 10
	local vus, valeurs = {}, {}
	for _, c in ipairs(couts or {}) do
		local v = tonumber(c)
		if v and v > 0 and v <= m and not vus[v] then
			vus[v] = true
			table.insert(valeurs, v)
		end
	end
	table.sort(valeurs)
	local r = {}
	for i, v in ipairs(valeurs) do
		-- `atteint` se decide a l'affichage (l'elixir bouge) : ici on ne donne que la place.
		r[i] = { cout = v, part = v / m }
	end
	return r
end

return Cout
