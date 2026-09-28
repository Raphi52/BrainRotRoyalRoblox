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
local Ligues = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Ligues"))
local PassSaison = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PassSaison"))
-- Saisons de classement : remise a zero partielle et recompense sur le sommet (tools/test_saison.py).
local Saison = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Saison"))
-- Journal : les dernieres parties du joueur, en regles pures (tools/test_journal.py).
local Journal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Journal"))
-- Abandon : regles de sanction du quitteur en serie (pures, testees hors du jeu).
local Abandon = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Abandon"))
-- Quetes : le moment ou une quete du jour se termine, nomme en regles pures (tools/test_quete_finie.py).
local Quetes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Quetes"))

local Economie = {}

-- Identifiants crees le 2026-09-26 sur create.roblox.com, experience « Brainrot Royale »
-- (universe 10768149063, place 126168119650545). 0 = offre desactivee et masquee.
-- Prix fixes (tarification geree desactivee) : 49 / 129 / 99 Robux ; VIP 199 ; pass de saison 299.
-- Un pass Roblox est PERMANENT : PASS_SAISON ouvre la piste premium de TOUTES les saisons.
Economie.PRODUITS = {
	{ id = 3714887785, nom = "Sac de 500 pieces", pieces = 500 },
	{ id = 3714889079, nom = "Coffre de 1500 pieces", pieces = 1500 },
	{ id = 3714889708, nom = "Poignee de 80 gemmes", gemmes = 80 }, -- monnaie premium, uniquement en Robux
}
Economie.PASS_VIP = 1999832722 -- pass « VIP » : pieces x2 en fin de partie
-- PASS DE SAISON PREMIUM (Game Pass Roblox) : ouvre la piste premium du pass.
Economie.PASS_SAISON = 1999634739

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
-- Expose : l'ecran le DIT (avant de choisir le robot, et apres une victoire). Il ne l'etait pas.
Economie.BONUS_HUMAIN = BONUS_HUMAIN

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
local passAchetes = {} -- player -> { [passId] = true } : pass payes pendant la session (voir possedePass)
-- player -> true : profil deja RENDU par ce serveur (voir sauver). A la fermeture, BindToClose le
-- rend, puis PlayerRemoving (liberer) le rendait une seconde fois : l'ecriture etait refusee et
-- le journal accusait a tort « un autre serveur » (mesure en Studio le 2026-09-26).
local rendus = {}
-- ARTICLES ALEATOIRES PAYANTS (2026-09-27, questionnaire de maturite : « Oui ») : ouvrir un coffre
-- contre des gemmes (vendues en Robux) et le coffre d'or de la piste premium (pass paye) donnent un
-- contenu tire au hasard. Roblox exige de les bloquer ou de les remplacer la ou la loi les interdit :
-- https://create.roblox.com/docs/production/promotion/content-maturity (PolicyService).
-- player -> false : autorise ; true ou absent : INTERDIT. Faute de reponse de Roblox, on bloque.
local aleatoireInterdit = {}
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

-- VERROU DE SESSION. Chaque match se joue dans un serveur RESERVE (Matchmaking) : le joueur change
-- de serveur a chaque partie. Le profil etait lu par GetAsync et ecrit par SetAsync sans aucune
-- trace de QUI le tenait : le serveur d'arrivee pouvait le lire AVANT que celui de depart n'ait
-- ecrit ses derniers gains (victoire, coffre, achat en pieces — tout ce qui attend l'ecriture
-- regroupee), puis l'ecraser avec sa copie perimee. Les gains disparaissaient sans un mot.
-- Le profil sur le disque porte desormais la SESSION qui le tient (`_session`) : on ne le prend
-- qu'une fois rendu, et on n'ecrit que tant qu'on le tient. Banc : tools/test_verrou_session.py.
-- SESSION et non SERVEUR (2026-09-26) : un joueur qui se reconnecte sur le MEME serveur pendant
-- que son ancienne session ecrit encore prenait le profil sans attendre (sans les derniers gains),
-- puis l'ancienne le rendait par-dessus et plus rien de la nouvelle session n'etait sauvegarde.
Economie.VERROU_ESSAIS = 8 -- tentatives avant de reprendre de force un verrou jamais rendu
Economie.VERROU_ATTENTE = 2 -- secondes entre deux tentatives (~14 s au pire, serveur mort)
local MOI = (game.JobId ~= nil and game.JobId ~= "") and game.JobId or "studio"
local numeroSession = 0
local jetons = {} -- player -> identifiant de SA session de profil (serveur + numero)

local function attendre(secondes)
	if task and task.wait then
		task.wait(secondes)
	end
end

-- Pur : identifiant du serveur qui tient cet enregistrement disque, nil s'il est libre.
function Economie.verrouTenu(enreg)
	if type(enreg) == "table" and type(enreg._session) == "table" then
		return enreg._session.job
	end
	return nil
end

-- Pur : l'enregistrement a ecrire pour PRENDRE le profil, ou nil s'il est tenu par un autre
-- serveur. `forcer` : cet autre serveur ne l'a pas rendu a temps, il est tenu pour mort.
function Economie.verrouPrendre(enreg, moi, maintenant, forcer)
	local tenant = Economie.verrouTenu(enreg)
	if tenant ~= nil and tenant ~= moi and not forcer then
		return nil
	end
	local nouveau = {}
	if type(enreg) == "table" then
		for k, v in pairs(enreg) do
			nouveau[k] = v
		end
	end
	nouveau._session = { job = moi, t = maintenant }
	return nouveau
end

-- Pur : on n'ecrit par-dessus le disque que si c'est NOUS qui tenons le profil. Un serveur a qui
-- le profil a ete repris tient une copie perimee : l'ecrire effacerait les gains faits ailleurs.
function Economie.verrouPeutEcrire(enreg, moi)
	return Economie.verrouTenu(enreg) == moi
end

-- Lit le profil ET le prend, en une seule operation (UpdateAsync). Rend (ok, donnees|erreur) ;
-- les donnees ne contiennent jamais le verrou lui-meme.
local function lireEtPrendre(player)
	local cle = "u" .. player.UserId
	for essai = 1, Economie.VERROU_ESSAIS do
		local forcer = essai == Economie.VERROU_ESSAIS
		local pris, tenant = nil, nil
		local ok, err = pcall(function()
			store:UpdateAsync(cle, function(enreg)
				tenant = Economie.verrouTenu(enreg)
				pris = Economie.verrouPrendre(enreg, jetons[player], os.time(), forcer)
				return pris
			end)
		end)
		if not ok then
			return false, err
		end
		if pris then
			if tenant ~= nil and tenant ~= jetons[player] and forcer then
				warn(string.format("[ECO] %s : profil jamais rendu par le serveur %s, repris de force", player.Name, tostring(tenant)))
			end
			local data = {}
			for k, v in pairs(pris) do
				if k ~= "_session" then
					data[k] = v
				end
			end
			return true, data
		end
		attendre(Economie.VERROU_ATTENTE)
	end
	return false, "verrou de session non obtenu"
end

local function profilNeuf()
	local cartes = {}
	for _, c in ipairs(Cards.list) do
		if not c.prix then
			cartes[c.id] = true
		end
	end
	return { pieces = 100, gemmes = 0, trophees = 0, victoires = 0, parties = 0, cartes = cartes, dernierBonus = 0, coffres = {}, niveaux = {}, exemplaires = {}, serie = 0,
		dernierCoffreGratuit = 0, quetes = nil, tutoFait = false,
		-- SAISON : numero en cours et SOMMET atteint dedans (la recompense se calcule dessus, pas
		-- sur le solde final — sinon trois defaites la derniere heure effacent un mois).
		saison = Saison.numero(os.time()), tropheesMax = 0,
		-- ADVERSAIRES RECENTS : { [identifiant] = horodatage }. Garde dans le PROFIL et non en
		-- memoire du serveur : entre deux parties, le joueur change de serveur.
		adversaires = {},
		-- ABANDONS RECENTS : horodatages des duels quittes en cours. Dans le PROFIL pour la meme
		-- raison que les adversaires — sinon il suffirait de changer de serveur pour effacer son
		-- ardoise, et la sanction ne vaudrait rien.
		abandons = {},
		-- JOURNAL : les dernieres parties (issue, trophees, adversaire, instant). Deux compteurs
		-- ne disaient pas si ca allait mieux ou moins bien en ce moment.
		journal = {},
		-- REGLAGES SONORES : ils suivent le joueur d'un serveur a l'autre. Gardes dans le profil
		-- et non chez le client : Roblox ne donne aucun stockage local, un reglage client serait
		-- reperdu a chaque partie.
		son = { musique = true, bruitages = true } }
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

-- Republie trophees et pieces (leaderstats, lus par les AUTRES joueurs : onglet CLAN) apres une
-- modification directe du profil, comme le font les crochets de capture.
function Economie.publier(player)
	local p = profils[player]
	if p then
		leaderstats(player, p)
	end
end

function Economie.charger(player)
	local p = profilNeuf()
	if store and persistant then
		numeroSession += 1
		jetons[player] = MOI .. "#" .. numeroSession
		local ok, data = lireEtPrendre(player)
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
			p.tutoFait = p.tutoFait or false -- profil anterieur au tutoriel
			p.journal = p.journal or {} -- profil anterieur au journal des parties
			-- profil anterieur aux reglages sonores : tout etait allume, on garde ce defaut.
			p.son = p.son or { musique = true, bruitages = true }
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
	-- PASSAGE DE SAISON : on le constate a la CONNEXION, pas par une horloge qui tournerait dans le
	-- vide. Le joueur recoit sa recompense de fin de saison et repart du plancher.
	Economie.tournerSaison(player, p)
	Economie.lirePolitique(player)
	profils[player] = p
	leaderstats(player, p)
	print(string.format("[ECO] profil %s : %d pieces, %d trophees, sauvegarde=%s", player.Name, p.pieces, p.trophees, tostring(Economie.sauvegardeActive(player))))
	return p
end

-- ADVERSAIRES RECENTS. On retient QUI on vient d'affronter, pour ne pas retomber dessus tout de
-- suite (Matchmaking.EVITEMENT). La table est elaguee a chaque ecriture : elle ne peut pas gonfler.
Economie.MEMOIRE_ADVERSAIRES = 900 -- secondes gardees (15 min : plus long que la fenetre d'evitement)
function Economie.noterAdversaire(player, autreId)
	local p = profils[player]
	if not p or autreId == nil then
		return
	end
	p.adversaires = p.adversaires or {}
	local maintenant = os.time()
	for cle, quand in pairs(p.adversaires) do
		if maintenant - quand > Economie.MEMOIRE_ADVERSAIRES then
			p.adversaires[cle] = nil
		end
	end
	p.adversaires[tostring(autreId)] = maintenant
	Economie.marquerSale(player)
end

-- ABANDONS : on note, on lit, on pardonne. La regle de sanction elle-meme vit dans
-- src/shared/Abandon.lua, testee hors du jeu.
function Economie.noterAbandon(player)
	local pr = profils[player]
	if not pr then
		return
	end
	pr.abandons = Abandon.noter(pr.abandons or {}, os.time())
	Economie.marquerSale(player)
end

function Economie.abandons(player)
	local pr = profils[player]
	return (pr and pr.abandons) or {}
end

-- Temps d'attente restant avant de pouvoir relancer une recherche, et test « ce depart
-- compte-t-il comme une fuite ». Exposes ICI plutot que dans GameServer : ce fichier atteint la
-- limite Luau de 200 variables locales, et un require de plus ne passe pas.
function Economie.attenteAbandon(player)
	return Abandon.reste(Economie.abandons(player), os.time())
end

function Economie.texteAbandon(reste)
	return Abandon.texte(reste)
end

function Economie.fuiteCompte(volontaire, partieEnCours, adversaireHumain)
	return Abandon.compteCommeFuite(volontaire, partieEnCours, adversaireHumain)
end

function Economie.compteAbandons(player)
	return Abandon.compte(Economie.abandons(player), os.time())
end

-- Une partie menee a son terme efface le plus ancien abandon.
function Economie.pardonnerAbandon(player)
	local pr = profils[player]
	if not pr or not pr.abandons or #pr.abandons == 0 then
		return
	end
	pr.abandons = Abandon.pardonner(pr.abandons, os.time())
	Economie.marquerSale(player)
end

-- Ce que la file d'attente recopie dans l'entree du joueur.
function Economie.adversairesRecents(player)
	local p = profils[player]
	return (p and p.adversaires) or {}
end

-- BASCULE DE SAISON. Rend (true, pieces versees) si la saison a tourne. Aucune horloge, aucun
-- evenement : on compare le numero garde dans le profil a celui d'aujourd'hui.
function Economie.tournerSaison(player, profil)
	local p = profil or profils[player]
	if not p then
		return false, 0
	end
	local maintenant = os.time()
	if p.saison == nil then
		p.saison = Saison.numero(maintenant) -- profil anterieur aux saisons : on aligne, sans rien retirer
		p.tropheesMax = math.max(p.tropheesMax or 0, p.trophees or 0)
		return false, 0
	end
	if not Saison.doitTourner(p.saison, maintenant) then
		p.tropheesMax = math.max(p.tropheesMax or 0, p.trophees or 0)
		return false, 0
	end
	local sommet = math.max(p.tropheesMax or 0, p.trophees or 0)
	local pieces = Saison.recompense(sommet)
	local avant = p.trophees or 0
	p.trophees = Saison.apresRemiseAZero(avant)
	p.pieces = (p.pieces or 0) + pieces
	p.saison = Saison.numero(maintenant)
	p.tropheesMax = p.trophees
	-- BILAN GARDE POUR L'ECRAN : la bascule se produit au CHARGEMENT du profil, donc avant que le
	-- joueur ne voie quoi que ce soit. Sans cette trace, il rouvrait le jeu avec 300 trophees de
	-- moins et des pieces en plus, sans un mot.
	p.bilanSaison = { saison = Saison.numero(maintenant) - 1, sommet = sommet, pieces = pieces,
		avant = avant, apres = p.trophees }
	print(string.format("[ECO] %s : saison %d terminee (sommet %d) -> %d trophees, +%d pieces",
		player and player.Name or "?", Saison.numero(maintenant) - 1, sommet, p.trophees, pieces))
	Economie.marquerSale(player)
	return true, pieces
end

-- BILAN VU : l'ecran l'a montre, on l'oublie pour qu'il ne revienne pas a chaque ouverture.
function Economie.oublierBilanSaison(player)
	local p = profils[player]
	if p and p.bilanSaison then
		p.bilanSaison = nil
		Economie.marquerSale(player)
		return true
	end
	return false
end

-- Sommet de la saison, suivi a chaque gain de trophees.
function Economie.suivreSommet(p)
	if p then
		p.tropheesMax = math.max(p.tropheesMax or 0, p.trophees or 0)
	end
end

-- Sauvegarde active pour CE joueur : le store existe et son profil a pu etre lu.
function Economie.sauvegardeActive(player)
	return (store and persistant and not sansSauvegarde[player]) == true
end

-- Rend TRUE si le profil est bel et bien sur le disque apres cet appel. Un achat paye en Robux
-- s'appuie dessus : on ne confirme la vente que si l'ecriture a reussi.
-- `rendre` : derniere ecriture de ce serveur pour ce joueur (depart, fermeture) — le verrou est
-- rendu avec elle, et le serveur suivant peut prendre le profil sans attendre.
function Economie.sauver(player, rendre)
	local p = profils[player]
	if not p then
		return false
	end
	sales[player] = nil
	if not Economie.sauvegardeActive(player) then
		-- pas de disque (Studio sans API, ou profil illisible) : rien a garantir
		return false
	end
	if rendus[player] then
		-- deja rendu par CE serveur (fermeture puis depart) : il n'est plus a nous, rien a ecrire
		return false
	end
	local refuse = false
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(enreg)
			refuse = not Economie.verrouPeutEcrire(enreg, jetons[player])
			if refuse then
				return nil -- nil : UpdateAsync n'ecrit rien
			end
			local nouveau = {}
			for k, v in pairs(p) do
				nouveau[k] = v
			end
			if not rendre then
				nouveau._session = { job = jetons[player], t = os.time() }
			end
			return nouveau
		end)
	end)
	if not ok then
		warn("[ECO] sauvegarde ratee pour " .. player.Name .. " : " .. tostring(err))
		return false
	end
	if refuse then
		-- Un autre serveur a pris le profil : notre copie est perimee, on n'ecrira plus rien.
		sansSauvegarde[player] = true
		warn("[ECO] " .. player.Name .. " : profil repris par un autre serveur, copie locale abandonnee")
		return false
	end
	if rendre then
		rendus[player] = true
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
		-- On garde l'IDENTIFIANT en plus du nom. Il etait calcule ici puis jete, et le rang se
		-- retrouvait ensuite par le NOM D'AFFICHAGE — lequel n'est PAS unique sur Roblox (seul le
		-- Name l'est). Deux joueurs homonymes se voyaient donc attribuer le meme rang mondial.
		table.insert(top, { rang = i, id = uid, nom = (uid and nomDe(uid)) or "?", trophees = entree.value })
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

-- Politique du PAYS du joueur, lue une fois a la connexion. pcall : l'appel peut echouer (doc
-- PolicyService) ; alors on BLOQUE, car vendre un tirage la ou il est interdit n'est pas rattrapable.
function Economie.lirePolitique(player)
	local ok, info = pcall(function()
		return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
	end)
	local permis = ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == false
	aleatoireInterdit[player] = not permis
	if not ok then
		warn("[ECO] politique du pays illisible pour " .. player.Name .. " : " .. tostring(info) .. " (tirages payants bloques)")
	end
	print(string.format("[ECO] %s : articles aleatoires payants %s", player.Name, permis and "permis" or "INTERDITS"))
	return not permis
end

function Economie.aleatoirePayantInterdit(player)
	return aleatoireInterdit[player] ~= false
end

function Economie.liberer(player)
	Economie.sauver(player, true)
	aleatoireInterdit[player] = nil
	profils[player] = nil
	sansSauvegarde[player] = nil
	sales[player] = nil
	passAchetes[player] = nil
	rendus[player] = nil
	jetons[player] = nil
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
	-- CHAMPIONS : un seul par deck (regle du jeu de reference, module Champions). Compte fait sur
	-- le champ `capacite` des cartes : la donnee est la source de verite.
	local champions = 0
	for _, id in ipairs(propre) do
		if Cards.byId[id].capacite then
			champions += 1
		end
	end
	if champions > 1 then
		return nil, "un seul champion par deck"
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
-- REGLAGES SONORES : ecrits par le joueur depuis son ecran. Aucun enjeu de triche, mais ils
-- passent quand meme par le serveur, seul endroit qui survit a un changement de serveur.
function Economie.reglerSon(player, musique, bruitages)
	local p = profils[player]
	if not p then
		return nil
	end
	p.son = p.son or { musique = true, bruitages = true }
	if musique ~= nil then
		p.son.musique = musique == true
	end
	if bruitages ~= nil then
		p.son.bruitages = bruitages == true
	end
	Economie.marquerSale(player)
	return p.son
end

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

-- PASS ACHETES PENDANT LA SESSION. UserOwnsGamePassAsync garde sa reponse en cache pour toute
-- la session : un pass paye EN JEU restait « non possede » jusqu'a la reconnexion — le joueur
-- payait et ne recevait rien. L'achat confirme par Roblox (PromptGamePassPurchaseFinished, cable
-- dans GameServer) fait foi pour le reste de la session (table `passAchetes`, declaree en tete
-- du module pour que `liberer` la voie). Banc : tools/test_pass_achete.py.

-- Rend true si l'achat est retenu : seulement un achat REEL, et d'un pass de CE jeu.
function Economie.noterPassAchete(player, passId, achete)
	if achete ~= true or passId == nil or passId == 0 then
		return false
	end
	if passId ~= Economie.PASS_VIP and passId ~= Economie.PASS_SAISON then
		return false
	end
	passAchetes[player] = passAchetes[player] or {}
	passAchetes[player][passId] = true
	print(string.format("[ECO] %s : pass %s achete en jeu, actif tout de suite", player.Name, tostring(passId)))
	return true
end

local function possedePass(player, passId)
	if passId == 0 then
		return false
	end
	-- COPIE DE TEST (build.py --vip-non-possede) : le compte qui lance Studio est le createur, qui
	-- possede d'office ses pass ; l'offre VIP n'apparaitrait jamais a la capture.
	if passId == Economie.PASS_VIP and Economie.vipTestNonPossede and not (passAchetes[player] and passAchetes[player][passId]) then
		return false
	end
	if passAchetes[player] and passAchetes[player][passId] then
		return true
	end
	local ok, res = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and res == true
end

local function aVip(player)
	return possedePass(player, Economie.PASS_VIP)
end

-- COSMETIQUES (skins de tours, emotes premium) : en GEMMES, aucun effet sur le jeu.
local function modulesCosmetiques()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	return require(Shared:WaitForChild("Cosmetiques")), require(Shared:WaitForChild("Emotes"))
end

function Economie.cosmetiques(player)
	local p = profils[player]
	if not p then
		return nil
	end
	local Cosmetiques = modulesCosmetiques()
	p.cosmetiques = Cosmetiques.normaliser(p.cosmetiques)
	return p.cosmetiques
end

function Economie.acheterCosmetique(player, id)
	local p = profils[player]
	if not p then
		return false, "profil absent"
	end
	local Cosmetiques, Emotes = modulesCosmetiques()
	local etat = Economie.cosmetiques(player)
	local ok, motif = Cosmetiques.peutAcheter(Emotes, etat, p.gemmes or 0, id)
	if not ok then
		return false, motif
	end
	local a = Cosmetiques.article(Emotes, id)
	p.gemmes -= a.prix
	etat.possedes[id] = true
	if a.type == "skin" then
		etat.skin = id -- un skin achete s'equipe tout de suite : c'est ce qu'on veut voir
	end
	Economie.marquerSale(player)
	print(string.format("[COSMETIQUE] %s achete %s (%s) : -%d gemmes", player.Name, a.nom, a.type, a.prix))
	return true, a.nom
end

function Economie.equiperSkin(player, id)
	local Cosmetiques = modulesCosmetiques()
	local etat = Economie.cosmetiques(player)
	if not etat then
		return false, "profil absent"
	end
	local ok, motif = Cosmetiques.peutEquiper(etat, id)
	if not ok then
		return false, motif
	end
	etat.skin = id
	Economie.marquerSale(player)
	return true
end

-- PASS DE SAISON ------------------------------------------------------------------------------
-- Piste premium : Game Pass Roblox (Economie.PASS_SAISON), ou la copie de test (build.py
-- --pass-premium) pour la photographier sans achat.
function Economie.aPassPremium(player)
	if Economie.passPremiumTest then -- pose par GameServer en copie de test uniquement
		return true
	end
	return possedePass(player, Economie.PASS_SAISON)
end

-- Etat du pass pour la saison EN COURS : un pass d'une saison passee repart a zero.
function Economie.passEtat(p)
	local etat, remis = PassSaison.aJour(p.pass, Saison.numero(os.time()))
	p.pass = etat
	return etat, remis
end

-- Points de pass d'une partie finie : l'issue + 1 point par rang de LIGUE.
function Economie.avancerPass(player, issue, trophees)
	local p = profils[player]
	if not p then
		return 0
	end
	local etat = Economie.passEtat(p)
	local gain = PassSaison.pointsPartie(issue, Ligues.index(trophees or p.trophees))
	etat.points += gain
	return gain
end

-- Reclamer le palier `i` de la piste `piste`. Le serveur refait TOUS les controles.
function Economie.reclamerPalier(player, i, piste)
	local p = profils[player]
	if not p then
		return false, "profil absent"
	end
	i = tonumber(i)
	local etat = Economie.passEtat(p)
	local ok, motif = PassSaison.peutReclamer(etat, i, piste, Economie.aPassPremium(player))
	if not ok then
		return false, motif
	end
	local r = PassSaison.recompense(i, piste, Economie.aleatoirePayantInterdit(player))
	if r.type == "coffre" then
		-- emplacements pleins : on NE marque PAS le palier, la recompense reste a prendre
		if not Economie.gagnerCoffre(player, r.valeur) then
			return false, "emplacements de coffres pleins : ouvre un coffre d'abord"
		end
	elseif r.type == "gemmes" then
		p.gemmes = (p.gemmes or 0) + r.valeur
	else
		p.pieces += r.valeur
	end
	etat.reclames[piste][tostring(i)] = true
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[PASS] %s reclame le palier %d (%s) : %s", player.Name, i, piste, r.texte))
	return true, r.texte
end

-- issue : "victoire" | "defaite" | "egalite" ; contreHumain : l'adversaire etait un joueur
-- `tropheesAdverses` : trophees de l'adversaire humain (nil contre le robot). L'enjeu en trophees
-- en depend desormais — voir Arenes.facteur.
function Economie.recompenser(player, issue, contreHumain, adversaire, tropheesAdverses)
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
	-- L'ENJEU SUIT L'ADVERSAIRE : le tiers contre le robot (on ne grimpe plus au classement en le
	-- battant en boucle), et selon l'ecart de trophees contre un humain.
	p.trophees = math.max(0, Arenes.apres(avant, issue, tropheesAdverses, contreHumain == true))
	-- RECOMPENSE DE PALIER : versee UNE SEULE FOIS a la premiere arrivee dans une arene, meme
	-- si deux paliers sont franchis d'un coup.
	local palier = Arenes.recompensePalier(avant, p.trophees)
	local passPoints = Economie.avancerPass(player, issue, p.trophees)
	if palier > 0 then
		p.pieces += palier
		print(string.format("[ECO] %s atteint %s : +%d pieces de palier",
			player.Name, Arenes.nom(p.trophees), palier))
	end
	Economie.suivreSommet(p)
	p.parties += 1
	-- JOURNAL : on range la partie qui vient de finir, avec le delta REEL de trophees (celui que
	-- le plancher d'arene a pu amortir), pas la valeur theorique de l'issue.
	p.journal = Journal.ajouter(p.journal, Journal.entree(issue, p.trophees - avant, adversaire, os.time()))
	local coffre = nil
	local coffrePerdu = false
	if issue == "victoire" then
		p.victoires += 1
		-- Emplacements pleins : AUCUN coffre. On le retient pour le DIRE a l'ecran de fin — il
		-- etait perdu en silence (2026-09-21).
		coffre = Economie.gagnerCoffre(player)
		coffrePerdu = coffre == nil
	end
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : %s, +%d pieces (serie %d), %+d trophees",
		player.Name, issue, pieces, p.serie or 0, p.trophees - avant))
	-- MONTEE D'ARENE : elle changeait le profil en silence (pieces de palier versees, cartes
	-- ouvertes en boutique). On la fait remonter a l'ecran de fin, avec le NOM des cartes.
	local montee = Arenes.montee(avant, p.trophees)
	local monteeLignes = Arenes.lignesMontee(montee, function(id)
		local c = Cards.byId[id]
		return c and c.name or id
	end)
	-- LIGUE : promotion ou relegation, dite sur l'ecran de fin avec la montee d'arene.
	local ligueLigne = Ligues.changement(avant, p.trophees)
	if ligueLigne then
		monteeLignes = monteeLignes or {}
		table.insert(monteeLignes, 1, ligueLigne)
	end
	return { pieces = pieces + palier, piecesPartie = pieces, trophees = p.trophees - avant,
		coffre = coffre, coffrePerdu = coffrePerdu, serie = p.serie, bonusSerie = bonusSerie, palier = palier,
		arene = Arenes.nom(p.trophees), montee = montee, monteeLignes = monteeLignes,
		ligue = Ligues.actuelle(p.trophees).nom, passPoints = passPoints,
		passPalier = PassSaison.palier(p.pass and p.pass.points or 0) }
end

function Economie.gagnerCoffre(player, typeForce)
	local p = profils[player]
	if not p or #(p.coffres or {}) >= Economie.EMPLACEMENTS then
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
	-- CAPTURE (build.py --ouverture) : carte imposee pour photographier la revelation d'une carte
	-- NOUVELLE. Pose par GameServer en mode test uniquement, consommee une fois.
	local imposee = Economie.carteImposee
	Economie.carteImposee = nil
	if imposee and not p.cartes[imposee] then
		gain.carte = imposee
		p.cartes[imposee] = true
	elseif rng:NextNumber() < def.chanceCarte then
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
	-- ... parmi celles qu'un exemplaire fait encore progresser (pas au niveau maximum).
	local Coffres = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Coffres"))
	local utiles = Coffres.cartesUtiles(Economie.deck(player), p.niveaux, Economie.NIVEAU_MAX)
	gain.exemplaires = Economie.EXEMPLAIRES_COFFRE[c.type]
	if #utiles > 0 then
		gain.exemplaireCarte = utiles[rng:NextInteger(1, #utiles)]
		p.exemplaires[gain.exemplaireCarte] = (p.exemplaires[gain.exemplaireCarte] or 0) + gain.exemplaires
	else
		-- tout le deck au maximum : les exemplaires deviennent des pieces, rien n'est perdu
		gain.pieces += gain.exemplaires * Coffres.PIECES_PAR_EXEMPLAIRE
		gain.exemplaires = 0
	end
	p.pieces += gain.pieces
	table.remove(p.coffres, index)
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s ouvre un %s : +%d pieces, %d x %s%s", player.Name, def.nom, gain.pieces,
		gain.exemplaires, tostring(gain.exemplaireCarte), gain.carte and (", carte " .. gain.carte) or ""))
	return true, gain
end

-- OUVERTURE IMMEDIATE contre des gemmes d'un coffre EN COURS (prix : Coffres.coutGemmes).
function Economie.accelererCoffre(player, index)
	if Economie.aleatoirePayantInterdit(player) then
		-- article aleatoire payant : refuse AVANT toute depense (voir aleatoireInterdit)
		return false, "ouverture contre des gemmes indisponible dans ton pays"
	end
	local Coffres = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Coffres"))
	local p = profils[player]
	local c = p and type(index) == "number" and p.coffres[index]
	if not c then
		return false, "coffre inconnu"
	end
	if c.fin == 0 then
		return false, "pas demarre"
	end
	local cout = Coffres.coutGemmes(c.fin - os.time())
	if (p.gemmes or 0) < cout then
		return false, string.format("il faut %d gemmes (tu en as %d)", cout, p.gemmes or 0)
	end
	p.gemmes -= cout
	c.fin = os.time() - 1
	return Economie.ouvrirCoffre(player, index)
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

-- Montant du pari gagnant, lisible par le serveur de jeu (il l'annonce au spectateur).
function Economie.montantPronostic()
	return GAIN_PRONOSTIC
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
	local avant = q.faits[type] or 0
	q.faits[type] = avant + (combien or 1)
	-- QUETE QUI SE TERMINE : jusqu'ici l'avancee etait silencieuse, et la recompense (qui se
	-- RECLAME au menu) restait sur place sans que rien ne le dise. On pose une annonce datee, que
	-- l'etat de partie emporte et qui s'eteint toute seule (Quetes.encoreVisible).
	for _, quete in ipairs(Economie.quetesDuJour(q.jour)) do
		if quete.id == type and Quetes.vientDeFinir(avant, q.faits[type], quete.cible) then
			p.queteAnnonce = { id = quete.id, pose = os.time(),
				lignes = Quetes.lignes(quete.texte, quete.cible, quete.gain) }
			print(string.format("[ECO] %s : quete %s terminee, annonce posee", player.Name, quete.id))
		end
	end
	Economie.marquerSale(player)
end

-- L'ANNONCE A MONTRER MAINTENANT, ou nil. Lue par l'etat de partie a chaque envoi : c'est le delai
-- qui l'eteint, pas un accuse de reception du client (qui pourrait ne jamais arriver).
function Economie.queteAnnonce(player, maintenant)
	local p = profils[player]
	if not (p and p.queteAnnonce) then
		return nil
	end
	if not Quetes.encoreVisible(p.queteAnnonce.pose, maintenant or os.time()) then
		return nil
	end
	return p.queteAnnonce
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
	local gemmes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Quetes")).GEMMES
	p.gemmes = (p.gemmes or 0) + gemmes
	leaderstats(player, p)
	Economie.marquerSale(player)
	print(string.format("[ECO] %s : quete %s finie, +%d pieces, +%d gemmes", player.Name, id, quete.gain, gemmes))
	return true, quete.gain, gemmes
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
	if #(p.coffres or {}) >= Economie.EMPLACEMENTS then
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
			gemmes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Quetes")).GEMMES,
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

-- TUTORIEL : le module partage decide s'il est obligatoire (aucune partie jouee) ; le profil
-- retient seulement qu'il a ete VU, pour qu'une premiere partie abandonnee le rejoue.
function Economie.tutorielFait(player)
	local p = profils[player]
	return p ~= nil and p.tutoFait == true
end

function Economie.marquerTutoriel(player)
	local p = profils[player]
	if p and not p.tutoFait then
		p.tutoFait = true
		Economie.marquerSale(player)
	end
end

function Economie.profil(player)
	return profils[player]
end

-- Vue envoyee au client (lecture seule)
function Economie.vue(player)
	local p = profils[player]
	if not p then
		return nil
	end
	local passEtat = Economie.passEtat(p)
	local passDans, passSur = PassSaison.progression(passEtat.points)
	local passVue = { saison = passEtat.saison, points = passEtat.points, palier = PassSaison.palier(passEtat.points),
		dans = passDans, sur = passSur, reclames = passEtat.reclames, premium = Economie.aPassPremium(player),
		sansAleatoirePayant = Economie.aleatoirePayantInterdit(player),
		achetable = Economie.PASS_SAISON ~= 0, reste = Saison.texteReste(os.time()) }
	local offres = {}
	for i, prod in ipairs(Economie.PRODUITS) do
		if prod.id ~= 0 then
			-- `genre` : la pastille que le client dessine sur l'offre (pieces / gemmes / vip).
			table.insert(offres, { index = i, nom = prod.nom, genre = prod.gemmes and "gemmes" or "pieces" })
		end
	end
	-- PASS VIP : il n'etait propose NULLE PART dans le jeu (seule la page Roblox le vendait).
	-- Montre tant qu'il est configure et pas encore possede.
	if Economie.PASS_VIP ~= 0 and not aVip(player) then
		table.insert(offres, { index = "vip", nom = "Pass VIP : pieces x2", genre = "vip" })
	end
	return {
		pieces = p.pieces, gemmes = p.gemmes, trophees = p.trophees, victoires = p.victoires, parties = p.parties,
		cartes = p.cartes, sauvegarde = Economie.sauvegardeActive(player), offresRobux = offres,
		bonusDispo = p.dernierBonus + UN_JOUR <= os.time(),
		coffres = p.coffres, maintenant = os.time(),
		sansAleatoirePayant = Economie.aleatoirePayantInterdit(player), -- pas d'ouverture en gemmes
		-- CE QUE CONTIENT CHAQUE TYPE DE COFFRE : le joueur choisit lequel ouvrir (un seul a la
		-- fois, de 15 min a 3 h) et n'avait AUCUN moyen de savoir ce qu'il y gagnerait. Les
		-- chiffres partent d'ici, ils ne sont pas recopies dans l'ecran.
		coffresInfos = (function()
			local infos = {}
			for _, t in ipairs(Economie.ORDRE_COFFRES) do
				local c = Economie.COFFRES[t]
				infos[t] = { pieces = c.pieces, chanceCarte = c.chanceCarte, duree = c.duree,
					exemplaires = Economie.EXEMPLAIRES_COFFRE[t] }
			end
			return infos
		end)(),
		niveaux = p.niveaux, exemplaires = p.exemplaires, niveauMax = Economie.NIVEAU_MAX,
		-- deck : ce que le joueur emporte reellement (choix valide, ou toutes ses cartes) et
		-- `deckLibre` = false tant qu'il n'a pas assez de cartes pour qu'un choix existe.
		deck = Economie.deck(player), deckTaille = Economie.DECK_TAILLE, tutoFait = p.tutoFait == true,
		deckChoisi = p.deckChoisi ~= nil,
		besoinExemplaires = Economie.EXEMPLAIRES, coutNiveau = Economie.COUT_NIVEAU,
		-- Ce que rapporte UN niveau : la fiche l'affiche avant l'achat (Fiche.gainNiveau).
		bonusParNiveau = Economie.BONUS_PAR_NIVEAU,
		bonusHumain = BONUS_HUMAIN,
		-- Part des trophees contre le robot (Arenes) : l'ecran dit ce que coute le choix du robot.
		partRobot = Arenes.PART_ROBOT,
		-- serie de victoires en cours : le hub l'affiche, sinon le joueur ne sait pas ce qu'il
		-- perd en s'arretant maintenant.
		serie = p.serie or 0, serieMax = Economie.SERIE_MAX,
		-- quetes du jour et coffre gratuit : l'onglet EVENEMENTS les affiche
		evenements = Economie.vueQuetes(player),
		-- SAISON : son numero, le sommet atteint dedans et le temps qu'il reste pour progresser.
		saison = p.saison, tropheesMax = math.max(p.tropheesMax or 0, p.trophees or 0),
		saisonReste = Saison.texteReste(os.time()),
		pass = passVue,
		-- cosmetiques BRUTS (le module n'est pas requis ici : la vue sert aussi aux bancs d'economie)
		cosmetiques = p.cosmetiques,
		-- BILAN DE SAISON : present UNE fois, juste apres la bascule ; l'ecran l'affiche puis
		-- demande son effacement (action « saisonVue »).
		bilanSaison = p.bilanSaison,
		-- JOURNAL : les dernieres parties, avec leur resume. Le hub n'a que cette vue.
		journal = p.journal or {}, journalResume = Journal.resume(p.journal),
		-- REGLAGES SONORES : l'ecran les relit a l'ouverture, et le client les applique a l'arrivee.
		son = p.son or { musique = true, bruitages = true },
	}
end

-- `index` : rang d'un produit de Economie.PRODUITS, ou "vip" pour le pass VIP.
function Economie.demanderRobux(player, index)
	if index == "vip" then
		if Economie.PASS_VIP ~= 0 and not aVip(player) then
			MarketplaceService:PromptGamePassPurchase(player, Economie.PASS_VIP)
		end
		return
	end
	local prod = Economie.PRODUITS[tonumber(index)]
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
		Economie.sauver(player, true)
	end
end)

return Economie
