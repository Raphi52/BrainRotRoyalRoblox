-- Brainrot Royale : serveur (arene, elixir, unites, tours, bot)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
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

-- Constantes
-- Largeur de l'arene portee de 18 a 28 (2026-09-14) : a 36 studs de large pour 64 de long, l'arene
-- ne pouvait pas remplir un ecran large — la hauteur etait pleine, les cotes vides. Les ponts et
-- les tours laterales se DEDUISENT de la largeur, pour qu'un prochain reglage n'en oublie aucun.
local HALF_W, HALF_L = 28, 32
local VOIE_X = math.floor(HALF_W * 0.61) -- axe des ponts et des tours de cote (17 pour 28)
local BRIDGES = { -VOIE_X, VOIE_X }
local MAX_ELIXIR = 10
local ELIXIR_PER_SEC = 1 / 2.8
-- Duree d'une partie. La COPIE DE TEST la raccourcit (marqueur BRR_COURT pose par build.py) :
-- sinon, verifier la fin de partie demanderait 3 minutes de capture par essai. 25 s et non 40 :
-- le client de test rend la main vers 32 s, il ne voyait donc jamais la fin (mesure 2026-09-14).
local MATCH_TIME = ReplicatedStorage:FindFirstChild("BRR_COURT") and 25 or 180
local GROUND_Y = 0.5

local arena
local entities = {}
local teams = {}
-- declares ICI (et non pres de attribuerCamp) : endMatch et resetMatch, plus haut, s'en servent
local equipeDe = {}          -- joueur -> 1 ou 2
local occupant = { nil, nil } -- camp -> joueur
local timeLeft = MATCH_TIME
local result = nil
local stateTimer = 0

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
local function poserAmbiance()
	local ciel = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	ciel.Parent = Lighting
	Lighting.ClockTime = 15.5           -- fin d'apres-midi : ombres longues, couleurs chaudes
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
	brume.Density = 0.32
	brume.Offset = 0.1
	brume.Haze = 1.2
	brume.Glare = 0.35
	brume.Color = Color3.fromRGB(210, 220, 235)
	brume.Decay = Color3.fromRGB(160, 175, 200)
	brume.Parent = Lighting

	local eclat = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	eclat.Intensity = 0.45; eclat.Size = 24; eclat.Threshold = 1.6; eclat.Parent = Lighting
	local couleur = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	couleur.Saturation = 0.18; couleur.Contrast = 0.12; couleur.Parent = Lighting
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
	local pierre = Color3.fromRGB(150, 145, 135)
	-- bordures en pierre autour du terrain
	for _, s in ipairs({ -1, 1 }) do
		deco({ Name = "Muret", Size = Vector3.new(1.5, 1.6, HALF_L * 2 + 3), Position = Vector3.new(s * (HALF_W + 0.75), 0.8, 0), Color = pierre, Material = Enum.Material.Cobblestone })
		deco({ Name = "Muret", Size = Vector3.new(HALF_W * 2 + 3, 1.6, 1.5), Position = Vector3.new(0, 0.8, s * (HALF_L + 0.75)), Color = pierre, Material = Enum.Material.Cobblestone })
	end
	-- sol exterieur plus sombre pour detacher l'arene
	deco({ Name = "Exterieur", Size = Vector3.new(HALF_W * 2 + 120, 0.8, HALF_L * 2 + 120), Position = Vector3.new(0, -0.3, 0), Color = Color3.fromRGB(55, 105, 50), Material = Enum.Material.Grass, CastShadow = false })
	-- allees de terre menant aux ponts
	for _, bx in ipairs(BRIDGES) do
		deco({ Name = "Allee", Size = Vector3.new(3.2, 0.06, HALF_L * 2 - 4), Position = Vector3.new(bx, 0.53, 0), Color = Color3.fromRGB(170, 135, 90), Material = Enum.Material.Ground, CastShadow = false })
		for _, s in ipairs({ -1, 1 }) do
			deco({ Name = "Rambarde", Size = Vector3.new(0.4, 1, 6), Position = Vector3.new(bx + s * 2.1, 1.1, 0), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
		end
	end
	-- berges de la riviere
	for _, s in ipairs({ -1, 1 }) do
		deco({ Name = "Berge", Size = Vector3.new(HALF_W * 2, 0.7, 0.6), Position = Vector3.new(0, 0.55, s * 2.2), Color = Color3.fromRGB(120, 110, 95), Material = Enum.Material.Slate })
	end
	-- arbres et rochers autour, placement deterministe (meme decor a chaque partie)
	local rng = Random.new(42)
	for i = 1, 26 do
		local cote = (i % 2 == 0) and 1 or -1
		local x = cote * (HALF_W + 4 + rng:NextNumber(0, 14))
		local z = rng:NextNumber(-HALF_L, HALF_L)
		if i % 3 == 0 then
			deco({ Name = "Rocher", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.2, 3) * rng:NextNumber(0.7, 1.4), Position = Vector3.new(x, 0.6, z), Color = Color3.fromRGB(125, 125, 130), Material = Enum.Material.Rock })
		else
			local h = rng:NextNumber(4, 7)
			deco({ Name = "Tronc", Size = Vector3.new(0.9, h, 0.9), Position = Vector3.new(x, h / 2, z), Color = Color3.fromRGB(100, 70, 40), Material = Enum.Material.Wood })
			deco({ Name = "Feuillage", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5) * rng:NextNumber(0.8, 1.3), Position = Vector3.new(x, h + 1.5, z), Color = Color3.fromRGB(50 + rng:NextInteger(0, 30), 130 + rng:NextInteger(0, 40), 55), Material = Enum.Material.Grass })
		end
	end
end

-- RESTES : les corps en cours d'agonie vivent ICI, hors de l'arene. Le client joue le son de mort
-- et secoue la camera sur la DISPARITION de la part dans l'arene (GameClient, ChildRemoved) : si le
-- corps restait dans l'arene pendant son agonie, le son arriverait 0,45 s APRES l'explosion.
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

	makePart({ Name = "GroundPlayer", Size = Vector3.new(HALF_W * 2, 1, HALF_L), Position = Vector3.new(0, 0, -HALF_L / 2), Color = Color3.fromRGB(90, 170, 80), Material = Enum.Material.Grass })
	makePart({ Name = "GroundEnemy", Size = Vector3.new(HALF_W * 2, 1, HALF_L), Position = Vector3.new(0, 0, HALF_L / 2), Color = Color3.fromRGB(80, 150, 70), Material = Enum.Material.Grass })
	makePart({ Name = "River", Size = Vector3.new(HALF_W * 2, 1.1, 4), Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(60, 140, 220), Material = Enum.Material.Glass, Transparency = 0.2 })
	for _, bx in ipairs(BRIDGES) do
		makePart({ Name = "Bridge", Size = Vector3.new(4, 1.3, 6), Position = Vector3.new(bx, 0.15, 0), Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks })
	end
	-- zone de pose du joueur (visuelle)
	makePart({ Name = "DeployZone", Size = Vector3.new(HALF_W * 2, 0.05, HALF_L - 2), Position = Vector3.new(0, 0.53, -(HALF_L - 2) / 2 - 2), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.92, CanCollide = false })
	decorerArene()
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
	return fill
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

local function spawnTower(team, x, z, isKing)
	local size = isKing and Vector3.new(7, 8, 7) or Vector3.new(5, 7, 5)
	local part = makePart({
		Name = isKing and "KingTower" or "PrincessTower",
		Size = size,
		Position = Vector3.new(x, GROUND_Y + size.Y / 2, z),
		Color = teamColor(team),
		Material = Enum.Material.Brick,
	})
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
		orner({ Size = Vector3.new(1.2, 1.2, 1.2), Position = Vector3.new(x + c[1] * (size.X / 2 - 0.6), haut + 0.6, z + c[2] * (size.Z / 2 - 0.6)), Color = Color3.fromRGB(200, 195, 185), Material = Enum.Material.Limestone })
	end
	orner({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.X * 0.7, size.X * 0.7, size.X * 0.7), CFrame = CFrame.new(x, haut + 1.4, z) * CFrame.Angles(0, 0, math.rad(90)), Color = teamColor(team):Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Slate })
	orner({ Size = Vector3.new(0.2, 3.5, 0.2), Position = Vector3.new(x, haut + 3.5, z), Color = Color3.fromRGB(80, 60, 40), Material = Enum.Material.Wood })
	orner({ Size = Vector3.new(1.8, 1.1, 0.1), Position = Vector3.new(x + 0.9, haut + 4.6, z), Color = isKing and Color3.fromRGB(255, 205, 60) or teamColor(team), Material = Enum.Material.Fabric })
	return addEntity({
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
	-- MODELE DE LA BOUTIQUE (ecrit dans la place par build.py, sans aucun script) : prioritaire
	-- sur l'assemblage de morceaux, qui reste le repli si le modele manque.
	local source = MODELES and MODELES:FindFirstChild(card.id)
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

local function multNiveau(team, id)
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
		if teams[camp] and occupant[camp] == nil then
			local n = Economie.niveauRobot(occupant[3 - camp])
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
			teams[camp].profilRobot = (force and Robot.profilNomme(force.Value))
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
	habiller(part, card, teamColor(team))
	-- MARQUE DE CAMP au-dessus de la tete. En melee, les gros modeles recouvraient les disques au sol
	-- et l'on ne savait plus qui etait bleu ou rouge (capture --melee du 2026-09-14). Piece 3D et non
	-- etiquette flottante : CaptureService ne rend pas les BillboardGui, la marque ne serait pas
	-- verifiable sur capture.
	local haut = part:GetAttribute("HautVisuel") or card.size.Y / 2
	local marque = Instance.new("Part")
	marque.Name = "MarqueCamp"
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
		-- encombrement au sol : sert a la separation (Foule). Une unite ne traverse plus ses voisines.
		rayonFoule = Foule.rayon(card),
		-- CHARGE : nil pour la plupart des cartes. Celles qui en ont une accumulent leur elan dans
		-- `chargeParcouru` pendant la marche, et le perdent des qu'on les arrete.
		chargeProfil = Charge.profil(card.id), chargeParcouru = 0,
		-- PROFONDEUR : 0 pour une unite posee par un joueur, 1 pour une unite nee d'une mort.
		-- C'est la garde qui empeche une descendance en cascade (voir Descendance.autorisee).
		profondeur = 0,
		-- STATUTS : gel, ralentissement, poison vivent ici (module pur Statuts).
		statuts = {}, carte = card,
		-- BATIMENT POSE : il ne marche pas, et meurt tout seul au bout de sa duree de vie.
		estBatimentPose = Batiments.est(card),
	})
	-- BOUCLIER : il encaisse AVANT les points de vie et ne se regenere pas.
	if card.bouclier then
		Statuts.poserBouclier(e, math.floor(card.bouclier * multNiveau(team, card.id)))
	end
	-- USURE d'un batiment pose : ses points de vie sont etales sur sa duree de vie, si bien
	-- qu'il tient EXACTEMENT le temps annonce sur la carte meme si personne ne l'attaque.
	if e.estBatimentPose then
		e.usure = Batiments.usure(card, e.maxHp)
		e.etatBatiment = { poseT = horloge }
		e.speed = 0
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
	e.cibleEnCours = best
	return best, bestD
end

-- COMPTEURS DE COMBAT (envoyes dans l'etat) : le son se joue chez le client, qui ne voit pas les
-- attaques. Il compare ces compteurs a ceux du dernier etat recu et joue un son a chaque hausse.
local combat = { tirs = 0, coups = 0, zones = 0 }
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
-- Pure (testee hors Studio) : le client n'est pas cru, tout est reverifie ici.
local function pronosticAccepte(camp, aUnCamp, dejaPris, finie)
	return (camp == 1 or camp == 2) and not aUnCamp and not dejaPris and not finie
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
		Effets.victoire(arena, Vector3.new(0, 0, winner == 1 and -28 or 28), teamColor(winner))
	end
	-- RECOMPENSES : chaque joueur ayant un camp gagne pieces et trophees selon SON issue.
	-- task.spawn : la verification du pass VIP interroge Roblox et ne doit pas bloquer la boucle.
	for camp, joueur in pairs(occupant) do
		local issue = (vainqueur == 0) and "egalite" or (vainqueur == camp and "victoire" or "defaite")
		task.spawn(Economie.recompenser, joueur, issue, occupant[3 - camp] ~= nil)
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
	-- BOUCLIER : il absorbe le coup AVANT les points de vie (Statuts.encaisser).
	local surPV, reste, casse = Statuts.encaisser(target, amount)
	if casse then
		Effets.impact(arena, target.part.Position, Color3.fromRGB(235, 225, 140))
	end
	amount = surPV
	if amount <= 0 then
		target.coupT = horloge
		Effets.coup(target.part)
		return -- tout est parti dans le bouclier
	end
	target.hp = target.hp - amount
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
			target.fill.Size = UDim2.new(0, 0, 1, 0)
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
			if target.isKing then
				endMatch(3 - target.team)
			elseif prolongation then
				-- MORT SUBITE : en prolongation, la premiere tour prise termine la partie.
				endMatch(3 - target.team)
			end
		end
	elseif target.fill then
		target.fill.Size = UDim2.new(target.hp / target.maxHp, 0, 1, 0)
	end
end

-- TIRS EN VOL. Un tir n'est plus un dessin pose APRES coup : c'est un objet qui met du temps a
-- arriver (module pur Projectiles). Deux consequences visibles : une unite rapide peut sortir de
-- la trajectoire, et les degats tombent quand la boule touche — plus jamais avant.
local tirs = {}

-- STATUTS PORTES PAR UN COUP : ralentissement de la Regina, poison du Serpente. La regle de cumul
-- (on prolonge, on n'empile pas) est dans Statuts.appliquer.
local function appliquerEffets(carte, cible)
	local eff = carte and carte.effet
	if not eff or not cible or not cible.alive then
		return
	end
	if eff.lent then
		Statuts.appliquer(cible, "lent", eff.lent, horloge)
		Effets.impact(arena, cible.part.Position, Color3.fromRGB(150, 220, 255))
	end
	if eff.poison then
		Statuts.appliquer(cible, "poison", eff.poison, horloge)
	end
end

-- IMPACT : ce qui se passe a l'ARRIVEE du coup (que le tir ait vole ou non).
local function impact(e, target, centre, degats)
	if e.splash then
		for _, o in ipairs(entities) do
			if o.alive and o.team ~= e.team then
				local d = o.part.Position - centre
				if Vector3.new(d.X, 0, d.Z).Magnitude <= e.splash then
					damage(o, degats)
					appliquerEffets(e.carte, o)
				end
			end
		end
	elseif target and target.alive then
		damage(target, degats)
		appliquerEffets(e.carte, target)
	end
	Effets.impact(arena, centre, teamColor(e.team))
end

local function attack(e, target)
	e.attaqueT = horloge
	-- ELAN : seul le premier coup d'une charge est majore.
	local degats = e.splash and e.dmg or Charge.degats(e.dmg, e.chargeProfil, e.chargeLancee)
	if e.splash then
		combat.zones = combat.zones + 1
	elseif e.range >= 3 or e.isBuilding then
		combat.tirs = combat.tirs + 1
	else
		combat.coups = combat.coups + 1
	end
	-- Un TIREUR envoie un projectile : ses degats n'arrivent qu'avec lui. Une melee frappe au
	-- contact, immediatement — y faire voler quelque chose ne ferait que retarder le corps a corps.
	if e.range >= 3 or e.isBuilding then
		local depart, arrivee = e.part.Position, target.part.Position
		local duree = Projectiles.duree(e.carte, (arrivee - depart).Magnitude)
		Effets.projectile(arena, depart, arrivee, teamColor(e.team), e.splash ~= nil)
		table.insert(tirs, {
			tireur = e, cible = target, visee = arrivee, depart = depart,
			degats = degats, t0 = horloge, duree = duree,
		})
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
		local bx = BRIDGES[1]
		if math.abs(pos.X - BRIDGES[2]) < math.abs(pos.X - bx) then
			bx = BRIDGES[2]
		end
		bx = bx + math.clamp(lane * 0.25, -1.2, 1.2) -- le pont fait 4 studs de large
		if math.abs(pos.X - bx) > 0.8 then
			goal = Vector3.new(bx, pos.Y, sideOf(pos.Z) * 4)
		else
			goal = Vector3.new(bx, pos.Y, -sideOf(pos.Z) * 4)
		end
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
	end
	local newPos = pos + delta.Unit * step
	e.part.CFrame = CFrame.lookAt(newPos, newPos + delta.Unit)
	e.bouge = true -- `animer` replace les morceaux, avec la pose de marche
end

-- ANIMATION PROCEDURALE : les pieces sont ancrees (pas de physique, pas d'Animator), on calcule
-- donc la pose a chaque image : rebond + dandinement en marche, elan a l'attaque, recul au coup.
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
			end
			if (sort.degats or 0) > 0 then
				damage(cible, Sorts.degats(sort, cible.isBuilding))
			end
			Effets.impact(arena, cible.part.Position, sort.couleur or card.color)
		end
		combat.zones = combat.zones + 1
	elseif sort.effet == "poison" then
		-- FLAQUE : elle ronge dans la DUREE. C'est la reponse aux batiments et aux gros tas, la ou
		-- un sort instantane ne fait qu'entamer.
		for _, i in ipairs(touches) do
			Statuts.appliquer(refs[i], "poison",
				{ duree = sort.duree, degats = sort.parTic, tic = sort.tic }, horloge)
		end
		combat.zones = combat.zones + 1
	elseif sort.effet == "soin" then
		-- SOIN : jamais au-dela des PV maximaux, jamais sur un mort (Statuts.soigner).
		for _, i in ipairs(touches) do
			local cible = refs[i]
			local gagne = Statuts.soigner(cible, math.floor((sort.soin or 0) * multNiveau(team, card.id)))
			if gagne > 0 and cible.fill then
				cible.fill.Size = UDim2.new(cible.hp / cible.maxHp, 0, 1, 0)
			end
			Effets.impact(arena, cible.part.Position, sort.couleur or card.color)
		end
	else
		for _, i in ipairs(touches) do
			local cible = refs[i]
			damage(cible, Sorts.degats(sort, cible.isBuilding))
			-- RECUL : le tronc repousse ce qu'il touche hors de son elan. Une tour ne bouge pas.
			local dx, dz = Sorts.recul(sort, objets[i], pos.X, pos.Z)
			if (dx ~= 0 or dz ~= 0) and cible.alive then
				local q = cible.part.Position
				local nx = math.clamp(q.X + dx, -HALF_W + 1, HALF_W - 1)
				local nz = math.clamp(q.Z + dz, -HALF_L + 1, HALF_L - 1)
				cible.part.CFrame = CFrame.new(nx, q.Y, nz) * (cible.part.CFrame - q)
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
		return false
	end
	local t = teams[team]
	local id = t.hand[handIndex]
	local card = id and Cards.byId[id]
	if not card or t.elixir < card.cost then
		return false
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
		return false
	end
	t.elixir = t.elixir - card.cost
	if card.sort then
		lancerSort(card, team, pos)
	else
		Effets.pose(arena, pos, teamColor(team))
		spawnGroupe(card, team, pos)
	end
	-- CYCLE : la carte jouee repart en FOND de file, la tete de file prend sa place.
	Cycle.jouer(t.hand, t.queue, handIndex)
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
	result = nil
	vainqueur = nil
	prolongation = false
	pronostics = {}
	timeLeft = MATCH_TIME
	buildArena()
	for team = 1, 2 do
		local s = team == 1 and -1 or 1
		-- Le robot ne sort plus les cartes PAYANTES qu'un joueur neuf n'a pas : son paquet est
		-- celui du joueur d'en face, sinon les seules cartes offertes (Economie.cartesRobot).
		local permises = occupant[team] and Economie.deck(occupant[team])
			or Economie.cartesRobot(occupant[3 - team] and Economie.cartesPossedees(occupant[3 - team]))
		local hand, queue = newDeck(permises)
		local niveaux = occupant[team] and Economie.niveaux(occupant[team]) or nil
		-- BRR_PARTIE (capture d'une partie normale) : 10 d'elixir au depart, sinon a 25 s de jeu
		-- -- limite du client de test -- le terrain ne portait que 3 unites (mesure 2026-09-14).
		teams[team] = { elixir = ReplicatedStorage:FindFirstChild("BRR_PARTIE") and MAX_ELIXIR or 5, hand = hand, queue = queue, towers = {}, botTimer = 2, niveaux = niveaux,
			-- robot REACTIF par defaut ; le journal [BOT] doit dire la verite sur qui joue.
			botVersion = "nouveau" }
		table.insert(teams[team].towers, spawnTower(team, -VOIE_X, s * 22, false))
		table.insert(teams[team].towers, spawnTower(team, VOIE_X, s * 22, false))
		table.insert(teams[team].towers, spawnTower(team, 0, s * 28, true))
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
	local menaceVolante = false
	for _, e in ipairs(entities) do
		if e.alive ~= false and not e.isBuilding and e.team ~= team and e.part and (e.hp or 0) > 0 then
			local p = e.part.Position
			if p.Z * s > 0 then
				local voie = p.X < 0 and 1 or 2
				menace[voie] += e.hp
				if e.flying then
					menaceVolante = true
				end
			end
		end
	end
	local voieMenace = menace[1] >= menace[2] and 1 or 2
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
	-- (1) cartes jouables : en defense la plus chere (plus solide), en attaque aussi
	-- ANTI-AERIEN : s'il a un volant sur le dos, il prend d'abord une carte capable de le toucher.
	-- Avant, il posait une melee sous un bombardier et la regardait se faire raser sans riposte.
	local meilleur, meilleurCout = nil, -1
	local function choisir(filtre)
		local idx, cout = nil, -1
		for i = 1, 4 do
			local c = Cards.byId[t.hand[i]]
			if c and t.elixir >= c.cost and c.cost > cout and (not filtre or filtre(c)) then
				idx, cout = i, c.cost
			end
		end
		return idx, cout
	end
	-- ANTICIPATION : seul un robot au-dela du palier debutant pense a repondre aux volants.
	if menaceVolante and (not profil or profil.anticipe) then
		meilleur, meilleurCout = choisir(Regles.peutViserVolant)
	end
	if not meilleur then
		meilleur, meilleurCout = choisir(nil)
	end
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
	elseif enDanger then
		voie, z, raison = voieMenace, math.random(8, 12), "defense_voie" .. voieMenace
	elseif melee or t.elixir >= (profil
			and Robot.gardeAttaque(profil, Robot.enOuverture(MATCH_TIME - timeLeft, MATCH_TIME))
			or (MAX_ELIXIR - 3)) then
		-- fix-ok: seuil 9 jamais atteint (sim-v20.log : elixir en garde <= 7,9, 0 attaque) -> 7
		-- (3) elixir haut : attaquer la voie de la tour ennemie (non-roi) la plus faible
		local faible, pvMin = nil, math.huge
		for _, tw in ipairs(teams[3 - team].towers) do
			if tw.alive and not tw.isKing and tw.hp < pvMin then
				faible, pvMin = tw, tw.hp
			end
		end
		voie = faible and (faible.part.Position.X < 0 and 1 or 2) or math.random(1, 2)
		z, raison = melee and math.random(4, 9) or math.random(14, 20), "attaque_tour_faible"
	else
		journalBot(team, "passe", card.id, card.cost, t.elixir, "garde_elixir")
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
	-- la ligne, loin de la riviere. Pose a l'avant, il etait refuse et le robot perdait son
	-- tour sans rien depenser — une panne, pas une erreur de debutant.
	if Batiments.est(card) then
		z = s * math.random(12, 18)
		if card.batiment.type == "collecteur" then
			-- le collecteur se met a l'abri, au fond, derriere la tour du roi
			x, z = math.random(-6, 6), s * math.random(24, 27)
		else
			x = (voie == 1 or (x or 0) < 0) and -VOIE_X or VOIE_X
		end
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
	local seul = occupant[1] == nil and occupant[2] == nil
	local camp = attribuerCamp(player)
	if camp and seul and not ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") then
		-- premier joueur : partie NEUVE, sinon il arrive dans un match que le robot mene deja
		resetMatch()
	elseif camp and teams[camp] then
		-- la partie en cours avait distribue le paquet du robot : le joueur recoit le SIEN
		teams[camp].hand, teams[camp].queue = newDeck(Economie.deck(player))
		teams[camp].niveaux = Economie.niveaux(player)
	end
	majNiveauxRobot()
	return camp
end

local function quitter(player)
	local camp = equipeDe[player]
	if camp then
		occupant[camp] = nil
		equipeDe[player] = nil
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
	local ok, motif = Economie.acheterCarte(player, "Bombardiro")
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
	local r = Economie.recompenser(player, "victoire")
	cas("victoire : pieces", 30, r.pieces)
	cas("victoire : trophees", 30, p.trophees)
	Economie.recompenser(player, "defaite")
	cas("defaite : trophees", 15, p.trophees)
	Economie.recompenser(player, "defaite")
	cas("trophees jamais negatifs", 0, p.trophees)
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
		teams[camp].niveaux = Economie.niveaux(player)
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
		p.coffres = { { type = "or", fin = 0 }, { type = "argent", fin = os.time() + 47 * 60 }, { type = "bois", fin = os.time() - 5 } }
	end
	-- capture de la boutique avec des niveaux varies (build.py --niveaux)
	if ReplicatedStorage:FindFirstChild("BRR_NIVEAUX") then
		local p = Economie.profil(player)
		p.pieces = 480
		p.niveaux = { Tralalero = 3, TungSahur = 5, Ballerina = 2 }
		p.exemplaires = { Tralalero = 7, Cappuccino = 2, Chimpanzini = 1, Lirili = 5 }
	end
	if ReplicatedStorage:FindFirstChild("BRR_ECOTEST") then
		task.spawn(ecotest, player)
	end
	if ReplicatedStorage:FindFirstChild("BRR_AUTOTEST") and not ReplicatedStorage:FindFirstChild("BRR_HUB") then
		rejoindre(player)
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
		local ok, motif = Economie.reclamerQuete(player, arg)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "coffreGratuit" then
		local ok, motif = Economie.reclamerCoffreGratuit(player)
		return { ok = ok, motif = type(motif) == "table" and nil or motif, vue = Economie.vue(player) }
	elseif action == "demarrerCoffre" then
		local ok, motif = Economie.demarrerCoffre(player, tonumber(arg))
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "ouvrirCoffre" then
		local ok, gain = Economie.ouvrirCoffre(player, tonumber(arg))
		return { ok = ok, motif = not ok and gain or nil, gain = ok and gain or nil, vue = Economie.vue(player) }
	elseif action == "ameliorer" then
		local ok, motif = Economie.ameliorer(player, arg)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "deck" then
		-- `arg` = liste d'identifiants envoyee par le hub. Economie.choisirDeck refuse tout ce qui
		-- n'est pas possede : le client ne decide rien.
		local ok, motif = Economie.choisirDeck(player, arg)
		return { ok = ok, motif = motif, vue = Economie.vue(player) }
	elseif action == "jouer" then
		if Matchmaking.actif() and not equipeDe[player] then
			local etat = Matchmaking.entrer(player, rejoindre)
			return { ok = true, attente = etat == "attente", vue = Economie.vue(player) }
		end
		return { ok = rejoindre(player) ~= nil, vue = Economie.vue(player) }
	elseif action == "attente" then
		return { ok = true, etat = Matchmaking.etat(player), camp = equipeDe[player], vue = Economie.vue(player) }
	elseif action == "enMatch" then
		return { ok = Matchmaking.estServeurDeMatch(game), vue = Economie.vue(player) }
	elseif action == "quitter" then
		Matchmaking.sortir(player)
		quitter(player)
		return { ok = true, vue = Economie.vue(player) }
	elseif action == "classement" then
		return { ok = true, classement = Economie.classement(), vue = Economie.vue(player) }
	elseif action == "robux" then
		Economie.demanderRobux(player, tonumber(arg))
		return { ok = true, vue = Economie.vue(player) }
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
Players.PlayerRemoving:Connect(function(player)
	Economie.liberer(player)
	Matchmaking.sortir(player)
	local camp = equipeDe[player]
	if camp then
		occupant[camp] = nil
		equipeDe[player] = nil
		print("[BRR] camp " .. camp .. " libere : le bot le reprend")
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	arrivee(player)
end

local function campLibre(camp)
	return occupant[camp] == nil
end

-- Nom affiche dans le score : le joueur du camp adverse s'il y en a un, sinon le robot.
local function nomAdversaire(monCamp)
	local adversaire = occupant[3 - monCamp]
	return adversaire and adversaire.DisplayName or "Bot"
end

local function sendState(player)
	-- SPECTATEUR : aucun camp. Il recevait jusqu'ici l'etat du camp 1 (main, elixir, « Toi 0 - 1 »)
	-- comme s'il jouait. On ne lui envoie donc ni main ni elixir, et le score est donne camp par
	-- camp, sans « toi ».
	local camp = equipeDe[player]
	if camp == nil then
		StateEvent:FireClient(player, {
			elixir = 0,
			hand = {},
			nextCard = nil,
			timeLeft = timeLeft,
			phase = Regles.phase(timeLeft, MATCH_TIME, prolongation),
			spectateur = true,
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
		-- ARENE atteinte : le nom du palier de trophees, affiche pendant la partie.
		arene = Arenes.nom(Economie.tropheesDe(occupant[monCamp])),
		timeLeft = timeLeft,
		phase = Regles.phase(timeLeft, MATCH_TIME, prolongation),
		monCamp = monCamp,
		spectateur = false,
		crownsYou = crowns(monCamp),
		crownsEnemy = crowns(3 - monCamp),
		nomAdversaire = nomAdversaire(monCamp),
		chatVisible = occupant[3 - monCamp] ~= nil, -- chat seulement face a un humain
		result = texteFin(monCamp),
		combat = combat,
	})
end

PlayCard.OnServerEvent:Connect(function(player, handIndex, pos)
	if typeof(handIndex) ~= "number" or typeof(pos) ~= "Vector3" then
		return
	end
	local camp = equipeDe[player]
	if not camp then
		return -- spectateur : il regarde, il ne pose pas de carte
	end
	tryPlay(camp, math.floor(handIndex), pos)
end)

-- EMOTES RAPIDES (facon Clash Royale) : une bulle au-dessus de la tour du Roi de l'expediteur.
-- Liste FERMEE : le client envoie un identifiant, jamais un texte libre (pas de moderation a faire).
local EMOTES = { gg = "GG !", rire = "HAHA", bravo = "Bien joue", oups = "Oups !" }
local EMOTE_DELAI = 3 -- secondes minimum entre deux emotes du meme joueur
local derniereEmote = {}

-- Pure (testee hors Studio) : l'emote est-elle connue et le delai respecte ?
local function emoteAutorisee(id, derniere, maintenant)
	if type(id) ~= "string" or EMOTES[id] == nil then
		return false
	end
	return derniere == nil or maintenant - derniere >= EMOTE_DELAI
end

local function afficherEmote(camp, texte)
	local roi = teams[camp] and teams[camp].towers[3]
	if not (roi and roi.part and roi.part.Parent) then
		return
	end
	local ancienne = roi.part:FindFirstChild("BulleEmote")
	if ancienne then
		ancienne:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BulleEmote"
	gui.Size = UDim2.new(0, 120, 0, 40)
	gui.StudsOffset = Vector3.new(0, roi.part.Size.Y / 2 + 7, 0)
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
	gui.Parent = roi.part
	task.delay(2.5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

EmoteEvent.OnServerEvent:Connect(function(player, id)
	local camp = equipeDe[player]
	if not camp then
		return -- spectateur : pas de tour, pas d'emote
	end
	local maintenant = os.clock()
	if not emoteAutorisee(id, derniereEmote[player], maintenant) then
		return
	end
	derniereEmote[player] = maintenant
	afficherEmote(camp, EMOTES[id])
end)
Players.PlayerRemoving:Connect(function(player)
	derniereEmote[player] = nil
end)

PronosticEvent.OnServerEvent:Connect(function(player, camp)
	if pronosticAccepte(camp, equipeDe[player] ~= nil, pronostics[player] ~= nil, result ~= nil) then
		pronostics[player] = camp
	end
end)
Players.PlayerRemoving:Connect(function(player)
	pronostics[player] = nil
end)

RestartEvent.OnServerEvent:Connect(function(player)
	-- Seul un joueur qui TIENT un camp relance la partie. Un spectateur (aucun camp libre a son
	-- arrivee) pouvait sinon remettre a zero la partie des deux autres. Le controle est ICI, cote
	-- serveur : cacher le bouton cote client ne protege de rien, n'importe quel client peut envoyer
	-- l'evenement.
	if not equipeDe[player] then
		print("[BRR] Rejouer refuse : " .. player.Name .. " n'a pas de camp")
		return
	end
	if result then
		resetMatch()
	end
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

-- SIMULATION D'EQUILIBRE (build.py --autotest --run --sim="1-1:6;1-3:6;3-5:6") : series de parties
-- robot contre robot, niveaux imposes, temps x SIM_ACCEL. Le camp le plus fort ALTERNE a chaque
-- partie, pour ne pas mesurer un avantage de cote. Une ligne [SIM] par partie.
local SIM = ReplicatedStorage:FindFirstChild("BRR_SIM")
local SIM_ACCEL = 8
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
				print(string.format("[SIM] %d-%d partie=%d gagnant=%s couronnes_fort=%d couronnes_faible=%d pv_tours_fort=%d pv_tours_faible=%d temps_restant=%d",
					na, nb, k, gagnant, crowns(campFort), crowns(3 - campFort), pvTours(campFort), pvTours(3 - campFort), math.floor(timeLeft)))
				task.wait(0.5)
			end
		end
		print("[SIM] FIN")
	end)
end

-- STATUTS, image par image : le poison ronge, les soigneurs remettent des PV, et tout ce qui est
-- expire disparait NET (aucune vitesse residuelle, aucun demi-gel). La regle vit dans Statuts ;
-- ici on ne fait que parcourir les entites vivantes.
local function majStatuts(dt)
	for _, e in ipairs(entities) do
		if e.alive then
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
										a.fill.Size = UDim2.new(a.hp / a.maxHp, 0, 1, 0)
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
					e.fill.Size = UDim2.new(math.max(0, e.hp / e.maxHp), 0, 1, 0)
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
		dt = dt * SIM_ACCEL
	end
	if not result then
		timeLeft = timeLeft - dt
		horloge = horloge + dt
		for team = 1, 2 do
			local t = teams[team]
			t.elixir = math.min(MAX_ELIXIR,
				t.elixir + ELIXIR_PER_SEC * dt * Regles.multiplicateurElixir(timeLeft, MATCH_TIME, prolongation))
		end
		-- Le bot ne remplace que le camp SANS joueur : a deux joueurs, plus aucun bot.
		for camp = 1, 2 do
			-- gros plan de test : aucun robot, seule la rangee immobile est a l'image
			-- en melee, les DEUX camps jouent en rafale : sinon le robot seul rasait le camp du joueur en 13 s
			if (autoTest or campLibre(camp) or ReplicatedStorage:FindFirstChild("BRR_MELEE")) and not ReplicatedStorage:FindFirstChild("BRR_GROSPLAN") then
				botThink(camp, dt)
			end
		end
		majGroupes()
		majTirs()
		majStatuts(dt)
		majBatiments(dt)

		for _, e in ipairs(entities) do
			if e.alive and e.active then
				e.cooldown = e.cooldown - dt
				local target, d = findTarget(e)
				if target then
					if d <= e.range + target.part.Size.X / 2 then
						-- Arrivee au contact sans frapper encore : elle garde son elan pour LE coup
						-- qui vient, c'est tout l'interet. En revanche elle ne l'accumule plus.
						if e.cooldown <= 0 and Statuts.peutAgir(e, horloge) then
							-- meme rage que pour la marche : elle frappe aussi plus vite
							e.cooldown = e.atkSpeed / Sorts.multiplicateurRage(e.rageSort,
								e.rageT and (horloge - e.rageT) or nil)
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
