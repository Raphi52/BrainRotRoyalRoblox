-- Brainrot Royale : habillage visuel (« game feel »).
-- Tout ici est fabrique a la volee avec des instances de base : particules, lumiere, anneau.
-- AUCUN identifiant d'asset n'est requis, donc ce module marche sur n'importe quel compte Roblox.
-- Cote SERVEUR : les parts creees dans l'arene sont repliquees a tous les clients.
local Effets = {}

local function services()
	return game:GetService("Debris"), game:GetService("TweenService")
end

local function partTemporaire(parent, position, duree)
	local Debris = services()
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = position
	p.Parent = parent
	Debris:AddItem(p, duree)
	return p
end

local function particules(hote, couleur, taille, vitesse, nombre)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(couleur)
	e.Size = NumberSequence.new(taille)
	e.Speed = NumberRange.new(vitesse)
	e.Lifetime = NumberRange.new(0.25, 0.55)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = hote
	e:Emit(nombre)
	return e
end

local function eclat(hote, couleur, portee, duree)
	local Debris = services()
	local l = Instance.new("PointLight")
	l.Color = couleur
	l.Brightness = 4
	l.Range = portee
	l.Parent = hote
	Debris:AddItem(l, duree)
	return l
end

-- Mort d'une unite : gerbe de particules + lueur breve.
function Effets.mort(parent, position, couleur)
	local hote = partTemporaire(parent, position, 0.9)
	particules(hote, couleur, 1.2, 9, 22)
	eclat(hote, couleur, 10, 0.25)
	return hote
end

-- Chute d'une tour : plus gros, plus long, lumiere plus large.
function Effets.tourDetruite(parent, position, couleur)
	local hote = partTemporaire(parent, position, 1.8)
	particules(hote, couleur, 3.5, 22, 90)
	eclat(hote, couleur, 34, 0.9)
	return hote
end

-- Impact d'un tir : petite gerbe seche, sans lumiere.
function Effets.impact(parent, position, couleur)
	local hote = partTemporaire(parent, position, 0.5)
	particules(hote, couleur, 0.6, 6, 8)
	return hote
end

-- Pose d'une carte : anneau qui s'ouvre et s'efface (Tween), pour confirmer le geste du joueur.
function Effets.pose(parent, position, couleur)
	local Debris, TweenService = services()
	local anneau = Instance.new("Part")
	anneau.Anchored = true
	anneau.CanCollide = false
	anneau.CanQuery = false
	anneau.Material = Enum.Material.Neon
	anneau.Color = couleur
	anneau.Shape = Enum.PartType.Cylinder
	anneau.Size = Vector3.new(0.2, 2, 2)
	anneau.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	anneau.Transparency = 0.2
	anneau.Parent = parent
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anneau, info, { Size = Vector3.new(0.2, 14, 14), Transparency = 1 }):Play()
	Debris:AddItem(anneau, 0.6)
	local hote = partTemporaire(parent, position + Vector3.new(0, 1, 0), 0.8)
	particules(hote, couleur, 0.9, 7, 14)
	return anneau
end

-- Fin de partie : feu d'artifice au-dessus du camp vainqueur.
function Effets.victoire(parent, position, couleur)
	local hote = partTemporaire(parent, position + Vector3.new(0, 12, 0), 2.5)
	particules(hote, couleur, 4, 28, 140)
	eclat(hote, couleur, 45, 1.6)
	return hote
end

return Effets
