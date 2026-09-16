-- Brainrot Royale : client (camera, main de cartes, elixir, pose)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cards"))
-- Habillage sonore : joue CHEZ CE CLIENT, sur les evenements deja recus du serveur.
local Sons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sons"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayCard = remotes:WaitForChild("PlayCard")
local StateEvent = remotes:WaitForChild("State")
local RestartEvent = remotes:WaitForChild("Restart")

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
local SECOUSSE_DUREE = 0.45
local SECOUSSE_AMPLITUDE = 1.6
local secousseFin = 0

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
		local a = SECOUSSE_AMPLITUDE * reste * reste -- s'eteint vite, pas de tremblement qui traine
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

local function label(parent, text, size, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Parent = parent
	return l
end

local top = label(gui, "3:00", UDim2.new(0, 300, 0, 40), UDim2.new(0.5, -150, 0, 10))
local crownsLabel = label(gui, "0 - 0", UDim2.new(0, 300, 0, 30), UDim2.new(0.5, -150, 0, 50))

local bottom = Instance.new("Frame")
bottom.Size = UDim2.new(0, 560, 0, 170)
bottom.Position = UDim2.new(0.5, -280, 1, -180)
bottom.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
bottom.BackgroundTransparency = 0.2
bottom.Parent = gui
local corner = Instance.new("UICorner")
corner.Parent = bottom
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
	local c = Instance.new("UICorner")
	c.Parent = b
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

-- Le chat Roblox couvrait le haut gauche de l'arene : inutile dans un duel contre le bot.
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 20 do
		if pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end) then
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
local elixirFill = Instance.new("Frame")
elixirFill.BorderSizePixel = 0
elixirFill.BackgroundColor3 = Color3.fromRGB(210, 60, 230)
elixirFill.Size = UDim2.new(0, 0, 1, 0)
elixirFill.Parent = elixirBack
local elixirText = label(elixirBack, "0", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))

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

StateEvent.OnClientEvent:Connect(function(s)
	local moi = s.spectateur and (s.crownsCamp1 or 0) or (s.crownsYou or 0)
	local lui = s.spectateur and (s.crownsCamp2 or 0) or (s.crownsEnemy or 0)
	if sonCouronnesMoi and (moi > sonCouronnesMoi or lui > sonCouronnesEnnemi) then
		Sons.jouer("tourDetruite")
		secousseFin = os.clock() + SECOUSSE_DUREE
	end
	sonCouronnesMoi, sonCouronnesEnnemi = moi, lui
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
	local t = math.max(0, math.ceil(s.timeLeft))
	top.Text = string.format("%d:%02d", math.floor(t / 60), t % 60)
	if s.spectateur then
		crownsLabel.Text = "Rouge " .. (s.crownsCamp1 or 0) .. "  -  " .. (s.crownsCamp2 or 0) .. " Bleu"
	else
		crownsLabel.Text = "Toi " .. s.crownsYou .. "  -  " .. s.crownsEnemy .. " Bot"
	end
	for i = 1, 4 do
		local card = Cards.byId[s.hand[i]]
		local b = buttons[i]
		if card then
			b.button.Text = card.name .. "\n" .. card.cost .. " elixir"
			b.button.BackgroundColor3 = card.color
			if s.elixir >= card.cost then
				b.button.BackgroundTransparency = 0
			else
				b.button.BackgroundTransparency = 0.6
			end
		end
		b.stroke.Thickness = (selected == i) and 4 or 0
	end
	local nextCard = Cards.byId[s.nextCard]
	nextLabel.Text = "Suivante\n" .. (nextCard and nextCard.name or "?")
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
	if hit.Position.Z > -3 then
		return string.format("clic cote ennemi z=%.1f", hit.Position.Z)
	end
	local card = Cards.byId[lastHand[selected]]
	if not card or currentElixir < card.cost then
		Sons.jouer("refus")
		return "elixir insuffisant"
	end
	PlayCard:FireServer(selected, hit.Position)
	Sons.jouer("pose")
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
