-- Brainrot Royale : client (camera, main de cartes, elixir, pose)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cards"))
-- Habillage sonore : joue CHEZ CE CLIENT, sur les evenements deja recus du serveur.
local Sons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sons"))
-- Memes regles de pose que le serveur (module partage) : le client ne fait que prevenir un aller-
-- retour inutile, le serveur reverifie tout.
local Regles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regles"))
-- Apercu de pose (disque au sol + fantome de l'unite) : regles pures, banc tools/test_apercu.py.
local Apercu = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Apercu"))
-- Memes regles de pose de BATIMENT que le serveur : sans elles, le client montrait un disque VERT
-- sur la riviere et le serveur refusait ensuite la carte, sans un mot.
local Batiments = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Batiments"))
-- Lecture : ce que le joueur doit savoir de l'adversaire (elixir estime, cartes vues, alerte).
local Lecture = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lecture"))
-- Cout : ce qui manque pour poser une carte (tools/test_cout.py).
local Cout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cout"))
-- Cycle : le retour de la derniere carte jouee (tools/test_cycle.py).
local Cycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cycle"))
-- Camps : qui est a moi, qui est en face — couleurs RELATIVES au joueur (pures, tools/test_camps.py).
local Camps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Camps"))
local Profil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Profil"))
-- Duel : libelle du bouton de fin et etat de la revanche (regles pures, tools/test_pvp.py).
local Duel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Duel"))
-- Signalement : recours contre un adversaire penible (liste FERMEE de motifs).
local Signalement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signalement"))
-- Reseau : latence mesuree et avertissement de connexion instable (pures, tools/test_reseau.py).
local Reseau = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reseau"))
-- Spectateur : suivre un camp, main RETARDEE, resultat du pari (pures, tools/test_spectateur.py).
local Spectateur = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spectateur"))
-- Adversaire : badge et annonce « robot » (pures, tools/test_adversaire.py).
local Adversaire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Adversaire"))
-- Bilan : compte le gaspillage d'elixir ET dit quoi en afficher pendant la partie.
local Bilan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilan"))
-- Couronnes : nommer le moment le plus important de la partie (pures, tools/test_couronnes.py).
local Couronnes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Couronnes"))
-- Geste : glisser-deposer et annulation de la carte armee (pures, tools/test_geste.py).
local Geste = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Geste"))
-- Zone : surlignage de la zone de pose autorisee (pures, tools/test_zone.py).
local Zone = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Zone"))
-- Mise : positions calculees a partir de la taille de l'ecran (pures, tools/test_mise.py).
local Mise = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Mise"))
-- Emotes : la liste FERMEE vient du module partage (elle etait dupliquee ici et dans le serveur).
local Emotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Emotes"))
-- FICHES : l'etiquette d'effet d'une carte (GEL, POISON, BOUCLIER...), deduite de ses donnees.
local Fiche = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fiche"))
-- Sorts : le rendement d'un sort de degats, affiche sur sa fiche.
local Sorts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sorts"))
-- SPECIALITE et SOUTIEN sont declares par identifiant dans leurs propres modules (regles de
-- COMBAT, pas donnees de carte) : on les lit ici et on les passe a la fiche.
local Specialite = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Specialite"))
local Soutien = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Soutien"))
-- DESCENDANCE et RECUL : memes regles de combat declarees par identifiant, meme traitement.
local Descendance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Descendance"))
local Recul = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Recul"))
local function extrasDe(id)
	-- `noms` : la fiche ecrit « laisse 2 Trippi Troppi » et non l'identifiant brut.
	local noms = {}
	for _, c in ipairs(Cards.list) do
		noms[c.id] = c.name
	end
	return {
		specialite = Specialite.profil(id), soutien = Soutien.profil(id),
		descendance = Descendance.profil(id), recul = Recul.profil(id), noms = noms,
		-- RENDEMENT D'UN SORT : la regle vit dans Sorts, la fiche ne fait que l'afficher.
		rendementSort = Cards.byId[id] and Sorts.degatsParElixir(Cards.byId[id]) or nil,
		-- CHARGE et ASSASSIN : deux regles de combat qui changent la facon de jouer la carte et
		-- qui n'etaient sur AUCUNE fiche. Modules charges ICI, dans la fonction : le corps de ce
		-- script est au plafond des 200 variables locales de Lua.
		charge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Charge")).profil(id),
		-- POINT FORT : la place de ses chiffres dans le catalogue reel (« la plus longue portee
		-- du jeu »). Calcule par Reperes, jamais ecrit a la main.
		pointFort = (function()
			local R = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reperes"))
			return R.texte(R.points(Cards.byId[id], Cards.list))
		end)(),
		assassin = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Assassin")).estAssassin(id) or nil,
		-- RENTABILITE D'UN COLLECTEUR : en partie aussi, c'est le chiffre qui decide de poser la
		-- pompe ou de garder l'elixir. La regle vit dans Batiments.
		rentabilite = Cards.byId[id] and Batiments.texteRentabilite(Cards.byId[id]) or nil,
	}
end
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayCard = remotes:WaitForChild("PlayCard")
local StateEvent = remotes:WaitForChild("State")
local RestartEvent = remotes:WaitForChild("Restart")
local EmoteEvent = remotes:WaitForChild("Emote")
local PronosticEvent = remotes:WaitForChild("Pronostic")
-- RemoteFunction du hub : elle sert AUSSI en partie, pour le signalement (le serveur repond, donc
-- le joueur sait si c'est parti). Declaree ICI, apres `remotes` : plus haut, `remotes` n'existe pas
-- encore et l'ecran de match tombait en erreur des le chargement.
local BoutiqueFn = remotes:WaitForChild("Boutique")
local RefusEvent = remotes:WaitForChild("Refus")
local PingEvent = remotes:WaitForChild("Ping")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- CAMERA VUE DE DESSUS, CADRAGE REGLE SUR LA PROJECTION REELLE.
-- Deux versions precedentes ont echoue, chacune vue sur une capture (2026-09-14) :
--  1. distance FIXE : sur une image etroite (592x1348), l'arene n'occupait qu'une bande au milieu ;
--  2. distance CALCULEE par trigonometrie approchee : correcte en portrait, mais en 16:9 l'arene
--     DEBORDAIT du cadre (haut coupe). La projection d'un plan incline ne se ramene pas a un sinus.
-- Ici, on ne calcule plus : on MESURE. Les coins de l'arene sont projetes a l'ecran avec la
-- projection de la camera elle-meme (WorldToViewportPoint), et la distance s'ajuste doucement
-- jusqu'a ce qu'ils tiennent dans le cadre. Cela vaut pour n'importe quel format d'ecran.
local ARENE_DEMI_LARGEUR, ARENE_DEMI_LONGUEUR = 32, 44 -- HALF_W, HALF_L du serveur
local HAUTEUR_TOURS = 9
local BANDE_CARTES = 0.16 -- part BASSE de l'ecran prise par la main de cartes
-- Part HAUTE reservee au chrono et au score. Mesure du 2026-09-14 : a 0.10, c'est ELLE qui
-- limitait le rapprochement (debordement 0.003, distance bloquee a 71) — les sommets des tours du
-- fond venaient toucher cette bande, et l'arene restait petite au milieu de l'ecran. Le chrono est
-- en surimpression : il peut mordre un peu sur le ciel.
local BANDE_HAUT = 0.04
local ANGLE_VUE = 62
-- TUTORIEL, etape « avancer » : la camera se RAPPROCHE pour qu'on regarde ses unites traverser.
-- Declare ici parce que la boucle de camera (plus bas) la lit a chaque image.
local tutoCameraProche = false
local INCLINAISON = math.rad(52)

local distance = 70 -- point de depart, corrige des la premiere image
-- CAMP DU JOUEUR. Le camp 2 doit voir l'arene depuis l'AUTRE bout, sinon son camp est en haut de
-- l'ecran et sa zone de pose hors de vue. Le serveur envoie `monCamp` dans l'etat ; tant qu'aucun
-- etat n'est arrive, on garde le camp 1 (cas du joueur seul).
local monCamp = 1
local dejaRelance = false -- copie de test : un seul appui sur Rejouer
local jeSuisSpectateur = false -- vrai quand les deux camps sont deja pris
local attenteEnCours = false -- vrai tant que le coup d'envoi n'est pas donne (duel en ligne)
-- nom de l'adversaire, pose sur SON cote de l'arene. Declare ICI : l'etat le remplit bien avant
-- que la boucle de lisibilite (plus bas) ne le lise.
local nomAdverseVu = nil
-- une seule annonce « tu affrontes le robot » par partie : repetee 10 fois par seconde, ce serait
-- l'inverse d'une information.
local annonceAdversaireVue = false
local inviteSalutVue = false -- l'invitation a saluer ne se dit qu'une fois
local ecartNiveauVu = false -- l'ecart de niveau se dit une fois, pas en boucle
local distanceMesuree, debordementMesure = 0, 0 -- sonde de cadrage (copie de test)

local COINS = {}
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		table.insert(COINS, Vector3.new(sx * ARENE_DEMI_LARGEUR, 0, sz * ARENE_DEMI_LONGUEUR))
		table.insert(COINS, Vector3.new(sx * ARENE_DEMI_LARGEUR, HAUTEUR_TOURS, sz * ARENE_DEMI_LONGUEUR))
	end
end

-- Secousse de camera a la chute d'une tour (declenchee plus bas, au meme endroit que le son).
-- Amplitude PROPORTIONNELLE a l'evenement : chute de tour > mort d'unite > impact de zone. Une
-- petite secousse n'ecrase jamais une plus forte encore en cours.
local SECOUSSE_DUREE = 0.45
local SECOUSSE = { tour = 1.6, mort = 0.45, zone = 0.25 }
local secousseFin, secousseAmplitude = 0, 0
local function secouer(force)
	local maintenant = os.clock()
	local reste = math.max(0, (secousseFin - maintenant) / SECOUSSE_DUREE)
	if force >= secousseAmplitude * reste * reste then
		secousseAmplitude = force
		secousseFin = maintenant + SECOUSSE_DUREE
	end
end

RunService.RenderStepped:Connect(function()
	camera.CameraType = Enum.CameraType.Scriptable
	-- un angle plus ETROIT rapproche la scene sans deplacer la camera : la mise en page du jeu
	-- (main de cartes, jauge) ne bouge pas d'un pixel pendant l'etape.
	camera.FieldOfView = tutoCameraProche and 48 or ANGLE_VUE
	-- COPIE DE TEST (build.py --grosplan) : camera basse face a la rangee de test, pour juger le
	-- sens des modeles. Camp 1 (z=-7) doit montrer son DOS, camp 2 (z=+7) son VISAGE.
	if game:GetService("ReplicatedStorage"):FindFirstChild("BRR_GROSPLAN") then
		camera.FieldOfView = 95
		local g = game:GetService("ReplicatedStorage"):FindFirstChild("BRR_GALERIE")
		if g and not string.find(g.Value, ",") then
			-- une seule carte : camera tout pres de l'unite du camp 1 (x=0, z=-7), de trois quarts arriere
			camera.CFrame = CFrame.lookAt(Vector3.new(6, 7, -15), Vector3.new(0, 2, -7))
		else
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 17, -17), Vector3.new(0, 1, 4))
		end
		return
	end

	local sens = (monCamp == 2) and -1 or 1
	-- Spectateur : vue NEUTRE, centree sur l'arene. Pas de decalage vers un camp, et pas de place
	-- reservee a la main de cartes puisqu'elle est masquee.
	local bandeBasse = jeSuisSpectateur and BANDE_HAUT or BANDE_CARTES
	local cible = jeSuisSpectateur and Vector3.new(0, 0, 0)
		or Vector3.new(0, 0, sens * (-2 - ARENE_DEMI_LONGUEUR * (bandeBasse - BANDE_HAUT)))
	local direction = Vector3.new(0, math.sin(INCLINAISON), -sens * math.cos(INCLINAISON))
	camera.CFrame = CFrame.lookAt(cible + direction * distance, cible)

	-- Ou tombent les coins de l'arene ? On veut tout entre les deux bandes d'interface.
	-- DEPART A -INFINI, et c'est le coeur du calcul : `pire` est le plus grand DEBORDEMENT, une
	-- valeur NEGATIVE quand tout tient avec de la marge. En partant de 0 (version du 2026-09-14),
	-- math.max ecrasait ces valeurs negatives : la camera ne se rapprochait JAMAIS et restait a sa
	-- distance de depart. C'est ce qui laissait l'arene petite au milieu de l'ecran, surtout pour le
	-- spectateur, dont la vue est centree et a donc le plus d'air a rattraper.
	local pire = -math.huge
	for _, coin in ipairs(COINS) do
		local point = camera:WorldToViewportPoint(coin)
		local vue = camera.ViewportSize
		local x = (vue.X > 0) and (point.X / vue.X) or 0.5
		local y = (vue.Y > 0) and (point.Y / vue.Y) or 0.5
		-- Debordement, en part d'ecran, par rapport au cadre utile.
		local basUtile = jeSuisSpectateur and BANDE_HAUT or BANDE_CARTES
		pire = math.max(pire, -x, x - 1, BANDE_HAUT - y, y - (1 - basUtile))
	end

	-- SECOUSSE : appliquee APRES le calcul complet du CFrame, jamais stockee dedans. La camera est
	-- recalculee a chaque image depuis zero, donc quand le compte a rebours tombe a zero la vue
	-- redevient exacte d'elle-meme : aucun decalage residuel n'est possible.
	if secousseFin > os.clock() then
		local reste = (secousseFin - os.clock()) / SECOUSSE_DUREE
		local a = secousseAmplitude * reste * reste -- s'eteint vite, pas de tremblement qui traine
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end

	distanceMesuree, debordementMesure = distance, pire
	if pire > 0.005 then
		distance = math.min(distance * (1 + math.min(pire, 0.12)), 260) -- trop gros : on recule
	elseif pire < -0.008 then
		-- Seuil de rapprochement. A -0.03, la camera s'arretait avec 2 a 3 % de marge inutilisee
		-- (mesure 2026-09-14 : debordement -0.022, distance figee a 70). A -0.008, elle va chercher
		-- le bord ; au-dessus, la premiere branche la fait reculer, les deux se stabilisent.
		distance = math.max(distance * 0.995, 20)
	end
end)

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "RoyaleUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- TOUS LES ELEMENTS D'INTERFACE DANS UNE SEULE TABLE. Lua plafonne a 200 variables locales par
-- fichier, et l'ecran de match les avait toutes consommees (« too many local variables », mesure
-- du 2026-09-20). Les regrouper libere le plafond sans rien changer au comportement.
local hud = {}

-- HABILLAGE DU HUD (2026-09-20) ------------------------------------------------------------
-- fix-ok: cause mesuree du HUD « plat » — l'ecran de match ne contenait AUCUN degrade et UN
-- seul contour (jauge d'elixir, panneau bas et cartes en aplat de couleur unie), alors que le
-- hub avait deja recu sa couche premium. Ces trois fabriques ajoutent la couche manquante et
-- s'appliquent a des elements DEJA construits : aucune logique de jeu n'est touchee.
local function coinUI(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = o
	return c
end

local function degradeUI(o, haut, bas, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(haut, bas)
	g.Rotation = rotation or 90
	g.Parent = o
	return g
end

local function contourUI(o, epaisseur, couleur, transparence, mode)
	local st = Instance.new("UIStroke")
	st.Thickness = epaisseur or 2
	st.Color = couleur or Color3.fromRGB(12, 14, 24)
	st.Transparency = transparence or 0
	-- En mode Border, un UIStroke pose sur un label a fond transparent dessine le RECTANGLE du
	-- label (cadres fantomes deja mesures dans le hub). Contextual ne trace que le texte.
	st.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	st.Parent = o
	return st
end

local function label(parent, text, size, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 1
	l.Parent = parent
	-- contour de police epais : lisible par-dessus l'arene claire comme par-dessus une gerbe.
	contourUI(l, 2, Color3.fromRGB(10, 12, 20), 0.15, Enum.ApplyStrokeMode.Contextual)
	return l
end

local top = label(gui, "3:00", UDim2.new(0, 300, 0, 40), UDim2.new(0.5, -150, 0, 10))
local crownsLabel = label(gui, "0 - 0", UDim2.new(0, 300, 0, 30), UDim2.new(0.5, -150, 0, 50))
-- PHOTOS DE PROFIL, de part et d'autre de la ligne de score. En duel, l'adversaire n'etait qu'un
-- NOM : rien ne donnait le sentiment d'affronter quelqu'un. Les deux pastilles sont ENFANTS du
-- score, donc elles suivent la place que la mise en page lui donne — pas un offset de plus a la
-- main (lecon du 2026-09-20 : « Rejouer » qui recouvrait le bloc suivant).
local function pastilleProfil(cote)
	local cadre = Instance.new("Frame")
	cadre.Name = "Profil" .. cote
	cadre.AnchorPoint = Vector2.new(cote == "Moi" and 1 or 0, 0.5)
	cadre.Position = UDim2.new(cote == "Moi" and 0 or 1, cote == "Moi" and -8 or 8, 0.5, 0)
	cadre.BackgroundColor3 = Color3.fromRGB(60, 64, 78)
	cadre.BorderSizePixel = 0
	cadre.Parent = crownsLabel
	local rond = Instance.new("UICorner")
	rond.CornerRadius = UDim.new(1, 0) -- pastille ronde : on ne confond pas avec une carte
	rond.Parent = cadre
	contourUI(cadre, 2, Color3.fromRGB(12, 14, 22), 0.1)
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.Size = UDim2.new(1, 0, 1, 0)
	photo.BackgroundTransparency = 1
	photo.Image = ""
	photo.Parent = cadre
	local rond2 = Instance.new("UICorner")
	rond2.CornerRadius = UDim.new(1, 0)
	rond2.Parent = photo
	local lettre = label(cadre, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	lettre.Name = "Repli"
	lettre.TextScaled = true
	return { cadre = cadre, photo = photo, lettre = lettre }
end
hud.profilMoi = pastilleProfil("Moi")
hud.profilLui = pastilleProfil("Lui")

-- CHARGEMENT DE LA PHOTO. C'est un appel RESEAU : il peut etre lent, echouer, ou ne rien rendre
-- (hors ligne, et dans Studio). On ne bloque donc rien, on garde la pastille de repli tant que
-- l'image n'est pas la, et un echec n'est pas une erreur — c'est le cas NORMAL a traiter.
hud.photosVues = {}
local function chargerPhoto(userId, poser)
	if hud.photosVues[userId] ~= nil then
		poser(hud.photosVues[userId])
		return
	end
	hud.photosVues[userId] = false -- une seule demande par joueur
	task.spawn(function()
		local ok, contenu = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150)
		end)
		hud.photosVues[userId] = (ok and type(contenu) == "string" and contenu ~= "") and contenu or false
		poser(hud.photosVues[userId] or nil)
	end)
end

local function poserProfil(pastille, nom, estRobot, image)
	local vue = Profil.vue(nom, estRobot, image)
	pastille.photo.Image = vue.image or ""
	pastille.lettre.Text = vue.texte
	-- Color3.fromRGB directement : le raccourci c3 est defini bien plus bas dans ce fichier, et une
	-- variable locale n'existe pas avant sa declaration — l'appel serait nul a l'execution.
	pastille.cadre.BackgroundColor3 = Color3.fromRGB(vue.couleur[1], vue.couleur[2], vue.couleur[3])
end

local function majProfils(s)
	local taille = Profil.taille(crownsLabel.AbsoluteSize.Y)
	-- (hud.misePermet est renseigne au premier calcul de mise en page ; on ne suppose pas qu'il existe)
	local montrer = (hud.misePermet or {})["score"] ~= false
		and Profil.affichables(crownsLabel.AbsoluteSize.X, crownsLabel.AbsoluteSize.Y)
	for _, p in ipairs({ hud.profilMoi, hud.profilLui }) do
		p.cadre.Size = UDim2.new(0, taille, 0, taille)
		p.cadre.Visible = montrer and s.result == nil
	end
	-- UNE SEULE MECANIQUE, DEUX LECTURES. Le joueur voit « moi » puis « en face » ; le SPECTATEUR
	-- n'a pas de camp, donc rien a montrer de son cote — il voyait SA PROPRE photo face a un
	-- rouage de robot, ce qui ne voulait rien dire pour lui. Il voit desormais les deux joueurs.
	local gaucheId, gaucheNom, gaucheRobot
	local droiteId, droiteNom, droiteRobot
	if s.spectateur then
		gaucheId, gaucheNom, gaucheRobot = s.userIdCamp1, s.nomCamp1, s.camp1EstRobot
		droiteId, droiteNom, droiteRobot = s.userIdCamp2, s.nomCamp2, s.camp2EstRobot
	else
		gaucheId, gaucheNom, gaucheRobot = player.UserId, player.DisplayName, false
		droiteId, droiteNom, droiteRobot = s.userIdAdversaire, s.nomAdversaire, s.adversaireEstRobot
	end
	local demandeMoi = Profil.demande(gaucheId, gaucheRobot)
	if demandeMoi.type == "joueur" then
		poserProfil(hud.profilMoi, gaucheNom, false, hud.photosVues[demandeMoi.userId] or nil)
		chargerPhoto(demandeMoi.userId, function(image)
			poserProfil(hud.profilMoi, gaucheNom, false, image)
		end)
	else
		poserProfil(hud.profilMoi, gaucheNom, demandeMoi.type == "robot", nil)
	end
	local demande = Profil.demande(droiteId, droiteRobot)
	local sonNom = droiteNom
	if demande.type == "joueur" then
		poserProfil(hud.profilLui, sonNom, false, hud.photosVues[demande.userId] or nil)
		chargerPhoto(demande.userId, function(image)
			poserProfil(hud.profilLui, sonNom, false, image)
		end)
	else
		poserProfil(hud.profilLui, sonNom, demande.type == "robot", nil)
	end
end
-- ARENE : le nom du palier de trophees, sous le score. En partie, rien ne disait dans quelle
-- arene on jouait — l'information n'existait que dans le hub, et seulement en chiffres.
-- Le badge separe a ete RETIRE : pose a cote du score, il en recouvrait la fin (capture du
-- 2026-09-20). La mention « ROBOT » vit desormais en tete de la fiche de l'adversaire.
local areneLabel = label(gui, "", UDim2.new(0, 360, 0, 22), UDim2.new(0.5, -180, 0, 80))
areneLabel.TextColor3 = Color3.fromRGB(210, 195, 150)
-- SAISON : rang mondial et temps restant, sous le nom d'arene. La progression d'un duel ne se
-- voyait nulle part pendant la partie — seulement dans le hub, et seulement en trophees bruts.
hud.saisonLabel = label(gui, "", UDim2.new(0, 360, 0, 20), UDim2.new(0.5, -180, 0, 102))
-- FICHE DE L'ADVERSAIRE (nom, niveau de ses cartes), sous la ligne de saison.
-- fix-ok: cause mesuree le 2026-09-20 — `hud.ficheAdversaire` etait LU a la ligne 1849 sans avoir
-- jamais ete cree : « attempt to index nil with 'Text' » a chaque etat recu, donc l'ecran de jeu
-- entier restait fige (main affichee « Button », journal Studio). Element manquant d'un
-- regroupement en cours dans une autre session : on le cree, on ne change rien a son usage.
hud.ficheAdversaire = label(gui, "", UDim2.new(0, 420, 0, 18), UDim2.new(0.5, -210, 0, 122))
hud.ficheAdversaire.TextScaled = false
hud.ficheAdversaire.TextSize = 14
hud.ficheAdversaire.TextColor3 = Color3.fromRGB(200, 208, 225)
-- ENJEU EN TROPHEES, sous la fiche (range dans `hud` : ce fichier est au plafond des locales).
hud.enjeuLabel = label(gui, "", UDim2.new(0, 420, 0, 16), UDim2.new(0.5, -210, 0, 141))
hud.enjeuLabel.TextScaled = false
hud.enjeuLabel.TextSize = 13
hud.enjeuLabel.TextColor3 = Color3.fromRGB(255, 205, 110)
hud.saisonLabel.TextScaled = false
hud.saisonLabel.TextSize = 13
hud.saisonLabel.TextColor3 = Color3.fromRGB(175, 190, 215)

-- EMOTES RAPIDES : boutons en haut a droite, caches pour le spectateur (le serveur refuse de toute facon).
local emotesBarre = Instance.new("Frame")
emotesBarre.BackgroundTransparency = 1
-- largeur DEDUITE du nombre d'emotes (+ le bouton de silence) : une largeur en dur laissait le
-- dernier bouton hors du cadre des qu'on ajoutait une emote.
local NB_BOUTONS_EMOTE = #Emotes.LISTE + 1
emotesBarre.Size = UDim2.new(0, NB_BOUTONS_EMOTE * 48, 0, 40)
emotesBarre.Position = UDim2.new(1, -(NB_BOUTONS_EMOTE * 48 + 10), 0, 10)
emotesBarre.Visible = false
emotesBarre.Parent = gui
local emotesListe = Instance.new("UIListLayout")
emotesListe.FillDirection = Enum.FillDirection.Horizontal
emotesListe.Padding = UDim.new(0, 6)
emotesListe.Parent = emotesBarre
local boutonsEmote = {}
-- Instant de MA derniere emote, garde chez le client pour appliquer le meme delai que le serveur.
hud.emote = { derniere = nil }
for _, e in ipairs(Emotes.LISTE) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 42, 0, 36)
	b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	b.BackgroundTransparency = 0.2
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Text = e.libelle
	if e.prix then
		-- EMOTE PREMIUM : fond or, cachee tant qu'elle n'est pas achetee (hud.majEmotes)
		b.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
		b.Visible = false
	end
	b.Parent = emotesBarre
	boutonsEmote[e.id] = b
	coinUI(b, 10)
	degradeUI(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170))
	contourUI(b, 2, Color3.fromRGB(10, 12, 20), 0.2)
	b.MouseButton1Click:Connect(function()
		hud.cliquerEmote(e.id)
	end)
end

-- EMOTES POSSEDEES : le serveur publie la liste en attribut du joueur (« tralalero,roi »). La
-- barre ne montre que les gratuites et les premium achetees, et sa largeur suit ce nombre.
function hud.majEmotes()
	local possedees = {}
	for id in string.gmatch(player:GetAttribute("EmotesPossedees") or "", "[^,]+") do
		possedees[id] = true
	end
	local n = 1 -- le bouton de silence
	for _, e in ipairs(Emotes.LISTE) do
		local visible = not e.prix or possedees[e.id] == true
		boutonsEmote[e.id].Visible = visible
		if visible then
			n = n + 1
		end
	end
	-- la TAILLE de la barre appartient a la mise en page (Mise.lua) : ce sont les boutons qui se
	-- partagent sa largeur, sinon trois emotes de plus debordaient hors de l ecran
	for _, b in pairs(boutonsEmote) do
		b.Size = UDim2.new(1 / n, -6, 1, 0)
	end
end
player:GetAttributeChangedSignal("EmotesPossedees"):Connect(hud.majEmotes)
task.defer(hud.majEmotes)

-- BOUTON DE CAPACITE DU CHAMPION (module Champions). Visible tant que MON champion est en vie :
-- son nom, le cout en elixir, et la recharge en grand chiffre. Le clic ne fait que DEMANDER, le
-- serveur verifie tout. Dans une FONCTION : ce fichier est au plafond des 200 variables locales.
;(function()
	local capacite = remotes:WaitForChild("Capacite")
	local b = Instance.new("TextButton")
	b.Name = "BoutonCapacite"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(104, 104)
	-- a droite de la main, au-dessus de la file « a venir »
	b.Position = UDim2.new(0.5, 330, 1, -150) -- a -205, il couvrait « revient dans N cartes » (capture du 2026-09-21)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	b.Visible = false
	b.ZIndex = 30
	b.Parent = gui
	local rond = Instance.new("UICorner")
	rond.CornerRadius = UDim.new(0.5, 0)
	rond.Parent = b
	local bord = Instance.new("UIStroke")
	bord.Thickness = 4
	bord.Color = Color3.fromRGB(40, 25, 5)
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	local function ligne(taille, y, h)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(0.9, 0, h, 0)
		t.Position = UDim2.new(0.05, 0, y, 0)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.ZIndex = 31
		t.Parent = b
		return t
	end
	local nom = ligne(0, 0.14, 0.2)
	local grand = ligne(0, 0.34, 0.36)
	local cout = ligne(0, 0.72, 0.16)
	b.MouseButton1Click:Connect(function()
		capacite:FireServer()
	end)
	function hud.majCapacite(c)
		b.Visible = c ~= nil and not hud.partieFinie
		if not c then
			return
		end
		nom.Text = c.nom
		cout.Text = c.cout .. " elixir"
		if c.reste > 0 then
			grand.Text = c.reste .. " s"
			b.BackgroundColor3 = Color3.fromRGB(90, 80, 70)
		else
			grand.Text = c.pret and "PRET" or "ELIXIR"
			b.BackgroundColor3 = c.pret and Color3.fromRGB(255, 190, 40) or Color3.fromRGB(140, 110, 60)
		end
		bord.Color = c.pret and Color3.fromRGB(255, 245, 200) or Color3.fromRGB(40, 25, 5)
	end
end)()

-- UN SEUL CHEMIN POUR ENVOYER UNE EMOTE : le bouton l'appelle, et la mise en scene de capture
-- aussi (build.py --emote-repos). Rien n'est simule a l'affichage, c'est le vrai clic.
function hud.cliquerEmote(id)
	-- DELAI ANTI-SPAM : le serveur refusait en SILENCE une emote trop rapprochee. Le joueur voyait
	-- un bouton sans effet et re-cliquait. On applique ICI la meme regle partagee : on le DIT, et
	-- on n'envoie rien pour rien. Le serveur reste l'autorite.
	if not Emotes.autorisee(id, hud.emote.derniere, os.clock()) then
		Sons.jouer("refus")
		-- `hud.annoncer` et non `annoncer` : la fonction locale est declaree PLUS BAS dans ce
		-- fichier, elle vaudrait nil ici (meme piege que Hub:624, journal du 2026-09-20).
		hud.annoncer(Emotes.texteAttente(Emotes.resteAvant(hud.emote.derniere, os.clock())))
		return false
	end
	hud.emote.derniere = os.clock()
	EmoteEvent:FireServer(id)
	return true
end

-- Les boutons s'ETEIGNENT pendant le repos : le joueur voit d'un coup d'oeil qu'il doit attendre,
-- au lieu de le decouvrir en cliquant. Range dans `hud` (ce fichier est au plafond des locales).
hud.emote = hud.emote or {}
function hud.majEmotes()
	local reste = Emotes.resteAvant(hud.emote.derniere, os.clock())
	for _, b in pairs(boutonsEmote) do
		b.BackgroundTransparency = reste > 0 and 0.6 or 0.2
		b.TextTransparency = reste > 0 and 0.45 or 0
		b.AutoButtonColor = reste <= 0
	end
end

-- COUPER LES EMOTES DE L'ADVERSAIRE. Une emote toutes les 3 s pendant trois minutes est le
-- harcelement classique du genre, et rien ne permettait d'y echapper. Ce bouton masque les bulles
-- du camp d'en face ; les siennes restent visibles.
local emotesCoupees = false
local boutonSilence = Instance.new("TextButton")
boutonSilence.Size = UDim2.new(0, 42, 0, 36)
boutonSilence.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
boutonSilence.BackgroundTransparency = 0.2
boutonSilence.TextColor3 = Color3.new(1, 1, 1)
boutonSilence.TextScaled = true
boutonSilence.Font = Enum.Font.GothamBold
boutonSilence.Text = "ON"
boutonSilence.Parent = emotesBarre
coinUI(boutonSilence, 10)
contourUI(boutonSilence, 2, Color3.fromRGB(10, 12, 20), 0.2)
local function bulleAdverse(gui)
	if gui.Name ~= "BulleEmote" then
		return false
	end
	local tour = gui.Parent
	-- la tour du Roi du camp d'en face : celle qui est de l'AUTRE cote de la riviere que le joueur.
	local sens = (monCamp == 1) and 1 or -1
	return tour and tour:IsA("BasePart") and tour.Position.Z * sens > 0
end
local function appliquerSilence()
	local arene = workspace:FindFirstChild("Arena")
	if not arene then
		return
	end
	for _, d in ipairs(arene:GetDescendants()) do
		if d:IsA("BillboardGui") and bulleAdverse(d) then
			d.Enabled = not emotesCoupees
		end
	end
end
boutonSilence.MouseButton1Click:Connect(function()
	emotesCoupees = not emotesCoupees
	boutonSilence.Text = emotesCoupees and "OFF" or "ON"
	appliquerSilence()
end)
workspace.DescendantAdded:Connect(function(d)
	if emotesCoupees and d:IsA("BillboardGui") and bulleAdverse(d) then
		d.Enabled = false
	end
end)

-- PRONOSTIC (spectateur seulement) : parier sur le camp gagnant, une fois par partie.
local pronoChoisi = nil
local pronoFinVue = false
local pronoBarre = Instance.new("Frame")
pronoBarre.BackgroundTransparency = 1
pronoBarre.Size = UDim2.new(0, 260, 0, 44)
-- sous le nom d'arene (qui finit a 102 px) : a 86, les deux textes se chevauchaient.
pronoBarre.Position = UDim2.new(0.5, -130, 0, 110)
pronoBarre.Visible = false
pronoBarre.Parent = gui
local pronoListe = Instance.new("UIListLayout")
pronoListe.FillDirection = Enum.FillDirection.Horizontal
pronoListe.Padding = UDim.new(0, 8)
pronoListe.Parent = pronoBarre
-- CAMP 1 = BLEU, CAMP 2 = ROUGE (GameServer.teamColor). Les boutons annoncaient l'inverse : le
-- spectateur pariait sur le camp qu'il croyait rouge et gagnait quand le BLEU l'emportait.
for camp, def in ipairs({ { "Bleu gagne", Color3.fromRGB(60, 110, 210) }, { "Rouge gagne", Color3.fromRGB(200, 60, 60) } }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 126, 1, 0)
	b.BackgroundColor3 = def[2]
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Text = def[1]
	b.Parent = pronoBarre
	coinUI(b, 10)
	degradeUI(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170))
	contourUI(b, 2, Color3.fromRGB(10, 12, 20), 0.15)
	b.MouseButton1Click:Connect(function()
		pronoChoisi = camp
		pronoBarre.Visible = false
		PronosticEvent:FireServer(camp)
	end)
end

local bottom = Instance.new("Frame")
bottom.Size = UDim2.new(0, 560, 0, 170)
bottom.Position = UDim2.new(0.5, -280, 1, -180)
bottom.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
bottom.BackgroundTransparency = 0.2
bottom.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = bottom
-- relief du panneau : le haut s'eclaircit, le bas s'assombrit, un trait sombre le detache de l'arene.
degradeUI(bottom, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 140))
contourUI(bottom, 3, Color3.fromRGB(10, 12, 20), 0.1)
-- petites fenetres : le panneau reduit pour ne pas couvrir le cote joueur
local panelScale = Instance.new("UIScale")
panelScale.Parent = bottom
bottom.AnchorPoint = Vector2.new(0.5, 1)
bottom.Position = UDim2.new(0.5, 0, 1, -6)
local function fitPanel()
	panelScale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1)
end
fitPanel()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)

local buttons = {}
local selected = nil
-- GESTE EN COURS : d'ou le doigt est parti, et ou il se trouve. Sans ce suivi, l'apercu ne pouvait
-- pas accompagner un glisse au doigt (GetMouseLocation ne bouge pas pendant un toucher).
local glisseDepart = nil -- { x, y, index }
local pointeurX, pointeurY = nil, nil
-- MAIN COURANTE : les identifiants des 4 cartes, tenus a jour par l'etat serveur. La fiche en a
-- besoin au moment du clic droit, alors que les boutons, eux, sont crees une seule fois.
local mainCourante = {}
-- Clics a AVALER : un appui long a deja ouvert la fiche, le clic de relachement ne doit pas
-- selectionner la carte en plus.
local ignorerClic = {}
local lastHand = {}
local currentElixir = 0

-- Declaree EN AVANT : `majApercu` l'appelle, et elle est definie plus bas. En Luau une fonction
-- locale posee APRES son usage vaut nil a l'appel — l'apercu plantait a chaque image (journal
-- Studio du 2026-09-20 : « GameClient:734: attempt to call a nil value »), donc ni le disque de
-- pose ni le cercle de portee ne s'affichaient.
local poseClientPermise

-- ===== APERCU DE POSE =====
-- Tant qu'une carte est choisie, un disque au sol suit la visee : VERT si la pose passe, ROUGE
-- sinon, et a la taille reelle de ce qu'on pose (le rayon d'effet pour un sort). Un fantome
-- transparent montre la silhouette de l'unite. Tout est LOCAL a ce client : rien n'est replique,
-- l'adversaire ne voit pas ou l'on hesite.
local apercuDossier, apercuDisque, apercuPieces = nil, nil, {}
-- apercuPortee : le cercle de portee d'attaque ; nil pour un sort ou un corps a corps.
local apercuCarteId, apercuPortee = nil, nil

local function effacerApercu()
	if apercuDossier then
		apercuDossier:Destroy()
	end
	apercuDossier, apercuDisque, apercuPieces, apercuCarteId = nil, nil, {}, nil
	apercuPortee = nil
end

-- (Re)construit le disque et le fantome pour CETTE carte. Refait seulement au changement de carte :
-- on ne recree pas des dizaines de pieces a chaque image.
local function construireApercu(card)
	effacerApercu()
	apercuDossier = Instance.new("Folder")
	apercuDossier.Name = "ApercuPose"
	apercuDossier.Parent = workspace
	local rayon = Apercu.rayonCercle(card)
	apercuDisque = Instance.new("Part")
	apercuDisque.Name = "ApercuDisque"
	apercuDisque.Anchored = true
	apercuDisque.CanCollide = false
	apercuDisque.CanQuery = false
	apercuDisque.CastShadow = false
	apercuDisque.Shape = Enum.PartType.Cylinder
	apercuDisque.Size = Vector3.new(0.15, rayon * 2, rayon * 2)
	apercuDisque.Material = Enum.Material.Neon
	apercuDisque.Transparency = 0.45
	apercuDisque.Parent = apercuDossier
	-- CERCLE DE PORTEE : jusqu'ou la carte FRAPPERA depuis ce point. L'apercu disait ou la pose
	-- est permise, jamais si la cible serait a portee : on posait un tireur trois studs trop bas
	-- et on l'apprenait apres, l'elixir deja parti. Rien pour un sort (son rayon EST le disque)
	-- ni pour un corps a corps (le cercle collerait au disque).
	local rayonPortee = Apercu.rayonPortee(card)
	if rayonPortee then
		-- ANNEAU, pas disque : un second disque plein par-dessus celui de la pose donnait une
		-- seule tache verdatre ou l'on ne distinguait plus rien (capture du 2026-09-20).
		apercuPortee = {}
		for i, seg in ipairs(Apercu.segmentsAnneau(rayonPortee)) do
			local bout = Instance.new("Part")
			bout.Name = "ApercuPortee"
			bout.Anchored = true
			bout.CanCollide = false
			bout.CanQuery = false
			bout.CastShadow = false
			bout.Size = Vector3.new(0.35, 0.12, seg.longueur)
			bout.Material = Enum.Material.Neon
			bout.Color = Apercu.COULEUR_PORTEE
			bout.Transparency = Apercu.TRANSPARENCE_PORTEE
			bout.Parent = apercuDossier
			apercuPortee[i] = { part = bout, x = seg.x, z = seg.z, angle = seg.angle }
		end
	end
	for _, piece in ipairs(Apercu.piecesFantome(card, true)) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Size = piece.taille
		part.Transparency = piece.transparence
		-- SmoothPlastic et non Neon : en neon, toutes les pieces se fondaient en une seule tache
		-- verte et la carte n'etait plus reconnaissable (capture du 2026-09-20).
		part.Material = Enum.Material.SmoothPlastic
		part.Color = piece.couleur
		if piece.forme == "boule" then
			part.Shape = Enum.PartType.Ball
		elseif piece.forme == "cylindre" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Parent = apercuDossier
		table.insert(apercuPieces, { part = part, ecart = piece.pos, rot = piece.rot })
	end
	apercuCarteId = card.id
end

-- SURLIGNAGE DE LA ZONE DE POSE ------------------------------------------------------------------
-- Une carte armee, et rien ne disait OU elle pouvait atterrir : le joueur decouvrait la limite en
-- se faisant refuser. Et la moitie adverse OUVERTE par une tour tombee — la regle la plus
-- valorisante du jeu — etait totalement invisible.
local zoneDossier, zoneSignature = nil, nil
local ouvertureAnnoncee = false

local function effacerZone()
	if zoneDossier then
		zoneDossier:Destroy()
	end
	zoneDossier, zoneSignature = nil, nil
end

local function construireZone(card, gauche, droite)
	effacerZone()
	zoneDossier = Instance.new("Folder")
	zoneDossier.Name = "ZonePose"
	zoneDossier.Parent = workspace
	-- fix-ok (capture moteur du 2026-09-20) : en Neon et pleine, la dalle DELAVAIT toute la scene —
	-- decor, unites et tours viraient au bleu pale, on ne lisait plus rien. Deux corrections : une
	-- matiere mate au lieu du neon, et pour la zone TOTALE (un sort vise partout) un simple LISERE
	-- au lieu d'un aplat sur l'arene entiere.
	local function dalle(rgb, x, z, largeur, longueur, transparence, nom)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = transparence
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		p.Size = Vector3.new(largeur, 0.08, longueur)
		p.Position = Vector3.new(x, 0.57, z)
		p.Parent = zoneDossier
	end
	-- fix-ok (deuxieme capture du 2026-09-20) : a 0,92 de transparence, la dalle etait INVISIBLE
	-- sur l'herbe — le surlignage n'informait plus de rien. Le juste milieu n'est pas une histoire
	-- d'opacite : c'est un CONTOUR net (qui se lit sur n'importe quel fond) plus un voile leger.
	local EPAIS = 1.2 -- largeur du lisere, en studs
	local function contour(rgb, r, transparence)
		dalle(rgb, r.x, r.z + r.longueur / 2 - EPAIS / 2, r.largeur, EPAIS, transparence, "ZoneBord")
		dalle(rgb, r.x, r.z - r.longueur / 2 + EPAIS / 2, r.largeur, EPAIS, transparence, "ZoneBord")
		dalle(rgb, r.x - r.largeur / 2 + EPAIS / 2, r.z, EPAIS, r.longueur, transparence, "ZoneBord")
		dalle(rgb, r.x + r.largeur / 2 - EPAIS / 2, r.z, EPAIS, r.longueur, transparence, "ZoneBord")
	end
	for _, r in ipairs(Zone.rectangles(monCamp, card, gauche, droite,
		ARENE_DEMI_LARGEUR, ARENE_DEMI_LONGUEUR)) do
		local rgb = Zone.couleur(r.genre)
		-- CONTOUR dans tous les cas : c'est lui qui dit la limite, et il ne delave rien.
		contour(rgb, r, 0.15)
		if r.genre ~= "totale" then
			-- voile leger a l'interieur : il designe la surface sans repeindre le decor. Pour un
			-- SORT (zone totale), aucun voile : toute l'arene serait couverte.
			dalle(rgb, r.x, r.z, r.largeur, r.longueur,
				(r.genre == "ouverte") and 0.74 or 0.84, "Zone" .. r.genre)
		end
	end
end

-- Suit la visee a chaque image. Sans carte choisie, l'apercu disparait.
local function majApercu()
	local fige0 = ReplicatedStorage:FindFirstChild("BRR_APERCU")
	-- « portee » : on RE-verifie a chaque image tant que la carte armee n'a pas de portee. La
	-- main arrive apres le premier appel et change : arme a l'instant 0, on tombait sur une
	-- carte de corps a corps une fois la vraie main distribuee (capture du 2026-09-20).
	local veutPortee = fige0 and fige0:IsA("StringValue") and fige0.Value == "portee"
	local armeeSansPortee = veutPortee and selected ~= nil
		and Apercu.rayonPortee(Cards.byId[lastHand[selected]]) == nil
	if fige0 and (not selected or armeeSansPortee) and lastHand[1] then
		-- CAPTURE : une carte reste armee, pour que l'apercu ET le surlignage de zone soient
		-- visibles. « sort » force une carte de SORT si la main en contient une : c'est le seul
		-- moyen de voir le LISERE de la zone totale sur une image.
		selected = 1
		local veut = fige0:IsA("StringValue") and fige0.Value or ""
		-- « portee » : on arme un TIREUR (portee >= PORTEE_MINI), seule facon de voir le cercle
		-- de portee sur une image ; la main etant tiree au hasard, elle n'en contient pas toujours.
		if veut == "portee" then
			for i = 1, 4 do
				if Apercu.rayonPortee(Cards.byId[lastHand[i]]) then
					selected = i
					veut = ""
					break
				end
			end
			if veut == "portee" then
				for _, c in ipairs(Cards.list) do
					if Apercu.rayonPortee(c) then
						lastHand[1] = c.id
						selected = 1
						break
					end
				end
			end
		end
		if veut == "sort" then
			local trouve = false
			for i = 1, 4 do
				local c = Cards.byId[lastHand[i]]
				if c and c.sort then
					selected, trouve = i, true
					break
				end
			end
			if not trouve then
				-- La main est tiree au hasard : elle ne contient pas toujours un sort. Pour la
				-- CAPTURE (et elle seule), on arme localement le premier sort du catalogue —
				-- l'apercu et le surlignage sont locaux, aucune pose n'est envoyee au serveur.
				for _, c in ipairs(Cards.list) do
					if c.sort then
						lastHand[1] = c.id
						selected = 1
						break
					end
				end
			end
		end
	end
	if not selected or jeSuisSpectateur then
		if apercuDossier then
			effacerApercu()
		end
		effacerZone() -- plus de carte armee : plus de surlignage
		return
	end
	local card = Cards.byId[lastHand[selected]]
	local arene = workspace:FindFirstChild("Arena")
	if not card or not arene then
		effacerApercu()
		return
	end
	if apercuCarteId ~= card.id then
		construireApercu(card)
	end
	-- ZONE : reconstruite seulement au changement de carte ou de tour tombee (Zone.signature),
	-- jamais a chaque image.
	local sensEnnemiZ = (monCamp == 1) and 1 or -1
	local deboutZ = { [-1] = false, [1] = false }
	for _, part in ipairs(arene:GetChildren()) do
		if part.Name == "PrincessTower" and part.Position.Z * sensEnnemiZ > 0 then
			deboutZ[part.Position.X < 0 and -1 or 1] = true
		end
	end
	local gaucheOuverte, droiteOuverte = not deboutZ[-1], not deboutZ[1]
	local signature = Zone.signature(monCamp, card, gaucheOuverte, droiteOuverte)
	if signature ~= zoneSignature then
		construireZone(card, gaucheOuverte, droiteOuverte)
		zoneSignature = signature
		-- SONDE (copie de test) : ce qui a REELLEMENT ete dessine. Une image peut etre ambigue,
		-- cette ligne ne l'est pas.
		if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") and zoneDossier then
			local genres = {}
			for _, p in ipairs(zoneDossier:GetChildren()) do
				genres[p.Name] = (genres[p.Name] or 0) + 1
			end
			local bouts = {}
			for nom, n in pairs(genres) do
				table.insert(bouts, nom .. "x" .. n)
			end
			table.sort(bouts)
			print(string.format("[BRRZONE] carte=%s sort=%s dalles=%s voie_gauche=%s voie_droite=%s",
				card.id, tostring(card.sort ~= nil), table.concat(bouts, ","),
				tostring(gaucheOuverte), tostring(droiteOuverte)))
		end
	end
	-- UNE SEULE annonce quand une voie s'ouvre : la regle etait invisible, la dire une fois suffit.
	if (gaucheOuverte or droiteOuverte) and not ouvertureAnnoncee then
		ouvertureAnnoncee = true
		local phrase = Zone.annonceOuverture(gaucheOuverte, droiteOuverte)
		if phrase then
			-- `hud.annoncer` et non `annoncer` : la fonction locale est declaree PLUS BAS (ligne
			-- « local function annoncer »). Ici `annoncer` etait donc une GLOBALE vide : la chute
			-- d'une tour de cote faisait planter l'annonce au lieu de l'afficher (selene, 2026-09-30).
			hud.annoncer(phrase)
		end
	end
	-- CAPTURE (copie de test) : sans utilisateur, la souris ne pointe jamais l'arene et l'apercu
	-- ne se montrerait sur aucune image. BRR_APERCU fige la visee a un point fixe de la moitie
	-- du joueur. Ce chemin n'existe que dans la copie de test.
	local fige = ReplicatedStorage:FindFirstChild("BRR_APERCU")
	local ray
	if fige then
		local cible = Vector3.new(-8, 0.5, -14)
		ray = { Origin = cible + Vector3.new(0, 60, 0), Direction = Vector3.new(0, -1, 0) }
	else
		-- pendant un glisse au doigt, c'est la DERNIERE position touchee qui compte : la souris,
		-- elle, ne bouge pas.
		local px, py
		if glisseDepart and pointeurX then
			px, py = pointeurX, pointeurY
		else
			local pos = UserInputService:GetMouseLocation()
			px, py = pos.X, pos.Y
		end
		ray = camera:ScreenPointToRay(px, py)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arene }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then
		apercuDossier.Parent = nil -- hors de l'arene : on cache sans detruire
		return
	end
	apercuDossier.Parent = workspace
	local p = hit.Position
	-- meme regle que le serveur : le joueur voit EXACTEMENT ce qui sera accepte
	local permise = poseClientPermise(card, p.X, p.Z, arene)
	local teinte = Apercu.teinte(permise)
	apercuDisque.Color = teinte
	apercuDisque.CFrame = CFrame.new(p.X, 0.62, p.Z) * CFrame.Angles(0, 0, math.rad(90))
	if apercuPortee then
		-- Pose SOUS le disque de pose (0,58 contre 0,62) : le disque vert ou rouge reste
		-- l'information principale, l'anneau n'est qu'un repere.
		for _, seg in ipairs(apercuPortee) do
			seg.part.CFrame = CFrame.new(p.X + seg.x, 0.58, p.Z + seg.z)
				* CFrame.Angles(0, math.rad(seg.angle), 0)
		end
	end
	local hauteur = Apercu.hauteurAuSol(card, 0.5)
	for _, f in ipairs(apercuPieces) do
		-- la couleur de la piece ne bouge pas (on reconnait la carte) ; seul le disque dit oui/non
		f.part.CFrame = CFrame.new(p.X, hauteur, p.Z) * CFrame.new(f.ecart)
			* CFrame.Angles(math.rad(f.rot and f.rot.X or 0), math.rad(f.rot and f.rot.Y or 0),
				math.rad(f.rot and f.rot.Z or 0))
	end
end

RunService.RenderStepped:Connect(majApercu)

-- POSE PERMISE, VUE DU CLIENT. Un seul endroit pour la visee ET pour le clic : les deux montraient
-- des regles differentes, et aucun des deux ne connaissait les cartes qui se posent PARTOUT
-- (le Mineur, `poseLibre`) ni les batiments. Resultat mesure : une pose LEGALE du Mineur chez
-- l'adversaire etait refusee par le client lui-meme, sans jamais atteindre le serveur.
function poseClientPermise(card, x, z, arene)
	if math.abs(x) > ARENE_DEMI_LARGEUR - 1 or math.abs(z) > ARENE_DEMI_LONGUEUR - 1 then
		return false
	end
	if card.sort or card.poseLibre then
		return true -- un sort vise toute l'arene ; le Mineur creuse ou il veut
	end
	if Batiments.est(card) then
		return Batiments.posePermise(monCamp, x, z, {})
	end
	local sensEnnemi = (monCamp == 1) and 1 or -1
	local debout = { [-1] = false, [1] = false }
	for _, part in ipairs(arene:GetChildren()) do
		if part.Name == "PrincessTower" and part.Position.Z * sensEnnemi > 0 then
			debout[part.Position.X < 0 and -1 or 1] = true
		end
	end
	return Regles.posePermise(monCamp, x, z, not debout[-1], not debout[1])
end

-- ===== FICHE D'UNE CARTE PENDANT LA PARTIE =====
-- La main ne portait qu'une etiquette d'UN mot (GEL, BOUCLIER...). Utile pour reconnaitre, pas
-- pour decider : combien de degats ? quel rayon ? combien de temps ? Ces chiffres n'existaient que
-- dans le hub, donc il fallait QUITTER la partie pour les lire — autant dire jamais.
--
-- Regle d'ergonomie : la fiche ne doit RIEN couter au geste principal. Le clic gauche continue de
-- choisir la carte, le clic sur l'arene continue de la poser. La fiche s'ouvre au clic DROIT ou
-- par un APPUI LONG (tactile), et le panneau absorbe les clics tant qu'il est ouvert, si bien
-- qu'on ne pose pas une carte par megarde en le refermant.
local FICHE_APPUI_LONG = 0.35 -- secondes d'appui avant d'ouvrir la fiche

local fichePanneau = Instance.new("Frame")
fichePanneau.Name = "FicheCarte"
fichePanneau.Size = UDim2.new(0, 460, 0, 300)
fichePanneau.Position = UDim2.new(0.5, -230, 0.5, -190)
fichePanneau.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
fichePanneau.BorderSizePixel = 0
fichePanneau.Visible = false
fichePanneau.ZIndex = 60
fichePanneau.Parent = gui
coinUI(fichePanneau, 16)
contourUI(fichePanneau, 3, Color3.fromRGB(255, 215, 110), 0)

local ficheTitre = label(fichePanneau, "", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 12))
ficheTitre.ZIndex = 61
local ficheCout = label(fichePanneau, "", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 56))
ficheCout.TextColor3 = Color3.fromRGB(230, 210, 255)
ficheCout.ZIndex = 61
local ficheStats = label(fichePanneau, "", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 86))
ficheStats.TextColor3 = Color3.fromRGB(190, 200, 220)
ficheStats.TextScaled = false
ficheStats.TextSize = 14
ficheStats.ZIndex = 61

local ficheListe = Instance.new("Frame")
ficheListe.BackgroundTransparency = 1
ficheListe.Size = UDim2.new(1, -24, 0, 130)
ficheListe.Position = UDim2.new(0, 12, 0, 114)
ficheListe.ZIndex = 61
ficheListe.Parent = fichePanneau
local ficheLayout = Instance.new("UIListLayout")
ficheLayout.SortOrder = Enum.SortOrder.LayoutOrder
ficheLayout.Padding = UDim.new(0, 3)
ficheLayout.Parent = ficheListe

local ficheFermer = Instance.new("TextButton")
-- Taille et place du bouton tirees du module : c'est ce qui garantit la marge annoncee
-- (Fiche.PANNEAU_MARGE) entre la derniere ligne et lui.
ficheFermer.Size = UDim2.new(0, 140, 0, Fiche.PANNEAU_BOUTON)
ficheFermer.Position = UDim2.new(0.5, -70, 1, -(Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS))
ficheFermer.Text = "FERMER"
ficheFermer.TextScaled = true
ficheFermer.Font = Enum.Font.GothamBold
ficheFermer.TextColor3 = Color3.new(1, 1, 1)
ficheFermer.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
ficheFermer.ZIndex = 62
ficheFermer.Parent = fichePanneau
coinUI(ficheFermer, 10)
ficheFermer.MouseButton1Click:Connect(function()
	fichePanneau.Visible = false
end)

local function ouvrirFiche(card)
	if not card then
		return
	end
	ficheTitre.Text = card.name
	ficheCout.Text = card.cost .. " elixir"
	ficheStats.Text = Fiche.stats(card)
	for _, e in ipairs(ficheListe:GetChildren()) do
		if e:IsA("TextLabel") then
			e:Destroy()
		end
	end
	local lignes = Fiche.lignes(card, extrasDe(card.id))
	if #lignes == 0 then
		table.insert(lignes, card.desc or "")
	end
	for i, ligne in ipairs(lignes) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 20)
		l.LayoutOrder = i
		l.Text = "• " .. ligne
		l.TextScaled = false
		l.TextSize = 14
		l.TextWrapped = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.fromRGB(235, 225, 170)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 61
		l.Parent = ficheListe
	end
	-- HAUTEUR AJUSTEE au nombre de lignes (regle pure : Fiche.hauteurPanneau). Une carte a un
	-- seul effet n'ouvre plus un grand vide au milieu de l'arene, et une carte a cinq lignes
	-- n'est plus tronquee.
	local hauteur = Fiche.hauteurPanneau(#lignes)
	fichePanneau.Size = UDim2.new(0, 460, 0, hauteur)
	fichePanneau.Position = UDim2.new(0.5, -230, 0.5, -math.floor(hauteur / 2) - 40)
	ficheListe.Size = UDim2.new(1, -24, 0, Fiche.hauteurListe(#lignes))
	fichePanneau.Visible = true
end

for i = 1, 4 do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 110, 0, 120)
	b.Position = UDim2.new(0, 10 + (i - 1) * 118, 0, 10)
	b.TextWrapped = true
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.2
	b.AutoButtonColor = true
	b.Parent = bottom
	coinUI(b, 14)
	-- carte en relief + contour cartoon ; le liseré jaune de selection reste au-dessus.
	degradeUI(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(145, 145, 165))
	contourUI(b, 3, Color3.fromRGB(10, 12, 20), 0.05)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 0
	stroke.Color = Color3.fromRGB(255, 230, 80)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	-- CLIC DROIT : ouvre la fiche sans toucher a la selection (MouseButton1 reste le geste de jeu).
	b.MouseButton2Click:Connect(function()
		ouvrirFiche(Cards.byId[mainCourante[i]])
	end)
	-- APPUI LONG (tactile) : meme resultat sans clic droit. Le clic de selection qui suit le
	-- relachement est avale, sinon l'appui long choisirait AUSSI la carte.
	local appuiT = nil
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			appuiT = os.clock()
		end
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- GLISSER-DEPOSER : on arme la carte des l'appui et on retient le point de depart.
			-- Un simple clic (deplacement sous le seuil) garde l'ancien mode en deux temps.
			glisseDepart = { x = input.Position.X, y = input.Position.Y, index = i }
			pointeurX, pointeurY = input.Position.X, input.Position.Y
			selected = i
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and appuiT then
			if os.clock() - appuiT >= FICHE_APPUI_LONG then
				ouvrirFiche(Cards.byId[mainCourante[i]])
				ignorerClic[i] = true
			end
			appuiT = nil
		end
	end)
	b.MouseButton1Click:Connect(function()
		if ignorerClic[i] then
			ignorerClic[i] = nil
			return -- ce clic termine un appui long : il a deja ouvert la fiche
		end
		if selected == i then
			selected = nil
		else
			selected = i
			Sons.jouer("selection")
		end
	end)
	-- JAUGE DE COUT : un filet en bas de la carte, qui se remplit a mesure que l'elixir monte.
	-- Le chiffre dit COMBIEN il manque, la jauge dit OU on en est — elle se lit sans lire.
	local fondJauge = Instance.new("Frame")
	-- La jauge est posee A COTE du bouton (dans la barre), et non DEDANS : la marge reservee au
	-- texte deplacerait aussi ses enfants, et la jauge remonterait sous les lettres.
	fondJauge.Size = UDim2.new(0, 110 - 16, 0, 6)
	fondJauge.Position = UDim2.new(0, 10 + (i - 1) * 118 + 8, 0, 10 + 120 - 12)
	fondJauge.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
	fondJauge.BorderSizePixel = 0
	fondJauge.Visible = false
	fondJauge.ClipsDescendants = true
	fondJauge.Parent = bottom
	coinUI(fondJauge, 3)
	-- Le texte du bouton est mis a l'echelle et descendait SOUS la jauge (capture du 2026-09-20) :
	-- on lui reserve le bas du bouton quand la jauge est la.
	local marge = Instance.new("UIPadding")
	marge.Parent = b
	local jauge = Instance.new("Frame")
	jauge.Size = UDim2.new(0, 0, 1, 0)
	jauge.BackgroundColor3 = Color3.fromRGB(215, 120, 245)
	jauge.BorderSizePixel = 0
	jauge.Parent = fondJauge

	buttons[i] = { button = b, stroke = stroke, fondJauge = fondJauge, jauge = jauge, marge = marge }
	-- Le texte de la carte est mis a l'echelle, mais `TextScaled` s'arrete a une taille minimale :
	-- sur un nom long (« Zibra Zubra Zibralini ») qui passe deja sur trois lignes, la derniere
	-- ligne sortait du bouton — le cout etait coupe en bas (capture cap-etiquettes.png du
	-- 2026-09-21). On abaisse ce plancher pour que tout tienne, quelle que soit la carte.
	buttons[i].plafond = Instance.new("UITextSizeConstraint")
	buttons[i].plafond.MinTextSize = 8
	buttons[i].plafond.MaxTextSize = 28
	buttons[i].plafond.Parent = b
	-- IMAGE DE LA CARTE (2026-09-21) : la main n'etait que des aplats portant un nom. La figurine
	-- (modele 3D, silhouette ou embleme du sort : Figurine.lua) occupe le HAUT de la carte, le texte
	-- descend dessous. Posee dans la barre, comme la jauge : la marge du texte deplacerait ses enfants.
	buttons[i].vue = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine")).vue(bottom, b.ZIndex + 1)
	buttons[i].vue.Size = UDim2.new(0, 100, 0, 62)
	buttons[i].vue.Position = UDim2.new(0, 10 + (i - 1) * 118 + 5, 0, 10 + 3)
	marge.PaddingTop = UDim.new(0, 62)
end

-- CARTES A VENIR. Defaut mesure le 2026-09-20 (capture cap-cout-main.png) : les deux prochaines
-- cartes etaient une LIGNE DE TEXTE gris (« A venir Tralalero Tralala 3 Ballerina Cappuccina 2 »).
-- A cote de quatre vignettes colorees, elle ne se lisait pas : il fallait la LIRE, mot a mot, pour
-- savoir ce qui arrive — alors que l'interet de les annoncer est le coup d'oeil. Elles deviennent
-- deux petites cartes, de la meme couleur et du meme format que celles de la main.
local nextTitre = label(bottom, "A VENIR", UDim2.new(0, 116, 0, 14), UDim2.new(0, 482, 0, 8))
nextTitre.TextColor3 = Color3.fromRGB(180, 188, 205)
nextTitre.TextScaled = false
nextTitre.TextSize = 12

-- Rangees dans `buttons`, comme les reperes de la jauge : le corps de ce fichier est a la limite
-- de Lua (200 variables locales), et une variable de plus le fait refuser de compiler.
buttons.apercus = {}
do
	local apercus = buttons.apercus
	for n = 1, 2 do
	local v = Instance.new("TextLabel")
	v.Size = UDim2.new(0, 116, 0, 48)
	v.Position = UDim2.new(0, 482, 0, 26 + (n - 1) * 54)
	v.BackgroundColor3 = Color3.fromRGB(60, 64, 88)
	v.BorderSizePixel = 0
	v.TextWrapped = true
	v.TextScaled = true
	v.Font = Enum.Font.GothamBold
	v.TextColor3 = Color3.new(1, 1, 1)
	v.TextStrokeTransparency = 0.3
	v.Text = ""
	v.Parent = bottom
	coinUI(v, 10)
	-- Meme contour cartoon que les cartes en main : c'est ce qui les fait lire comme des CARTES
	-- et non comme une etiquette.
	contourUI(v, 2, Color3.fromRGB(10, 12, 20), 0.15)
	local st = Instance.new("UIStroke")
	st.Thickness = 0
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = v
	apercus[n] = { vignette = v, stroke = st }
	-- Meme image que la main, en petit, a gauche ; le texte se decale d'autant.
	apercus[n].vue = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine")).vue(bottom, v.ZIndex + 1)
	apercus[n].vue.Size = UDim2.new(0, 44, 0, 44)
	apercus[n].vue.Position = UDim2.new(0, 482 + 2, 0, 26 + (n - 1) * 54 + 2)
	local decale = Instance.new("UIPadding")
	decale.PaddingLeft = UDim.new(0, 46)
	decale.Parent = v
	end
end
-- RETOUR DE LA DERNIERE CARTE JOUEE, sous les deux vignettes. `Cycle.retour` etait ecrit et teste
-- mais appele par PERSONNE : compter son cycle — savoir dans combien de cartes celle qu'on vient
-- de jouer revient — est pourtant ce qui decide si l'on depense sa carte de defense maintenant ou
-- si on la garde. Le joueur devait tenir ce compte de tete, sur huit cartes.
buttons.retour = label(gui, "", UDim2.new(0, 260, 0, 30), UDim2.new(0.5, 44, 1, -212))
buttons.retour.AnchorPoint = Vector2.new(0, 1)
buttons.retour.TextXAlignment = Enum.TextXAlignment.Right
buttons.retour.TextColor3 = Color3.fromRGB(190, 200, 220)
buttons.retour.TextScaled = false
buttons.retour.TextSize = 11
buttons.retour.TextWrapped = true
bottom.Size = UDim2.new(0, 608, 0, 170)

-- Le chat Roblox couvre le haut gauche de l'arene : on le masque dans un duel contre le bot,
-- mais on le rend face a un humain et aux spectateurs (le serveur envoie s.chatVisible).
local chatVoulu = false
local chatApplique = nil
local function appliquerChat()
	if chatApplique == chatVoulu then
		return
	end
	local StarterGui = game:GetService("StarterGui")
	if pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, chatVoulu)
	end) then
		chatApplique = chatVoulu
	end
end
task.spawn(function()
	for _ = 1, 20 do
		appliquerChat()
		if chatApplique ~= nil then
			break
		end
		task.wait(0.5)
	end
end)

local elixirBack = Instance.new("Frame")
elixirBack.Size = UDim2.new(1, -20, 0, 24)
elixirBack.Position = UDim2.new(0, 10, 0, 138)
elixirBack.BackgroundColor3 = Color3.fromRGB(50, 20, 60)
elixirBack.Parent = bottom
coinUI(elixirBack, 12)
contourUI(elixirBack, 2, Color3.fromRGB(10, 12, 20), 0.1)
elixirBack.ClipsDescendants = true
local elixirFill = Instance.new("Frame")
elixirFill.BorderSizePixel = 0
elixirFill.BackgroundColor3 = Color3.fromRGB(210, 60, 230)
elixirFill.Size = UDim2.new(0, 0, 1, 0)
elixirFill.Parent = elixirBack
coinUI(elixirFill, 12)
-- lueur dans la jauge : clair en haut, sature en bas — c'est ce qui donne l'aspect « liquide »
-- au lieu d'une barre de couleur unie.
degradeUI(elixirFill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 110, 200))
-- REPERES DE COUT : un trait par cout DIFFERENT de la main, a sa place sur la jauge. Le joueur
-- lisait « 3 » sans voir ou s'arrete le prochain palier utile ; il devait relire ses quatre cartes
-- et comparer. Un trait deja franchi s'allume, les autres restent sombres : on voit d'un coup
-- combien de cartes sont payables et laquelle tombe au prochain cran.
-- Ils sont ranges dans `buttons` (et non dans une variable a eux) parce que le corps de ce
-- fichier a atteint la limite de Lua : 200 variables locales, refus de compiler au-dela.
buttons.reperes = {}
do
	local reperes = buttons.reperes
	for n = 1, 4 do
	local m = Instance.new("Frame")
	m.Size = UDim2.new(0, 2, 1, -8)
	m.Position = UDim2.new(0, 0, 0, 4)
	m.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	m.BorderSizePixel = 0
	m.ZIndex = 3
	m.Visible = false
	m.Parent = elixirBack
	reperes[n] = m
	end
end
local elixirText = label(elixirBack, "0", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
elixirText.ZIndex = 5

-- GASPILLAGE, DIT AU MOMENT OU IL SE PRODUIT. Juste au-dessus de la jauge : c'est la que le regard
-- se porte quand elle est pleine. Le bilan de fin, lui, arrive trop tard pour corriger la faute.
hud.gaspilleLabel = label(bottom, "", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 118))
hud.gaspilleLabel.TextScaled = false
hud.gaspilleLabel.TextSize = 13
hud.gaspilleLabel.TextColor3 = Color3.fromRGB(255, 205, 90)
hud.gaspilleLabel.Visible = false

-- MISE EN SCENE DU TUTORIEL ---------------------------------------------------------------------
-- Le serveur envoie l'etape en cours (`s.tuto`) ; ici on la JOUE, sans un mot d'explication :
-- un DOIGT qui pulse sur la zone de pose, la JAUGE d'elixir qui bat quand il faut attendre, la
-- CAMERA qui se rapproche pour regarder ses unites avancer. Le module Tutoriel nomme la mise en
-- scene (`montrer`) ; le client ne decide de rien d'autre que de la forme.
local tutoCouche = Instance.new("Frame")
tutoCouche.BackgroundTransparency = 1
tutoCouche.Size = UDim2.fromScale(1, 1)
tutoCouche.Visible = false
tutoCouche.ZIndex = 20
tutoCouche.Parent = gui

-- bandeau d'etape, en haut : « ETAPE 2 / 5 »
local tutoBandeau = Instance.new("Frame")
tutoBandeau.Size = UDim2.new(0, 220, 0, 34)
tutoBandeau.Position = UDim2.new(0.5, -110, 0, 124)
tutoBandeau.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
tutoBandeau.BackgroundTransparency = 0.15
tutoBandeau.ZIndex = 21
tutoBandeau.Parent = tutoCouche
coinUI(tutoBandeau, 10)
contourUI(tutoBandeau, 2, Color3.fromRGB(255, 205, 60), 0.2)
local tutoTexte = label(tutoBandeau, "", UDim2.new(1, -12, 1, -8), UDim2.new(0, 6, 0, 4))
tutoTexte.ZIndex = 22

-- DOIGT : un rond clair qui bat au-dessus de la zone de pose. Aucune image n'est chargee (pas
-- d'asset externe dans ce projet) : c'est un disque dessine, avec un halo qui respire.
local tutoDoigt = Instance.new("Frame")
tutoDoigt.Size = UDim2.new(0, 54, 0, 54)
tutoDoigt.AnchorPoint = Vector2.new(0.5, 0.5)
tutoDoigt.Position = UDim2.new(0.5, 0, 0.62, 0)
tutoDoigt.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
tutoDoigt.BackgroundTransparency = 0.25
tutoDoigt.ZIndex = 21
tutoDoigt.Visible = false
tutoDoigt.Parent = tutoCouche
coinUI(tutoDoigt, 27)
contourUI(tutoDoigt, 3, Color3.fromRGB(255, 205, 60), 0)

local tutoAnneau = Instance.new("Frame")
tutoAnneau.Size = UDim2.new(0, 54, 0, 54)
tutoAnneau.AnchorPoint = Vector2.new(0.5, 0.5)
tutoAnneau.Position = UDim2.new(0.5, 0, 0.62, 0)
tutoAnneau.BackgroundTransparency = 1
tutoAnneau.ZIndex = 20
tutoAnneau.Visible = false
tutoAnneau.Parent = tutoCouche
coinUI(tutoAnneau, 27)
local anneauTrait = contourUI(tutoAnneau, 3, Color3.fromRGB(255, 205, 60), 0)

-- Le battement est une seule boucle de temps : elle pilote le doigt, l'anneau qui s'ouvre et la
-- pulsation de la jauge. Une seule source de rythme, donc tout bat ENSEMBLE.
local tutoMontrer = nil
local tutoBattement = 0
RunService.RenderStepped:Connect(function(dt)
	if not tutoCouche.Visible then
		return
		end
	tutoBattement = (tutoBattement + dt) % 1.2
	local phase = tutoBattement / 1.2
	if tutoDoigt.Visible then
		tutoDoigt.BackgroundTransparency = 0.25 + 0.2 * math.sin(phase * math.pi * 2)
		local taille = 54 + 40 * phase
		tutoAnneau.Size = UDim2.new(0, taille, 0, taille)
		anneauTrait.Transparency = phase
	end
	if tutoMontrer == "jauge" then
		-- la jauge RESPIRE : c'est elle qu'il faut regarder quand l'elixir manque.
		elixirBack.BackgroundColor3 = Color3.fromRGB(50, 20, 60):Lerp(Color3.fromRGB(150, 60, 190),
			0.5 + 0.5 * math.sin(phase * math.pi * 2))
	else
		elixirBack.BackgroundColor3 = Color3.fromRGB(50, 20, 60)
	end
end)

-- Applique une etape recue du serveur. `nil` = plus de tutoriel : tout revient a la normale.
local function appliquerTuto(t)
	if not t then
		tutoCouche.Visible = false
		tutoCameraProche = false
		tutoDoigt.Visible = false
		tutoAnneau.Visible = false
		tutoMontrer = nil
		elixirBack.BackgroundColor3 = Color3.fromRGB(50, 20, 60)
		return
	end
	tutoCouche.Visible = true
	tutoMontrer = t.montrer
	tutoCameraProche = t.montrer == "camera_suit"
	tutoTexte.Text = "ETAPE " .. t.index .. " / " .. t.total
	local doigt = t.montrer == "doigt" or t.montrer == "zone_etendue" or t.montrer == "cible_air"
	tutoDoigt.Visible = doigt
	tutoAnneau.Visible = doigt
	if t.montrer == "zone_etendue" then
		tutoDoigt.Position = UDim2.new(0.5, 0, 0.42, 0)
		tutoAnneau.Position = UDim2.new(0.5, 0, 0.42, 0)
	elseif t.montrer == "cible_air" then
		tutoDoigt.Position = UDim2.new(0.5, 0, 0.34, 0)
		tutoAnneau.Position = UDim2.new(0.5, 0, 0.34, 0)
	else
		tutoDoigt.Position = UDim2.new(0.5, 0, 0.62, 0)
		tutoAnneau.Position = UDim2.new(0.5, 0, 0.62, 0)
	end
end


-- BANNIERE DE PHASE : « DOUBLE ELIXIR ! » puis « PROLONGATION ! ». Sans elle, le rythme changeait
-- sans que personne ne le voie — le joueur ne comprenait pas pourquoi l'adversaire posait deux
-- fois plus de cartes. Elle s'affiche 2,5 s au CHANGEMENT de phase, puis s'efface toute seule.
local banniere = Instance.new("TextLabel")
banniere.BackgroundTransparency = 1
banniere.Size = UDim2.new(1, 0, 0, 54)
banniere.Position = UDim2.new(0, 0, 0.16, 0)
banniere.Font = Enum.Font.GothamBlack
banniere.TextScaled = false
banniere.TextSize = 42
banniere.TextStrokeTransparency = 0
banniere.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
banniere.Visible = false
banniere.ZIndex = 20
banniere.Parent = gui
-- LIRE L'ADVERSAIRE ------------------------------------------------------------------------------
-- Trois informations qui manquaient totalement : combien d'elixir il a (estime, jamais lu dans son
-- compteur), ce qu'il a deja pose, et si une de mes tours est en train de tomber.
-- SOUS LA RANGEE DE BOUTONS, PAS DESSOUS. Mesure le 2026-09-20 (capture cap-regles-partie.png) :
-- ce cadre etait pose en (12, 12), exactement la ou le hub dessine MENU puis REGLES (rangee de
-- 44 px de haut posee a 12 px du bord). L'elixir estime de l'adversaire, sa jauge et la premiere
-- ligne de « Il a pose : » disparaissaient DERRIERE les boutons — l'information la plus utile du
-- panneau etait illisible. Les boutons vivent dans un autre script (Hub) : on ne peut pas lire
-- leur taille ici, c'est donc tools/test_lecture.py qui compare les deux fichiers et rougit si la
-- rangee grandit sans que ce cadre descende.
local HAUT_BOUTONS = 64 -- 12 (marge) + 44 (hauteur d'un bouton) + 8 (respiration)
hud.lectureCadre = Instance.new("Frame")
hud.lectureCadre.BackgroundTransparency = 1
hud.lectureCadre.Size = UDim2.new(0, 230, 0, 96)
hud.lectureCadre.Position = UDim2.new(0, 12, 0, HAUT_BOUTONS)
hud.lectureCadre.Parent = gui

hud.elixirAdverseTexte = label(hud.lectureCadre, "Adversaire : -", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0))
hud.elixirAdverseTexte.TextXAlignment = Enum.TextXAlignment.Left
hud.elixirAdverseTexte.TextColor3 = Color3.fromRGB(225, 180, 245)

hud.elixirAdverseFond = Instance.new("Frame")
hud.elixirAdverseFond.Size = UDim2.new(1, 0, 0, 10)
hud.elixirAdverseFond.Position = UDim2.new(0, 0, 0, 22)
hud.elixirAdverseFond.BackgroundColor3 = Color3.fromRGB(45, 20, 55)
hud.elixirAdverseFond.BorderSizePixel = 0
hud.elixirAdverseFond.Parent = hud.lectureCadre
coinUI(hud.elixirAdverseFond, 5)
hud.elixirAdverseFond.ClipsDescendants = true
hud.elixirAdverseJauge = Instance.new("Frame")
hud.elixirAdverseJauge.Size = UDim2.new(0, 0, 1, 0)
hud.elixirAdverseJauge.BackgroundColor3 = Color3.fromRGB(190, 90, 220)
hud.elixirAdverseJauge.BorderSizePixel = 0
hud.elixirAdverseJauge.Parent = hud.elixirAdverseFond

-- MON PROPRE CYCLE, a droite (symetrique de la lecture de l'adversaire, a gauche) : compter ce
-- qu'on a deja sorti est ce qui decide de la prochaine poussee.
hud.mesCartesTexte = label(gui, "", UDim2.new(0, 230, 0, 72), UDim2.new(1, -242, 0, 58))
hud.mesCartesTexte.TextXAlignment = Enum.TextXAlignment.Right
hud.mesCartesTexte.TextYAlignment = Enum.TextYAlignment.Top
hud.mesCartesTexte.TextScaled = false
hud.mesCartesTexte.TextSize = 13
hud.mesCartesTexte.TextColor3 = Color3.fromRGB(185, 205, 235)

hud.cartesVuesTexte = label(hud.lectureCadre, "", UDim2.new(1, 0, 0, 58), UDim2.new(0, 0, 0, 36))
hud.cartesVuesTexte.TextXAlignment = Enum.TextXAlignment.Left
hud.cartesVuesTexte.TextYAlignment = Enum.TextYAlignment.Top
hud.cartesVuesTexte.TextScaled = false
hud.cartesVuesTexte.TextSize = 13
hud.cartesVuesTexte.TextColor3 = Color3.fromRGB(190, 200, 215)

-- ALERTE DE TOUR : bandeau rouge qui bat, avec le COTE a regarder. Sans le cote, le joueur
-- cherchait la menace dans la mauvaise voie.
hud.alerteLabel = label(gui, "", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.26, 0))
hud.alerteLabel.TextColor3 = Color3.fromRGB(255, 95, 95)
hud.alerteLabel.Visible = false
hud.alerteLabel.ZIndex = 21
local alerteBattement = 0
RunService.RenderStepped:Connect(function(dt)
	if not hud.alerteLabel.Visible then
		return
	end
	alerteBattement = (alerteBattement + dt) % 0.8
	hud.alerteLabel.TextTransparency = 0.25 * (1 + math.sin(alerteBattement / 0.8 * math.pi * 2)) / 2
end)

local function majLecture(s)
	if s.spectateur then
		hud.lectureCadre.Visible = false
		hud.alerteLabel.Visible = false
		hud.mesCartesTexte.Visible = false
		return
	end
	-- la mise en page a le dernier mot : sur un ecran etroit, ce bloc cede la place
	hud.mesCartesTexte.Visible = hud.misePermet.mesCartes ~= false
	hud.lectureCadre.Visible = true
	local e = s.elixirAdverse or 0
	hud.elixirAdverseTexte.Text = "Adversaire : ~" .. e .. " elixir"
	hud.elixirAdverseJauge.Size = UDim2.new(e / Lecture.MAX_ELIXIR, 0, 1, 0)
	-- il ne peut plus rien payer de moins de 2 : le moment de pousser.
	hud.elixirAdverseTexte.TextColor3 = Lecture.peutRepondre(e, 4) and Color3.fromRGB(225, 180, 245)
		or Color3.fromRGB(150, 235, 170)
	local noms = {}
	for i, id in ipairs(s.cartesAdverses or {}) do
		local c = Cards.byId[id]
		if c then
			-- « x2 » : la carte est deja passee. Son deck tourne, elle revient vite.
			table.insert(noms, "- " .. c.name .. " (" .. c.cost .. ")"
				.. Lecture.marqueVue((s.passagesAdverses or {})[i]))
		end
	end
	hud.cartesVuesTexte.Text = #noms > 0 and ("Il a pose :\n" .. table.concat(noms, "\n")) or ""
	-- LE MIEN : meme lecture, sans retard ni estimation — ce sont MES poses, je les ai vues.
	local miennes = {}
	for i, id in ipairs(s.mesCartes or {}) do
		local c = Cards.byId[id]
		if c then
			table.insert(miennes, c.name .. " (" .. c.cost .. ")"
				.. Lecture.marqueVue((s.mesPassages or {})[i]))
		end
	end
	hud.mesCartesTexte.Text = #miennes > 0 and ("Tu as pose :\n" .. table.concat(miennes, "\n")) or ""
	local a = s.alerte
	-- INACTIVITE. Deux messages opposes, sur la meme ligne d'alerte :
	--  - a MOI, si je ne joue plus : un compte a rebours, pour me rattraper. Une partie qui
	--    s'arrete sans preavis passe pour un bug ou pour une deconnexion.
	--  - a moi AUSSI, si c'est l'adversaire qui ne joue plus : j'attendais sans comprendre.
	-- Mon propre avertissement passe devant : c'est le seul qui appelle une action de ma part.
	local inactivite = s.avertissementInactif or s.adversaireInactif
	if inactivite and not s.result then
		hud.alerteLabel.Visible = true
		hud.alerteLabel.Text = inactivite
		hud.alerteLabel.TextColor3 = s.avertissementInactif and Color3.fromRGB(255, 80, 80)
			or Color3.fromRGB(255, 190, 90)
		return
	end
	hud.alerteLabel.Visible = a ~= nil and not s.result
	if a then
		hud.alerteLabel.Text = a.texte or ""
		hud.alerteLabel.TextColor3 = (a.niveau == "critique") and Color3.fromRGB(255, 80, 80)
			or Color3.fromRGB(255, 190, 90)
	end
end

-- MESSAGE COURT (refus de pose, abandon, revanche). Le jeu refusait des gestes en silence : le
-- joueur ne pouvait pas apprendre la regle qu'il venait d'enfreindre.
hud.messageLabel = label(gui, "", UDim2.new(0, 520, 0, 34), UDim2.new(0.5, -260, 0.72, 0))
hud.messageLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
hud.messageLabel.Visible = false
hud.messageLabel.ZIndex = 22
local messageFin = 0
local function annoncer(texte)
	hud.messageLabel.Text = texte
	hud.messageLabel.Visible = true
	hud.messageLabel.TextTransparency = 0
	messageFin = os.clock() + 2.2
end
-- Pose dans `hud` pour les callbacks construits PLUS HAUT dans ce fichier (les boutons d'emote) :
-- une fonction locale n'existe pas encore a l'endroit ou ils sont ecrits.
hud.annoncer = annoncer
RunService.Heartbeat:Connect(function()
	if hud.messageLabel.Visible and os.clock() > messageFin then
		hud.messageLabel.Visible = false
	end
	-- Boutons d'emote eteints pendant le repos : le refus se VOIT avant le clic.
	hud.majEmotes()
end)
-- CAPTURE DU REFUS D'EMOTE (build.py --emote-repos) : deux clics d'affilee sur le MEME chemin que
-- le bouton. Le second tombe dans le delai de repos : le message et les boutons eteints qu'on
-- photographie sont ceux qu'un joueur voit en insistant.
if ReplicatedStorage:FindFirstChild("BRR_EMOTE_REPOS") then
	task.spawn(function()
		task.wait(11)
		hud.cliquerEmote("gg")
		task.wait(0.6)
		hud.cliquerEmote("gg")
		-- Le message central est PARTAGE avec les refus de pose, que le client de test declenche en
		-- boucle : sur la photo il peut deja avoir ete remplace. On imprime donc ce qui a ete
		-- REELLEMENT pose a l'ecran a cet instant, en plus des boutons eteints qui, eux, durent.
		print(string.format("[EMOTE] deux clics rapproches : label=%q visible=%s boutons_eteints=%s",
			hud.messageLabel.Text, tostring(hud.messageLabel.Visible),
			tostring(boutonsEmote.gg.BackgroundTransparency > 0.4)))
	end)
end

RefusEvent.OnClientEvent:Connect(function(motif)
	-- PARTIE FINIE : un refus de pose n'a plus rien a apprendre au joueur, l'ecran de fin est la
	-- reponse. Il arrivait pourtant (une pose partie juste avant la fin) et s'ecrivait PAR-DESSUS
	-- le bouton Rejouer — « partie terminee » en plein milieu (capture du 2026-09-21).
	if hud.partieFinie then
		return
	end
	Sons.jouer("refus")
	annoncer(tostring(motif))
end)

-- SPECTATEUR : SUIVRE UN JOUEUR -----------------------------------------------------------------
-- Il regardait une vue neutre, sans main ni camp : rien a anticiper, donc rien a commenter. Ici il
-- choisit le camp qu'il suit, et voit sa main — mais RETARDEE, pour qu'elle ne puisse pas servir a
-- souffler les cartes a l'adversaire (Spectateur.RETARD).
hud.suiviBouton = Instance.new("TextButton")
hud.suiviBouton.Size = UDim2.new(0, 150, 0, 32)
hud.suiviBouton.Position = UDim2.new(0.5, -75, 1, -46)
hud.suiviBouton.BackgroundColor3 = Color3.fromRGB(35, 40, 60)
hud.suiviBouton.BackgroundTransparency = 0.15
hud.suiviBouton.TextColor3 = Color3.new(1, 1, 1)
hud.suiviBouton.TextScaled = true
hud.suiviBouton.Font = Enum.Font.GothamBold
hud.suiviBouton.Text = "Suivre Rouge"
hud.suiviBouton.Visible = false
hud.suiviBouton.Parent = gui
coinUI(hud.suiviBouton, 10)
contourUI(hud.suiviBouton, 2, Color3.fromRGB(10, 12, 20), 0.2)

hud.mainSuivieTexte = label(gui, "", UDim2.new(0, 300, 0, 44), UDim2.new(0.5, -150, 1, -92))
hud.mainSuivieTexte.TextScaled = false
hud.mainSuivieTexte.TextSize = 13
hud.mainSuivieTexte.TextColor3 = Color3.fromRGB(200, 210, 230)
hud.mainSuivieTexte.Visible = false

hud.suiviBouton.MouseButton1Click:Connect(function()
	pcall(function()
		BoutiqueFn:InvokeServer("suivre")
	end)
end)

local function majSpectateur(s)
	-- Garde l'etat pour le clic d'arene (le fichier est au plafond des variables locales de Lua).
	hud.spectateur = s.spectateur == true
	hud.pariPossible = s.spectateur == true and not s.result
	hud.suiviBouton.Visible = s.spectateur == true and not s.result
	hud.mainSuivieTexte.Visible = hud.suiviBouton.Visible
	if not hud.suiviBouton.Visible then
		return
	end
	hud.suiviBouton.Text = s.suiviLibelle or "Suivre"
	local noms = {}
	for _, id in ipairs(s.mainSuivie or {}) do
		local c = Cards.byId[id]
		if c then
			table.insert(noms, c.name .. " (" .. c.cost .. ")")
		end
	end
	-- Le RETARD est ecrit noir sur blanc : sans cela, le spectateur croirait voir le present et
	-- s'etonnerait que « sa » carte ne soit pas jouee.
	hud.mainSuivieTexte.Text = #noms > 0
		and (Spectateur.nomCamp(s.campSuivi or 1) .. " avait en main (il y a "
			.. tostring(s.retardMain or Spectateur.RETARD) .. " s) : " .. table.concat(noms, ", "))
		or ""
end

-- QUALITE DE LA CONNEXION -----------------------------------------------------------------------
-- Un chiffre et une pastille de couleur, en haut a gauche sous la lecture de l'adversaire. Rien
-- ne disait au joueur que SA connexion decrochait : il en concluait que le jeu est casse, ou que
-- l'adversaire triche.
hud.pingLabel = label(gui, "-- ms", UDim2.new(0, 120, 0, 18), UDim2.new(0, 12, 0, HAUT_BOUTONS + 100))
hud.pingLabel.TextXAlignment = Enum.TextXAlignment.Left
hud.pingLabel.TextScaled = false
hud.pingLabel.TextSize = 13

hud.reseauAvertissement = label(gui, "", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.2, 0))
hud.reseauAvertissement.TextScaled = false
hud.reseauAvertissement.TextSize = 16
hud.reseauAvertissement.TextColor3 = Color3.fromRGB(255, 190, 90)
hud.reseauAvertissement.Visible = false
hud.reseauAvertissement.ZIndex = 21

local echantillons = {}
local pingEnCours = nil
local dernierEtatRecu = os.clock()
-- AVANT LE PREMIER ETAT, ON NE PARLE PAS DE COUPURE. Mesure du 2026-09-20 (capture moteur) : au
-- chargement, aucun etat n'est encore arrive et le bandeau « Connexion perdue » s'affichait
-- d'office — a chaque entree en partie, pour tout le monde. On n'accuse le reseau qu'apres avoir
-- eu au moins une preuve qu'il marchait.
local premierEtatRecu = false

PingEvent.OnClientEvent:Connect(function(jeton)
	if pingEnCours and jeton == pingEnCours then
		-- aller-retour REEL, en millisecondes
		echantillons = Reseau.ajouter(echantillons, (os.clock() - jeton) * 1000)
		pingEnCours = nil
	end
end)

task.spawn(function()
	while true do
		pingEnCours = os.clock()
		PingEvent:FireServer(pingEnCours)
		task.wait(2)
	end
end)

local function majReseau()
	local ms = Reseau.mediane(echantillons)
	local instable = Reseau.instable(echantillons)
	local perdu = premierEtatRecu and Reseau.perdu(os.clock() - dernierEtatRecu) or false
	hud.pingLabel.Text = Reseau.texte(ms)
	local q = perdu and "perdu" or Reseau.qualite(ms or 0)
	local c = Reseau.couleur(q)
	hud.pingLabel.TextColor3 = Color3.fromRGB(c[1], c[2], c[3])
	local texte = Reseau.avertissement(ms, instable, perdu)
	hud.reseauAvertissement.Visible = texte ~= nil
	hud.reseauAvertissement.Text = texte or ""
end

local attenteReseau = 0
RunService.Heartbeat:Connect(function(dt)
	attenteReseau = attenteReseau + dt
	if attenteReseau >= 0.5 then
		attenteReseau = 0
		majReseau()
	end
end)

-- SIGNALER L'ADVERSAIRE ---------------------------------------------------------------------
-- Un bouton discret, et une liste FERMEE de motifs : aucun texte libre a moderer. Le serveur
-- choisit la cible et refuse tout le reste ; ici on ne fait qu'ouvrir la liste et dire le retour.
hud.signalerBouton = Instance.new("TextButton")
hud.signalerBouton.Size = UDim2.new(0, 34, 0, 34)
hud.signalerBouton.Position = UDim2.new(1, -44, 0, 56)
hud.signalerBouton.BackgroundColor3 = Color3.fromRGB(40, 30, 40)
hud.signalerBouton.BackgroundTransparency = 0.25
hud.signalerBouton.TextColor3 = Color3.fromRGB(255, 190, 190)
hud.signalerBouton.TextScaled = true
hud.signalerBouton.Font = Enum.Font.GothamBold
hud.signalerBouton.Text = "!"
hud.signalerBouton.Visible = false
hud.signalerBouton.Parent = gui
coinUI(hud.signalerBouton, 10)
contourUI(hud.signalerBouton, 2, Color3.fromRGB(10, 12, 20), 0.2)

hud.signalerPanneau = Instance.new("Frame")
hud.signalerPanneau.Size = UDim2.new(0, 220, 0, 22 + #Signalement.MOTIFS * 30)
hud.signalerPanneau.Position = UDim2.new(1, -234, 0, 94)
hud.signalerPanneau.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
hud.signalerPanneau.BackgroundTransparency = 0.1
hud.signalerPanneau.Visible = false
hud.signalerPanneau.ZIndex = 24
hud.signalerPanneau.Parent = gui
coinUI(hud.signalerPanneau, 10)
contourUI(hud.signalerPanneau, 2, Color3.fromRGB(255, 150, 150), 0.3)
local signalerTitre = label(hud.signalerPanneau, "Signaler l'adversaire", UDim2.new(1, -12, 0, 18), UDim2.new(0, 6, 0, 4))
signalerTitre.TextScaled = false
signalerTitre.TextSize = 13
signalerTitre.ZIndex = 25

for i, m in ipairs(Signalement.MOTIFS) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 26)
	b.Position = UDim2.new(0, 6, 0, 22 + (i - 1) * 30)
	b.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = false
	b.TextSize = 13
	b.Font = Enum.Font.Gotham
	b.Text = m.libelle
	b.ZIndex = 25
	b.Parent = hud.signalerPanneau
	coinUI(b, 8)
	b.MouseButton1Click:Connect(function()
		hud.signalerPanneau.Visible = false
		-- le RETOUR vient du serveur, jamais d'une phrase inventee ici : s'il refuse, on le dit.
		local ok, r = pcall(function()
			return BoutiqueFn:InvokeServer("signaler", m.id)
		end)
		if ok and r then
			annoncer(tostring(r.message or r.motif or "Signalement envoye."))
		else
			annoncer("Signalement impossible pour l'instant.")
		end
	end)
end

hud.signalerBouton.MouseButton1Click:Connect(function()
	hud.signalerPanneau.Visible = not hud.signalerPanneau.Visible
end)

-- COUP D'ENVOI : « On attend l'adversaire… » puis 3, 2, 1. Sans lui, le joueur arrive dans une
-- arene figee sans savoir si le jeu a plante.
hud.attenteLabel = label(gui, "", UDim2.new(1, 0, 0, 72), UDim2.new(0, 0, 0.36, 0))
hud.attenteLabel.TextColor3 = Color3.fromRGB(255, 225, 150)
hud.attenteLabel.Visible = false
hud.attenteLabel.ZIndex = 23
local compteVu = nil
local function majAttente(s)
	local a = s.attente
	attenteEnCours = a ~= nil
	hud.attenteLabel.Visible = a ~= nil or s.adversaireAbsent ~= nil
	if not a and not s.adversaireAbsent then
		compteVu = nil
		return
	end
	if not a and s.adversaireAbsent then
		-- COUPURE EN FACE : on le DIT, avec le temps qu'il lui reste. Sans ce mot, l'adversaire
		-- croit a un bug de son propre jeu et quitte a son tour.
		attenteEnCours = false
		hud.attenteLabel.Visible = true
		hud.attenteLabel.Text = s.adversaireAbsent
		return
	end
	if a == "depart" then
		hud.attenteLabel.Text = tostring(s.compteARebours or 1)
		if compteVu ~= s.compteARebours then
			compteVu = s.compteARebours
			Sons.jouer("selection")
		end
	else
		hud.attenteLabel.Text = "On attend l'adversaire... " .. tostring(s.compteARebours or 0) .. " s"
	end
end

-- DERNIERE GARDE : quand les deux tours de princesse d'un camp sont tombees, son Roi tire 1,5 fois
-- plus vite (module Garde). La regle changeait les combats et n'etait NULLE PART a l'ecran :
-- l'attaquant voyait son unite fondre sans comprendre. Bandeau a la bascule, puis mention tant que
-- la garde dure. Le module est range dans `hud` : ce fichier est au plafond des 200 locales.
hud.garde = { mod = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Garde")) }
do
	hud.garde.titre = label(gui, "", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0.235, 0))
	hud.garde.titre.TextScaled = false
	hud.garde.titre.TextSize = 24
	hud.garde.titre.Font = Enum.Font.GothamBlack
	hud.garde.titre.TextStrokeTransparency = 0
	hud.garde.titre.Visible = false
	hud.garde.titre.ZIndex = 21
	hud.garde.mention = label(gui, "", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0.275, 0))
	hud.garde.mention.TextScaled = false
	hud.garde.mention.TextSize = 15
	hud.garde.mention.Visible = false
	hud.garde.mention.ZIndex = 21
end

-- Rend l'etat des deux gardes lisible en une ligne, et annonce la BASCULE (le moment ou elle
-- s'engage), pas l'etat permanent : un bandeau qui reste finit par ne plus se voir.
function hud.majGarde(s)
	local moi, lui = s.gardeMoi == true, s.gardeLui == true
	local cle = tostring(moi) .. "/" .. tostring(lui)
	if cle ~= hud.garde.vue then
		hud.garde.vue = cle
		if moi or lui then
			-- La MIENNE passe devant : c'est elle qui me dit que je defends avec un sursis.
			local pourMoi = moi
			local t = hud.garde.mod.teinte(pourMoi)
			hud.garde.titre.Text = hud.garde.mod.titre(pourMoi)
			hud.garde.titre.TextColor3 = Color3.fromRGB(t[1], t[2], t[3])
			hud.garde.mention.Text = hud.garde.mod.mention(pourMoi)
			hud.garde.mention.TextColor3 = Color3.fromRGB(t[1], t[2], t[3])
			Sons.jouer("tourDetruite")
		end
	end
	-- La mention RESTE tant que la garde dure : c'est une situation, pas un evenement.
	hud.garde.titre.Visible = (moi or lui) and not s.result
	hud.garde.mention.Visible = hud.garde.titre.Visible
end

-- ANNONCE DE COURONNE : le moment le plus important d'une partie ne produisait qu'un son et une
-- secousse. Ici on le NOMME, differemment selon qu'on la prend ou qu'on la perd.
hud.couronneLabel = Instance.new("TextLabel")
hud.couronneLabel.BackgroundTransparency = 1
hud.couronneLabel.Size = UDim2.new(1, 0, 0, 58)
hud.couronneLabel.Position = UDim2.new(0, 0, 0.3, 0)
hud.couronneLabel.Font = Enum.Font.GothamBlack
hud.couronneLabel.TextSize = 46
hud.couronneLabel.TextStrokeTransparency = 0
hud.couronneLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hud.couronneLabel.Visible = false
hud.couronneLabel.ZIndex = 22
hud.couronneLabel.Parent = gui

-- QUETE DU JOUR TERMINEE : elle se finissait en silence (une ligne de progression dans un ecran
-- qu'il faut penser a ouvrir). Comme la recompense se RECLAME au menu, l'annonce dit aussi QUOI
-- FAIRE, sinon les pieces restent sur place. Les trois lignes viennent du serveur (module Quetes).
hud.quete = { lignes = {} }
do
	hud.quete.cadre = Instance.new("Frame")
	hud.quete.cadre.Size = UDim2.new(0, 420, 0, 94)
	hud.quete.cadre.Position = UDim2.new(0.5, -210, 0.19, 0) -- sous la ligne d adversaire : a 0.14 il la recouvrait (capture du 2026-09-20)
	hud.quete.cadre.BackgroundColor3 = Color3.fromRGB(26, 22, 10)
	-- Fond OPAQUE : a 0,15 le message de latence passait au travers et brouillait les lignes
	-- (capture cap-quete2.png du 2026-09-20).
	hud.quete.cadre.BackgroundTransparency = 0
	hud.quete.cadre.Visible = false
	hud.quete.cadre.ZIndex = 22
	hud.quete.cadre.Parent = gui
	coinUI(hud.quete.cadre, 10)
	contourUI(hud.quete.cadre, 2, Color3.fromRGB(255, 215, 90), 0.15)
	for i = 1, 3 do
		local t = label(hud.quete.cadre, "", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 6 + (i - 1) * 28))
		t.TextScaled = false
		t.TextSize = i == 1 and 22 or 17
		t.ZIndex = 23
		t.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(235, 238, 248)
		hud.quete.lignes[i] = t
	end
end

-- Pose dans `hud` et non en variable locale : ce fichier touche deja le plafond de 200 locales.
function hud.majQuete(q)
	hud.quete.cadre.Visible = q ~= nil
	for i = 1, 3 do
		hud.quete.lignes[i].Text = (q and q.lignes and q.lignes[i]) or ""
	end
	-- Un seul son, a l'apparition : rejoue a chaque image, il bourdonnerait.
	if q and hud.quete.vue ~= q.pose then
		hud.quete.vue = q.pose
		Sons.jouer("coffre")
	elseif not q then
		hud.quete.vue = nil
	end
end

-- VOL DE LA COURONNE JUSQU'AU SCORE : la couronne 3D montait sous l'affichage du score et y restait
-- a moitie cachee (captures du 2026-09-21). On la reprend A L'ECRAN : elle part de la tour tombee
-- (projection de la couronne 3D posee par le serveur), vole en arc jusqu'au compteur, qui
-- s'allume en or a l'arrivee. Pose dans `hud` : le fichier touche le plafond de 200 locales.
function hud.volerCouronne(ev)
	-- PHOTO DE TEST : en plein vol (1,2 s sur 2,5), la couronne est entre la tour et le score.
	-- Signal LOCAL : le script de capture tourne sur ce meme client.
	-- UNE seule photo, sur la PREMIERE couronne : le script de recuperation garde la derniere image,
	-- et d autres couronnes tombent plus tard dans la partie (mesure du 2026-09-21 : 3 photos)
	if ReplicatedStorage:FindFirstChild("BRR_PHOTO_JEU") and not hud.photoCouronnePrise then
		hud.photoCouronnePrise = true
		task.delay(1.2, function()
			ReplicatedStorage:SetAttribute("BRR_PHOTO", os.clock())
		end)
	end
	task.spawn(function()
		local depart = Vector2.new(gui.AbsoluteSize.X / 2, gui.AbsoluteSize.Y * 0.45)
		local arene = workspace:FindFirstChild("Arena")
		for _ = 1, 10 do -- la couronne 3D arrive par replication, un peu apres le score
			-- la couronne 3D du camp qui l a GAGNEE (attribut Camp pose par le serveur)
			local campVoulu = ev.camp == "moi" and monCamp or (3 - monCamp)
			local c3d = nil
			for _, m in ipairs(arene and arene:GetChildren() or {}) do
				if m.Name == "CouronneGagnee" and m:GetAttribute("Camp") == campVoulu then
					c3d = m
				end
			end
			if c3d then
				local ecran, visible = camera:WorldToViewportPoint(c3d:GetPivot().Position)
				if visible then
					depart = Vector2.new(ecran.X, ecran.Y) - gui.AbsolutePosition
				end
				for _, p in ipairs(c3d:GetDescendants()) do
					if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end -- une seule couronne a l'ecran
				end
				break
			end
			task.wait(0.03)
		end
		local cible = crownsLabel.AbsolutePosition + crownsLabel.AbsoluteSize / 2 - gui.AbsolutePosition
		cible = cible + Vector2.new(ev.camp == "moi" and -crownsLabel.AbsoluteSize.X * 0.2 or crownsLabel.AbsoluteSize.X * 0.2, 0)
		local c = Instance.new("TextLabel")
		c.Name = "CouronneVol"
		c.BackgroundTransparency = 1
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Size = UDim2.new(0, 110, 0, 110)
		c.Text = utf8.char(0x1F451) -- couronne
		c.TextScaled = true
		c.ZIndex = 30
		c.Parent = gui
		local echelle = Instance.new("UIScale")
		echelle.Parent = c
		local debut = os.clock()
		local distance = (cible - depart).Magnitude
		while true do
			local t = (os.clock() - debut) / Couronnes.VOL_DUREE
			local v = Couronnes.vol(t)
			local pos = depart:Lerp(cible, v.avance) - Vector2.new(0, v.arc * distance)
			c.Position = UDim2.fromOffset(pos.X, pos.Y)
			echelle.Scale = v.echelle
			if t >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		c:Destroy()
		-- ARRIVEE : le compteur s'allume en or puis revient a sa couleur
		local couleur = crownsLabel.TextColor3
		crownsLabel.TextColor3 = Color3.fromRGB(255, 215, 70)
		TweenService:Create(crownsLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextColor3 = couleur }):Play()
		Sons.jouer("coffre")
	end)
end

local function annoncerCouronne(ev)
	hud.couronneLabel.Text = ev.texte
	hud.couronneLabel.TextColor3 = Color3.fromRGB(ev.couleur[1], ev.couleur[2], ev.couleur[3])
	hud.couronneLabel.Visible = true
	hud.couronneLabel.TextTransparency = 0
	TweenService:Create(hud.couronneLabel, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }):Play()
	task.delay(1.9, function()
		if hud.couronneLabel.TextTransparency >= 1 then
			hud.couronneLabel.Visible = false
		end
	end)
	Sons.jouer("tourDetruite")
	secouer(Couronnes.secousse(ev.total))
	hud.volerCouronne(ev)
end

local phasePrec = nil
local function annoncerPhase(phase)
	if phase == phasePrec then
		return
	end
	phasePrec = phase
	if phase == "double" then
		banniere.Text = "DOUBLE ELIXIR !"
		banniere.TextColor3 = Color3.fromRGB(225, 120, 255)
	elseif phase == "prolongation" then
		-- Instant d'entree : le rappel permanent attend la fin de cette annonce.
		hud.instantProlongation = os.clock()
		banniere.Text = "PROLONGATION !"
		banniere.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		banniere.Visible = false
		return
	end
	banniere.Visible = true
	-- Une ANNONCE se lit en grand ; le rappel permanent, lui, repasse en petit.
	banniere.TextSize = 42
	banniere.TextTransparency = 0
	Sons.jouer("coffre", 0.9)
	secouer(0.25)
	TweenService:Create(banniere, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }):Play()
	task.delay(2.6, function()
		if phasePrec == phase then
			banniere.Visible = false
		end
	end)
end

-- ELIXIR PLEIN = ELIXIR PERDU : la jauge pulse quand elle est au maximum, pour que le gaspillage
-- se VOIE. C'est la faute n^o 1 des debutants, et rien ne la signalait.
local pulseElixir = nil
local function pulserElixir(plein)
	if plein and not pulseElixir then
		pulseElixir = TweenService:Create(elixirBack,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundColor3 = Color3.fromRGB(235, 150, 255) })
		pulseElixir:Play()
	elseif not plein and pulseElixir then
		pulseElixir:Cancel()
		pulseElixir = nil
		elixirBack.BackgroundColor3 = Color3.fromRGB(50, 20, 60)
	end
end

local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.Visible = false
overlay.Parent = gui
local resultLabel = label(overlay, "", UDim2.new(0, 500, 0, 100), UDim2.new(0.5, -250, 0.4, -50))
-- CE QUE LA PARTIE A RAPPORTE, sous le resultat : pieces, trophees, serie. Les recompenses
-- etaient versees en silence, l'ecran de fin ne montrait qu'un mot.
hud.gainLabel = label(overlay, "", UDim2.new(0, 560, 0, 34), UDim2.new(0.5, -280, 0.4, 56))
hud.gainLabel.TextColor3 = Color3.fromRGB(255, 225, 140)
-- MONTEE D'ARENE, en haut de l'ecran de fin. Defaut mesure le 2026-09-20 : franchir un palier
-- versait jusqu'a 1800 pieces et ouvrait des cartes en boutique SANS un mot ; le joueur ne le
-- decouvrait qu'en retournant de lui-meme en boutique. Les lignes viennent d'Arenes.lignesMontee :
-- l'ecran ne decide rien, il affiche.
hud.montee = { lignes = {} }
do
	hud.montee.cadre = Instance.new("Frame")
	hud.montee.cadre.Size = UDim2.new(0, 560, 0, 138)
	-- 0,06 -> 0,075 et pas de 32 -> 27 : avec la ligne de LIGUE (4 lignes), la 1re passait sous les
	-- boutons REGLES / SON (capture du 2026-09-21) ; le bas du cadre reste plus haut qu'avant.
	hud.montee.cadre.Position = UDim2.new(0.5, -280, 0.075, 0)
	hud.montee.cadre.BackgroundColor3 = Color3.fromRGB(26, 22, 10)
	hud.montee.cadre.BackgroundTransparency = 0.15
	hud.montee.cadre.Visible = false
	hud.montee.cadre.Parent = overlay
	coinUI(hud.montee.cadre, 12)
	contourUI(hud.montee.cadre, 2, Color3.fromRGB(255, 205, 60), 0.15)
	for i = 1, 4 do
		local t = label(hud.montee.cadre, "", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 6 + (i - 1) * 27))
		t.TextScaled = false
		t.TextSize = i == 1 and 22 or 17
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(235, 238, 248)
		hud.montee.lignes[i] = t
	end
end

-- Ecrit dans le cadre les lignes recues du serveur (nil ou vide : le cadre disparait). Pose dans
-- `hud` et non en variable locale : ce fichier touche deja le plafond de 200 locales de Lua.
function hud.majMontee(lignes)
	local n = 0
	for i = 1, 4 do
		local texte = lignes and lignes[i] or ""
		hud.montee.lignes[i].Text = texte
		if texte ~= "" then
			n = n + 1
		end
	end
	hud.montee.cadre.Visible = n > 0
	hud.montee.cadre.Size = UDim2.new(0, 560, 0, 12 + n * 27)
end
-- RECAPITULATIF DE FIN DE MATCH : deux colonnes (toi / lui) et UNE phrase pour progresser.
-- L'ecran de fin ne disait qu'un mot : on ne savait ni pourquoi on avait perdu, ni ce qu'on
-- avait bien fait.
hud.bilanCadre = Instance.new("Frame")
hud.bilanCadre.Size = UDim2.new(0, 460, 0, 130)
hud.bilanCadre.Position = UDim2.new(0.5, -230, 0.4, 96)
hud.bilanCadre.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
hud.bilanCadre.BackgroundTransparency = 0.25
hud.bilanCadre.Visible = false
hud.bilanCadre.Parent = overlay
coinUI(hud.bilanCadre, 12)
contourUI(hud.bilanCadre, 2, Color3.fromRGB(255, 205, 60), 0.35)

hud.bilanTitres = label(hud.bilanCadre, "", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 6))
hud.bilanTitres.TextScaled = false
hud.bilanTitres.TextSize = 13
hud.bilanTitres.TextColor3 = Color3.fromRGB(255, 205, 60)
hud.bilanLignes = label(hud.bilanCadre, "", UDim2.new(1, -16, 0, 74), UDim2.new(0, 8, 0, 26))
hud.bilanLignes.TextScaled = false
hud.bilanLignes.TextSize = 13
hud.bilanLignes.TextYAlignment = Enum.TextYAlignment.Top
hud.bilanLignes.TextColor3 = Color3.fromRGB(221, 227, 238)
hud.bilanConseil = label(hud.bilanCadre, "", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 1, -26))
hud.bilanConseil.TextScaled = false
hud.bilanConseil.TextSize = 13
hud.bilanConseil.TextColor3 = Color3.fromRGB(150, 235, 170)

-- PARTAGE DE LA FIN DE PARTIE : la partie qu'on vient de jouer disparaissait avec l'ecran de fin.
-- Un jeu Roblox ne peut PAS ecrire dans le presse-papier : on affiche donc le resume dans un
-- champ de texte SELECTIONNABLE (non modifiable), que le joueur copie lui-meme.
hud.partageCadre = Instance.new("Frame")
hud.partageCadre.Name = "PartageCadre"
hud.partageCadre.Size = UDim2.new(0, 460, 0, 92) -- place reelle donnee par Mise.fin
hud.partageCadre.Position = UDim2.new(0.5, -230, 0.4, 236)
hud.partageCadre.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
hud.partageCadre.BackgroundTransparency = 0.25
hud.partageCadre.Visible = false
hud.partageCadre.Parent = overlay
coinUI(hud.partageCadre, 12)
contourUI(hud.partageCadre, 2, Color3.fromRGB(255, 205, 60), 0.5)

hud.partageTexte = Instance.new("TextBox")
hud.partageTexte.Name = "PartageTexte"
hud.partageTexte.Size = UDim2.new(1, -16, 1, -26)
hud.partageTexte.Position = UDim2.new(0, 8, 0, 5)
hud.partageTexte.BackgroundTransparency = 1
hud.partageTexte.TextEditable = false -- on partage un resume, on ne le retouche pas
hud.partageTexte.ClearTextOnFocus = false -- sinon le clic pour selectionner efface le texte
hud.partageTexte.MultiLine = true
hud.partageTexte.TextWrapped = true
hud.partageTexte.TextXAlignment = Enum.TextXAlignment.Left
hud.partageTexte.TextYAlignment = Enum.TextYAlignment.Top
hud.partageTexte.Font = Enum.Font.Code
hud.partageTexte.TextSize = 12
hud.partageTexte.TextColor3 = Color3.fromRGB(221, 227, 238)
hud.partageTexte.Text = ""
hud.partageTexte.Parent = hud.partageCadre

hud.partageAide = label(hud.partageCadre, "", UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 1, -19))
hud.partageAide.TextScaled = false
hud.partageAide.TextSize = 12
hud.partageAide.TextColor3 = Color3.fromRGB(255, 205, 60)

local function majPartage(s)
	local texte = s.partage
	-- le recapitulatif peut etre sacrifie sur un petit ecran SANS emporter le resume : c'est la
	-- seule chose qu'on emporte hors du jeu.
	hud.partageCadre.Visible = s.result ~= nil and texte ~= nil and not s.spectateur
		and hud.misePermet["finpartage"] ~= false
	if not hud.partageCadre.Visible then
		return
	end
	if hud.partageTexte.Text ~= texte then
		hud.partageTexte.Text = texte
	end
	hud.partageAide.Text = s.partageBouton or ""
end


local function majBilan(s)
	-- SPECTATEUR : les memes chiffres, mais nommes par CAMP (il n'a pas de « toi »). Il regardait
	-- la partie sans jamais savoir pourquoi elle s'etait jouee ainsi.
	local moi, lui = s.bilanMoi, s.bilanLui
	local titreGauche, titreDroite = "Toi", s.nomAdversaire or "Adversaire"
	if s.spectateur then
		moi, lui = s.bilanCamp1, s.bilanCamp2
		titreGauche = s.nomCamp1 or Spectateur.nomCamp(1)
		titreDroite = s.nomCamp2 or Spectateur.nomCamp(2)
	end
	hud.bilanCadre.Visible = s.result ~= nil and moi ~= nil and lui ~= nil
		and hud.misePermet["finrecap"] ~= false
	if not hud.bilanCadre.Visible then
		return
	end
	hud.bilanTitres.Text = string.format("%-22s %s   %s", "", titreGauche, titreDroite)
	local lignes = {
		string.format("Cartes jouees            %5d   %5d", moi.cartes, lui.cartes),
		string.format("Elixir depense           %5d   %5d", moi.depense, lui.depense),
		string.format("Elixir GASPILLE          %5d   %5d", moi.gaspille, lui.gaspille),
		string.format("Degats sur ses tours     %5d   %5d", moi.degatsTours, lui.degatsTours),
		string.format("Cout moyen               %s   %s",
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilan")).texteCout(moi),
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilan")).texteCout(lui)),
	}
	hud.bilanLignes.Text = table.concat(lignes, "\n")
	-- Le conseil est personnel (il s'adresse au joueur) : au spectateur, on montre plutot le
	-- resultat de son pari — la seule chose qui le concerne dans cette fin de partie.
	hud.bilanConseil.Text = s.spectateur and (s.pronosticResultat or "") or (s.conseil or "")
end

local restart = Instance.new("TextButton")
restart.Size = UDim2.new(0, 220, 0, 60)
-- SOUS TOUT CE QUI EST AFFICHE. Le bouton etait pose a un offset FIXE calcule a la main sous le
-- recapitulatif ; a chaque bloc ajoute en dessous, il repassait par-dessus (capture du 2026-09-20 :
-- « Rejouer » barrait le resume partageable et son code). On le REPLACE donc en fonction de ce qui
-- est reellement visible, au lieu de corriger le nombre magique une fois de plus.
local BAS_RECAP = 236 -- bas du recapitulatif, dans le repere 0.4 de l'ecran de fin
restart.Position = UDim2.new(0.5, -110, 0.4, BAS_RECAP)

-- Le bouton « Rejouer » n'est plus place a la main : Mise.fin lui donne sa place, sous tout ce qui
-- est affiche. On se contente de redemander le calcul quand le contenu de l'ecran de fin change.
local function placerRejouer()
	if hud.replacerFin then
		hud.replacerFin()
	end
end
restart.Text = "Rejouer"
restart.TextScaled = true
restart.Font = Enum.Font.GothamBold
restart.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
restart.Parent = overlay
-- REFUSER LA REVANCHE. Sans ce bouton, dire non passait forcement par le depart : l'autre restait
-- devant « En attente de l'adversaire... » sans savoir s'il reflechissait ou s'il etait parti.
hud.boutonRefus = Instance.new("TextButton")
hud.boutonRefus.Name = "RefusRevanche"
hud.boutonRefus.Size = UDim2.new(0, 150, 0, 34)
hud.boutonRefus.AnchorPoint = Vector2.new(0.5, 0)
hud.boutonRefus.Position = UDim2.new(0.5, 0, 1, 8) -- sous « Rejouer », qui est place par la mise en page
hud.boutonRefus.Text = "Non merci"
hud.boutonRefus.TextScaled = true
hud.boutonRefus.Font = Enum.Font.GothamMedium
hud.boutonRefus.BackgroundColor3 = Color3.fromRGB(58, 62, 76)
hud.boutonRefus.TextColor3 = Color3.fromRGB(226, 230, 240)
hud.boutonRefus.Visible = false
hud.boutonRefus.Parent = restart
hud.boutonRefus.MouseButton1Click:Connect(function()
	RestartEvent:FireServer("non")
	hud.boutonRefus.Visible = false
end)

restart.MouseButton1Click:Connect(function()
	RestartEvent:FireServer()
	restart.Text = "En attente..."
	restart.AutoButtonColor = false
end)

-- MORT D'UNITE, SANS NOUVEL EVENEMENT RESEAU. Le serveur detruit la part de l'unite tuee ; cette
-- suppression est repliquee. Les parts d'unites portent le nom de leur carte (spawnUnit :
-- Name = card.id), ce qui les distingue du decor et des parts temporaires des effets.
task.spawn(function()
	local arene = workspace:WaitForChild("Arena", 30)
	local function suivre(dossier)
		dossier.ChildRemoved:Connect(function(enfant)
			if Cards.byId[enfant.Name] then
				-- LE SON DIT A QUI ETAIT L'UNITE : la part retiree porte encore son attribut de camp.
				-- Sans cela, perdre son tank sonnait exactement comme abattre celui d'en face.
				local camp = enfant:GetAttribute("Camp")
				local vu = jeSuisSpectateur and 0 or monCamp
				Sons.jouer("mort", 0.7 * Camps.volumeSon(camp, vu), Camps.vitesseSon(camp, vu))
				-- la camera ne tremble que pour SES pertes : tout secouer noyait le signal
				if Camps.estAmi(camp, vu) ~= false then
					secouer(SECOUSSE.mort)
				end
			end
		end)
	end
	if arene then
		suivre(arene)
	end
	-- L'arene est reconstruite a chaque partie (buildArena) : se rebrancher sur la nouvelle.
	workspace.ChildAdded:Connect(function(enfant)
		if enfant.Name == "Arena" then
			suivre(enfant)
		end
	end)
end)

-- MEMOIRE D'ETAT POUR LE SON. Le serveur n'envoie pas d'evenement « tour tombee » ni « fin » :
-- il envoie l'ETAT. On compare donc a l'etat precedent, et on ne joue qu'au CHANGEMENT -- sinon
-- chaque rafraichissement (plusieurs par seconde) rejouerait le meme son.
local sonCouronnesMoi, sonCouronnesEnnemi, sonResultat = nil, nil, nil
local combatPrecMoi, combatPrecLui = nil, nil
local sonCombatPermis = Sons.limiteur(6)

StateEvent.OnClientEvent:Connect(function(s)
	-- dernier signe de vie du serveur : au-dela de Reseau.SILENCE, on parle de coupure, pas de lenteur
	dernierEtatRecu = os.clock()
	premierEtatRecu = true
	chatVoulu = s.chatVisible == true
	appliquerChat()
	-- mise en scene du tutoriel : APRES le pilotage du chat, que test_chat.py fige en tete.
	appliquerTuto(s.tuto)
	emotesBarre.Visible = not s.spectateur
	if s.result then
		pronoFinVue = true
	elseif pronoFinVue then
		pronoFinVue, pronoChoisi = false, nil -- nouvelle partie : nouveau pronostic
	end
	-- PARIS FERMES : la barre disparait des que la partie est engagee. Le serveur refuse de toute
	-- facon le pari (c'est lui qui decide), mais laisser le bouton donnerait un clic sans effet.
	pronoBarre.Visible = s.spectateur == true and not s.result and pronoChoisi == nil
		and s.parisOuverts ~= false
	if s.parisFermes and not hud.parisFermesVu then
		hud.parisFermesVu = true
		annoncer(s.parisFermes) -- une seule fois : l'etat arrive plusieurs fois par seconde
	elseif s.parisOuverts then
		hud.parisFermesVu = nil -- nouvelle partie : l'annonce pourra se refaire
	end
	local moi = s.spectateur and (s.crownsCamp1 or 0) or (s.crownsYou or 0)
	local lui = s.spectateur and (s.crownsCamp2 or 0) or (s.crownsEnemy or 0)
	-- Un compteur qui REDESCEND = nouvelle partie : on se resynchronise sans rien annoncer.
	if Couronnes.remiseAZero(sonCouronnesMoi, sonCouronnesEnnemi, moi, lui) then
		sonCouronnesMoi, sonCouronnesEnnemi = nil, nil
	end
	for _, ev in ipairs(Couronnes.evenements(sonCouronnesMoi, sonCouronnesEnnemi, moi, lui)) do
		annoncerCouronne(ev)
	end
	sonCouronnesMoi, sonCouronnesEnnemi = moi, lui
	-- SONS DE COMBAT : un son par type d'attaque en hausse depuis l'etat precedent, au plus 6 par
	-- seconde en tout. Les compteurs ne redescendent jamais (une baisse = serveur redemarre).
	-- SONS DE COMBAT, CAMP PAR CAMP : ce que JE declenche sonne grave et plein, ce qui vient d'en
	-- face sonne clair et plus discret. Meme banque de sons, deux lectures.
	local vuSon = jeSuisSpectateur and 0 or monCamp
	-- PIEGE Lua : 0 est VRAI. `vuSon and (3 - vuSon)` donnerait donc 3 pour un spectateur (vuSon = 0),
	-- c'est-a-dire un camp qui n'existe pas. On l'ecrit en clair.
	local campEnFace = (vuSon == 0) and 0 or (3 - vuSon)
	for _, bord in ipairs({ { s.combatMoi, vuSon }, { s.combatLui, campEnFace } }) do
		local c, campSon = bord[1], bord[2]
		if c then
			local prec = (campSon == vuSon) and combatPrecMoi or combatPrecLui
			if prec then
				local maintenant = os.clock()
				local vol = Camps.volumeSon(campSon, vuSon)
				local vit = Camps.vitesseSon(campSon, vuSon)
				if (c.zones or 0) > (prec.zones or 0) then
					-- la secousse ne suit QUE ses propres explosions subies ou lancees pres de soi
					secouer(SECOUSSE.zone)
					if sonCombatPermis(maintenant) then Sons.jouer("explosion", vol, vit) end
				end
				if (c.coups or 0) > (prec.coups or 0) and sonCombatPermis(maintenant) then
					Sons.jouer("coupMelee", vol, vit)
				end
				if (c.tirs or 0) > (prec.tirs or 0) and sonCombatPermis(maintenant) then
					Sons.jouer("tir", vol, vit)
				end
			end
			local copie = { tirs = c.tirs, coups = c.coups, zones = c.zones }
			if campSon == vuSon then
				combatPrecMoi = copie
			else
				combatPrecLui = copie
			end
		end
	end
	if not s.result then
		Sons.tension(s.timeLeft)
	end
	if s.result ~= sonResultat then
		sonResultat = s.result
		if s.result then
			-- « VICTOIRE ! » est le mot pose par le serveur (GameServer:534) ; tout le reste
			-- (« DEFAITE... », « EGALITE ») prend le son de defaite.
			if string.find(string.lower(s.result), "victoire") then
				Sons.jouer("victoire")
			else
				Sons.jouer("defaite")
			end
		end
	end
	currentElixir = s.elixir
	if s.monCamp then
		monCamp = s.monCamp
	end
	lastHand = s.hand
	-- La jauge GLISSE au lieu de sauter : le serveur n'envoie l'etat que quelques fois par seconde,
	-- une affectation directe faisait avancer l'elixir par a-coups visibles.
	TweenService:Create(elixirFill, TweenInfo.new(0.28, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(s.elixir / 10, 0, 1, 0) }):Play()
	elixirText.Text = tostring(math.floor(s.elixir))
	-- Les traits suivent la MAIN COURANTE : ils changent des qu'une carte est jouee.
	local coutsMain = {}
	for i = 1, 4 do
		local ci = Cards.byId[mainCourante[i]]
		if ci then
			table.insert(coutsMain, ci.cost)
		end
	end
	local marques = Cout.reperes(coutsMain, 10)
	for n = 1, 4 do
		local m = buttons.reperes[n]
		local rep = marques[n]
		m.Visible = rep ~= nil
		if rep then
			m.Position = UDim2.new(rep.part, -1, 0, 4)
			-- Franchi : trait clair sur la partie remplie. Pas encore : trait sombre sur le vide.
			local atteint = s.elixir >= rep.cout
			m.BackgroundColor3 = atteint and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 70, 140)
			m.BackgroundTransparency = atteint and 0.25 or 0
		end
	end
	-- couleur de la jauge selon la phase : rose normal, violet vif en double, or en prolongation
	if s.phase == "prolongation" then
		elixirFill.BackgroundColor3 = Color3.fromRGB(255, 195, 70)
	elseif s.phase == "double" then
		elixirFill.BackgroundColor3 = Color3.fromRGB(235, 90, 255)
	else
		elixirFill.BackgroundColor3 = Color3.fromRGB(210, 60, 230)
	end
	if not s.spectateur then
		local plein = s.elixir >= 9.95
		pulserElixir(plein)
		-- on ne parle QUE pendant le debordement : rappeler un gaspillage passe ne corrige rien.
		local texte = Bilan.alerteGaspillage(s.gaspilleEnCours, plein)
		hud.gaspilleLabel.Visible = texte ~= nil and not s.result
		hud.gaspilleLabel.Text = texte or ""
		hud.gaspilleLabel.TextColor3 = (Bilan.niveauGaspillage(s.gaspilleEnCours) == "grave")
			and Color3.fromRGB(255, 120, 110) or Color3.fromRGB(255, 205, 90)
	else
		hud.gaspilleLabel.Visible = false
	end
	if not s.result then
		annoncerPhase(s.phase or "normale")
	end
	-- COMPTE A REBOURS DU DOUBLE ELIXIR : dix secondes pour decider de garder son elixir ou non.
	-- Il passe APRES annoncerPhase, qui cache la banniere en phase normale.
	-- Le preavis de FIN passe devant celui du double elixir : il est plus proche, et les deux ne
	-- se croisent de toute facon jamais (le double arrive au dernier tiers, la fin a zero).
	local preavis = s.preavisFin or s.preavisDouble
	if s.result then
		-- PARTIE FINIE : le bandeau de partie s'efface. Les trois branches suivantes exigeaient
		-- toutes « pas de resultat », mais AUCUNE ne masquait la banniere a la fin : un match
		-- termine en prolongation gardait « MORT SUBITE » en travers de l'ecran de fin
		-- (capture du 2026-09-20).
		banniere.Visible = false
	elseif preavis then
		banniere.Text = preavis
		banniere.TextSize = 42
		banniere.TextColor3 = s.preavisFin and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(225, 120, 255)
		banniere.TextTransparency = 0
		banniere.Visible = true
	elseif s.phase == "prolongation"
		and (os.clock() - (hud.instantProlongation or 0)) > 3 then
		-- RAPPEL PERMANENT : la prolongation ne se joue pas comme le reste de la partie, et
		-- l'annonce d'entree ne dure que deux secondes et demie. Tant que la regle s'applique,
		-- elle reste sous les yeux — plus petite que l'annonce, pour ne pas manger l'ecran.
		banniere.Text = Regles.rappelProlongation(true)
		banniere.TextColor3 = Color3.fromRGB(255, 200, 80)
		banniere.TextSize = 26
		banniere.TextTransparency = 0
		banniere.Visible = true
	elseif preavis == nil and phasePrec == "normale" then
		banniere.TextSize = 42
		banniere.Visible = false
	end
	local t = math.max(0, math.ceil(s.timeLeft))
	top.Text = string.format("%d:%02d", math.floor(t / 60), t % 60)
	-- MODE EGALISE : il remplace le nom d'arene, qui ne veut plus rien dire quand les niveaux sont
	-- gommes — et il rappelle que la partie ne touche pas au classement.
	-- FICHE DE L'ADVERSAIRE, et l'ecart de niveau dit FRANCHEMENT (une seule fois) : sans lui, le
	-- joueur met une defaite due a l'inventaire sur son propre dos.
	hud.ficheAdversaire.Text = (not s.spectateur and s.ficheAdversaire) or ""
	-- L'ENJEU EN TROPHEES, juste sous la fiche de l'adversaire : il se lit avec elle (ses
	-- trophees expliquent l'enjeu). Disparait a la fin, ou le gain reel le remplace.
	hud.enjeuLabel.Text = (not s.spectateur and s.enjeu) or ""
	hud.ficheAdversaire.Visible = hud.misePermet.fiche ~= false
	if s.ecartNiveau and not ecartNiveauVu and not s.spectateur then
		ecartNiveauVu = true
		annoncer(s.ecartNiveau)
	elseif s.ecartNiveau == nil then
		ecartNiveauVu = false
	end
	-- SALUT D'OUVERTURE : le bouton « Salut » pulse pendant la fenetre d'invitation, et une phrase
	-- l'accompagne. Le duel commencait sans un mot.
	local saluer = boutonsEmote[Emotes.SALUT]
	if saluer then
		local invite = s.inviteSalut ~= nil and not s.spectateur
		saluer.BackgroundColor3 = invite and Color3.fromRGB(90, 150, 95) or Color3.fromRGB(25, 25, 35)
		if invite and not inviteSalutVue then
			inviteSalutVue = true
			annoncer(s.inviteSalut)
		elseif s.inviteSalut == nil then
			inviteSalutVue = false
		end
	end
	-- QUI EST EN FACE : badge permanent, et UNE annonce au coup d'envoi (jamais repetee).
	if s.annonceAdversaire and not annonceAdversaireVue and not s.result then
		annonceAdversaireVue = true
		annoncer(s.annonceAdversaire)
	elseif s.annonceAdversaire == nil then
		annonceAdversaireVue = false -- adversaire humain : on rearme pour la partie suivante
	end
	-- le nom du decor accompagne celui de l'arene : deux duels ne se ressemblent plus.
	local lieu = s.arene or ""
	if s.decor and lieu ~= "" then
		lieu = lieu .. "  ·  " .. s.decor
	elseif s.decor then
		lieu = s.decor
	end
	areneLabel.Text = s.egalise or lieu
	areneLabel.TextColor3 = s.egalise and Color3.fromRGB(180, 210, 255) or Color3.fromRGB(210, 195, 150)
	-- rang mondial + fin de saison : masques pour un spectateur, qui n'a pas de rang dans ce duel.
	hud.saisonLabel.Text = (not s.spectateur and s.rang)
		and (s.rang .. "   ·   " .. (s.saisonReste or "")) or ""
	-- DERNIERES SECONDES : le chrono vire au rouge sous 30 s (et en prolongation). Il etait blanc
	-- du debut a la fin : rien ne disait qu'il fallait se depecher.
	if s.phase == "prolongation" then
		top.TextColor3 = Color3.fromRGB(255, 195, 70)
	elseif t <= 30 then
		top.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		top.TextColor3 = Color3.new(1, 1, 1)
	end
	if s.spectateur then
		crownsLabel.Text = "Bleu " .. Couronnes.jauge(s.crownsCamp1 or 0) .. "  -  "
			.. Couronnes.jauge(s.crownsCamp2 or 0) .. " Rouge"
	else
		nomAdverseVu = s.nomAdversaire
		-- jauge « ●●○ » plutot qu'un chiffre nu : on lit l'avancement sans compter.
		crownsLabel.Text = "Toi " .. Couronnes.jauge(s.crownsYou) .. "  -  "
			.. Couronnes.jauge(s.crownsEnemy) .. " " .. (s.nomAdversaire or "Robot")
	end
	for i = 1, 4 do
		local card = Cards.byId[s.hand[i]]
		mainCourante[i] = s.hand[i]
		local b = buttons[i]
		if card then
			-- ETIQUETTE D'EFFET : un seul mot, celui qui decide (GEL, POISON, BOUCLIER, SOIGNEUR...).
			-- La main ne disait que le nom et le cout : rien n'apprenait au joueur ce que sa carte FAIT,
			-- alors que les effets viennent d'etre rendus visibles dans l'arene.
			local tag = Fiche.etiquette(card, extrasDe(card.id))
			-- TUTORIEL : une seule carte est jouable par etape. Le serveur refuse les autres.
			local horsEtape = s.tuto ~= nil and s.tuto.carte ~= nil and s.tuto.carte ~= card.id
			-- CE QUI MANQUE, EN TOUTES LETTRES. La carte trop chere affichait son cout nu sur un
			-- fond pali : le joueur devait faire la soustraction lui-meme, en pleine partie. Elle
			-- annonce maintenant « IL MANQUE 2 », et la carte interdite par le tutoriel le DIT au
			-- lieu de se distinguer par une simple nuance de gris.
			local etat = Cout.etat(card.cost, s.elixir, horsEtape)
			-- L'etiquette d'effet s'efface quand la carte n'est pas jouable : le texte est mis a
			-- l'echelle du bouton, et trois lignes le rendaient minuscule (capture du 2026-09-20).
			-- Ce qui compte a cet instant, c'est ce qui manque — l'effet se relit apres.
			local etiquette = (etat == Cout.JOUABLE and tag ~= "") and (tag .. " ") or ""
			-- NOM RACCOURCI EN MAIN (deux mots) : un nom de trois mots prenait trois lignes et
			-- poussait le cout hors de la carte (capture cap-etiquettes.png du 2026-09-21).
			b.button.Text = Fiche.nomMain(card.name) .. "\n" .. etiquette
				.. Cout.libelle(card.cost, s.elixir, horsEtape)
			b.button.BackgroundColor3 = card.color
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine")).rendre(b.vue, card.id)
			b.button.BackgroundTransparency = Cout.opacite(etat)
			local rgbT = Cout.teinte(etat)
			b.button.TextColor3 = Color3.fromRGB(rgbT[1], rgbT[2], rgbT[3])
			-- La jauge ne sert que tant qu'il manque quelque chose : pleine, elle n'apprend rien.
			b.fondJauge.Visible = etat == Cout.MANQUE
			b.marge.PaddingBottom = UDim.new(0, b.fondJauge.Visible and 18 or 0)
			b.jauge.Size = UDim2.new(Cout.part(card.cost, s.elixir), 0, 1, 0)
		end
		-- CADRE DE RARETE : la couleur du contour dit la rarete de la carte (gris commune, bleu
		-- rare, violet epique, or legendaire). Selectionnee, le cadre s'epaissit sans changer de
		-- couleur : on garde l'information de rarete pendant la visee.
		if not card then
			b.fondJauge.Visible = false
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine")).rendre(b.vue, nil)
		end
		local rar = card and Cards.RARETES[card.rarete]
		b.stroke.Color = rar and rar.couleur or Color3.fromRGB(255, 230, 80)
		b.stroke.Thickness = (selected == i) and 5 or (card and 2 or 0)
	end
	-- CARTES A VENIR : les DEUX prochaines, et non la seule suivante. Compter son cycle pour
	-- savoir quand la carte cle revient est le coeur du genre ; avec une seule carte annoncee,
	-- le joueur ne pouvait pas le faire. La liste vient du serveur (Cycle.suivantes).
	local aVenir = s.suivantes or { s.nextCard }
	for n = 1, 2 do
		local a = buttons.apercus[n]
		local c = Cards.byId[aVenir[n]]
		a.vignette.Visible = c ~= nil
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine")).rendre(a.vue, c and c.id)
		if c then
			-- Meme lecture que la main : couleur de la carte, nom, cout ; contour de rarete.
			a.vignette.Text = c.name .. "\n" .. c.cost .. " elixir"
			a.vignette.BackgroundColor3 = c.color
			-- Une carte a venir n'est pas jouable TOUT DE SUITE : elle reste legerement en
			-- retrait, sinon elle se confondrait avec la main et on essaierait de la poser.
			a.vignette.BackgroundTransparency = 0.25
			local rr = Cards.RARETES[c.rarete]
			a.stroke.Color = rr and rr.couleur or Color3.fromRGB(255, 230, 80)
			a.stroke.Thickness = 2
		end
	end
	-- Le texte vient du module : l'ecran ne recalcule pas le cycle, il l'affiche.
	buttons.retour.Text = Cycle.texteRetour(
		s.derniereJouee and Cards.byId[s.derniereJouee] and Cards.byId[s.derniereJouee].name or nil,
		s.retourDerniere)
	-- Le bouton n'apparait que s'il y a un HUMAIN a signaler (pendant le duel ou juste apres) :
	-- le proposer face au robot ferait croire a un recours qui n'a aucun sens.
	hud.signalerBouton.Visible = s.signalable == true and not s.spectateur
	if not hud.signalerBouton.Visible then
		hud.signalerPanneau.Visible = false
	end
	majAttente(s)
	hud.majGarde(s)
	hud.majQuete(s.queteFinie)
	majLecture(s)
	majSpectateur(s)
	majBilan(s)
	majPartage(s)
	majProfils(s)
	placerRejouer()
	overlay.Visible = s.result ~= nil
	-- Garde dans `hud` pour les gestes et les refus traites AILLEURS dans ce fichier (le refus du
	-- serveur est ecoute bien avant la declaration de `overlay`).
	hud.partieFinie = s.result ~= nil
	if hud.majCapacite then
		hud.majCapacite(s.champion)
	end
	if s.result then
		local g = s.gain
		if g then
			local bouts = { string.format("%+d trophees", g.trophees or 0), string.format("+%d pieces", g.pieces or 0) }
			-- PASS DE SAISON : ce que la partie lui a rapporte (module charge a l'usage : ce fichier
			-- est au plafond des 200 variables locales)
			local passTexte = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PassSaison"))
				.texteFin(g.passPoints, g.passPalier)
			if passTexte then
				table.insert(bouts, passTexte)
			end
			if (g.serie or 0) > 1 then
				table.insert(bouts, "serie x" .. g.serie)
			end
			if g.coffre then
				table.insert(bouts, "coffre " .. tostring(g.coffre))
			elseif g.coffrePerdu then
				-- Emplacements pleins : la victoire n'a pas rapporte de coffre. Il etait perdu en
				-- silence ; on le dit, avec la raison (module Coffres, charge a l'usage).
				table.insert(bouts, require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Coffres")).textePerdu())
			end
			if s.mentionAdversaire then
				-- une victoire contre le robot ne vaut pas une victoire contre un humain : on le dit.
				table.insert(bouts, s.mentionAdversaire)
			end
			hud.gainLabel.Text = table.concat(bouts, "   ")
			hud.majMontee(g.monteeLignes)
		else
			hud.majMontee(nil)
			-- SPECTATEUR : pas de gain de partie, mais le resultat de son PARI — il ne l'apprenait
			-- jamais, et le pronostic ne servait donc a rien.
			hud.gainLabel.Text = s.pronosticResultat or ""
		end
		-- REVANCHE A DEUX : « Rejouer » attend l'autre joueur au lieu de lui couper son ecran de fin.
		if s.serveurDeMatch then
			restart.Visible = false
			hud.gainLabel.Text = hud.gainLabel.Text .. "   Retour au hub..."
		else
			-- Le libelle vient de la REGLE (Duel.texteBouton) : les quatre situations possibles y
			-- sont traitees au meme endroit, et verifiees au banc. Ecrit a la main ici, le cas
			-- « l'autre est parti pendant que j'attendais » avait ete oublie — le bouton repassait
			-- a « Rejouer » sans un mot et relancait contre le robot.
			restart.Text = Duel.texteBouton(s.adversaireHumain, s.revancheMoi, s.revancheLui,
				s.revancheRefusee or s.revanchePerdue, s.revancheReste)
			-- BOUTON « NON MERCI » : il n'existait pas. La seule facon de refuser une revanche
			-- etait de PARTIR, ce qui laissait l'autre devant une attente sans fin.
			hud.boutonRefus.Visible = s.adversaireHumain == true and s.revancheMoi ~= true
				and not s.revancheRefusee
			-- Le bouton reste actionnable SAUF quand on attend vraiment quelqu'un.
			restart.AutoButtonColor = not (s.adversaireHumain and s.revancheMoi and not s.revanchePerdue)
			-- Une seule annonce : l'etat arrive plusieurs fois par seconde, et le message se
			-- reecrirait en boucle par-dessus tout le reste.
			-- RELANCE BLOQUEE : son adversaire est coupe et peut revenir. Le serveur refuse le
			-- clic ; sans ce mot, le bouton semblerait simplement casse.
			if s.relanceBloquee then
				restart.Text = Duel.texteRelanceBloquee()
				restart.AutoButtonColor = false
				hud.boutonRefus.Visible = false
			elseif (s.revanchePerdue or s.revancheRefusee) and not hud.revanchePerdueVue then
				hud.revanchePerdueVue = true
				annoncer(s.revancheRefusee and Duel.texteRefus() or Duel.texteRevanchePerdue())
			end
		end
	else
		hud.gainLabel.Text = ""
		hud.revanchePerdueVue = nil -- nouvelle partie : l'annonce pourra se refaire si besoin
		hud.majMontee(nil)
		restart.Text = "Rejouer"
		restart.AutoButtonColor = true
	end
	-- Un spectateur voit le resultat mais pas le bouton : il n'a rien a relancer. Le refus reel est
	-- pose cote serveur ; ceci evite seulement de lui montrer un bouton sans effet.
	jeSuisSpectateur = s.spectateur == true
	restart.Visible = not jeSuisSpectateur and s.serveurDeMatch ~= true
	-- Rien a jouer : ni main de cartes, ni jauge d'elixir. Les cacher evite d'afficher une main
	-- vide et une jauge a zero, qui donneraient l'impression d'un jeu casse.
	-- ECRAN DE FIN : la main disparait AUSSI. Ces cartes ne se posent plus, et la place qu'elle
	-- occupait est exactement celle qui manquait au recapitulatif et au resume partageable
	-- (capture du 2026-09-20 : « Rejouer » descendait sur le panneau de cartes).
	bottom.Visible = not jeSuisSpectateur and s.result == nil
	-- MEME RAISON pour les blocs qui servent a CONDUIRE le duel : lecture de l'adversaire, latence,
	-- historique de ses propres cartes. La partie est finie, ils ne decident plus rien — et sur une
	-- fenetre etroite ils se superposaient au resultat et au resume (capture du 2026-09-20).
	-- La barre d'emotes, elle, RESTE : c'est le moment ou l'on se dit « gg ».
	local enJeu = s.result == nil
	hud.lectureCadre.Visible = enJeu and hud.misePermet["lecture"] ~= false
	hud.pingLabel.Visible = enJeu and hud.misePermet["ping"] ~= false
	hud.mesCartesTexte.Visible = enJeu and hud.misePermet["mesCartes"] ~= false
	resultLabel.Text = s.result or ""
	if s.result then
		selected = nil
	end
end)

-- ETAGEMENT DES ETIQUETTES, COTE CLIENT : positions EXACTES a l'ecran (WorldToViewportPoint).
-- Le serveur estimait l'ecran par des coefficients de camera ; ses etiquettes restaient posees sur
-- celles des tours (captures 3D du 2026-09-14). Les tours ne bougent pas ; chaque autre etiquette
-- monte juste assez pour degager celles deja placees (6 px de marge : 2 px laissaient les barres effleurer le titre des tours). SizeOffset : une unite deplace d'une DEMI-hauteur
-- (mesure sur captures 3D, facteur 2 applique), negatif = vers le haut. Local au client : rien n'est replique.
local hauteurOrigine = setmetatable({}, { __mode = "k" })
local ZONE_TOUR = 12 -- 8 laissait le titre d un groupe sur « Tour » (centre a plus de 8 studs, meme endroit a l ecran)
local function etagerEtiquettes()
	local arene = workspace:FindFirstChild("Arena")
	if not arene then
		return
	end
	-- ZONE DES TOURS : a moins de ZONE_TOUR studs (au sol) d'une tour, une unite ne garde que sa
	-- barre de vie. Son nom se posait sur celui de la tour (captures 3D du 2026-09-14).
	local tours = {}
	for _, part in ipairs(arene:GetChildren()) do
		if part.Name == "KingTower" or part.Name == "PrincessTower" then
			table.insert(tours, part.Position)
		end
	end
	local function dansZoneTour(position)
		for _, t in ipairs(tours) do
			if Vector2.new(position.X - t.X, position.Z - t.Z).Magnitude < ZONE_TOUR then
				return true
			end
		end
		return false
	end
	local items = {}
	local enZone = {}
	local groupesEnZone = {}
	for _, membre in ipairs(arene:GetChildren()) do
		local idGroupe = membre:IsA("BasePart") and membre:FindFirstChildWhichIsA("BillboardGui") == nil
			and membre:GetAttribute("Groupe")
		if idGroupe and dansZoneTour(membre.Position) then
			groupesEnZone[idGroupe] = true
		end
	end
	for _, gui in ipairs(arene:GetDescendants()) do
		if gui:IsA("BillboardGui") and gui.Parent and gui.Parent:IsA("BasePart") then
			local part = gui.Parent
			if part.Name ~= "KingTower" and part.Name ~= "PrincessTower" then
				local zone = dansZoneTour(part.Position)
				-- Groupe : dans la zone des qu'un membre encore present y est.
				local idGroupe = part:GetAttribute("Groupe")
				if not zone and idGroupe and groupesEnZone[idGroupe] then
					zone = true
				end
				local nom = gui:FindFirstChildWhichIsA("TextLabel")
				if nom and nom.Visible == zone then
					nom.Visible = not zone
				end
				-- Dans la zone, la barre passe SOUS le modele : au-dessus, elle traversait la barre de la
				-- tour ou du Roi (captures 3D du 2026-09-14). Decalage d'origine memorise pour revenir.
				if hauteurOrigine[gui] == nil then
					hauteurOrigine[gui] = gui.StudsOffset.Y
				end
				local y = zone and -hauteurOrigine[gui] or hauteurOrigine[gui]
				if math.abs(gui.StudsOffset.Y - y) > 0.01 then
					gui.StudsOffset = Vector3.new(0, y, 0)
				end
				enZone[gui] = zone
			end
		end
	end
	for _, gui in ipairs(arene:GetDescendants()) do
		if gui:IsA("BillboardGui") and gui.Parent and gui.Parent:IsA("BasePart") then
			local part = gui.Parent
			local ecran, visible = camera:WorldToViewportPoint(part.Position + gui.StudsOffset)
			if visible then
				table.insert(items, {
					gui = gui, x = ecran.X, y = ecran.Y,
					w = gui.Size.X.Offset, h = gui.Size.Y.Offset,
					fixe = part.Name == "KingTower" or part.Name == "PrincessTower",
					-- Barre sous le modele (zone d'une tour) : ne peut que DESCENDRE, et seulement pour
					-- degager une tour. Hors etagement, ses barres restaient posees sur « Tour » quand
					-- le groupe etait juste devant la tour (capture 3D du 2026-09-14).
					bas = enZone[gui] == true,
				})
			end
		end
	end
	table.sort(items, function(a, b)
		if a.fixe ~= b.fixe then
			return a.fixe
		end
		if a.y ~= b.y then
			return a.y > b.y
		end
		return a.x < b.x
	end)
	local places = {}
	for _, it in ipairs(items) do
		local monte = 0
		if it.bas then
			for _ = 1, 10 do
				local bouge = false
				for _, p in ipairs(places) do
					local ex = (p.w + it.w) / 2 + 6
					local ey = (p.h + it.h) / 2 + 6
					if p.fixe and math.abs(p.x - it.x) < ex and math.abs((it.y - monte) - (p.y - p.monte)) < ey then
						monte = it.y - (p.y - p.monte) - ey -- negatif : vers le BAS
						bouge = true
					end
				end
				if not bouge then
					break
				end
			end
		elseif not it.fixe then
			for _ = 1, 10 do
				local bouge = false
				for _, p in ipairs(places) do
					local ex = (p.w + it.w) / 2 + 6
					local ey = (p.h + it.h) / 2 + 6
					if not p.bas and math.abs(p.x - it.x) < ex and math.abs((it.y - monte) - (p.y - p.monte)) < ey then
						monte = it.y - (p.y - p.monte) + ey
						bouge = true
					end
				end
				if not bouge then
					break
				end
			end
		end
		it.monte = monte
		table.insert(places, it)
		local y = -math.clamp(2 * monte / math.max(it.h, 1), -8, 8) -- facteur 2 : a -1, les captures montraient un decalage d environ une DEMI-hauteur
		if math.abs(it.gui.SizeOffset.Y - y) > 0.02 then
			it.gui.SizeOffset = Vector2.new(0, y)
		end
	end
end

local attenteEtage = 0
RunService.Heartbeat:Connect(function(dt)
	attenteEtage = attenteEtage + dt
	if attenteEtage >= 0.1 then
		attenteEtage = 0
		etagerEtiquettes()
	end
end)

-- LISIBILITE DES DEUX CAMPS ---------------------------------------------------------------------
-- Le serveur peint en couleurs ABSOLUES (camp 1 bleu, camp 2 rouge) : le joueur du camp 2 voyait
-- donc SES unites en rouge. Ici, chaque client repeint SELON LUI — les miennes bleues, celles d'en
-- face rouges — et change la FORME de la marque (boule / cube), lisible meme sans les couleurs.
local function c3(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function poserNomAdverse(arene)
	local cote = Camps.coteAdverse(jeSuisSpectateur and 0 or monCamp)
	if not cote or not nomAdverseVu then
		return
	end
	for _, part in ipairs(arene:GetChildren()) do
		if part.Name == "KingTower" and part.Position.Z * cote > 0 then
			local etiquette = part:FindFirstChild("NomAdversaire")
			if not etiquette then
				etiquette = Instance.new("BillboardGui")
				etiquette.Name = "NomAdversaire"
				etiquette.Size = UDim2.new(0, 160, 0, 26)
				etiquette.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 7, 0)
				etiquette.AlwaysOnTop = true
				etiquette.Parent = part
				local l = Instance.new("TextLabel")
				l.Name = "Nom"
				l.BackgroundTransparency = 1
				l.Size = UDim2.new(1, 0, 1, 0)
				l.TextScaled = true
				l.Font = Enum.Font.GothamBold
				l.TextStrokeTransparency = 0
				l.TextColor3 = c3(Camps.ENNEMI)
				l.Parent = etiquette
			end
			local l = etiquette:FindFirstChild("Nom")
			if l then
				l.Text = Camps.nomAdverse(nomAdverseVu)
			end
		end
	end
end

-- BARRE DE VIE LISIBLE SANS LES COULEURS : celle d'en face est COUPEE en segments. Les traits
-- sont crees une seule fois puis reutilises ; une barre alliee n'en porte aucun.
local function segmenterBarre(fond, combien)
	local traits = {}
	for _, o in ipairs(fond:GetChildren()) do
		if o.Name == "TraitCamp" then
			table.insert(traits, o)
		end
	end
	for i = 1, combien do
		local t = traits[i]
		if not t then
			t = Instance.new("Frame")
			t.Name = "TraitCamp"
			t.BorderSizePixel = 0
			t.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			t.Size = UDim2.new(0, 2, 1, 0)
			t.ZIndex = 5
			t.Parent = fond
		end
		t.Position = UDim2.new(i / (combien + 1), -1, 0, 0)
		t.Visible = true
	end
	for i = combien + 1, #traits do
		traits[i].Visible = false
	end
end

-- MARQUE DE CAMP SUR LES TOURS : les unites en portaient une, pas les tours. Meme langage —
-- boule a moi, cube en face — pose par le CLIENT, donc relatif a celui qui regarde.
local function marquerTour(part, camp, vu, couleur)
	local marque = part:FindFirstChild("MarqueTour")
	if not marque then
		marque = Instance.new("Part")
		marque.Name = "MarqueTour"
		marque.Anchored = true
		marque.CanCollide = false
		marque.CanQuery = false
		marque.CastShadow = false
		-- MATERIAU AUTO-ECLAIRE, et c'est essentiel : en passant la marque en plastique ordinaire,
		-- elle subissait l'eclairage — les marques proches, dos au soleil, sortaient NOIRES et les
		-- lointaines blanches (capture du 2026-09-21). La clarte vue n'avait plus rien a voir avec
		-- la clarte calculee, donc le contraste prouve au banc ne valait plus rien a l'ecran.
		marque.Material = Enum.Material.Neon
		marque.Parent = part
	end
	-- TAILLE SELON LA DISTANCE. Elle etait FIXE (1,8 stud) : au-dessus de MES tours, a une dizaine
	-- de studs, elle se lisait ; au-dessus de celles d'en face, a plus de 60 studs, boule et cube
	-- devenaient le meme point. Une taille fixe en studs rétrecit a l'ecran comme 1/distance, donc
	-- on la fait grandir AVEC la distance pour garder la meme taille a l'ecran.
	local hautMarque = part.Size.Y / 2 + 6.5
	local ancre = part.Position + Vector3.new(0, hautMarque, 0)
	local taille = Camps.tailleMarque((camera.CFrame.Position - ancre).Magnitude)
	marque.Size = Vector3.new(taille, taille, taille)
	marque.CFrame = part.CFrame * CFrame.new(0, hautMarque, 0)
	-- La couleur de la marque n'est PAS celle du corps : la mienne est CLAIRE, celle d'en face est
	-- SOMBRE. De loin, la clarte survit la ou la teinte se perd (contraste mesure au banc : 7,6
	-- entre les deux marques, contre 1,08 quand toutes deux etaient claires).
	marque.Color = c3(Camps.couleurMarque(camp, vu))
	marque.Shape = (Camps.formeTour(camp, vu) == Camps.FORME_AMI)
		and Enum.PartType.Ball or Enum.PartType.Block
	-- LISERE : sans bord, une marque posee sur le ciel ou sur l'herbe perd sa silhouette — et
	-- c'est la silhouette qui porte la forme. Il prend le contrepied de la marque : sombre sous une
	-- marque claire, clair sous une marque sombre.
	--
	-- PREMIER ESSAI, RATE (capture du 2026-09-21) : une SelectionBox. Elle dessine toujours une
	-- BOITE, meme autour d'une boule — donc elle effacait justement la difference de forme — et
	-- son epaisseur, donnee en studs, fusionnait en un bloc plein qui masquait la marque : on ne
	-- voyait plus qu'un carre noir en bas et un carre blanc en haut.
	-- Un Highlight, lui, epouse la forme reelle et garde une epaisseur constante A L'ECRAN.
	local bord = marque:FindFirstChildWhichIsA("Highlight")
	if not bord then
		bord = Instance.new("Highlight")
		bord.Adornee = marque
		bord.FillTransparency = 1 -- que le contour : la couleur de la marque doit rester visible
		bord.DepthMode = Enum.HighlightDepthMode.Occluded
		bord.Parent = marque
	end
	bord.OutlineTransparency = 0
	bord.OutlineColor = c3(Camps.lisere(camp, vu))
end

local function relookerCamps()
	local arene = workspace:FindFirstChild("Arena")
	if not arene then
		return
	end
	local vu = jeSuisSpectateur and 0 or monCamp
	for _, part in ipairs(arene:GetChildren()) do
		local camp = part:GetAttribute("Camp")
		if camp then
			local couleur = c3(Camps.couleur(camp, vu))
			-- SEULES LES TOURS changent de couleur de corps. Une unite porte la couleur de sa CARTE
			-- (spawnUnit : Color = card.color) : la repeindre effacerait ce qui la rend
			-- reconnaissable. Son camp se lit sur son disque, sa marque et son contour.
			if part.Name == "KingTower" or part.Name == "PrincessTower" then
				part.Color = couleur
				-- la tour porte desormais la meme marque de forme que les unites
				marquerTour(part, camp, vu, couleur)
			end
			for _, enfant in ipairs(part:GetChildren()) do
				if enfant.Name == "MarqueCamp" then
					enfant.Color = couleur
					-- la FORME dit le camp sans la couleur : boule a moi, cube en face.
					enfant.Shape = (Camps.forme(camp, vu) == Camps.FORME_AMI)
						and Enum.PartType.Ball or Enum.PartType.Block
				elseif enfant.Name == "DisqueCamp" then
					enfant.Color = couleur
				elseif enfant:IsA("Highlight") then
					enfant.OutlineColor = c3(Camps.contour(camp, vu))
				elseif enfant:IsA("BillboardGui") then
					local fond = enfant:FindFirstChildWhichIsA("Frame")
					local barre = fond and fond:FindFirstChildWhichIsA("Frame")
					if barre then
						barre.BackgroundColor3 = couleur
						-- SANS LES COULEURS : la barre d'en face est coupee en segments.
						segmenterBarre(fond, Camps.segmentsBarre(camp, vu))
					end
				end
			end
		end
	end
	poserNomAdverse(arene)
end

local attenteCamps = 0
RunService.Heartbeat:Connect(function(dt)
	attenteCamps = attenteCamps + dt
	if attenteCamps >= 0.25 then
		attenteCamps = 0
		relookerCamps()
	end
end)

-- MISE EN PAGE CALCULEE ---------------------------------------------------------------------
-- Les positions etaient ecrites en pixels fixes : sur une fenetre etroite, les blocs se
-- recouvraient (lecture de l'adversaire sous les boutons du hub, historique sous les emotes).
-- Elles viennent maintenant du module Mise, verifie sur des dizaines de formats.
local function poser(objet, b)
	if not objet or not b then
		return
	end
	objet.Position = UDim2.new(0, b.x, 0, b.y)
	if objet:IsA("Frame") or objet:IsA("TextLabel") or objet:IsA("TextButton") then
		objet.Size = UDim2.new(0, b.l, 0, b.h)
	end
	if b.visible == false then
		objet.Visible = false
	end
end

-- Ce que la MISE EN PAGE autorise a afficher. Mesure a l'ecran (capture du 2026-09-20) : la
-- boucle d'etat remettait « Tu as pose » a Visible = true juste apres que la mise en page l'ait
-- retire — le bloc sacrifie revenait donc a chaque rafraichissement.
hud.misePermet = {}

local function appliquerMise()
	local vue = camera.ViewportSize
	local l, h = math.floor(vue.X), math.floor(vue.Y)
	-- BRR_ECRAN (copie de test) : force un FORMAT, pour montrer la mise en page compacte. Le
	-- harnais de capture ne peut pas redimensionner la fenetre du bureau cache (le format vient de
	-- la session d'affichage, cf. tools/studio-capture-moteur.ps1) : sans ce crochet, la version
	-- compacte ne serait visible sur aucune image.
	local forceEcran = ReplicatedStorage:FindFirstChild("BRR_ECRAN")
	if forceEcran then
		local fl, fh = string.match(tostring(forceEcran.Value), "^(%d+)x(%d+)$")
		if fl then
			l, h = tonumber(fl), tonumber(fh)
		end
	end
	local bs = Mise.blocs(l, h)
	if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
		local bouts = {}
		for _, b in ipairs(bs) do
			if b.visible then
				table.insert(bouts, string.format("%s@%d,%d+%dx%d", b.nom, b.x, b.y, b.l, b.h))
			else
				table.insert(bouts, b.nom .. "=RETIRE")
			end
		end
		print(string.format("[BRRMISE] ecran=%dx%d | %s", l, h, table.concat(bouts, " ")))
	end
	local par = {}
	for _, b in ipairs(bs) do
		par[b.nom] = b
	end
	for nom, b in pairs(par) do
		hud.misePermet[nom] = b.visible ~= false
	end
	poser(top, par.chrono)
	poser(crownsLabel, par.score)
	poser(hud.areneLabel, par.lieu)
	poser(hud.saisonLabel, par.progression)
	poser(hud.ficheAdversaire, par.fiche)
	poser(hud.lectureCadre, par.lecture)
	poser(hud.pingLabel, par.ping)
	poser(emotesBarre, par.emotes)
	poser(hud.mesCartesTexte, par.mesCartes)
	-- le panneau de cartes garde son ancrage bas-centre : on ne regle que sa largeur utile
	if par.main then
		bottom.Size = UDim2.new(0, par.main.l, 0, par.main.h)
	end

	-- ECRAN DE FIN : meme traitement que le reste. Ses blocs etaient poses a des offsets ecrits a
	-- la main, et « Rejouer » finissait par recouvrir le bloc ajoute en dessous (capture du
	-- 2026-09-20 : il barrait le resume partageable et son code).
	local fins = Mise.fin(l, h)
	if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
		local bouts = {}
		for _, b in ipairs(fins) do
			table.insert(bouts, string.format("%s@%d,%d+%dx%d%s", b.nom, b.x, b.y, b.l, b.h,
				b.visible and "" or "=RETIRE"))
		end
		print(string.format("[BRRFIN] ecran=%dx%d | %s", l, h, table.concat(bouts, " ")))
	end
	for _, b in ipairs(fins) do
		hud.misePermet[b.nom] = b.visible ~= false
	end
	poser(resultLabel, Mise.trouver(fins, "fintitre"))
	poser(hud.gainLabel, Mise.trouver(fins, "fingain"))
	poser(hud.bilanCadre, Mise.trouver(fins, "finrecap"))
	poser(hud.partageCadre, Mise.trouver(fins, "finpartage"))
	poser(restart, Mise.trouver(fins, "finrejouer"))
	-- ces trois-la ne dependent que de la place disponible : on les remet quand elle revient.
	for objet, nom in pairs({ [resultLabel] = "fintitre", [hud.gainLabel] = "fingain",
		[restart] = "finrejouer" }) do
		local b = Mise.trouver(fins, nom)
		objet.Visible = (b == nil) or (b.visible ~= false)
	end
end
hud.replacerFin = appliquerMise
appliquerMise()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(appliquerMise)

-- Pose d'une carte : clic / tap sur sa moitie d'arene
local function deployAtScreen(x, y)
	-- APRES LA FIN : un clic dans l'arene n'envoie plus rien. Il partait au serveur, revenait en
	-- refus « partie terminee » et recouvrait le bouton Rejouer (capture du 2026-09-21). L'ecran de
	-- fin est deja la reponse : on ne pose rien et on ne dit rien.
	if hud.partieFinie then
		return "partie finie"
	end
	-- SPECTATEUR : son clic ne partait nulle part et ne disait rien (le serveur jetait meme sa
	-- demande sans un mot). Il ne pouvait pas savoir s'il avait mal clique ou s'il n'a pas le
	-- droit. On le dit, et on lui rappelle ce qu'il PEUT faire : parier.
	if hud.spectateur then
		Sons.jouer("refus")
		hud.annoncer(Spectateur.texteRefusPose(hud.pariPossible == true))
		return "spectateur"
	end
	if not selected then
		return "aucune carte selectionnee"
	end
	local ray = camera:ScreenPointToRay(x, y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return "arene absente"
	end
	params.FilterDescendantsInstances = { arena }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then
		return "clic hors arene"
	end
	-- ZONE DE POSE. Ce test etait ECRIT EN DUR POUR LE CAMP 1 (`z > -3`) : le joueur du camp 2,
	-- dont la moitie est en z POSITIF, voyait donc TOUS ses clics refuses par son propre client —
	-- il ne pouvait poser aucune carte en duel humain contre humain (mesure 2026-09-20). On passe
	-- par la meme regle que le serveur, qui tient compte du camp ET des tours ennemies tombees.
	-- UN SORT VISE TOUTE L'ARENE : c'est ce qui le distingue d'une unite. On saute donc le test
	-- de moitie, et le serveur revalide de son cote (Sorts.cibleValide).
	local card = Cards.byId[lastHand[selected]]
	if not card then
		return "carte absente"
	end
	if not poseClientPermise(card, hit.Position.X, hit.Position.Z, arena) then
		Sons.jouer("refus")
		annoncer(card.sort and "Hors de l'arene" or "Hors de ta zone de pose")
		return string.format("clic hors zone z=%.1f", hit.Position.Z)
	end
	if currentElixir < card.cost then
		Sons.jouer("refus")
		annoncer("Pas assez d'elixir")
		return "elixir insuffisant"
	end
	if attenteEnCours then
		Sons.jouer("refus")
		annoncer("La partie n'a pas encore commence")
		return "partie pas commencee"
	end
	PlayCard:FireServer(selected, hit.Position)
	Sons.jouer("pose")
	effacerApercu() -- la carte part : plus rien a viser
	-- La pose se SENT : plus la carte est chere, plus l'arrivee cogne (l'unite tombe du ciel).
	secouer(0.12 + card.cost * 0.05)
	selected = nil
	return string.format("pose %s x=%.1f z=%.1f", card.id, hit.Position.X, hit.Position.Z)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	deployAtScreen(input.Position.X, input.Position.Y)
end)

-- CAPTURE DU REFUS FAIT AU SPECTATEUR (build.py --spectateur) : on appelle le MEME chemin qu'un
-- vrai clic au centre de l'arene, en boucle, pour que la photo tombe forcement pendant le message.
if ReplicatedStorage:FindFirstChild("BRR_SPECTATEUR") then
	task.spawn(function()
		task.wait(6)
		while true do
			deployAtScreen(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
			task.wait(1.5)
		end
	end)
end

-- ANNULER LA CARTE ARMEE. Une carte choisie par erreur restait armee : le geste suivant, meme a
-- l'autre bout de l'ecran, la posait — on perdait la carte ET l'elixir.
local function annulerSelection()
	if not selected then
		return false
	end
	selected = nil
	glisseDepart = nil
	effacerApercu()
	Sons.jouer("clic")
	annoncer(Geste.texteAnnulation())
	return true
end

UserInputService.InputChanged:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
		pointeurX, pointeurY = input.Position.X, input.Position.Y
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	local depart = glisseDepart
	glisseDepart = nil
	if not depart or not selected then
		return
	end
	local x, y = input.Position.X, input.Position.Y
	local typeGeste = Geste.type(depart.x, depart.y, x, y)
	-- relache SUR la main de cartes = « je repose la carte », le geste naturel
	local hautPanneau = bottom.Visible and bottom.AbsolutePosition.Y or nil
	local surPanneau = Geste.annuleSurPanneau(y, hautPanneau)
	local surArene = workspace:FindFirstChild("Arena") ~= nil
	local action = Geste.relachement(typeGeste, surPanneau, surArene)
	if action == "poser" then
		deployAtScreen(x, y)
	elseif action == "annuler" then
		annulerSelection()
	end
	-- « garder » : la carte reste armee, la pose se fera au geste suivant (mode deux temps)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	-- ECHAP et CLIC DROIT annulent, meme au-dessus de l'interface (d'ou l'absence de garde
	-- `processed` : une carte armee doit pouvoir etre reposee depuis n'importe ou).
	local nom = (input.UserInputType == Enum.UserInputType.MouseButton2) and "MouseButton2"
		or (input.KeyCode == Enum.KeyCode.Escape and "Escape" or nil)
	if nom and Geste.annuleParTouche(nom) then
		annulerSelection()
	end
end)

-- Auto-test du client (copie de test seulement) : lit l'UI et pose des cartes par le vrai chemin clic
-- CAPTURE DE LA FICHE EN PARTIE (build.py --partie --detail=ScudoBanana) : un ecran qui s'ouvre
-- au clic droit ne se photographie pas tout seul.
local ficheDemandee = ReplicatedStorage:FindFirstChild("BRR_DETAIL")
if ficheDemandee and ficheDemandee.Value ~= "" then
	task.spawn(function()
		task.wait(6)
		ouvrirFiche(Cards.byId[ficheDemandee.Value])
	end)
end

if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
	task.spawn(function()
		task.wait(4)
		local vp = camera.ViewportSize
		print(string.format("[BRR] client ecran=%dx%d", vp.X, vp.Y))
		local function sonde(fx, fy)
			local ray = camera:ScreenPointToRay(vp.X * fx, vp.Y * fy)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { workspace.Arena }
			local h = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
			if h then
				return string.format("(%.0f,%.0f)", h.Position.X, h.Position.Z)
			end
			return "vide"
		end
		for _, fy in ipairs({ 0.01, 0.2, 0.4, 0.6, 0.7 }) do
			print(string.format("[BRR] carte y=%.2f gauche=%s centre=%s droite=%s", fy, sonde(0.1, fy), sonde(0.5, fy), sonde(0.9, fy)))
		end
		local panelTop = bottom.AbsolutePosition.Y / vp.Y
		print(string.format("[BRR] panneau cartes commence a y=%.2f ; sous lui : %s", panelTop, sonde(0.5, panelTop - 0.01)))
		for round = 1, 6 do
			task.wait(4)
			local texts = {}
			for i = 1, 4 do
				table.insert(texts, (buttons[i].button.Text:gsub("\n", " / ")))
			end
			-- Le nom et le camp sont dans la ligne : a deux joueurs, le journal de Studio melange les
			-- sorties des deux clients et « client main=... » seul ne disait pas QUI parlait.
			print("[BRR] client " .. player.Name .. " camp" .. tostring(monCamp) .. " main=" .. table.concat(texts, " | ") .. " elixir=" .. elixirText.Text .. " chrono=" .. top.Text .. " " .. crownsLabel.Text)
			local cheapest, cost = nil, 99
			for i = 1, 4 do
				local c = Cards.byId[lastHand[i]]
				if c and c.cost < cost then
					cheapest, cost = i, c.cost
				end
			end
			selected = cheapest
			-- clic simule : bas-centre de l'ecran, cote joueur
			local x = vp.X * (0.35 + 0.3 * (round % 2))
			print("[BRR] client clic -> " .. deployAtScreen(x, vp.Y * 0.62))
			selected = cheapest
			local refus = deployAtScreen(vp.X * 0.5, vp.Y * 0.12)
			selected = nil
			print("[BRR] client clic ennemi -> " .. refus)
		end
		-- COPIE DE TEST : le joueur 1 appuie tout seul sur « Rejouer » 3 s apres la fin, et les deux
		-- clients redisent leur etat 5 s plus tard. C'est ce qui prouve que la partie repart POUR LES
		-- DEUX, et pas seulement pour celui qui a clique.
		if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") and not dejaRelance then
			dejaRelance = true
			-- Le SPECTATEUR essaie en premier : s'il pouvait relancer, la partie repartirait avant
			-- l'appui du camp 1 et le refus passerait inapercu.
			task.delay(3, function()
				if jeSuisSpectateur then
					print("[BRR] test : un SPECTATEUR appuie sur Rejouer")
					RestartEvent:FireServer()
				end
			end)
			task.delay(6, function()
				if jeSuisSpectateur then
					print("[BRR] test : apres l'appui du spectateur, chrono=" .. top.Text
						.. " overlay=" .. tostring(overlay.Visible) .. " bouton=" .. tostring(restart.Visible))
				elseif monCamp == 1 then
					print("[BRR] test : le camp 1 appuie sur Rejouer")
					RestartEvent:FireServer()
				end
			end)
			task.delay(11, function()
				print("[BRR] client APRES-REJOUER " .. player.Name .. " camp" .. tostring(monCamp)
					.. " chrono=" .. top.Text .. " resultat=" .. (resultLabel.Text ~= "" and resultLabel.Text or "aucun")
					.. " overlay=" .. tostring(overlay.Visible) .. " elixir=" .. elixirText.Text)
			end)
		end
		print("[BRR] client FIN " .. player.Name .. " camp" .. tostring(monCamp)
			.. " resultat=" .. (resultLabel.Text ~= "" and resultLabel.Text or "aucun")
			.. " overlay=" .. tostring(overlay.Visible))
	end)
end


-- SONDE D'INTERFACE (copie de test) : ce que l'ecran de match AFFICHE vraiment. Une capture peut
-- venir d'un autre Studio ; cette ligne-ci vit dans le journal de NOTRE place et ne se confond pas.
if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
	task.delay(17, function()
		local motifs = 0
		for _, o in ipairs(hud.signalerPanneau:GetChildren()) do
			if o:IsA("TextButton") then
				motifs = motifs + 1
			end
		end
		print(string.format("[BRRUI] %s camp=%s | signaler_visible=%s motifs=%d | rang=%q saison=%q arene=%q | elixir_adverse=%q cartes_vues=%q | emotes_visible=%s",
			player.Name, tostring(monCamp), tostring(hud.signalerBouton.Visible), motifs,
			hud.saisonLabel.Text, tostring(hud.attenteLabel.Text), areneLabel.Text,
			hud.elixirAdverseTexte.Text, (hud.cartesVuesTexte.Text:gsub("\n", " / ")),
			tostring(emotesBarre.Visible)))
	end)
end

-- SONDE DE LISIBILITE (copie de test) : ce que CE client peint vraiment sur chaque camp.
-- C'est la seule facon de prouver que le joueur du camp 2 voit SES unites en bleu : le serveur,
-- lui, les peint en rouge — la correction vit entierement ici.
if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
	task.delay(16, function()
		local arene = workspace:FindFirstChild("Arena")
		if not arene then
			return
		end
		local vues = {}
		for _, part in ipairs(arene:GetChildren()) do
			local camp = part:GetAttribute("Camp")
			local marque = camp and part:FindFirstChild("MarqueCamp")
			if marque and not vues[camp] then
				vues[camp] = string.format("camp%d marque=%d,%d,%d forme=%s",
					camp, math.floor(marque.Color.R * 255 + 0.5), math.floor(marque.Color.G * 255 + 0.5),
					math.floor(marque.Color.B * 255 + 0.5), tostring(marque.Shape))
			end
		end
		print(string.format("[BRRCAMP] %s monCamp=%s spectateur=%s | %s | %s | nom_adverse=%s",
			player.Name, tostring(monCamp), tostring(jeSuisSpectateur),
			vues[1] or "camp1 absent", vues[2] or "camp2 absent", tostring(nomAdverseVu)))
	end)
end

-- SONDE DE CADRAGE (copie de test) : distance de camera et debordement reel.
if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
	task.delay(20, function()
		print(string.format("[BRRCAD] %s spectateur=%s distance=%.1f debordement=%.3f vue=%s",
			player.Name, tostring(jeSuisSpectateur), distanceMesuree, debordementMesure,
			tostring(camera.ViewportSize)))
	end)
end
