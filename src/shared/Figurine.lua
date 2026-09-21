-- FIGURINE : le rendu 3D d'une carte dans une vue d'interface. UN SEUL rendu pour les cinq endroits
-- ou une carte s'affiche : la collection, la grille de composition du deck, la rangee du deck sur
-- l'accueil, la main en partie et les cartes a venir.
--
-- Le defaut corrige (2026-09-21) : les cartes etaient des aplats de couleur portant un nom. Seules
-- les 17 cartes dotees d'un modele 3D avaient une image, et seulement sur l'accueil.
--
-- CE QUE LA CARTE MONTRE (regle pure : Portrait.source) :
--   - son MODELE 3D s'il existe (ReplicatedStorage.Modeles, ecrit dans la place par build.py) ;
--   - sinon sa SILHOUETTE en morceaux, assemblee EXACTEMENT comme le serveur la pose en jeu
--     (GameServer, `habiller`) : l'image est l'unite telle qu'on la voit sur le terrain ;
--   - sinon, pour un sort, son EMBLEME (Portrait.EMBLEMES) dans la couleur du sort.
-- Rien ne vient du catalogue Roblox : Cards.lua refuse explicitement cette dependance.
--
-- Ce module utilise l'API Roblox (il construit des pieces) : son cadrage et ses emblemes, eux, sont
-- dans Portrait.lua, pur et verifie hors du jeu (tools/test_portrait.py, tools/test_figurine.py).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared:WaitForChild("Cards"))
local Portrait = require(Shared:WaitForChild("Portrait"))

local Figurine = {}

local BLANC = Color3.new(1, 1, 1)

-- Une vue prete a recevoir une figurine : fond transparent, lumiere douce venant d'en haut a gauche.
function Figurine.vue(parent, zIndex)
	local vue = Instance.new("ViewportFrame")
	vue.Name = "Figurine"
	vue.BackgroundTransparency = 1
	vue.Ambient = Color3.fromRGB(170, 170, 185)
	vue.LightColor = Color3.fromRGB(255, 250, 240)
	vue.LightDirection = Vector3.new(-1, -1.4, 1)
	vue.Size = UDim2.fromScale(1, 1)
	vue.ZIndex = zIndex or 1
	vue.Visible = false
	vue.Parent = parent
	return vue
end

local function forme(piece, nom)
	if nom == "boule" then
		piece.Shape = Enum.PartType.Ball
	elseif nom == "cylindre" then
		piece.Shape = Enum.PartType.Cylinder
	end
end

local function construire(carte)
	local modeles = ReplicatedStorage:FindFirstChild("Modeles")
	-- Un modele EN BLOCS n'est pas retenu (Arrondi.MODELES_EN_BLOCS) : la carte montre alors la
	-- silhouette lissee, comme l'arene. Sans cela, le portrait et l'arene divergeraient.
	-- Ecrit avec un `if` et non « a and b and c » : quand le modele est ecarte, cette chaine rendait
	-- `false` (et non nil), et la ligne suivante appelait une methode sur ce booleen — le portrait
	-- plantait et le menu entier restait fige (journal Studio du 2026-09-21, Figurine:59).
	local source = nil
	-- un CHAMPION reprend le modele de sa carte de base (`modele`), comme dans l'arene
	if modeles and require(Shared:WaitForChild("Arrondi")).modeleRetenu(carte.modele or carte.id) then
		source = modeles:FindFirstChild(carte.modele or carte.id)
	end
	-- MODELE NON MESURABLE (capture cap-cartes-main.png du 2026-09-21) : Cappuccino et Tralaleritos
	-- sont un bloc de 1 stud portant un maillage (SpecialMesh) bien plus grand que lui. Le cadrage
	-- lit la boite du BLOC : l'image sortait a une echelle au hasard (minuscule, ou un aplat rose qui
	-- remplissait la carte). Ces modeles cedent la place a leur silhouette, qui, elle, se mesure.
	local mesurable = source ~= nil and source:FindFirstChildWhichIsA("SpecialMesh", true) == nil
	local genre = Portrait.source(carte, mesurable)

	if genre == "modele" then
		local copie = source:Clone()
		-- MEME correction que le serveur (GameServer, `habiller`) : l'avant du modele regarde vers -Z.
		copie.WorldPivot = CFrame.new()
		copie:PivotTo(CFrame.Angles(0, math.rad(carte.modeleRotY or 0), 0))
		return copie
	end

	local modele = Instance.new("Model")
	if genre == "morceaux" then
		local k = carte.echelle or 1
		-- MEME LISSAGE que le serveur (module Arrondi) : sans lui, le personnage etait rond dans
		-- l'arene et en BLOCS sur sa carte en main (capture cap-lisse-1.png du 2026-09-21).
		local arrondi = require(Shared:WaitForChild("Arrondi"))
		local lisser = arrondi.applicable(carte, false)
		for _, m in ipairs(carte.morceaux) do
			local piece = Instance.new("Part")
			piece.Anchored = true
			-- MEME calcul que le serveur (GameServer, `habiller`) : ecart, taille, couleur, matiere.
			local ecart = m.pos * k + Vector3.new(0, (k - 1) * carte.size.Y / 2, 0)
			piece.Size = m.taille * k
			piece.Color = m.couleur or carte.color
			piece.Material = m.materiau and Enum.Material[m.materiau] or Enum.Material.SmoothPlastic
			forme(piece, m.forme)
			if lisser and m.forme == nil and arrondi.forme(m.taille, m.forme) == "ellipsoide" then
				local lisse = Instance.new("SpecialMesh")
				lisse.MeshType = Enum.MeshType.Sphere
				lisse.Parent = piece
			end
			piece.CFrame = CFrame.new(ecart) * CFrame.Angles(
				math.rad(m.rot and m.rot.X or 0), math.rad(m.rot and m.rot.Y or 0), math.rad(m.rot and m.rot.Z or 0))
			piece.Parent = modele
		end
	elseif genre == "embleme" then
		local base = carte.sort.couleur or carte.color
		for _, m in ipairs(Portrait.embleme(carte.sort)) do
			local piece = Instance.new("Part")
			piece.Anchored = true
			piece.Size = Vector3.new(m.taille.x, m.taille.y, m.taille.z)
			piece.Color = base:Lerp(BLANC, m.clair)
			piece.Material = Enum.Material.SmoothPlastic
			forme(piece, m.forme)
			piece.CFrame = CFrame.new(m.pos.x, m.pos.y, m.pos.z) * CFrame.Angles(
				math.rad(m.rot.x), math.rad(m.rot.y), math.rad(m.rot.z))
			piece.Parent = modele
		end
	else
		modele:Destroy()
		return nil
	end
	return modele
end

-- Rend la carte `id` dans `vue`. Idempotent : la meme carte n'est pas reconstruite a chaque
-- rafraichissement (le menu et la main se mettent a jour plusieurs fois par seconde).
function Figurine.rendre(vue, id)
	if vue:GetAttribute("Carte") == id then
		return
	end
	vue:SetAttribute("Carte", id)
	vue:ClearAllChildren()
	local carte = id and Cards.byId[id]
	local modele = carte and construire(carte)
	vue.Visible = modele ~= nil
	if not modele then
		return -- aucune apparence connue : la carte garde son aplat de couleur
	end
	modele.Parent = vue
	local centre, taille = modele:GetBoundingBox()
	local ox, oy, oz = Portrait.oeil(Portrait.distance(taille.X, taille.Y, taille.Z))
	if not ox then
		vue.Visible = false
		return
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = Portrait.CHAMP
	camera.CFrame = CFrame.lookAt(centre.Position + Vector3.new(ox, oy, oz), centre.Position)
	camera.Parent = vue
	vue.CurrentCamera = camera
end

return Figurine
