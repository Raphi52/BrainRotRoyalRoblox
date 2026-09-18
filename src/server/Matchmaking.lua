-- Recherche d'adversaire : file d'attente partagee entre TOUS les serveurs hub (MemoryStore),
-- puis un serveur RESERVE par match (TeleportService:ReserveServer) ou arrivent les deux joueurs.
-- Si personne n'est trouve en ATTENTE_MAX secondes, le joueur joue contre le robot sur place.
--
-- La logique de decision (qui mene, avec qui) est PURE et testee hors Roblox
-- (tools/test_matchmaking.py) ; seules les fonctions du bas touchent aux services Roblox.
local M = {}

M.ATTENTE_MAX = 20 -- secondes avant de donner le robot
M.DUREE_ENTREE = 60 -- expiration d'une entree de file (joueur parti sans prevenir)
M.CARTE = "BRR_File_v1"

-- entrees : liste { cle = "userId", valeur = { t = horodatage, code = nil|"..." } } triee par t.
-- Rend l'adversaire que `moi` doit prendre, ou nil. Une seule des deux parties decide : celle dont
-- l'entree est la plus ANCIENNE des entrees libres. Sans cette regle, deux serveurs reserveraient
-- chacun un serveur pour la meme paire.
function M.choisirAdversaire(entrees, moi)
	local libres = {}
	for _, e in ipairs(entrees) do
		if e.valeur and not e.valeur.code then
			libres[#libres + 1] = e
		end
	end
	if #libres < 2 or libres[1].cle ~= moi then
		return nil
	end
	return libres[2].cle
end

-- Prise d'une entree dans un UpdateAsync : n'accepte que si elle est encore libre.
function M.marquer(valeur, code)
	if valeur == nil or valeur.code then
		return nil -- deja prise (ou partie) : on n'ecrase pas
	end
	return { t = valeur.t, code = code }
end

function M.robotDu(debut, maintenant)
	return maintenant - debut >= M.ATTENTE_MAX
end

-- Serveur reserve (match) : PrivateServerId non vide ET aucun proprietaire.
function M.estServeurDeMatch(jeu)
	return jeu.PrivateServerId ~= "" and jeu.PrivateServerOwnerId == 0
end

-- ===== Partie Roblox =====
local enAttente = {} -- player -> { debut = os.clock(), etat = "attente"|"robot"|"teleport" }

local function carte()
	return game:GetService("MemoryStoreService"):GetSortedMap(M.CARTE)
end

local function teleporter(joueurs, code)
	local TeleportService = game:GetService("TeleportService")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, joueurs, options)
	end)
	if not ok then
		warn("[BRR] teleportation vers le match echouee : " .. tostring(err))
	end
	return ok
end

-- La file ne sert que dans un vrai serveur en ligne : dans Studio, ReserveServer est refuse.
function M.actif()
	return not game:GetService("RunService"):IsStudio() and not M.estServeurDeMatch(game)
end

local function sortirDeLaFile(player)
	pcall(function()
		carte():RemoveAsync(tostring(player.UserId))
	end)
end

-- Un tour de recherche pour un joueur en attente. `robot(player)` = le faire jouer sur place.
local function tour(player, etat, robot)
	local moi = tostring(player.UserId)
	local map = carte()
	-- Quelqu'un nous a deja pris ? (code ecrit par le serveur de l'autre joueur)
	local okLu, valeur = pcall(function()
		return map:GetAsync(moi)
	end)
	if okLu and valeur and valeur.code then
		etat.etat = "teleport"
		print("[BRR] " .. player.Name .. " : adversaire trouve, depart vers le match")
		sortirDeLaFile(player)
		if not teleporter({ player }, valeur.code) then
			etat.etat = "robot"
			robot(player)
		end
		return
	end
	local okListe, liste = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 20)
	end)
	if okListe and liste then
		local entrees = {}
		for _, e in ipairs(liste) do
			entrees[#entrees + 1] = { cle = e.key, valeur = e.value }
		end
		table.sort(entrees, function(a, b)
			return (a.valeur and a.valeur.t or 0) < (b.valeur and b.valeur.t or 0)
		end)
		local autre = M.choisirAdversaire(entrees, moi)
		if autre then
			local okCode, code = pcall(function()
				return game:GetService("TeleportService"):ReserveServer(game.PlaceId)
			end)
			if okCode and code then
				local pris = false
				pcall(function()
					map:UpdateAsync(autre, function(v)
						local n = M.marquer(v, code)
						pris = n ~= nil
						return n
					end, M.DUREE_ENTREE)
				end)
				if pris then
					etat.etat = "teleport"
					print("[BRR] " .. player.Name .. " : match forme avec " .. autre)
					sortirDeLaFile(player)
					if not teleporter({ player }, code) then
						etat.etat = "robot"
						robot(player)
					end
					return
				end
			end
		end
	end
	if M.robotDu(etat.debut, os.clock()) then
		etat.etat = "robot"
		sortirDeLaFile(player)
		print("[BRR] " .. player.Name .. " : personne apres " .. M.ATTENTE_MAX .. " s, partie contre le robot")
		robot(player)
	end
end

function M.entrer(player, robot)
	if enAttente[player] then
		return enAttente[player].etat
	end
	local etat = { debut = os.clock(), etat = "attente" }
	enAttente[player] = etat
	local ok = pcall(function()
		carte():SetAsync(tostring(player.UserId), { t = os.time() + os.clock() % 1 }, M.DUREE_ENTREE)
	end)
	if not ok then
		-- MemoryStore indisponible : on ne fait pas attendre pour rien
		etat.etat = "robot"
		robot(player)
		return etat.etat
	end
	print("[BRR] " .. player.Name .. " entre dans la file d'attente")
	task.spawn(function()
		while enAttente[player] == etat and etat.etat == "attente" and player.Parent do
			tour(player, etat, robot)
			task.wait(2)
		end
	end)
	return etat.etat
end

function M.etat(player)
	return enAttente[player] and enAttente[player].etat or nil
end

function M.sortir(player)
	if enAttente[player] then
		enAttente[player] = nil
		sortirDeLaFile(player)
	end
end

-- Fin de match sur un serveur reserve : tout le monde retourne sur un serveur hub public.
function M.retourHub()
	local joueurs = game:GetService("Players"):GetPlayers()
	if #joueurs > 0 then
		pcall(function()
			game:GetService("TeleportService"):TeleportAsync(game.PlaceId, joueurs)
		end)
	end
end

return M
