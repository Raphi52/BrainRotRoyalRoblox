-- QUITTER SES DUELS EN SERIE, en regles PURES.
--
-- Le defaut corrige : rien ne decourageait l'abandon. Des qu'un joueur etait mene, il pouvait
-- partir sans rien perdre et relancer une partie dans la seconde. En face, on gagnait une victoire
-- creuse a la premiere couronne — et un joueur sur deux voyait ses duels s'arreter avant la fin.
-- C'est la plainte la plus banale du PvP, et elle n'avait aucune reponse dans le jeu.
--
-- CE QU'ON NE FAIT PAS : punir le PREMIER depart. Une coupure de reseau, un appel, une urgence
-- ressemblent exactement a un abandon vu du serveur. Le premier est donc GRATUIT ; c'est la
-- REPETITION qui est sanctionnee, parce qu'elle, on ne la fait pas par accident.
local Abandon = {}

Abandon.FENETRE = 1800        -- on oublie un abandon au bout de 30 minutes
-- Attente avant de pouvoir relancer une recherche, selon le nombre d'abandons dans la fenetre.
-- Le premier ne coute rien ; ensuite cela monte vite, puis plafonne : au-dela, on ne corrige plus
-- un comportement, on chasse le joueur du jeu.
Abandon.PALIERS = { 0, 30, 120, 300 }

-- SEUL UN DEPART VOLONTAIRE COMPTE, et seulement s'il laisse un HUMAIN en plan. Partir d'une
-- partie contre le robot ne lese personne ; une coupure reseau est traitee ailleurs (Reprise), et
-- surtout elle n'est pas un choix.
function Abandon.compteCommeFuite(volontaire, partieEnCours, adversaireHumain)
	return volontaire == true and partieEnCours == true and adversaireHumain == true
end

local function nombre(v)
	return tonumber(v) or 0
end

-- On ne garde que les abandons RECENTS : la liste ne grossit pas indefiniment, et un joueur qui
-- s'est calme repart d'une ardoise propre.
function Abandon.purger(liste, maintenant)
	local out = {}
	local t = nombre(maintenant)
	for _, instant in ipairs(liste or {}) do
		if t - nombre(instant) < Abandon.FENETRE then
			table.insert(out, nombre(instant))
		end
	end
	return out
end

function Abandon.noter(liste, maintenant)
	local out = Abandon.purger(liste, maintenant)
	table.insert(out, nombre(maintenant))
	return out
end

function Abandon.compte(liste, maintenant)
	return #Abandon.purger(liste, maintenant)
end

function Abandon.attente(compte)
	local n = math.max(0, math.floor(nombre(compte)))
	if n <= 0 then
		return 0
	end
	return Abandon.PALIERS[math.min(n, #Abandon.PALIERS)]
end

-- Temps restant avant de pouvoir relancer une recherche. Il court depuis le DERNIER abandon.
function Abandon.reste(liste, maintenant)
	local recents = Abandon.purger(liste, maintenant)
	if #recents == 0 then
		return 0
	end
	local dernier = recents[#recents]
	local du = Abandon.attente(#recents)
	return math.max(0, math.ceil(dernier + du - nombre(maintenant)))
end

function Abandon.autorise(liste, maintenant)
	return Abandon.reste(liste, maintenant) <= 0
end

-- UNE PARTIE MENEE A SON TERME EFFACE UN ABANDON. Sans cela, la sanction ne ferait que s'empiler
-- et un joueur reveu ne pourrait jamais revenir a zero : on punirait un passe, pas un
-- comportement.
function Abandon.pardonner(liste, maintenant)
	local recents = Abandon.purger(liste, maintenant)
	table.remove(recents, 1) -- le plus ancien s'efface
	return recents
end

-- CE QU'ON DIT AU JOUEUR. Une attente sans explication ressemble a un bug, et le joueur ne
-- comprend pas ce qu'il doit changer.
function Abandon.texte(reste)
	local r = math.max(0, math.floor(nombre(reste)))
	if r <= 0 then
		return nil
	end
	if r >= 60 then
		return string.format("Tu as quitte des duels en cours : nouvelle partie dans %d:%02d",
			math.floor(r / 60), r % 60)
	end
	return string.format("Tu as quitte des duels en cours : nouvelle partie dans %d s", r)
end

return Abandon
