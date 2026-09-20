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
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayCard = remotes:WaitForChild("PlayCard")
local StateEvent = remotes:WaitForChild("State")
local RestartEvent = remotes:WaitForChild("Restart")
local EmoteEvent = remotes:WaitForChild("Emote")
local PronosticEvent = remotes:WaitForChild("Pronostic")

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
local ARENE_DEMI_LARGEUR, ARENE_DEMI_LONGUEUR = 28, 32 -- HALF_W, HALF_L du serveur
local HAUTEUR_TOURS = 9
local BANDE_CARTES = 0.16 -- part BASSE de l'ecran prise par la main de cartes
-- Part HAUTE reservee au chrono et au score. Mesure du 2026-09-14 : a 0.10, c'est ELLE qui
-- limitait le rapprochement (debordement 0.003, distance bloquee a 71) — les sommets des tours du
-- fond venaient toucher cette bande, et l'arene restait petite au milieu de l'ecran. Le chrono est
-- en surimpression : il peut mordre un peu sur le ciel.
local BANDE_HAUT = 0.04
local ANGLE_VUE = 62
local INCLINAISON = math.rad(52)

local distance = 70 -- point de depart, corrige des la premiere image
-- CAMP DU JOUEUR. Le camp 2 doit voir l'arene depuis l'AUTRE bout, sinon son camp est en haut de
-- l'ecran et sa zone de pose hors de vue. Le serveur envoie `monCamp` dans l'etat ; tant qu'aucun
-- etat n'est arrive, on garde le camp 1 (cas du joueur seul).
local monCamp = 1
local dejaRelance = false -- copie de test : un seul appui sur Rejouer
local jeSuisSpectateur = false -- vrai quand les deux camps sont deja pris
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
	camera.FieldOfView = ANGLE_VUE
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
-- ARENE : le nom du palier de trophees, sous le score. En partie, rien ne disait dans quelle
-- arene on jouait — l'information n'existait que dans le hub, et seulement en chiffres.
local areneLabel = label(gui, "", UDim2.new(0, 360, 0, 22), UDim2.new(0.5, -180, 0, 80))
areneLabel.TextColor3 = Color3.fromRGB(210, 195, 150)

-- EMOTES RAPIDES : boutons en haut a droite, caches pour le spectateur (le serveur refuse de toute facon).
local emotesBarre = Instance.new("Frame")
emotesBarre.BackgroundTransparency = 1
emotesBarre.Size = UDim2.new(0, 190, 0, 40)
emotesBarre.Position = UDim2.new(1, -200, 0, 10)
emotesBarre.Visible = false
emotesBarre.Parent = gui
local emotesListe = Instance.new("UIListLayout")
emotesListe.FillDirection = Enum.FillDirection.Horizontal
emotesListe.Padding = UDim.new(0, 6)
emotesListe.Parent = emotesBarre
for _, e in ipairs({ { "gg", "GG" }, { "rire", "HAHA" }, { "bravo", "Bravo" }, { "oups", "Oups" } }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 42, 0, 36)
	b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	b.BackgroundTransparency = 0.2
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Text = e[2]
	b.Parent = emotesBarre
	coinUI(b, 10)
	degradeUI(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170))
	contourUI(b, 2, Color3.fromRGB(10, 12, 20), 0.2)
	b.MouseButton1Click:Connect(function()
		EmoteEvent:FireServer(e[1])
	end)
end

-- PRONOSTIC (spectateur seulement) : parier sur le camp gagnant, une fois par partie.
local pronoChoisi = nil
local pronoFinVue = false
local pronoBarre = Instance.new("Frame")
pronoBarre.BackgroundTransparency = 1
pronoBarre.Size = UDim2.new(0, 260, 0, 44)
pronoBarre.Position = UDim2.new(0.5, -130, 0, 86)
pronoBarre.Visible = false
pronoBarre.Parent = gui
local pronoListe = Instance.new("UIListLayout")
pronoListe.FillDirection = Enum.FillDirection.Horizontal
pronoListe.Padding = UDim.new(0, 8)
pronoListe.Parent = pronoBarre
for camp, def in ipairs({ { "Rouge gagne", Color3.fromRGB(200, 60, 60) }, { "Bleu gagne", Color3.fromRGB(60, 110, 210) } }) do
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
local lastHand = {}
local currentElixir = 0

-- ===== APERCU DE POSE =====
-- Tant qu'une carte est choisie, un disque au sol suit la visee : VERT si la pose passe, ROUGE
-- sinon, et a la taille reelle de ce qu'on pose (le rayon d'effet pour un sort). Un fantome
-- transparent montre la silhouette de l'unite. Tout est LOCAL a ce client : rien n'est replique,
-- l'adversaire ne voit pas ou l'on hesite.
local apercuDossier, apercuDisque, apercuPieces = nil, nil, {}
local apercuCarteId = nil

local function effacerApercu()
	if apercuDossier then
		apercuDossier:Destroy()
	end
	apercuDossier, apercuDisque, apercuPieces, apercuCarteId = nil, nil, {}, nil
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

-- Suit la visee a chaque image. Sans carte choisie, l'apercu disparait.
local function majApercu()
	if ReplicatedStorage:FindFirstChild("BRR_APERCU") and not selected and lastHand[1] then
		selected = 1 -- capture : une carte reste choisie pour que l'apercu soit visible
	end
	if not selected or jeSuisSpectateur then
		if apercuDossier then
			effacerApercu()
		end
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
	-- CAPTURE (copie de test) : sans utilisateur, la souris ne pointe jamais l'arene et l'apercu
	-- ne se montrerait sur aucune image. BRR_APERCU fige la visee a un point fixe de la moitie
	-- du joueur. Ce chemin n'existe que dans la copie de test.
	local fige = ReplicatedStorage:FindFirstChild("BRR_APERCU")
	local ray
	if fige then
		local cible = Vector3.new(-8, 0.5, -14)
		ray = { Origin = cible + Vector3.new(0, 60, 0), Direction = Vector3.new(0, -1, 0) }
	else
		local pos = UserInputService:GetMouseLocation()
		ray = camera:ScreenPointToRay(pos.X, pos.Y)
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
	local permise
	if card.sort then
		permise = math.abs(p.X) <= ARENE_DEMI_LARGEUR - 1 and math.abs(p.Z) <= ARENE_DEMI_LONGUEUR - 1
	else
		local sensEnnemi = (monCamp == 1) and 1 or -1
		local debout = { [-1] = false, [1] = false }
		for _, part in ipairs(arene:GetChildren()) do
			if part.Name == "PrincessTower" and part.Position.Z * sensEnnemi > 0 then
				debout[part.Position.X < 0 and -1 or 1] = true
			end
		end
		permise = Regles.posePermise(monCamp, p.X, p.Z, not debout[-1], not debout[1])
			and math.abs(p.X) <= ARENE_DEMI_LARGEUR - 1 and math.abs(p.Z) <= ARENE_DEMI_LONGUEUR - 1
	end
	local teinte = Apercu.teinte(permise)
	apercuDisque.Color = teinte
	apercuDisque.CFrame = CFrame.new(p.X, 0.62, p.Z) * CFrame.Angles(0, 0, math.rad(90))
	local hauteur = Apercu.hauteurAuSol(card, 0.5)
	for _, f in ipairs(apercuPieces) do
		-- la couleur de la piece ne bouge pas (on reconnait la carte) ; seul le disque dit oui/non
		f.part.CFrame = CFrame.new(p.X, hauteur, p.Z) * CFrame.new(f.ecart)
			* CFrame.Angles(math.rad(f.rot and f.rot.X or 0), math.rad(f.rot and f.rot.Y or 0),
				math.rad(f.rot and f.rot.Z or 0))
	end
end

RunService.RenderStepped:Connect(majApercu)

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
	b.MouseButton1Click:Connect(function()
		if selected == i then
			selected = nil
		else
			selected = i
			Sons.jouer("selection")
		end
	end)
	buttons[i] = { button = b, stroke = stroke }
end

local nextLabel = label(bottom, "Suivante :", UDim2.new(0, 116, 0, 120), UDim2.new(0, 482, 0, 10))
nextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
nextLabel.TextWrapped = true
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
local elixirText = label(elixirBack, "0", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))

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
		banniere.Text = "PROLONGATION !"
		banniere.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		banniere.Visible = false
		return
	end
	banniere.Visible = true
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
local restart = Instance.new("TextButton")
restart.Size = UDim2.new(0, 220, 0, 60)
restart.Position = UDim2.new(0.5, -110, 0.55, 0)
restart.Text = "Rejouer"
restart.TextScaled = true
restart.Font = Enum.Font.GothamBold
restart.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
restart.Parent = overlay
restart.MouseButton1Click:Connect(function()
	RestartEvent:FireServer()
end)

-- MORT D'UNITE, SANS NOUVEL EVENEMENT RESEAU. Le serveur detruit la part de l'unite tuee ; cette
-- suppression est repliquee. Les parts d'unites portent le nom de leur carte (spawnUnit :
-- Name = card.id), ce qui les distingue du decor et des parts temporaires des effets.
task.spawn(function()
	local arene = workspace:WaitForChild("Arena", 30)
	local function suivre(dossier)
		dossier.ChildRemoved:Connect(function(enfant)
			if Cards.byId[enfant.Name] then
				Sons.jouer("mort", 0.7)
				secouer(SECOUSSE.mort)
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
local combatPrec = nil
local sonCombatPermis = Sons.limiteur(6)

StateEvent.OnClientEvent:Connect(function(s)
	chatVoulu = s.chatVisible == true
	appliquerChat()
	emotesBarre.Visible = not s.spectateur
	if s.result then
		pronoFinVue = true
	elseif pronoFinVue then
		pronoFinVue, pronoChoisi = false, nil -- nouvelle partie : nouveau pronostic
	end
	pronoBarre.Visible = s.spectateur == true and not s.result and pronoChoisi == nil
	local moi = s.spectateur and (s.crownsCamp1 or 0) or (s.crownsYou or 0)
	local lui = s.spectateur and (s.crownsCamp2 or 0) or (s.crownsEnemy or 0)
	if sonCouronnesMoi and (moi > sonCouronnesMoi or lui > sonCouronnesEnnemi) then
		Sons.jouer("tourDetruite")
		secouer(SECOUSSE.tour)
	end
	sonCouronnesMoi, sonCouronnesEnnemi = moi, lui
	-- SONS DE COMBAT : un son par type d'attaque en hausse depuis l'etat precedent, au plus 6 par
	-- seconde en tout. Les compteurs ne redescendent jamais (une baisse = serveur redemarre).
	local c = s.combat
	if c then
		if combatPrec then
			local maintenant = os.clock()
			if (c.zones or 0) > (combatPrec.zones or 0) then
				secouer(SECOUSSE.zone)
				if sonCombatPermis(maintenant) then Sons.jouer("explosion") end
			end
			if (c.coups or 0) > (combatPrec.coups or 0) and sonCombatPermis(maintenant) then
				Sons.jouer("coupMelee")
			end
			if (c.tirs or 0) > (combatPrec.tirs or 0) and sonCombatPermis(maintenant) then
				Sons.jouer("tir")
			end
		end
		combatPrec = { tirs = c.tirs, coups = c.coups, zones = c.zones }
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
	-- couleur de la jauge selon la phase : rose normal, violet vif en double, or en prolongation
	if s.phase == "prolongation" then
		elixirFill.BackgroundColor3 = Color3.fromRGB(255, 195, 70)
	elseif s.phase == "double" then
		elixirFill.BackgroundColor3 = Color3.fromRGB(235, 90, 255)
	else
		elixirFill.BackgroundColor3 = Color3.fromRGB(210, 60, 230)
	end
	if not s.spectateur then
		pulserElixir(s.elixir >= 9.95)
	end
	if not s.result then
		annoncerPhase(s.phase or "normale")
	end
	local t = math.max(0, math.ceil(s.timeLeft))
	top.Text = string.format("%d:%02d", math.floor(t / 60), t % 60)
	areneLabel.Text = s.arene or ""
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
		crownsLabel.Text = "Rouge " .. (s.crownsCamp1 or 0) .. "  -  " .. (s.crownsCamp2 or 0) .. " Bleu"
	else
		crownsLabel.Text = "Toi " .. s.crownsYou .. "  -  " .. s.crownsEnemy .. " " .. (s.nomAdversaire or "Bot")
	end
	for i = 1, 4 do
		local card = Cards.byId[s.hand[i]]
		local b = buttons[i]
		if card then
			b.button.Text = card.name .. (card.sort and "\nSORT " or "\n") .. card.cost .. " elixir"
			b.button.BackgroundColor3 = card.color
			if s.elixir >= card.cost then
				b.button.BackgroundTransparency = 0
			else
				b.button.BackgroundTransparency = 0.6
			end
		end
		-- CADRE DE RARETE : la couleur du contour dit la rarete de la carte (gris commune, bleu
		-- rare, violet epique, or legendaire). Selectionnee, le cadre s'epaissit sans changer de
		-- couleur : on garde l'information de rarete pendant la visee.
		local rar = card and Cards.RARETES[card.rarete]
		b.stroke.Color = rar and rar.couleur or Color3.fromRGB(255, 230, 80)
		b.stroke.Thickness = (selected == i) and 5 or (card and 2 or 0)
	end
	-- CARTES A VENIR : les DEUX prochaines, et non la seule suivante. Compter son cycle pour
	-- savoir quand la carte cle revient est le coeur du genre ; avec une seule carte annoncee,
	-- le joueur ne pouvait pas le faire. La liste vient du serveur (Cycle.suivantes).
	local aVenir = {}
	for _, id in ipairs(s.suivantes or { s.nextCard }) do
		local c = Cards.byId[id]
		if c then
			table.insert(aVenir, c.name .. " " .. c.cost)
		end
	end
	nextLabel.Text = "A venir\n" .. (#aVenir > 0 and table.concat(aVenir, "\n") or "?")
	overlay.Visible = s.result ~= nil
	-- Un spectateur voit le resultat mais pas le bouton : il n'a rien a relancer. Le refus reel est
	-- pose cote serveur ; ceci evite seulement de lui montrer un bouton sans effet.
	jeSuisSpectateur = s.spectateur == true
	restart.Visible = not jeSuisSpectateur
	-- Rien a jouer : ni main de cartes, ni jauge d'elixir. Les cacher evite d'afficher une main
	-- vide et une jauge a zero, qui donneraient l'impression d'un jeu casse.
	bottom.Visible = not jeSuisSpectateur
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

-- Pose d'une carte : clic / tap sur sa moitie d'arene
local function deployAtScreen(x, y)
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
	local carteVisee = Cards.byId[lastHand[selected]]
	if carteVisee and carteVisee.sort then
		if math.abs(hit.Position.X) > 27 or math.abs(hit.Position.Z) > 31 then
			Sons.jouer("refus")
			return "sort hors arene"
		end
	else
	local sensEnnemi = (monCamp == 1) and 1 or -1
	local debout = { [-1] = false, [1] = false } -- tour ennemie encore debout, par cote
	for _, part in ipairs(arena:GetChildren()) do
		if part.Name == "PrincessTower" and part.Position.Z * sensEnnemi > 0 then
			debout[part.Position.X < 0 and -1 or 1] = true
		end
	end
	if not Regles.posePermise(monCamp, hit.Position.X, hit.Position.Z, not debout[-1], not debout[1]) then
		Sons.jouer("refus")
		return string.format("clic hors zone z=%.1f", hit.Position.Z)
	end
	end
	local card = Cards.byId[lastHand[selected]]
	if not card or currentElixir < card.cost then
		Sons.jouer("refus")
		return "elixir insuffisant"
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

-- Auto-test du client (copie de test seulement) : lit l'UI et pose des cartes par le vrai chemin clic
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


-- SONDE DE CADRAGE (copie de test) : distance de camera et debordement reel.
if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
	task.delay(20, function()
		print(string.format("[BRRCAD] %s spectateur=%s distance=%.1f debordement=%.3f vue=%s",
			player.Name, tostring(jeSuisSpectateur), distanceMesuree, debordementMesure,
			tostring(camera.ViewportSize)))
	end)
end
