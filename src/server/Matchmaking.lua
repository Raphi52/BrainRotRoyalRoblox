-- Recherche d'adversaire : file d'attente partagee entre TOUS les serveurs hub (MemoryStore),
-- puis un serveur RESERVE par match (TeleportService:ReserveServer) ou arrivent les deux joueurs.
-- Si personne n'est trouve en ATTENTE_MAX secondes, le joueur joue contre le robot sur place.
--
-- La logique de decision (qui mene, avec qui) est PURE et testee hors Roblox
-- (tools/test_matchmaking.py) ; seules les fonctions du bas touchent aux services Roblox.
local M = {}
M.CARTE_PRIVE = "BRR_Prive_v1"

M.ATTENTE_MAX = 20 -- secondes avant de donner le robot
-- ATTENDRE UN HUMAIN. La bascule vers le robot a 20 s etait SUBIE : un joueur qui veut un vrai
-- adversaire n'avait aucun moyen de le dire, et se retrouvait contre une machine. Avec ce choix,
-- il attend — mais jamais indefiniment : au-dela de ce plafond, on lui donne le robot quand meme
-- plutot que de le laisser devant un ecran d'attente sans fin.
M.ATTENTE_PATIENTE = 180
-- APPARIEMENT PAR NIVEAU DE JEU. Jusqu'ici la file etait « premier arrive, premier servi » : un
-- joueur a 3000 trophees avec un deck de niveau 5 pouvait tomber sur un debutant a 0 trophee au
-- niveau 1 — soit +40 % de points de vie et de degats sur chaque carte en face. La partie etait
-- jouee d'avance, pour les DEUX.
-- Deux garde-fous, et un seul reglage a comprendre : plus on attend, plus on elargit.
M.ECART_TROPHEES = 150   -- ecart accepte a la seconde 0
M.ELARGISSEMENT = 40     -- trophees d'ecart gagnes par seconde d'attente
M.ECART_NIVEAU = 1       -- ecart de niveau MOYEN de deck accepte (1 niveau = +10 % de statistiques)
M.PATIENCE_NIVEAU = 12   -- secondes apres lesquelles on tolere un niveau d'ecart de plus
-- EVITEMENT DU DUEL REPETE. Retomber trois fois de suite sur la meme personne donne le sentiment
-- d'un jeu vide — et, quand on vient de perdre, celui d'etre poursuivi. On evite donc un
-- adversaire recent TANT QU'UN AUTRE EST DISPONIBLE ; s'il est le seul, on joue quand meme,
-- parce qu'un duel contre un visage connu vaut mieux que le robot.
M.EVITEMENT = 600 -- secondes pendant lesquelles on prefere quelqu'un d'autre

-- `valeur.adv` : table { [identifiant] = horodatage } portee par l'entree de file, recopiee du
-- profil du joueur (il change de serveur entre deux parties, la memoire ne peut pas etre locale).
function M.dejaAffronte(valeur, cle, maintenant, fenetre)
	local adv = valeur and valeur.adv
	if not adv or cle == nil then
		return false
	end
	local quand = adv[tostring(cle)]
	if quand == nil then
		return false
	end
	return (maintenant or 0) - quand <= (fenetre or M.EVITEMENT)
end

-- Ecart de trophees tolere apres `attente` secondes. Il s'ouvre sans limite au moment ou le robot
-- arriverait de toute facon : mieux vaut un humain un peu plus fort qu'une machine.
function M.ecartTropheesTolere(attente)
	if (attente or 0) >= M.ATTENTE_MAX then
		return math.huge
	end
	return M.ECART_TROPHEES + (attente or 0) * M.ELARGISSEMENT
end

-- Ecart de NIVEAU tolere : 1 au depart, 2 apres PATIENCE_NIVEAU, sans limite au seuil du robot.
function M.ecartNiveauTolere(attente)
	if (attente or 0) >= M.ATTENTE_MAX then
		return math.huge
	end
	if (attente or 0) >= M.PATIENCE_NIVEAU then
		return M.ECART_NIVEAU + 1
	end
	return M.ECART_NIVEAU
end

-- DEUX JOUEURS SONT-ILS APPARIABLES ? `a` et `b` : { tr = trophees, nv = niveau moyen du deck }.
-- Une entree SANS ces champs (vieille entree, profil illisible) reste appariable : on ne laisse
-- jamais un joueur seul en file a cause d'une donnee manquante.
-- L'attente retenue est la PLUS LONGUE des deux : celui qui patiente depuis longtemps fait
-- profiter l'autre de son elargissement.
function M.compatible(a, b, attenteA, attenteB)
	if not a or not b then
		return false
	end
	local attente = math.max(attenteA or 0, attenteB or 0)
	if a.tr and b.tr and math.abs(a.tr - b.tr) > M.ecartTropheesTolere(attente) then
		return false
	end
	if a.nv and b.nv and math.abs(a.nv - b.nv) > M.ecartNiveauTolere(attente) then
		return false
	end
	return true
end
M.DUREE_ENTREE = 60 -- expiration d'une entree de file (joueur parti sans prevenir)
M.CARTE = "BRR_File_v1"

-- entrees : liste { cle = "userId", valeur = { t = horodatage, code = nil|"..." } } triee par t.
-- Rend l'adversaire que `moi` doit prendre, ou nil. Une seule des deux parties decide : celle dont
-- l'entree est la plus ANCIENNE des entrees libres. Sans cette regle, deux serveurs reserveraient
-- chacun un serveur pour la meme paire.
-- `maintenant` (facultatif) : horodatage commun, pour calculer l'attente de chacun (valeur.t).
-- Sans lui, l'appariement redevient « le plus ancien prend le suivant », comme avant.
-- FILE BLOQUEE (defaut corrige le 2026-09-21) : seul le PLUS ANCIEN de toute la file pouvait
-- former un match. S'il n'etait compatible avec personne (3000 trophees, seul a ce niveau), plus
-- AUCUN duel ne se formait derriere lui — 20 s, et jusqu'a 3 minutes en mode « attendre un humain ».
-- Desormais la file est parcourue dans l'ordre d'anciennete : chaque joueur encore seul prend son
-- meilleur partenaire parmi les PLUS RECENTS que lui. Tous les serveurs lisent la meme file et font
-- le meme calcul : chaque paire a toujours UN SEUL meneur (le plus ancien des deux).
local function meilleurPartenaire(libres, i, pris, maintenant)
	local e0 = libres[i]
	local mien = e0.valeur
	local moi = e0.cle
	local attenteMoi = maintenant and mien.t and (maintenant - mien.t) or nil
	-- Le MEILLEUR adversaire compatible, pas le premier venu : a egalite d'attente, le plus proche
	-- en trophees. Sans candidat compatible, on n'apparie PAS — la file elargit d'elle-meme a la
	-- seconde suivante, et le robot reste le filet de securite a ATTENTE_MAX.
	-- Deux listes : ceux qu'on n'a PAS affrontes recemment, et les autres. On ne retombe sur un
	-- visage connu que si la premiere est vide — jamais au prix d'une attente supplementaire.
	local meilleur, meilleurEcart = nil, math.huge
	local repli, repliEcart = nil, math.huge
	for j = i + 1, #libres do
		local e = libres[j]
		local attenteLui = maintenant and e.valeur.t and (maintenant - e.valeur.t) or nil
		if not pris[e.cle] and M.compatible(mien, e.valeur, attenteMoi, attenteLui) then
			local ecart = (mien.tr and e.valeur.tr) and math.abs(mien.tr - e.valeur.tr) or 0
			-- l'evitement vaut dans LES DEUX SENS : il suffit que l'un des deux se souvienne
			local recent = M.dejaAffronte(mien, e.cle, maintenant)
				or M.dejaAffronte(e.valeur, moi, maintenant)
			if recent then
				if ecart < repliEcart then
					repli, repliEcart = e.cle, ecart
				end
			elseif ecart < meilleurEcart then
				meilleur, meilleurEcart = e.cle, ecart
			end
		end
	end
	return meilleur or repli
end

function M.choisirAdversaire(entrees, moi, maintenant)
	local libres = {}
	for _, e in ipairs(entrees) do
		if e.valeur and not e.valeur.code then
			libres[#libres + 1] = e
		end
	end
	local pris = {}
	for i, e in ipairs(libres) do
		if not pris[e.cle] then
			local autre = meilleurPartenaire(libres, i, pris, maintenant)
			if autre then
				pris[e.cle], pris[autre] = true, true
				if e.cle == moi then
					return autre
				end
			end
		end
		if e.cle == moi then
			return nil -- je suis le plus recent de ma paire, ou sans partenaire : l'autre mene
		end
	end
	return nil
end

-- RENOUVELER son entree a chaque tour (defaut corrige le 2026-09-21) : l'entree expirait au bout de
-- DUREE_ENTREE (60 s) alors qu'un joueur patient attend jusqu'a 180 s. Passee la minute, il
-- DISPARAISSAIT de la file tout en restant « en recherche » : personne ne pouvait plus le trouver.
-- Rend la valeur a reecrire (meme contenu, nouvelle duree), ou nil si l'entree est prise ou partie.
function M.renouveler(valeur)
	if valeur == nil or valeur.code then
		return nil
	end
	return valeur
end

-- MISE A JOUR d'une entree DEJA en file, sans perdre sa place. Le joueur qui change de deck
-- pendant la recherche portait sinon un niveau PERIME : la file l'appariait sur un deck qu'il
-- n'emmene plus. On garde son horodatage (donc son anciennete) et on refuse de toucher a une
-- entree deja PRISE par un autre serveur — ce serait casser un match en train de se former.
function M.majValeur(valeur, profil)
	if valeur == nil or valeur.code then
		return nil
	end
	local p = profil or {}
	return { t = valeur.t, tr = p.tr, nv = p.nv, adv = p.adv }
end

-- COMBIEN DE JOUEURS CHERCHENT ? Compte les entrees LIBRES (celles deja prises sont des matchs en
-- cours de formation, pas des gens qui attendent).
function M.compterLibres(entrees)
	local n = 0
	for _, e in ipairs(entrees or {}) do
		if e.valeur and not e.valeur.code then
			n = n + 1
		end
	end
	return n
end

-- Prise d'une entree dans un UpdateAsync : n'accepte que si elle est encore libre.
function M.marquer(valeur, code)
	if valeur == nil or valeur.code then
		return nil -- deja prise (ou partie) : on n'ecrase pas
	end
	return { t = valeur.t, code = code, tr = valeur.tr, nv = valeur.nv, adv = valeur.adv }
end

-- Rendre sa place a une entree que J'AI marquee (mon code) quand l'adversaire m'a echappe. On ne
-- touche pas a un code pose par un autre serveur : celui-la est un vrai match.
function M.liberer(valeur, code)
	if valeur == nil or valeur.code ~= code then
		return nil
	end
	return { t = valeur.t, tr = valeur.tr, nv = valeur.nv, adv = valeur.adv }
end

M.LECTURE_FILE = 100

-- `patient` : le joueur a demande a attendre un humain. Le plafond devient ATTENTE_PATIENTE.
function M.robotDu(debut, maintenant, patient)
	local seuil = patient and M.ATTENTE_PATIENTE or M.ATTENTE_MAX
	return (maintenant - debut) >= seuil
end

-- Temps restant avant le robot, pour l'annoncer au lieu de le subir.
function M.avantRobot(debut, maintenant, patient)
	local seuil = patient and M.ATTENTE_PATIENTE or M.ATTENTE_MAX
	return math.max(0, seuil - (maintenant - debut))
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

-- `donnees` (facultatif) : table transportee AVEC le joueur (TeleportData). C'est par la que le
-- mode « niveaux egalises » d'un duel prive atteint le serveur reserve : lui ne connait ni le code
-- ni la file, il ne voit que les joueurs qui arrivent.
local function teleporter(joueurs, code, donnees)
	local TeleportService = game:GetService("TeleportService")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	if donnees then
		options:SetTeleportData(donnees)
	end
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
	-- Lire ET renouveler son entree d'un seul geste : sans ce renouvellement, elle expirait a 60 s
	-- et le joueur patient devenait introuvable. La cle de tri (l'heure d'arrivee) est rendue avec
	-- la valeur, sinon la mise a jour l'effacerait et l'entree sortirait de l'ordre d'anciennete.
	local valeur
	local okLu = pcall(function()
		map:UpdateAsync(moi, function(v)
			valeur = v
			local n = M.renouveler(v)
			if n == nil then
				return nil
			end
			return n, n.t
		end, M.DUREE_ENTREE)
	end)
	-- Entree disparue (expiree, ou effacee) alors que le joueur cherche encore : on la REPOSE avec
	-- son heure d'arrivee d'origine, pour qu'il garde son rang dans la file.
	if okLu and valeur == nil and etat.entree then
		pcall(function()
			map:SetAsync(moi, etat.entree, M.DUREE_ENTREE, etat.entree.t)
		end)
	end
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
		-- Triee par HEURE D'ARRIVEE (cle de tri), et non par identifiant : a 20 entrees lues dans
		-- l'ordre des identifiants, les joueurs au-dela n'etaient jamais vus. 100 = maximum permis.
		return map:GetRangeAsync(Enum.SortDirection.Ascending, M.LECTURE_FILE)
	end)
	if okListe and liste then
		local entrees = {}
		for _, e in ipairs(liste) do
			entrees[#entrees + 1] = { cle = e.key, valeur = e.value }
		end
		table.sort(entrees, function(a, b)
			return (a.valeur and a.valeur.t or 0) < (b.valeur and b.valeur.t or 0)
		end)
		local autre = M.choisirAdversaire(entrees, moi, os.time())
		if autre then
			local okCode, code = pcall(function()
				return game:GetService("TeleportService"):ReserveServer(game.PlaceId)
			end)
			-- SE RESERVER D'ABORD. Deux serveurs peuvent lire la file a des instants differents : sans
			-- ce verrou, je pouvais prendre B pendant qu'un troisieme me prenait moi — et partir seul.
			-- Je marque donc MA propre entree ; si elle etait deja prise, je laisse faire l'autre.
			local moiPris = false
			if okCode and code then
				pcall(function()
					map:UpdateAsync(moi, function(v)
						local n = M.marquer(v, code)
						moiPris = n ~= nil
						if n == nil then
							return nil
						end
						return n, n.t
					end, M.DUREE_ENTREE)
				end)
			end
			if okCode and code and moiPris then
				local pris = false
				pcall(function()
					map:UpdateAsync(autre, function(v)
						local n = M.marquer(v, code)
						pris = n ~= nil
						if n == nil then
							return nil
						end
						return n, n.t
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
				-- L'autre a ete pris entre-temps : je me LIBERE, sinon je resterais marque d'un code
				-- de serveur ou personne ne viendra.
				pcall(function()
					map:UpdateAsync(moi, function(v)
						local n = M.liberer(v, code)
						if n == nil then
							return nil
						end
						return n, n.t
					end, M.DUREE_ENTREE)
				end)
			end
		end
	end
	if M.robotDu(etat.debut, os.clock(), etat.patient) then
		etat.etat = "robot"
		sortirDeLaFile(player)
		print("[BRR] " .. player.Name .. " : personne apres " .. M.ATTENTE_MAX .. " s, partie contre le robot")
		robot(player)
	end
end

-- `profil(player)` rend { tr = trophees, nv = niveau moyen du deck } : l'appelant (GameServer) le
-- fournit, pour que ce module ne depende pas de l'economie.
function M.entrer(player, robot, profil, patient)
	if enAttente[player] then
		return enAttente[player].etat
	end
	local etat = { debut = os.clock(), etat = "attente", patient = patient == true }
	enAttente[player] = etat
	local carteJoueur = (profil and profil(player)) or {}
	local arrivee = os.time() + os.clock() % 1
	-- adversaires recents : recopies du profil, pour que l'evitement survive au changement de
	-- serveur entre deux parties. L'entree est gardee en memoire pour la reposer si elle expire.
	etat.entree = { t = arrivee, tr = carteJoueur.tr, nv = carteJoueur.nv, adv = carteJoueur.adv }
	local ok = pcall(function()
		carte():SetAsync(tostring(player.UserId), etat.entree, M.DUREE_ENTREE, arrivee)
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

-- Ecrit le nouveau profil du joueur dans sa propre entree de file (deck change en pleine
-- recherche). Sans effet s'il n'est pas en attente.
function M.majProfil(player, profil)
	if not (enAttente[player] and enAttente[player].etat == "attente") then
		return false
	end
	local fait = false
	pcall(function()
		carte():UpdateAsync(tostring(player.UserId), function(v)
			local n = M.majValeur(v, profil)
			fait = n ~= nil
			if n == nil then
				return nil
			end
			return n, n.t
		end, M.DUREE_ENTREE)
	end)
	if fait then
		-- la copie de secours (reposee si l'entree expire) suit le nouveau deck
		local e0 = enAttente[player].entree
		if e0 then
			enAttente[player].entree = { t = e0.t, tr = profil and profil.tr, nv = profil and profil.nv,
				adv = profil and profil.adv }
		end
		print("[BRR] " .. player.Name .. " : deck change en file, appariement mis a jour")
	end
	return fait
end

-- NOMBRE DE JOUEURS EN RECHERCHE, avec un cache court : MemoryStore est plafonne en lectures, et
-- le hub redemande toutes les secondes.
local cacheFile, cacheFileA = 0, -math.huge
M.CACHE_FILE = 3
function M.compterFile()
	if os.clock() - cacheFileA < M.CACHE_FILE then
		return cacheFile
	end
	local ok, liste = pcall(function()
		return carte():GetRangeAsync(Enum.SortDirection.Ascending, 50)
	end)
	if ok and liste then
		local entrees = {}
		for _, e in ipairs(liste) do
			entrees[#entrees + 1] = { cle = e.key, valeur = e.value }
		end
		cacheFile = M.compterLibres(entrees)
		cacheFileA = os.clock()
	end
	return cacheFile
end

-- PRENDRE LE ROBOT TOUT DE SUITE : la sortie de secours de l'attente patiente. Sans elle, choisir
-- « attendre un humain » serait un piege de trois minutes.
function M.robotMaintenant(player, robot)
	local etat = enAttente[player]
	if not (etat and etat.etat == "attente") then
		return false
	end
	etat.etat = "robot"
	sortirDeLaFile(player)
	print("[BRR] " .. player.Name .. " : robot demande tout de suite")
	robot(player)
	return true
end

-- Secondes restantes avant la bascule automatique (0 = elle est due).
function M.resteAvantRobot(player)
	local etat = enAttente[player]
	if not (etat and etat.etat == "attente") then
		return 0
	end
	return M.avantRobot(etat.debut, os.clock(), etat.patient)
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

-- ===== DUEL PRIVE =====
-- Un code a partager, qui court-circuite la file : les deux amis arrivent dans le MEME serveur
-- reserve, donc dans la meme arene, avec le coup d'envoi commun (Duel.attente) qui attend le second.
-- Le module de code prive est charge A L'USAGE, pas au chargement : ce fichier est EXECUTE hors
-- Roblox par tools/test_matchmaking.py, ou `game` n'existe pas. Un require en tete le cassait.
local function Prive()
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Prive"))
end

local function cartePrive()
	return game:GetService("MemoryStoreService"):GetSortedMap(M.CARTE_PRIVE)
end

-- L'hote CREE le duel : un serveur reserve, un code, et l'attente de l'ami sur place.
-- Rend (code, nil) ou (nil, motif en clair).
function M.creerPrive(player, tirage, egalise)
	if not M.actif() then
		return nil, Prive().motif("studio")
	end
	local okCode, acces = pcall(function()
		return game:GetService("TeleportService"):ReserveServer(game.PlaceId)
	end)
	if not (okCode and acces) then
		return nil, Prive().motif("indisponible")
	end
	local code = Prive().code(tirage or function(n)
		return math.random(1, n)
	end)
	local ecrit = pcall(function()
		cartePrive():SetAsync(code, { acces = acces, hote = tostring(player.UserId), t = os.time(),
			-- le mode voyage avec le CODE : l'invite partira dans les memes conditions que l'hote
			egalise = egalise == true }, Prive().DUREE)
	end)
	if not ecrit then
		return nil, Prive().motif("indisponible")
	end
	print("[BRR] duel prive cree par " .. player.Name .. " : code " .. Prive().joli(code))
	-- L'hote part le premier : le serveur reserve l'attend (coup d'envoi commun cote GameServer).
	teleporter({ player }, acces, { egalise = egalise == true, prive = true })
	return code, nil
end

-- L'INVITE entre le code. Rend (true, nil) ou (false, motif en clair).
function M.rejoindrePrive(player, saisie)
	if not M.actif() then
		return false, Prive().motif("studio")
	end
	local code = Prive().normaliser(saisie)
	if not Prive().valide(code) then
		return false, Prive().motif("invalide")
	end
	local okLu, entree = pcall(function()
		return cartePrive():GetAsync(code)
	end)
	if not okLu or not entree then
		return false, Prive().motif("inconnu")
	end
	if entree.t and Prive().expire(entree.t, os.time(), Prive().DUREE) then
		return false, Prive().motif("expire")
	end
	if entree.hote == tostring(player.UserId) then
		return false, Prive().motif("soi")
	end
	print("[BRR] " .. player.Name .. " rejoint le duel prive " .. Prive().joli(code))
	if not teleporter({ player }, entree.acces, { egalise = entree.egalise == true, prive = true }) then
		return false, Prive().motif("indisponible")
	end
	return true, nil
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
