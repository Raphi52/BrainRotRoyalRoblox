-- ECONOMIE : profil sauvegarde, recompenses, boutique, achats Robux.
--
-- Le serveur est la SEULE autorite : le client demande, le serveur verifie le prix, le solde et la
-- carte avant de debiter. Rien de ce que le client envoie n'est cru sur parole.
--
-- SAUVEGARDE : DataStoreService. Dans Studio, elle echoue tant que « Enable Studio Access to API
-- Services » n'est pas coche (Game Settings > Security) ; le profil vit alors en memoire pour la
-- session et le journal le dit ([ECO] sauvegarde indisponible). Une fois le jeu publie, elle marche.
--
-- ROBUX : les identifiants de produits et de pass se creent sur le compte du createur
-- (create.roblox.com > l'experience > Monetization). Tant qu'ils valent 0, l'offre est MASQUEE et
-- aucun achat n'est propose : rien n'est vendu par erreur.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cards"))
-- ARENES : paliers de trophees (nom, protection du bas de tableau, recompense de palier,
-- cartes debloquees). Fonctions pures, verifiees par tools/test_arenes.py.
local Arenes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Arenes"))

local Economie = {}

-- A REMPLIR par le createur apres creation sur create.roblox.com (0 = desactive).
Economie.PRODUITS = {
	{ id = 0, nom = "Sac de 500 pieces", pieces = 500 },
	{ id = 0, nom = "Coffre de 1500 pieces", pieces = 1500 },
	{ id = 0, nom = "Poignee de 80 gemmes", gemmes = 80 }, -- monnaie premium, uniquement en Robux
}
Economie.PASS_VIP = 0 -- pass « VIP » : pieces x2 en fin de partie

-- DECK : nombre de cartes emportees en partie (4 en main + 4 en file, voir newDeck cote serveur
-- de jeu). Tant que le joueur possede moins de DECK_TAILLE cartes, aucun choix n'est possible et
-- il joue avec tout ce qu'il a (comportement d'avant le deck choisi).
Economie.DECK_TAILLE = 8

local RECOMPENSE = {
	victoire = { pieces = 30, trophees = 30 },
	defaite = { pieces = 10, trophees = -15 },
	egalite = { pieces = 15, trophees = 0 },
}
local BONUS_JOUR = 50
-- SERIE DE VICTOIRES : +BONUS_SERIE pieces par victoire consecutive au-dela de la premiere,
-- plafonne a SERIE_MAX. Fonction PURE : verifiee hors Studio (tools/test_serie.py).
local BONUS_SERIE = 10
Economie.SERIE_MAX = 5
function Economie.bonusSerie(serie)
	if not serie or serie < 2 then
		return 0
	end
	return math.min(serie - 1, Economie.SERIE_MAX) * BONUS_SERIE
end
-- Pronostic juste d'un spectateur (voir GameServer) : petite recompense, le pari est gratuit.
local GAIN_PRONOSTIC = 15
-- Victoire contre un HUMAIN (pas le bot) : pieces en plus, pour donner envie de jouer entre joueurs.
local BONUS_HUMAIN = 20

-- COFFRES : gagnes a la victoire, ouverts apres un temps d'attente (une ouverture a la fois).
-- `chanceCarte` : probabilite de debloquer une carte encore verrouillee ; si tout est deja
-- debloque, elle devient `piecesSiComplet` pieces de plus (jamais un tirage vide).
Economie.COFFRES = {
	bois = { nom = "Coffre en bois", duree = 15 * 60, pieces = { 20, 40 }, chanceCarte = 0.10, piecesSiComplet = 20, poids = 70 },
	argent = { nom = "Coffre d'argent", duree = 60 * 60, pieces = { 60, 100 }, chanceCarte = 0.35, piecesSiComplet = 60, poids = 25 },
	["or"] = { nom = "Coffre d'or", duree = 3 * 60 * 60, pieces = { 150, 250 }, chanceCarte = 1.0, piecesSiComplet = 200, poids = 5 },
}
Economie.ORDRE_COFFRES = { "bois", "argent", "or" }
-- exemplaires donnes par coffre (tous pour UNE carte debloquee tiree au hasard)
Economie.EXEMPLAIRES_COFFRE = { bois = 3, argent = 8, ["or"] = 20 }

-- NIVEAUX DE CARTES : niveau 1 a NIVEAU_MAX. Passer du niveau n a n+1 coute EXEMPLAIRES[n]
-- exemplaires de la carte et COUT_NIVEAU[n] pieces. Chaque niveau au-dessus de 1 : +10 % de points
-- de vie et de degats (Economie.multiplicateur).
Economie.NIVEAU_MAX = 5
Economie.EXEMPLAIRES = { 2, 4, 10, 20 }
Economie.COUT_NIVEAU = { 50, 150, 400, 1000 }
Economie.BONUS_PAR_NIVEAU = 0.10
function Economie.multiplicateur(niveau)
	return 1 + Economie.BONUS_PAR_NIVEAU * ((niveau or 1) - 1)
end
-- NIVEAU DU ROBOT : le NIVEAU MOYEN DU DECK du joueur d'en face, arrondi. Mesure du 2026-09-14
-- (48 parties simulees, tools/sim-A.txt et sim-B.txt) : un seul niveau d'ecart fait gagner le plus
-- fort 71 % du temps, deux niveaux 88 %. Regle d'abord sur les trophees, le robot ne suivait pas
-- la vraie force des cartes du joueur ; il la suit maintenant directement.
function Economie.niveauMoyen(niveauxParCarte, ids)
	local total, n = 0, 0
	for _, id in ipairs(ids) do
		total += niveauxParCarte[id] or 1
		n += 1
	end
	if n == 0 then
		return 1
	end
	return math.clamp(math.floor(total / n + 0.5), 1, Economie.NIVEAU_MAX)
end
function Economie.niveauRobot(player)
	if not player then
		return 1
	end
	local ids = Economie.deck(player)
	if not ids then
		return 1
	end
	return Economie.niveauMoyen(Economie.niveaux(player), ids)
end
Economie.EMPLACEMENTS = 4
local rng = Random.new()
function Economie.graine(n) -- tests : tirages reproductibles
	rng = Random.new(n)
end
local UN_JOUR = 20 * 60 * 60 -- 20 h : on laisse de la marge a celui qui joue a heure fixe

local store, persistant = nil, false
-- fix-ok: une lecture de profil ratee ne coupait la sauvegarde QUE pour ce joueur-la ; le
-- drapeau `persistant` etant au niveau du module, elle la coupait pour TOUT le serveur.
-- L'echec est desormais retenu par joueur.
local sansSauvegarde = {} -- player -> true : profil illisible, on n'ecrit pas (sinon on l'ecrase)
-- Ecritures REGROUPEES : Roblox plafonne les SetAsync par cle. Chaque recompense, coffre ou
-- niveau marquait le profil d'un SetAsync immediat ; on note desormais le profil « sale » et
-- une seule ecriture part au plus toutes les DELAI_ECRITURE secondes.
local sales = {} -- player -> true : profil modifie en memoire, pas encore ecrit
local DELAI_ECRITURE = 30
-- Registre des RECUS d'achat Robux. Roblox rappelle ProcessReceipt jusqu'a obtenir une reponse :
-- sans trace du PurchaseId deja honore, un rappel apres crediter recredite le joueur.
local storeRecus = nil
-- CLASSEMENT entre serveurs : trophees par joueur (cle u<UserId>), recopies a chaque sauvegarde.
local storeClassement = nil
do
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore("BRR_Profils_v1")
	end)
	if ok then
		store, persistant = res, true
	else
		warn("[ECO] sauvegarde indisponible : " .. tostring(res))
	end
	local okC, resC = pcall(function()
		return DataStoreService:GetOrderedDataStore("BRR_Trophees_v1")
	end)
	if okC then
		storeClassement = resC
	else
		warn("[ECO] classement indisponible : " .. tostring(resC))
	end
	local okR, resR = pcall(function()
		return DataStoreService:GetDataStore("BRR_Recus")
	end)
	if okR then
		storeRecus = resR
	else
		warn("[ECO] registre des recus indisponible : " .. tostring(resR))
	end
end

local profils = {}

local function profilNeuf()
	local cartes = {}
	for _, c in ipairs(Cards.list) do
		if not c.prix then
			cartes[c.id] = true
		end
	end
	return { pieces = 100, gemmes = 0, trophees = 0, victoires = 0, parties = 0, cartes = cartes, dernierBonus = 0, coffres = {}, niveaux = {}, exemplaires = {}, serie = 0,
		dernierCoffreGratuit = 0, quetes = nil }
end

local function leaderstats(player, p)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
		local t = Instance.new("IntValue")
		t.Name = "Trophees"
		t.Parent = ls
		local pc = Instance.new("IntValue")
		pc.Name = "Pieces"
		pc.Parent = ls
	end
	ls.Trophees.Value = p.trophees
	ls.Pieces.Value = p.pieces
end

function Economie.profil(player)
	return profils[player]
end

function Economie.charger(player)
	local p = profilNeuf()
	if store and persistant then
		local ok, data = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				p[k] = v
			end
			p.coffres = p.coffres or {} -- profil anterieur aux coffres
			p.gemmes = p.gemmes or 0 -- profil anterieur aux gemmes
			p.niveaux = p.niveaux or {} -- profil anterieur aux niveaux
			p.exemplaires = p.exemplaires or {}
			p.serie = p.serie or 0 -- profil anterieur aux series de victoires
			p.dernierCoffreGratuit = p.dernierCoffreGratuit or 0 -- profil anterieur au coffre gratuit
			-- une carte ajoutee au jeu apres la creation du profil, et gratuite, est offerte
			for _, c in ipairs(Cards.list) do
				if not c.prix then
					p.cartes[c.id] = true
				end
			end
		elseif not ok then
			warn("[ECO] lecture impossible pour " .. player.Name .. " : " .. tostring(data))
			sansSauvegarde[player] = true
		end
	end
	profils[player] = p
	leaderstats(player, p)
	print(string.format("[ECO] profil %s : %d pieces, %d trophees, sauvegarde=%s", player.Name, p.pieces, p.trophees, tostring(Economie.sauvegardeActive(player))))
	return p
end

-- Sauvegarde active pour CE joueur : le store existe et son profil a pu etre lu.
function Economie.sauvegardeActive(player)
	return (store and persistant and not sansSauvegarde[player]) == true
end

-- Rend TRUE si le profil est bel et bien sur le disque apres cet appel. Un achat paye en Robux
-- s'appuie dessus : on ne confirme la vente que si l'ecriture a reussi.
function Economie.sauver(player)
	local p = profils[player]
	if not p then
		return false
	end
	sales[player] = nil
	if not Economie.sauvegardeActive(player) then
		-- pas de disque (Studio sans API, ou profil illisible) : rien a garantir
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, p)
	end)
	if not ok then
		warn("[ECO] sauvegarde ratee pour " .. player.Name .. " : " .. tostring(err))
		return false
	end
	-- Classement : une panne ici ne doit pas faire croire que le PROFIL n'est pas ecrit.
	if storeClassement then
		local okC, errC = pcall(function()
			storeClassement:SetAsync("u" .. player.UserId, p.trophees)
		end)
		if not okC then
			warn("[ECO] classement non mis a jour pour " .. player.Name .. " : " .. tostring(errC))
		end
	end
	return true
end

-- Pure (testee hors Studio) : entrees d'OrderedDataStore { key = "u<id>", value } -> top 10 affichable.
local function formaterClassement(entrees, nomDe)
	local top = {}
	for i, entree in ipairs(entrees) do
		if i > 10 then
			break
		end
		local uid = tonumber(string.match(entree.key, "^u(%d+)$"))
		table.insert(top, { rang = i, nom = (uid and nomDe(uid)) or "?", trophees = entree.value })
	end
	return top
end

-- Top 10 mondial, mis en cache CLASSEMENT_CACHE secondes : GetSortedAsync est plafonne par Roblox.
local CLASSEMENT_CACHE = 60
local cacheClassement, cacheClassementA = {}, -math.huge
local nomsConnus = {}
local function nomDe(uid)
	if nomsConnus[uid] == nil then
		local ok, nom = pcall(function()
			return Players:GetNameFromUserIdAsync(uid)
		end)
		nomsConnus[uid] = ok and nom or false
	end
	return nomsConnus[uid] or nil
end
function Economie.classement()
	if not storeClassement or os.clock() - cacheClassementA < CLASSEMENT_CACHE then
		return cacheClassement
	end
	local ok, res = pcall(function()
		return storeClassement:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if ok then
		cacheClassement = formaterClassement(res, nomDe)
		cacheClassementA = os.clock()
	else
		warn("[ECO] lecture du classement ratee : " .. tostring(res))
	end
	return cacheClassement
end

-- Le profil a change, mais rien d'irreversible : l'ecriture peut attendre le prochain passage.
-- Tout ce qui engage de l'ARGENT REEL doit appeler Economie.sauver et lire son resultat.
function Economie.marquerSale(player)
	if profils[player] then
		sales[player] = true
	end
end

-- Ecrit tous les profils en attente. Rend le nombre de profils reellement ecrits.
function Economie.viderSales()
	local n = 0
	for player in pairs(sales) do
		if Economie.sauver(player) then
			n += 1
		end
		sales[player] = nil
	end
	return n
end

function Economie.liberer(player)
	Economie.sauver(player)
	profils[player] = nil
	sansSauvegarde[player] = nil
	sales[player] = nil
end

-- Deck CHOISI : valide ou nil. Le client n'est jamais cru — meme un deck deja SAUVEGARDE est
-- reverifie ici, car le catalogue peut avoir change (carte retiree) depuis l'enregistrement.
-- Rend (nil, motif) si le choix ne tient pas : DECK_TAILLE cartes distinctes, connues, possedees.
-- fix-ok: Economie.deck renvoyait TOUTES les cartes possedees (aucun champ de deck choisi
-- n'existait dans le profil) et GameServer en tirait 8 au hasard ; cause mesuree par
-- tools/test_deck.py, rouge avant l'ajout de deckChoisi + deckValide, vert apres (exit 0).
local function deckValide(p, ids)
	if type(ids) ~= "table" or #ids ~= Economie.DECK_TAILLE then
		return nil, "il faut exactement " .. Economie.DECK_TAILLE .. " cartes"
	end
	local vus, propre = {}, {}
	for _, id in ipairs(ids) do
		if type(id) ~= "string" or not Cards.byId[id] then
			return nil, "carte inconnue"
		end
		if vus[id] then
			return nil, "carte en double : " .. id
		end
		if not p.cartes[id] then
			return nil, "carte non possedee : " .. id
		end
		vus[id] = true
		table.insert(propre, id)
	end
	return propre
end

-- Cartes jouables du joueur : son deck choisi s'il en a un valide, sinon TOUTES ses cartes
-- possedees (au moins 4, garanti par profilNeuf).
function Economie.deck(player)
	local p = profils[player]
	if not p then
		return nil
	end
	if p.deckChoisi then
		local propre = deckValide(p, p.deckChoisi)
		if propre then
			return propre
		end
		p.deckChoisi = nil -- deck devenu impossible (carte retiree du jeu) : on repart sur tout
	end
	local ids = {}
	for _, c in ipairs(Cards.list) do
		if p.cartes[c.id] then
			table.insert(ids, c.id)
		end
	end
	return ids
end

-- Trophees d'un joueur (0 si absent) : sert a regler la DIFFICULTE du robot d'en face.
function Economie.tropheesDe(player)
	local p = player and profils[player]
	return p and p.trophees or 0
end

-- Cartes REELLEMENT possedees par un joueur (sans tenir compte de son deck choisi).
function Economie.cartesPossedees(player)
	local p = profils[player]
	if not p then
		return nil
	end
	local ids = {}
	for _, c in ipairs(Cards.list) do
		if p.cartes[c.id] then
			table.insert(ids, c.id)
		end
	end
	return ids
end

-- PAQUET DU ROBOT. Avant, un camp sans joueur tirait dans TOUT le catalogue : le robot sortait des
-- cartes payantes (jusqu'a 1500 pieces) contre un joueur neuf qui ne peut pas y repondre en nature.
-- Il joue desormais le paquet du joueur d'EN FACE ; sans joueur en face, seulement les cartes
-- offertes. Fonction PURE : testee hors Roblox (tools/test_robot_deck.py).
function Economie.cartesRobot(idsEnFace)
	if idsEnFace and #idsEnFace >= Economie.DECK_TAILLE then
		return idsEnFace
	end
	local ids = {}
	for _, c in ipairs(Cards.list) do
		if not c.prix then
			table.insert(ids, c.id)
		end
	end
	return ids
end

-- Le joueur choisit son deck depuis le hub. Rend (false, motif) si le serveur refuse.
function Economie.choisirDeck(player, ids)
	local p = profils[player]
	if not p then
		return false, "profil absent"
	end
	local propre, motif = deckValide(p, ids)
	if not propre then
		return false, motif
	end
	p.deckChoisi = propre
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : deck choisi = %s", player.Name, table.concat(propre, ", ")))
	return true
end

local function aVip(player)
	if Economie.PASS_VIP == 0 then
		return false
	end
	local ok, res = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Economie.PASS_VIP)
	end)
	return ok and res
end

-- issue : "victoire" | "defaite" | "egalite" ; contreHumain : l'adversaire etait un joueur
function Economie.recompenser(player, issue, contreHumain)
	local p = profils[player]
	local r = RECOMPENSE[issue]
	if not (p and r) then
		return nil
	end
	local bonus = (issue == "victoire" and contreHumain) and BONUS_HUMAIN or 0
	-- SERIE DE VICTOIRES : enchainer des victoires rapporte de plus en plus, jusqu'a un plafond.
	-- Sans elle, la 10e victoire rapportait exactement autant que la premiere — rien ne donnait
	-- envie de rester une partie de plus. Une defaite ou une egalite remet la serie a zero.
	if issue == "victoire" then
		p.serie = (p.serie or 0) + 1
	else
		p.serie = 0
	end
	local bonusSerie = Economie.bonusSerie(p.serie)
	local pieces = (r.pieces + bonus + bonusSerie) * (aVip(player) and 2 or 1)
	p.pieces += pieces
	-- TROPHEES : l'issue passe par Arenes.apres, qui PROTEGE le bas de tableau. Un debutant qui
	-- enchaine trois defaites ne descend plus sous le plancher : il gardait sinon un compteur
	-- qui ne faisait que baisser, sans aucun repere de progression.
	local avant = p.trophees
	p.trophees = math.max(0, Arenes.apres(avant, issue))
	-- RECOMPENSE DE PALIER : versee UNE SEULE FOIS a la premiere arrivee dans une arene, meme
	-- si deux paliers sont franchis d'un coup.
	local palier = Arenes.recompensePalier(avant, p.trophees)
	if palier > 0 then
		p.pieces += palier
		print(string.format("[ECO] %s atteint %s : +%d pieces de palier",
			player.Name, Arenes.nom(p.trophees), palier))
	end
	p.parties += 1
	local coffre = nil
	if issue == "victoire" then
		p.victoires += 1
		coffre = Economie.gagnerCoffre(player)
	end
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : %s, +%d pieces (serie %d), %+d trophees",
		player.Name, issue, pieces, p.serie or 0, p.trophees - avant))
	return { pieces = pieces, trophees = p.trophees - avant, coffre = coffre, serie = p.serie,
		bonusSerie = bonusSerie, palier = palier, arene = Arenes.nom(p.trophees) }
end

function Economie.gagnerCoffre(player, typeForce)
	local p = profils[player]
	if not p or #p.coffres >= Economie.EMPLACEMENTS then
		return nil -- emplacements pleins : pas de coffre (incite a ouvrir ceux qu'on a)
	end
	local t = typeForce
	if not t then
		local total = 0
		for _, id in ipairs(Economie.ORDRE_COFFRES) do
			total += Economie.COFFRES[id].poids
		end
		local tirage = rng:NextNumber(0, total)
		for _, id in ipairs(Economie.ORDRE_COFFRES) do
			tirage -= Economie.COFFRES[id].poids
			if tirage <= 0 then
				t = id
				break
			end
		end
		t = t or "bois"
		-- PLAFOND D'ARENE : un joueur de la premiere arene ne tombe pas sur un coffre d'or. Le
		-- meilleur coffre possible suit le palier atteint (Arenes.coffreMax).
		local maxi = Arenes.coffreMax(p.trophees or 0)
		local rang = {}
		for i, id in ipairs(Economie.ORDRE_COFFRES) do
			rang[id] = i
		end
		if (rang[t] or 1) > (rang[maxi] or #Economie.ORDRE_COFFRES) then
			t = maxi
		end
	end
	table.insert(p.coffres, { type = t, fin = 0 }) -- fin = 0 : pas encore demarre
	print(string.format("[ECO] %s gagne un %s", player.Name, Economie.COFFRES[t].nom))
	return t
end

function Economie.demarrerCoffre(player, index)
	local p = profils[player]
	local c = p and type(index) == "number" and p.coffres[index]
	if not c then
		return false, "coffre inconnu"
	end
	if c.fin ~= 0 then
		return false, "deja demarre"
	end
	for _, autre in ipairs(p.coffres) do
		if autre.fin ~= 0 and autre.fin > os.time() then
			return false, "un coffre s'ouvre deja"
		end
	end
	c.fin = os.time() + Economie.COFFRES[c.type].duree
	Economie.marquerSale(player)
	return true
end

function Economie.ouvrirCoffre(player, index)
	local p = profils[player]
	local c = p and type(index) == "number" and p.coffres[index]
	if not c then
		return false, "coffre inconnu"
	end
	if c.fin == 0 then
		return false, "pas demarre"
	end
	if c.fin > os.time() then
		return false, "pas encore pret"
	end
	local def = Economie.COFFRES[c.type]
	local gain = { pieces = rng:NextInteger(def.pieces[1], def.pieces[2]), carte = nil }
	if rng:NextNumber() < def.chanceCarte then
		local verrouillees = {}
		for _, card in ipairs(Cards.list) do
			if not p.cartes[card.id] then
				table.insert(verrouillees, card.id)
			end
		end
		if #verrouillees > 0 then
			gain.carte = verrouillees[rng:NextInteger(1, #verrouillees)]
			p.cartes[gain.carte] = true
		else
			gain.pieces += def.piecesSiComplet
		end
	end
	-- exemplaires : une carte DEBLOQUEE au hasard (la carte gagnee a l'instant compte)
	local debloquees = Economie.deck(player)
	gain.exemplaireCarte = debloquees[rng:NextInteger(1, #debloquees)]
	gain.exemplaires = Economie.EXEMPLAIRES_COFFRE[c.type]
	p.exemplaires[gain.exemplaireCarte] = (p.exemplaires[gain.exemplaireCarte] or 0) + gain.exemplaires
	p.pieces += gain.pieces
	table.remove(p.coffres, index)
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s ouvre un %s : +%d pieces, %d x %s%s", player.Name, def.nom, gain.pieces,
		gain.exemplaires, gain.exemplaireCarte, gain.carte and (", carte " .. gain.carte) or ""))
	return true, gain
end

function Economie.niveau(player, id)
	local p = profils[player]
	return p and p.niveaux[id] or 1
end

-- niveaux de toutes les cartes du joueur (pour appliquer les bonus en partie)
function Economie.niveaux(player)
	local t = {}
	for _, c in ipairs(Cards.list) do
		t[c.id] = Economie.niveau(player, c.id)
	end
	return t
end

function Economie.ameliorer(player, id)
	local p = profils[player]
	local card = type(id) == "string" and Cards.byId[id]
	if not (p and card) then
		return false, "carte inconnue"
	end
	if not p.cartes[id] then
		return false, "carte verrouillee"
	end
	local n = p.niveaux[id] or 1
	if n >= Economie.NIVEAU_MAX then
		return false, "niveau maximum"
	end
	local besoin, cout = Economie.EXEMPLAIRES[n], Economie.COUT_NIVEAU[n]
	if (p.exemplaires[id] or 0) < besoin then
		return false, "pas assez d'exemplaires"
	end
	if p.pieces < cout then
		return false, "pas assez de pieces"
	end
	p.exemplaires[id] -= besoin
	p.pieces -= cout
	p.niveaux[id] = n + 1
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s ameliore %s au niveau %d", player.Name, id, n + 1))
	return true
end

function Economie.acheterCarte(player, id)
	local p = profils[player]
	local card = type(id) == "string" and Cards.byId[id]
	if not (p and card) then
		return false, "carte inconnue"
	end
	if p.cartes[id] then
		return false, "deja debloquee"
	end
	if not card.prix then
		return false, "carte non vendue"
	end
	-- DEBLOCAGE PAR ARENE : une carte rattachee a un palier ne s'achete pas avant de l'avoir
	-- atteint. Jusqu'ici le seul frein etait le prix : une legendaire pouvait tomber dans le
	-- deck d'un joueur de la premiere partie, qui ne savait pas encore quoi en faire.
	local ouverte, areneRequise = Arenes.carteDebloquee(id, p.trophees or 0)
	if not ouverte then
		return false, "carte de " .. tostring(areneRequise)
	end
	if p.pieces < card.prix then
		return false, "pas assez de pieces"
	end
	p.pieces -= card.prix
	p.cartes[id] = true
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s achete %s pour %d pieces", player.Name, id, card.prix))
	return true
end

function Economie.gainPronostic(player)
	local p = profils[player]
	if not p then
		return
	end
	p.pieces += GAIN_PRONOSTIC
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : pronostic juste, +%d pieces", player.Name, GAIN_PRONOSTIC))
end

-- ===== QUETES QUOTIDIENNES =====
-- Trois quetes par jour, les MEMES pour tout le monde, DEDUITES du numero du jour : rien a tirer
-- au hasard, rien a sauvegarder cote serveur, et deux joueurs peuvent parler de « la quete du
-- jour ». Seule l'AVANCEE est dans le profil. Le jeu n'avait aucune raison de revenir demain :
-- le bonus quotidien seul (+50 pieces) se prend en trois secondes et on repart.
Economie.QUETES = {
	{ id = "victoires", texte = "Gagner %d parties", cible = 2, gain = 80 },
	{ id = "cartes", texte = "Poser %d cartes", cible = 25, gain = 60 },
	{ id = "tours", texte = "Detruire %d tours", cible = 4, gain = 70 },
	{ id = "sorts", texte = "Lancer %d sorts", cible = 5, gain = 50 },
	{ id = "parties", texte = "Jouer %d parties", cible = 3, gain = 50 },
}
Economie.QUETES_PAR_JOUR = 3

-- Numero du jour (UTC). Fonction a part pour que le banc puisse avancer le temps a la main.
function Economie.jourDe(maintenant)
	return math.floor((maintenant or os.time()) / 86400)
end

-- Les 3 quetes du jour : une fenetre glissante sur la liste, decalee par le numero du jour.
-- Deterministe, donc reproductible au banc et identique pour tous les joueurs du meme jour.
function Economie.quetesDuJour(jour)
	local n = #Economie.QUETES
	local choisies = {}
	for k = 0, Economie.QUETES_PAR_JOUR - 1 do
		local i = (jour + k) % n + 1
		table.insert(choisies, Economie.QUETES[i])
	end
	return choisies
end

local function etatQuetes(p, maintenant)
	local jour = Economie.jourDe(maintenant)
	-- changement de jour : l'avancee repart de zero (les quetes changent aussi)
	if not p.quetes or p.quetes.jour ~= jour then
		p.quetes = { jour = jour, faits = {}, recus = {} }
	end
	return p.quetes
end

-- AVANCEE d'une quete. Appelee par le serveur de jeu a chaque evenement (carte posee, tour
-- detruite, partie gagnee...). Ne fait rien si aucune quete du jour ne porte sur ce type.
function Economie.avancerQuete(player, type, combien)
	local p = profils[player]
	if not p then
		return
	end
	local q = etatQuetes(p, os.time())
	local concernee = false
	for _, quete in ipairs(Economie.quetesDuJour(q.jour)) do
		if quete.id == type then
			concernee = true
		end
	end
	if not concernee then
		return
	end
	q.faits[type] = (q.faits[type] or 0) + (combien or 1)
	Economie.marquerSale(player)
end

-- RECLAMER une quete finie. Rend (true, gain) ou (false, motif).
function Economie.reclamerQuete(player, id)
	local p = profils[player]
	if not p then
		return false, "profil absent"
	end
	local q = etatQuetes(p, os.time())
	local quete = nil
	for _, candidate in ipairs(Economie.quetesDuJour(q.jour)) do
		if candidate.id == id then
			quete = candidate
		end
	end
	if not quete then
		return false, "quete inconnue"
	end
	if q.recus[id] then
		return false, "deja recue"
	end
	if (q.faits[id] or 0) < quete.cible then
		return false, "pas encore finie"
	end
	q.recus[id] = true
	p.pieces += quete.gain
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : quete %s finie, +%d pieces", player.Name, id, quete.gain))
	return true, quete.gain
end

-- ===== COFFRE GRATUIT =====
-- Toutes les 4 h, un coffre offert. C'est le rendez-vous court qui fait revenir dans la journee,
-- la ou le bonus quotidien ne donne qu'un rendez-vous par jour.
Economie.COFFRE_GRATUIT_DELAI = 4 * 3600
Economie.COFFRE_GRATUIT_TYPE = "argent"

-- Secondes restantes avant le prochain coffre gratuit (0 = disponible maintenant). PURE.
function Economie.attenteCoffreGratuit(dernier, maintenant)
	local reste = (dernier or 0) + Economie.COFFRE_GRATUIT_DELAI - (maintenant or 0)
	if reste < 0 then
		return 0
	end
	return reste
end

function Economie.reclamerCoffreGratuit(player)
	local p = profils[player]
	if not p then
		return false, "profil absent"
	end
	local maintenant = os.time()
	local reste = Economie.attenteCoffreGratuit(p.dernierCoffreGratuit, maintenant)
	if reste > 0 then
		return false, string.format("revenir dans %dh%02d", reste // 3600, (reste % 3600) // 60)
	end
	if #p.coffres >= Economie.EMPLACEMENTS then
		return false, "emplacements pleins"
	end
	local coffre = Economie.gagnerCoffre(player, Economie.COFFRE_GRATUIT_TYPE)
	if not coffre then
		return false, "emplacements pleins"
	end
	p.dernierCoffreGratuit = maintenant
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : coffre gratuit (%s)", player.Name, Economie.COFFRE_GRATUIT_TYPE))
	return true, coffre
end

-- Etat des quetes et du coffre gratuit, pour l'affichage (lecture seule).
function Economie.vueQuetes(player)
	local p = profils[player]
	if not p then
		return nil
	end
	local maintenant = os.time()
	local q = etatQuetes(p, maintenant)
	local liste = {}
	for _, quete in ipairs(Economie.quetesDuJour(q.jour)) do
		table.insert(liste, {
			id = quete.id,
			texte = string.format(quete.texte, quete.cible),
			fait = math.min(q.faits[quete.id] or 0, quete.cible),
			cible = quete.cible,
			gain = quete.gain,
			recue = q.recus[quete.id] == true,
			finie = (q.faits[quete.id] or 0) >= quete.cible,
		})
	end
	return {
		quetes = liste,
		coffreGratuitReste = Economie.attenteCoffreGratuit(p.dernierCoffreGratuit, maintenant),
		coffreGratuitType = Economie.COFFRE_GRATUIT_TYPE,
	}
end

function Economie.bonusQuotidien(player)
	local p = profils[player]
	if not p then
		return false, "profil absent"
	end
	local maintenant = os.time()
	local reste = p.dernierBonus + UN_JOUR - maintenant
	if reste > 0 then
		return false, string.format("revenir dans %dh%02d", reste // 3600, (reste % 3600) // 60)
	end
	p.dernierBonus = maintenant
	p.pieces += BONUS_JOUR
	leaderstats(player, p)
	Economie.marquerSale(player)
	return true
end

-- Vue envoyee au client (lecture seule)
function Economie.vue(player)
	local p = profils[player]
	if not p then
		return nil
	end
	local offres = {}
	for i, prod in ipairs(Economie.PRODUITS) do
		if prod.id ~= 0 then
			table.insert(offres, { index = i, nom = prod.nom })
		end
	end
	return {
		pieces = p.pieces, gemmes = p.gemmes, trophees = p.trophees, victoires = p.victoires, parties = p.parties,
		cartes = p.cartes, sauvegarde = Economie.sauvegardeActive(player), offresRobux = offres,
		bonusDispo = p.dernierBonus + UN_JOUR <= os.time(),
		coffres = p.coffres, maintenant = os.time(),
		niveaux = p.niveaux, exemplaires = p.exemplaires, niveauMax = Economie.NIVEAU_MAX,
		-- deck : ce que le joueur emporte reellement (choix valide, ou toutes ses cartes) et
		-- `deckLibre` = false tant qu'il n'a pas assez de cartes pour qu'un choix existe.
		deck = Economie.deck(player), deckTaille = Economie.DECK_TAILLE,
		deckChoisi = p.deckChoisi ~= nil,
		besoinExemplaires = Economie.EXEMPLAIRES, coutNiveau = Economie.COUT_NIVEAU,
		-- serie de victoires en cours : le hub l'affiche, sinon le joueur ne sait pas ce qu'il
		-- perd en s'arretant maintenant.
		serie = p.serie or 0, serieMax = Economie.SERIE_MAX,
		-- quetes du jour et coffre gratuit : l'onglet EVENEMENTS les affiche
		evenements = Economie.vueQuetes(player),
	}
end

function Economie.demanderRobux(player, index)
	local prod = Economie.PRODUITS[index]
	if prod and prod.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, prod.id)
	end
end

-- Un recu deja honore est-il connu du registre ? Rend (trouve, sur) : `sur` est faux quand le
-- registre n'a pas pu etre lu — on refuse alors de trancher plutot que de crediter deux fois.
local function recuDejaHonore(cle)
	if not storeRecus then
		return false, false
	end
	local ok, val = pcall(function()
		return storeRecus:GetAsync(cle)
	end)
	if not ok then
		warn("[ECO] registre des recus illisible : " .. tostring(val))
		return false, false
	end
	return val ~= nil, true
end

-- Achats Robux : Roblox rappelle ce callback jusqu'a ce qu'il rende PurchaseGranted.
-- Trois garanties : (1) un rappel apres coup ne recredite pas — le PurchaseId est enregistre ;
-- (2) l'argent n'est confirme QUE si le profil est ecrit sur le disque ; (3) si l'ecriture rate,
-- le credit est repris en memoire et la vente reste ouverte, donc Roblox rappellera.
-- Credit (sens = 1) ou reprise (sens = -1) de ce que rapporte un produit : pieces et/ou gemmes.
local function crediter(p, prod, sens)
	p.pieces += sens * (prod.pieces or 0)
	p.gemmes += sens * (prod.gemmes or 0)
end

local function libelleGain(prod)
	if prod.gemmes then
		return string.format("+%d gemmes", prod.gemmes)
	end
	return string.format("+%d pieces", prod.pieces)
end

MarketplaceService.ProcessReceipt = function(recu)
	local player = Players:GetPlayerByUserId(recu.PlayerId)
	if not player or not profils[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, prod in ipairs(Economie.PRODUITS) do
		if prod.id ~= 0 and prod.id == recu.ProductId then
			local cle = "r" .. tostring(recu.PurchaseId)
			local deja, sur = recuDejaHonore(cle)
			if deja then
				print(string.format("[ECO] %s : recu %s deja honore, aucun nouveau credit", player.Name, tostring(recu.PurchaseId)))
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			if not sur then
				-- registre muet : on prefere que Roblox rappelle plus tard qu'un double credit
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local p = profils[player]
			crediter(p, prod, 1)
			leaderstats(player, p)
			if not Economie.sauver(player) then
				crediter(p, prod, -1) -- le disque n'a pas pris : on ne vend pas du vide
				leaderstats(player, p)
				warn(string.format("[ECO] %s : achat Robux %s NON confirme (sauvegarde impossible)", player.Name, prod.nom))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local okR, errR = pcall(function()
				storeRecus:SetAsync(cle, { u = player.UserId, produit = prod.id, quand = os.time() })
			end)
			if not okR then
				crediter(p, prod, -1) -- recu non tracable : un rappel recrediterait
				leaderstats(player, p)
				if not Economie.sauver(player) then
					-- le disque garde un profil deja credite alors que la vente n'est pas confirmee :
					-- un rappel ajoutera un second credit. Rare (l'ecriture precedente a reussi),
					-- mais il faut pouvoir le retrouver dans les journaux.
					warn(string.format("[ECO] %s : ECART de solde possible sur le recu %s (%s sur le disque, vente non confirmee)", player.Name, tostring(recu.PurchaseId), libelleGain(prod)))
				end
				warn(string.format("[ECO] %s : recu %s non enregistre (%s), achat repousse", player.Name, tostring(recu.PurchaseId), tostring(errR)))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			print(string.format("[ECO] %s : achat Robux %s, %s", player.Name, prod.nom, libelleGain(prod)))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Passage regulier des ecritures en attente (voir DELAI_ECRITURE). `task` n'existe pas dans le
-- banc de test hors Studio : la boucle ne demarre que dans Roblox.
if task and task.spawn then
	task.spawn(function()
		while true do
			task.wait(DELAI_ECRITURE)
			Economie.viderSales()
		end
	end)
end

game:BindToClose(function()
	for player in pairs(profils) do
		Economie.sauver(player)
	end
end)

return Economie
