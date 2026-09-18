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

local Economie = {}

-- A REMPLIR par le createur apres creation sur create.roblox.com (0 = desactive).
Economie.PRODUITS = {
	{ id = 0, nom = "Sac de 500 pieces", pieces = 500 },
	{ id = 0, nom = "Coffre de 1500 pieces", pieces = 1500 },
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
do
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore("BRR_Profils_v1")
	end)
	if ok then
		store, persistant = res, true
	else
		warn("[ECO] sauvegarde indisponible : " .. tostring(res))
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
	return { pieces = 100, trophees = 0, victoires = 0, parties = 0, cartes = cartes, dernierBonus = 0, coffres = {}, niveaux = {}, exemplaires = {} }
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
			p.niveaux = p.niveaux or {} -- profil anterieur aux niveaux
			p.exemplaires = p.exemplaires or {}
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
	return true
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
	local pieces = (r.pieces + bonus) * (aVip(player) and 2 or 1)
	p.pieces += pieces
	p.trophees = math.max(0, p.trophees + r.trophees)
	p.parties += 1
	local coffre = nil
	if issue == "victoire" then
		p.victoires += 1
		coffre = Economie.gagnerCoffre(player)
	end
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : %s, +%d pieces, %+d trophees", player.Name, issue, pieces, r.trophees))
	return { pieces = pieces, trophees = r.trophees, coffre = coffre }
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
		pieces = p.pieces, trophees = p.trophees, victoires = p.victoires, parties = p.parties,
		cartes = p.cartes, sauvegarde = Economie.sauvegardeActive(player), offresRobux = offres,
		bonusDispo = p.dernierBonus + UN_JOUR <= os.time(),
		coffres = p.coffres, maintenant = os.time(),
		niveaux = p.niveaux, exemplaires = p.exemplaires, niveauMax = Economie.NIVEAU_MAX,
		-- deck : ce que le joueur emporte reellement (choix valide, ou toutes ses cartes) et
		-- `deckLibre` = false tant qu'il n'a pas assez de cartes pour qu'un choix existe.
		deck = Economie.deck(player), deckTaille = Economie.DECK_TAILLE,
		deckChoisi = p.deckChoisi ~= nil,
		besoinExemplaires = Economie.EXEMPLAIRES, coutNiveau = Economie.COUT_NIVEAU,
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
			p.pieces += prod.pieces
			leaderstats(player, p)
			if not Economie.sauver(player) then
				p.pieces -= prod.pieces -- le disque n'a pas pris : on ne vend pas du vide
				leaderstats(player, p)
				warn(string.format("[ECO] %s : achat Robux %s NON confirme (sauvegarde impossible)", player.Name, prod.nom))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local okR, errR = pcall(function()
				storeRecus:SetAsync(cle, { u = player.UserId, produit = prod.id, quand = os.time() })
			end)
			if not okR then
				p.pieces -= prod.pieces -- recu non tracable : un rappel recrediterait
				leaderstats(player, p)
				if not Economie.sauver(player) then
					-- le disque garde un profil deja credite alors que la vente n'est pas confirmee :
					-- un rappel ajoutera un second credit. Rare (l'ecriture precedente a reussi),
					-- mais il faut pouvoir le retrouver dans les journaux.
					warn(string.format("[ECO] %s : ECART de solde possible sur le recu %s (+%d pieces sur le disque, vente non confirmee)", player.Name, tostring(recu.PurchaseId), prod.pieces))
				end
				warn(string.format("[ECO] %s : recu %s non enregistre (%s), achat repousse", player.Name, tostring(recu.PurchaseId), tostring(errR)))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			print(string.format("[ECO] %s : achat Robux %s, +%d pieces", player.Name, prod.nom, prod.pieces))
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
