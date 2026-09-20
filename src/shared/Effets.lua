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

-- COURBES DE RENDU. Un emetteur « plat » (couleur unie, taille fixe, opacite constante, aucune
-- retombee) donne l'aspect confetti d'un prototype : les particules apparaissent et disparaissent
-- d'un bloc. Les trois courbes ci-dessous donnent le vocabulaire visuel du jeu :
--   taille   : la gerbe s'ouvre vite (25 % du temps de vie) puis se referme jusqu'a zero ;
--   opacite  : fondu d'entree tres court, fondu de sortie long -> aucune coupure seche ;
--   couleur  : coeur blanc chaud a la naissance, teinte du camp ensuite -> lecture d'impact.
local function courbeTaille(taille)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, taille * 0.35),
		NumberSequenceKeypoint.new(0.25, taille),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local function courbeOpacite()
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function degrade(couleur)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.22, couleur),
		ColorSequenceKeypoint.new(1, couleur),
	})
end

local function particules(hote, couleur, taille, vitesse, nombre)
	local e = Instance.new("ParticleEmitter")
	e.Color = degrade(couleur)
	e.Size = courbeTaille(taille)
	e.Transparency = courbeOpacite()
	e.Speed = NumberRange.new(vitesse * 0.45, vitesse)
	e.Lifetime = NumberRange.new(0.25, 0.55)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(-180, 180)
	e.RotSpeed = NumberRange.new(-240, 240)
	e.Acceleration = Vector3.new(0, -34, 0)  -- les debris RETOMBENT au lieu de flotter
	e.Drag = 1.8
	e.LightEmission = 0.75                    -- braise : la particule eclaire au lieu de subir
	e.LightInfluence = 0
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

-- ONDE DE CHOC : anneau plat qui s'etale et s'efface. C'est ce qui donne du POIDS a un
-- evenement : sans lui, la chute d'une tour n'est qu'un tas de particules.
local function onde(parent, position, couleur, rayon, duree)
	local _, TweenService = services()
	local Debris = services()
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CastShadow = false
	a.Material = Enum.Material.Neon
	a.Color = couleur
	a.Shape = Enum.PartType.Cylinder
	a.Size = Vector3.new(0.2, 3, 3)
	a.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	a.Transparency = 0.15
	a.Parent = parent
	TweenService:Create(a, TweenInfo.new(duree, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, rayon, rayon), Transparency = 1 }):Play()
	Debris:AddItem(a, duree + 0.1)
	return a
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
	onde(parent, position, couleur, 46, 0.7)
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
	onde(parent, position, couleur, 60, 1.1)
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

-- ===== CHIFFRES DE DEGATS FLOTTANTS =====
-- Pourquoi : rien ne disait COMBIEN un coup enlevait. Le joueur voyait une barre de vie descendre
-- et devait deviner si son Tralalero faisait mal ou rien du tout — c'est le retour le plus direct
-- qui manquait en combat, et il rend chaque echange lisible.
Effets.DEGATS_DUREE = 0.75
Effets.DEGATS_MONTEE = 4.5 -- studs parcourus vers le haut
Effets.DEGATS_TAILLE_MIN = 16
Effets.DEGATS_TAILLE_MAX = 42
-- Au-dela de ce montant, le chiffre ne grossit plus : sinon un sort a 340 ecrasait tout l'ecran.
Effets.DEGATS_PLAFOND = 250

-- TAILLE du chiffre selon le montant (calcul pur, donc verifiable au banc). Un petit coup reste
-- discret, un gros coup se voit de loin, et tout est borne.
function Effets.tailleChiffre(montant)
	local m = math.max(0, montant or 0)
	local k = math.min(m / Effets.DEGATS_PLAFOND, 1)
	return math.floor(Effets.DEGATS_TAILLE_MIN + (Effets.DEGATS_TAILLE_MAX - Effets.DEGATS_TAILLE_MIN) * k + 0.5)
end

-- LIMITEUR : dans une melee, chaque coup de chaque unite produirait un chiffre — des centaines par
-- seconde, illisibles et couteux. On en autorise `parSeconde` au plus, et on compte les refuses.
function Effets.limiteurChiffres(parSeconde)
	local fenetre, jetons = -1, 0
	return function(maintenant)
		local seconde = math.floor(maintenant)
		if seconde ~= fenetre then
			fenetre, jetons = seconde, 0
		end
		if jetons >= parSeconde then
			return false
		end
		jetons = jetons + 1
		return true
	end
end

-- LE CHIFFRE LUI-MEME : une etiquette qui monte et s'efface au-dessus de la cible touchee.
-- `couleur` = couleur du camp qui ENCAISSE (on lit tout de suite qui prend cher).
function Effets.chiffreDegats(parent, position, montant, couleur)
	local Debris, TweenService = services()
	local m = math.floor((montant or 0) + 0.5)
	if m <= 0 then
		return nil -- un coup a 0 n'apprend rien : on n'affiche rien
	end
	local hote = Instance.new("Part")
	hote.Anchored = true
	hote.CanCollide = false
	hote.CanQuery = false
	hote.CastShadow = false
	hote.Transparency = 1
	hote.Size = Vector3.new(0.2, 0.2, 0.2)
	-- decalage lateral aleatoire : deux coups simultanes ne se superposent pas exactement
	hote.Position = position + Vector3.new((math.random() - 0.5) * 2.5, 2, (math.random() - 0.5) * 2.5)
	hote.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 120, 0, 40)
	gui.AlwaysOnTop = true
	gui.Parent = hote
	local texte = Instance.new("TextLabel")
	texte.BackgroundTransparency = 1
	texte.Size = UDim2.new(1, 0, 1, 0)
	texte.Font = Enum.Font.GothamBlack
	texte.Text = "-" .. m
	texte.TextSize = Effets.tailleChiffre(m)
	texte.TextColor3 = couleur or Color3.new(1, 1, 1)
	texte.TextStrokeTransparency = 0
	texte.TextStrokeColor3 = Color3.new(0, 0, 0)
	texte.Parent = gui
	local info = TweenInfo.new(Effets.DEGATS_DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(hote, info, { Position = hote.Position + Vector3.new(0, Effets.DEGATS_MONTEE, 0) }):Play()
	TweenService:Create(texte, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(hote, Effets.DEGATS_DUREE + 0.1)
	return hote
end

-- POSE D'ANIMATION (calcul pur, sans instance : le serveur en fait un CFrame applique aux morceaux).
-- marche : 0 (arret) a 1 (pleine marche) ; phase : angle du pas ; depuisAttaque / depuisCoup :
-- secondes ecoulees depuis le dernier coup porte / recu. Rend : hauteur, roulis, avancee, tangage.
Effets.ATTAQUE_DUREE = 0.25
Effets.COUP_DUREE = 0.15
Effets.APPARITION_DUREE = 0.45
Effets.AGONIE_DUREE = 0.45

-- STYLE DE DEMARCHE par carte, deduit de ses chiffres de jeu (aucun champ a maintenir a la main,
-- donc aucune carte ne peut etre oubliee) :
--   vol    : flotte et s'incline, aucun appui au sol (flying) ;
--   bond   : petits groupes rapides, saut ample plutot que pas ;
--   lourd  : gros PV lents, pas pesant, roulis large, peu de rebond ;
--   tir    : longue portee, reste stable et recule a chaque tir ;
--   marche : demarche par defaut.
function Effets.style(card)
	if card.flying then return "vol" end
	if (card.count or 1) >= 2 and (card.speed or 0) >= 12 then return "bond" end
	if (card.hp or 0) >= 1800 or (card.speed or 99) <= 6 then return "lourd" end
	if (card.range or 0) >= 9 then return "tir" end
	return "marche"
end

-- coefficients par style : rebond, roulis, tangage de marche, recul de tir, lacet (balancement
-- gauche-droite du corps), et vitesse de cycle.
local STYLES = {
	marche = { rebond = 0.35, roulis = 7, tangage = 0, recul = 0, lacet = 0, cadence = 1 },
	vol =    { rebond = 0.55, roulis = 12, tangage = 4, recul = 0.15, lacet = 6, cadence = 0.55 },
	bond =   { rebond = 0.85, roulis = 4, tangage = 10, recul = 0, lacet = 0, cadence = 1.15 },
	lourd =  { rebond = 0.18, roulis = 12, tangage = 3, recul = 0, lacet = 4, cadence = 0.7 },
	tir =    { rebond = 0.22, roulis = 5, tangage = 0, recul = 0.45, lacet = 0, cadence = 0.9 },
}
Effets.STYLES = STYLES
function Effets.cadence(style)
	return (STYLES[style] or STYLES.marche).cadence
end

-- `style` (facultatif, 5e argument) : nom rendu par Effets.style. Sans lui, la demarche par defaut
-- est rendue a l'identique — les appels a quatre arguments restent valides.
-- Rend : hauteur, roulis, avancee, tangage, lacet.
function Effets.posture(marche, phase, depuisAttaque, depuisCoup, style)
	local s = STYLES[style] or STYLES.marche
	local vol = style == "vol"
	-- en vol, le flottement ne s'arrete jamais : un volant a l'arret plane encore.
	local appui = vol and math.max(marche, 0.65) or marche
	local haut = (vol and math.sin(phase) or math.abs(math.sin(phase))) * s.rebond * appui
	local roulis = math.sin(phase) * math.rad(s.roulis) * appui
	local lacet = math.sin(phase * 0.5) * math.rad(s.lacet) * appui
	local avant, tangage = 0, math.sin(phase) * math.rad(s.tangage) * marche
	if depuisAttaque >= 0 and depuisAttaque < Effets.ATTAQUE_DUREE then
		local k = math.sin(math.pi * depuisAttaque / Effets.ATTAQUE_DUREE)
		avant = avant + 0.7 * k             -- elan vers la cible
		tangage = tangage - math.rad(12) * k -- penche en avant
	end
	if depuisAttaque >= 0 and depuisAttaque < Effets.ATTAQUE_DUREE and s.recul > 0 then
		-- un tireur ne se jette pas sur sa cible : il encaisse le depart du coup.
		local k = math.sin(math.pi * depuisAttaque / Effets.ATTAQUE_DUREE)
		avant = avant - (0.7 + s.recul) * k
		tangage = tangage + math.rad(6) * k
	end
	if depuisCoup >= 0 and depuisCoup < Effets.COUP_DUREE then
		avant = avant - 0.3 * (1 - depuisCoup / Effets.COUP_DUREE) -- recul de 0,3 stud
	end
	return haut, roulis, avant, tangage, lacet
end

-- APPARITION : l'unite tombe du ciel et s'ecrase au sol avec un rebond amorti. `t` = secondes
-- depuis la pose. Rend une hauteur a ajouter et un tangage ; a t >= APPARITION_DUREE, rend 0, 0
-- (l'unite est exactement a sa place, aucune derive possible).
function Effets.apparition(t)
	if t < 0 or t >= Effets.APPARITION_DUREE then
		return 0, 0
	end
	local u = t / Effets.APPARITION_DUREE
	if u < 0.55 then
		-- chute : 9 studs plus haut, acceleration quadratique
		local k = u / 0.55
		return 9 * (1 - k) * (1 - k), math.rad(-14) * (1 - k)
	end
	-- rebond amorti apres le contact
	local k = (u - 0.55) / 0.45
	return math.abs(math.sin(k * math.pi * 1.5)) * 0.9 * (1 - k), 0
end

-- AGONIE : une unite abattue ne disparait plus d'un coup — elle bascule, s'enfonce et s'efface
-- pendant AGONIE_DUREE, puis elle est detruite. Le jeu l'a deja retiree du combat : purement
-- visuel, aucun effet sur l'equilibrage.
function Effets.agonie(corps, duree)
	local Debris = services()
	local RunService = game:GetService("RunService")
	duree = duree or Effets.AGONIE_DUREE
	local pieces = { corps }
	for _, d in ipairs(corps:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(pieces, d)
		end
	end
	local depart, bases = os.clock(), {}
	for _, p in ipairs(pieces) do
		bases[p] = { cf = p.CFrame, t = p.Transparency }
	end
	Debris:AddItem(corps, duree + 0.1)
	task.spawn(function()
		while corps.Parent do
			local u = math.min((os.clock() - depart) / duree, 1)
			for _, p in ipairs(pieces) do
				local b = bases[p]
				if b then
					p.CFrame = b.cf * CFrame.new(0, -2.2 * u * u, 0) * CFrame.Angles(0, 0, math.rad(80) * u)
					p.Transparency = b.t + (1 - b.t) * u
				end
			end
			if u >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if corps.Parent then
			corps:Destroy()
		end
	end)
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
