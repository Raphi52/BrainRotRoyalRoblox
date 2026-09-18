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

-- COUP ENCAISSE : la cible vire au blanc 0,08 s puis reprend sa couleur. Toutes les pieces visibles
-- de la cible flashent (le corps d'une unite habillee est invisible : ce sont ses morceaux qui se
-- voient). La couleur d'origine est gardee dans un attribut : deux coups rapproches ne peuvent
-- donc pas « oublier » la vraie couleur en sauvegardant le blanc du premier flash.
local BLANC = Color3.new(1, 1, 1)
function Effets.coup(corps, duree)
	local touchees = {}
	local function prendre(p)
		if p:IsA("BasePart") and p.Transparency < 1 and p:GetAttribute("CouleurCoup") == nil then
			p:SetAttribute("CouleurCoup", p.Color)
			p.Color = BLANC
			table.insert(touchees, p)
		end
	end
	prendre(corps)
	for _, d in ipairs(corps:GetDescendants()) do
		prendre(d)
	end
	task.delay(duree or 0.08, function()
		for _, p in ipairs(touchees) do
			p.Color = p:GetAttribute("CouleurCoup")
			p:SetAttribute("CouleurCoup", nil)
		end
	end)
	return #touchees
end

-- POSE D'ANIMATION (calcul pur, sans instance : le serveur en fait un CFrame applique aux morceaux).
-- marche : 0 (arret) a 1 (pleine marche) ; phase : angle du pas ; depuisAttaque / depuisCoup :
-- secondes ecoulees depuis le dernier coup porte / recu. Rend : hauteur, roulis, avancee, tangage.
Effets.ATTAQUE_DUREE = 0.25
Effets.COUP_DUREE = 0.15
function Effets.posture(marche, phase, depuisAttaque, depuisCoup)
	local haut = math.abs(math.sin(phase)) * 0.35 * marche -- rebond a chaque pas
	local roulis = math.sin(phase) * math.rad(7) * marche  -- dandinement gauche/droite
	local avant, tangage = 0, 0
	if depuisAttaque >= 0 and depuisAttaque < Effets.ATTAQUE_DUREE then
		local k = math.sin(math.pi * depuisAttaque / Effets.ATTAQUE_DUREE)
		avant = avant + 0.7 * k             -- elan vers la cible
		tangage = tangage - math.rad(12) * k -- penche en avant
	end
	if depuisCoup >= 0 and depuisCoup < Effets.COUP_DUREE then
		avant = avant - 0.3 * (1 - depuisCoup / Effets.COUP_DUREE) -- recul de 0,3 stud
	end
	return haut, roulis, avant, tangage
end

-- PROJECTILE : position a l'instant u (0..1) entre a et b ; `hauteur` > 0 donne une parabole.
function Effets.trajectoire(a, b, u, hauteur)
	local p = a + (b - a) * u
	return p + Vector3.new(0, (hauteur or 0) * 4 * u * (1 - u), 0)
end

-- Un tir VOYAGE de a vers b (0,15 a 0,35 s) avec une trainee. Purement visuel : le serveur a deja
-- applique le degat a l'instant du tir, l'equilibrage ne bouge pas.
function Effets.projectile(parent, a, b, couleur, enCloche)
	local Debris = services()
	local RunService = game:GetService("RunService")
	local long = (b - a).Magnitude
	local duree = enCloche and 0.35 or math.clamp(long / 70, 0.15, 0.3)
	local hauteur = enCloche and math.max(3, long * 0.35) or 0
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = couleur
	if enCloche then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.2, 1.2, 1.2)
	else
		p.Size = Vector3.new(0.35, 0.35, 1.4)
	end
	p.CFrame = CFrame.lookAt(a, b)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.25, 0)
	a1.Position = Vector3.new(0, -0.25, 0)
	a0.Parent, a1.Parent = p, p
	local trainee = Instance.new("Trail")
	trainee.Attachment0, trainee.Attachment1 = a0, a1
	trainee.Color = ColorSequence.new(couleur)
	trainee.Transparency = NumberSequence.new(0.2, 1)
	trainee.Lifetime = 0.18
	trainee.LightEmission = 1
	trainee.Parent = p
	p.Parent = parent
	Debris:AddItem(p, duree + 0.3)
	task.spawn(function()
		local debut, prec = os.clock(), a
		while p.Parent do
			local u = math.min((os.clock() - debut) / duree, 1)
			local pos = Effets.trajectoire(a, b, u, hauteur)
			if (pos - prec).Magnitude > 0.001 then
				p.CFrame = CFrame.lookAt(pos, pos + (pos - prec))
			end
			prec = pos
			if u >= 1 then
				p.Transparency = 1
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	return p, duree
end

return Effets
