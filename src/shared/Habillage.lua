-- HABILLAGE DU MENU (2026-09-29) : ce que les interfaces Roblox les plus citees ont, et que le
-- menu n'avait pas. References etudiees : Clash Royale (le modele du jeu), Pet Simulator 99,
-- Pls Donate et Sol's RNG (citees sur le forum des developpeurs Roblox comme references).
--
--  1. BARRE D'ONGLETS A ICONES. L'onglet actif s'elargit, son icone monte et lui seul porte son
--     nom ; les autres ne montrent que leur icone. Mesure avant (captures/boutique-offres.png,
--     portrait 592 px de large) : « BOUTIQUE » touchait les bords de son onglet et « EVENEMENTS »
--     etait coupe, a moitie cache par la pastille. Une icone tient dans n'importe quelle largeur.
--  2. BOUTON A LEVRE : le bas de chaque bouton est une bande plus sombre (le relief des jeux
--     mobiles) et le texte s'enfonce quand on appuie.
--  3. JOUER VIVANT : un reflet balaie le bouton et un halo dore respire autour.
--  4. GLISSEMENT ENTRE ONGLETS, dans le sens de l'onglet choisi, comme dans Clash Royale.
--  5. SOLDES QUI DEFILENT jusqu'a leur nouvelle valeur, et un « + » qui mene a la boutique.
--
-- Les icones sont DESSINEES avec des cadres : aucun asset a televerser, comme le reste du jeu.
-- Le haut du fichier (largeurs, levre, icones, defilement) est de la DONNEE PURE : il se charge
-- hors de Roblox et tools/test_habillage.py le verifie. Les services Roblox ne sont demandes
-- qu'a l'usage, dans les fonctions qui construisent l'ecran.
local Habillage = {}

-- 1. LARGEURS DE LA BARRE ---------------------------------------------------------------------
-- L'onglet actif prend 0,28 de la largeur, les autres se partagent le reste : 0,18 chacun pour
-- cinq onglets. La somme fait toujours 1, sinon la barre deborde ou laisse un trou.
Habillage.LARGEUR_ACTIF = 0.28

function Habillage.largeurs(n, iActif)
	local t = {}
	local repos = (1 - Habillage.LARGEUR_ACTIF) / (n - 1)
	for i = 1, n do
		t[i] = (i == iActif) and Habillage.LARGEUR_ACTIF or repos
	end
	return t
end

-- 2. LEVRE DES BOUTONS --------------------------------------------------------------------------
-- Facteurs de gris multiplies a la couleur du bouton, de haut (0) en bas (1). Le saut net a 0,83
-- dessine la levre : une bande plus sombre, comme l'epaisseur d'un bouton en relief. Le texte du
-- bouton vit entre 0,18 et 0,82 (sa marge interne) : au repos il reste au-dessus de la levre, et
-- a l'appui il y descend — c'est l'enfoncement.
Habillage.LEVRE = {
	{ 0.00, 1.00 },
	{ 0.50, 0.90 },
	{ 0.82, 0.78 },
	{ 0.83, 0.55 },
	{ 1.00, 0.48 },
}
-- Enfoncement du texte a l'appui (marge haute / basse, en part de la hauteur).
Habillage.MARGE_REPOS = { 0.18, 0.18 }
Habillage.MARGE_APPUI = { 0.25, 0.11 }

-- 3. ICONES --------------------------------------------------------------------------------------
-- Chaque forme : centre (x, y), largeur l, hauteur h — en part d'un carre de 1 —, rotation en
-- degres, arrondi (0 = angle vif, 0,5 = rond) et teinte : base, clair, sombre, blanc, or.
-- `anneau` = epaisseur d'un cercle vide (trait seul), en pixels.
-- Les epees se croisent au centre : une lame de 0,72 tournee de 45 degres a ses bouts a
-- +/-0,2546 du centre sur chaque axe ; la garde est aux 3/5 vers la poignee.
local function f(x, y, l, h, rot, arrondi, teinte, anneau)
	return { x = x, y = y, l = l, h = h, rot = rot or 0, arrondi = arrondi or 0, teinte = teinte, anneau = anneau }
end
Habillage.ICONES = {
	-- un sac de boutique, son anse et une piece
	boutique = {
		f(0.50, 0.33, 0.34, 0.34, 0, 0.5, "sombre", 4),
		f(0.50, 0.62, 0.66, 0.52, 0, 0.22, "base"),
		f(0.50, 0.44, 0.66, 0.10, 0, 0.3, "clair"),
		f(0.50, 0.66, 0.26, 0.26, 0, 0.5, "or"),
	},
	-- deux cartes en eventail, un embleme sur celle de devant
	cartes = {
		f(0.40, 0.52, 0.42, 0.62, -14, 0.14, "clair"),
		f(0.60, 0.50, 0.42, 0.62, 10, 0.14, "base"),
		f(0.60, 0.50, 0.18, 0.18, 10, 0.5, "blanc"),
	},
	-- deux epees croisees
	bataille = {
		f(0.50, 0.46, 0.11, 0.72, 45, 0.4, "blanc"),
		f(0.50, 0.46, 0.11, 0.72, -45, 0.4, "blanc"),
		f(0.347, 0.613, 0.30, 0.085, -45, 0.4, "or"),
		f(0.653, 0.613, 0.30, 0.085, 45, 0.4, "or"),
		f(0.245, 0.715, 0.13, 0.13, 0, 0.5, "sombre"),
		f(0.755, 0.715, 0.13, 0.13, 0, 0.5, "sombre"),
	},
	-- un blason : corps arrondi, pointe en bas, embleme
	clan = {
		f(0.50, 0.40, 0.62, 0.46, 0, 0.18, "base"),
		f(0.50, 0.58, 0.44, 0.44, 45, 0.12, "base"),
		f(0.50, 0.47, 0.22, 0.22, 45, 0.15, "or"),
	},
	-- un cadeau : boite, couvercle, ruban, noeud
	evenements = {
		f(0.40, 0.25, 0.20, 0.15, -28, 0.45, "or"),
		f(0.60, 0.25, 0.20, 0.15, 28, 0.45, "or"),
		f(0.50, 0.64, 0.62, 0.44, 0, 0.12, "base"),
		f(0.50, 0.42, 0.74, 0.17, 0, 0.14, "clair"),
		f(0.50, 0.58, 0.12, 0.54, 0, 0, "or"),
	},
}

-- Teinte d'une forme a partir de la couleur de l'onglet, en composantes 0-1 (pur : aucun Color3).
function Habillage.teinte(r, g, b, nom)
	local function vers(c, cible, k)
		return c + (cible - c) * k
	end
	if nom == "clair" then
		return vers(r, 1, 0.45), vers(g, 1, 0.45), vers(b, 1, 0.45)
	elseif nom == "sombre" then
		return r * 0.55, g * 0.55, b * 0.55
	elseif nom == "blanc" then
		return 0.94, 0.95, 0.98
	elseif nom == "or" then
		return 1, 0.80, 0.24
	end
	return r, g, b
end

-- 5. DEFILEMENT DES SOLDES ----------------------------------------------------------------------
-- Valeur affichee a l'instant t (0 a 1) d'un defilement de `avant` a `apres` : rapide au debut,
-- doux a l'arrivee, et EXACTEMENT `apres` a la fin (un solde faux d'une piece serait un mensonge).
function Habillage.intermediaire(avant, apres, t)
	if t >= 1 then
		return apres
	end
	if t <= 0 then
		return avant
	end
	local e = 1 - (1 - t) ^ 3
	return math.floor(avant + (apres - avant) * e + 0.5)
end
Habillage.DUREE_DEFILEMENT = 0.6

-- ================================================================================================
-- CONSTRUCTION DANS ROBLOX (services demandes a l'usage : le haut du fichier reste pur).
-- ================================================================================================
local function jouer(objet, duree, proprietes, style)
	local info = TweenInfo.new(duree, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = game:GetService("TweenService"):Create(objet, info, proprietes)
	t:Play()
	return t
end

-- Couleur du contour, demandee a l'usage : Color3 n'existe pas hors de Roblox (banc Python).
local function contourSombre()
	return Color3.fromRGB(12, 14, 24)
end
local EPAISSEUR = 2 -- contour sombre commun autour de l'icone, en pixels

-- Levre + enfoncement : appele par la fabrique `bouton` du menu, pour TOUS les boutons.
function Habillage.levre(b, marge)
	local points = {}
	for _, p in ipairs(Habillage.LEVRE) do
		points[#points + 1] = ColorSequenceKeypoint.new(p[1], Color3.new(p[2], p[2], p[2]))
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(points)
	g.Rotation = 90
	g.Parent = b
	if marge then
		-- La marge est cherchee AU MOMENT de l'appui : un onglet a icone retire la sienne.
		local function poser(m, duree)
			if marge.Parent ~= b then
				return
			end
			jouer(marge, duree, { PaddingTop = UDim.new(m[1], 0), PaddingBottom = UDim.new(m[2], 0) })
		end
		b.MouseButton1Down:Connect(function()
			poser(Habillage.MARGE_APPUI, 0.06)
		end)
		b.MouseButton1Up:Connect(function()
			poser(Habillage.MARGE_REPOS, 0.14)
		end)
		b.MouseLeave:Connect(function()
			poser(Habillage.MARGE_REPOS, 0.14)
		end)
	end
	return g
end

-- Icone dessinee dans `parent`. Deux passes : d'abord la silhouette sombre elargie de toutes les
-- formes (un seul contour autour de l'icone entiere, comme un autocollant), puis les formes en
-- couleur par-dessus. Un contour par forme dessinait des traits au milieu du blason et du sac.
-- `zBase` : ZIndex des formes. Le menu ne fixe pas ZIndexBehavior : en mode Global, des formes a
-- ZIndex 1 passeraient SOUS le fond de l'onglet (ZIndex 6). On les pose donc au-dessus de lui.
function Habillage.icone(parent, nom, couleur, zBase)
	zBase = zBase or 1
	local groupe = Instance.new("CanvasGroup")
	groupe.ZIndex = zBase
	groupe.Name = "Icone"
	groupe.BackgroundTransparency = 1
	groupe.AnchorPoint = Vector2.new(0.5, 0.5)
	groupe.SizeConstraint = Enum.SizeConstraint.RelativeYY
	groupe.Parent = parent
	for passe = 1, 2 do
		for _, forme in ipairs(Habillage.ICONES[nom] or {}) do
			local cadre = Instance.new("Frame")
			cadre.AnchorPoint = Vector2.new(0.5, 0.5)
			cadre.Position = UDim2.fromScale(forme.x, forme.y)
			local e = (passe == 1 and not forme.anneau) and 2 * EPAISSEUR or 0
			cadre.Size = UDim2.new(forme.l, e, forme.h, e)
			cadre.Rotation = forme.rot
			cadre.BorderSizePixel = 0
			cadre.ZIndex = zBase + passe - 1
			local r, g, b = Habillage.teinte(couleur.R, couleur.G, couleur.B, forme.teinte)
			local teinte = passe == 1 and contourSombre() or Color3.new(r, g, b)
			if forme.anneau then
				cadre.BackgroundTransparency = 1
				local trait = Instance.new("UIStroke")
				trait.Thickness = forme.anneau + (passe == 1 and 2 * EPAISSEUR or 0)
				trait.Color = teinte
				trait.Parent = cadre
			else
				cadre.BackgroundColor3 = teinte
			end
			if forme.arrondi > 0 then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(forme.arrondi, 0)
				c.Parent = cadre
			end
			cadre.Parent = groupe
		end
	end
	return groupe
end

-- Pose d'une icone (repos / actif) : l'icone active grossit et MONTE, jusqu'a deborder du haut de
-- la barre — le geste de Clash Royale qui dit « tu es ici » sans lire.
-- En part de la hauteur de l'onglet. Actif : les formes occupent 0,08-0,67, le nom 0,71-0,97.
local POSE = {
	repos = { y = 0.46, taille = 0.62, transparence = 0.2, gris = 0.62 },
	actif = { y = 0.36, taille = 0.80, transparence = 0, gris = 1 },
}
Habillage.POSE = POSE

-- Transforme un bouton d'onglet deja construit : son titre passe dans une etiquette sous l'icone.
function Habillage.equiperOnglet(o)
	local b = o.bouton
	b.Text = ""
	b.ClipsDescendants = false
	-- Les marges internes ne servaient qu'au titre, qui quitte le bouton : sans elles, l'icone et
	-- son nom se placent sur la hauteur ENTIERE de l'onglet (deux marges s'y superposaient).
	for _, enfant in ipairs(b:GetChildren()) do
		if enfant:IsA("UIPadding") or enfant:IsA("UITextSizeConstraint") then
			enfant:Destroy()
		end
	end
	o.icone = Habillage.icone(b, o.nom, o.teinte, b.ZIndex + 1)
	local p = POSE.repos
	o.icone.Position = UDim2.fromScale(0.5, p.y)
	o.icone.Size = UDim2.fromScale(p.taille, p.taille)
	o.icone.GroupTransparency = p.transparence
	o.icone.GroupColor3 = Color3.new(p.gris, p.gris, p.gris)
	local nom = Instance.new("TextLabel")
	nom.Name = "Nom"
	nom.BackgroundTransparency = 1
	nom.AnchorPoint = Vector2.new(0.5, 1)
	nom.Position = UDim2.new(0.5, 0, 1, -3)
	nom.Size = UDim2.new(1, -8, 0.26, 0)
	nom.Font = Enum.Font.GothamBlack
	nom.Text = o.titre
	nom.TextScaled = true
	nom.TextColor3 = Color3.new(1, 1, 1)
	nom.ZIndex = b.ZIndex + 3
	nom.Visible = false
	nom.Parent = b
	local plafond = Instance.new("UITextSizeConstraint")
	plafond.MaxTextSize = 17
	plafond.Parent = nom
	local trait = Instance.new("UIStroke")
	trait.Thickness = 2
	trait.Color = contourSombre()
	trait.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	trait.Parent = nom
	o.etiquette = nom
end

-- Etat d'un onglet : largeur, pose de l'icone, nom visible ou non. `instantane` au premier
-- affichage (pas d'animation depuis une position arbitraire).
function Habillage.majOnglet(o, actif, largeur, instantane)
	local p = actif and POSE.actif or POSE.repos
	local cible = {
		taille = UDim2.new(largeur, 0, 1, 0),
		pos = UDim2.fromScale(0.5, p.y),
		icone = UDim2.fromScale(p.taille, p.taille),
	}
	o.etiquette.Visible = actif
	o.icone.GroupColor3 = Color3.new(p.gris, p.gris, p.gris)
	if instantane then
		o.bouton.Size = cible.taille
		o.icone.Position = cible.pos
		o.icone.Size = cible.icone
		o.icone.GroupTransparency = p.transparence
		return
	end
	jouer(o.bouton, 0.18, { Size = cible.taille })
	jouer(o.icone, 0.22, { Position = cible.pos, Size = cible.icone, GroupTransparency = p.transparence },
		actif and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
end

-- Glissement d'un ecran qui apparait : il arrive du cote de l'onglet choisi (sens = -1 ou 1).
function Habillage.glisser(cadre, cible, sens)
	if not sens or sens == 0 then
		cadre.Position = cible
		return
	end
	cadre.Position = cible + UDim2.fromScale(0.06 * sens, 0)
	jouer(cadre, 0.2, { Position = cible })
end

-- JOUER VIVANT : un reflet qui balaie le bouton toutes les 3 s, et un halo dore qui respire.
-- Les deux sont des ENFANTS du bouton : ils disparaissent avec lui pendant la recherche.
function Habillage.vivant(b)
	local reflet = Instance.new("Frame")
	reflet.Name = "Reflet"
	reflet.Size = UDim2.fromScale(1, 1)
	reflet.BackgroundColor3 = Color3.new(1, 1, 1)
	reflet.BorderSizePixel = 0
	reflet.ZIndex = b.ZIndex
	reflet.Parent = b
	local coinReflet = Instance.new("UICorner")
	coinReflet.CornerRadius = UDim.new(0, 14)
	coinReflet.Parent = reflet
	local bande = Instance.new("UIGradient")
	bande.Rotation = 20
	bande.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	bande.Offset = Vector2.new(-1, 0)
	bande.Parent = reflet

	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.BackgroundTransparency = 1
	halo.Size = UDim2.new(1, 10, 1, 10)
	halo.Position = UDim2.new(0, -5, 0, -5)
	halo.ZIndex = b.ZIndex
	halo.Parent = b
	local coinHalo = Instance.new("UICorner")
	coinHalo.CornerRadius = UDim.new(0, 18)
	coinHalo.Parent = halo
	local trait = Instance.new("UIStroke")
	trait.Color = Color3.fromRGB(255, 214, 90)
	trait.Thickness = 3
	trait.Transparency = 0.7
	trait.Parent = halo
	-- respiration : aller-retour sans fin, pose une fois (TweenInfo repete, pas de boucle Lua)
	game:GetService("TweenService"):Create(trait,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.1, Thickness = 5 }):Play()

	task.spawn(function()
		while b.Parent do
			if b.Visible then
				bande.Offset = Vector2.new(-1, 0)
				jouer(bande, 0.8, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			end
			task.wait(3)
		end
	end)
	return reflet, halo
end

-- Solde qui defile de l'ancienne valeur a la nouvelle, et un eclat dore quand il MONTE.
-- Appele APRES l'ecriture directe du texte : sans defilement possible (premier affichage), le
-- texte exact est deja en place.
function Habillage.compter(label, valeur)
	valeur = tonumber(valeur) or 0
	local avant = label:GetAttribute("BRR_valeur")
	label:SetAttribute("BRR_valeur", valeur)
	if avant == nil or avant == valeur then
		return
	end
	local jeton = (label:GetAttribute("BRR_defile") or 0) + 1
	label:SetAttribute("BRR_defile", jeton)
	if valeur > avant then
		label.TextColor3 = Color3.fromRGB(255, 226, 110)
		jouer(label, 0.9, { TextColor3 = Color3.new(1, 1, 1) })
	end
	local debut = os.clock()
	task.spawn(function()
		while label:GetAttribute("BRR_defile") == jeton do
			local t = (os.clock() - debut) / Habillage.DUREE_DEFILEMENT
			label.Text = tostring(Habillage.intermediaire(avant, valeur, t))
			if t >= 1 then
				return
			end
			task.wait()
		end
	end)
end

-- « + » a droite d'un jeton de solde : mene a la boutique (convention de Clash Royale et de Pet
-- Simulator 99). La valeur du jeton se resserre pour lui laisser la place.
function Habillage.plus(jetons, auClic)
	for _, val in ipairs(jetons) do
		local pilule = val.Parent
		local b = Instance.new("TextButton")
		b.Name = "Plus"
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -5, 0.5, 0)
		b.Size = UDim2.fromOffset(22, 22)
		b.BackgroundColor3 = Color3.fromRGB(70, 200, 90)
		b.Text = "+"
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.ZIndex = val.ZIndex + 3
		b.Parent = pilule
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
		local trait = Instance.new("UIStroke")
		trait.Thickness = 2
		trait.Color = contourSombre()
		trait.Parent = b
		val.Size = val.Size - UDim2.fromOffset(26, 0)
		b.MouseButton1Click:Connect(auClic)
	end
end

return Habillage
