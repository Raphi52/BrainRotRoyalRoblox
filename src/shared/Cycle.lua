-- CYCLE DES CARTES : la main de 4, la file de 8, et ce qui revient.
--
-- Le serveur faisait deja tourner une file, mais avec trois manques :
--  1. AUCUN DOUBLON EMPECHE — un paquet de moins de 8 cartes etait complete en REPETANT les memes
--     identifiants, si bien que la meme carte pouvait occuper deux cases de la main. Le joueur en
--     voyait deux, n'en comprenait qu'une, et son cycle n'avait plus de sens.
--  2. UNE SEULE carte suivante annoncee, alors que tout l'interet du genre est de COMPTER son
--     cycle pour savoir quand la carte cle revient.
--  3. Aucun moyen de savoir dans COMBIEN de coups une carte donnee revient.
--
-- Fonctions PURES (tools/test_cycle.py). Le serveur s'en sert pour construire et faire tourner.
local Cycle = {}

Cycle.TAILLE_MAIN = 4
Cycle.TAILLE_PAQUET = 8
Cycle.SUIVANTES_VUES = 2 -- combien de cartes a venir le client affiche

-- Melange de Fisher-Yates, avec un tirage FOURNI par l'appelant (`tirage(n)` rend 1..n). Le banc
-- passe une suite deterministe ; le serveur passe math.random. Aucun appel au hasard ici.
function Cycle.melanger(ids, tirage)
	local l = {}
	for _, id in ipairs(ids) do
		table.insert(l, id)
	end
	for i = #l, 2, -1 do
		local j = tirage and tirage(i) or i
		j = math.max(1, math.min(math.floor(j), i))
		l[i], l[j] = l[j], l[i]
	end
	return l
end

-- CONSTRUIT le paquet de 8, SANS DOUBLON tant qu'il y a de quoi. Moins de 8 cartes distinctes : on
-- complete en repetant, mais en repoussant les repetitions a la FIN, pour qu'aucune main de depart
-- ne montre deux fois la meme carte.
function Cycle.paquet(ids, tirage)
	local vus, distincts = {}, {}
	for _, id in ipairs(ids or {}) do
		if id and not vus[id] then
			vus[id] = true
			table.insert(distincts, id)
		end
	end
	if #distincts == 0 then
		return {}
	end
	local paquet = Cycle.melanger(distincts, tirage)
	local i = 1
	while #paquet < Cycle.TAILLE_PAQUET do
		table.insert(paquet, paquet[i])
		i = i + 1
	end
	while #paquet > Cycle.TAILLE_PAQUET do
		table.remove(paquet)
	end
	return paquet
end

-- MAIN + FILE de depart.
function Cycle.distribuer(ids, tirage)
	local p = Cycle.paquet(ids, tirage)
	local main, file = {}, {}
	for i, id in ipairs(p) do
		if i <= Cycle.TAILLE_MAIN then
			table.insert(main, id)
		else
			table.insert(file, id)
		end
	end
	return main, file
end

-- JOUER la case `index` : la carte part en FOND de file, la tete de file prend sa place.
-- Rend (carteJouee, ok). Une case vide ou hors bornes ne consomme rien.
function Cycle.jouer(main, file, index)
	local id = main and main[index]
	if not id or not file or #file == 0 then
		return nil, false
	end
	main[index] = table.remove(file, 1)
	table.insert(file, id)
	return id, true
end

-- Les prochaines cartes, pour le bandeau du client.
function Cycle.suivantes(file, combien)
	local n = combien or Cycle.SUIVANTES_VUES
	local l = {}
	for i = 1, n do
		if file and file[i] then
			table.insert(l, file[i])
		end
	end
	return l
end

-- DANS COMBIEN DE COUPS cette carte revient-elle en main ? 0 = elle y est deja, sinon son rang
-- dans la file. nil si elle n'est pas dans le paquet.
function Cycle.retour(main, file, id)
	for _, c in ipairs(main or {}) do
		if c == id then
			return 0
		end
	end
	for i, c in ipairs(file or {}) do
		if c == id then
			return i
		end
	end
	return nil
end

-- COUT MOYEN du paquet, en elixir : la mesure qui dit si un deck est lourd ou rapide.
-- `coutDe(id)` est fourni par l'appelant, donc ce module ne depend pas du catalogue.
function Cycle.coutMoyen(ids, coutDe)
	local total, n = 0, 0
	for _, id in ipairs(ids or {}) do
		local c = coutDe and coutDe(id)
		if c then
			total = total + c
			n = n + 1
		end
	end
	if n == 0 then
		return 0
	end
	return total / n
end

return Cycle
