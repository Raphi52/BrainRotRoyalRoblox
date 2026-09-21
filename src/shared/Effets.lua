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
	-- etincelles blanches, courtes et rapides : le coup se lit meme au milieu d'une melee
	local e = particules(hote, Color3.new(1, 0.95, 0.8), 0.25, 16, 6)
	e.Lifetime = NumberRange.new(0.1, 0.22)
	return hote
end

-- COURONNE GAGNEE : une couronne doree jaillit de la tour tombee, monte et s'efface, sur une pluie
-- d'or. C'est le moment le plus important de la partie : il doit se voir de tout l'ecran.
local OR = Color3.new(1, 205 / 255, 70 / 255)
-- Capture du 2026-09-21 : a 5 studs, en Neon, sur 1,4 s, la forme se fondait dans l'eclat.
Effets.COURONNE_DUREE = 2.5
Effets.COURONNE_TAILLE = 9
function Effets.couronne(parent, position, couleur)
	local Debris, TweenService = services()
	local k = Effets.COURONNE_TAILLE / 5
	-- basse et courte montee : plus haut, elle sortait du cadre (capture du 2026-09-21)
	local base = position + Vector3.new(0, 5, 0)
	local c = Instance.new("Model")
	c.Name = "CouronneGagnee"
	local pieces = {}
	local function piece(taille, decalage)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Foil -- metal, pas Neon : la silhouette se detache de l'eclat
		p.Color = OR
		p.Size = taille * k
		p.CFrame = CFrame.new(base + decalage * k)
		p.Parent = c
		table.insert(pieces, { p = p, d = decalage * k })
		return p
	end
	piece(Vector3.new(5, 1.4, 5), Vector3.new(0, 0, 0)) -- bandeau
	for i = 0, 4 do -- cinq pointes
		local a = math.rad(i * 72)
		piece(Vector3.new(0.9, 1.8, 0.9), Vector3.new(math.cos(a) * 2, 1.5, math.sin(a) * 2))
	end
	c.Parent = parent
	local duree = Effets.COURONNE_DUREE
	-- monte et tourne pendant toute la duree, reste OPAQUE, puis s'efface sur les 0,6 dernieres s
	local monte = TweenInfo.new(duree, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local efface = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duree - 0.6)
	for _, x in ipairs(pieces) do
		TweenService:Create(x.p, monte, {
			CFrame = CFrame.new(base + Vector3.new(0, 3, 0) + x.d) * CFrame.Angles(0, math.rad(200), 0),
		}):Play()
		TweenService:Create(x.p, efface, { Transparency = 1 }):Play()
	end
	Debris:AddItem(c, duree + 0.2)
	local hote = partTemporaire(parent, base, 2)
	particules(hote, OR, 1.6, 20, 70)
	particules(hote, couleur, 1.1, 14, 30)
	eclat(hote, OR, 40, 1.2)
	onde(parent, position, OR, 54, 0.9)
	return c
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
-- ===== GIVRE : LE GEL SE VOIT =====
-- Defaut mesure le 2026-09-20, capture a l'appui : une unite GELEE etait a l'ecran RIGOUREUSEMENT
-- identique a une unite libre. Le joueur voyait un tas d'ennemis s'arreter sans comprendre
-- pourquoi, et rien ne disait combien de temps cela durait. Le calcul du gel vivait dans Statuts,
-- mais personne ne le DESSINAIT.
--
-- Le rendu : une gangue de glace translucide autour du corps, plus un halo bleu. Elle est POSEE au
-- debut du gel et RETIREE a sa fin, par son nom — jamais par un minuteur separe, sinon un second
-- gel lance pendant le premier effacerait la glace alors que l'unite est toujours prise.
Effets.GIVRE_COULEUR = Color3.new(150 / 255, 225 / 255, 255 / 255) -- bleu glace
Effets.GIVRE_NOM = "Givre"
Effets.GIVRE_MARGE = 1.5 -- la gangue depasse nettement du corps (1,35 se confondait avec lui)
Effets.CRISTAL_NOM = "GivreCristal"
local GIVRE_VIF = Color3.new(200 / 255, 245 / 255, 255 / 255) -- givre, plus clair que la coque
-- bleu SATURE pour les cristaux et l'onde : pale, ils viraient au blanc-jaune au soleil (capture du 2026-09-21)
local GLACE_FORTE = Color3.new(70 / 255, 180 / 255, 255 / 255)
-- CRISTAUX : ecart (en fractions de la taille) et inclinaison (degres). Ils herissent la coque :
-- c'est ce qui fait lire « GELE » et non « devenu blanc » (capture Rugissement du 2026-09-21).
local CRISTAUX = {
	{ 0, 0.62, 0, 0, 0, 12 }, { 0.42, 0.45, 0.2, 0, 0, -38 }, { -0.42, 0.4, -0.15, 0, 0, 40 },
	{ 0.1, 0.42, 0.45, 35, 0, 0 }, { -0.12, 0.38, -0.48, -32, 0, 0 },
}

function Effets.givrer(corps, taille)
	if not corps or corps:FindFirstChild(Effets.GIVRE_NOM) then
		return nil -- deja gele : on ne rempile pas une seconde gangue
	end
	local t = taille or corps.Size
	local glace = Instance.new("Part")
	glace.Name = Effets.GIVRE_NOM
	glace.Anchored = true
	glace.CanCollide = false
	glace.CanQuery = false
	glace.CastShadow = false
	glace.Material = Enum.Material.Ice
	glace.Color = Effets.GIVRE_COULEUR
	glace.Transparency = 0.3
	glace.Reflectance = 0.25
	glace.Size = t * Effets.GIVRE_MARGE
	-- suit le corps par les memes attributs que les morceaux (voir `suivreCorps` cote serveur)
	glace:SetAttribute("Ecart", Vector3.new(0, 0, 0))
	glace:SetAttribute("RotX", 0); glace:SetAttribute("RotY", 0); glace:SetAttribute("RotZ", 0)
	glace.CFrame = corps.CFrame
	glace.Parent = corps
	local halo = Instance.new("PointLight")
	halo.Color = Effets.GIVRE_COULEUR
	halo.Range = math.max(t.X, t.Y, t.Z) * 2
	halo.Brightness = 1.6
	halo.Parent = glace
	-- GIVRE QUI S'ECHAPPE : paillettes blanches qui montent doucement, en continu tant que
	-- l'unite est gelee (l'emetteur part avec la coque au degel)
	local givre = Instance.new("ParticleEmitter")
	givre.Color = ColorSequence.new(GIVRE_VIF)
	givre.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	givre.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	givre.Lifetime = NumberRange.new(0.6, 1.1)
	givre.Speed = NumberRange.new(1, 3)
	givre.SpreadAngle = Vector2.new(180, 180)
	givre.Acceleration = Vector3.new(0, 2.5, 0)
	givre.Rotation = NumberRange.new(0, 360)
	givre.RotSpeed = NumberRange.new(-90, 90)
	givre.LightEmission = 0.8
	givre.Rate = 28
	givre.Parent = glace
	-- CRISTAUX : enfants du CORPS avec les attributs de suivi, ils bougent donc avec lui
	for _, c in ipairs(CRISTAUX) do
		local k = Instance.new("Part")
		k.Name = Effets.CRISTAL_NOM
		k.Anchored = true
		k.CanCollide = false
		k.CanQuery = false
		k.CastShadow = false
		k.Material = Enum.Material.Neon
		k.Color = GLACE_FORTE
		k.Transparency = 0.05
		-- assez gros pour se lire a la distance de la camera de jeu
		k.Size = Vector3.new(0.8, math.max(2, t.Y * 0.9), 0.8)
		k:SetAttribute("Ecart", Vector3.new(c[1] * t.X, c[2] * t.Y, c[3] * t.Z))
		k:SetAttribute("RotX", c[4]); k:SetAttribute("RotY", c[5]); k:SetAttribute("RotZ", c[6])
		k.CFrame = corps.CFrame
		k.Parent = corps
	end
	return glace
end

-- DEGIVRER : retire la gangue. Appele quand le statut de gel expire, jamais avant.
function Effets.degivrer(corps)
	local glace = corps and corps:FindFirstChild(Effets.GIVRE_NOM)
	if glace then
		for _, k in ipairs(corps:GetChildren()) do
			if k.Name == Effets.CRISTAL_NOM then
				k:Destroy()
			end
		end
		glace:Destroy()
		return true
	end
	return false
end

-- ONDE DE GIVRE (Rugissement) : un CERCLE DE PICS DE GLACE sort du sol au rayon REEL du gel, tient
-- un instant, puis s'effrite (les pics s'enfoncent en s'effacant, des eclats volent). Remplace
-- l'anneau plat, qui vu de la camera de jeu se fondait dans sa propre lumiere (capture du
-- 2026-09-21). Un pic se lit comme de la glace sous n'importe quel angle.
Effets.PICS_ONDE = 14
function Effets.ondeGivre(parent, position, rayon)
	local Debris, TweenService = services()
	local sol = position.Y - 1.2
	for i = 1, Effets.PICS_ONDE do
		local a = (i / Effets.PICS_ONDE) * math.pi * 2
		-- rayon et hauteur legerement irreguliers : un cercle trop parfait fait decor
		local r = rayon * (0.9 + 0.2 * ((i * 7) % 5) / 4)
		-- assez grands pour se lire depuis la camera de jeu (0,9 x 3 : de simples points, capture du 2026-09-21)
		local h = 4.5 + ((i * 3) % 4) * 0.5
		local x, z = position.X + math.cos(a) * r, position.Z + math.sin(a) * r
		local pic = Instance.new("Part")
		pic.Name = "PicGivre"
		pic.Anchored = true
		pic.CanCollide = false
		pic.CanQuery = false
		pic.CastShadow = false
		pic.Material = Enum.Material.Glass
		pic.Color = GLACE_FORTE
		pic.Transparency = 0.1
		pic.Reflectance = 0.2
		pic.Size = Vector3.new(1.5, h, 1.5)
		-- penche VERS L'EXTERIEUR, comme repousse par le cri
		local function pose(y)
			return CFrame.new(x, y, z) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-18))
		end
		local cache, dehors = pose(sol - h / 2), pose(sol + h / 2 - 0.3)
		pic.CFrame = cache
		pic.Parent = parent
		-- 1) il JAILLIT
		TweenService:Create(pic, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = dehors }):Play()
		-- 2) il tient, puis 3) il S'EFFRITE : s'enfonce en s'effacant, eclats de glace
		TweenService:Create(pic, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.65),
			{ CFrame = cache, Transparency = 1 }):Play()
		local eclats = particules(pic, GIVRE_VIF, 0.45, 12, 0)
		eclats.Acceleration = Vector3.new(0, -30, 0)
		task.delay(0.65, function()
			eclats:Emit(6)
		end)
		Debris:AddItem(pic, 1.3)
	end
	-- givre au centre et lueur bleue : le cri part DU champion
	local hote = partTemporaire(parent, position, 1.2)
	local g = particules(hote, GIVRE_VIF, 0.9, 26, 60)
	g.Acceleration = Vector3.new(0, -6, 0)
	eclat(hote, GLACE_FORTE, rayon * 3, 0.45)
	return hote
end

function Effets.estGivre(corps)
	return corps ~= nil and corps:FindFirstChild(Effets.GIVRE_NOM) ~= nil
end

-- ===== POISON ET RALENTISSEMENT : LES STATUTS SE VOIENT AUSSI =====
-- Meme defaut que le gel, corrige le 2026-09-20 : les deux autres statuts ne se DESSINAIENT pas.
-- Une unite empoisonnee perdait des points de vie sans cause visible (le joueur croyait a un
-- tireur cache), et une unite ralentie avait l'air de MARCHER LENTEMENT, ce qui ressemble a un
-- defaut de reseau plutot qu'a une carte qui fait son travail.
--
-- Les trois marques suivent la meme mecanique que le givre : un enfant NOMME, pose a l'entree du
-- statut et retire quand il expire. On ne pose jamais de minuteur separe — sinon un second poison
-- lance pendant le premier effacerait la marque d'une unite encore empoisonnee.
Effets.POISON_COULEUR = Color3.new(150 / 255, 220 / 255, 90 / 255) -- vert acide
Effets.POISON_NOM = "Poison"
Effets.LENT_COULEUR = Color3.new(170 / 255, 225 / 255, 245 / 255)  -- bleu pale, plus clair que la glace
Effets.LENT_NOM = "Engourdi"

-- Marque commune : une bulle translucide autour du corps, dont on regle la couleur, l'opacite et
-- la taille. Le givre est la version dure ; ici, plus legere, pour qu'on voie encore le
-- personnage dessous — un poison qui cacherait l'unite empecherait de reconnaitre la carte.
local function marque(corps, nom, couleur, taille, opacite, grossissement, materiau)
	if not corps or corps:FindFirstChild(nom) then
		return nil
	end
	local t = taille or corps.Size
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	-- SmoothPlastic et non ForceField : le materiau d'energie rend un voile si pale que la
	-- bulle verte du poison etait INVISIBLE sur la capture du 2026-09-20.
	p.Material = materiau or Enum.Material.SmoothPlastic
	p.Color = couleur
	p.Transparency = opacite
	local d = math.max(t.X, t.Y, t.Z) * grossissement
	p.Size = Vector3.new(d, d, d)
	p:SetAttribute("Ecart", Vector3.new(0, 0, 0))
	p:SetAttribute("RotX", 0); p:SetAttribute("RotY", 0); p:SetAttribute("RotZ", 0)
	p.CFrame = corps.CFrame
	p.Parent = corps
	return p
end

-- POISON : bulle verte + gouttes qui RETOMBENT en continu (Rate, et non une salve : le poison
-- dure, il ne claque pas une fois).
function Effets.empoisonner(corps, taille)
	local p = marque(corps, Effets.POISON_NOM, Effets.POISON_COULEUR, taille, 0.45, 1.3)
	if not p then
		return nil
	end
	local gouttes = Instance.new("ParticleEmitter")
	gouttes.Color = degrade(Effets.POISON_COULEUR)
	gouttes.Size = courbeTaille(1.2)
	gouttes.Transparency = courbeOpacite()
	gouttes.Lifetime = NumberRange.new(0.5, 0.9)
	gouttes.Speed = NumberRange.new(0.5, 1.5)
	gouttes.SpreadAngle = Vector2.new(60, 60)
	gouttes.Acceleration = Vector3.new(0, -12, 0) -- ca degouline vers le sol
	gouttes.LightEmission = 0.5
	gouttes.LightInfluence = 0
	gouttes.Rate = 26
	gouttes.Parent = p
	return p
end

function Effets.depoisonner(corps)
	local p = corps and corps:FindFirstChild(Effets.POISON_NOM)
	if p then
		p:Destroy()
		return true
	end
	return false
end

function Effets.estEmpoisonne(corps)
	return corps ~= nil and corps:FindFirstChild(Effets.POISON_NOM) ~= nil
end

-- RALENTISSEMENT : un halo bleu pale, SANS gangue dure — la difference avec le gel doit se lire
-- d'un coup d'oeil, sinon les deux cartes de glace se confondent.
-- RALENTISSEMENT : une FLAQUE DE GIVRE aux pieds, et non une bulle. Sur la capture du
-- 2026-09-20, la bulle bleu pale se confondait avec la gangue de glace du gel : deux cartes
-- differentes, un seul visuel. Une marque AU SOL se distingue d'un coup d'oeil d'une gangue qui
-- enveloppe le corps, meme de loin et meme en petit a l'ecran.
function Effets.engourdir(corps, taille)
	if not corps or corps:FindFirstChild(Effets.LENT_NOM) then
		return nil
	end
	local t = taille or corps.Size
	-- 1,5 fois l'emprise au sol : a 2,1 la flaque debordait sur l'unite voisine et deux
	-- marques se chevauchaient (capture du 2026-09-20).
	local rayon = math.max(t.X, t.Z) * 1.5
	local flaque = Instance.new("Part")
	flaque.Name = Effets.LENT_NOM
	flaque.Anchored = true
	flaque.CanCollide = false
	flaque.CanQuery = false
	flaque.CastShadow = false
	flaque.Shape = Enum.PartType.Cylinder
	flaque.Material = Enum.Material.Ice
	flaque.Color = Effets.LENT_COULEUR
	flaque.Transparency = 0.25
	flaque.Size = Vector3.new(0.2, rayon, rayon)
	-- posee AU SOL sous le corps, couchee (comme le disque de camp) et suivie par les memes
	-- attributs d'ecart que les morceaux.
	local bas = -(t.Y / 2) + 0.12
	flaque:SetAttribute("Ecart", Vector3.new(0, bas, 0))
	flaque:SetAttribute("Sol", true)
	flaque:SetAttribute("RotX", 0); flaque:SetAttribute("RotY", 0); flaque:SetAttribute("RotZ", 90)
	flaque.CFrame = corps.CFrame * CFrame.new(0, bas, 0) * CFrame.Angles(0, 0, math.rad(90))
	flaque.Parent = corps
	local halo = Instance.new("PointLight")
	halo.Color = Effets.LENT_COULEUR
	halo.Range = rayon
	halo.Brightness = 1.1
	halo.Parent = flaque
	return flaque
end

function Effets.degourdir(corps)
	local p = corps and corps:FindFirstChild(Effets.LENT_NOM)
	if p then
		p:Destroy()
		return true
	end
	return false
end

function Effets.estEngourdi(corps)
	return corps ~= nil and corps:FindFirstChild(Effets.LENT_NOM) ~= nil
end

-- ===== BOUCLIER : UNE COQUE QUI MAIGRIT =====
-- Dernier statut muet, corrige le 2026-09-20 : le bouclier ne se signalait QU'A L'INSTANT OU IL
-- CASSAIT. Avant cela, rien ne distinguait une unite protegee d'une unite nue, et le joueur ne
-- pouvait pas decider s'il valait mieux depenser un sort maintenant ou attendre. Or c'est
-- exactement ce que le bouclier demande de decider.
--
-- Le rendu suit l'ETAT : la coque part epaisse et franche, puis s'amincit et s'efface a mesure
-- qu'elle encaisse. Les deux valeurs viennent du module pur Statuts (opaciteBouclier,
-- epaisseurBouclier), donc elles sont verifiables hors Studio et ne peuvent pas diverger de la
-- regle de jeu.
Effets.BOUCLIER_COULEUR = Color3.new(255 / 255, 225 / 255, 120 / 255) -- or pale
Effets.BOUCLIER_NOM = "Bouclier"

function Effets.blinder(corps, taille, opacite, marge)
	if not corps or corps:FindFirstChild(Effets.BOUCLIER_NOM) then
		return nil
	end
	local t = taille or corps.Size
	local coque = Instance.new("Part")
	coque.Name = Effets.BOUCLIER_NOM
	coque.Anchored = true
	coque.CanCollide = false
	coque.CanQuery = false
	coque.CastShadow = false
	coque.Shape = Enum.PartType.Ball
	coque.Material = Enum.Material.Glass
	coque.Color = Effets.BOUCLIER_COULEUR
	coque.Transparency = opacite or 0.35
	local d = math.max(t.X, t.Y, t.Z) * (marge or 1.45)
	coque.Size = Vector3.new(d, d, d)
	coque:SetAttribute("Ecart", Vector3.new(0, 0, 0))
	coque:SetAttribute("RotX", 0); coque:SetAttribute("RotY", 0); coque:SetAttribute("RotZ", 0)
	coque:SetAttribute("Base", math.max(t.X, t.Y, t.Z))
	coque.CFrame = corps.CFrame
	coque.Parent = corps
	return coque
end

-- MISE A JOUR apres chaque coup encaisse : la coque MAIGRIT et s'efface. C'est le seul endroit ou
-- son aspect change — on ne la reconstruit jamais, sinon elle clignoterait a chaque coup.
function Effets.majBouclier(corps, opacite, marge)
	local coque = corps and corps:FindFirstChild(Effets.BOUCLIER_NOM)
	if not coque then
		return false
	end
	coque.Transparency = opacite
	local base = coque:GetAttribute("Base") or coque.Size.X
	local d = base * marge
	coque.Size = Vector3.new(d, d, d)
	return true
end

-- RETIRE la coque : appele quand le bouclier tombe a zero (l'eclat de rupture, lui, est joue par
-- le serveur au meme instant).
function Effets.debloquer(corps)
	local coque = corps and corps:FindFirstChild(Effets.BOUCLIER_NOM)
	if coque then
		coque:Destroy()
		return true
	end
	return false
end

function Effets.aBouclier(corps)
	return corps ~= nil and corps:FindFirstChild(Effets.BOUCLIER_NOM) ~= nil
end

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
