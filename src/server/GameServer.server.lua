-- Brainrot Royale : serveur (arene, elixir, unites, tours, bot)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cards"))
local Economie = require(script.Parent:WaitForChild("Economie"))
-- File d'attente entre serveurs + un serveur reserve par match (voir Matchmaking.lua)
local Matchmaking = require(script.Parent:WaitForChild("Matchmaking"))
-- Habillage visuel : particules, lumieres, anneau de pose. Aucun asset requis.
local Effets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Effets"))
-- Regles de partie en fonctions PURES (double elixir, prolongation, zone de pose) :
-- verifiables hors Studio par tools/test_regles.py.
local Regles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regles"))
-- SORTS : regles pures (zone visee, cibles, degats, rage), verifiees par tools/test_sorts.py.
local Sorts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sorts"))
-- FOULE : les unites s'encombrent au lieu de se traverser (fonctions pures, tools/test_foule.py).
local Foule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Foule"))
-- CIBLAGE : menace et persistance de la cible (fonctions pures, tools/test_cibles.py).
local Cible = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cible"))
-- DIFFICULTE DU ROBOT : profil deduit des trophees du joueur d'en face (tools/test_robot.py).
local Robot = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Robot"))
local Tutoriel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tutoriel"))
-- STATUTS : gel, ralentissement, poison, bouclier, soin (fonctions pures, tools/test_statuts.py).
local Statuts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Statuts"))
-- BATIMENTS POSES : duree de vie, usure, collecteur, invocateur (tools/test_batiments.py).
local Batiments = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Batiments"))
-- PROJECTILES : un tir met du temps a arriver, et peut se perdre (tools/test_projectiles.py).
local Projectiles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Projectiles"))
-- CYCLE DES CARTES : paquet sans doublon, file de 8, cartes a venir (tools/test_cycle.py).
local Cycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cycle"))
-- ARENES : paliers de trophees, leur nom et ce qu'ils debloquent (tools/test_arenes.py).
local Arenes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Arenes"))
-- Charge : elan des unites qui foncent (degats du premier coup, acceleration).
local Charge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Charge"))
-- Descendance : ce qu'une grosse unite laisse derriere elle en mourant.
local Descendance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Descendance"))
-- Soutien : unites qui renforcent leurs allies proches (aura, jamais stockee).
local Soutien = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Soutien"))
-- Terrain : avantage defensif au pied de ses propres tours.
local Terrain = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terrain"))
-- Specialite : degats majores contre les volants ou contre les essaims.
local Specialite = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Specialite"))
-- Recul : unites qui projettent ce qu'elles frappent.
local Recul = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Recul"))
-- Visee : un tireur vise ou la cible SERA (anticipation du temps de vol).
local Visee = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Visee"))
-- Frappe : composition des bonus de degats, sous un plafond commun.
local Frappe = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Frappe"))
-- Assassin : unites qui vont chercher les tireurs derriere le mur de melee.
local Assassin = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assassin"))
-- Reponse : quelle carte le robot joue CONTRE ce qui arrive.
local Reponse = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reponse"))
-- Emplacement : ou le robot pose un batiment (place reellement libre).
local Emplacement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Emplacement"))
-- Voie : par quel cote attaquer et defendre (egalites departagees).
local Voie = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Voie"))
-- Traversee : franchir la riviere sans se figer a l'entree du pont.
local Traversee = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traversee"))
-- Deploiement : une unite qui arrive n'agit pas avant d'avoir touche le sol.
local Deploiement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Deploiement"))
-- DERNIERE GARDE : le Roi tire plus vite quand il ne reste que lui (mesure : 15 parties sur
-- 20 finissaient par sa chute). Regle pure, banc tools/test_garde.py.
local Garde = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Garde"))
-- RESERVE DEFENSIVE : le robot n'engage pas une attaque qui le laisserait sans reponse.
-- Regle pure, banc tools/test_reserve.py.
local Reserve = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reserve"))
-- FENETRE : pousser quand l'adversaire ne peut pas repondre. C'est la competence qui separe
-- enfin les paliers hauts (Fenetre.lua). Regle pure, banc tools/test_fenetre.py.
local Fenetre = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fenetre"))
-- DEFENSE : ne repondre qu'a une menace que ses propres unites ne tiennent pas deja.
-- Regle pure, banc tools/test_defense.py.
local Defense = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Defense"))
-- Duel : coup d'envoi commun, forfait et revanche a deux (fonctions pures, tools/test_pvp.py).
local Duel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Duel"))
-- Lecture : elixir adverse estime, cartes deja vues, alerte de tour (pures, tools/test_lecture.py).
local Lecture = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lecture"))
-- Apercu : la geometrie d'un anneau au sol (segments) sert AUSSI au compte a rebours des batiments.
local Apercu = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Apercu"))
-- Bilan : elixir gaspille, degats aux tours, cartes jouees (pures, tools/test_bilan.py).
local Bilan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilan"))
local Inactif = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Inactif"))
local Partage = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Partage"))
-- Reprise : delai de grace apres une coupure reseau (pures, tools/test_reprise.py).
local Reprise = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reprise"))
-- Signalement : recours contre un adversaire penible (pures, tools/test_signalement.py).
local Signalement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signalement"))
-- Saison : rang mondial et temps restant, affiches PENDANT le duel (tools/test_saison.py).
local Saison = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Saison"))
-- Spectateur : suivre un camp, main RETARDEE, resultat du pari (pures, tools/test_spectateur.py).
local Spectateur = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spectateur"))
-- Egalise : duel ou toutes les cartes des DEUX camps passent au meme niveau (tools/test_egalise.py).
local Egalise = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Egalise"))
-- Adversaire : dire clairement qui est en face, humain ou robot (pures, tools/test_adversaire.py).
local Adversaire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Adversaire"))
-- Emotes : liste FERMEE partagee avec le client, delai, salut d'ouverture (tools/test_emotes.py).
local Emotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Emotes"))
-- Decor : habillage de l'arene, APPARENCE SEULE (pures, tools/test_decor.py).
local Decor = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Decor"))

Players.CharacterAutoLoads = false

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local PlayCard = Instance.new("RemoteEvent")
PlayCard.Name = "PlayCard"
PlayCard.Parent = remotes
local StateEvent = Instance.new("RemoteEvent")
StateEvent.Name = "State"
StateEvent.Parent = remotes
-- Boutique / hub : le client DEMANDE, le serveur verifie tout (voir Economie.lua)
local BoutiqueFn = Instance.new("RemoteFunction")
BoutiqueFn.Name = "Boutique"
BoutiqueFn.Parent = remotes
local RestartEvent = Instance.new("RemoteEvent")
RestartEvent.Name = "Restart"
RestartEvent.Parent = remotes
-- EMOTES : le client demande une emote, le serveur la valide et la limite en frequence.
local EmoteEvent = Instance.new("RemoteEvent")
EmoteEvent.Name = "Emote"
EmoteEvent.Parent = remotes
-- PRONOSTIC : un spectateur parie (gratuitement) sur le camp gagnant.
local PronosticEvent = Instance.new("RemoteEvent")
PronosticEvent.Name = "Pronostic"
PronosticEvent.Parent = remotes
-- REFUS DE POSE : jusqu'ici le serveur refusait EN SILENCE. Le client avait deja joue le son de
-- pose, retire la carte de la visee et secoue la camera : le joueur croyait avoir pose, et voyait
-- son elixir intact sans comprendre. Le serveur dit maintenant POURQUOI.
local RefusEvent = Instance.new("RemoteEvent")
RefusEvent.Name = "Refus"
RefusEvent.Parent = remotes
-- LATENCE : le client envoie un instant, le serveur le RENVOIE tel quel. C'est le seul moyen
-- honnete de mesurer un aller-retour ; deduire la latence du nombre d'images melangerait la carte
-- graphique et le reseau. Le serveur ne garde rien et ne calcule rien : il fait l'echo.
local PingEvent = Instance.new("RemoteEvent")
PingEvent.Name = "Ping"
PingEvent.Parent = remotes
-- VUE POUSSEE : un pass Roblox paye en jeu ne bouge aucun solde, et le hub ne se rafraichissait
-- que sur un changement de solde — la piste premium restait verrouillee sous les yeux du joueur
-- qui venait de payer. Bloc `do` : aucune variable locale de plus au niveau du script.
do
	local vueEvent = Instance.new("RemoteEvent")
	vueEvent.Name = "Vue"
	vueEvent.Parent = remotes
end

-- Constantes
-- Largeur de l'arene portee de 18 a 28 (2026-09-14) : a 36 studs de large pour 64 de long, l'arene
-- ne pouvait pas remplir un ecran large — la hauteur etait pleine, les cotes vides. Les ponts et
-- les tours laterales se DEDUISENT de la largeur, pour qu'un prochain reglage n'en oublie aucun.
local HALF_W, HALF_L = 32, 44 -- agrandie le 2026-09-21 (etait 28, 32) : pas assez de place pour jouer
local VOIE_X = math.floor(HALF_W * 0.61) -- axe des ponts et des tours de cote (17 pour 28)
local BRIDGES = { -VOIE_X, VOIE_X }
-- Largeur utile d'un pont et demi-largeur de la bande d'eau : elles servent au RECUL, qui ne doit
-- jamais deposer une unite terrestre dans la riviere (les berges sont posees a z = +/- 2,2).
local MAX_ELIXIR = 10
-- Duree d'une partie. La COPIE DE TEST la raccourcit (marqueur BRR_COURT pose par build.py) :
-- sinon, verifier la fin de partie demanderait 3 minutes de capture par essai. 25 s et non 40 :
-- le client de test rend la main vers 32 s, il ne voyait donc jamais la fin (mesure 2026-09-14).
local MATCH_TIME = ReplicatedStorage:FindFirstChild("BRR_COURT") and 25 or 180
local GROUND_Y = 0.5

local arena
local entities = {}
local teams = {}
-- DERNIERE GARDE deja annoncee pour ce camp (une ligne de journal par partie et par camp).
local gardeAnnoncee = {}

-- declares ICI (et non pres de attribuerCamp) : endMatch et resetMatch, plus haut, s'en servent
local equipeDe = {}          -- joueur -> 1 ou 2
local occupant = { nil, nil } -- camp -> joueur
local timeLeft = MATCH_TIME
local result = nil
-- TUTORIEL EN COURS : le module `Shared/Tutoriel` decrit le scenario (carte imposee, elixir
-- impose, plafond de temps) ; ici on ne garde que l'AVANCEE. `demande` distingue le tutoriel
-- impose au joueur neuf de celui relance depuis le menu.
local tuto = { actif = false, index = 0, dansEtape = 0, camp = 1, poseFaite = false, conditionFaite = false, joueur = nil }
local tutoDemande = false -- mis a vrai par l'action « tutoriel » du menu (REVOIR LE TUTORIEL)
-- TUTORIEL FINI : le joueur a qui l'annoncer. La partie d'apprentissage se TERMINE avec la
-- derniere etape (Tutoriel.retourMenu) ; sans ce drapeau, le hub n'avait aucun moyen de savoir
-- que c'etait fini et laissait le debutant seul dans un match de 3 minutes.
local tutoFiniPour = nil

local function tutoEtape()
	return tuto.actif and Tutoriel.etape(tuto.index) or nil
end

-- Entree dans une etape : l'elixir impose CREE le manque que l'etape veut montrer.
local function tutoEntrerEtape(n)
	tuto.index = n
	tuto.dansEtape = 0
	tuto.poseFaite = false
	tuto.conditionFaite = false
	local e = Tutoriel.etape(n)
	local t = teams[tuto.camp]
	if e and e.elixir and t then
		t.elixir = e.elixir
	end
	-- La carte imposee doit etre DANS LA MAIN, sinon l'etape est injouable : le paquet est tire
	-- au hasard et ne contenait pas « Glorbo » a l'etape 2 (capture cap-tuto-etape.png). On la
	-- place au premier emplacement ; la carte remplacee retourne au fond de la pioche.
	if e and e.carte and t and t.hand then
		local deja = false
		for i = 1, 4 do
			if t.hand[i] == e.carte then
				deja = true
			end
		end
		if not deja then
			if t.hand[1] then
				table.insert(t.queue, t.hand[1])
			end
			t.hand[1] = e.carte
		end
	end
	if e then
		print(string.format("[TUTO] etape %d/%d : %s", n, Tutoriel.nombreEtapes(), e.id))
	end
end
local stateTimer = 0
local photoMains = 0

-- COUP D'ENVOI D'UN DUEL (serveur reserve). Avant, le premier arrive lancait la partie tout seul :
-- le chrono tournait, son elixir montait et son robot jouait pendant que l'autre joueur etait
-- encore en teleportation. Le deuxieme entrait donc dans une partie deja commencee, avec moins
-- d'elixir et moins de temps. Desormais la partie est GELEE jusqu'a ce que les deux camps soient
-- pris (ou jusqu'au plafond d'attente), puis un compte a rebours part pour les deux en meme temps.
local departServeur = os.clock()
local finCompteARebours = nil -- instant (os.clock) du coup d'envoi, une fois les deux presents
local geleDepart = false

local function joueursPresents()
	local n = 0
	for camp = 1, 2 do
		if occupant[camp] then
			n = n + 1
		end
	end
	return n
end

-- Rend (gele, texte, secondes). `gele` : la simulation ne tourne pas encore.
-- Un serveur reserve a UN duel. BRR_DUEL (copie de test) l'arme dans Studio, qui ne peut pas en
-- etre un : sans ce crochet, le coup d'envoi commun ne serait verifiable qu'en production.
local function estDuelReserve()
	return Matchmaking.estServeurDeMatch(game) or ReplicatedStorage:FindFirstChild("BRR_DUEL") ~= nil
end

local function etatDepart()
	if not estDuelReserve() or result then
		return false
	end
	local joueurs = joueursPresents()
	if joueurs >= 2 then
		finCompteARebours = finCompteARebours or os.clock()
	end
	return Duel.attente(true, joueurs, os.clock() - departServeur,
		finCompteARebours and (os.clock() - finCompteARebours) or nil)
end

local function sideOf(z)
	if z >= 0 then
		return 1
	end
	return -1
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = arena
	return p
end

-- AMBIANCE. Par defaut, Roblox eclaire a plat : les cubes sortent ternes et l'arene grise.
-- Soleil bas + ombres + brume legere + ciel : la meme geometrie gagne du relief, sans cout de calcul
-- notable puisque tout est fixe (aucune lumiere dynamique ajoutee).
-- Declare AVANT poserAmbiance : la valeur est choisie plus bas (resetMatch), mais un `local`
-- pose apres son usage vaut nil a l'appel. fix-ok: « GameServer:258: attempt to index nil with
-- 'heure' » (journal du 2026-09-20) faisait echouer buildArena, donc toute la partie.
local themeArene
local function c3(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local grainesDecor = 0

local function poserAmbiance()
	local ciel = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	ciel.Parent = Lighting
	Lighting.ClockTime = themeArene.heure -- position du soleil : propre au theme (apparence seule)
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.15
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 150)
	Lighting.Ambient = Color3.fromRGB(70, 75, 90)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	-- PAS de Lighting.Technology ici : un script du jeu n'a pas le droit de l'ecrire (« lacking
	-- capability RobloxScript », mesure du 2026-09-14) et l'erreur tuait tout le serveur — arene
	-- absente, cartes vides. Le moteur de rendu est donc choisi dans le fichier de la place,
	-- par build.py.

	local brume = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	brume.Density = math.min(themeArene.brume, Decor.BRUME_MAX) -- au-dela, l'atmosphere noie la scene
	brume.Offset = 0.1
	brume.Haze = 1.2
	brume.Glare = 0.35
	-- fix-ok (capture moteur du 2026-09-20) : la COULEUR de la brume etait ecrite en dur, bleu pale.
	-- En augmentant sa densite pour un theme chaud, toute la scene virait au bleu — « Terres
	-- brulees » sortait bleu ciel. La teinte suit donc le theme, comme la densite.
	brume.Color = c3(themeArene.brumeCouleur)
	brume.Decay = c3(themeArene.brumeFond)
	brume.Parent = Lighting

	local eclat = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	eclat.Intensity = 0.45; eclat.Size = 24; eclat.Threshold = 1.6; eclat.Parent = Lighting
	local couleur = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	couleur.Saturation = themeArene.teinte; couleur.Contrast = 0.12; couleur.Parent = Lighting
	local profondeur = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	profondeur.Intensity = 0.12; profondeur.Spread = 0.6; profondeur.Parent = Lighting
end

-- DECOR. Purement visuel (CanCollide=false, CanQuery=false) : n'influe ni sur le deplacement ni sur
-- le ciblage. Tout est derive de HALF_W/HALF_L/BRIDGES, donc suit un futur redimensionnement.
local function deco(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CastShadow = props.CastShadow ~= false
	return makePart(props)
end

local function decorerArene()
	local pierre = c3(themeArene.pierre)
	-- bordures en pierre autour du terrain
	for _, s in ipairs({ -1, 1 }) do
		deco({ Name = "Muret", Size = Vector3.new(1.5, 1.6, HALF_L * 2 + 3), Position = Vector3.new(s * (HALF_W + 0.75), 0.8, 0), Color = pierre, Material = Enum.Material.Cobblestone })
		deco({ Name = "Muret", Size = Vector3.new(HALF_W * 2 + 3, 1.6, 1.5), Position = Vector3.new(0, 0.8, s * (HALF_L + 0.75)), Color = pierre, Material = Enum.Material.Cobblestone })
	end
	-- sol exterieur plus sombre pour detacher l'arene
	deco({ Name = "Exterieur", Size = Vector3.new(HALF_W * 2 + 120, 0.8, HALF_L * 2 + 120), Position = Vector3.new(0, -0.3, 0), Color = c3(themeArene.exterieur), Material = Enum.Material.Grass, CastShadow = false })
	-- allees de terre menant aux ponts
	for _, bx in ipairs(BRIDGES) do
		deco({ Name = "Allee", Size = Vector3.new(3.2, 0.06, HALF_L * 2 - 4), Position = Vector3.new(bx, 0.53, 0), Color = c3(themeArene.allee), Material = Enum.Material.Ground, CastShadow = false })
		for _, s in ipairs({ -1, 1 }) do
			deco({ Name = "Rambarde", Size = Vector3.new(0.4, 1, 6), Position = Vector3.new(bx + s * 2.1, 1.1, 0), Color = c3(themeArene.bois), Material = Enum.Material.Wood })
		end
	end
	-- berges de la riviere
	for _, s in ipairs({ -1, 1 }) do
		deco({ Name = "Berge", Size = Vector3.new(HALF_W * 2, 0.7, 0.6), Position = Vector3.new(0, 0.55, s * 2.2), Color = c3(themeArene.pierre), Material = Enum.Material.Slate })
	end
	-- arbres et rochers autour, placement deterministe (meme decor a chaque partie)
	local rng = Random.new(42)
	for i = 1, 26 do
		local cote = (i % 2 == 0) and 1 or -1
		local x = cote * (HALF_W + 4 + rng:NextNumber(0, 14))
		local z = rng:NextNumber(-HALF_L, HALF_L)
		if i % 3 == 0 then
			deco({ Name = "Rocher", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.2, 3) * rng:NextNumber(0.7, 1.4), Position = Vector3.new(x, 0.6, z), Color = c3(themeArene.rocher), Material = Enum.Material.Rock })
		else
			local h = rng:NextNumber(4, 7)
			deco({ Name = "Tronc", Size = Vector3.new(0.9, h, 0.9), Position = Vector3.new(x, h / 2, z), Color = c3(themeArene.bois), Material = Enum.Material.Wood })
			deco({ Name = "Feuillage", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5) * rng:NextNumber(0.8, 1.3), Position = Vector3.new(x, h + 1.5, z), Color = c3(themeArene.feuillage):Lerp(Color3.fromRGB(255, 255, 255), rng:NextNumber(0, 0.18)), Material = Enum.Material.Grass })
		end
	end
end

-- RESTES : les corps en cours d'agonie vivent ICI, hors de l'arene. Le client joue le son de mort
-- et secoue la camera sur la DISPARITION de la part dans l'arene (GameClient, ChildRemoved) : si le
-- corps restait dans l'arene pendant son agonie, le son arriverait 0,45 s APRES l'explosion.
-- THEME DE L'ARENE : choisi une seule fois par partie, cote SERVEUR, donc identique pour les deux
-- joueurs. Il ne change QUE des couleurs et la lumiere : la geometrie reste la meme a chaque duel.
themeArene = Decor.THEMES[1]

local restes = nil
local function dossierRestes()
	if not restes or not restes.Parent then
		restes = Instance.new("Folder")
		restes.Name = "Restes"
		restes.Parent = workspace
	end
	return restes
end

local function buildArena()
	if arena then
		arena:Destroy()
	end
	if restes then
		restes:Destroy()
		restes = nil
	end
	arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace
	poserAmbiance()

	-- MEMES DIMENSIONS ET MEMES POSITIONS A CHAQUE DUEL : seules les couleurs suivent le theme.
	makePart({ Name = "GroundPlayer", Size = Vector3.new(HALF_W * 2, 1, HALF_L), Position = Vector3.new(0, 0, -HALF_L / 2), Color = c3(themeArene.herbeProche), Material = Enum.Material.Grass })
	makePart({ Name = "GroundEnemy", Size = Vector3.new(HALF_W * 2, 1, HALF_L), Position = Vector3.new(0, 0, HALF_L / 2), Color = c3(themeArene.herbeLoin), Material = Enum.Material.Grass })
	makePart({ Name = "River", Size = Vector3.new(HALF_W * 2, 1.1, 4), Position = Vector3.new(0, 0.05, 0), Color = c3(themeArene.eau), Material = Enum.Material.Glass, Transparency = 0.2 })
	for _, bx in ipairs(BRIDGES) do
		makePart({ Name = "Bridge", Size = Vector3.new(4, 1.3, 6), Position = Vector3.new(bx, 0.15, 0), Color = c3(themeArene.bois), Material = Enum.Material.WoodPlanks })
	end
	-- zone de pose du joueur (visuelle)
	makePart({ Name = "DeployZone", Size = Vector3.new(HALF_W * 2, 0.05, HALF_L - 2), Position = Vector3.new(0, 0.53, -(HALF_L - 2) / 2 - 2), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.92, CanCollide = false })
	decorerArene()
	-- SIGNATURE DE GEOMETRIE (copie de test) : taille et position de tout ce qui porte les regles.
	-- Deux decors differents doivent rendre EXACTEMENT la meme ligne — c'est la preuve, en moteur,
	-- que l'habillage n'a pas bouge d'un centimetre ce qui se joue.
	if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
		local bouts = {}
		for _, nom in ipairs({ "GroundPlayer", "GroundEnemy", "River", "Bridge", "DeployZone" }) do
			for _, p in ipairs(arena:GetChildren()) do
				if p.Name == nom and p:IsA("BasePart") then
					table.insert(bouts, string.format("%s:%.2f,%.2f,%.2f@%.2f,%.2f,%.2f",
						nom, p.Size.X, p.Size.Y, p.Size.Z, p.Position.X, p.Position.Y, p.Position.Z))
				end
			end
		end
		table.sort(bouts)
		print("[BRRGEO] decor=" .. themeArene.id .. " | " .. table.concat(bouts, " "))
	end
end

local function makeHealthBar(part, label, color)
	local gui = Instance.new("BillboardGui")
	-- Taille en PIXELS : en studs, la camera haute (~80 studs) rendait noms et barres illisibles.
	local tour = part.Size.X >= 5
	gui.Size = tour and UDim2.new(0, 110, 0, 30) or UDim2.new(0, 90, 0, 26)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.Text = label
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0
	name.Font = Enum.Font.GothamBold
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0.35, 0)
	back.Position = UDim2.new(0, 0, 0.6, 0)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	-- SEUILS, SUR LES TOURS SEULEMENT. Defaut mesure le 2026-09-20 : la barre etait une bande unie
	-- qui raccourcit. Rien n'y marquait la MOITIE ni le QUART, qui declenchent pourtant les alertes
	-- du jeu, et aucun chiffre ne disait ou en etait la tour : « elle tient encore ? » se jugeait a
	-- l'oeil, sur trois pixels. Les traits viennent des MEMES constantes que l'alerte, donc la
	-- barre ne peut pas dire autre chose que ce que le jeu fait. Les unites n'en recoivent pas :
	-- quarante barres marquees seraient du bruit.
	if tour then
		for _, seuil in ipairs(Lecture.SEUILS_AFFICHES) do
			local trait = Instance.new("Frame")
			trait.Size = UDim2.new(0, 2, 1, 0)
			trait.Position = UDim2.new(seuil, -1, 0, 0)
			trait.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
			trait.BorderSizePixel = 0
			trait.ZIndex = 3
			trait.Parent = back
		end
		local part = Instance.new("TextLabel")
		part.Name = "PartVie"
		part.BackgroundTransparency = 1
		part.Size = UDim2.new(1, 0, 0.45, 0)
		part.Position = UDim2.new(0, 0, 0.12, 0)
		part.TextXAlignment = Enum.TextXAlignment.Right
		part.TextScaled = true
		part.TextStrokeTransparency = 0
		part.Font = Enum.Font.GothamBold
		part.Text = "100 %"
		part.Parent = gui
	end
	return fill
end

-- Met la barre d'une entite a jour : sa longueur, et — pour une tour — son chiffre de vie avec sa
-- couleur d'alerte. UN SEUL endroit, appele partout ou les points de vie bougent (degats, soin,
-- usure) : sinon une tour soignee garderait un chiffre rouge.
local function majBarre(e)
	if not e or not e.fill then
		return
	end
	local part = math.max(0, math.min(1, e.hp / math.max(1, e.maxHp)))
	e.fill.Size = UDim2.new(part, 0, 1, 0)
	-- JAUGE EN GEOMETRIE (tours) : elle se vide vers la GAUCHE, donc sa longueur ET son centre
	-- bougent. Sa couleur suit le niveau, comme le chiffre.
	if e.jaugeVie and e.jaugeVie.Parent then
		local L = e.jaugeLarge * math.max(part, 0.001)
		e.jaugeVie.Size = Vector3.new(L, 0.9, 0.7)
		e.jaugeVie.Position = Vector3.new(e.jaugeX - e.jaugeLarge / 2 + L / 2,
			e.jaugeVie.Position.Y, e.jaugeVie.Position.Z)
		local c = Lecture.teinteVie(Lecture.niveauVie(e.hp, e.maxHp))
		e.jaugeVie.Color = Color3.fromRGB(c[1], c[2], c[3])
	end
	local etiquette = e.fill.Parent and e.fill.Parent.Parent
	local part = etiquette and etiquette:FindFirstChild("PartVie")
	if part then
		part.Text = Lecture.texteVie(e.hp, e.maxHp)
		local rgb = Lecture.teinteVie(Lecture.niveauVie(e.hp, e.maxHp))
		part.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
end

local function teamColor(team)
	if team == 1 then
		return Color3.fromRGB(60, 140, 255)
	end
	return Color3.fromRGB(255, 70, 70)
end

local function addEntity(e)
	e.hp = e.maxHp
	e.cooldown = 0
	e.alive = true
	if not e.enGroupe then
		e.fill = makeHealthBar(e.part, e.label, teamColor(e.team))
		e.etiquette = e.fill.Parent.Parent
		e.hauteurBase = e.etiquette.StudsOffset.Y
	end
	table.insert(entities, e)
	return e
end

-- SKIN DE TOURS PAR CAMP (module Cosmetiques) : rempli quand un joueur prend un camp, relu a chaque
-- reconstruction des tours. Apparence seulement : corps a la couleur du CAMP, ornements du skin.
-- APPARENCE du joueur (skins de tours, emotes) dans UNE variable locale : ce fichier touche le
-- plafond des 200 locales de Lua.
local apparence = { Cosmetiques = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetiques")) }
apparence.skinCamp = {}
-- Emotes premium POSSEDEES, publiees en attribut du joueur : la barre d'emotes de la partie les
-- lit directement (« tralalero,roi »). Le serveur reste l'autorite (emotePermise).
function apparence.publierEmotes(player)
	local cos = Economie.cosmetiques(player)
	local l = {}
	for id, v in pairs(cos and cos.possedes or {}) do
		if v then
			table.insert(l, id)
		end
	end
	player:SetAttribute("EmotesPossedees", table.concat(l, ","))
end
function apparence.appliquerSkinTour(tour, skinId)
	local s = apparence.Cosmetiques.skin(skinId)
	local part = tour.part
	if not part or not part.Parent then
		return
	end
	part.Material = Enum.Material[s.corps]
	for _, o in ipairs(part:GetChildren()) do
		if o.Name == "Creneau" then
			o.Color = c3(s.creneaux)
			o.Material = Enum.Material[s.creneauxMat]
		elseif o.Name == "Toit" then
			o.Color = s.toit and c3(s.toit) or part.Color:Lerp(Color3.new(0, 0, 0), 0.25)
			o.Material = Enum.Material[s.toitMat]
		elseif o.Name == "Drapeau" and s.drapeau then
			o.Color = c3(s.drapeau)
		elseif o.Name == "LiseretSkin" then
			o:Destroy()
		end
	end
	if s.accent then
		-- liseret NEON autour du haut de la tour : le skin se reconnait de loin
		local l = Instance.new("Part")
		l.Name = "LiseretSkin"
		l.Anchored = true
		l.CanCollide = false
		l.CanQuery = false
		l.Material = Enum.Material.Neon
		l.Color = c3(s.accent)
		l.Size = Vector3.new(part.Size.X + 0.3, 0.35, part.Size.Z + 0.3)
		l.CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 - 0.3, 0)
		l.Parent = part
	end
end
function apparence.appliquerSkin(camp)
	for _, tw in ipairs(teams[camp] and teams[camp].towers or {}) do
		apparence.appliquerSkinTour(tw, apparence.skinCamp[camp] or apparence.Cosmetiques.DEFAUT)
	end
end

local function spawnTower(team, x, z, isKing)
	local size = isKing and Vector3.new(7, 8, 7) or Vector3.new(5, 7, 5)
	local part = makePart({
		Name = isKing and "KingTower" or "PrincessTower",
		Size = size,
		Position = Vector3.new(x, GROUND_Y + size.Y / 2, z),
		Color = teamColor(team),
		Material = Enum.Material.Brick,
	})
	-- CAMP EN ATTRIBUT : le client colore ensuite SELON LE JOUEUR qui regarde (Shared/Camps).
	-- Sans lui, il faudrait deviner le camp a la couleur, qui est justement ce qu'on veut changer.
	part:SetAttribute("Camp", team)
	-- habillage de la tour : socle, creneaux, toit conique, drapeau. Enfants de la tour, donc
	-- detruits avec elle ; visuels seulement.
	local function orner(props)
		props.CanCollide = false; props.CanQuery = false; props.Anchored = true
		local p = Instance.new("Part")
		for k, v in pairs(props) do p[k] = v end
		p.Parent = part
	end
	local haut = GROUND_Y + size.Y
	orner({ Size = Vector3.new(size.X + 1.2, 1, size.Z + 1.2), Position = Vector3.new(x, GROUND_Y + 0.5, z), Color = Color3.fromRGB(140, 135, 125), Material = Enum.Material.Cobblestone })
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		orner({ Name = "Creneau", Size = Vector3.new(1.2, 1.2, 1.2), Position = Vector3.new(x + c[1] * (size.X / 2 - 0.6), haut + 0.6, z + c[2] * (size.Z / 2 - 0.6)), Color = Color3.fromRGB(200, 195, 185), Material = Enum.Material.Limestone })
	end
	orner({ Name = "Toit", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.X * 0.7, size.X * 0.7, size.X * 0.7), CFrame = CFrame.new(x, haut + 1.4, z) * CFrame.Angles(0, 0, math.rad(90)), Color = teamColor(team):Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Slate })
	orner({ Size = Vector3.new(0.2, 3.5, 0.2), Position = Vector3.new(x, haut + 3.5, z), Color = Color3.fromRGB(80, 60, 40), Material = Enum.Material.Wood })
	orner({ Name = "Drapeau", Size = Vector3.new(1.8, 1.1, 0.1), Position = Vector3.new(x + 0.9, haut + 4.6, z), Color = isKing and Color3.fromRGB(255, 205, 60) or teamColor(team), Material = Enum.Material.Fabric })
	-- JAUGE DE VIE EN VRAIE GEOMETRIE. L'etiquette flottante au-dessus de la tour porte deja la
	-- barre, mais CaptureService ne rend PAS les BillboardGui : rien de tout cela n'est verifiable
	-- sur une capture, et une ombre de doute reste sur ce qu'un joueur voit vraiment. On pose donc
	-- la meme information en parts NEON, devant la tour : un rail sombre, un remplissage colore
	-- selon le niveau (vert / orange / rouge) et deux encoches aux SEUILS du jeu (moitie, quart).
	local LARGE = size.X + 1.4
	-- Cote AVANT pour les tours de princesse ; cote RIVIERE pour le Roi, dont l'avant est au bord
	-- de l'ecran et passait sous la barre de cartes (capture cap-tours-sante.png du 2026-09-20).
	local sens = isKing and 1 or -1
	local zJauge = z + (team == 1 and sens or -sens) * (size.Z / 2 + 0.9)
	local yJauge = GROUND_Y + 1.1
	orner({ Name = "RailVie", Size = Vector3.new(LARGE + 0.5, 1.15, 0.45), Position = Vector3.new(x, yJauge, zJauge),
		Color = Color3.fromRGB(18, 18, 26), Material = Enum.Material.SmoothPlastic })
	local remplissage = Instance.new("Part")
	remplissage.Name = "RemplissageVie"
	remplissage.Anchored = true; remplissage.CanCollide = false; remplissage.CanQuery = false
	remplissage.CastShadow = false
	remplissage.Size = Vector3.new(LARGE, 0.9, 0.7)
	remplissage.Position = Vector3.new(x, yJauge, zJauge)
	remplissage.Material = Enum.Material.Neon
	-- Couleur de depart = celle du niveau « sain », la meme que le chiffre : une seule source.
	remplissage.Color = Color3.fromRGB(120, 235, 150)
	remplissage.Parent = part
	for _, seuil in ipairs(Lecture.SEUILS_AFFICHES) do
		-- La jauge se vide de la droite vers la gauche : le seuil est a `seuil` du bord gauche.
		orner({ Name = "SeuilVie", Size = Vector3.new(0.22, 1.35, 0.75),
			Position = Vector3.new(x - LARGE / 2 + LARGE * seuil, yJauge, zJauge),
			Color = Color3.fromRGB(245, 245, 250), Material = Enum.Material.SmoothPlastic })
	end
	return addEntity({
		jaugeVie = remplissage, jaugeLarge = LARGE, jaugeX = x,
		part = part, team = team, isBuilding = true, isKing = isKing,
		label = isKing and "Roi" or "Tour",
		-- melee de test : tours x20, sinon la partie finissait en 13-17 s et l'ecran de fin cachait tout
		maxHp = (isKing and 5200 or 3400) * (ReplicatedStorage:FindFirstChild("BRR_MELEE") and 20 or 1), dmg = isKing and 70 or 55,
		range = isKing and 12 or 14, atkSpeed = 0.85, speed = 0,
		targets = "any", active = not isKing,
		-- une tour est un obstacle : les unites la contournent au lieu d'entrer dedans
		rayonFoule = math.max(size.X, size.Z) / 2,
	})
end

-- SILHOUETTES. Un cube colore ne dit pas quel personnage on joue. Chaque carte porte desormais une
-- liste de morceaux (decalage, taille, couleur, forme) soudes au corps : museau, nageoire, ailes,
-- batte, tasse, banane. C'est de la geometrie simple, sans fichier externe ni dependance a un
-- modele du catalogue — donc rien a telecharger et rien qui puisse disparaitre.
-- Temps de jeu (accelere avec SIM) : sert a dater les attaques et les coups pour l'animation.
local horloge = 0

local MODELES = ReplicatedStorage:FindFirstChild("Modeles")

-- SILHOUETTE ET ANCRAGE AU SOL (2026-09-20) ----------------------------------------------------
-- fix-ok: cause mesuree du rendu « unites en cubes » — aucune unite ne portait de contour ni
-- d'ombre : posee sur l'arene claire, la geometrie se confondait avec le decor et on ne lisait
-- ni la silhouette ni le camp. Le trait cartoon (Highlight, contour SEUL : FillTransparency = 1,
-- donc aucune teinte ajoutee sur les couleurs de la carte) redonne la decoupe, et le disque
-- d'ombre pose l'unite au sol au lieu de la laisser flotter.
local function poserSilhouette(corps, card, teamColor)
	local trait = Instance.new("Highlight")
	trait.FillTransparency = 1
	trait.OutlineColor = teamColor:Lerp(Color3.new(0, 0, 0), 0.65)
	trait.OutlineTransparency = 0.05
	trait.DepthMode = Enum.HighlightDepthMode.Occluded
	trait.Adornee = corps
	trait.Parent = corps

	local rayon = math.max(card.size.X, card.size.Z) * (card.echelle or 1) * 1.15
	local ombre = Instance.new("Part")
	ombre.Name = "OmbreSol"
	ombre.Shape = Enum.PartType.Cylinder
	ombre.Anchored = true
	ombre.CanCollide = false
	ombre.CanQuery = false
	ombre.CastShadow = false
	ombre.Size = Vector3.new(0.12, rayon, rayon)
	ombre.Color = Color3.fromRGB(0, 0, 0)
	ombre.Material = Enum.Material.SmoothPlastic
	ombre.Transparency = 0.62
	local ecart = Vector3.new(0, -card.size.Y / 2 + 0.06, 0)
	ombre.CFrame = corps.CFrame * CFrame.new(ecart) * CFrame.Angles(0, 0, math.rad(90))
	ombre:SetAttribute("Ecart", ecart)
	ombre:SetAttribute("RotX", 0); ombre:SetAttribute("RotY", 0); ombre:SetAttribute("RotZ", 90)
	-- « Sol » : le disque ne suit PAS le rebond de l'animation, il reste par terre.
	ombre:SetAttribute("Sol", true)
	ombre.Parent = corps
end

local function habiller(corps, card, teamColor)
	-- Regle des formes lisses (module Arrondi). Chargee ICI et non en variable du fichier : le
	-- corps de ce script est au plafond des 200 variables locales de Lua.
	local arrondi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Arrondi"))
	-- MODELE DE LA BOUTIQUE (ecrit dans la place par build.py, sans aucun script) : prioritaire
	-- sur l'assemblage de morceaux, qui reste le repli si le modele manque — ou s'il est lui-meme
	-- EN BLOCS (Arrondi.MODELES_EN_BLOCS) : le rendu lisse est alors plus proche du rendu voulu.
	-- `if` et non « a and b and c » : la chaine rendrait `false` pour un modele ecarte, et le
	-- meme piege a deja fige le menu dans Figurine (journal du 2026-09-21).
	local source = nil
	-- un CHAMPION reprend le modele de sa carte de base (`modele`)
	if MODELES and arrondi.modeleRetenu(card.modele or card.id) then
		source = MODELES:FindFirstChild(card.modele or card.id)
	end
	if source then
		local modele = source:Clone()
		modele.WorldPivot = CFrame.new() -- build.py centre les pieces sur l'origine
		-- rotation propre au modele : chaque auteur a choisi son « avant » ; on l'aligne sur l'avant
		-- du corps (-Z, celui de CFrame.lookAt), qui suit la marche de l'unite.
		modele:PivotTo(CFrame.Angles(0, math.rad(card.modeleRotY or 0), 0))
		modele.WorldPivot = CFrame.new()
		local _, taille = modele:GetBoundingBox()
		-- HAUTEUR visee par carte (et non la plus grande dimension, qui ecrasait les modeles longs),
		-- plafonnee pour qu'un modele tres long ne deborde pas sur les voisins.
		local hauteur = (card.hauteurModele or card.size.Y * 1.5) * (card.echelle or 1)
		local facteur = hauteur / math.max(taille.Y, 0.01)
		local plafond = hauteur * 2.2 / math.max(taille.X, taille.Z, 0.01)
		facteur = math.min(facteur, plafond)
		if facteur > 0 then
			modele:ScaleTo(facteur)
		end
		local _, apres = modele:GetBoundingBox()
		-- pieds au niveau du bas du corps
		local ecart = Vector3.new(0, apres.Y / 2 - card.size.Y / 2, 0)
		modele:SetAttribute("Ecart", ecart)
		modele:SetAttribute("RotX", 0); modele:SetAttribute("RotY", 0); modele:SetAttribute("RotZ", 0)
		modele:PivotTo(corps.CFrame * CFrame.new(ecart))
		modele.Parent = corps
		-- sommet visuel (au-dessus du centre du corps) : sert a poser la marque de camp
		corps:SetAttribute("HautVisuel", ecart.Y + apres.Y / 2)
		poserSilhouette(corps, card, teamColor)
		return
	end
	local morceaux = card.morceaux
	if not morceaux then return end
	-- LISSAGE des brainrots sans modele 3D retenu : chaque bloc est rendu en ellipsoide de memes
	-- dimensions (module Arrondi). Aucun modele premium n'existe pour eux dans la Boutique
	-- (recherche du 2026-09-21) : c'est la seule facon de ne plus les montrer en cubes.
	local lisser = arrondi.applicable(card, false)
	for _, m in ipairs(morceaux) do
		local piece = Instance.new("Part")
		piece.Anchored = true
		piece.CanCollide = false
		local k = card.echelle or 1
		-- decalage vertical : a l'echelle k, les pieds descendraient sous le sol
		local ecart = m.pos * k + Vector3.new(0, (k - 1) * card.size.Y / 2, 0)
		piece.Size = m.taille * k
		piece.Color = m.couleur or card.color
		piece.Material = m.materiau and Enum.Material[m.materiau] or Enum.Material.SmoothPlastic
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		-- l'ombre portee est ce qui donne du volume : sans elle, la piece reste un aplat de couleur.
		piece.CastShadow = true
		if m.forme == "boule" then
			piece.Shape = Enum.PartType.Ball
		elseif m.forme == "cylindre" then
			piece.Shape = Enum.PartType.Cylinder
		elseif lisser and arrondi.forme(m.taille, m.forme) == "ellipsoide" then
			-- Un maillage SPHERE epouse la taille de la piece : le bloc devient un ellipsoide de
			-- memes dimensions. La silhouette du catalogue est gardee, les aretes disparaissent.
			local lisse = Instance.new("SpecialMesh")
			lisse.MeshType = Enum.MeshType.Sphere
			lisse.Parent = piece
		end
		piece.CFrame = corps.CFrame * CFrame.new(ecart) * CFrame.Angles(
			math.rad(m.rot and m.rot.X or 0), math.rad(m.rot and m.rot.Y or 0), math.rad(m.rot and m.rot.Z or 0))
		piece.Parent = corps
		-- PAS DE WeldConstraint : il ne deplace pas une piece ANCREE, et tout est ancre ici (le jeu
		-- bouge les unites a la main, sans physique). On garde donc l'ecart voulu dans un attribut,
		-- et `suivreCorps` le reapplique apres chaque deplacement du corps.
		piece:SetAttribute("Ecart", ecart)
		piece:SetAttribute("RotX", m.rot and m.rot.X or 0)
		piece:SetAttribute("RotY", m.rot and m.rot.Y or 0)
		piece:SetAttribute("RotZ", m.rot and m.rot.Z or 0)
	end
	poserSilhouette(corps, card, teamColor)
end

-- `pose` (facultatif) : decalage d'animation (rebond, dandinement, elan, recul) applique a tous
-- les morceaux sauf ceux marques « Sol » (le disque de camp reste pose par terre).
local function suivreCorps(corps, pose)
	for _, piece in ipairs(corps:GetChildren()) do
		local ecart = piece:GetAttribute("Ecart")
		if ecart then
			local base = corps.CFrame
			if pose and not piece:GetAttribute("Sol") then
				base = base * pose
			end
			local cf = base * CFrame.new(ecart) * CFrame.Angles(
				math.rad(piece:GetAttribute("RotX")), math.rad(piece:GetAttribute("RotY")),
				math.rad(piece:GetAttribute("RotZ")))
			if piece:IsA("Model") then
				piece:PivotTo(cf)
			else
				piece.CFrame = cf
			end
		end
	end
end

-- `degatsDeSort` (facultatif) : vrai quand le multiplicateur sert aux DEGATS D'UN SORT. C'est le
-- niveau, comme pour les unites (regle du 2026-09-21). BRR_SORT_SANS_NIVEAU (copie de test
-- uniquement) remet l'ANCIENNE regle — sorts insensibles au niveau — pour MESURER l'effet du
-- changement a parties egales par ailleurs. Aucune partie reelle ne porte ce drapeau.
-- Parametre et non fonction a part : le corps de ce script est au plafond des 200 variables
-- locales de Lua (« too many local variables », mesure du 2026-09-21).
local function multNiveau(team, id, degatsDeSort)
	if degatsDeSort and ReplicatedStorage:FindFirstChild("BRR_SORT_SANS_NIVEAU") then
		return 1
	end
	local niv = teams[team] and teams[team].niveaux
	return Economie.multiplicateur(niv and niv[id] or 1)
end

-- Niveaux du ROBOT : chaque camp sans joueur prend, pour toutes ses cartes, le niveau fixe par les
-- trophees du joueur d'en face (Economie.niveauRobot). Sans joueur en face : niveau 1.
-- TOURS AU NIVEAU DU CAMP : niveau moyen des cartes du camp, meme bonus que les unites. Mesure du
-- 2026-09-14 : seules les unites gagnaient en force, les tours tombaient vite a haut niveau et les
-- parties duraient ~70 s au lieu de ~125. Appele quand les niveaux d'un camp changent ; une tour
-- deja entamee garde sa PROPORTION de points de vie.
-- Exposant des PV des tours. Mesures (7 parties par niveau, temps x8) : exposant 1 -> 104 s de jeu
-- aux niveaux 3 et 5 (sim-C) ; exposant 2 -> 160 s, parties finies au chrono (sim-D) ; cible ~125 s.
local EXPOSANT_PV_TOURS = 1.5
-- ETAT DES TOURS d'un camp, dans la forme que la regle pure attend ({ estRoi, vivante }). Le
-- serveur nomme ses champs `isKing` et `alive` ; le module de regle ne connait ni l'un ni
-- l'autre, et c'est voulu : il doit rester verifiable hors Studio.
local function etatTours(team)
	local out = {}
	local t = teams and teams[team]
	for _, tw in ipairs((t and t.towers) or {}) do
		table.insert(out, { estRoi = tw.isKing == true, vivante = tw.alive ~= false })
	end
	return out
end

-- FACTEUR de derniere garde pour une entite du serveur. Traduit `isKing` en `estRoi` : sans
-- cette traduction, Garde.facteur rendrait 1 pour TOUTES les tours, en silence, et la regle
-- n'aurait aucun effet sans qu'aucun test ne s'en plaigne.
local function facteurGarde(e)
	if not e or not e.isBuilding or e.estBatimentPose then
		return 1
	end
	return Garde.facteur({ estRoi = e.isKing == true, vivante = e.alive ~= false },
		etatTours(e.team))
end

local function majTours()
	for camp = 1, 2 do
		local t = teams[camp]
		if t and t.niveaux then
			local ids = {}
			for _, c in ipairs(Cards.list) do
				table.insert(ids, c.id)
			end
			if occupant[camp] then
				ids = Economie.deck(occupant[camp]) or ids
			end
			local n = Economie.niveauMoyen(t.niveaux, ids)
			local mult = Economie.multiplicateur(n)
			t.niveauTours = n
			for _, tw in ipairs(t.towers) do
				tw.baseHp = tw.baseHp or tw.maxHp
				tw.baseDmg = tw.baseDmg or tw.dmg
				local part = tw.maxHp > 0 and (tw.hp / tw.maxHp) or 1
				-- PV au CARRE du multiplicateur : une unite de niveau n survit mult fois plus longtemps ET
				-- frappe mult fois plus fort, soit ~mult^2 degats encaisses par une tour. A mult simple,
				-- les parties duraient 104 s aux niveaux 3 et 5 contre 127 s au niveau 1 (tools/sim-C.txt).
				-- arrondi au plus proche : tronquer donnait 6663 au lieu de 6664 (3400 x 1,96) a cause des
				-- decimales binaires de 1,4 x 1,4
				tw.maxHp = math.floor(tw.baseHp * mult ^ EXPOSANT_PV_TOURS + 0.5)
				tw.hp = tw.maxHp * part
				tw.dmg = math.floor(tw.baseDmg * mult)
			end
		end
	end
end

local function majNiveauxRobot()
	for camp = 1, 2 do
		-- BRR_SIM : dans une SERIE de mesure, les deux camps recoivent leur profil, joueur present
		-- ou non. Defaut mesure le 2026-09-21 : en Studio un joueur local occupe toujours un camp,
		-- donc ce camp gardait le profil de la premiere partie pendant que l'autre alternait —
		-- l'alternance des cotes n'avait jamais lieu, et les duels de paliers melangeaient la
		-- force du palier avec l'avantage de cote. Meme piege que le « camp muet » de botThink.
		if teams[camp] and (occupant[camp] == nil
			or ReplicatedStorage:FindFirstChild("BRR_SIM")) then
			-- EGALISE : le robot passe AUSSI au niveau de reference, sinon le camp vide serait le
			-- seul a garder un avantage d'inventaire.
			local n = Egalise.actif(modeEgalise) and Egalise.NIVEAU or Economie.niveauRobot(occupant[3 - camp])
			local niv = {}
			for _, c in ipairs(Cards.list) do
				niv[c.id] = n
			end
			teams[camp].niveaux = niv
			teams[camp].niveauRobot = n
			-- DIFFICULTE : jusqu'ici seule la FORCE de ses cartes suivait le joueur ; son
			-- comportement, lui, etait le meme a 0 trophee et a 3000. Le profil regle son temps
			-- de reflexion, son taux d'erreur et son agressivite.
			-- BRR_ROBOT (copie de test) : force un palier, pour verifier en moteur un comportement
			-- que les trophees d'un joueur neuf ne declencheraient jamais (ex. la contre-attaque).
			local force = ReplicatedStorage:FindFirstChild("BRR_ROBOT")
			-- DUEL DE PALIERS : « normal:expert » donne un palier DIFFERENT a chaque camp, et les
			-- deux cotes s'echangent a chaque partie (Robot.paliersDuel). C'est ce qui permet de
			-- verifier que les paliers sont vraiment classes par force. Un nom seul garde
			-- l'ancien comportement : les deux camps au meme niveau.
			-- Le numero de partie est porte par l'objet BRR_SIM lui-meme : le fichier principal
			-- est a la limite des 200 variables locales de Luau, une de plus ne compile pas.
			local nomDuel = force and Robot.paliersDuel(force.Value, camp,
				(ReplicatedStorage:FindFirstChild("BRR_SIM")
					and ReplicatedStorage.BRR_SIM:GetAttribute("partie")) or 1)
			teams[camp].profilRobot = (nomDuel and Robot.profilNomme(nomDuel))
				or (force and Robot.profilNomme(force.Value))
				or Robot.profil(Economie.tropheesDe(occupant[3 - camp]))
			print(string.format("[BOT] camp=%d difficulte=%s (trophees=%d)", camp,
				teams[camp].profilRobot.nom, teams[camp].profilRobot.trophees))
		end
	end
	majTours()
end

local function spawnUnit(card, team, pos, offset, enGroupe)
	local flyY = card.flying and 6 or 0
	local part = makePart({
		Name = card.id,
		Size = card.size,
		Position = Vector3.new(pos.X + offset.X, GROUND_Y + card.size.Y / 2 + flyY, pos.Z + offset.Z),
		Color = card.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		-- invisible : le cube reste la zone de contact, les morceaux dessinent le personnage
		Transparency = card.morceaux and 1 or 0,
		CastShadow = not card.morceaux,
	})
	-- tourne vers l'adversaire des l'apparition (camp 1 regarde +Z, camp 2 regarde -Z) ; la marche
	-- reoriente ensuite le corps via CFrame.lookAt.
	part.CFrame = CFrame.lookAt(part.Position, part.Position + Vector3.new(0, 0, team == 1 and 1 or -1))
	part:SetAttribute("Camp", team) -- lu par le client pour colorer ami/ennemi (Shared/Camps)
	habiller(part, card, teamColor(team))
	-- MARQUE DE CAMP au-dessus de la tete. En melee, les gros modeles recouvraient les disques au sol
	-- et l'on ne savait plus qui etait bleu ou rouge (capture --melee du 2026-09-14). Piece 3D et non
	-- etiquette flottante : CaptureService ne rend pas les BillboardGui, la marque ne serait pas
	-- verifiable sur capture.
	local haut = part:GetAttribute("HautVisuel") or card.size.Y / 2
	local marque = Instance.new("Part")
	marque.Name = "MarqueCamp"
	marque:SetAttribute("Camp", team)
	marque.Anchored = true; marque.CanCollide = false; marque.CanQuery = false; marque.CastShadow = false
	marque.Shape = Enum.PartType.Ball
	marque.Size = Vector3.new(1.3, 1.3, 1.3)
	marque.Material = Enum.Material.Neon
	marque.Color = teamColor(team)
	local ecartMarque = Vector3.new(0, haut + 1, 0)
	marque:SetAttribute("Ecart", ecartMarque)
	marque:SetAttribute("RotX", 0); marque:SetAttribute("RotY", 0); marque:SetAttribute("RotZ", 0)
	marque.CFrame = part.CFrame * CFrame.new(ecartMarque)
	marque.Parent = part
	-- disque au sol a la couleur du camp (remplace le cadre autour du cube, qui dessinait un cube
	-- meme invisible). Suit le corps via les attributs d'ecart, comme les morceaux.
	local rayon = math.max(card.size.X, card.size.Z) + 0.6
	local disque = Instance.new("Part")
	disque.Name = "DisqueCamp"
	disque:SetAttribute("Camp", team)
	disque.Anchored = true; disque.CanCollide = false; disque.CanQuery = false; disque.CastShadow = false
	disque.Shape = Enum.PartType.Cylinder
	disque.Size = Vector3.new(0.12, rayon, rayon)
	disque.Color = teamColor(team); disque.Material = Enum.Material.Neon; disque.Transparency = 0.25
	local basY = -(card.size.Y / 2) - flyY + 0.08
	disque:SetAttribute("Ecart", Vector3.new(0, basY, 0))
	disque:SetAttribute("Sol", true)
	disque:SetAttribute("RotX", 0); disque:SetAttribute("RotY", 0); disque:SetAttribute("RotZ", 90)
	disque.CFrame = part.CFrame * CFrame.new(0, basY, 0) * CFrame.Angles(0, 0, math.rad(90))
	disque.Parent = part
	local e = addEntity({
		part = part, team = team, isBuilding = Batiments.est(card), label = card.name,
		-- niveau de la carte pour le JOUEUR du camp (le robot reste niveau 1)
		maxHp = math.floor(card.hp * multNiveau(team, card.id)), dmg = math.floor(card.dmg * multNiveau(team, card.id)),
		range = card.range, atkSpeed = card.atkSpeed,
		speed = card.speed, targets = card.targets, flying = card.flying, splash = card.splash,
		active = true, lane = offset.X, enGroupe = enGroupe,
		-- ANIMATION : demarche propre a la carte (vol, bond, pas lourd, tireur) et instant de la
		-- pose, qui declenche l'arrivee du ciel dans `animer`.
		style = Effets.style(card), poseT = horloge,
		-- DUREE D'ARRIVEE : tant qu'elle n'est pas ecoulee, l'unite ne fait rien (Deploiement).
		dureeDeploiement = Deploiement.duree(card),
		-- encombrement au sol : sert a la separation (Foule). Une unite ne traverse plus ses voisines.
		rayonFoule = Foule.rayon(card),
		-- CHARGE : nil pour la plupart des cartes. Celles qui en ont une accumulent leur elan dans
		-- `chargeParcouru` pendant la marche, et le perdent des qu'on les arrete.
		chargeProfil = Charge.profil(card.id), chargeParcouru = 0,
		-- DISQUE D'ELAN : cree plus bas si la carte a une charge (Charge.aUneCharge).
		-- ASSASSIN : bonus de priorite contre les tireurs ennemis (nil pour presque toutes les
		-- cartes). Pose ici, lu par Cible.priorite : aucun chemin de ciblage separe.
		chasseTireurs = (Assassin.profil(card.id) or {}).bonus,
		-- PROFONDEUR : 0 pour une unite posee par un joueur, 1 pour une unite nee d'une mort.
		-- C'est la garde qui empeche une descendance en cascade (voir Descendance.autorisee).
		profondeur = 0,
		-- STATUTS : gel, ralentissement, poison vivent ici (module pur Statuts).
		statuts = {}, carte = card,
		-- BATIMENT POSE : il ne marche pas, et meurt tout seul au bout de sa duree de vie.
		estBatimentPose = Batiments.est(card),
	})
	-- CHAMPION : il devient LE champion de son camp ; son bouton de capacite apparait.
	if card.capacite and teams[team] then
		teams[team].champion = { e = e, capacite = card.capacite, derniere = nil }
		print("[CHAMPION] camp " .. team .. " pose " .. card.name)
	end
	-- BOUCLIER : il encaisse AVANT les points de vie et ne se regenere pas.
	if card.bouclier then
		Statuts.poserBouclier(e, math.floor(card.bouclier * multNiveau(team, card.id)))
		-- LA PROTECTION SE VOIT : coque doree qui MAIGRIT en encaissant (Statuts.opaciteBouclier
		-- et Statuts.epaisseurBouclier). Sans elle, le bouclier ne se signalait qu'a l'instant
		-- ou il cassait — trop tard pour decider d'y depenser un sort ou non.
		Effets.blinder(e.part, e.part.Size, Statuts.opaciteBouclier(e), Statuts.epaisseurBouclier(e))
	end
	-- USURE d'un batiment pose : ses points de vie sont etales sur sa duree de vie, si bien
	-- qu'il tient EXACTEMENT le temps annonce sur la carte meme si personne ne l'attaque.
	-- ELAN VISIBLE. Defaut mesure le 2026-09-20 : trois cartes prennent de l'ELAN en courant et
	-- frappent jusqu'a 2,5 fois plus fort — la regle est codee, testee (tools/test_charge.py) et
	-- appliquee par le serveur, mais RIEN ne la montre. Celui qui la lance ne sait pas si elle est
	-- prete ; celui d'en face ne voit pas la menace arriver, alors que la parade existe : bloquer
	-- l'unite lui vole sa charge. Une mecanique decisive, invisible des deux cotes.
	-- Un disque au sol grandit avec l'elan, puis s'allume en rouge quand la charge est LANCEE.
	if Charge.aUneCharge(card.id) then
		local d = Instance.new("Part")
		d.Name = "DisqueElan"
		d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CastShadow = false
		d.Shape = Enum.PartType.Cylinder
		d.Size = Vector3.new(0.12, 1, 1)
		d.Material = Enum.Material.Neon
		d.Color = Color3.fromRGB(255, 210, 120)
		d.Transparency = 1
		d.Parent = e.part
		e.disqueElan = d
	end
	-- PAS ENCORE OPERATIONNELLE : un anneau au sol se REFERME sur l'unite pendant son deploiement.
	-- La regle etait appliquee et expliquee, mais invisible : celui qui pose ne savait pas quand
	-- sa carte devient active, et celui d'en face ne voyait pas qu'il avait encore le temps de
	-- reagir. En GEOMETRIE (une etiquette flottante n'apparait sur aucune capture du moteur).
	if (e.dureeDeploiement or 0) > 0 then
		local a = Instance.new("Part")
		a.Name = "AnneauDeploiement"
		a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CastShadow = false
		a.Shape = Enum.PartType.Cylinder
		a.Size = Vector3.new(0.1, Deploiement.ANNEAU_LARGE, Deploiement.ANNEAU_LARGE)
		a.Material = Enum.Material.Neon
		-- Couleur posee par la regle des le premier rafraichissement (blanc = intouchable, or
		-- ensuite). Ni bleu ni rouge : un anneau de couleur de camp se confondait avec les unites
		-- (capture cap-deploiement.png du 2026-09-21).
		a.Color = Color3.fromRGB(Deploiement.COULEUR_INTOUCHABLE[1],
			Deploiement.COULEUR_INTOUCHABLE[2], Deploiement.COULEUR_INTOUCHABLE[3])
		a.Transparency = Deploiement.transparenceAnneau(0)
		a.CFrame = CFrame.new(e.part.Position.X, GROUND_Y + 0.12, e.part.Position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		a.Parent = e.part
		e.anneauDeploiement = a
	end
	if e.estBatimentPose then
		e.usure = Batiments.usure(card, e.maxHp)
		e.etatBatiment = { poseT = horloge }
		e.speed = 0
		-- COMBIEN DE TEMPS IL LUI RESTE. Defaut mesure le 2026-09-20 : un batiment pose tombe TOUT
		-- SEUL, et rien ne disait quand. Le joueur voyait une barre descendre sans savoir si c'est
		-- parce qu'on le frappe ou parce que le temps passe — donc sans pouvoir decider s'il vaut
		-- la peine de le defendre.
		-- Deux supports, parce qu'ils ne se voient pas dans les memes conditions : le CHIFFRE sur
		-- l'etiquette flottante (lisible en jeu), et un ANNEAU au sol en vraie geometrie (le seul
		-- verifiable sur capture, CaptureService ne rendant pas les BillboardGui).
		if e.etiquette then
			local reste = Instance.new("TextLabel")
			reste.Name = "ResteBatiment"
			reste.BackgroundTransparency = 1
			reste.Size = UDim2.new(1, 0, 0.45, 0)
			reste.Position = UDim2.new(0, 0, 0.12, 0)
			reste.TextXAlignment = Enum.TextXAlignment.Right
			reste.TextScaled = true
			reste.TextStrokeTransparency = 0
			reste.Font = Enum.Font.GothamBold
			reste.Text = Batiments.texteRestant(card, e.hp, e.maxHp)
			reste.Parent = e.etiquette
		end
		local rayon = math.max(e.part.Size.X, e.part.Size.Z) / 2 + 0.8
		e.rebours = {}
		for i, seg in ipairs(Apercu.segmentsAnneau(rayon, 16)) do
			local bout = Instance.new("Part")
			bout.Name = "ReboursBatiment"
			bout.Anchored = true; bout.CanCollide = false; bout.CanQuery = false
			bout.CastShadow = false
			bout.Size = Vector3.new(0.35, 0.16, seg.longueur)
			bout.CFrame = CFrame.new(e.part.Position.X + seg.x, GROUND_Y + 0.12, e.part.Position.Z + seg.z)
				* CFrame.Angles(0, math.rad(seg.angle), 0)
			bout.Material = Enum.Material.Neon
			bout.Color = Color3.fromRGB(120, 235, 150)
			bout.Parent = e.part
			e.rebours[i] = bout
		end
	end
	return e
end

local function flatDist(a, b)
	local d = a.part.Position - b.part.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

local function canHit(attacker, target)
	if attacker.targets == "buildings" and not target.isBuilding then
		return false
	end
	if target.flying and not attacker.isBuilding and attacker.range < 5 and not attacker.flying then
		return false
	end
	return true
end

-- CHOIX DE CIBLE. Deux regles, toutes deux dans le module pur `Cible` :
--  - MENACE : une TOUR vise d'abord ce qui la detruit (une unite anti-tours compte comme
--    Cible.BONUS_ANTI_TOUR studs plus proche). Une unite, elle, frappe ce qu'elle a devant.
--  - PERSISTANCE : on garde la cible en cours tant qu'aucune autre n'est franchement meilleure.
--    Sans cela, deux ennemis a distance quasi egale faisaient papillonner la tour, qui etalait
--    ses degats sans jamais achever personne.
local function findTarget(e)
	local best, bestD, bestP = nil, math.huge, math.huge
	local avantCible = e.cibleEnCours
	local sight = e.isBuilding and e.range or math.max(e.range, 10)
	local enCours, dEnCours = nil, nil
	for _, o in ipairs(entities) do
		if o.alive and o.team ~= e.team and canHit(e, o) then
			local d = flatDist(e, o)
			if d <= sight or o.isBuilding then
				local pr = Cible.priorite(e, o, d)
				if pr < bestP then
					best, bestD, bestP = o, d, pr
				end
				if o == e.cibleEnCours then
					enCours, dEnCours = o, d
				end
			end
		end
	end
	-- la cible en cours est toujours valable : on ne la lache que pour nettement mieux
	if enCours and Cible.garder(Cible.priorite(e, enCours, dEnCours), bestP) then
		best, bestD = enCours, dEnCours
	end
	-- ASSASSIN : on ne trace que le CHANGEMENT de cible, et seulement quand il va chercher un
	-- tireur — sinon le journal serait illisible (une ligne par image et par unite).
	if best ~= avantCible and (tonumber(e.chasseTireurs) or 0) > 0 and best
		and not best.isBuilding and (best.range or 0) >= Cible.PORTEE_TIREUR then
		print("[ASSASSIN]", e.label, "laisse la melee et vise", best.label,
			string.format("(portee %.1f, a %.1f studs)", best.range or 0, bestD or 0))
	end
	e.cibleEnCours = best
	return best, bestD
end

-- COMPTEURS DE COMBAT (envoyes dans l'etat) : le son se joue chez le client, qui ne voit pas les
-- attaques. Il compare ces compteurs a ceux du dernier etat recu et joue un son a chaque hausse.
local combat = { tirs = 0, coups = 0, zones = 0 }
-- LES MEMES COMPTEURS, PAR CAMP : le client peut alors jouer CE QUI M'ARRIVE autrement que ce qui
-- arrive en face. Le total ci-dessus reste envoye tel quel (rien de casse pour ce qui le lit).
local combatCamp = { { tirs = 0, coups = 0, zones = 0 }, { tirs = 0, coups = 0, zones = 0 } }
-- CHIFFRES DE DEGATS : au plus 25 par seconde pour tout le monde. Sans plafond, une melee en
-- produisait un par coup et par unite — illisible a l'ecran et couteux a repliquer.
local chiffrePermis = Effets.limiteurChiffres(25)

-- FIN DE PARTIE VUE DE CHAQUE CAMP.
-- Avant, `result` contenait la PHRASE du camp 1 (« VICTOIRE ! » / « DEFAITE... ») et `sendState`
-- l'envoyait telle quelle a tous les clients : a deux joueurs, le perdant lisait la victoire de
-- l'autre. On garde donc le NUMERO du vainqueur, et chaque client recoit la phrase de SON camp.
local vainqueur = nil -- 1, 2, ou 0 pour une egalite
-- PROLONGATION : ouverte quand le temps reglementaire finit sur une egalite de couronnes. La
-- premiere tour prise y termine la partie sur-le-champ ; sinon c'est la tour la plus entamee qui
-- decide. Une partie ne se finit donc presque plus sur un match nul.
local prolongation = false

-- PRONOSTICS DES SPECTATEURS : player -> camp choisi (1 rouge, 2 bleu), vide a chaque partie.
local pronostics = {}
-- GAIN DE FIN DE PARTIE par joueur (pieces, trophees, serie) : affiche sur l'ecran de fin.
local recompenses = {}
-- REVANCHE : en duel humain, « Rejouer » ne relance QUE si les deux l'ont demande. Sinon le
-- premier qui cliquait effacait l'ecran de fin de l'autre avant qu'il ait lu son resultat.
local revanche = {}
-- Par joueur : { t = instant de sa demande, refus = il a dit non }. Une SEULE table, le script
-- etant a la limite Luau des 200 variables locales. Sans `t`, l'attente n'avait aucune limite ;
-- sans `refus`, l'adversaire ne pouvait que partir pour dire non.
local revancheEtat = {}
-- REPRISE APRES COUPURE : camp -> jeton. Tant qu'un jeton vit, le camp reste RESERVE a son joueur :
-- ni robot ni adversaire ne le prennent, et sa partie l'attend telle quelle.
local reprises = {}
-- MODE A NIVEAUX EGALISES : arme par le duel prive (donnee de teleportation lue a l'arrivee). Il
-- vaut pour TOUTE la partie et pour LES DEUX camps, robot compris.
local modeEgalise = false

-- Niveaux a utiliser pour ce joueur : les siens, ou le niveau de reference si la partie est
-- egalisee. Un seul endroit, pour qu'aucun chemin (depart, arrivee en cours, robot) ne l'oublie.
local function niveauxDe(player)
	local niveaux = player and Economie.niveaux(player) or nil
	if not Egalise.actif(modeEgalise) then
		return niveaux
	end
	local ids = {}
	for _, c in ipairs(Cards.list) do
		table.insert(ids, c.id)
	end
	return Egalise.niveaux(niveaux, ids, true)
end
-- SIGNALEMENTS de la partie en cours : « auteur>cible » -> vrai. Un seul par adversaire et par
-- partie ; la table est videe a chaque nouvelle partie.
local signalements = {}
-- DERNIER ADVERSAIRE de chaque joueur : on peut encore le signaler sur l'ecran de fin, quand il
-- a deja quitte le serveur. Sans cette memoire, le seul moment pour signaler serait pendant le
-- duel — c'est-a-dire au pire moment, celui ou on joue.
local dernierAdversaire = {}
-- SPECTATEURS : quel camp chacun suit, et l'historique des mains de chaque camp. La main n'est
-- JAMAIS montree en direct (Spectateur.RETARD) : un complice pourrait la dicter a l'adversaire.
local suivi = {}
-- Qui a deja salue : on n'invite qu'une fois, et seulement face a un humain.
local saluts = {}
local historiqueMains = { {}, {} }
-- Un camp dont le joueur humain a saute reste « humain » pour le calcul des recompenses : sinon
-- l'adversaire perdait son bonus « contre un humain » a cause d'une coupure qu'il n'a pas choisie.
local humainAbsent = {}
-- Pure (testee hors Studio) : le client n'est pas cru, tout est reverifie ici.
-- Une partie vient-elle d'etre annulee ? L'instant est garde sur ReplicatedStorage (voir la boucle
-- de reprise) : il survit a resetMatch, qui remet toutes les tables de partie a zero.
local function annuleeRecente()
	local quand = ReplicatedStorage:GetAttribute("BRR_AnnuleeA")
	return quand ~= nil and (os.clock() - quand) < 8
end

local function pronosticAccepte(camp, aUnCamp, dejaPris, finie, ouverts)
	return (camp == 1 or camp == 2) and not aUnCamp and not dejaPris and not finie and ouverts == true
end

local function endMatch(winner)
	if result then
		return
	end
	vainqueur = winner or 0
	-- Serveur reserve pour CE match : il n'accueille pas de revanche, tout le monde rentre au hub.
	if Matchmaking.estServeurDeMatch(game) then
		task.delay(10, Matchmaking.retourHub)
	end
	if winner == 1 or winner == 2 then
		-- Feu d'artifice au-dessus du camp qui gagne (z du Roi : -28 pour le camp 1, +28 pour le 2).
		Effets.victoire(arena, Vector3.new(0, 0, winner == 1 and -(HALF_L - 4) or (HALF_L - 4)), teamColor(winner))
	end
	-- RECOMPENSES : chaque joueur ayant un camp gagne pieces et trophees selon SON issue.
	-- task.spawn : la verification du pass VIP interroge Roblox et ne doit pas bloquer la boucle.
	-- TROPHEES D'AVANT-MATCH, figes ICI : l'enjeu depend de ceux de l'adversaire, et les joueurs
	-- sont recompenses l'un APRES l'autre. Sans ce cliche, le second lirait les trophees du premier
	-- deja mis a jour — un enjeu different selon qui passe en premier.
	local entreAmis = false
	for _, j in pairs(occupant) do
		if j:GetAttribute("BRR_Prive") then
			entreAmis = true -- un seul suffit : les DEUX joueurs d'un duel prive portent la marque
		end
	end
	local tropheesAvant = {}
	for camp, joueur in pairs(occupant) do
		tropheesAvant[camp] = Economie.tropheesDe(joueur)
	end
	for camp, joueur in pairs(occupant) do
		local issue = (vainqueur == 0) and "egalite" or (vainqueur == camp and "victoire" or "defaite")
		local contreHumain = occupant[3 - camp] ~= nil or humainAbsent[3 - camp] == true
		-- UN DUEL EGALISE NE COMPTE PAS AU CLASSEMENT : melanger les deux fausserait les trophees,
		-- qui mesurent aussi l'inventaire. On le dit au joueur plutot que de le cacher.
		if not Duel.compteAuClassement(Egalise.actif(modeEgalise), entreAmis) then
			print("[BRR] duel hors classement (egalise ou entre amis) : aucune recompense pour " .. joueur.Name)
			continue
		end
		-- CE QUE LA PARTIE A RAPPORTE : jusqu'ici pieces et trophees etaient credites en silence,
		-- l'ecran de fin n'affichait qu'un mot. Le gain est garde ici et parti dans l'etat.
		task.spawn(function()
			-- Le nom de l'adversaire part avec la recompense : le journal doit dire CONTRE QUI,
			-- sinon toutes les lignes se ressemblent.
			local enFace = occupant[3 - camp]
			recompenses[joueur] = Economie.recompenser(joueur, issue, contreHumain,
				enFace and enFace.DisplayName or "Robot",
				-- ses trophees : l'enjeu en depend (battre plus fort rapporte plus)
				enFace and tropheesAvant[3 - camp] or nil)
		end)
		-- PARTIE MENEE A SON TERME : elle efface le plus ancien abandon. Sans ce pardon, la
		-- sanction ne ferait que s'empiler et un joueur revenu a de meilleures manieres ne
		-- pourrait jamais revenir a zero : on punirait un passe, pas un comportement.
		Economie.pardonnerAbandon(joueur)
		Economie.avancerQuete(joueur, "parties", 1)
		if issue == "victoire" then
			Economie.avancerQuete(joueur, "victoires", 1)
		end
	end
	-- Spectateurs qui avaient vu juste : quelques pieces (une egalite ne paie personne).
	for spectateur, camp in pairs(pronostics) do
		if vainqueur == camp and spectateur.Parent then
			task.spawn(Economie.gainPronostic, spectateur)
		end
	end
	if winner == 1 then
		result = "VICTOIRE !"
	elseif winner == 2 then
		result = "DEFAITE..."
	else
		result = "EGALITE"
	end
end

local function texteFin(camp)
	if vainqueur == nil then
		return nil
	elseif vainqueur == 0 then
		return "EGALITE"
	elseif camp == 0 then
		-- Spectateur : on annonce QUI a gagne, sans « victoire » ni « defaite ».
		return "CAMP " .. vainqueur .. " GAGNE"
	elseif vainqueur == camp then
		return "VICTOIRE !"
	end
	return "DEFAITE..."
end

-- Proportion de points de vie de la tour la plus ENTAMEE encore debout (0 a 1). Sert a trancher
-- une prolongation ou personne n'a pris de tour : le camp le plus abime perd.
local function pvBasTour(team)
	local bas = 1
	for _, tw in ipairs(teams[team].towers) do
		if tw.alive then
			bas = math.min(bas, tw.hp / tw.maxHp)
		end
	end
	return bas
end

local function crowns(team)
	-- couronnes gagnees par `team` = tours ennemies detruites
	local n = 0
	for _, t in ipairs(teams[3 - team].towers) do
		if not t.alive then
			if t.isKing then
				return 3
			end
			n = n + 1
		end
	end
	return n
end

local function damage(target, amount)
	if not target.alive then
		return
	end
	-- GRACE A LA POSE : pendant la fraction de seconde ou l'unite tombe du ciel, elle ne peut
	-- pas etre effacee. Sans elle, un sort lance PILE sur la zone de pose la tuait avant
	-- qu'elle touche le sol, et le joueur ne voyait jamais ce qu'il venait de payer.
	if Statuts.invulnerable(target, horloge) then
		return
	end
	-- TERRAIN : se battre chez soi, a portee d'une tour encore debout, fait encaisser moins. La
	-- reduction s'applique AVANT le bouclier, comme une armure : elle protege aussi le bouclier.
	amount = Terrain.degatsSubis(amount, target.reductionTerrain)
	-- BOUCLIER : il absorbe le coup AVANT les points de vie (Statuts.encaisser).
	local surPV, reste, casse = Statuts.encaisser(target, amount)
	if casse then
		Effets.impact(arena, target.part.Position, Color3.fromRGB(235, 225, 140))
		Effets.debloquer(target.part) -- la coque a cede : elle disparait avec l'eclat
	elseif reste > 0 then
		-- elle tient encore : on la fait MAIGRIR au lieu de la reconstruire, sinon elle
		-- clignoterait a chaque coup.
		Effets.majBouclier(target.part, Statuts.opaciteBouclier(target), Statuts.epaisseurBouclier(target))
	end
	amount = surPV
	if amount <= 0 then
		target.coupT = horloge
		Effets.coup(target.part)
		return -- tout est parti dans le bouclier
	end
	target.hp = target.hp - amount
	-- TOUR EN DANGER : on empile les coups recents, pour distinguer une tour BASSE d'une tour qui
	-- encaisse MAINTENANT. La liste est nettoyee a chaque lecture (Lecture.degatsRecents).
	if target.isBuilding and not target.estBatimentPose then
		target.coups = target.coups or {}
		table.insert(target.coups, { t = horloge, montant = amount })
		-- BILAN : une tour de depart n'encaisse que des coups de l'autre camp (son usure ne touche
		-- que les batiments POSES). On attribue donc la pression au camp d'en face.
		local auteur = teams[3 - target.team]
		if auteur then
			local compte = math.min(amount, math.max(0, target.hp + amount))
			Bilan.degatsTour(auteur.bilan, compte)
			if ReplicatedStorage:FindFirstChild("BRR_DUEL") then
				print(string.format("[DUEL] degats_tour : camp%d marque %.0f sur %s du camp%d (pv %.0f)",
					3 - target.team, compte, target.label, target.team, math.max(0, target.hp)))
			end
		end
	end
	target.coupT = horloge
	-- COMBIEN a fait ce coup : le chiffre monte au-dessus de la cible, a la couleur du camp qui
	-- encaisse. Plafonne (chiffrePermis) pour ne pas noyer l'ecran en melee.
	if amount > 0 and chiffrePermis(os.clock()) then
		Effets.chiffreDegats(arena, target.part.Position, amount, teamColor(target.team))
	end
	if target.hp > 0 then
		Effets.coup(target.part)
	end
	if target.isKing then
		target.active = true
	end
	if target.hp <= 0 then
		target.alive = false
		-- TUTORIEL : deux etapes se terminent sur un FAIT de jeu, pas au chronometre.
		-- « tourTombee » : une tour ADVERSE s'ecroule. « volantAbattu » : une unite volante du
		-- camp d'en face est abattue. C'est ici que passent toutes les morts, donc c'est le seul
		-- endroit ou ces deux faits peuvent etre vus sans les deduire.
		if tuto.actif and target.team ~= tuto.camp then
			local etapeEnCours = tutoEtape()
			local fin = etapeEnCours and etapeEnCours.finQuand
			-- Une TOUR est un batiment SANS carte d'origine (les batiments poses par une carte en
			-- ont une) ; le VOL est porte directement par l'entite (`flying`, copie de la carte).
			local estTour = target.isBuilding == true and target.carte == nil
			if fin == "tourTombee" and estTour then
				tuto.conditionFaite = true
				print("[TUTO] tour adverse tombee : etape terminee par le joueur")
			elseif fin == "volantAbattu" and target.flying == true then
				tuto.conditionFaite = true
				print("[TUTO] volant abattu : etape terminee par le joueur")
			end
		end
		local ou = target.part.Position
		-- EXPLOSION A LA MORT : certaines cartes (Bomba Salsiccia) partent en emportant ce qui
		-- les entoure. La regle est dans Statuts.explosionMort ; ici on l'applique et on la dessine.
		local carteMorte = target.carte
		if carteMorte and carteMorte.mort then
			local objets, refs = {}, {}
			for _, o in ipairs(entities) do
				if o.alive then
					table.insert(objets, { camp = o.team, x = o.part.Position.X, z = o.part.Position.Z })
					table.insert(refs, o)
				end
			end
			local touches, degatsMort = Statuts.explosionMort(carteMorte, objets, target.team, ou.X, ou.Z)
			Effets.tourDetruite(arena, ou, carteMorte.color or teamColor(target.team))
			for _, i in ipairs(touches) do
				damage(refs[i], math.floor(degatsMort * multNiveau(target.team, carteMorte.id)))
			end
		end
		-- DESCENDANCE : certaines grosses cartes laissent des petites unites derriere elles. Abattre
		-- le colosse ne suffit donc pas : il reste du travail. La garde de profondeur fait qu'une
		-- fille ne pond jamais a son tour.
		if carteMorte and not target.isBuilding then
			local ne = Descendance.aLaMort(carteMorte.id, target.profondeur, ou.X, ou.Z)
			if ne then
				local carteFille = Cards.byId[ne.fille]
				if carteFille then
					for _, pt in ipairs(ne.positions) do
						local bebe = spawnUnit(carteFille, target.team,
							Vector3.new(pt.x, ou.Y, pt.z), Vector3.new(), false)
						if bebe then
							bebe.profondeur = ne.profondeur
						end
					end
					Effets.pose(arena, ou, teamColor(target.team))
					print("[DESCENDANCE]", carteMorte.name, "laisse", ne.nombre, carteFille.name)
				end
			end
		end
		if target.isBuilding then
			Effets.tourDetruite(arena, ou, teamColor(target.team))
			-- une TOUR (pas un simple batiment pose) rapporte une couronne au camp adverse
			if table.find(teams[target.team].towers, target) then
				-- CAMP GAGNANT en attribut : le client fait voler SA couronne depuis la BONNE tour, meme quand
				-- deux couronnes tombent ensemble (capture du 2026-09-21 : les deux partaient de ma tour)
				local couronne3d = Effets.couronne(arena, ou, teamColor(3 - target.team))
				if couronne3d then
					couronne3d:SetAttribute("Camp", 3 - target.team)
				end
			end
			target.part:Destroy()
		else
			Effets.mort(arena, ou, teamColor(target.team))
			-- l'unite bascule et s'efface au lieu de disparaitre d'un coup ; elle est deja hors
			-- du combat (alive = false), donc rien ne change cote regles. Elle sort de l'arene
			-- TOUT DE SUITE : c'est cette sortie que le client entend comme une mort.
			if target.etiquette then
				target.etiquette:Destroy() -- sinon un nom et une barre vide flottent sur le cadavre
			end
			target.part.Parent = dossierRestes()
			Effets.agonie(target.part)
		end
		if target.fill then
			target.hp = 0
			majBarre(target)
		end
		-- UNE TOUR DU DEPART, pas un batiment POSE : un canon ou un collecteur detruit ne doit ni
		-- compter dans la quete « tours », ni reveiller la tour du roi, ni — surtout — terminer la
		-- partie en prolongation, ou la premiere TOUR prise fait la mort subite.
		if target.isBuilding and not target.estBatimentPose then
			local vainqueurTour = occupant[3 - target.team]
			if vainqueurTour then
				Economie.avancerQuete(vainqueurTour, "tours", 1)
			end
			for _, t in ipairs(teams[target.team].towers) do
				if t.isKing then
					t.active = true
				end
			end
			-- DERNIERE GARDE : annoncee UNE SEULE FOIS par camp, au moment ou elle s'engage.
			-- Sans cette trace, la regle serait invisible dans les journaux et impossible a
			-- prouver en moteur.
			if not gardeAnnoncee[target.team] and Garde.engagee(etatTours(target.team)) then
				gardeAnnoncee[target.team] = true
				print(string.format("[GARDE] camp %d : derniere garde, le Roi tire x%.2f plus vite",
					target.team, Garde.FACTEUR))
			end
			if target.isKing then
				endMatch(3 - target.team)
			elseif prolongation then
				-- MORT SUBITE : en prolongation, la premiere tour prise termine la partie.
				endMatch(3 - target.team)
			end
		end
	elseif target.fill then
		majBarre(target)
	end
end

-- TIRS EN VOL. Un tir n'est plus un dessin pose APRES coup : c'est un objet qui met du temps a
-- arriver (module pur Projectiles). Deux consequences visibles : une unite rapide peut sortir de
-- la trajectoire, et les degats tombent quand la boule touche — plus jamais avant.
local tirs = {}
-- JOURNAL DES TIRS : combien sont partis, combien sont arrives, et le temps de vol cumule. Un
-- instantane de `#tirs` ne prouve rien (il depend de l'image ou l'on regarde) ; ces compteurs,
-- eux, disent si les degats mettent VRAIMENT du temps a arriver. Lus par le scenario de test.
local journalTirs = { partis = 0, arrives = 0, volCumule = 0 }

-- STATUTS PORTES PAR UN COUP : ralentissement de la Regina, poison du Serpente. La regle de cumul
-- (on prolonge, on n'empile pas) est dans Statuts.appliquer.
local function appliquerEffets(carte, cible)
	local eff = carte and carte.effet
	if not eff or not cible or not cible.alive then
		return
	end
	if eff.lent then
		-- LE RALENTISSEMENT SE VOIT : halo bleu pale, retire des que le statut expire. Sans lui,
		-- une unite ralentie avait l'air de ramer a cause du reseau, pas d'une carte adverse.
		Statuts.appliquer(cible, "lent", eff.lent, horloge)
		Effets.impact(arena, cible.part.Position, Color3.fromRGB(150, 220, 255))
		Effets.engourdir(cible.part, cible.part.Size)
	end
	if eff.poison then
		Statuts.appliquer(cible, "poison", eff.poison, horloge)
		-- LE POISON SE VOIT : bulle verte qui degouline. Avant, l'unite perdait des points de
		-- vie sans cause visible et le joueur cherchait un tireur qui n'existait pas.
		Effets.empoisonner(cible.part, cible.part.Size)
	end
end

-- IMPACT : ce qui se passe a l'ARRIVEE du coup (que le tir ait vole ou non).
-- RECUL : projette une cible frappee, sans jamais la sortir de l'arene et sans jamais la
-- verrouiller (une cible repoussee en boucle ne pourrait plus agir du tout).
local function repousser(e, cible)
	local profil = Recul.profil(e.carte and e.carte.id)
	if not profil or not cible or not cible.alive then
		return
	end
	if not Recul.permis(cible.reculT and (horloge - cible.reculT) or nil, profil.periode) then
		return
	end
	local d = Recul.distance(profil, { batiment = cible.isBuilding, pvMax = cible.maxHp })
	if d <= 0 then
		return
	end
	local p, q = e.part.Position, cible.part.Position
	local dx, dz = Recul.vecteur(p.X, p.Z, q.X, q.Z, d)
	if dx == 0 and dz == 0 then
		return
	end
	cible.reculT = horloge
	local nx = math.clamp(q.X + dx, -HALF_W + 1, HALF_W - 1)
	local nz = math.clamp(q.Z + dz, -HALF_L + 1, HALF_L - 1)
	-- LA RIVIERE : une unite au sol ne se fait jamais projeter dans l'eau, ni de l'autre cote —
	-- ce serait un passage gratuit. Elle est retenue sur sa berge. Un volant survole, lui.
	if not cible.flying and not Recul.surPont(nx, BRIDGES, Regles.LARGEUR_PONT / 2) then
		nz = Recul.corrigeRiviere(nz, q.Z, Regles.DEMI_RIVIERE)
	end
	cible.part.CFrame = CFrame.new(nx, q.Y, nz) * (cible.part.CFrame - q)
	-- Un recul est un SAUT, pas une course : sans cette remise a jour, la vitesse mesuree a
	-- l'image suivante serait enorme et les tireurs viseraient tres loin devant une unite qui,
	-- en realite, n'a pas avance d'elle-meme (Visee).
	cible.posPrecX, cible.posPrecZ = nx, nz
	cible.vitesseX, cible.vitesseZ = 0, 0
	-- une unite projetee perd son elan de charge : elle ne court plus, elle recule.
	if cible.chargeProfil then
		cible.chargeParcouru, cible.chargeLancee = 0, false
	end
	print("[RECUL]", e.label, "projette", cible.label, string.format("%.1f", d), "studs")
end

local function impact(e, target, centre, degats)
	if e.splash then
		for _, o in ipairs(entities) do
			if o.alive and o.team ~= e.team then
				local d = o.part.Position - centre
				if Vector3.new(d.X, 0, d.Z).Magnitude <= e.splash then
					damage(o, degats)
					appliquerEffets(e.carte, o)
					repousser(e, o)
				end
			end
		end
	elseif target and target.alive then
		damage(target, degats)
		appliquerEffets(e.carte, target)
		repousser(e, target)
	end
	Effets.impact(arena, centre, teamColor(e.team))
end

local function attack(e, target)
	e.attaqueT = horloge
	-- COMPOSITION DES BONUS, en un seul endroit et sous un plafond COMMUN (Frappe.PLAFOND) :
	--  * SOUTIEN    : l'aura majore le coup qui PART, et seulement celui-la. Rien n'est stocke sur
	--                 l'unite — si le tambour meurt entre deux coups, le suivant est deja normal ;
	--  * SPECIALITE : depend de CE QU'ON FRAPPE (volant, essaim), donc se calcule cible par cible ;
	--  * CHARGE     : l'elan, seulement pour le premier coup et jamais sur une frappe de zone.
	-- Sans plafond commun, ces trois regles se multipliaient jusqu'a x11,25 en theorie.
	local specialite = Specialite.multiplicateur(e.carte and e.carte.id,
		{ flying = target.flying, count = target.carte and target.carte.count, isBuilding = target.isBuilding })
	local elan = 1
	if not e.splash and e.chargeProfil and e.chargeLancee then
		elan = e.chargeProfil.multiplicateur
	end
	local total, plafonne = Frappe.composer({ e.bonusDegats or 1, specialite, elan })
	local degats = Frappe.degats(e.dmg, total)
	if total > 1 then
		print("[FRAPPE]", e.label, "contre", target.label,
			string.format("aura x%.2f specialite x%.2f elan x%.2f -> x%.2f%s : %d -> %d",
				e.bonusDegats or 1, specialite, elan, total, plafonne and " (PLAFONNE)" or "",
				e.dmg, degats))
	end
	local mien = combatCamp[e.team]
	if e.splash then
		combat.zones = combat.zones + 1
		mien.zones = mien.zones + 1
	elseif e.range >= 3 or e.isBuilding then
		combat.tirs = combat.tirs + 1
		mien.tirs = mien.tirs + 1
	else
		combat.coups = combat.coups + 1
		mien.coups = mien.coups + 1
	end
	-- Un TIREUR envoie un projectile : ses degats n'arrivent qu'avec lui. Une melee frappe au
	-- contact, immediatement — y faire voler quelque chose ne ferait que retarder le corps a corps.
	if e.range >= 3 or e.isBuilding then
		local depart, ou = e.part.Position, target.part.Position
		local duree = Projectiles.duree(e.carte, (ou - depart).Magnitude)
		-- ANTICIPATION : la cible aura bouge quand le tir arrivera. On vise donc devant elle, avec
		-- une part propre a la carte — jamais 1 pour tout le monde, sinon l'esquive n'existerait
		-- plus et les unites rapides perdraient tout interet.
		local vx, vz = target.vitesseX or 0, target.vitesseZ or 0
		local px, pz = Visee.point(ou.X, ou.Z, vx, vz, duree,
			Visee.part(e.carte and e.carte.id, e.isBuilding))
		local arrivee = Vector3.new(px, ou.Y, pz)
		Effets.projectile(arena, depart, arrivee, teamColor(e.team), e.splash ~= nil)
		table.insert(tirs, {
			tireur = e, cible = target, visee = arrivee, depart = depart,
			degats = degats, t0 = horloge, duree = duree,
		})
		if duree > 0 and (arrivee - ou).Magnitude > 0.5 then
			journalTirs.anticipes = (journalTirs.anticipes or 0) + 1
		end
		journalTirs.partis = journalTirs.partis + 1
	else
		impact(e, target, target.part.Position, degats)
	end
	if e.chargeProfil then
		e.chargeParcouru, e.chargeLancee = 0, false
	end
end

-- Fait avancer les tirs et applique ceux qui ARRIVENT. Un tir simple dont la cible s'est deplacee
-- de plus de Projectiles.MARGE_ESQUIVE studs est PERDU : c'est l'esquive.
local function majTirs()
	local restants = {}
	for _, p in ipairs(tirs) do
		if Projectiles.arrive(horloge - p.t0, p.duree) then
			journalTirs.arrives = journalTirs.arrives + 1
			journalTirs.volCumule = journalTirs.volCumule + p.duree
			local vivant = p.cible and p.cible.alive
			if p.tireur.splash then
				impact(p.tireur, nil, p.visee, p.degats)
			elseif vivant then
				local d = p.cible.part.Position - p.visee
				if Vector3.new(d.X, 0, d.Z).Magnitude <= Projectiles.MARGE_ESQUIVE then
					impact(p.tireur, p.cible, p.cible.part.Position, p.degats)
				end
			end
		else
			table.insert(restants, p)
		end
	end
	tirs = restants
end

local function moveUnit(e, target, dt)
	-- Une unite IMMOBILE (vitesse 0) ne se retourne pas : sinon elle pivotait vers le pont le plus
	-- proche sans avancer, et la rangee de test montrait les modeles de profil (capture 2026-09-14).
	if e.speed <= 0 then
		return
	end
	local pos = e.part.Position
	local goal = target.part.Position
	-- Couloir : une unite de groupe garde son ecart lateral pendant la marche (sinon les 3
	-- Chimpanzini convergeaient vers la meme cible et leurs etiquettes se recouvraient).
	local lane = e.lane or 0
	if not e.flying and sideOf(pos.Z) ~= sideOf(goal.Z) then
		-- FRANCHIR LA RIVIERE. L'ancien calcul visait le point d'entree du pont SUR SA PROPRE
		-- RIVE quand l'unite etait mal alignee : arrivee dessus, la distance au but tombait a
		-- zero et l'unite se figeait (4 blocages mesures a z = -4 sur une serie de 6 parties).
		-- Traversee garantit que le point vise n'est jamais la position courante.
		local gx, gz = Traversee.point(pos.X, pos.Z, BRIDGES, lane)
		goal = Vector3.new(gx, pos.Y, gz)
	elseif lane ~= 0 and flatDist(e, target) > e.range + 6 then
		goal = Vector3.new(math.clamp(goal.X + lane, -HALF_W + 1, HALF_W - 1), goal.Y, goal.Z)
	end
	local delta = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = delta.Magnitude
	if dist < 0.01 then
		return
	end
	-- RAGE : un sort de rage accelere la marche pendant sa duree, puis tout revient net.
	local rage = Sorts.multiplicateurRage(e.rageSort, e.rageT and (horloge - e.rageT) or nil)
	-- GEL et RALENTISSEMENT : le gel met la vitesse a zero, le froid la divise (Statuts).
	rage = Statuts.facteurVitesse(e, horloge, rage)
	if rage <= 0 then
		return -- gelee : elle ne marche plus du tout
	end
	-- FOULE : gênée par ses voisines, l'unite ralentit au lieu de les traverser. C'est ce qui
	-- fait qu'un mur d'unites RETIENT vraiment une poussee adverse.
	-- CHARGE : lancee, l'unite accelere. Le calcul se fait sur l'elan DEJA acquis, donc
	-- l'acceleration arrive apres la course, jamais avant.
	local vitesse = e.speed
	if e.chargeProfil then
		e.chargeLancee = Charge.lancee(e.chargeParcouru, e.chargeProfil)
		vitesse = Charge.vitesse(vitesse, e.chargeProfil, e.chargeLancee)
	end
	local step = math.min(dist, vitesse * rage * (e.freinFoule or 1) * dt)
	if e.chargeProfil then
		-- L'elan compte le pas REELLEMENT parcouru : une unite freinee par la foule ou bloquee par
		-- un mur ne charge pas, elle pietine.
		local avant = e.chargeLancee
		e.chargeParcouru = Charge.maj(e.chargeParcouru, step)
		e.chargeLancee = Charge.lancee(e.chargeParcouru, e.chargeProfil)
		if e.chargeLancee and not avant then
			print("[CHARGE]", e.label, "lancee apres", math.floor(e.chargeParcouru), "studs, coup a",
				Charge.degats(e.dmg, e.chargeProfil, true), "au lieu de", e.dmg)
		end
		-- L'ELAN SE VOIT : le disque grandit avec l'avancement, puis vire au ROUGE une fois la
		-- charge lancee. C'est le signal que l'adversaire attend pour bloquer l'unite.
		if e.disqueElan then
			local part = Charge.avancement(e.chargeParcouru, e.chargeProfil)
			local large = 2.5 + 4 * part
			e.disqueElan.Size = Vector3.new(0.12, large, large)
			e.disqueElan.CFrame = CFrame.new(e.part.Position.X, GROUND_Y + 0.14, e.part.Position.Z)
				* CFrame.Angles(0, 0, math.rad(90))
			e.disqueElan.Transparency = e.chargeLancee and 0.25 or (1 - part * 0.6)
			e.disqueElan.Color = e.chargeLancee and Color3.fromRGB(255, 90, 70)
				or Color3.fromRGB(255, 210, 120)
		end
	end
	local newPos = pos + delta.Unit * step
	e.part.CFrame = CFrame.lookAt(newPos, newPos + delta.Unit)
	e.bouge = true -- `animer` replace les morceaux, avec la pose de marche
end

-- ANIMATION PROCEDURALE : les pieces sont ancrees (pas de physique, pas d'Animator), on calcule
-- donc la pose a chaque image : rebond + dandinement en marche, elan a l'attaque, recul au coup.
-- L'ANNEAU DE DEPLOIEMENT se referme sur l'unite, puis disparait a l'instant ou elle devient
-- active. Mis a jour ICI, dans l'animation appelee a CHAQUE image pour CHAQUE unite, et non dans
-- le deplacement : une unite en cours de deploiement ne bouge pas encore, son anneau serait reste
-- fige puis oublie sur le terrain.
local function majAnneauDeploiement(e)
	if not e.anneauDeploiement then
		return
	end
	local avance = Deploiement.avancement(horloge - (e.poseT or 0), e.dureeDeploiement)
	if avance >= 1 then
		e.anneauDeploiement:Destroy()
		e.anneauDeploiement = nil
		return
	end
	local d = Deploiement.diametreAnneau(avance)
	e.anneauDeploiement.Size = Vector3.new(0.1, d, d)
	e.anneauDeploiement.CFrame = CFrame.new(e.part.Position.X, GROUND_Y + 0.12, e.part.Position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	e.anneauDeploiement.Transparency = Deploiement.transparenceAnneau(avance)
	-- BLANC tant que l'unite est INTOUCHABLE (Statuts.INVULN_POSE), OR ensuite : le meme anneau
	-- raconte les deux temps de la pose. Sans cela, la protection restait invisible et un sort
	-- lance pile sur la pose paraissait « rate ».
	local c = Deploiement.couleurAnneau(horloge - (e.poseT or 0), Statuts.INVULN_POSE)
	e.anneauDeploiement.Color = Color3.fromRGB(c[1], c[2], c[3])
end

local function animer(e, dt)
	local cible = e.bouge and 1 or 0
	e.bouge = false
	e.marche = (e.marche or 0) + (cible - (e.marche or 0)) * math.min(1, dt * 10)
	e.phase = (e.phase or 0) + dt * (5 + e.speed * 1.5) * Effets.cadence(e.style)
	local haut, roulis, avant, tangage, lacet = Effets.posture(e.marche, e.phase,
		horloge - (e.attaqueT or -99), horloge - (e.coupT or -99), e.style)
	-- ARRIVEE : pendant la demi-seconde qui suit la pose, l'unite tombe du ciel et rebondit.
	local hautArrivee, tangageArrivee = Effets.apparition(horloge - (e.poseT or -99))
	haut = haut + hautArrivee
	tangage = tangage + tangageArrivee
	local repos = e.marche < 0.01 and avant == 0 and tangage == 0 and haut == 0 and lacet == 0
	if repos and e.auRepos and cible == 0 then
		return -- rien ne bouge : inutile de replacer les morceaux
	end
	e.auRepos = repos
	suivreCorps(e.part, CFrame.new(0, haut, -avant) * CFrame.Angles(tangage, lacet, roulis))
end

-- `permises` : cartes debloquees du joueur (nil = toutes, pour le robot). Avec moins de 8 cartes,
-- la file est completee en repetant le paquet : la main et la file ne sont jamais vides.
-- `permises` : cartes debloquees du joueur (nil = toutes, pour le robot). Le paquet est monte par
-- le module pur Cycle : SANS DOUBLON tant qu'il y a de quoi (jusqu'ici, un joueur a moins de 8
-- cartes voyait la meme carte occuper deux cases de sa main, et son cycle n'avait plus de sens).
local function newDeck(permises)
	local ids = {}
	if permises then
		for _, id in ipairs(permises) do
			table.insert(ids, id)
		end
	else
		for _, c in ipairs(Cards.list) do
			table.insert(ids, c.id)
		end
	end
	return Cycle.distribuer(ids, function(n)
		return math.random(1, n)
	end)
end

-- Groupe (ex. 3 Chimpanzini) : triangle espace. Alignes a 2,5 studs, leurs etiquettes de 90 px
-- se recouvraient (capture 3D du 2026-09-14). Le 2e avance d'un rang vers l'ennemi.
local function offsetGroupe(i, n, team)
	if n <= 1 then
		return Vector3.new(0, 0, 0)
	end
	local x = (i - (n + 1) / 2) * 6
	local avance = (i % 2 == 0) and 5 or 0
	return Vector3.new(x, 0, team == 1 and avance or -avance)
end

-- UNE etiquette par groupe (ex. « Chimpanzini ×3 ») avec une barre de vie empilee par membre.
-- Trois etiquettes separees se recouvraient des que le trio attaquait la meme cible (capture
-- 3D du 2026-09-14). L'etiquette vit sur un ancre invisible qui suit le centre des survivants.
local groupes = {}
local compteurGroupes = 0
local function spawnGroupe(card, team, pos)
	local membres = {}
	local enGroupe = card.count > 1
	for i = 1, card.count do
		table.insert(membres, spawnUnit(card, team, pos, offsetGroupe(i, card.count, team), enGroupe))
	end
	if not enGroupe then
		return membres
	end
	local ancre = makePart({
		Name = "Groupe" .. card.id, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1,
		CanCollide = false, CanQuery = false, Position = membres[1].part.Position,
	})
	-- Identifiant de groupe en ATTRIBUT sur l'ancre et sur chaque membre, pour que le client sache
	-- qu'un groupe est dans la zone d'une tour des qu'UN membre y entre. (Des liens ObjectValue
	-- avaient d'abord ete accuses de la vue blanche des captures ; la vraie cause etait la premiere
	-- lecture perimee de la fenetre hors ecran, corrigee dans hors-ecran-capture.ps1 le 2026-09-14.)
	compteurGroupes = compteurGroupes + 1
	local idGroupe = "g" .. compteurGroupes
	ancre:SetAttribute("Groupe", idGroupe)
	for _, m in ipairs(membres) do
		m.part:SetAttribute("Groupe", idGroupe)
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 110, 0, 18 + card.count * 8)
	gui.StudsOffset = Vector3.new(0, card.size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = ancre
	local nomCourt = string.match(card.name, "^(%S+)") or card.name
	local titre = Instance.new("TextLabel")
	titre.BackgroundTransparency = 1
	titre.Size = UDim2.new(1, 0, 0, 16)
	titre.TextScaled = true
	titre.TextColor3 = Color3.new(1, 1, 1)
	titre.TextStrokeTransparency = 0
	titre.Font = Enum.Font.GothamBold
	titre.Parent = gui
	for i, m in ipairs(membres) do
		local fond = Instance.new("Frame")
		fond.Size = UDim2.new(1, 0, 0, 6)
		fond.Position = UDim2.new(0, 0, 0, 18 + (i - 1) * 8)
		fond.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		fond.BorderSizePixel = 0
		fond.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BackgroundColor3 = teamColor(team)
		fill.BorderSizePixel = 0
		fill.Parent = fond
		m.fill = fill
	end
	table.insert(groupes, {
		ancre = ancre, membres = membres, titre = titre, nom = nomCourt,
		etiquette = gui, hauteurBase = gui.StudsOffset.Y,
	})
	return membres
end

local function majGroupes()
	local restants = {}
	for _, g in ipairs(groupes) do
		local somme, vivants = Vector3.new(0, 0, 0), 0
		for _, m in ipairs(g.membres) do
			if m.alive then
				somme = somme + m.part.Position
				vivants = vivants + 1
			end
		end
		if vivants == 0 or not g.ancre.Parent then
			g.ancre:Destroy()
		else
			-- N'ecrire que ce qui CHANGE (economie de replication). Ce n'etait PAS la cause de la vue
			-- blanche des captures, un temps soupconnee : premiere lecture perimee de la fenetre hors
			-- ecran, corrigee dans hors-ecran-capture.ps1 le 2026-09-14.
			local centre = somme / vivants
			if (g.ancre.Position - centre).Magnitude > 0.1 then
				g.ancre.Position = centre
			end
			local texte = g.nom .. " ×" .. vivants
			if g.titre.Text ~= texte then
				g.titre.Text = texte
			end
			table.insert(restants, g)
		end
	end
	groupes = restants
end

-- Etagement des etiquettes : fait COTE CLIENT (GameClient), qui connait la vraie position a l'ecran.

-- LANCER UN SORT : aucune unite posee. On collecte les cibles (Sorts.cibles), on applique les
-- degats (moins fort sur les tours) ou la rage, et on dessine l'explosion. Le cout en elixir et
-- le cycle de cartes sont geres par tryPlay, comme pour une unite.
-- LANCER UN SORT : aucune unite posee. On collecte les cibles (Sorts.cibles), on applique l'effet
-- — degats, rage, GEL, POISON, SOIN, recul — puis on dessine. Le cout en elixir et le cycle de
-- cartes restent geres par tryPlay, comme pour une unite.
local function lancerSort(card, team, pos)
	local sort = card.sort
	-- MESURE (series de simulation) : degats de sort ENVOYES par ce camp, avant bouclier et
	-- reduction de terrain. Sert a voir quelle part du combat les sorts font a haut niveau.
	if teams[team] then
		local brut = (sort.degats or 0) * multNiveau(team, card.id, true)
		teams[team].degatsSorts = (teams[team].degatsSorts or 0) + brut
	end
	-- objets a plat : le module pur ne connait ni Roblox ni nos entites
	local objets, refs = {}, {}
	for _, e in ipairs(entities) do
		if e.alive then
			table.insert(objets, {
				camp = e.team, x = e.part.Position.X, z = e.part.Position.Z,
				batiment = e.isBuilding, vole = e.flying == true, pv = e.hp,
			})
			table.insert(refs, e)
		end
	end
	local touches = Sorts.cibles(objets, team, pos.X, pos.Z, sort.rayon, sort.effet)
	-- TRONC QUI ROULE : il ne touche QUE le sol, un volant lui passe au-dessus.
	if sort.solSeulement then
		touches = Sorts.auSol(objets, touches)
	end
	-- FOUDRE : elle ne nettoie pas la zone, elle tombe sur les cibles les plus SOLIDES.
	if sort.cibles then
		touches = Sorts.plusSolides(objets, touches, sort.cibles)
	end
	if sort.effet == "rage" then
		for _, i in ipairs(touches) do
			refs[i].rageT = horloge -- `animer` et le combat lisent cet instant
			refs[i].rageSort = sort
		end
	elseif sort.effet == "gel" then
		-- GEL : tout s'arrete dans la zone — la marche comme les coups (Statuts.peutAgir).
		for _, i in ipairs(touches) do
			local cible = refs[i]
			if not cible.isBuilding or not cible.isKing then
				Statuts.appliquer(cible, "gel", { duree = sort.duree }, horloge)
				-- LE GEL SE VOIT : gangue de glace posee sur le corps, retiree quand le statut expire
				-- (majStatuts). Sans elle, une unite gelee etait a l'ecran identique a une unite libre.
				Effets.givrer(cible.part, cible.part.Size)
			end
			if (sort.degats or 0) > 0 then
				damage(cible, Sorts.degats(sort, cible.isBuilding, multNiveau(team, card.id, true)))
			end
			Effets.impact(arena, cible.part.Position, sort.couleur or card.color)
		end
		combat.zones = combat.zones + 1
	elseif sort.effet == "poison" then
		-- FLAQUE : elle ronge dans la DUREE. C'est la reponse aux batiments et aux gros tas, la ou
		-- un sort instantane ne fait qu'entamer.
		for _, i in ipairs(touches) do
			-- Le NIVEAU s'applique aussi au poison : c'est un sort de degats, etale dans le temps.
			Statuts.appliquer(refs[i], "poison",
				{ duree = sort.duree, degats = math.floor((sort.parTic or 0) * multNiveau(team, card.id, true) + 0.5),
					tic = sort.tic }, horloge)
			Effets.empoisonner(refs[i].part, refs[i].part.Size)
		end
		combat.zones = combat.zones + 1
	elseif sort.effet == "soin" then
		-- SOIN : jamais au-dela des PV maximaux, jamais sur un mort (Statuts.soigner).
		for _, i in ipairs(touches) do
			local cible = refs[i]
			local gagne = Statuts.soigner(cible, math.floor((sort.soin or 0) * multNiveau(team, card.id)))
			if gagne > 0 and cible.fill then
				majBarre(cible)
			end
			Effets.impact(arena, cible.part.Position, sort.couleur or card.color)
		end
	else
		for _, i in ipairs(touches) do
			local cible = refs[i]
			damage(cible, Sorts.degats(sort, cible.isBuilding, multNiveau(team, card.id, true)))
			-- RECUL : le tronc repousse ce qu'il touche hors de son elan. Une tour ne bouge pas.
			local dx, dz = Sorts.recul(sort, objets[i], pos.X, pos.Z)
			if (dx ~= 0 or dz ~= 0) and cible.alive then
				local q = cible.part.Position
				local nx = math.clamp(q.X + dx, -HALF_W + 1, HALF_W - 1)
				local nz = math.clamp(q.Z + dz, -HALF_L + 1, HALF_L - 1)
				if not cible.flying and not Recul.surPont(nx, BRIDGES, Regles.LARGEUR_PONT / 2) then
					nz = Recul.corrigeRiviere(nz, q.Z, Regles.DEMI_RIVIERE)
				end
				cible.part.CFrame = CFrame.new(nx, q.Y, nz) * (cible.part.CFrame - q)
				-- meme raison que pour le recul d'une unite : un saut n'est pas une course.
				cible.posPrecX, cible.posPrecZ = nx, nz
				cible.vitesseX, cible.vitesseZ = 0, 0
			end
		end
		combat.zones = combat.zones + 1
	end
	-- Rendu : anneau de pose a la couleur du sort, plus une gerbe au centre.
	local couleur = sort.couleur or card.color
	Effets.pose(arena, pos, couleur)
	if sort.effet == "rage" or sort.effet == "soin" then
		Effets.impact(arena, pos + Vector3.new(0, 2, 0), couleur)
	else
		Effets.tourDetruite(arena, pos + Vector3.new(0, 1, 0), couleur)
	end
	print("[BRR] sort", team, card.id, "cibles=" .. #touches)
end

local function tryPlay(team, handIndex, pos)
	if result then
		return false, "partie terminee"
	end
	if geleDepart then
		return false, "la partie n'a pas encore commence"
	end
	local t = teams[team]
	local id = t.hand[handIndex]
	local card = id and Cards.byId[id]
	if not card then
		return false, "carte absente"
	end
	if t.elixir < card.cost then
		return false, "pas assez d'elixir"
	end
	-- TUTORIEL : une seule carte est jouable par etape (les autres sont grisees cote client).
	-- Le serveur refuse quand meme les autres : le client ne decide rien.
	if tuto.actif and team == tuto.camp and not Tutoriel.carteJouable(tuto.index, card.id) then
		return false, "pas cette carte pendant le tutoriel"
	end
	-- ZONE DE POSE : sa propre moitie, PLUS la moitie adverse du cote d'une tour ennemie tombee
	-- (Regles.posePermise). Casser une tour donne desormais un avantage de terrain, pas seulement
	-- une couronne.
	local z = pos.Z
	local ok = math.abs(pos.X) <= HALF_W - 1 and math.abs(z) <= HALF_L - 1
	local gauche, droite = false, false
	for _, tw in ipairs(teams[3 - team].towers) do
		if not tw.isKing and not tw.alive then
			if tw.part.Position.X < 0 then
				gauche = true
			else
				droite = true
			end
		end
	end
	if card.sort then
		-- Un SORT vise toute l'arene (c'est sa raison d'etre) : seuls les bords le limitent.
		ok = Sorts.cibleValide(pos.X, z, HALF_W, HALF_L)
	elseif card.poseLibre then
		-- MINEUR : il CREUSE. Sa carte dit explicitement qu'il sort n'importe ou, y compris
		-- derriere les tours adverses : c'est toute sa raison d'etre, et le seul moyen d'aller
		-- chercher un collecteur pose au fond du camp d'en face.
		ok = ok
	elseif Batiments.est(card) then
		-- BATIMENT : dans sa moitie seulement, jamais sur la bande de la riviere (il boucherait
		-- le pont), et jamais colle a un autre batiment (Batiments.posePermise).
		local autres = {}
		for _, o in ipairs(entities) do
			if o.alive and o.estBatimentPose and o.team == team then
				table.insert(autres, { x = o.part.Position.X, z = o.part.Position.Z })
			end
		end
		ok = ok and Batiments.posePermise(team, pos.X, z, autres)
	else
		ok = ok and Regles.posePermise(team, pos.X, z, gauche, droite)
	end
	if not ok then
		return false, Batiments.est(card) and "batiment : dans ta moitie, loin de la riviere et d'un autre batiment"
			or "hors de ta zone de pose"
	end
	t.elixir = t.elixir - card.cost
	if tuto.actif and team == tuto.camp then
		tuto.poseFaite = true
	end
	if card.sort then
		lancerSort(card, team, pos)
	else
		Effets.pose(arena, pos, teamColor(team))
		spawnGroupe(card, team, pos)
	end
	-- CE QUE L'ADVERSAIRE A VU : cout depense et carte posee. Deux faits OBSERVABLES, qui servent
	-- a estimer son elixir et a montrer son cycle (module Lecture). Rien n'est lu dans son
	-- compteur reel : c'est une estimation, pas une fenetre ouverte sur son ecran.
	t.depenseVue = (t.depenseVue or 0) + card.cost
	t.dernierePose = horloge -- horloge de JEU : le gel du coup d'envoi ne compte pas comme inactivite
	Bilan.jouer(t.bilan, card.cost)
	t.jouees = t.jouees or {}
	table.insert(t.jouees, { id = card.id, t = horloge })
	-- CYCLE : la carte jouee repart en FOND de file, la tete de file prend sa place.
	Cycle.jouer(t.hand, t.queue, handIndex)
	-- DERNIERE CARTE JOUEE : le client affiche dans combien de cartes elle revient (Cycle.retour).
	t.derniereJouee = card.id
	-- QUETES DU JOUR : chaque carte posee (et chaque sort lance) fait avancer celles qui portent
	-- dessus. Le joueur d'en face n'a pas de profil quand c'est le robot : occupant peut etre nil.
	local joueur = occupant[team]
	if joueur then
		Economie.avancerQuete(joueur, "cartes", 1)
		if card.sort then
			Economie.avancerQuete(joueur, "sorts", 1)
		end
	end
	return true
end

local function resetMatch()
	entities = {}
	groupes = {}
	ancresEmote = {} -- l'arene est reconstruite : les anciennes ancres partent avec elle
	result = nil
	vainqueur = nil
	prolongation = false
	-- NIVEAUX EGALISES : c'est une propriete de la PARTIE, et elle n'etait JAMAIS eteinte. Une
	-- seule arrivee depuis un duel prive egalise suffisait donc a egaliser toutes les parties
	-- suivantes du serveur — et comme un duel egalise ne compte pas au classement, plus personne
	-- ne gagnait de trophee ensuite. On la recalcule depuis les joueurs REELLEMENT presents.
	modeEgalise = false
	for camp = 1, 2 do
		if occupant[camp] and occupant[camp]:GetAttribute("BRR_Egalise") then
			modeEgalise = true
		end
	end
	pronostics = {}
	revanche = {}
	-- Il n'etait vide que sur le chemin de la revanche, alors que DOUZE chemins menent ici
	-- (expiration d'une coupure, double deconnexion, fin de tutoriel, demarrage...). Un refus
	-- survivait donc a la partie suivante : l'autre lisait « ton adversaire ne veut pas de
	-- revanche » sur une partie ou il n'avait encore rien demande.
	revancheEtat = {}
	recompenses = {}
	reprises = {}
	humainAbsent = {}
	signalements = {}
	gardeAnnoncee = {}
	historiqueMains = { {}, {} }
	finCompteARebours = nil
	timeLeft = MATCH_TIME
	tutoFiniPour = nil -- une nouvelle partie n'est plus la fin d'un tutoriel
	-- DECOR DU DUEL : tire une fois ici, donc identique pour les deux joueurs, et jamais le meme
	-- que la partie precedente (sinon la variation ne se voit pas).
	-- BRR_DECOR (copie de test) : force un theme, pour capturer chaque decor et comparer leur
	-- geometrie. Le jeu livre, lui, tire au hasard sans jamais repeter le precedent.
	local force = ReplicatedStorage:FindFirstChild("BRR_DECOR")
	if force and Decor.parId(force.Value) then
		themeArene = Decor.parId(force.Value)
	else
		grainesDecor = Decor.graineSuivante(grainesDecor + math.random(1, Decor.nombre()), themeArene.id)
		themeArene = Decor.choisir(grainesDecor)
	end
	print("[BRR] arene : " .. themeArene.nom)
	buildArena()
	for team = 1, 2 do
		local s = team == 1 and -1 or 1
		-- Le robot ne sort plus les cartes PAYANTES qu'un joueur neuf n'a pas : son paquet est
		-- celui du joueur d'en face, sinon les seules cartes offertes (Economie.cartesRobot).
		local permises = occupant[team] and Economie.deck(occupant[team])
			or Economie.cartesRobot(occupant[3 - team] and Economie.cartesPossedees(occupant[3 - team]))
		local hand, queue = newDeck(permises)
		local niveaux = niveauxDe(occupant[team])
		-- BRR_PARTIE (capture d'une partie normale) : 10 d'elixir au depart, sinon a 25 s de jeu
		-- -- limite du client de test -- le terrain ne portait que 3 unites (mesure 2026-09-14).
		teams[team] = { elixir = ReplicatedStorage:FindFirstChild("BRR_PARTIE") and MAX_ELIXIR or 5, hand = hand, queue = queue, towers = {}, botTimer = 2, niveaux = niveaux,
			-- lecture du duel : elixir de depart, regeneration cumulee et depense VUE
			elixirDepart = ReplicatedStorage:FindFirstChild("BRR_PARTIE") and MAX_ELIXIR or 5,
			regenCumulee = 0, depenseVue = 0, jouees = {}, bilan = Bilan.neuf(),
			-- INACTIVITE : instant de la derniere carte posee, et debut de CETTE partie. Les deux
			-- sur `horloge`, qui est MONOTONE depuis le demarrage du serveur et ne se remet jamais
			-- a zero (elle date aussi les poses, les statuts, les projectiles). Comparer le silence
			-- a 0 revenait donc a compter depuis le demarrage du SERVEUR : des la deuxieme partie,
			-- le silence valait deja des centaines de secondes et la partie s'arretait pour
			-- « inactivite » au bout de 21 s, alors que les deux joueurs jouaient.
			dernierePose = nil,
			debutJeu = horloge,
			-- robot REACTIF par defaut ; le journal [BOT] doit dire la verite sur qui joue.
			botVersion = "nouveau" }
		table.insert(teams[team].towers, spawnTower(team, -VOIE_X, s * (HALF_L - 10), false))
		table.insert(teams[team].towers, spawnTower(team, VOIE_X, s * (HALF_L - 10), false))
		table.insert(teams[team].towers, spawnTower(team, 0, s * (HALF_L - 4), true))
		apparence.appliquerSkin(team)
	end
	majNiveauxRobot()
end

-- Journal des decisions du robot : une ligne [BOT] par tour de reflexion, pour lire POURQUOI il
-- joue (ou passe), pas seulement la carte jouee. Format stable, lisible par un script.
local function journalBot(team, action, cardId, cout, elixir, raison, x, z)
	print(string.format("[BOT] camp=%d version=%s action=%s carte=%s cout=%d elixir=%.1f raison=%s pos=%s",
		team, tostring(teams[team].botVersion or "nouveau"), action, tostring(cardId), cout or 0,
		elixir or 0, raison, x and string.format("%.0f,%.0f", x, z) or "-"))
end

-- Robot d'origine (joue au hasard). Garde tel quel : il sert d'adversaire de reference a la
-- simulation « nouveau contre ancien » (--sim="v:8").
local function botThinkAncien(team, dt)
	local t = teams[team]
	t.botTimer = t.botTimer - dt
	if t.botTimer > 0 then
		return
	end
	-- MELEE (build.py --melee, copie de test) : rafale toutes les 0,4 s, elixir toujours plein, pose
	-- pres de la riviere -- pour capturer un terrain charge avant la limite des 25 s du client de test.
	local melee = ReplicatedStorage:FindFirstChild("BRR_MELEE") ~= nil
	t.botTimer = melee and 0.4 or (1.5 + math.random() * 2.5)
	if melee then
		t.elixir = MAX_ELIXIR
	end
	local idx = math.random(1, 4)
	local card = Cards.byId[t.hand[idx]]
	if card and t.elixir >= card.cost then
		local x = BRIDGES[math.random(1, 2)] + math.random(-3, 3)
		local z = melee and math.random(4, 9) or math.random(6, 20)
		if team == 1 then
			z = -z
		end
		local elixirAvant = t.elixir
		if tryPlay(team, idx, Vector3.new(x, 0, z)) then
			print("[BRR] joue", team, card.id)
			journalBot(team, "joue", card.id, card.cost, elixirAvant, "hasard", x, z)
		else
			journalBot(team, "refus", card.id, card.cost, elixirAvant, "pose_refusee", x, z)
		end
	else
		journalBot(team, "passe", card and card.id or "?", card and card.cost or 0, t.elixir,
			card and "trop_cher" or "carte_absente")
	end
end

-- Robot reactif : (1) ne choisit que parmi les cartes JOUABLES ; (2) defend la voie ou l'ennemi
-- entre dans sa moitie ; (3) sinon garde son elixir, et n'attaque (voie de la tour ennemie la plus
-- faible) que lorsque l'elixir approche du plafond, pour ne pas le perdre. Aucune triche : il ne
-- lit que l'etat du serveur, sans elixir en plus.
local function botThinkNouveau(team, dt)
	local t = teams[team]
	t.botTimer = t.botTimer - dt
	if t.botTimer > 0 then
		return
	end
	local melee = ReplicatedStorage:FindFirstChild("BRR_MELEE") ~= nil
	-- Le temps de reflexion vient du PROFIL : un robot de debutant reagit en ~3 s, un expert en
	-- ~1 s. Sans profil (cas de test), on garde l'ancienne cadence.
	local profil = t.profilRobot
	t.botTimer = melee and 0.4 or (profil and Robot.delai(profil, math.random()) or (1.5 + math.random() * 2.5))
	if melee then
		t.elixir = MAX_ELIXIR
	end
	local s = team == 1 and -1 or 1 -- signe de z de sa propre moitie
	-- (2) menace : PV des unites ennemies deja dans sa moitie, par voie (x < 0 -> voie 1)
	local menace = { 0, 0 }
	-- DEFENSEURS DEJA ENGAGES, par voie : ses unites dans SA moitie. Comptees dans la meme
	-- unite que la menace (points de vie) pour que la comparaison soit honnete.
	local engages = { 0, 0 }
	local menaceVolante = false
	-- Ce que le robot VOIT chez l'adversaire, sous la forme attendue par Reponse : c'est la meme
	-- boucle, on ne la parcourt pas deux fois.
	local objetsVus = {}
	for _, e in ipairs(entities) do
		if e.alive ~= false and not e.isBuilding and e.team ~= team and e.part and (e.hp or 0) > 0 then
			local p = e.part.Position
			if p.Z * s > 0 then
				local voie = p.X < 0 and 1 or 2
				menace[voie] += e.hp
				if e.flying then
					menaceVolante = true
				end
				table.insert(objetsVus, { camp = e.team, pv = e.hp, volant = e.flying == true,
					enGroupe = e.enGroupe == true, portee = e.range or 0, batiment = false })
			end
		elseif e.alive ~= false and not e.isBuilding and e.team == team and e.part and (e.hp or 0) > 0 then
			-- SES PROPRES unites : elles ne sont pas une menace, mais un soutien n'a de sens que
			-- s'il y a quelqu'un a renforcer (Reponse compte les allies).
			-- Et une unite a lui dans sa moitie DEFEND deja : elle compte contre la menace.
			local pa = e.part.Position
			if pa.Z * s > 0 then
				local voie = pa.X < 0 and 1 or 2
				engages[voie] += e.hp
			end
			table.insert(objetsVus, { camp = team, pv = e.hp, volant = e.flying == true,
				enGroupe = e.enGroupe == true, portee = e.range or 0, batiment = false })
		end
	end
	-- A egalite (y compris zero contre zero), on departage au hasard : `menace[1] >= menace[2]`
	-- rendait TOUJOURS la voie 1, et le robot posait donc toujours ses defenses du meme cote.
	local voieMenace = Voie.menacee(menace[1], menace[2], math.random())
	local enDanger = menace[voieMenace] > 0
	-- MEMOIRE DE DEFENSE. Une attaque repoussee, c'est : une menace reelle dans sa moitie a la
	-- reflexion precedente, plus rien maintenant, et des unites a lui encore debout. C'est LE
	-- moment ou l'adversaire n'a plus d'elixir — le robot le punit au lieu de retourner en garde.
	local menaceTotale = menace[1] + menace[2]
	local survivants = 0
	for _, e in ipairs(entities) do
		if e.alive and not e.isBuilding and e.team == team and e.part and e.part.Position.Z * s > 0 then
			survivants += 1
		end
	end
	if (t.menacePrecedente or 0) > 0 and menaceTotale == 0 then
		t.defenseT = horloge
		t.menaceRepoussee = t.menacePrecedente
		t.voieDefendue = t.voieMenacePrecedente or voieMenace
		t.survivantsDefense = survivants
	end
	t.menacePrecedente = menaceTotale
	if enDanger then
		t.voieMenacePrecedente = voieMenace
	end
	-- (1) QUELLE CARTE CONTRE QUOI. Avant, le robot prenait « la plus chere qu'il peut payer » avec
	-- un seul filtre anti-volant : il ignorait donc tout ce que le jeu sait faire depuis (anti-air,
	-- anti-groupe, assassins, auras), et il vidait son elixir sur une grosse carte sans rapport
	-- avec la menace. La note vit dans Reponse (module pur) ; ici on ne fait que decrire la main.
	local vue = Reponse.menace(objetsVus, team, Cible.PORTEE_TIREUR)
	local enAttaque = not enDanger
	local mains = {}
	for i = 1, 4 do
		local c = Cards.byId[t.hand[i]]
		if c and t.elixir >= c.cost then
			local specialite = Specialite.profil(c.id)
			table.insert(mains, { index = i, traits = {
				peutViserVolant = Regles.peutViserVolant(c),
				antiAir = specialite ~= nil and specialite.contre == "air",
				antiGroupe = specialite ~= nil and specialite.contre == "groupe",
				assassin = Assassin.estAssassin(c.id),
				soutien = Soutien.estSoutien(c.id),
				-- Un SORT n'a ni PV ni degats d'unite : sans ces deux lignes il serait note a zero
				-- et le robot ne le jouerait plus jamais. Sa valeur, c'est sa zone et ses degats.
				zone = (c.splash or 0) > 0 or (c.sort ~= nil and (c.sort.degats or 0) > 0),
				cout = c.cost,
				-- consistance, ramenee a une petite echelle : elle ne doit que departager.
				corps = c.sort and ((c.sort.degats or 0) * 3 / 400)
					or (((c.hp or 0) + (c.dmg or 0) * 3) / 400),
			} })
		end
	end
	-- ANTICIPATION : seul un robot au-dela du palier debutant tient compte de la menace. Un
	-- debutant, lui, joue sans regarder ce qui arrive — c'est ce qui rend sa premiere partie
	-- gagnable, et c'est deja le sens du palier.
	-- ecrit en if/else : `a and vue or {}` est le piege Lua deja rencontre dans Regles.posePermise
	-- (il rend `{}` des que `vue` serait faux), et il n'a rien a faire dans une decision de jeu.
	local vuePrise
	if not profil or profil.anticipe then
		vuePrise = vue
	else
		vuePrise = {}
	end
	local meilleur = Reponse.choisir(mains, vuePrise, enAttaque)
	local meilleurCout = meilleur and Cards.byId[t.hand[meilleur]].cost or -1
	-- ERREUR DE DEBUTANT : de temps en temps, il pose une carte au hasard parmi celles qu'il peut
	-- payer, au lieu de la meilleure. C'est ce qui rend une premiere partie gagnable.
	if meilleur and profil and Robot.seTrompe(profil, math.random()) then
		local jouables = {}
		for i = 1, 4 do
			local c = Cards.byId[t.hand[i]]
			if c and t.elixir >= c.cost then
				table.insert(jouables, i)
			end
		end
		if #jouables > 0 then
			meilleur = jouables[math.random(1, #jouables)]
			meilleurCout = Cards.byId[t.hand[meilleur]].cost
		end
	end
	if not meilleur then
		journalBot(team, "passe", "-", 0, t.elixir, enDanger and "menace_sans_carte" or "aucune_jouable")
		return
	end
	local card = Cards.byId[t.hand[meilleur]]
	local voie, z, raison
	-- FENETRE D'ATTAQUE : l'adversaire peut-il repondre ? Le robot part de la MEME estimation que
	-- celle montree au joueur (Lecture.elixirEstime, construite sur le temps ecoule et les cartes
	-- vues), jamais du compteur reel d'en face — il ne triche pas. Il l'entache ensuite d'une
	-- erreur d'autant plus grande que son palier lit mal : un normal ne regarde pas, un aguerri se
	-- trompe de deux elixir, un expert lit juste. Fenetre ouverte : il engage plus tot.
	local precisionLecture = (profil and profil.lecture) or 0
	-- Deux etages, et c'est voulu : l'estimation HONNETE, la meme que celle affichee au joueur
	-- (Lecture.elixirEstime), puis l'erreur propre au palier (Fenetre.estimation). Le compteur
	-- reel de l'adversaire n'est JAMAIS lu : le robot n'a pas le droit de tricher. Calcul fait ici
	-- et non dans une fonction du fichier : celui-ci est a la limite des 200 variables de Luau.
	local adv = teams[3 - team]
	local vueAdverse = adv and Fenetre.estimation(
		Lecture.elixirEstime(adv.elixirDepart or 5, adv.regenCumulee or 0, adv.depenseVue or 0),
		precisionLecture, math.random()) or 10
	local fenetreOuverte = Fenetre.ouverte(vueAdverse, precisionLecture, Fenetre.COUT_REPONSE)
	local seuilAttaque = Fenetre.seuilEffectif(
		(profil and Robot.gardeAttaque(profil, Robot.enOuverture(MATCH_TIME - timeLeft, MATCH_TIME)))
			or (MAX_ELIXIR - 3),
		fenetreOuverte, precisionLecture)
	-- CONTRE-ATTAQUE : juste apres avoir repousse une vraie attaque, on relance dans la voie qu'on
	-- vient de defendre, avec les survivants pour accompagner.
	local contre = not enDanger and Robot.contreAttaque(profil, {
		menaceRepoussee = t.menaceRepoussee or 0,
		survivants = t.survivantsDefense or 0,
		depuisDefense = t.defenseT and (horloge - t.defenseT) or nil,
		elixir = t.elixir,
		cout = card.cost,
	})
	if contre then
		voie = t.voieDefendue or voieMenace
		z = math.random(10, 16)
		raison = "contre_attaque_voie" .. voie
		t.defenseT = nil -- une seule relance par defense
	-- SUR-DEFENSE CORRIGEE. Avant : `elseif enDanger then`, donc une pose a CHAQUE cycle tant
	-- que l'unite ennemie vivait. Mesure (60 parties) : l'expert, qui reflechit deux fois plus
	-- vite, faisait 9 defenses par attaque contre 3,8 au normal, et ne gagnait plus que 40 %.
	-- On ne defend plus une menace que ses unites deja engagees tiennent.
	elseif enDanger and Defense.doitRepondre(menace[voieMenace], engages[voieMenace]) then
		voie, z, raison = voieMenace, math.random(8, 12), "defense_voie" .. voieMenace
	elseif melee or t.elixir >= seuilAttaque then
		-- fix-ok: seuil 9 jamais atteint (sim-v20.log : elixir en garde <= 7,9, 0 attaque) -> 7
		-- (3) elixir haut : attaquer la voie de la tour ennemie (non-roi) la plus faible
		-- TOUR LA PLUS FAIBLE. La comparaison etait STRICTE (`tw.hp < pvMin`) : au debut de partie
		-- les deux tours ont exactement les memes PV, donc la premiere de la liste gagnait
		-- toujours — et les deux robots attaquaient le meme cote toute la partie (mesure : 123
		-- defenses voie 1 contre 10 voie 2). Voie.tourLaPlusFaible departage les egalites.
		local tours = {}
		for _, tw in ipairs(teams[3 - team].towers) do
			table.insert(tours, { x = tw.part.Position.X, pv = tw.hp,
				vivante = tw.alive == true, roi = tw.isKing == true })
		end
		-- RESERVE DEFENSIVE. Mesure du 2026-09-20 (60 parties) : 1352 fois, le robot est menace
		-- sans pouvoir payer la moindre carte — elixir median 1,9. Ce n'est pas un bug, c'est
		-- qu'il vient de tout depenser en attaquant. Il n'engage donc une poussee que s'il lui
		-- reste de quoi parer la riposte. La DEFENSE et la CONTRE-ATTAQUE, decidees plus haut,
		-- ne passent jamais par ici : repondre a une menace deja la prime sur toute reserve.
		if not melee and not Reserve.attaquePermise(t.elixir, card.cost, Reserve.pour(profil)) then
			journalBot(team, "passe", card.id, card.cost, t.elixir,
				string.format("reserve_defense_attend_%d",
					math.ceil(Reserve.seuil(card.cost, Reserve.pour(profil)))))
			return
		end
		voie = Voie.tourLaPlusFaible(tours, math.random()) or math.random(1, 2)
		z = melee and math.random(4, 9) or math.random(14, 20)
		-- la raison distingue l'attaque ordinaire de celle declenchee par la LECTURE de
		-- l'adversaire : sans cela la competence serait invisible dans les journaux.
		raison = fenetreOuverte and "attaque_fenetre" or "attaque_tour_faible" -- fenetre : l'adversaire ne peut pas repondre
	else
		-- en danger mais la menace est deja couverte : on le dit, sinon la regle serait invisible
		journalBot(team, "passe", card.id, card.cost, t.elixir,
			enDanger and "defense_couverte" or "garde_elixir")
		return
	end
	local x = BRIDGES[voie] + math.random(-2, 2)
	z = z * s
	-- ERREUR DE PLACEMENT : la faute la plus courante d'un debutant n'est pas de choisir la
	-- mauvaise carte, c'est de la poser au mauvais endroit. L'ecart depend du palier (0 pour un
	-- expert). On garde la pose DANS sa moitie : sinon la carte serait refusee et le robot
	-- perdrait son tour sans rien depenser, ce qui n'est pas une erreur, c'est une panne.
	if profil then
		local dx, dz = Robot.deviation(profil, math.random(), math.random())
		x = math.clamp(x + dx, -HALF_W + 2, HALF_W - 2)
		z = z + dz
		if z * s < 4 then
			z = 4 * s -- jamais au-dela de sa propre moitie
		end
	end
	-- UN SORT NE SE POSE PAS COMME UNE UNITE : le robot le lache sur le CENTRE du paquet ennemi
	-- le plus fourni (il vise donc la ou ca paie), sinon sur la tour qu'il attaque.
	if card.sort then
		local sx, sz, n = 0, 0, 0
		for _, e in ipairs(entities) do
			if e.alive and not e.isBuilding and e.team ~= team then
				sx, sz, n = sx + e.part.Position.X, sz + e.part.Position.Z, n + 1
			end
		end
		if n > 0 and card.sort.effet ~= "rage" then
			x, z = sx / n, sz / n
		elseif card.sort.effet == "rage" then
			-- rage : sur SES propres unites les plus avancees
			local rx, rz, m = 0, 0, 0
			for _, e in ipairs(entities) do
				if e.alive and not e.isBuilding and e.team == team then
					rx, rz, m = rx + e.part.Position.X, rz + e.part.Position.Z, m + 1
				end
			end
			if m == 0 then
				journalBot(team, "passe", card.id, card.cost, t.elixir, "rage_sans_unite")
				return
			end
			x, z = rx / m, rz / m
		end
	end
	-- UN SORT DE SOIN se lache sur SES unites, comme la rage : sur le paquet ennemi il ne
	-- ferait rien du tout, et le robot aurait depense sa carte pour rien.
	if card.sort and card.sort.effet == "soin" then
		local rx, rz, m = 0, 0, 0
		for _, e in ipairs(entities) do
			if e.alive and not e.isBuilding and e.team == team and (e.hp or 0) < (e.maxHp or 0) then
				rx, rz, m = rx + e.part.Position.X, rz + e.part.Position.Z, m + 1
			end
		end
		if m == 0 then
			journalBot(team, "passe", card.id, card.cost, t.elixir, "soin_sans_blesse")
			return
		end
		x, z = rx / m, rz / m
	end
	-- UN BATIMENT ne se pose ni comme une unite ni comme un sort : il tient une voie DERRIERE
	-- la ligne, loin de la riviere, et JAMAIS colle a un autre batiment allie.
	-- Mesure du 2026-09-20 : sans cette derniere condition, le robot reproposait le meme point et
	-- se faisait refuser 31 fois dans une seule partie — 10 % de ses decisions perdues, et la
	-- carte restait coincee dans sa main. On cherche donc une place REELLEMENT libre, en donnant
	-- a Emplacement la regle du jeu elle-meme (aucune regle recopiee, aucune divergence possible).
	if Batiments.est(card) then
		local autres = {}
		for _, o in ipairs(entities) do
			if o.alive and o.estBatimentPose and o.team == team then
				table.insert(autres, { x = o.part.Position.X, z = o.part.Position.Z })
			end
		end
		local function permise(px, pz)
			return Batiments.posePermise(team, px, pz, autres)
		end
		local voieX = (voie == 1 or (x or 0) < 0) and -VOIE_X or VOIE_X
		if card.batiment.type == "collecteur" then
			voieX = 0 -- le collecteur se met a l'abri, au centre et au fond
		end
		local bx, bz = Emplacement.pourBatiment(voieX, s, HALF_W - 2, permise)
		if not bx then
			-- aucune place libre : on PASSE au lieu d'insister sur une pose que le jeu refusera.
			journalBot(team, "passe", card.id, card.cost, t.elixir, "batiment_sans_place")
			return
		end
		x, z = bx, bz
	end
	local elixirAvant = t.elixir
	if tryPlay(team, meilleur, Vector3.new(x, 0, z)) then
		print("[BRR] joue", team, card.id)
		journalBot(team, "joue", card.id, card.cost, elixirAvant, raison, x, z)
	else
		journalBot(team, "refus", card.id, card.cost, elixirAvant, "pose_refusee", x, z)
	end
end

-- Chaque camp porte sa version de robot (t.botVersion). Par defaut le REACTIF : mesure du
-- 2026-09-18, deux series independantes de 20 parties (sim-v20.log, sim-v20-seuil7.log), il bat
-- l'aleatoire 16 fois sur 20. L'aleatoire ne sert plus que de temoin dans la simulation « v:N ».
local function botThink(team, dt)
	-- TUTORIEL : le robot reste immobile tant que le joueur n'a pas compris la pose et l'elixir
	-- (Tutoriel.ROBOT_SILENCE). Ensuite il joue normalement : aucune regle n'est changee.
	if tuto.actif and team ~= tuto.camp and horloge < Tutoriel.ROBOT_SILENCE then
		return
	end
	if teams[team].botVersion ~= "ancien" then
		botThinkNouveau(team, dt)
	else
		botThinkAncien(team, dt)
	end
end

-- Mode test sans joueur (Studio > Run) : deux bots s'affrontent, rapport dans la sortie
local autoTest = false
local reportTimer = 0
local reported = false
local function report()
	local towers = {}
	for team = 1, 2 do
		for _, tw in ipairs(teams[team].towers) do
			table.insert(towers, string.format("%d%s=%d", team, tw.isKing and "R" or "T", tw.alive and math.floor(tw.hp) or 0))
		end
	end
	local units, stuck = 0, 0
	for _, e in ipairs(entities) do
		if not e.isBuilding then
			units = units + 1
			local p = e.part.Position
			-- Les unites VOLONTAIREMENT immobiles (trio de test, vitesse mise a zero) ne sont pas des
			-- unites bloquees. Mesure du 2026-09-14 : les 19 alertes « bloquees » d'une partie
			-- venaient toutes de ce trio, et m'ont fait croire a un defaut des ponts qui n'existe pas.
			if e.speed > 0 and e.lastPos and (p - e.lastPos).Magnitude < 0.5 and e.cooldown < -1 then
				stuck = stuck + 1
				print("[BRR] BLOQUE", e.label, math.floor(p.X), math.floor(p.Z))
			end
			e.lastPos = p
		end
	end
	print(string.format("[BRR] t=%d unites=%d bloquees=%d tours=%s resultat=%s", math.floor(timeLeft), units, stuck, table.concat(towers, " "), tostring(result)))
end
task.delay(3, function()
	if #Players:GetPlayers() == 0 then
		autoTest = true
		print("[BRR] mode test auto : bot contre bot")
	end
end)

-- DEUX JOUEURS POUR DE VRAI.
-- Avant, tout etait cable sur l'equipe 1 : le premier arrivant jouait le camp 1, le camp 2 etait
-- TOUJOURS le bot (`botThink(2, dt)` en dur), et l'etat envoye a chaque client etait celui de
-- l'equipe 1 — deux joueurs connectes auraient vu et joue la MEME main.
-- Desormais : le premier arrivant prend le camp 1, le second le camp 2, et le bot ne joue QUE le
-- camp encore vide. Un joueur qui part libere son camp, que le bot reprend.

local function attribuerCamp(player)
	for camp = 1, 2 do
		if occupant[camp] == nil then
			occupant[camp] = player
			equipeDe[player] = camp
			print("[BRR] " .. player.Name .. " prend le camp " .. camp)
			local cos = Economie.cosmetiques(player)
			apparence.skinCamp[camp] = cos and cos.skin or apparence.Cosmetiques.DEFAUT
			apparence.appliquerSkin(camp)
			print("[COSMETIQUE] camp " .. camp .. " : skin " .. apparence.skinCamp[camp])
			return camp
		end
	end
	-- Les deux camps sont pris : le joueur regarde (aucune carte jouable).
	print("[BRR] " .. player.Name .. " arrive en spectateur")
	return nil
end

local function rejoindre(player)
	if equipeDe[player] then
		return equipeDe[player]
	end
	-- IL REVIENT : son camp l'attendait, avec sa main, son elixir et ses unites. Aucune remise a
	-- neuf — ce serait effacer la partie de celui qui est reste.
	local repris = Reprise.campDe(reprises, player.UserId, os.clock())
	if repris then
		reprises[repris] = nil
		if teams[repris] then
			teams[repris].enPause = nil -- il est la : la partie repart
		end
		humainAbsent[repris] = nil
		occupant[repris] = player
		equipeDe[player] = repris
		majNiveauxRobot()
		print("[BRR] " .. player.Name .. " revient apres sa coupure : camp " .. repris .. " repris")
		return repris
	end
	local seul = occupant[1] == nil and occupant[2] == nil
	local camp = attribuerCamp(player)
	-- DUEL HUMAIN : le deuxieme arrivant entrait dans une partie DEJA commencee par le premier
	-- (chrono avance, elixir et unites du robot deja en place). On repart d'une partie neuve.
	local duelNeuf = camp ~= nil and not seul and occupant[3 - camp] ~= nil and not result
	if duelNeuf then
		print("[BRR] duel humain : partie remise a neuf pour les deux camps")
		resetMatch()
	end
	if camp and seul and not duelNeuf and not ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
		-- premier joueur : partie NEUVE, sinon il arrive dans un match que le robot mene deja
		resetMatch()
	elseif camp and teams[camp] then
		-- la partie en cours avait distribue le paquet du robot : le joueur recoit le SIEN
		teams[camp].hand, teams[camp].queue = newDeck(Economie.deck(player))
		teams[camp].niveaux = niveauxDe(player)
	end
	majNiveauxRobot()
	-- TUTORIEL : impose a la toute premiere partie (Tutoriel.obligatoire lit `parties == 0`),
	-- tant qu'il n'a pas ete VU jusqu'au bout — une premiere partie abandonnee le rejoue.
	-- BRR_TUTO : crochet de CAPTURE. La copie de test coupe le tutoriel (elle doit jouer un match
	-- normal), mais il faut pouvoir le regarder a l'ecran ; ce drapeau le force.
	local forcerTuto = ReplicatedStorage:FindFirstChild("BRR_TUTO") ~= nil
	-- JAMAIS DE TUTORIEL DANS UN DUEL HUMAIN : il impose une carte dans la main, force l'elixir et
	-- fait taire le camp d'en face — regles faussees pour les deux. Il reste reserve au solo.
	local duelHumain = camp ~= nil and (occupant[3 - camp] ~= nil or Matchmaking.estServeurDeMatch(game))
	if camp and seul and not duelHumain and (forcerTuto or not ReplicatedStorage:FindFirstChild("BRR_AUTOTEST")) then
		if forcerTuto or tutoDemande or (Tutoriel.obligatoire(Economie.profil(player)) and not Economie.tutorielFait(player)) then
			tuto.actif = true
			tuto.camp = camp
			tuto.joueur = player
			tutoEntrerEtape(1)
			print("[TUTO] demarre pour " .. player.Name .. (tutoDemande and " (relance depuis le menu)" or " (premiere partie)"))
		end
	end
	tutoDemande = false
	return camp
end

-- ABANDON EN DUEL HUMAIN. Avant, partir en pleine partie rendait le camp au ROBOT : l'adversaire
-- restait a jouer contre une machine, et le partant echappait a sa defaite (aucune perte de
-- trophees). Un depart compte donc comme une defaite pour lui, et une victoire pour l'autre.
local function abandon(player, camp)
	if not Duel.forfait(result ~= nil, camp, camp ~= nil and occupant[3 - camp] ~= nil) then
		return false
	end
	print("[BRR] " .. player.Name .. " abandonne : victoire du camp " .. (3 - camp))
	-- On termine la partie AVANT de liberer le camp : sinon l'adversaire encore en place gagnait
	-- sans son bonus « contre un humain », et le partant ne prenait aucune defaite.
	endMatch(3 - camp)
	occupant[camp] = nil
	equipeDe[player] = nil
	revanche[player] = nil
	return true
end

local function quitter(player, volontaire)
	-- Quitter en plein tutoriel ne le marque PAS comme fait : il sera rejoue.
	if tuto.actif and tuto.joueur == player then
		tuto.actif = false
		tuto.joueur = nil
		print("[TUTO] abandonne : il sera rejoue a la prochaine partie")
	end
	local camp = equipeDe[player]
	if camp then
		-- COUPURE RESEAU : on n'accorde pas la victoire tout de suite. Le camp est mis de cote pour
		-- lui (Reprise.DELAI secondes), et personne ne joue a sa place.
		-- DUEL ENTRE HUMAINS : l'autre est present, OU lui-meme en train de revenir. Sans ce
		-- second cas, le SECOND a sauter perdait son camp — parce que le premier venait de
		-- partir — alors qu'il avait saute exactement comme lui, souvent pour la meme cause.
		if Reprise.permise(result ~= nil,
			Reprise.duelHumain(occupant[3 - camp] ~= nil, reprises[3 - camp] ~= nil),
			volontaire == true) then
			reprises[camp] = Reprise.ouvrir(camp, player.UserId, os.clock())
			-- PAUSE : la partie s'arrete pendant son absence, sinon il retrouverait une partie ou
			-- il a pris 45 s de degats sans pouvoir se defendre. Une seule fois par joueur et par
			-- partie : couper son reseau en difficulte ne doit pas devenir une tactique.
			-- Le compteur vit dans l'equipe : elle est recreee a chaque partie, donc « une pause
			-- par joueur et par PARTIE » se lit directement, sans remise a zero a gerer.
			local eq = teams[camp]
			if eq and Reprise.pausePermise(eq.pauses or 0) then
				eq.pauses = (eq.pauses or 0) + 1
				eq.enPause = true
			end
			humainAbsent[camp] = true
			occupant[camp] = nil
			equipeDe[player] = nil
			print(string.format("[BRR] %s a saute : camp %d garde %d s (reprise possible)",
				player.Name, camp, Reprise.DELAI))
			return
		end
		-- QUITTER UN DUEL EN COURS CONTRE UN HUMAIN se paie — a la REPETITION, pas au premier
		-- depart : une coupure, un appel, une urgence ressemblent exactement a un abandon.
		-- Un duel ENTRE AMIS ne compte pas au classement : le quitter n'est pas fuir un adversaire.
		if Economie.fuiteCompte(volontaire == true, result == nil, occupant[3 - camp] ~= nil)
			and not player:GetAttribute("BRR_Prive") then
			Economie.noterAbandon(player)
			print(string.format("[BRR] %s quitte un duel en cours : %d abandon(s) recent(s)",
				player.Name, Economie.compteAbandons(player)))
		end
		if abandon(player, camp) then
			majNiveauxRobot()
			return
		end
		occupant[camp] = nil
		equipeDe[player] = nil
		revanche[player] = nil
		print("[BRR] " .. player.Name .. " retourne au hub : le bot reprend le camp " .. camp)
		majNiveauxRobot()
	end
end

-- HUB : un joueur arrive sur l'accueil SANS camp ; il en prend un en appuyant sur JOUER.
-- La copie de test (sans --hub) le place directement, pour que les tests automatiques jouent.
-- SCENARIO DE TEST de l'economie (build.py --autotest --ecotest) : chaque cas limite est joue
-- cote serveur et son resultat imprime [ECOTEST] ; attendu=... permet de lire le journal sans code.
local function ecotest(player)
	task.wait(4)
	local function cas(nom, attendu, obtenu)
		print(string.format("[ECOTEST] %s : attendu=%s obtenu=%s %s", nom, tostring(attendu), tostring(obtenu),
			tostring(attendu) == tostring(obtenu) and "OK" or "ECHEC"))
	end
	local p = Economie.profil(player)
	cas("solde de depart", 100, p.pieces)
	cas("Bombardiro verrouille au depart", "nil", tostring(p.cartes.Bombardiro))
	-- DEBLOCAGE PAR ARENE (Arenes.carteDebloquee) : Bombardiro n'est vendu qu'a partir de la Plage
	-- Tralalero. Ce scenario datait d'avant cette regle et attendait « pas assez de pieces » des
	-- 0 trophee : 9 cas etaient rouges en moteur sans aucun defaut du jeu (mesure du 2026-09-26).
	local ok, motif = Economie.acheterCarte(player, "Bombardiro")
	cas("achat avant son arene", "carte de Plage Tralalero", motif)
	p.trophees = 200 -- Plage Tralalero atteinte : seul le prix peut encore bloquer
	ok, motif = Economie.acheterCarte(player, "Bombardiro")
	cas("achat sans assez de pieces", "pas assez de pieces", motif)
	cas("solde inchange apres refus", 100, p.pieces)
	p.pieces = 1000
	ok = Economie.acheterCarte(player, "Bombardiro")
	cas("achat Bombardiro a 1000", true, ok)
	cas("solde apres achat", 500, p.pieces)
	ok, motif = Economie.acheterCarte(player, "Bombardiro")
	cas("double achat refuse", "deja debloquee", motif)
	ok, motif = Economie.acheterCarte(player, "Tralalero")
	cas("carte offerte non vendue", "deja debloquee", motif)
	ok, motif = Economie.acheterCarte(player, "CarteInventee")
	cas("carte inconnue", "carte inconnue", motif)
	cas("Bombardiro dans le deck", true, table.find(Economie.deck(player), "Bombardiro") ~= nil)
	ok = Economie.bonusQuotidien(player)
	cas("bonus du jour", true, ok)
	cas("solde apres bonus", 550, p.pieces)
	ok = Economie.bonusQuotidien(player)
	cas("second bonus refuse", false, ok)
	-- TROPHEES (Arenes.apres) : le tiers de l'enjeu contre le robot, l'enjeu entier contre un
	-- humain de meme niveau, et le plancher protege a la descente.
	p.trophees = 0
	local r = Economie.recompenser(player, "victoire")
	cas("victoire : pieces", 30, r.pieces)
	cas("victoire contre le robot : le tiers des trophees", 10, p.trophees)
	Economie.recompenser(player, "victoire", true, nil, p.trophees)
	cas("victoire contre un humain de meme niveau : +30", 40, p.trophees)
	Economie.recompenser(player, "defaite", true, nil, p.trophees)
	cas("defaite sous le plancher protege : rien perdu", 40, p.trophees)
	p.trophees = 300
	Economie.recompenser(player, "defaite", true, nil, 300)
	cas("defaite au-dessus du plancher : -15", 285, p.trophees)
	p.trophees = 105
	Economie.recompenser(player, "defaite", true, nil, 105)
	cas("jamais sous le plancher protege", 100, p.trophees)
	p.trophees = 10 -- etat attendu par la suite du scenario (coffres, niveaux)
	cas("leaderstats a jour", p.pieces, player.leaderstats.Pieces.Value)
	-- COFFRES
	Economie.graine(7)
	p.coffres = {}
	p.cartes.Patapim = nil
	local t = Economie.gagnerCoffre(player, "or")
	cas("coffre gagne", "or", t)
	for _ = 1, 5 do
		Economie.gagnerCoffre(player, "bois")
	end
	cas("4 emplacements maximum", 4, #p.coffres)
	cas("coffre refuse si plein", "nil", tostring(Economie.gagnerCoffre(player, "bois")))
	ok, motif = Economie.ouvrirCoffre(player, 1)
	cas("ouverture sans demarrer", "pas demarre", motif)
	ok = Economie.demarrerCoffre(player, 1)
	cas("demarrage", true, ok)
	cas("duree coffre d'or (s)", 3 * 3600, p.coffres[1].fin - os.time())
	ok, motif = Economie.demarrerCoffre(player, 2)
	cas("une seule ouverture a la fois", "un coffre s'ouvre deja", motif)
	ok, motif = Economie.ouvrirCoffre(player, 1)
	cas("ouverture trop tot", "pas encore pret", motif)
	ok, motif = Economie.ouvrirCoffre(player, 9)
	cas("coffre inexistant", "coffre inconnu", motif)
	p.coffres[1].fin = os.time() - 1 -- on avance le temps
	local avant = p.pieces
	local gain
	ok, gain = Economie.ouvrirCoffre(player, 1)
	cas("ouverture une fois pret", true, ok)
	cas("pieces du coffre d'or entre 150 et 250", true, gain.pieces >= 150 and gain.pieces <= 250)
	cas("solde credite du gain", avant + gain.pieces, p.pieces)
	-- Le coffre d'or debloque TOUJOURS une carte verrouillee, mais LAQUELLE depend du catalogue :
	-- l'attendre par son nom (« Patapim ») cassait ce banc a chaque carte payante ajoutee, sans
	-- qu'aucun defaut du jeu n'existe. On verifie donc la PROPRIETE : une carte payante, que le
	-- joueur n'avait pas, et qu'il possede apres coup.
	local carteTiree = gain.carte
	cas("coffre d'or : une carte est debloquee", true, carteTiree ~= nil)
	cas("coffre d'or : la carte tiree etait payante", true,
		carteTiree ~= nil and Cards.byId[carteTiree] ~= nil and Cards.byId[carteTiree].prix ~= nil)
	cas("carte bien ajoutee au profil", true, carteTiree ~= nil and p.cartes[carteTiree] == true)
	cas("coffre retire apres ouverture", 3, #p.coffres)
	ok = Economie.demarrerCoffre(player, 1)
	cas("demarrage possible apres ouverture", true, ok)
	p.coffres[1].fin = os.time() - 1
	ok, gain = Economie.ouvrirCoffre(player, 1)
	cas("bois : pieces entre 20 et 60", true, gain.pieces >= 20 and gain.pieces <= 60)
	local r2 = Economie.recompenser(player, "victoire")
	cas("victoire donne un coffre si place libre", true, r2.coffre ~= nil)
	-- NIVEAUX
	p.niveaux, p.exemplaires = {}, {}
	p.pieces = 2000
	p.cartes.Patapim = true
	cas("niveau de depart", 1, Economie.niveau(player, "Tralalero"))
	ok, motif = Economie.ameliorer(player, "Tralalero")
	cas("amelioration sans exemplaires", "pas assez d'exemplaires", motif)
	p.exemplaires.Tralalero = 2
	local av = p.pieces
	ok = Economie.ameliorer(player, "Tralalero")
	cas("amelioration niveau 2", true, ok)
	cas("niveau apres amelioration", 2, Economie.niveau(player, "Tralalero"))
	cas("exemplaires consommes", 0, p.exemplaires.Tralalero)
	cas("pieces consommees (50)", av - 50, p.pieces)
	p.exemplaires.Tralalero = 100
	p.pieces = 10
	ok, motif = Economie.ameliorer(player, "Tralalero")
	cas("amelioration sans pieces", "pas assez de pieces", motif)
	cas("exemplaires intacts apres refus", 100, p.exemplaires.Tralalero)
	p.pieces = 100000
	for _ = 1, 10 do
		Economie.ameliorer(player, "Tralalero")
	end
	cas("plafond niveau 5", 5, Economie.niveau(player, "Tralalero"))
	ok, motif = Economie.ameliorer(player, "Tralalero")
	cas("amelioration au maximum refusee", "niveau maximum", motif)
	cas("exemplaires consommes 4+10+20 (depuis le niveau 2)", 100 - 34, p.exemplaires.Tralalero)
	p.cartes.Patapim = nil
	ok, motif = Economie.ameliorer(player, "Patapim")
	cas("carte verrouillee non ameliorable", "carte verrouillee", motif)
	cas("multiplicateur niveau 5", 1.4, Economie.multiplicateur(5))
	p.coffres = { { type = "argent", fin = os.time() - 1 } }
	local total = 0
	for _, n in pairs(p.exemplaires) do total += n end
	ok, gain = Economie.ouvrirCoffre(player, 1)
	cas("coffre d'argent donne 8 exemplaires", 8, gain.exemplaires)
	local total2 = 0
	for _, n in pairs(p.exemplaires) do total2 += n end
	cas("exemplaires credites au profil", total + 8, total2)
	cas("exemplaires sur une carte debloquee", true, p.cartes[gain.exemplaireCarte] == true)
	local camp = equipeDe[player]
	if camp then
		teams[camp].niveaux = niveauxDe(player)
		local u = spawnUnit(Cards.byId.Tralalero, camp, Vector3.new(0, 0, camp == 1 and -10 or 10), Vector3.zero)
		cas("PV en partie au niveau 5", math.floor(Cards.byId.Tralalero.hp * 1.4), u.maxHp)
		cas("degats en partie au niveau 5", math.floor(Cards.byId.Tralalero.dmg * 1.4), u.dmg)
		local robot = spawnUnit(Cards.byId.Tralalero, 3 - camp, Vector3.new(0, 0, camp == 1 and 10 or -10), Vector3.zero)
		cas("robot reste niveau 1", Cards.byId.Tralalero.hp, robot.maxHp)
	else
		print("[ECOTEST] joueur sans camp : cas en partie non joues")
	end
	-- NIVEAU DU ROBOT = niveau moyen du deck du joueur ; tours au niveau de leur camp
	cas("moyenne vide -> 1", 1, Economie.niveauMoyen({}, {}))
	cas("moyenne 1,1,1,1 -> 1", 1, Economie.niveauMoyen({ a = 1, b = 1, c = 1, d = 1 }, { "a", "b", "c", "d" }))
	cas("moyenne 2,3 -> 2,5 arrondi a 3", 3, Economie.niveauMoyen({ a = 2, b = 3 }, { "a", "b" }))
	cas("moyenne 1,1,1,2 -> 1,25 arrondi a 1", 1, Economie.niveauMoyen({ a = 1, b = 1, c = 1, d = 2 }, { "a", "b", "c", "d" }))
	cas("moyenne 5,5 -> 5", 5, Economie.niveauMoyen({ a = 5, b = 5 }, { "a", "b" }))
	cas("carte absente comptee niveau 1", 3, Economie.niveauMoyen({ a = 5 }, { "a", "b" }))
	cas("les trophees ne comptent plus", Economie.niveauRobot(player), (function() local t = p.trophees; p.trophees = 5000; local n = Economie.niveauRobot(player); p.trophees = t; return n end)())
	local campJ = equipeDe[player]
	if campJ then
		local campR = 3 - campJ
		p.niveaux = {}
		for _, id in ipairs(Economie.deck(player)) do
			p.niveaux[id] = 3
		end
		teams[campJ].niveaux = Economie.niveaux(player)
		majNiveauxRobot()
		cas("deck du joueur tout niveau 3 -> robot niveau 3", 3, teams[campR].niveauRobot)
		local ur = spawnUnit(Cards.byId.Tralalero, campR, Vector3.new(4, 0, campR == 1 and -10 or 10), Vector3.zero)
		cas("PV d'une unite du robot au niveau 3", math.floor(Cards.byId.Tralalero.hp * 1.2), ur.maxHp)
		cas("tours du robot au niveau 3", 3, teams[campR].niveauTours)
		cas("tour du Roi du robot : 5200 x 1,2 puissance 1,5", math.floor(5200 * 1.2 ^ 1.5 + 0.5), teams[campR].towers[3].maxHp) -- 5200 x 1,2^1,5
		cas("tours du joueur au niveau moyen de SON deck", 3, teams[campJ].niveauTours)
		p.niveaux = {}
		teams[campJ].niveaux = Economie.niveaux(player)
		majNiveauxRobot()
		cas("deck redescendu au niveau 1 -> robot niveau 1", 1, teams[campR].niveauRobot)
		cas("tour du Roi revenue a 5200", 5200, teams[campR].towers[3].maxHp)
		for _, id in ipairs(Economie.deck(player)) do
			p.niveaux[id] = 5
		end
		resetMatch()
		cas("nouvelle partie : deck niveau 5 -> robot niveau 5", 5, teams[campR].niveauRobot)
		cas("nouvelle partie : tour princesse du robot 3400 x 1,4 puissance 1,5", math.floor(3400 * 1.4 ^ 1.5 + 0.5), teams[campR].towers[1].maxHp) -- 3400 x 1,4^1,5
		cas("degats de la tour au multiplicateur simple", math.floor(55 * 1.4), teams[campR].towers[1].dmg)
		local tw = teams[campR].towers[1]
		tw.hp = tw.maxHp / 2
		p.niveaux = {}
		teams[campJ].niveaux = Economie.niveaux(player)
		majNiveauxRobot()
		cas("tour entamee garde sa proportion (50 %)", 0.5, math.floor(tw.hp / tw.maxHp * 100 + 0.5) / 100)
		resetMatch()
	else
		print("[ECOTEST] joueur sans camp : cas robot en partie non joues")
	end
	-- CAS LIMITES DU ROBOT (version « nouveau », camp 2) : ils doivent rester verts quand
	-- botThinkNouveau (robot reactif) change. Etat remis a neuf avant et apres.
	resetMatch()
	local tb = teams[2]
	tb.botVersion = "nouveau"
	tb.elixir, tb.botTimer = 0, 0
	local mainAvant = table.concat(tb.hand, ",")
	local okA, errA = pcall(botThink, 2, 0.1)
	cas("robot sans carte jouable : pas d'erreur", "true", tostring(okA) .. (errA and tostring(errA) or ""))
	cas("robot sans carte jouable : main inchangee", mainAvant, table.concat(tb.hand, ","))
	cas("robot sans carte jouable : elixir reste 0", 0, tb.elixir)
	resetMatch()
	tb = teams[2]
	tb.botVersion = "nouveau"
	tb.elixir, tb.botTimer = MAX_ELIXIR, 0
	local okB, errB = pcall(botThink, 2, 0.1)
	cas("robot sans unite ennemie : pas d'erreur", "true", tostring(okB) .. (errB and tostring(errB) or ""))
	local intactes = true
	for _, tw in ipairs(teams[1].towers) do
		intactes = intactes and tw.hp == tw.maxHp
	end
	cas("robot tours ennemies intactes : etat de depart", true, intactes)
	tb.botTimer = 0
	local okC, errC = pcall(botThink, 2, 0.1)
	cas("robot tours ennemies intactes : pas d'erreur", "true", tostring(okC) .. (errC and tostring(errC) or ""))
	resetMatch()
	print("[ECOTEST] FIN")
end

local function arrivee(player)
	Economie.charger(player)
	-- capture du hub avec des coffres dans chaque etat (build.py --coffres)
	if ReplicatedStorage:FindFirstChild("BRR_COFFRES") then
		local p = Economie.profil(player)
		p.coffres = { { type = "or", fin = 0 }, { type = "argent", fin = os.time() + 47 * 60 }, { type = "bois", fin = os.time() - 5 }, { type = "bois", fin = 0 } }
	end
	-- capture du PASS DE SAISON (build.py --pass-points=N) : N points deja faits cette saison
	Economie.passPremiumTest = ReplicatedStorage:FindFirstChild("BRR_PASS_PREMIUM") ~= nil
	-- capture des COSMETIQUES (build.py --cosmetiques / --skin=id)
	if ReplicatedStorage:FindFirstChild("BRR_COSMETIQUES") then
		Economie.profil(player).gemmes = 500
	end
	local skinTest = ReplicatedStorage:FindFirstChild("BRR_SKIN")
	if skinTest then
		local cos = Economie.cosmetiques(player)
		cos.possedes[skinTest.Value] = true
		cos.possedes.tralalero = true -- une emote premium, pour la voir dans la barre
		cos.skin = skinTest.Value
	end
	apparence.publierEmotes(player)
	local passPoints = ReplicatedStorage:FindFirstChild("BRR_PASS_POINTS")
	if passPoints then
		local p = Economie.profil(player)
		Economie.passEtat(p).points = passPoints.Value
	end
	-- capture de la revelation d'une carte NOUVELLE LEGENDAIRE (build.py --ouverture)
	if ReplicatedStorage:FindFirstChild("BRR_OUVERTURE") then
		local p = Economie.profil(player)
		for _, card in ipairs(Cards.list) do
			if card.rarete == "legendaire" and not p.cartes[card.id] then
				Economie.carteImposee = card.id
				print("[OUVERTURE] carte legendaire imposee : " .. card.name)
				break
			end
		end
	end
	-- capture de la boutique avec des niveaux varies (build.py --niveaux)
	-- CAPTURE DE LA MONTEE EN ARENE (build.py --trophees=N) : une barre a zero ne prouve rien.
	-- On pose un nombre de trophees CHOISI, et la barre affiche la part reelle du palier.
	-- CAPTURE DE LA FIN DE SAISON (build.py --fin-saison) : la bascule n'a lieu qu'au passage d'une
	-- vraie saison. On pose ici le MEME bilan que celui qu'elle produit, pour photographier l'ecran.
	if ReplicatedStorage:FindFirstChild("BRR_FIN_SAISON") then
		local p = Economie.profil(player)
		p.bilanSaison = { saison = Saison.numero(os.time()) - 1, sommet = 940,
			pieces = Saison.recompense(940), avant = 940, apres = Saison.apresRemiseAZero(940) }
	end
	-- CAPTURE DE LA MONTEE D'ARENE (build.py --montee) : on se place JUSTE sous un seuil (595
	-- trophees, l'arene suivante est a 600). La victoire mise en scene plus bas franchit donc le
	-- palier par le vrai chemin, et l'ecran de fin affiche ce que le serveur a reellement verse.
	if ReplicatedStorage:FindFirstChild("BRR_MONTEE") then
		local p = Economie.profil(player)
		p.trophees = 595
		Economie.publier(player)
	end
	-- CAPTURE DU COFFRE PERDU (build.py --pleins) : 4 emplacements pleins, puis la victoire mise
	-- en scene plus bas ; l'ecran de fin doit dire « pas de coffre : emplacements pleins ».
	-- CAPTURE DE L'OUVERTURE EN GEMMES (build.py --coffres --gemmes) : 30 gemmes, puis le coffre
	-- d'argent EN COURS (emplacement 2) est ouvert par le VRAI chemin Economie.accelererCoffre.
	if ReplicatedStorage:FindFirstChild("BRR_GEMMES") then
		local p = Economie.profil(player)
		p.gemmes = 30
		task.delay(8, function()
			if ReplicatedStorage:FindFirstChild("BRR_CLICS") then
				return -- ce sont les clics du joueur (client) qui decident
			end
			local ok, r = Economie.accelererCoffre(player, 2)
			print("[GEMMES] acceleration :", ok, type(r) == "table" and r.pieces or r, "reste", p.gemmes, "gemmes,", #p.coffres, "coffres")
		end)
	end
	-- CAPTURE (build.py --liste-bas) : journal PLEIN (Journal.MAX parties), par le vrai module.
	if ReplicatedStorage:FindFirstChild("BRR_LISTE_BAS") then
		local p = Economie.profil(player)
		local J = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Journal"))
		for i = 1, J.MAX do
			p.journal = J.ajouter(p.journal, J.entree(i % 3 == 0 and "defaite" or "victoire",
				i % 3 == 0 and -15 or 30, i % 2 == 0 and "Robot" or ("Joueur" .. i), os.time() - i * 600))
		end
	end
	-- CAPTURE (build.py --deck-legendaire) : deux LEGENDAIRES possedees et placees dans le deck, par
	-- le vrai chemin (Economie.choisirDeck), pour photographier leur bordure de rarete.
	if ReplicatedStorage:FindFirstChild("BRR_DECK_LEGENDAIRE") then
		local p = Economie.profil(player)
		p.cartes.Vacca, p.cartes.Nuclearo = true, true
		local ids = { "Vacca", "Nuclearo" }
		for _, id in ipairs(Economie.deck(player)) do
			if #ids < Economie.DECK_TAILLE and id ~= "Vacca" and id ~= "Nuclearo" then
				table.insert(ids, id)
			end
		end
		print("[DECK] deck legendaire de test :", Economie.choisirDeck(player, ids))
	end
	-- CAPTURE (build.py --deck-max) : tout le deck au niveau maximum, pour voir ou vont les
	-- exemplaires d'un coffre ouvert ensuite.
	if ReplicatedStorage:FindFirstChild("BRR_DECK_MAX") then
		local p = Economie.profil(player)
		for _, id in ipairs(Economie.deck(player)) do
			p.niveaux[id] = Economie.NIVEAU_MAX
		end
	end
	if ReplicatedStorage:FindFirstChild("BRR_PLEINS") then
		local p = Economie.profil(player)
		p.coffres = { { type = "bois", fin = 0 }, { type = "bois", fin = 0 }, { type = "argent", fin = 0 }, { type = "or", fin = 0 } }
	end
	-- CAPTURE DE LA PASTILLE (build.py --quete-prete) : on termine la premiere quete du jour par le
	-- VRAI chemin (Economie.avancerQuete), sans la reclamer. Avec le coffre gratuit deja disponible
	-- sur un profil neuf, la pastille de l'onglet EVENEMENTS doit afficher 2.
	if ReplicatedStorage:FindFirstChild("BRR_QUETE_PRETE") then
		local quete = Economie.quetesDuJour(Economie.jourDe(os.time()))[1]
		if quete then
			Economie.avancerQuete(player, quete.id, quete.cible)
		end
	end
	-- CAPTURE D'UN SOLDE CHOISI (build.py --pieces=N) : certaines lignes de la boutique ne
	-- s'affichent qu'au-dessus d'un certain solde (« N cartes a ta portee »). On pose le solde,
	-- le reste du calcul suit le vrai chemin.
	local forcePieces = ReplicatedStorage:FindFirstChild("BRR_PIECES")
	if forcePieces and forcePieces.Value > 0 then
		local p = Economie.profil(player)
		p.pieces = forcePieces.Value
	end
	local forceTrophees = ReplicatedStorage:FindFirstChild("BRR_TROPHEES")
	if forceTrophees and forceTrophees.Value > 0 then
		local p = Economie.profil(player)
		p.trophees = forceTrophees.Value
		Economie.publier(player)
	end
	if ReplicatedStorage:FindFirstChild("BRR_NIVEAUX") then
		local p = Economie.profil(player)
		p.pieces = 480
		-- PizzaBombarda niveau 3 : preuve que le niveau s'applique aussi aux degats d'un SORT
		-- (regle ajoutee le 2026-09-21 ; avant, ameliorer un sort ne rapportait rien).
		p.niveaux = { Tralalero = 3, TungSahur = 5, Ballerina = 2, PizzaBombarda = 3 }
		p.cartes.PizzaBombarda = true
		p.exemplaires = { Tralalero = 7, Cappuccino = 2, Chimpanzini = 1, Lirili = 5 }
	end
	if ReplicatedStorage:FindFirstChild("BRR_ECOTEST") then
		task.spawn(ecotest, player)
	end
	-- CAPTURE DU SPECTATEUR (build.py --spectateur) : on ne le fait PAS rejoindre un camp. Il se
	-- retrouve exactement dans l'etat d'un vrai spectateur (aucun camp), et ses clics suivent le
	-- vrai chemin de refus.
	if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") and not ReplicatedStorage:FindFirstChild("BRR_HUB")
		and not ReplicatedStorage:FindFirstChild("BRR_SPECTATEUR") then
		rejoindre(player)
	end
	-- DUEL PRIVE EGALISE : le mode voyage avec le joueur (donnee de teleportation posee par
	-- Matchmaking.creerPrive / rejoindrePrive). Lu ICI, avant que le camp ne soit pris.
	local okDonnee, donnee = pcall(function()
		return player:GetJoinData() and player:GetJoinData().TeleportData
	end)
	-- DUEL ENTRE AMIS : le joueur arrive d'un code prive. Marque SUR LUI, comme le mode egalise :
	-- c'est ce qui permet a la fin de partie de ne pas le classer (voir Duel.compteAuClassement).
	if okDonnee and type(donnee) == "table" and donnee.prive == true then
		player:SetAttribute("BRR_Prive", true)
	end
	if okDonnee and type(donnee) == "table" and Egalise.actif(donnee.egalise) then
		-- Le mode est marque SUR LE JOUEUR, pas seulement sur le serveur : c'est LUI qui vient
		-- d'un duel egalise. Sans cette marque, on ne saurait pas le retrouver a la partie
		-- suivante — et le mode restait donc allume pour toujours (voir resetMatch).
		player:SetAttribute("BRR_Egalise", true)
		if not modeEgalise then
			modeEgalise = true
			print("[BRR] duel a NIVEAUX EGALISES : toutes les cartes au niveau " .. Egalise.NIVEAU)
		end
	end
	-- Serveur reserve : on y arrive DEPUIS la file d'attente, le camp est pris sans repasser par JOUER.
	if Matchmaking.estServeurDeMatch(game) then
		rejoindre(player)
	end
end

BoutiqueFn.OnServerInvoke = function(player, action, arg)
	if action == "acheter" then
		local ok, motif = Economie.acheterCarte(player, arg)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "bonus" then
		local ok, motif = Economie.bonusQuotidien(player)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "quete" then
		-- `arg` = identifiant de la quete reclamee ; le serveur verifie l'avancee lui-meme.
		local ok, motif, gemmes = Economie.reclamerQuete(player, arg)
		return { ok = ok, motif = motif, gemmes = gemmes, vue = Economie.vue(player) }
	elseif action == "coffreGratuit" then
		local ok, motif = Economie.reclamerCoffreGratuit(player)
		return { ok = ok, motif = type(motif) == "table" and nil or motif, vue = Economie.vue(player) }
	elseif action == "demarrerCoffre" then
		local ok, motif = Economie.demarrerCoffre(player, tonumber(arg))
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "ouvrirCoffre" then
		local ok, gain = Economie.ouvrirCoffre(player, tonumber(arg))
		return { ok = ok, motif = not ok and gain or nil, gain = ok and gain or nil, vue = Economie.vue(player) }
	elseif action == "accelererCoffre" then
		local ok, gain = Economie.accelererCoffre(player, tonumber(arg))
		return { ok = ok, motif = not ok and gain or nil, gain = ok and gain or nil, vue = Economie.vue(player) }
	elseif action == "ameliorer" then
		local ok, motif = Economie.ameliorer(player, arg)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "deck" then
		-- `arg` = liste d'identifiants envoyee par le hub. Economie.choisirDeck refuse tout ce qui
		-- n'est pas possede : le client ne decide rien.
		local ok, motif = Economie.choisirDeck(player, arg)
		-- CHANGER DE DECK EN PLEINE RECHERCHE : son entree de file porte le niveau moyen de son
		-- deck. Sans cette mise a jour, il serait apparie sur un deck qu'il n'emmene plus.
		local enFile = false
		if ok then
			enFile = Matchmaking.majProfil(player, { tr = Economie.tropheesDe(player),
				nv = Economie.niveauMoyen(Economie.niveaux(player) or {}, Economie.deck(player) or {}),
				adv = Economie.adversairesRecents(player) })
		end
		return { ok = ok, motif = motif, fileMiseAJour = enFile, vue = Economie.vue(player) }
	elseif action == "jouer" then
		-- QUITTEUR EN SERIE : il attend avant de relancer une recherche. On le DIT, avec le temps
		-- restant : une attente sans explication ressemble a un bug, et n'apprend rien.
		local resteFuite = Economie.attenteAbandon(player)
		if resteFuite > 0 then
			return { ok = false, motif = Economie.texteAbandon(resteFuite), attenteAbandon = resteFuite,
				vue = Economie.vue(player) }
		end
		if Matchmaking.actif() and not equipeDe[player] then
			-- APPARIEMENT : la file a besoin du niveau de jeu, pas seulement d'un tour de role.
			-- Trophees et niveau MOYEN du deck choisi — les deux chiffres qui decident si un duel
			-- est jouable (tools/test_appariement.py).
			local etat = Matchmaking.entrer(player, rejoindre, function(p)
				return { tr = Economie.tropheesDe(p),
					nv = Economie.niveauMoyen(Economie.niveaux(p) or {}, Economie.deck(p) or {}),
					-- adversaires recents : la file preferera quelqu'un d'autre
					adv = Economie.adversairesRecents(p) }
			end, arg == "patient")
			return { ok = true, attente = etat == "attente", vue = Economie.vue(player) }
		end
		return { ok = rejoindre(player) ~= nil, vue = Economie.vue(player) }
	elseif action == "suivre" then
		-- SPECTATEUR : changer de camp suivi. Sans camp, aucun effet (un joueur suit le sien).
		if equipeDe[player] == nil then
			suivi[player] = Spectateur.campSuivant(suivi[player] or 1, tonumber(arg))
		end
		return { ok = equipeDe[player] == nil, camp = suivi[player], vue = Economie.vue(player) }
	elseif action == "signaler" then
		-- SIGNALEMENT : liste FERMEE de motifs (le client envoie un identifiant, jamais du texte).
		-- Le serveur choisit la cible lui-meme : l'adversaire du moment, ou le dernier connu.
		local camp = equipeDe[player]
		local cible = (camp and occupant[3 - camp]) or dernierAdversaire[player]
		local idCible = cible and cible.UserId or nil
		local cle = Signalement.cle(player.UserId, idCible)
		local ok, motif = Signalement.accepte(arg, idCible, player.UserId, signalements[cle] == true)
		if ok then
			signalements[cle] = true
			-- TRACE : une ligne par signalement dans le journal du serveur, format stable.
			print(Signalement.ligne(player.UserId, idCible, arg, os.time(), camp))
		end
		return { ok = ok, motif = motif,
			message = ok and Signalement.confirmation(arg) or motif,
			vue = Economie.vue(player) }
	elseif action == "duelPrive" then
		-- DUEL PRIVE : l'hote cree un code a partager ; le serveur reserve l'arene et l'y envoie.
		-- `arg` = "egalise" quand le joueur a coche le mode a niveaux egalises.
		local code, motif = Matchmaking.creerPrive(player, nil, arg == "egalise")
		return { ok = code ~= nil, code = code, motif = motif, vue = Economie.vue(player) }
	elseif action == "rejoindreCode" then
		-- `arg` = code tape par le joueur. Toute la verification est ICI (le client ne decide rien).
		local ok, motif = Matchmaking.rejoindrePrive(player, arg)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "robotMaintenant" then
		-- SORTIE DE SECOURS de l'attente patiente : sans elle, « attendre un humain » serait un
		-- piege de trois minutes.
		local ok = Matchmaking.robotMaintenant(player, rejoindre)
		return { ok = ok, vue = Economie.vue(player) }
	elseif action == "attente" then
		-- COMBIEN CHERCHENT EN MEME TEMPS : une attente muette laisse croire que le jeu est vide.
		return { ok = true, etat = Matchmaking.etat(player), camp = equipeDe[player],
			enFile = Matchmaking.actif() and Matchmaking.compterFile() or 0,
			-- temps restant avant la bascule : on l'ANNONCE au lieu de la subir
			avantRobot = math.ceil(Matchmaking.resteAvantRobot(player)),
			vue = Economie.vue(player) }
	elseif action == "enMatch" then
		return { ok = Matchmaking.estServeurDeMatch(game), vue = Economie.vue(player) }
	elseif action == "quitter" then
		Matchmaking.sortir(player)
		-- Le bouton MENU reste un ABANDON volontaire : aucun delai de grace (sinon il suffirait de
		-- partir puis de revenir pour annuler une defaite qui s'annonce mal).
		quitter(player, true)
		return { ok = true, vue = Economie.vue(player) }
	elseif action == "classement" then
		return { ok = true, classement = Economie.classement(), vue = Economie.vue(player) }
	elseif action == "cosmetique" then
		-- `arg` = { id = article, equiper = true pour un skin deja possede }
		local a = type(arg) == "table" and arg or {}
		local ok, motif
		if a.equiper then
			ok, motif = Economie.equiperSkin(player, a.id)
		else
			ok, motif = Economie.acheterCosmetique(player, a.id)
		end
		if ok then
			apparence.publierEmotes(player)
		end
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "pass" then
		-- `arg` = { palier = n, piste = "gratuit" | "premium" } ; tout est revérifie par Economie.
		local a = type(arg) == "table" and arg or {}
		local ok, motif = Economie.reclamerPalier(player, a.palier, a.piste)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "passPremium" then
		if Economie.PASS_SAISON ~= 0 then
			game:GetService("MarketplaceService"):PromptGamePassPurchase(player, Economie.PASS_SAISON)
			return { ok = true, vue = Economie.vue(player) }
		end
		return { ok = false, motif = "Pass premium bientot en vente", vue = Economie.vue(player) }
	elseif action == "robux" then
		-- rang d'un produit, ou "vip" : Economie.demanderRobux verifie l'un et l'autre
		Economie.demanderRobux(player, arg)
		return { ok = true, vue = Economie.vue(player) }
	elseif action == "tutoriel" then
		-- REVOIR LE TUTORIEL : la prochaine entree en partie rejoue le scenario, meme si le
		-- joueur l'a deja vu. Le marqueur du profil n'est pas efface : il le reste apres coup.
		tutoDemande = true
		return { ok = true, vue = Economie.vue(player) }
	elseif action == "saisonVue" then
		-- L'ecran a montre le bilan de fin de saison : on l'oublie, sinon il reviendrait a chaque
		-- ouverture du menu.
		local ok = Economie.oublierBilanSaison(player)
		return { ok = ok, vue = Economie.vue(player) }
	elseif action == "son" then
		-- REGLAGES SONORES : `arg` = { musique = ..., bruitages = ... }. Gardes dans le profil pour
		-- qu'ils suivent le joueur d'un serveur a l'autre (Roblox n'offre pas de stockage local).
		local reglage = type(arg) == "table" and arg or {}
		local son = Economie.reglerSon(player, reglage.musique, reglage.bruitages)
		return { ok = son ~= nil, son = son, vue = Economie.vue(player) }
	elseif action == "profil" then
		-- lecture seule : l'ecran de menu redemande la vue a chaque ouverture d'onglet.
		return { ok = true, vue = Economie.vue(player) }
	end
	-- ACTION INCONNUE = REFUS EXPLICITE. Avant, ce retour rendait ok = true : un bouton dont
	-- l'action etait mal orthographiee se comportait comme un succes silencieux, et l'ecran se
	-- rafraichissait comme si tout allait bien. Le client peut maintenant afficher le motif.
	warn(string.format("[BOUTIQUE] %s : action inconnue « %s » refusee", player.Name, tostring(action)))
	return { ok = false, motif = "action inconnue : " .. tostring(action), vue = Economie.vue(player) }
end

Players.PlayerAdded:Connect(arrivee)
-- PASS ROBLOX PAYE EN JEU : actif tout de suite (Economie.noterPassAchete), et l'ecran du joueur
-- recoit sa vue a jour sans attendre un changement de solde (Remotes.Vue).
game:GetService("MarketplaceService").PromptGamePassPurchaseFinished:Connect(function(player, passId, achete)
	if Economie.noterPassAchete(player, passId, achete) then
		remotes.Vue:FireClient(player, Economie.vue(player))
	end
end)
Players.PlayerRemoving:Connect(function(player)
	Matchmaking.sortir(player)
	-- MEME CHEMIN qu'un retour au hub, mais NON VOLONTAIRE : une deconnexion peut etre une simple
	-- coupure reseau. `quitter` ouvre alors un delai de grace (Reprise) au lieu du forfait ; le
	-- forfait tombe seulement si personne ne revient.
	quitter(player, false)
	revanche[player] = nil
	recompenses[player] = nil
	Economie.liberer(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	arrivee(player)
end

local function campLibre(camp)
	return occupant[camp] == nil
end

-- Nom affiche dans le score : le joueur du camp adverse s'il y en a un, sinon le ROBOT AVEC SON
-- NIVEAU. « Bot » tout court ne disait ni qu'il s'agit d'une machine adaptee au joueur, ni a quel
-- point elle l'est.
local function nomAdversaire(monCamp)
	-- LIGNE DE SCORE : nom COURT. Le palier et les chiffres sont dans la fiche, juste en dessous —
	-- les empiler ici faisait deborder le texte sous le badge (capture du 2026-09-20).
	local adversaire = occupant[3 - monCamp]
	return Adversaire.nomCourt(adversaire and adversaire.DisplayName)
end

-- RESUME PARTAGEABLE de la partie finie, du point de vue de `camp`. Rien ne sortait du jeu :
-- une belle partie disparaissait a l'ecran suivant. Ce n'est PAS un replay (on n'enregistre pas
-- les coups) : c'est le resume des faits, plus un code compact qui porte les memes chiffres.
local function resumePartage(camp)
	if vainqueur == nil or camp == 0 then
		return nil
	end
	local issue = (vainqueur == 0 and "egalite") or (vainqueur == camp and "victoire" or "defaite")
	local moi = Bilan.vue(teams[camp].bilan)
	return Partage.resume({
		issue = issue,
		couronnesMoi = crowns(camp), couronnesLui = crowns(3 - camp),
		adversaire = nomAdversaire(camp),
		duree = math.floor(MATCH_TIME - timeLeft),
		cartes = moi and moi.cartes or 0,
		gaspille = moi and moi.gaspille or 0,
		degatsTours = moi and moi.degatsTours or 0,
		decor = themeArene and themeArene.nom or nil,
	})
end


-- LECTURE DU DUEL, cote serveur : trois petites vues construites a partir de faits OBSERVABLES.
local function lectureElixir(camp)
	local t = teams[camp]
	if not t then
		return 0
	end
	return Lecture.elixirEstime(t.elixirDepart or 5, t.regenCumulee or 0, t.depenseVue or 0)
end

local function lectureCartes(camp)
	local t = teams[camp]
	if not t then
		return {}
	end
	local l = {}
	for _, c in ipairs(Lecture.dernieresCartes(t.jouees)) do
		table.insert(l, c.id)
	end
	return l
end

-- COMBIEN DE FOIS CHAQUE CARTE AFFICHEE EST DEJA PASSEE, dans le MEME ordre que lectureCartes.
-- Le compte porte sur TOUT l'historique du camp, pas sur les quatre dernieres : c'est ce qui
-- distingue « il la rejoue » de « je l'ai vue une fois ».
local function lecturePassages(camp)
	local t = teams[camp]
	if not t then
		return {}
	end
	local l = {}
	for _, c in ipairs(Lecture.dernieresCartes(t.jouees)) do
		table.insert(l, Lecture.dejaVue(t.jouees, c.id))
	end
	return l
end

local function lectureAlerte(camp)
	local t = teams[camp]
	if not t then
		return nil
	end
	local tours = {}
	for _, tw in ipairs(t.towers) do
		local recents, restants = Lecture.degatsRecents(tw.coups, horloge)
		tw.coups = restants -- la liste ne grossit jamais : on la nettoie a chaque lecture
		table.insert(tours, { vivante = tw.alive == true, pv = tw.hp, pvMax = tw.maxHp,
			degatsRecents = recents, x = tw.part.Position.X, roi = tw.isKing == true })
	end
	local niveau, cote = Lecture.alerteCamp(tours)
	if not niveau then
		return nil
	end
	return { niveau = niveau, cote = cote, texte = Lecture.texteAlerte(niveau, cote) }
end

local function sendState(player)
	local _, attenteTexte, attenteSecondes = etatDepart()
	-- On garde le dernier adversaire VU : il peut partir avant qu'on ait eu le temps de le signaler.
	local monCampCourant = equipeDe[player]
	if monCampCourant and occupant[3 - monCampCourant] then
		local autre = occupant[3 - monCampCourant]
		local vu = dernierAdversaire[player]
		if not vu or vu.UserId ~= autre.UserId then
			-- DUEL FORME : chacun retient l'autre, pour ne pas etre reapparie avec lui juste apres.
			Economie.noterAdversaire(player, autre.UserId)
		end
		-- On retient son IDENTIFIANT, pas l'objet joueur lui-meme. Garder l'objet empechait Roblox
		-- de liberer un joueur parti : sur un serveur qui tourne des heures, la table accumulait
		-- tous les adversaires croises depuis le demarrage, et aucun n'etait jamais retire.
		dernierAdversaire[player] = { UserId = autre.UserId, Name = autre.DisplayName }
	end
	-- SPECTATEUR : aucun camp. Il recevait jusqu'ici l'etat du camp 1 (main, elixir, « Toi 0 - 1 »)
	-- comme s'il jouait. On ne lui envoie donc ni main ni elixir, et le score est donne camp par
	-- camp, sans « toi ».
	local camp = equipeDe[player]
	if camp == nil then
		-- SPECTATEUR : il suit un camp (par defaut le 1), voit sa main AVEC RETARD, et apprend en
		-- fin de partie si son pari etait juste.
		local vu = suivi[player] or 1
		StateEvent:FireClient(player, {
			elixir = 0,
			hand = {},
			nextCard = nil,
			campSuivi = vu,
			suiviLibelle = Spectateur.libelleSuivi(vu),
			mainSuivie = Spectateur.instantane(historiqueMains[vu], horloge),
			retardMain = Spectateur.RETARD,
			-- Le bouton de pari disparait quand les paris ferment : sans ce mot, le spectateur
			-- chercherait un bouton evanoui.
			parisOuverts = Spectateur.parisOuverts(timeLeft, MATCH_TIME, crowns(1), crowns(2)),
			parisFermes = (not Spectateur.parisOuverts(timeLeft, MATCH_TIME, crowns(1), crowns(2))
				and not result and pronostics[player] == nil) and Spectateur.texteParisFermes() or nil,
			-- PARTIE ANNULEE (les deux ont saute) : on le dit pendant quelques secondes, le temps
			-- qu'il le lise. Passe ce delai, la nouvelle partie a commence et le message n'a plus
			-- d'objet.
			pronosticResultat = (annuleeRecente() and Spectateur.texteAnnulee())
				or (result and Spectateur.resultatPronostic(pronostics[player], vainqueur,
					Economie.montantPronostic()) or nil),
			-- RECAPITULATIF VU DU SPECTATEUR : il regardait la partie sans jamais savoir POURQUOI
			-- elle s'est jouee ainsi. Les memes chiffres que pour les joueurs, mais nommes par camp
			-- (il n'a pas de « toi »).
			bilanCamp1 = result and Bilan.vue(teams[1].bilan) or nil,
			bilanCamp2 = result and Bilan.vue(teams[2].bilan) or nil,
			nomCamp1 = Adversaire.nom(occupant[1] and occupant[1].DisplayName,
				teams[1] and teams[1].profilRobot and teams[1].profilRobot.nom),
			nomCamp2 = Adversaire.nom(occupant[2] and occupant[2].DisplayName,
				teams[2] and teams[2].profilRobot and teams[2].profilRobot.nom),
			-- PHOTOS DE PROFIL vues par le SPECTATEUR : celles des DEUX joueurs. Il n'a pas de
			-- camp, donc rien a montrer « de son cote » — il voyait sa propre photo face a un
			-- rouage de robot, ce qui ne voulait rien dire pour lui.
			userIdCamp1 = occupant[1] and occupant[1].UserId or nil,
			userIdCamp2 = occupant[2] and occupant[2].UserId or nil,
			camp1EstRobot = occupant[1] == nil,
			camp2EstRobot = occupant[2] == nil,
			timeLeft = timeLeft,
			phase = Regles.phase(timeLeft, MATCH_TIME, prolongation),
		-- PREAVIS DE DOUBLE ELIXIR : le basculement etait annonce A L'INSTANT ou il arrive, alors
		-- que toute la decision se prend AVANT (garder son elixir pour partir en poussee des la
		-- bascule). Le compte a rebours est calcule ICI : le client n'a pas la duree du match.
		preavisDouble = Regles.texteAvantDouble(timeLeft, MATCH_TIME, prolongation),
		-- PREAVIS DE FIN : « PROLONGATION DANS n » si les couronnes sont a egalite, « FIN DANS n »
		-- sinon. Les dernieres secondes ne se jouent pas pareil dans les deux cas.
		preavisFin = Regles.texteAvantFin(timeLeft, crowns(1), crowns(2), prolongation),
			spectateur = true,
			attente = attenteTexte,
			compteARebours = attenteSecondes,
			serveurDeMatch = Matchmaking.estServeurDeMatch(game),
			chatVisible = true, -- le spectateur n'a pas de duel contre le bot : il peut parler
			crownsCamp1 = crowns(1),
			crownsCamp2 = crowns(2),
			crownsYou = crowns(1),
			crownsEnemy = crowns(2),
			result = texteFin(0), -- 0 : ni gagnant ni perdant, donc « EGALITE » ou rien
			combat = combat,
		})
		return
	end
	local monCamp = camp
	local t = teams[monCamp]
	StateEvent:FireClient(player, {
		elixir = t.elixir,
		hand = t.hand,
		nextCard = t.queue[1],
		-- CYCLE VISIBLE : les DEUX prochaines cartes, pas seulement la suivante. Compter son cycle
		-- pour savoir quand la carte cle revient est le coeur du genre ; avec une seule carte
		-- annoncee, le joueur ne pouvait pas le faire.
		suivantes = Cycle.suivantes(t.queue),
		-- RETOUR DE LA DERNIERE JOUEE : « dans combien de cartes elle revient ». Compter son
		-- cycle est le coeur du genre ; le joueur devait le faire de tete, sur huit cartes.
		derniereJouee = t.derniereJouee,
		retourDerniere = t.derniereJouee and Cycle.retour(t.hand, t.queue, t.derniereJouee) or nil,
		-- TUTORIEL : l'etape en cours, pour que le client la METTE EN SCENE (doigt, jauge qui
		-- pulse, camera). Le client n'invente rien : il joue ce que le scenario nomme.
		tuto = (tuto.actif and monCamp == tuto.camp and tutoEtape()) and {
			index = tuto.index,
			total = Tutoriel.nombreEtapes(),
			id = tutoEtape().id,
			montrer = tutoEtape().montrer,
			carte = tutoEtape().carte,
		} or nil,
		-- ARENE atteinte : le nom du palier de trophees, affiche pendant la partie.
		arene = Arenes.nom(Economie.tropheesDe(occupant[monCamp])),
		-- MODE EGALISE : le joueur doit savoir que ses niveaux ne comptent pas ici, et que le
		-- resultat ne touchera pas son classement.
		-- HORS CLASSEMENT : niveaux egalises, ou duel entre amis. Le joueur doit le savoir AVANT de
		-- jouer, pas le decouvrir a l'ecran de fin avec zero trophee.
		egalise = Duel.libelleHorsClassement(Egalise.libelle(Egalise.actif(modeEgalise)),
			(occupant[1] and occupant[1]:GetAttribute("BRR_Prive") == true)
			or (occupant[2] and occupant[2]:GetAttribute("BRR_Prive") == true)),
		-- nom du decor du duel : de l'apparence, mais nommee, sinon la variation passe inapercue
		decor = themeArene.nom,
		-- SAISON : son rang mondial s'il est au tableau, sinon ses trophees, plus le temps qu'il
		-- reste avant la remise a zero. Sans cela, gagner une partie ne se voyait nulle part.
		rang = Saison.texteRang(Saison.rang(Economie.classement(), player.DisplayName, player.UserId),
			Economie.tropheesDe(occupant[monCamp])),
		saisonReste = Saison.texteReste(os.time()),
		timeLeft = timeLeft,
		phase = Regles.phase(timeLeft, MATCH_TIME, prolongation),
		-- PREAVIS DE DOUBLE ELIXIR : le basculement etait annonce A L'INSTANT ou il arrive, alors
		-- que toute la decision se prend AVANT (garder son elixir pour partir en poussee des la
		-- bascule). Le compte a rebours est calcule ICI : le client n'a pas la duree du match.
		preavisDouble = Regles.texteAvantDouble(timeLeft, MATCH_TIME, prolongation),
		-- PREAVIS DE FIN : « PROLONGATION DANS n » si les couronnes sont a egalite, « FIN DANS n »
		-- sinon. Les dernieres secondes ne se jouent pas pareil dans les deux cas.
		preavisFin = Regles.texteAvantFin(timeLeft, crowns(1), crowns(2), prolongation),
		monCamp = monCamp,
		spectateur = false,
		-- TUTORIEL TERMINE : le hub ramene le joueur au menu tout seul (Tutoriel.retourMenu).
		tutoTermine = (tutoFiniPour ~= nil and tutoFiniPour == player) or nil,
		-- COUP D'ENVOI : « on attend l'adversaire » puis « 3, 2, 1 », les deux camps en meme temps.
		attente = attenteTexte,
		compteARebours = attenteSecondes,
		serveurDeMatch = Matchmaking.estServeurDeMatch(game),
		-- GASPILLAGE EN DIRECT : le bilan de fin arrive trop tard pour corriger la faute.
		gaspilleEnCours = teams[monCamp].bilan and teams[monCamp].bilan.gaspille or 0,
		-- LIRE LE DUEL : elixir adverse ESTIME (temps ecoule moins cartes vues), cartes que
		-- l'adversaire a deja posees, et alerte quand une de MES tours est en danger.
		elixirAdverse = lectureElixir(3 - monCamp),
		cartesAdverses = lectureCartes(3 - monCamp),
		-- DEJA VUE : combien de fois chacune de ces cartes est passee depuis le debut.
		passagesAdverses = lecturePassages(3 - monCamp),
		-- SON PROPRE CYCLE : le joueur voyait ce que l'ADVERSAIRE avait pose, mais pas ce que
		-- lui-meme avait joue. Or compter SON cycle (qu'ai-je deja sorti, qu'est-ce qui revient)
		-- est exactement le meme travail, et c'est celui qui decide de la prochaine poussee.
		mesCartes = lectureCartes(monCamp),
		mesPassages = lecturePassages(monCamp),
		alerte = lectureAlerte(monCamp),
		-- INACTIVITE : l'inactif doit pouvoir se rattraper (une partie qui s'arrete sans preavis
		-- passe pour un bug), et celui qui joue doit comprendre POURQUOI rien n'arrive en face.
		avertissementInactif = Inactif.avertissement(
			Inactif.resteAvantFin(teams[monCamp].silence or 0, MATCH_TIME - timeLeft)),
		adversaireInactif = occupant[3 - monCamp] ~= nil
			and Inactif.texteAttente(teams[3 - monCamp].silence or 0, MATCH_TIME - timeLeft) or nil,
		-- GAIN de la partie finie (pieces, trophees) et etat de la revanche.
		gain = recompenses[player],
		-- DERNIERE GARDE : la regle change la cadence du Roi et n'etait visible NULLE PART.
		gardeMoi = Garde.engagee(etatTours(monCamp)) or nil,
		gardeLui = Garde.engagee(etatTours(3 - monCamp)) or nil,
		-- QUETE DU JOUR TERMINEE : elle se finissait en silence, et sa recompense (qui se reclame
		-- au menu) restait sur place sans que rien ne le dise. L'annonce s'eteint toute seule.
		queteFinie = Economie.queteAnnonce(player),
		-- RECAPITULATIF : ce que chacun a fait de sa partie, plus UNE phrase pour progresser.
		bilanMoi = result and Bilan.vue(teams[monCamp].bilan) or nil,
		bilanLui = result and Bilan.vue(teams[3 - monCamp].bilan) or nil,
		conseil = result and Bilan.conseil(teams[monCamp].bilan, teams[3 - monCamp].bilan) or nil,
		-- PARTAGE : le resume copiable de la partie qu'on vient de jouer, et son code.
		partage = result and resumePartage(monCamp) or nil,
		partageBouton = result and Partage.libelleBouton() or nil,
		revancheMoi = revanche[player] == true,
		-- REVANCHE PERDUE : j'ai demande, il n'y a plus personne en face. Sans ce mot, le bouton
		-- redevenait « Rejouer » en silence et relancait contre le robot.
		revanchePerdue = result ~= nil and (
			Duel.revanchePerdue(revanche[player] == true,
				occupant[3 - monCamp] ~= nil or humainAbsent[3 - monCamp] == true)
			-- ATTENTE EXPIREE : il n'a jamais repondu. On ne laisse personne devant un bouton sans
			-- fin — c'est ce qui se passait, sans aucune limite de temps.
			or (revanche[player] == true and revancheEtat[player] ~= nil
				and Duel.revancheExpiree(revancheEtat[player].t, os.clock()) == true)),
		-- REFUS EXPLICITE d'en face : « il reflechit » et « il ne veut pas » se ressemblaient
		-- exactement. Le refus libere tout de suite celui qui attend.
		-- Relance bloquee : son adversaire est coupe et peut encore revenir. Sans ce mot, le
		-- bouton semblerait casse.
		relanceBloquee = (result ~= nil and reprises[3 - monCamp] ~= nil) or nil,
		revancheRefusee = (result ~= nil and occupant[3 - monCamp] ~= nil
			and revancheEtat[occupant[3 - monCamp]] ~= nil
			and revancheEtat[occupant[3 - monCamp]].refus == true) or nil,
		-- Compte a rebours de MA demande : l'attente est bornee, et cela se voit.
		revancheReste = (result ~= nil and revanche[player] == true and revancheEtat[player] ~= nil)
			and Duel.resteRevanche(revancheEtat[player].t, os.clock()) or nil,
		revancheLui = occupant[3 - monCamp] ~= nil and revanche[occupant[3 - monCamp]] == true,
		adversaireHumain = occupant[3 - monCamp] ~= nil or humainAbsent[3 - monCamp] == true,
		-- COUPURE EN FACE : l'adversaire doit savoir POURQUOI plus rien n'arrive, et combien de
		-- temps il reste avant que la partie lui revienne.
		-- COUPURE EN FACE. Si la partie est EN PAUSE, on le dit avec ce mot : sans lui, on croit
		-- que son propre jeu a gele — plus rien ne bouge — et on quitte a son tour.
		adversaireAbsent = reprises[3 - monCamp]
			and ((teams[3 - monCamp] and teams[3 - monCamp].enPause)
				and Reprise.textePause(Reprise.reste(reprises[3 - monCamp], os.clock()))
				or Reprise.texteAbsence(Reprise.reste(reprises[3 - monCamp], os.clock()))) or nil,
		crownsYou = crowns(monCamp),
		crownsEnemy = crowns(3 - monCamp),
		-- CHAMPION : son bouton (nom, cout, recharge), nil s'il n'y en a pas ou s'il est tombe
		champion = apparence.championVue and apparence.championVue(monCamp) or nil,
		nomAdversaire = nomAdversaire(monCamp),
		-- PHOTO DE PROFIL : le client a besoin de l'identifiant de compte pour la demander a Roblox.
		-- Le robot n'en a pas — il aura sa pastille, pas une photo.
		userIdAdversaire = occupant[3 - monCamp] and occupant[3 - monCamp].UserId or nil,
		adversaireEstRobot = occupant[3 - monCamp] == nil,
		-- QUI EST EN FACE : la mention « ROBOT » vit dans la FICHE de l'adversaire
		-- (Adversaire.fiche), affichee sous le score. Le champ `badgeAdversaire` envoye ici en
		-- plus n'etait LU par aucun ecran depuis ce deplacement : c'etait de la donnee envoyee
		-- dix fois par seconde pour rien. Retire le 2026-09-20.
		annonceAdversaire = Adversaire.annonce(occupant[3 - monCamp] and occupant[3 - monCamp].DisplayName,
			teams[3 - monCamp] and teams[3 - monCamp].profilRobot and teams[3 - monCamp].profilRobot.nom),
		-- Avec le BONUS contre un joueur et l'issue : la victoire dit ce qu'elle a rapporte (ou laisse).
		mentionAdversaire = occupant[3 - monCamp]
			and Adversaire.mentionJoueur(occupant[3 - monCamp].DisplayName, Economie.BONUS_HUMAIN,
				vainqueur ~= nil and vainqueur == monCamp,
				Arenes.facteur("victoire", Economie.tropheesDe(player), Economie.tropheesDe(occupant[3 - monCamp]), true))
			or Adversaire.mention(nil, Economie.BONUS_HUMAIN, vainqueur ~= nil and vainqueur == monCamp, Arenes.PART_ROBOT),
		-- L'ENJEU EN TROPHEES, AVANT la fin : calcule par la meme regle que le gain reel (Arenes).
		-- Le joueur decouvrait son gain a la fin, sans savoir s'il jouait gros ou petit.
		enjeu = (not result) and Adversaire.enjeu(
			Arenes.variation("victoire", Economie.tropheesDe(player),
				occupant[3 - monCamp] and Economie.tropheesDe(occupant[3 - monCamp]) or nil,
				occupant[3 - monCamp] ~= nil),
			Arenes.variation("defaite", Economie.tropheesDe(player),
				occupant[3 - monCamp] and Economie.tropheesDe(occupant[3 - monCamp]) or nil,
				occupant[3 - monCamp] ~= nil)) or nil,
		-- QUI EST EN FACE, EN CHIFFRES : on affrontait un nom, sans savoir si perdre etait normal
		-- ni si gagner valait quelque chose. Ses trophees, et le niveau moyen de son deck (le meme
		-- que celui qui sert a l'appariement). Le robot, lui, annonce son palier.
		ficheAdversaire = Adversaire.fiche(occupant[3 - monCamp] and occupant[3 - monCamp].DisplayName,
			teams[3 - monCamp] and teams[3 - monCamp].profilRobot and teams[3 - monCamp].profilRobot.nom,
			occupant[3 - monCamp] and Economie.tropheesDe(occupant[3 - monCamp]) or nil,
			teams[3 - monCamp] and teams[3 - monCamp].niveauTours or nil),
		ecartNiveau = Adversaire.ecartNiveau(teams[monCamp] and teams[monCamp].niveauTours,
			teams[3 - monCamp] and teams[3 - monCamp].niveauTours),
		-- SALUT D'OUVERTURE : le duel commencait sans un mot. On l'invite, une fois, au debut,
		-- et seulement face a un humain (saluer une machine n'a aucun sens).
		inviteSalut = Emotes.inviteSalut(MATCH_TIME - timeLeft, occupant[3 - monCamp] ~= nil,
			saluts[player] == true),
		-- le signalement vise l'adversaire du moment, ou le dernier connu apres la partie
		signalable = (occupant[3 - monCamp] ~= nil) or (dernierAdversaire[player] ~= nil),
		chatVisible = occupant[3 - monCamp] ~= nil, -- chat seulement face a un humain
		result = texteFin(monCamp),
		combat = combat,
		-- combat vu de CE joueur : ce qu'il declenche, et ce qu'il subit
		combatMoi = combatCamp[monCamp],
		combatLui = combatCamp[3 - monCamp],
	})
end

-- CADENCE DE POSE : un client modifie pouvait marteler cet evenement des centaines de fois par
-- seconde. Chaque appel parcourt les entites (zone de pose, batiments voisins) : de quoi ralentir
-- la partie de l'ADVERSAIRE. Au plus 10 demandes par seconde et par joueur, ce qui reste tres
-- au-dessus de ce qu'un humain peut cliquer.
local dernieresPoses = {}
PlayCard.OnServerEvent:Connect(function(player, handIndex, pos)
	if typeof(handIndex) ~= "number" or typeof(pos) ~= "Vector3" then
		return
	end
	-- une position hors bornes ou non finie (NaN) n'a rien a faire dans le calcul
	if pos.X ~= pos.X or pos.Z ~= pos.Z or pos.Magnitude > 1e4 then
		return
	end
	local maintenant = os.clock()
	if dernieresPoses[player] and maintenant - dernieresPoses[player] < 0.1 then
		return
	end
	dernieresPoses[player] = maintenant
	local camp = equipeDe[player]
	if not camp then
		-- SPECTATEUR : sa demande etait jetee SANS UN MOT. On repond, comme pour tout autre refus :
		-- un silence laisse croire a une panne. Le texte vient du module partage.
		RefusEvent:FireClient(player, Spectateur.REFUS_POSE)
		return
	end
	local ok, motif = tryPlay(camp, math.floor(handIndex), pos)
	if not ok then
		RefusEvent:FireClient(player, motif or "pose refusee")
	end
end)

-- EMOTES RAPIDES (facon Clash Royale) : une bulle au-dessus de la tour du Roi de l'expediteur.
-- Liste FERMEE : le client envoie un identifiant, jamais un texte libre (pas de moderation a faire).
-- La liste et le delai vivent maintenant dans Shared/Emotes : ils etaient DUPLIQUES ici et dans le
-- client, donc condamnes a diverger (un bouton que le serveur refuse, ou une emote inatteignable).
local EMOTE_DELAI = Emotes.DELAI
apparence.derniereEmote = {} -- instant de la derniere emote de chaque joueur
local function emoteAutorisee(id, derniere, maintenant)
	return Emotes.autorisee(id, derniere, maintenant)
end

-- ANCRE D'EMOTE : une part invisible posee au-dessus du Roi, qui SURVIT a sa destruction. La bulle
-- y etait accrochee directement : Roi detruit, plus aucune emote — exactement au moment ou l'on
-- veut dire « bien joue ».
local ancresEmote = {}
local function ancreEmote(camp)
	local a = ancresEmote[camp]
	if a and a.Parent then
		return a
	end
	local roi = teams[camp] and teams[camp].towers[3]
	local z = (camp == 1) and -28 or 28
	local pos = (roi and roi.part and roi.part.Parent) and (roi.part.Position + Vector3.new(0, 6, 0))
		or Vector3.new(0, 10, z)
	a = makePart({ Name = Emotes.ANCRE, Size = Vector3.new(0.2, 0.2, 0.2), Position = pos,
		Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	ancresEmote[camp] = a
	return a
end

local function afficherEmote(camp, texte)
	local support = ancreEmote(camp)
	if not (support and support.Parent) then
		return
	end
	local ancienne = support:FindFirstChild("BulleEmote")
	if ancienne then
		ancienne:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BulleEmote"
	gui.Size = UDim2.new(0, 120, 0, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundColor3 = Color3.new(1, 1, 1)
	l.TextColor3 = teamColor(camp)
	l.Text = texte
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Parent = gui
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0.4, 0)
	coin.Parent = l
	gui.Parent = support
	task.delay(2.5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- CAPACITE DE CHAMPION (module Champions). Le client ne fait que DEMANDER : le serveur verifie
-- champion vivant, elixir et recharge, puis applique l'effet. Dans une FONCTION : ses variables
-- ne comptent pas dans les 200 locales de ce fichier ; ses points d'entree vivent dans `apparence`.
;(function()
	local Champions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Champions"))
	local function etatDe(camp)
		local ch = teams[camp] and teams[camp].champion
		if not ch then
			return nil
		end
		ch.vivant = ch.e ~= nil and ch.e.alive ~= false and ch.e.hp ~= nil and ch.e.hp > 0
		return ch
	end
	function apparence.championVue(camp)
		local ch = etatDe(camp)
		return ch and Champions.vue(ch, teams[camp].elixir, horloge) or nil
	end
	function apparence.activerCapacite(camp)
		local ch = etatDe(camp)
		local ok, motif = Champions.peutActiver(ch, teams[camp] and teams[camp].elixir, horloge)
		if not ok then
			return false, motif
		end
		local c = Champions.CAPACITES[ch.capacite]
		teams[camp].elixir -= c.cout
		ch.derniere = horloge
		local e = ch.e
		if c.effet == "bouclier" then
			Statuts.poserBouclier(e, c.valeur)
			Effets.blinder(e.part, e.part.Size, Statuts.opaciteBouclier(e), Statuts.epaisseurBouclier(e))
		elseif c.effet == "gel" then
			for _, x in ipairs(entities) do
				if x.team ~= camp and x.alive ~= false and not x.isBuilding and x.part
					and (x.part.Position - e.part.Position).Magnitude <= c.rayon then
					Statuts.appliquer(x, "gel", { duree = c.duree }, horloge)
					Effets.givrer(x.part, x.part.Size)
				end
			end
		end
		-- LE GESTE SE VOIT : onde de GIVRE jusqu'au rayon reel pour le Rugissement, onde doree sinon
		local arene = workspace:FindFirstChild("Arena") or workspace
		if c.effet == "gel" then
			Effets.ondeGivre(arene, e.part.Position, c.rayon)
		else
			Effets.tourDetruite(arene, e.part.Position, Color3.fromRGB(255, 205, 60))
		end
		print(string.format("[CHAMPION] camp %d active %s", camp, c.nom))
		return true
	end
	local ev = Instance.new("RemoteEvent")
	ev.Name = "Capacite"
	ev.Parent = remotes
	ev.OnServerEvent:Connect(function(player)
		local camp = equipeDe[player]
		if camp then
			apparence.activerCapacite(camp)
		end
	end)
	-- CAPTURE (build.py --champion) : le Roi Tralalero est pose devant mon Roi, puis sa capacite est
	-- activee par le VRAI chemin (activerCapacite), elixir et recharge compris.
	if ReplicatedStorage:FindFirstChild("BRR_CHAMPION") then
		task.spawn(function()
			while not (teams[1] and teams[1].towers and #teams[1].towers > 0) do
				task.wait(0.5)
			end
			-- cale sur l arrivee du joueur : la photo (vers 30 s) tombe PENDANT la recharge
			while not occupant[1] do
				task.wait(0.5)
			end
			task.wait(14)
			local roi = teams[1].towers[3].part.Position
			-- MILIEU de ma moitie (35 % vers le Roi) : a 60 %, le cercle du Rugissement passait derriere les
			-- tours et le bandeau « Hors de ta zone de pose » (capture du 2026-09-21)
			local ici = Vector3.new(roi.X, roi.Y, roi.Z * 0.35)
			local id = ReplicatedStorage.BRR_CHAMPION.Value
			spawnGroupe(Cards.byId[id] or Cards.byId.RoiTralalero, 1, ici)
			-- ENNEMIS AUTOUR : trois unites adverses posees a quelques studs, par le vrai chemin, pour
			-- que le Rugissement ait quelque chose a geler (et que le bouclier ait quelque chose a encaisser)
			-- Poses 0,3 s AVANT le cri, autour de la position REELLE du champion a cet instant : poses
			-- 1,9 s avant, ces Tralalero (11 studs/s) avaient deja depasse le cercle de 7 studs et filaient
			-- vers mon Roi (capture du 2026-09-21 : aucune unite gelee dans le cercle).
			task.wait(1.6) -- cri toujours 1,9 s apres la pose du champion : la photo reste calee
			local centre = teams[1].champion and teams[1].champion.e.part.Position or ici
			local decor = {}
			for i, autre in ipairs({ "Tralalero", "Tralalero", "Tralalero" }) do
				local a = math.rad(90 + (i - 2) * 70) * -math.sign(roi.Z) -- en eventail, cote riviere
				decor[i] = spawnGroupe(Cards.byId[autre], 2, centre + Vector3.new(math.cos(a) * 4, 0, math.sin(a) * 4))
			end
			task.wait(0.3)
			teams[1].elixir = math.max(teams[1].elixir, 5)
			print("[CHAMPION] activation de test :", apparence.activerCapacite(1))
			-- PHOTO : le client de test (BRR_Capture) la prend a CET instant, 0,3 s apres le cri
			task.delay(0.3, function()
				ReplicatedStorage:SetAttribute("BRR_PHOTO", os.clock())
				print("[CHAMPION] photo demandee")
			end)
			for _, groupe in ipairs(decor) do
				for _, u in ipairs(groupe or {}) do
					local ch = teams[1].champion and teams[1].champion.e.part
					print(string.format("[CHAMPION] ennemi a %.1f studs du champion, gele=%s", ch and (u.part.Position - ch.Position).Magnitude or -1,
						tostring(Statuts.actif(u, "gel", horloge) ~= nil and Statuts.actif(u, "gel", horloge) ~= false)))
				end
			end
			-- PHOTO DE L'ONDE (copie de test SEULEMENT) : l'onde dure 0,45 s et le debut de la rafale
			-- de photos derive de +-0,5 s d'une partie a l'autre (mesure du 2026-09-21). On REJOUE donc
			-- le meme visuel (Effets.ondeGivre, meme portee) toutes les 0,3 s pendant 1,8 s : aucun
			-- second gel, aucun effet de jeu, seulement de quoi tomber sur une onde.
			local ch = teams[1].champion
			if ch and ch.e and ch.e.part and ch.capacite == "rugissement" then
				for _ = 1, 6 do
					task.wait(0.3)
					Effets.ondeGivre(workspace:FindFirstChild("Arena") or workspace, ch.e.part.Position, 7)
				end
			end
			-- les ennemis poses pour la photo du GEL ont servi : on les retire (vrai chemin, damage)
			-- une fois le gel fini, sinon ils tuent le champion avant la fin de sa recharge et le
			-- bouton PRET ne se verrait jamais (mesure du 2026-09-21 : champion tombe a 3 s de la fin)
			task.wait(1.2) -- 3 s au total apres le cri (1,8 s de rejeu d onde compris)
			for _, groupe in ipairs(decor) do
				for _, u in ipairs(groupe or {}) do
					if u.alive then
						damage(u, u.hp + 1)
					end
				end
			end
		end)
	end
end)()

EmoteEvent.OnServerEvent:Connect(function(player, id)
	local camp = equipeDe[player]
	if not camp then
		return -- spectateur : pas de tour, pas d'emote
	end
	local maintenant = os.clock()
	if not emoteAutorisee(id, apparence.derniereEmote[player], maintenant) then
		return
	end
	-- EMOTE PREMIUM : seulement si le joueur l'a achetee (le client ne montre que celles-la)
	if not apparence.Cosmetiques.emotePermise(Emotes, Economie.cosmetiques(player), id) then
		return
	end
	apparence.derniereEmote[player] = maintenant
	if id == Emotes.SALUT then
		saluts[player] = true -- il a salue : on ne le lui propose plus
	end
	afficherEmote(camp, Emotes.texte(id))
end)
Players.PlayerRemoving:Connect(function(player)
	apparence.derniereEmote[player] = nil
	dernieresPoses[player] = nil
end)

-- ECHO DE LATENCE. Cadence bornee (au plus 4 par seconde et par joueur) : sans cela, un client
-- modifie pourrait inonder le serveur d'allers-retours gratuits.
local dernierPing = {}
PingEvent.OnServerEvent:Connect(function(player, jeton)
	if typeof(jeton) ~= "number" then
		return
	end
	local maintenant = os.clock()
	if dernierPing[player] and maintenant - dernierPing[player] < 0.25 then
		return
	end
	dernierPing[player] = maintenant
	PingEvent:FireClient(player, jeton)
end)
Players.PlayerRemoving:Connect(function(player)
	dernierPing[player] = nil
	-- Tables indexees par JOUEUR : sans ce nettoyage, elles gardaient une entree par joueur ayant
	-- traverse le serveur, indefiniment.
	dernierAdversaire[player] = nil
	revancheEtat[player] = nil
end)

PronosticEvent.OnServerEvent:Connect(function(player, camp)
	-- PARIS FERMES une fois la partie engagee : sinon on parie a la derniere seconde sur une issue
	-- deja evidente, et le pronostic rapporte des pieces sans jamais rien risquer.
	if pronosticAccepte(camp, equipeDe[player] ~= nil, pronostics[player] ~= nil, result ~= nil,
		Spectateur.parisOuverts(timeLeft, MATCH_TIME, crowns(1), crowns(2))) then
		pronostics[player] = camp
	end
end)
Players.PlayerRemoving:Connect(function(player)
	pronostics[player] = nil
	suivi[player] = nil
end)

RestartEvent.OnServerEvent:Connect(function(player, reponse)
	-- Seul un joueur qui TIENT un camp relance la partie. Un spectateur (aucun camp libre a son
	-- arrivee) pouvait sinon remettre a zero la partie des deux autres. Le controle est ICI, cote
	-- serveur : cacher le bouton cote client ne protege de rien, n'importe quel client peut envoyer
	-- l'evenement.
	local camp = equipeDe[player]
	if not camp then
		print("[BRR] Rejouer refuse : " .. player.Name .. " n'a pas de camp")
		return
	end
	if not result then
		return
	end
	-- SERVEUR RESERVE : ce serveur n'accueille qu'UN match, tout le monde rentre au hub. Relancer
	-- ici donnerait une partie que la teleportation coupe quelques secondes plus tard.
	if Matchmaking.estServeurDeMatch(game) then
		print("[BRR] Rejouer refuse : ce serveur ne joue qu'un match, retour au hub")
		return
	end
	local autre = occupant[3 - camp]
	-- REFUS EXPLICITE. Sans lui, la seule facon de dire non etait de PARTIR — et celui qui
	-- attendait ne distinguait pas « il reflechit » de « il ne veut pas ». Le refus le libere
	-- tout de suite, au lieu de le laisser regarder un compte a rebours deja perdu.
	if reponse == "non" then
		revancheEtat[player] = { refus = true }
		revanche[player] = nil
		print("[BRR] " .. player.Name .. " refuse la revanche")
		return
	end
	-- L'ADVERSAIRE EST COUPE : sa partie l'attend, et son camp lui est RESERVE. Relancer ici
	-- effacerait les deux (resetMatch remet `reprises` a zero) alors qu'il n'a rien pu valider.
	if not Duel.peutRelancer(reprises[3 - camp] ~= nil) then
		print("[BRR] Rejouer refuse : le camp " .. (3 - camp) .. " est reserve a un joueur coupe")
		return
	end
	revanche[player] = true
	revancheEtat[player] = { t = os.clock() }
	if not Duel.revanchePrete(autre ~= nil, true, autre ~= nil and revanche[autre] == true) then
		print(string.format("[BRR] %s demande la revanche : on attend %s (%d s)",
			player.Name, autre.Name, Duel.DELAI_REVANCHE))
		return
	end
	revanche = {}
	revancheEtat = {}
	recompenses = {}
	resetMatch()
end)

resetMatch()

-- Copie de test (capture 3D) : un trio IMMOBILE montre l'ecart a l'apparition ; deux trios en marche
-- montrent les couloirs. Mesure 2026-09-14 : un trio toutes les 3 s gagnait la partie en ~25 s et
-- entassait tout sur le Roi ennemi — la capture ne prouvait plus rien.
if game:GetService("ReplicatedStorage"):FindFirstChild("BRR_AUTOTEST")
	and not game:GetService("ReplicatedStorage"):FindFirstChild("BRR_PARTIE") then
	task.spawn(function()
		local chimp = Cards.byId.Chimpanzini
		task.wait(3)
		-- galerie : les 8 personnages immobiles en ligne, pour juger les silhouettes sur une capture
		-- build.py --galerie=A,B : seulement ces cartes, serrees au centre, sans trio ni vagues
		local filtre = ReplicatedStorage:FindFirstChild("BRR_GALERIE")
		local liste = Cards.list
		if filtre then
			liste = {}
			for id in string.gmatch(filtre.Value, "[^,]+") do
				table.insert(liste, Cards.byId[id])
			end
		end
		for i, card in ipairs(liste) do
			-- les deux camps : camp 1 cote joueur, camp 2 cote ennemi (preuve de la couleur du disque)
			for camp, z in pairs({ [1] = -7, [2] = 7 }) do
				local pos = filtre and Vector3.new((i - (#liste + 1) / 2) * 10, 0, z)
					or Vector3.new(-HALF_W + 4 + (i - 1) * ((HALF_W * 2 - 8) / (#liste - 1)), 0, z)
				local unites = card.count > 1 and spawnGroupe(card, camp, pos) or { spawnUnit(card, camp, pos, Vector3.zero) }
				for _, e in ipairs(unites) do
					e.speed = 0
					-- rangee de test INACTIVE : ni attaque ni marche, sinon les deux rangees
					-- s'entretuaient et la moitie des modeles manquait sur la capture.
					e.active = false
				end
			end
		end
		-- LES STATUTS A L'IMAGE (build.py --galerie=... --effets) : la rangee du camp 2 porte les
		-- TROIS statuts, un par unite, dans l'ordre des X CROISSANTS : gel, poison, ralentissement
		-- (la camera regarde vers les z positifs, donc a l'ecran ils apparaissent en ordre
		-- INVERSE : flaque a gauche, bulle verte au milieu, gangue de glace a droite). La rangee
		-- du camp 2, au fond, reste libre. La capture montre donc la MEME carte quatre fois, et ce
		-- qui differe a l'ecran ne peut venir que du statut. Sans ce contraste cote a cote, une
		-- image de statut ne prouve rien.
		-- BOUCLIER A L'IMAGE (build.py --galerie=ScudoBanana,... --boucliers) : la rangee porte
		-- le MEME bouclier a trois etats d'usure — plein, a moitie, presque cede. La coque
		-- maigrit et s'efface avec lui, donc l'image montre la regle elle-meme.
		if ReplicatedStorage:FindFirstChild("BRR_BOUCLIERS") then
			task.spawn(function()
				task.wait(1)
				local rangee = {}
				for _, e in ipairs(entities) do
					if e.alive and e.team == 1 and e.active == false and (e.bouclierMax or 0) > 0 then
						table.insert(rangee, e)
					end
				end
				table.sort(rangee, function(a, b)
					return a.part.Position.X < b.part.Position.X
				end)
				local parts = { 1, 0.5, 0.12 }
				for i, e in ipairs(rangee) do
					e.bouclier = math.floor(e.bouclierMax * (parts[(i - 1) % 3 + 1]))
					Effets.majBouclier(e.part, Statuts.opaciteBouclier(e), Statuts.epaisseurBouclier(e))
					print(string.format("[EFFETS] bouclier : unite %d part=%.2f opacite=%.2f epaisseur=%.2f",
						i, Statuts.partBouclier(e), Statuts.opaciteBouclier(e), Statuts.epaisseurBouclier(e)))
				end
			end)
		end
		if ReplicatedStorage:FindFirstChild("BRR_EFFETS") then
			task.spawn(function()
				while true do
					local rangee = {}
					for _, e in ipairs(entities) do
						-- camp 1 : c'est la rangee la PLUS PROCHE de la camera. Marquee sur le camp 2, au
						-- fond, la difference etait trop petite pour se lire sur l'image.
						-- `active == false` : c'est la marque de la RANGEE DE GALERIE (posee inactive plus haut).
						-- Sans ce filtre, toute unite que le jeu fait apparaitre par ailleurs entre dans la
						-- rangee et DECALE l'ordre des statuts : l'image ne dit plus lequel est lequel.
						if e.alive and e.team == 1 and not e.isBuilding and e.active == false then
							table.insert(rangee, e)
						end
					end
					table.sort(rangee, function(a, b)
						return a.part.Position.X < b.part.Position.X
					end)
					for i, e in ipairs(rangee) do
						local quoi = (i - 1) % 3
						if quoi == 0 then
							Statuts.appliquer(e, "gel", { duree = Statuts.GEL_MAX }, horloge)
							Effets.givrer(e.part, e.part.Size)
						elseif quoi == 1 then
							Statuts.appliquer(e, "poison", { duree = 5, degats = 0, tic = 1 }, horloge)
							Effets.empoisonner(e.part, e.part.Size)
						else
							Statuts.appliquer(e, "lent", { duree = 5, part = 0.5 }, horloge)
							Effets.engourdir(e.part, e.part.Size)
						end
					end
					task.wait(1)
				end
			end)
		end
		if filtre then
			return
		end
		for _, e in ipairs(spawnGroupe(chimp, 1, Vector3.new(-6, 0, -12))) do
			e.speed = 0
		end
		for vague = 1, 2 do
			task.wait(7)
			if not result then
				spawnGroupe(chimp, 1, Vector3.new(4 * vague - 6, 0, -16))
			end
		end
	end)
end


-- SCENARIO D'EFFETS EN MOTEUR (build.py --autotest --effets).
-- Les bancs python prouvent les REGLES hors Studio ; ce scenario prouve qu'elles vivent REELLEMENT
-- dans le moteur : un batiment qui s'use et produit, une unite GELEE qui cesse d'avancer, un tir
-- qui MET DU TEMPS a arriver. Chaque fait est MESURE sur les entites, pas declare. Une ligne
-- [EFFETS] par mesure, lisible par un script.
-- CAPTURE DE LA MAIN (build.py --main-cout) : on impose une main de couts varies et un elixir BAS,
-- pour que la photo montre a la fois des cartes jouables et des cartes trop cheres. Le tirage etant
-- aleatoire, une capture ordinaire tombait au hasard sur quatre cartes payables ou quatre trop
-- cheres. Rien n'est mis en scene dans l'AFFICHAGE : le texte vient du vrai code de la main.
-- CAPTURE DES SEUILS (build.py --tours-abimees) : on abime les tours a des valeurs CHOISIES, de
-- part et d'autre des seuils, pour qu'une seule photo montre les trois etats (saine, basse,
-- critique). Les degats passent par damage(), donc par le vrai chemin : la jauge, le chiffre et
-- les couleurs sont ceux du jeu, pas une mise en scene.
-- CAPTURE DU COMPTE A REBOURS DES BATIMENTS (build.py --batiment) : deux batiments poses dans une
-- arene vide, l'un intact et l'autre presque fini — une seule photo montre donc l'anneau plein et
-- l'anneau en alerte. Ils sont poses par le VRAI chemin (spawnUnit), et leur usure suit son cours.
-- CAPTURE DE L'ELAN (build.py --charge) : deux unites a charge lachees a deux secondes d'ecart,
-- dans une arene vide. Sur une seule photo, l'une prend encore son elan (disque pale qui grandit)
-- et l'autre est LANCEE (disque rouge). Rien n'est mis en scene : elles courent par le vrai
-- chemin, et le disque suit ce que le serveur calcule.
-- CAPTURE DU MESSAGE DE COURONNE (build.py --couronne) : le message ne vit que 1,9 s, on ne peut
-- pas le photographier au hasard. On ABAT une tour adverse a un instant connu, par le vrai chemin
-- (damage), et la capture tombe juste apres. Le texte affiche vient du module Couronnes.
if ReplicatedStorage:FindFirstChild("BRR_COURONNE") then
	task.spawn(function()
		-- Mesure du 2026-09-21 : attendre 6 s depuis le DEMARRAGE du serveur tombait avant que la
		-- partie cree les tours adverses, et rien n'etait abattu. On attend donc les tours, puis
		-- on laisse passer 21 s pour tomber dans la rafale de studio-capture-3d.ps1 (-Secondes 30).
		while not (teams[2] and teams[2].towers and #teams[2].towers > 0) do task.wait(0.5) end
		task.wait(21)
		-- la DERNIERE tour laterale : la premiere est sous le panneau des joueurs, en haut a droite
		local cible
		for _, tw in ipairs(teams[2] and teams[2].towers or {}) do
			if tw.alive and not tw.isKing then cible = tw end
		end
		if cible then
			damage(cible, cible.hp + 1)
			print("[COURONNE] tour adverse abattue pour la capture")
		end
	end)
end

-- CAPTURE DE LA MONTEE D'ARENE (build.py --montee) : on abat la tour du ROI adverse, ce qui
-- termine la partie par une vraie victoire ; Economie.recompenser verse alors la recompense de
-- palier et l'ecran de fin affiche les lignes rendues par Arenes.lignesMontee.
if ReplicatedStorage:FindFirstChild("BRR_MONTEE") or ReplicatedStorage:FindFirstChild("BRR_PLEINS") then
	task.spawn(function()
		task.wait(6)
		for _, tw in ipairs(teams[2] and teams[2].towers or {}) do
			if tw.alive and tw.isKing then
				damage(tw, tw.hp + 1)
				print("[MONTEE] tour du roi adverse abattue : victoire mise en scene")
				break
			end
		end
	end)
end

-- CAPTURE DE LA QUETE TERMINEE (build.py --quete-finie) : l'annonce ne vit que 6 s et depend de
-- la quete du JOUR. On prend la premiere quete du jour, on l'amene a un cran de sa cible, puis on
-- pose le dernier cran par le VRAI chemin (Economie.avancerQuete) : c'est le serveur qui decide
-- que la quete est finie, rien n'est mis en scene dans l'affichage.
if ReplicatedStorage:FindFirstChild("BRR_QUETE") then
	task.spawn(function()
		task.wait(5)
		local joueur = Players:GetPlayers()[1]
		local quete = Economie.quetesDuJour(Economie.jourDe(os.time()))[1]
		if joueur and quete then
			Economie.avancerQuete(joueur, quete.id, quete.cible - 1)
			task.wait(1)
			Economie.avancerQuete(joueur, quete.id, 1)
			print("[QUETE] quete " .. quete.id .. " terminee pour la capture")
		end
	end)
end

-- CAPTURE DE LA DERNIERE GARDE (build.py --garde) : on abat les DEUX tours de princesse du camp
-- adverse par le vrai chemin (damage). Le serveur engage alors sa derniere garde, et l'ecran
-- affiche ce que la regle vient de decider — rien n'est mis en scene dans l'affichage.
-- --garde vise le camp ADVERSE (bandeau rouge), --garde-moi le camp du JOUEUR (bandeau or) : les
-- deux etats opposes doivent pouvoir se photographier separement.
if ReplicatedStorage:FindFirstChild("BRR_GARDE") or ReplicatedStorage:FindFirstChild("BRR_GARDE_MOI") then
	task.spawn(function()
		task.wait(6)
		local campVise = ReplicatedStorage:FindFirstChild("BRR_GARDE_MOI") and 1 or 2
		for _, tw in ipairs(teams[campVise] and teams[campVise].towers or {}) do
			if tw.alive and not tw.isKing then
				damage(tw, tw.hp + 1)
				task.wait(0.4)
			end
		end
		print("[GARDE] deux tours de princesse du camp " .. campVise .. " abattues pour la capture")
	end)
end

-- CAPTURE DE L'ANNEAU DE DEPLOIEMENT (build.py --deploiement) : l'anneau ne vit que 0,45 s. On
-- pose des unites EN CONTINU, a intervalle plus court que ce delai : a n'importe quel instant,
-- plusieurs anneaux sont a des stades differents sur la photo. Rien n'est mis en scene dans
-- l'affichage — ce sont de vraies poses, par spawnUnit.
if ReplicatedStorage:FindFirstChild("BRR_DEPLOIEMENT") then
	task.spawn(function()
		-- TROIS poses seulement, espacees de 0,15 s et calees JUSTE avant l'instant de capture :
		-- les trois anneaux sont alors a trois stades differents sur la meme photo. Une pose en
		-- boucle avait noyé la scene sous trente unites (capture cap-deploiement.png).
		-- Trois poses calees pour ENCADRER la fin de l'invulnerabilite (0,35 s) : au moment de
		-- la photo, une unite est encore intouchable (anneau BLANC) et une autre ne l'est plus
		-- (anneau OR), alors que les deux sont encore en deploiement.
		-- MODE GALERIE : une seule unite, posee a l'endroit que vise le gros plan (0, -7), dans une
		-- arene vide. C'est la seule facon d'obtenir une photo ou la coque se lit : en partie
		-- normale, la melee et les unites lumineuses la noient (six captures du 2026-09-21).
		if ReplicatedStorage:FindFirstChild("BRR_GALERIE") then
			-- Pose calee 0,15 s avant la capture (--capture-delai ne prend qu'un entier) : a cet
			-- instant l'unite est encore intouchable, donc la coque est la.
			task.wait(7.85)
			spawnUnit(Cards.byId.Boneca, 1, Vector3.new(0, 0, -7), Vector3.zero)
			task.wait(0.05)
			for _, e in ipairs(entities) do
				if e.anneauDeploiement then
					print(string.format("[DEPLOIEMENT] galerie : depuis=%.2f diametre=%.2f"
						.. " intouchable=%s", horloge - (e.poseT or 0),
						e.anneauDeploiement.Size.Y, tostring(Statuts.invulnerable(e, horloge))))
				end
			end
			return
		end
		task.wait(7.58)
		for k = 1, 3 do
			-- z = -26 : EN ARRIERE de la melee. A z = -7 les poses tombaient au milieu des unites
			-- deja presentes et les anneaux devenaient illisibles (captures cap-invuln*.png du
			-- 2026-09-21). Boneca : modele sans partie lumineuse, qui n'eclaire pas son anneau.
			spawnUnit(Cards.byId.Boneca, 1, Vector3.new((k - 2) * 9, 0, -26), Vector3.zero)
			task.wait(0.2)
		end
		-- PREUVE HORS-IMAGE : l'arene est deja pleine d'effets lumineux, et un halo bleu existant
		-- pourrait passer pour l'anneau. On imprime donc ce que le serveur a REELLEMENT pose a
		-- l'instant de la photo : nom, diametre et transparence de chaque anneau vivant.
		local n, fantomes = 0, 0
		for _, e in ipairs(entities) do
			if e.anneauDeploiement then
				-- Une entite MORTE emporte sa part, donc son anneau : le champ reste, l'objet non.
				-- On ne compte comme visible que ce qui est encore dans le monde.
				if e.alive and e.anneauDeploiement.Parent then
					n = n + 1
					print(string.format("[DEPLOIEMENT] anneau %d : diametre=%.2f depuis=%.2f"
						.. " intouchable=%s", n, e.anneauDeploiement.Size.Y,
						horloge - (e.poseT or 0), tostring(Statuts.invulnerable(e, horloge))))
				else
					fantomes = fantomes + 1
				end
			end
		end
		print(string.format("[DEPLOIEMENT] trois unites posees : %d anneaux VISIBLES, %d champs"
			.. " restes sur des unites mortes", n, fantomes))
	end)
end

-- PREUVE DU NIVEAU DE SORT (build.py --sort-niveau) : on lance Pizza Bombarda par le VRAI chemin
-- (lancerSort) sur une unite ennemie isolee, et on imprime la perte de PV mesuree. Si le niveau
-- ne s'appliquait pas, la perte vaudrait 340 ; au niveau 3 (+20 %), elle doit valoir 408.
if ReplicatedStorage:FindFirstChild("BRR_SORT_NIVEAU") then
	task.spawn(function()
		task.wait(6)
		-- DEUX lancers identiques, niveau 1 puis niveau 3, sur deux cibles identiques placees au
		-- meme endroit : l'avantage de terrain (-15 % pres d'une tour) s'applique aux deux, et le
		-- RAPPORT des pertes isole l'effet du niveau (1,20 attendu). Une seule mesure brute (347)
		-- ne se lisait pas : elle melait le niveau et la reduction de terrain.
		teams[1].niveaux = teams[1].niveaux or {}
		local pertes = {}
		for _, niv in ipairs({ 1, 3 }) do
			teams[1].niveaux.PizzaBombarda = niv
			local cible = spawnUnit(Cards.byId.Patapim, 2, Vector3.new(0, 0, 20), Vector3.zero)
			task.wait(1) -- la grace a la pose protege une unite neuve : on l'attend
			local avant = cible.hp
			lancerSort(Cards.byId.PizzaBombarda, 1, cible.part.Position)
			pertes[niv] = avant - cible.hp
			print(string.format("[SORT_NIVEAU] Pizza Bombarda niveau %d : PV %d -> %d, perte=%d",
				niv, avant, cible.hp, pertes[niv]))
			cible.hp = 0
			task.wait(0.5)
		end
		print(string.format("[SORT_NIVEAU] rapport niveau 3 / niveau 1 = %.2f (attendu 1,20)",
			pertes[3] / math.max(1, pertes[1])))
	end)
end

if ReplicatedStorage:FindFirstChild("BRR_CHARGE") then
	task.spawn(function()
		task.wait(4)
		spawnUnit(Cards.byId.Cocofanto, 1, Vector3.new(-VOIE_X * 0.5, 0, -24), Vector3.zero)
		task.wait(2.5)
		spawnUnit(Cards.byId.Zibra, 1, Vector3.new(VOIE_X * 0.5, 0, -24), Vector3.zero)
		print("[CHARGE] deux unites a charge lachees pour la capture")
	end)
end

if ReplicatedStorage:FindFirstChild("BRR_BATIMENT") then
	task.spawn(function()
		task.wait(5)
		-- Poses en retrait (z = -20) : a -14 ils se melaient aux unites du robot et la photo ne
		-- montrait plus rien (capture du 2026-09-20).
		local neuf = spawnUnit(Cards.byId.TorreCannoli, 1, Vector3.new(-VOIE_X * 0.45, 0, -15), Vector3.zero)
		local presqueFini = spawnUnit(Cards.byId.TorreCannoli, 1, Vector3.new(VOIE_X * 0.45, 0, -15), Vector3.zero)
		-- La GRACE A LA POSE rend un batiment invulnerable un court instant : sans cette attente,
		-- les degats etaient avales et les deux batiments affichaient la meme duree (journal
		-- du 2026-09-20 : « neuf=40 s presque_fini=40 s »).
		task.wait(2)
		if presqueFini then
			-- On le vieillit par le VRAI chemin (degats) : le compte a rebours doit en tenir compte.
			damage(presqueFini, presqueFini.hp - presqueFini.maxHp * 0.12)
		end
		print(string.format("[BATIMENT] neuf=%s presque_fini=%s",
			neuf and Batiments.texteRestant(neuf.carte, neuf.hp, neuf.maxHp) or "nil",
			presqueFini and Batiments.texteRestant(presqueFini.carte, presqueFini.hp, presqueFini.maxHp) or "nil"))
	end)
end

if ReplicatedStorage:FindFirstChild("BRR_TOURS_ABIMEES") then
	task.spawn(function()
		task.wait(6)
		local parts = { 0.75, 0.40, 0.18 }
		for camp = 1, 2 do
			local n = 0
			for _, tw in ipairs(teams[camp] and teams[camp].towers or {}) do
				n = n + 1
				local cible = parts[n] or 0.5
				if tw.alive and tw.hp > tw.maxHp * cible then
					damage(tw, tw.hp - tw.maxHp * cible)
				end
			end
		end
		for camp = 1, 2 do
			for _, tw in ipairs(teams[camp] and teams[camp].towers or {}) do
				local c = tw.jaugeVie and tw.jaugeVie.Color
				print(string.format("[TOURS] camp%d %s : %s (%s) jauge=%s couleur=%s",
					camp, tw.label, Lecture.texteVie(tw.hp, tw.maxHp),
					Lecture.niveauVie(tw.hp, tw.maxHp),
					tw.jaugeVie and string.format("%.2f/%.2f", tw.jaugeVie.Size.X, tw.jaugeLarge) or "nil",
					c and string.format("%d,%d,%d", c.R * 255, c.G * 255, c.B * 255) or "nil"))
			end
		end
	end)
end

-- CAPTURE DES ETIQUETTES CHARGE / ASSASSIN (build.py --main-etiquettes) : on met en main les
-- quatre cartes concernees. L'etiquette affichee reste celle que Fiche.etiquette calcule, rien
-- n'est ecrit a la main dans l'affichage.
if ReplicatedStorage:FindFirstChild("BRR_MAIN_TAGS") then
	task.spawn(function()
		local mainTags = { "Cocofanto", "Cappuccino", "Zibra", "Bobritto" }
		while true do
			task.wait(0.5)
			if teams[1] then
				for k, id in ipairs(mainTags) do
					if Cards.byId[id] then
						teams[1].hand[k] = id
					end
				end
				teams[1].elixir = MAX_ELIXIR
			end
		end
	end)
end

if ReplicatedStorage:FindFirstChild("BRR_MAIN_COUT") then
	task.spawn(function()
		local mainVariee = { "Trippi", "Tralalero", "TorreCannoli", "Vacca" }
		while true do
			task.wait(0.5)
			if teams[1] then
				for k, id in ipairs(mainVariee) do
					if Cards.byId[id] then
						teams[1].hand[k] = id
					end
				end
				teams[1].elixir = 3
			end
		end
	end)
end

print("[EFFETS] drapeau=" .. tostring(ReplicatedStorage:FindFirstChild("BRR_EFFETS") ~= nil))
if ReplicatedStorage:FindFirstChild("BRR_EFFETS")
	and not ReplicatedStorage:FindFirstChild("BRR_GALERIE") then
	task.spawn(function()
		task.wait(3)
		local function dire(quoi, texte)
			print(string.format("[EFFETS] %s : %s", quoi, texte))
		end

		-- 1. BATIMENT POSE : il apparait, il s'use tout seul, il ne compte pas comme une tour.
		-- MAIN FORCEE : la main est tiree au hasard, donc une capture de l'interface ne montrait
		-- une carte a effet que par chance (capture du 2026-09-20 : quatre cartes ordinaires). On
		-- impose ici une main d'effets, pour que la verification ne depende plus du tirage.
		-- une carte de chaque famille : statut, sort, specialite, soutien
		local mainEffets = { "ScudoBanana", "GelatoGlaciale", "Ballerina", "Lirili" }
		for camp = 1, 2 do
			if teams[camp] then
				for k, id in ipairs(mainEffets) do
					teams[camp].hand[k] = id
				end
			end
		end
		local canon = spawnUnit(Cards.byId.TorreCannoli, 1, Vector3.new(-VOIE_X, 0, -14), Vector3.zero)
		dire("batiment", string.format("pose=%s pv=%d usure=%.1f pv/s batiment_pose=%s tour=%s",
			canon.label, canon.maxHp, canon.usure or 0, tostring(canon.estBatimentPose), tostring(canon.isBuilding)))
		local pvDepart = canon.hp
		local pompe = spawnUnit(Cards.byId.PompaElixir, 1, Vector3.new(0, 0, -25), Vector3.zero)
		teams[1].elixir = 0 -- plancher force : au plafond de 10, le gain de la pompe serait invisible
		local elixirAvantPompe = teams[1].elixir

		-- 2. CIBLE ENNEMIE : une unite rapide, posee en face du canon.
		local proie = spawnUnit(Cards.byId.Tralalero, 2, Vector3.new(-VOIE_X, 0, 6), Vector3.zero)
		local zDepart = proie.part.Position.Z
		task.wait(2)
		local zApres = proie.part.Position.Z
		dire("marche", string.format("avance_libre=%.2f studs en 2 s", math.abs(zApres - zDepart)))

		-- 3. GEL : on lance le sort sur elle et on mesure qu'elle N'AVANCE PLUS.
		lancerSort(Cards.byId.GelatoGlaciale, 1, proie.part.Position)
		local zGel = proie.part.Position.Z
		local facteur = Statuts.facteurVitesse(proie, horloge, 1)
		dire("gel", string.format("actif=%s facteur_vitesse=%.2f peut_agir=%s",
			tostring(Statuts.actif(proie, "gel", horloge)), facteur, tostring(Statuts.peutAgir(proie, horloge))))
		task.wait(1.2)
		dire("gel", string.format("avance_pendant_le_gel=%.2f studs en 1,2 s", math.abs(proie.part.Position.Z - zGel)))
		task.wait(1.5)
		dire("gel", string.format("apres_degel facteur_vitesse=%.2f (retour net attendu : 1.00)",
			Statuts.facteurVitesse(proie, horloge, 1)))

		-- 4. TIR QUI VOLE : on compte les projectiles EN VOL, puis on verifie qu'ils arrivent.
		task.wait(4) -- on laisse le canon tirer plusieurs fois
		dire("tirs", string.format("partis=%d arrives=%d anticipes=%d vol_moyen=%.2f s (0,00 s voudrait dire des degats instantanes)",
			journalTirs.partis, journalTirs.arrives, journalTirs.anticipes or 0,
			journalTirs.arrives > 0 and (journalTirs.volCumule / journalTirs.arrives) or 0))
		dire("cible", string.format("pv_restants=%d sur %d", math.max(0, math.floor(proie.hp)), proie.maxHp))

		-- 5. USURE et COLLECTEUR mesures apres coup.
		dire("batiment", string.format("usure_constatee=%.0f pv perdus, encore_vivant=%s",
			pvDepart - canon.hp, tostring(canon.alive)))
		task.wait(4) -- une periode de pompe entiere depuis la pose (8 s)
		dire("collecteur", string.format("versements_de_la_pompe=%.0f elixir (mesure directe) ; elixir_camp1 avant=%.1f maintenant=%.1f",
			(pompe.etatBatiment and pompe.etatBatiment.rendu) or 0, elixirAvantPompe, teams[1].elixir))
		dire("FIN", "scenario termine")
	end)
end

-- SCENARIO DE DUEL EN MOTEUR (build.py --autotest --deux-joueurs --court --duel).
-- Les bancs python prouvent les REGLES hors Studio (tools/test_pvp.py) ; ce scenario prouve
-- qu'elles vivent REELLEMENT dans le moteur : la partie reste GELEE tant que les deux camps ne
-- sont pas pris, le compte a rebours part pour les DEUX, les deux camps demarrent avec le MEME
-- elixir, et un depart en cours de duel donne la partie a l'autre. Une ligne [DUEL] par mesure.
if ReplicatedStorage:FindFirstChild("BRR_DUEL") then
	task.spawn(function()
		local function dire(quoi, texte)
			print(string.format("[DUEL] %s : %s", quoi, texte))
		end
		local vuAttente, vuCompte = false, {}
		local tDepart = nil
		-- 1. GEL : on echantillonne l'etat de depart jusqu'au coup d'envoi.
		for _ = 1, 400 do
			local gele, phase, reste = etatDepart()
			if gele then
				if phase == "adversaire" then
					vuAttente = true
				elseif phase == "depart" and reste and not vuCompte[reste] then
					vuCompte[reste] = true
					dire("compte_a_rebours", string.format("%d ... (joueurs=%d, chrono fige a %.0f s, elixir camp1=%.1f camp2=%.1f)",
						reste, joueursPresents(), timeLeft, teams[1].elixir, teams[2].elixir))
				end
			elseif joueursPresents() >= 2 then
				tDepart = horloge
				break
			end
			task.wait(0.1)
		end
		dire("attente_adversaire", tostring(vuAttente) .. " (vrai = la partie a bien attendu le second joueur)")
		local compte = 0
		for _ in pairs(vuCompte) do compte = compte + 1 end
		dire("coup_denvoi", string.format("paliers de compte a rebours vus=%d ; chrono au depart=%.0f s ; elixir camp1=%.1f camp2=%.1f (ecart=%.2f)",
			compte, timeLeft, teams[1].elixir, teams[2].elixir, math.abs(teams[1].elixir - teams[2].elixir)))
		if not tDepart then
			dire("FIN", "aucun coup d'envoi observe (deux joueurs necessaires)")
			return
		end
		-- 2. COUPURE RESEAU puis RETOUR, avant le forfait volontaire.
		task.wait(5)
		local partant = occupant[2]
		if not partant then
			dire("coupure", "aucun joueur humain sur le camp 2 : cas non joue")
		else
			local cartesAvant = teams[2].bilan.cartes
			quitter(partant, false) -- comme une deconnexion : NON volontaire
			task.wait(0.2)
			dire("coupure", string.format("%s saute a %.0f s : resultat=%s camp_reserve=%s reste=%.0f s robot_autorise=%s",
				partant.Name, horloge, tostring(result), tostring(reprises[2] ~= nil),
				Reprise.reste(reprises[2], os.clock()), tostring(Reprise.robotAutorise(reprises[2]))))
			task.wait(3)
			dire("coupure", string.format("apres 3 s d'absence : cartes_jouees_par_ce_camp=%d (avant=%d, une hausse voudrait dire qu'un robot a pris sa place) resultat=%s",
				teams[2].bilan.cartes, cartesAvant, tostring(result)))
			-- 3. IL REVIENT : son camp doit lui etre rendu, sans remise a neuf de la partie.
			local chronoAvant = timeLeft
			local campRepris = rejoindre(partant)
			dire("retour", string.format("camp_rendu=%s reserve_levee=%s chrono_avant=%.0f chrono_apres=%.0f (une partie remise a neuf remonterait a %d)",
				tostring(campRepris), tostring(reprises[2] == nil), chronoAvant, timeLeft, MATCH_TIME))
			-- 4. ABANDON VOLONTAIRE (bouton MENU) : la, le forfait tombe tout de suite.
			task.wait(1)
			quitter(partant, true)
			task.wait(0.2)
			dire("forfait", string.format("abandon volontaire : resultat=%s vainqueur=%s camp_libre=%s",
				tostring(result), tostring(vainqueur), tostring(occupant[2] == nil)))
		end
		-- 3. REVANCHE : avec un seul humain restant, un clic suffit ; a deux, il en faut deux.
		-- LECTURE DU DUEL, mesuree en moteur : l'estimation d'elixir suit-elle les cartes vues ?
		dire("lecture", string.format("elixir_estime_camp2=%d (vrai=%.1f) cartes_vues_de_lui=%d alerte_camp1=%s",
			lectureElixir(2), teams[2].elixir, #lectureCartes(2),
			tostring((lectureAlerte(1) or {}).texte or "aucune")))
		-- BILAN mesure en moteur : les compteurs ont-ils vraiment tourne pendant la partie ?
		local b1, b2 = Bilan.vue(teams[1].bilan), Bilan.vue(teams[2].bilan)
		dire("bilan", string.format("camp1 cartes=%d depense=%d gaspille=%d degats_tours=%d cout_moyen=%.1f",
			b1.cartes, b1.depense, b1.gaspille, b1.degatsTours, b1.coutMoyen))
		dire("bilan", string.format("camp2 cartes=%d depense=%d gaspille=%d degats_tours=%d cout_moyen=%.1f",
			b2.cartes, b2.depense, b2.gaspille, b2.degatsTours, b2.coutMoyen))
		dire("bilan", "conseil_camp1 = " .. tostring(Bilan.conseil(teams[1].bilan, teams[2].bilan)))
		dire("revanche", string.format("un_humain=%s deux_humains_un_clic=%s deux_humains_deux_clics=%s",
			tostring(Duel.revanchePrete(false, true, false)),
			tostring(Duel.revanchePrete(true, true, false)),
			tostring(Duel.revanchePrete(true, true, true))))
		dire("FIN", "scenario de duel termine")
	end)
end

-- SIMULATION D'EQUILIBRE (build.py --autotest --run --sim="1-1:6;1-3:6;3-5:6") : series de parties
-- robot contre robot, niveaux imposes, temps x Regles.SIM_ACCEL. Le camp le plus fort ALTERNE a chaque
-- partie, pour ne pas mesurer un avantage de cote. Une ligne [SIM] par partie.
local SIM = ReplicatedStorage:FindFirstChild("BRR_SIM")
local function pvTours(camp)
	local total = 0
	for _, tw in ipairs(teams[camp].towers) do
		total += tw.alive and math.max(0, tw.hp) or 0
	end
	return math.floor(total)
end
if SIM then
	task.spawn(function()
		task.wait(4)
		for bloc in string.gmatch(SIM.Value, "[^;]+") do
			-- « v:N » : N parties nouveau robot contre ancien, meme niveau, camps alternes.
			local nombreVs = tonumber(string.match(bloc, "^v:(%d+)$"))
			if nombreVs then
				local gagnes = 0
				for k = 1, nombreVs do
					resetMatch()
					local campNouveau = (k % 2 == 1) and 1 or 2
					for camp = 1, 2 do
						teams[camp].botVersion = (camp == campNouveau) and "nouveau" or "ancien"
					end
					majTours()
					while not result do
						task.wait(0.2)
					end
					local gagnant = vainqueur == 0 and "egalite" or (vainqueur == campNouveau and "nouveau" or "ancien")
					if gagnant == "nouveau" then
						gagnes += 1
					end
					print(string.format("[SIM] vs partie=%d gagnant=%s couronnes_nouveau=%d couronnes_ancien=%d pv_tours_nouveau=%d pv_tours_ancien=%d temps_restant=%d",
						k, gagnant, crowns(campNouveau), crowns(3 - campNouveau), pvTours(campNouveau), pvTours(3 - campNouveau), math.floor(timeLeft)))
					task.wait(0.5)
				end
				print(string.format("[SIM] vs BILAN nouveau=%d/%d", gagnes, nombreVs))
				continue
			end
			local na, nb, nombre = string.match(bloc, "(%d+)-(%d+):(%d+)")
			na, nb, nombre = tonumber(na), tonumber(nb), tonumber(nombre)
			for k = 1, nombre do
				resetMatch()
				-- alternance des cotes : paliers (Robot.paliersDuel) et niveaux
				SIM:SetAttribute("partie", k)
				-- camp du niveau nb (le plus fort) : 1 aux parties impaires, 2 aux paires
				local campFort = (k % 2 == 1) and 1 or 2
				for camp = 1, 2 do
					local n = (camp == campFort) and nb or na
					local niv = {}
					for _, c in ipairs(Cards.list) do
						niv[c.id] = n
					end
					teams[camp].niveaux = niv
				end
				majTours()
				while not result do
					task.wait(0.2)
				end
				local gagnant = vainqueur == 0 and "egalite" or (vainqueur == campFort and "fort" or "faible")
				print(string.format("[SIM] %d-%d partie=%d gagnant=%s couronnes_fort=%d couronnes_faible=%d pv_tours_fort=%d pv_tours_faible=%d temps_restant=%d sorts_fort=%d sorts_faible=%d regle=%s",
					na, nb, k, gagnant, crowns(campFort), crowns(3 - campFort), pvTours(campFort), pvTours(3 - campFort), math.floor(timeLeft),
					math.floor(teams[campFort].degatsSorts or 0), math.floor(teams[3 - campFort].degatsSorts or 0),
					ReplicatedStorage:FindFirstChild("BRR_SORT_SANS_NIVEAU") and "ancienne" or "nouvelle"))
				task.wait(0.5)
			end
		end
		print("[SIM] FIN")
	end)
end

-- STATUTS, image par image : le poison ronge, les soigneurs remettent des PV, et tout ce qui est
-- expire disparait NET (aucune vitesse residuelle, aucun demi-gel). La regle vit dans Statuts ;
-- ici on ne fait que parcourir les entites vivantes.
-- AURAS DE SOUTIEN, recalculees a chaque image. Rien n'est memorise sur les unites renforcees :
-- sortir du rayon ou tuer le soutien retire le bonus AU MEME INSTANT, sans aucun reste.
local function majSoutiens()
	local soutiens = {}
	for _, e in ipairs(entities) do
		if e.alive and e.carte and Soutien.estSoutien(e.carte.id) then
			table.insert(soutiens, { id = e.carte.id, camp = e.team,
				x = e.part.Position.X, z = e.part.Position.Z, vivant = true })
		end
	end
	for _, e in ipairs(entities) do
		if e.alive then
			if #soutiens == 0 then
				e.bonusDegats, e.bonusCadence = 1, 1
			else
				local moi = { camp = e.team, estBatiment = e.isBuilding, id = e.carte and e.carte.id,
					x = e.part.Position.X, z = e.part.Position.Z }
				-- `dejaRenforcee` : sans elle, une unite a la frontiere d'une aura entrait et sortait
				-- a chaque image, et ses degats oscillaient sans raison visible.
				local md, mc = Soutien.bonus(moi, soutiens, (e.bonusDegats or 1) > 1 or (e.bonusCadence or 1) > 1)
				-- La trace distingue deux choses tres differentes, sinon on ne peut rien en conclure :
				--  * ENTRE  : l'unite passe de « aucune aura » a « renforcee ». C'est ce qui permet
				--             de mesurer le papillonnage (une unite ne doit pas entrer dix fois) ;
				--  * CHANGE : elle passe d'une aura a une autre (x1,15 -> x1,30). C'est legitime, et
				--             le compter comme une entree faisait croire a un papillonnage qui
				--             n'existait pas (mesure du 2026-09-20 : 18 « entrees » pour 3 poses).
				local avant = math.max(e.bonusDegats or 1, e.bonusCadence or 1)
				local apres = math.max(md, mc)
				if apres > 1 and avant <= 1 then
					print("[SOUTIEN] ENTRE", e.label, "degats x" .. string.format("%.2f", md),
						"cadence x" .. string.format("%.2f", mc))
				elseif apres > 1 and (md ~= (e.bonusDegats or 1) or mc ~= (e.bonusCadence or 1)) then
					print("[SOUTIEN] CHANGE", e.label, "degats x" .. string.format("%.2f", md),
						"cadence x" .. string.format("%.2f", mc))
				end
				e.bonusDegats, e.bonusCadence = md, mc
			end
		end
	end
end

-- AVANTAGE DE TERRAIN, recalcule a chaque image comme les auras : avancer chez l'adversaire ou
-- perdre la tour le retire AU MEME INSTANT, sans aucun reste.
local function majTerrain()
	local tours = {}
	for camp = 1, 2 do
		local eq = teams[camp]
		if eq then
			for _, tw in ipairs(eq.towers) do
				table.insert(tours, { camp = camp, x = tw.part.Position.X, z = tw.part.Position.Z,
					vivante = tw.alive == true })
			end
		end
	end
	for _, e in ipairs(entities) do
		if e.alive then
			local avant = e.reductionTerrain or 0
			e.reductionTerrain = Terrain.reduction({ camp = e.team, estBatiment = e.isBuilding,
				x = e.part.Position.X, z = e.part.Position.Z }, tours)
			if e.reductionTerrain > 0 and avant == 0 then
				print("[TERRAIN]", e.label, "defend chez lui : degats subis -"
					.. math.floor(e.reductionTerrain * 100) .. "%")
			end
		end
	end
end

-- VITESSE OBSERVEE de chaque unite, mesuree entre deux images. Le serveur deplace les unites a
-- la main (aucune physique), il n'existe donc aucun vecteur vitesse : c'est ici qu'on le deduit.
-- Il sert a la VISEE des tireurs, qui doivent viser devant une cible en mouvement.
local function majVitesses(dt)
	if dt <= 0 then
		return
	end
	for _, e in ipairs(entities) do
		if e.alive and not e.isBuilding then
			local p = e.part.Position
			e.vitesseX, e.vitesseZ = Visee.vitesseObservee(p.X, p.Z, e.posPrecX, e.posPrecZ, dt)
			e.posPrecX, e.posPrecZ = p.X, p.Z
		end
	end
end

local function majStatuts(dt)
	majSoutiens()
	majTerrain()
	for _, e in ipairs(entities) do
		if e.alive then
			-- DEGIVRAGE : la glace disparait a la seconde ou le gel expire, pas avant.
			if Effets.estGivre(e.part) and not Statuts.actif(e, "gel", horloge) then
				Effets.degivrer(e.part)
			end
			if Effets.estEmpoisonne(e.part) and not Statuts.actif(e, "poison", horloge) then
				Effets.depoisonner(e.part)
			end
			if Effets.estEngourdi(e.part) and not Statuts.actif(e, "lent", horloge) then
				Effets.degourdir(e.part)
			end
			local perte = Statuts.tic(e, "poison", horloge)
			if perte > 0 then
				damage(e, math.floor(perte + 0.5))
			end
			-- SOIGNEUR (Dottore Pizza) : il rend des PV a ses allies dans son rayon, jamais au-dela
			-- de leur maximum et jamais a un mort (Statuts.soigner).
			local soin = e.carte and e.carte.soin
			if soin and e.alive then
				e.soinT = (e.soinT or 0) - dt
				if e.soinT <= 0 then
					e.soinT = soin.periode or 1
					local montant = math.floor(soin.montant * multNiveau(e.team, e.carte.id))
					for _, a in ipairs(entities) do
						if a.alive and a.team == e.team and a ~= e and not a.isBuilding then
							local d = a.part.Position - e.part.Position
							if Vector3.new(d.X, 0, d.Z).Magnitude <= soin.rayon then
								local gagne = Statuts.soigner(a, montant)
								if gagne > 0 then
									if a.fill then
										majBarre(a)
									end
									Effets.impact(arena, a.part.Position, Color3.fromRGB(120, 235, 160))
								end
							end
						end
					end
				end
			end
		end
	end
end

-- BATIMENTS POSES : ils s'usent tout seuls, produisent (elixir ou unites) et disparaissent a la
-- fin de leur duree de vie. Sans cette usure, poser un batiment serait gratuit : il resterait la
-- toute la partie. Les regles sont dans Batiments ; ici on applique.
local function majBatiments(dt)
	for _, e in ipairs(entities) do
		if e.alive and e.estBatimentPose and e.carte then
			local b = e.carte.batiment
			if e.usure and e.usure > 0 then
				e.hp = e.hp - e.usure * dt
				if e.fill then
					majBarre(e)
				end
				-- COMPTE A REBOURS : le chiffre sur l'etiquette et l'anneau au sol, tous deux
				-- calcules par le module (le temps restant tient compte des DEGATS recus : un
				-- batiment a moitie detruit tombera deux fois plus tot).
				local etiq = e.etiquette and e.etiquette:FindFirstChild("ResteBatiment")
				local fini = Batiments.presqueFini(e.carte, e.hp, e.maxHp)
				if etiq then
					etiq.Text = Batiments.texteRestant(e.carte, e.hp, e.maxHp)
					etiq.TextColor3 = fini and Color3.fromRGB(255, 120, 110) or Color3.fromRGB(235, 240, 250)
				end
				if e.rebours then
					local part = math.max(0, math.min(1, e.hp / math.max(1, e.maxHp)))
					local allumes = math.ceil(part * #e.rebours)
					for i, bout in ipairs(e.rebours) do
						bout.Transparency = i <= allumes and 0 or 0.9
						bout.Color = fini and Color3.fromRGB(255, 110, 100) or Color3.fromRGB(120, 235, 150)
					end
				end
				if e.hp <= 0 then
					damage(e, 1) -- passe par la mort normale : effet, etiquette, nettoyage
				end
			end
			if e.alive then
				local cycles = Batiments.produire(e.etatBatiment, e.carte, horloge)
				for _ = 1, cycles do
					if b.type == "collecteur" then
						-- COLLECTEUR : il rend de l'elixir, sans jamais depasser le plafond du jeu.
						local eq = teams[e.team]
						if eq then
							eq.elixir = math.min(MAX_ELIXIR, eq.elixir + (b.gain or 0))
							-- compteur de versements : sert au scenario de test en moteur, ou la
							-- regeneration naturelle et les depenses du robot masquent le gain.
							e.etatBatiment.rendu = (e.etatBatiment.rendu or 0) + (b.gain or 0)
							Effets.impact(arena, e.part.Position + Vector3.new(0, 3, 0), Color3.fromRGB(190, 110, 245))
						end
					elseif b.type == "invocateur" and b.invoque then
						-- INVOCATEUR : il pond ses unites DEVANT lui, du cote ennemi.
						local carteFille = Cards.byId[b.invoque]
						if carteFille then
							local s = e.team == 1 and 1 or -1
							local ou = e.part.Position + Vector3.new(0, 0, s * 3)
							for k = 1, (b.nombre or 1) do
								spawnUnit(carteFille, e.team, ou, offsetGroupe(k, b.nombre or 1, e.team), false)
							end
							Effets.pose(arena, ou, teamColor(e.team))
						end
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	if SIM then
		dt = dt * Regles.SIM_ACCEL
	end
	-- COUP D'ENVOI COMMUN : tant que l'adversaire n'est pas la (ou que le compte a rebours court),
	-- RIEN ne tourne — ni chrono, ni elixir, ni robot. Les deux joueurs partent au meme instant.
	geleDepart = (etatDepart()) == true
	-- PARTIE EN PAUSE : un joueur a saute et sa reprise est ouverte. Rien ne tourne — ni chrono,
	-- ni elixir, ni unites — exactement comme au coup d'envoi. Sans cela, il retrouvait au retour
	-- une partie ou il avait encaisse 45 s de degats sans pouvoir se defendre : la reprise lui
	-- rendait une partie deja perdue.
	for camp, jeton in pairs(reprises) do
		local eq = teams[camp]
		if jeton and eq and eq.enPause and not Reprise.expire(jeton, os.clock()) then
			geleDepart = true
		end
	end
	if geleDepart then
		stateTimer = stateTimer + dt
		if stateTimer >= 0.1 then
			stateTimer = 0
			for _, p in ipairs(Players:GetPlayers()) do
				sendState(p)
			end
		end
		return
	end
	if not result then
		timeLeft = timeLeft - dt
		horloge = horloge + dt
		for team = 1, 2 do
			local t = teams[team]
			local gain = Regles.ELIXIR_PAR_SEC * dt * Regles.multiplicateurElixir(timeLeft, MATCH_TIME, prolongation)
			local avant = t.elixir
			t.elixir = math.min(MAX_ELIXIR, t.elixir + gain)
			-- la regeneration VUE s'arrete au plafond, comme la vraie : sinon l'estimation
			-- annoncerait un elixir que l'adversaire n'a jamais eu.
			t.regenCumulee = (t.regenCumulee or 0) + (t.elixir - avant)
			-- ELIXIR GASPILLE : ce que la jauge PLEINE a refuse. C'est la faute n^o 1 des debutants,
			-- et rien ne la leur montrait jusqu'ici.
			Bilan.gaspiller(t.bilan, gain, t.elixir - avant)
		end
		-- ADVERSAIRE PLANTE : rester sans jouer epuisait le chrono ENTIER en face, pour une
		-- victoire vide. On surveille donc les joueurs HUMAINS (le robot, lui, joue toujours) et
		-- seulement quand poser etait POSSIBLE — accuser une jauge vide reviendrait a accuser le
		-- jeu lui-meme.
		for team = 1, 2 do
			local joueur = occupant[team]
			local t = teams[team]
			if joueur and t then
				-- Cout de la carte la moins chere de sa main : en dessous, il ne POUVAIT pas jouer.
				local coutMin = math.huge
				for _, id in ipairs(t.hand or {}) do
					local c = Cards.byId[id]
					if c and c.cost < coutMin then
						coutMin = c.cost
					end
				end
				if Inactif.compteur(t.elixir, coutMin) then
					t.silence = Inactif.silence(t.dernierePose, horloge, t.debutJeu or horloge)
				end
				if Inactif.doitFinir(t.silence or 0, MATCH_TIME - timeLeft) then
					print(string.format("[BRR] %s ne joue plus depuis %d s : la partie s'arrete",
						joueur.Name, math.floor(t.silence or 0)))
					-- Rester planté pour epuiser le chrono est le meme geste que partir, en plus
					-- couteux pour l'autre : c'est compte comme un abandon.
					if Inactif.vautAbandon(occupant[3 - team] ~= nil)
						and not joueur:GetAttribute("BRR_Prive") then -- partie amicale : pas de sanction
						Economie.noterAbandon(joueur)
					end
					endMatch(3 - team)
				end
			end
		end
		-- TUTORIEL : l'avancee est decidee par le module (condition remplie, ou plafond de temps
		-- atteint — une etape n'immobilise jamais le joueur). La fin rend la main au jeu normal.
		if tuto.actif then
			tuto.dansEtape = tuto.dansEtape + dt
			local e = tutoEtape()
			-- « pose » se lit sur la pose du joueur ; « tourTombee » et « volantAbattu » sur la mort
			-- constatee dans damage(). « delai » n'a pas de condition : seul le plafond le termine.
			local remplie = e ~= nil and ((e.finQuand == "pose" and tuto.poseFaite) or tuto.conditionFaite)
			local suivante = Tutoriel.suivante(tuto.index, remplie, tuto.dansEtape)
			if suivante == nil then
				tuto.actif = false
				local campJoueur = tuto.camp
				local joueur = tuto.joueur
				if joueur then
					Economie.marquerTutoriel(joueur)
					tutoFiniPour = joueur
				end
				-- LA PARTIE S'ARRETE ICI. Laisser tourner le match « normal » abandonnait un
				-- debutant face a un robot pendant deux minutes, et le seul retour au menu etait
				-- un ABANDON (donc une defaite). Sa premiere partie se conclut a son credit.
				print("[TUTO] termine : la partie d'apprentissage se termine, retour au menu")
				endMatch(Tutoriel.campVainqueur(campJoueur))
			elseif suivante ~= tuto.index then
				tutoEntrerEtape(suivante)
			end
		end
		-- DELAI DE GRACE ECOULE : il n'est pas revenu, la partie va a celui qui est reste.
		for camp, jeton in pairs(reprises) do
			if Reprise.expire(jeton, os.clock()) then
				reprises[camp] = nil
				if teams[camp] then
					teams[camp].enPause = nil -- le temps repart : il n'est pas revenu
				end
				local gagnant = Reprise.vainqueurApres(camp, occupant[3 - camp] ~= nil)
				if not result and gagnant then
					print("[BRR] camp " .. camp .. " : personne n'est revenu, victoire du camp " .. gagnant)
					endMatch(gagnant)
				elseif not result and Reprise.partieAbandonnee(occupant[1] == nil, occupant[2] == nil) then
					-- LES DEUX ONT SAUTE. Aucun vainqueur : on ne peut pas savoir qui l'aurait
					-- emporte, et c'est souvent le reseau — pas un joueur — qui a lache. Sans ce
					-- cas, aucune fin n'etait declenchee et la partie restait GELEE pour toujours,
					-- occupant le serveur sans que personne puisse y jouer.
					print("[BRR] les deux joueurs ont saute : partie annulee, aucun vainqueur")
					-- LE SPECTATEUR DOIT L'APPRENDRE. resetMatch efface les pronostics et repart a
					-- neuf : sans cette marque, son pari s'evaporait sans un mot et la partie
					-- disparaissait de son ecran. L'instant est pose sur ReplicatedStorage plutot
					-- que dans une variable : ce script est a la limite Luau de 200 variables
					-- locales, et l'attribut survit tres bien a la remise a neuf.
					ReplicatedStorage:SetAttribute("BRR_AnnuleeA", os.clock())
					resetMatch()
					break -- la partie est repartie a neuf : les autres jetons n'ont plus d'objet
				end
			end
		end
		-- Le bot ne remplace que le camp SANS joueur : a deux joueurs, plus aucun bot.
		for camp = 1, 2 do
			-- gros plan de test : aucun robot, seule la rangee immobile est a l'image
			-- en melee, les DEUX camps jouent en rafale : sinon le robot seul rasait le camp du joueur en 13 s
			-- Reprise.robotAutorise : pendant une coupure, personne ne joue ce camp. Un robot qui
			-- depenserait SON elixir et sortirait SES cartes serait pire que la defaite.
			-- BRR_SIM : une SERIE de mesure pilote TOUJOURS les deux camps. Defaut mesure le
			-- 2026-09-20 : `autoTest` ne passe a vrai que si AUCUN joueur n'est present 3 s apres
			-- le demarrage — or en Studio un joueur local existe toujours. Le camp qu'il occupait
			-- n'avait donc aucun robot, et il ne jouait pas : sur une serie de 20 parties, le
			-- camp 1 a pose 3 cartes contre 721 au camp 2, et perdu 20 fois sur 20 en 3-0. Le
			-- chiffre ressemblait a un desequilibre de jeu ; ce n'etait que le banc qui mesurait
			-- un camp contre le vide.
			if (autoTest or campLibre(camp) or ReplicatedStorage:FindFirstChild("BRR_MELEE")
				or ReplicatedStorage:FindFirstChild("BRR_SIM"))
				and Reprise.robotAutorise(reprises[camp])
				and not ReplicatedStorage:FindFirstChild("BRR_GROSPLAN") then
				botThink(camp, dt)
			end
		end
		-- HISTORIQUE DES MAINS pour les spectateurs : une photo par seconde suffit, et elle ne leur
		-- sera montree qu'avec RETARD secondes de decalage.
		photoMains = (photoMains or 0) + dt
		if photoMains >= 1 then
			photoMains = 0
			for camp = 1, 2 do
				if teams[camp] then
					historiqueMains[camp] = Spectateur.ajouter(historiqueMains[camp], teams[camp].hand, horloge)
				end
			end
		end
		majGroupes()
		-- la vitesse doit etre connue AVANT que les tireurs choisissent leur point de visee
		majVitesses(dt)
		majTirs()
		majStatuts(dt)
		majBatiments(dt)

		for _, e in ipairs(entities) do
			-- L'ANNEAU DE DEPLOIEMENT d'abord, AVANT le filtre `e.active`. Mesure du 2026-09-21 :
			-- place apres, il n'etait jamais rafraichi sur une entite inactive — le journal
			-- comptait « 112 anneaux VISIBLES » (tous figes a 6,00) pour trois poses reelles.
			-- Un anneau qui ne se referme pas est pire que pas d'anneau : il dit « pas encore
			-- prete » sur une unite qui l'est depuis longtemps.
			if e.alive then
				majAnneauDeploiement(e)
			end
			if e.alive and e.active then
				e.cooldown = e.cooldown - dt
				-- DEPLOIEMENT : pendant son arrivee (elle tombe encore du ciel), une unite ne
				-- frappe pas et n'avance pas. Sans cela, poser une carte au contact d'un ennemi
				-- le frappait avant qu'il puisse reagir, et l'unite attaquait en plein vol.
				local target, d = findTarget(e)
				if target and not e.isBuilding
					and not Deploiement.pret(horloge - (e.poseT or -99), e.dureeDeploiement) then
					-- on ne trace qu'une fois par unite : sinon une ligne par image et par unite.
					if not e.deploiementTrace then
						e.deploiementTrace = true
						print("[DEPLOIEMENT]", e.label, "arrive encore :",
							string.format("%.2f", Deploiement.restant(horloge - (e.poseT or 0),
								e.dureeDeploiement)), "s avant d'agir")
					end
					target = nil
				end
				if target then
					if d <= e.range + target.part.Size.X / 2 then
						-- Arrivee au contact sans frapper encore : elle garde son elan pour LE coup
						-- qui vient, c'est tout l'interet. En revanche elle ne l'accumule plus.
						if e.cooldown <= 0 and Statuts.peutAgir(e, horloge) then
							-- meme rage que pour la marche : elle frappe aussi plus vite
							-- cadence : la rage ET le soutien raccourcissent le delai entre deux coups
						-- DERNIERE GARDE : quand un camp a perdu ses DEUX tours de princesse, son
						-- Roi tire plus vite (Garde). Mesure du 2026-09-20 : 15 parties sur 20
						-- finissaient par la chute du Roi, sans que le camp mene ait un seul
						-- moment pour se refaire. La regle ne donne ni points de vie ni degats.
						e.cooldown = Garde.delai(
							Soutien.delaiAttaque(e.atkSpeed, e.bonusCadence)
								/ Sorts.multiplicateurRage(e.rageSort,
									e.rageT and (horloge - e.rageT) or nil),
							facteurGarde(e))
							attack(e, target)
						end
					elseif not e.isBuilding then
						moveUnit(e, target, dt)
					end
				end
				if e.alive and not e.isBuilding then
					animer(e, dt)
				end
			end
		end

		-- SEPARATION DE FOULE. Une fois tout le monde deplace, on repousse ce qui se chevauche :
		-- deux unites ne peuvent plus occuper le meme point, et une tour ne se traverse pas.
		-- Calcul fait APRES les deplacements (et non pendant), pour que l'ordre des unites dans
		-- la liste ne change pas le resultat.
		local vus = {}
		for i, e in ipairs(entities) do
			if e.alive and e.part then
				local p = e.part.Position
				table.insert(vus, { id = i, x = p.X, z = p.Z, rayon = e.rayonFoule or 1,
					flying = e.flying == true, batiment = e.isBuilding == true, ref = e })
			end
		end
		for _, v in ipairs(vus) do
			local e = v.ref
			if not e.isBuilding then
				local dx, dz = Foule.poussee(v, vus, dt)
				if dx ~= 0 or dz ~= 0 then
					local p = e.part.Position
					-- la poussee reste DANS l'arene : sinon une melee ejectait une unite dehors
					local nx = math.clamp(p.X + dx, -HALF_W + 1, HALF_W - 1)
					local nz = math.clamp(p.Z + dz, -HALF_L + 1, HALF_L - 1)
					e.part.CFrame = CFrame.new(nx, p.Y, nz) * (e.part.CFrame - p)
					e.bouge = true
				end
				e.freinFoule = Foule.freinage(Foule.chevauchement(v, vus), v.rayon)
			end
		end

		local alive = {}
		for _, e in ipairs(entities) do
			if e.alive then
				table.insert(alive, e)
			end
		end
		entities = alive

		if timeLeft <= 0 and not result then
			timeLeft = 0
			local gagnant = Regles.finDuTemps(crowns(1), crowns(2))
			if gagnant then
				endMatch(gagnant)
			elseif not prolongation then
				-- Egalite de couronnes : on ne rend plus un match nul, on joue la prolongation.
				prolongation = true
				timeLeft = Regles.dureeProlongation(MATCH_TIME)
			else
				-- Prolongation ecoulee sans tour prise : la tour la plus entamee perd.
				endMatch(Regles.finProlongation(pvBasTour(1), pvBasTour(2)))
			end
		end
	end

	if autoTest and not reported then
		if result then
			reported = true
			report()
		end
		reportTimer = reportTimer + dt
		if reportTimer >= 5 then
			reportTimer = 0
			report()
		end
	end

	stateTimer = stateTimer + dt
	if stateTimer >= 0.1 then
		stateTimer = 0
		for _, p in ipairs(Players:GetPlayers()) do
			sendState(p)
		end
	end
end)
