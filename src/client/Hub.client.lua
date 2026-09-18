-- HUB : ecran d'accueil (profil, Jouer, Boutique, bonus du jour) et boutique de cartes.
-- Tout achat passe par la RemoteFunction « Boutique » : le serveur verifie prix et solde, le client
-- ne fait qu'afficher la reponse. Les offres Robux n'apparaissent que si le createur a renseigne
-- leurs identifiants (Economie.lua).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cards"))
-- Habillage sonore de l'accueil : clic, coffre ouvert, achat refuse.
local Sons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sons"))
local Boutique = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Boutique")
local player = Players.LocalPlayer

-- Copie de test : le hub reste ferme (la partie automatique doit se jouer), sauf build.py --hub.
local test = ReplicatedStorage:FindFirstChild("BRR_AUTOTEST")
local forcerHub = ReplicatedStorage:FindFirstChild("BRR_HUB")

local OR = Color3.fromRGB(255, 205, 60)
local FOND = Color3.fromRGB(22, 24, 38)

local gui = Instance.new("ScreenGui")
gui.Name = "Hub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function coin(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = o
end

local function texte(parent, t, taille, pos, couleur, alignement)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = taille
	l.Position = pos
	l.Text = t
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = couleur or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextXAlignment = alignement or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

local function bouton(parent, t, taille, pos, couleur)
	local b = Instance.new("TextButton")
	b.Size = taille
	b.Position = pos
	b.BackgroundColor3 = couleur
	b.Text = t
	b.TextScaled = true
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.3
	b.AutoButtonColor = true
	b.Parent = parent
	coin(b)
	-- REACTION AU DOIGT : un fondu court sur la transparence du fond. On n'anime PAS la taille :
	-- les boutons sont poses en echelle dans des mises en page, une taille animee les ferait
	-- bouger les uns par rapport aux autres.
	local function fondu(valeur, duree)
		TweenService:Create(b, TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = valeur }):Play()
	end
	b.MouseEnter:Connect(function() fondu(0.15, 0.15) end)
	b.MouseLeave:Connect(function() fondu(0, 0.2) end)
	b.MouseButton1Down:Connect(function() fondu(0.4, 0.08) end)
	b.MouseButton1Up:Connect(function() fondu(0.15, 0.18) end)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0); pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = b
	return b
end

-- ACCUEIL ---------------------------------------------------------------------------------------
local accueil = Instance.new("Frame")
accueil.Size = UDim2.fromScale(1, 1)
accueil.BackgroundColor3 = FOND
accueil.BackgroundTransparency = 0.15
accueil.Parent = gui

texte(accueil, "BRAINROT ROYALE", UDim2.new(0.8, 0, 0.12, 0), UDim2.new(0.1, 0, 0.08, 0), OR)
local ligneProfil = texte(accueil, "...", UDim2.new(0.8, 0, 0.06, 0), UDim2.new(0.1, 0, 0.22, 0))
local ligneInfo = texte(accueil, "", UDim2.new(0.8, 0, 0.035, 0), UDim2.new(0.1, 0, 0.29, 0), Color3.fromRGB(180, 190, 210))

local boutonJouer = bouton(accueil, "JOUER", UDim2.new(0.34, 0, 0.13, 0), UDim2.new(0.33, 0, 0.38, 0), Color3.fromRGB(60, 170, 80))
-- BOUTIQUE et DECK cote a cote sur la ligne du milieu (l'accueil garde la meme hauteur)
local boutonBoutique = bouton(accueil, "BOUTIQUE", UDim2.new(0.165, 0, 0.09, 0), UDim2.new(0.33, 0, 0.54, 0), Color3.fromRGB(70, 110, 220))
local boutonDeck = bouton(accueil, "DECK", UDim2.new(0.165, 0, 0.09, 0), UDim2.new(0.505, 0, 0.54, 0), Color3.fromRGB(140, 80, 200))
local boutonBonus = bouton(accueil, "BONUS DU JOUR", UDim2.new(0.34, 0, 0.07, 0), UDim2.new(0.33, 0, 0.66, 0), Color3.fromRGB(200, 120, 40))
local message = texte(accueil, "", UDim2.new(0.8, 0, 0.04, 0), UDim2.new(0.1, 0, 0.745, 0), OR)

-- COFFRES : 4 emplacements sous les boutons. Le serveur donne l'heure de fin ; le client ne fait
-- qu'afficher le compte a rebours, et c'est le serveur qui refuse une ouverture trop tot.
local COULEUR_COFFRE = { bois = Color3.fromRGB(140, 95, 55), argent = Color3.fromRGB(150, 160, 175), ["or"] = Color3.fromRGB(220, 170, 40) }
local NOM_COFFRE = { bois = "BOIS", argent = "ARGENT", ["or"] = "OR" }
local rangee = Instance.new("Frame")
rangee.BackgroundTransparency = 1
rangee.Size = UDim2.new(0.7, 0, 0.16, 0)
rangee.Position = UDim2.new(0.15, 0, 0.8, 0)
rangee.Parent = accueil
local rangeeLayout = Instance.new("UIListLayout")
rangeeLayout.FillDirection = Enum.FillDirection.Horizontal
rangeeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rangeeLayout.Padding = UDim.new(0.02, 0)
rangeeLayout.Parent = rangee
local emplacements = {}
local decalageHorloge = 0 -- os.time() serveur - os.time() client

-- bouton de retour au hub, pendant la partie
local boutonMenu = bouton(gui, "MENU", UDim2.new(0, 110, 0, 44), UDim2.new(0, 12, 0, 12), Color3.fromRGB(40, 45, 70))
boutonMenu.Visible = false

-- BOUTIQUE --------------------------------------------------------------------------------------
local boutique = Instance.new("Frame")
boutique.Size = UDim2.fromScale(0.86, 0.84)
boutique.Position = UDim2.fromScale(0.07, 0.08)
boutique.BackgroundColor3 = FOND
boutique.Visible = false
boutique.Parent = gui
coin(boutique, 18)

texte(boutique, "BOUTIQUE", UDim2.new(0.6, 0, 0.09, 0), UDim2.new(0.2, 0, 0.02, 0), OR)
local soldeBoutique = texte(boutique, "", UDim2.new(0.5, 0, 0.05, 0), UDim2.new(0.25, 0, 0.11, 0))
local fermer = bouton(boutique, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 12), Color3.fromRGB(170, 50, 50))

-- Grilles DEFILANTES (2026-09-16) : le catalogue a grossi a 15 cartes et la grille debordait
-- sous le bouton ENREGISTRER (vu sur capture-deck2.png). Une hauteur figee ne tient que pour un
-- nombre de cartes donne ; le defilement tient pour n'importe lequel.
-- Les cellules sont en Scale, donc mesurees sur la partie VISIBLE du cadre : le canevas vaut
-- (nombre de rangees x hauteur de rangee), ce qui depasse 1 des qu'il y a plus de rangees que
-- l'ecran n'en montre.
local COLONNES = 4
local function grilleDefilante(parent, taille, position, hauteurCellule, ecartVertical)
	local cadre = Instance.new("ScrollingFrame")
	cadre.BackgroundTransparency = 1
	cadre.BorderSizePixel = 0
	cadre.Size = taille
	cadre.Position = position
	cadre.ScrollBarThickness = 8
	cadre.ScrollBarImageColor3 = OR
	cadre.CanvasSize = UDim2.new()
	cadre.Parent = parent
	-- PIEGE mesure le 2026-09-16 : dans un ScrollingFrame, une taille en proportion se mesure sur
	-- le CANEVAS, pas sur la partie visible — les tuiles avaient double de taille. On divise donc
	-- par la hauteur du canevas pour que `hauteurCellule` reste une proportion de ce qu'on VOIT.
	local rangees = math.ceil(#Cards.list / COLONNES)
	local canevas = rangees * (hauteurCellule + ecartVertical)
	cadre.CanvasSize = UDim2.new(0, 0, canevas, 0)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.23, 0, hauteurCellule / canevas, 0)
	layout.CellPadding = UDim2.new(0.02, 0, ecartVertical / canevas, 0)
	layout.Parent = cadre
	return cadre
end

local grille = grilleDefilante(boutique, UDim2.new(0.94, 0, 0.62, 0), UDim2.new(0.03, 0, 0.18, 0), 0.44, 0.04)

local offresRobux = Instance.new("Frame")
offresRobux.BackgroundTransparency = 1
offresRobux.Size = UDim2.new(0.94, 0, 0.12, 0)
offresRobux.Position = UDim2.new(0.03, 0, 0.85, 0)
offresRobux.Parent = boutique
local layoutRobux = Instance.new("UIListLayout")
layoutRobux.FillDirection = Enum.FillDirection.Horizontal
layoutRobux.Padding = UDim.new(0.02, 0)
layoutRobux.Parent = offresRobux

local vue = nil
local majDeck -- ecran DECK, defini plus bas : afficher() le rafraichit s'il existe deja
local tuiles = {}

local function majCoffres()
	if not vue then
		return
	end
	local maintenant = os.time() + decalageHorloge
	for i = 1, 4 do
		local e = emplacements[i]
		local c = vue.coffres[i]
		if not c then
			e.cadre.BackgroundColor3 = Color3.fromRGB(40, 42, 60)
			e.titre.Text = "vide"
			e.etat.Text = "Gagne une partie"
			e.etat.BackgroundTransparency = 1
		else
			e.cadre.BackgroundColor3 = COULEUR_COFFRE[c.type]
			e.titre.Text = NOM_COFFRE[c.type]
			e.etat.BackgroundTransparency = 0.2
			if c.fin == 0 then
				e.etat.Text = "DEMARRER"
			elseif c.fin > maintenant then
				local r = c.fin - maintenant
				e.etat.Text = r >= 3600 and string.format("%dh%02d", r // 3600, (r % 3600) // 60)
					or string.format("%d:%02d", r // 60, r % 60)
			else
				e.etat.Text = "OUVRIR !"
			end
		end
	end
end

local function afficher(v)
	if not v then
		return
	end
	vue = v
	ligneProfil.Text = string.format("%d pieces   |   %d trophees", v.pieces, v.trophees)
	ligneInfo.Text = string.format("%d victoires sur %d parties%s", v.victoires, v.parties,
		v.sauvegarde and "" or "   (progression non sauvegardee dans Studio)")
	boutonBonus.Text = v.bonusDispo and "BONUS DU JOUR : +50" or "BONUS DEJA PRIS"
	boutonBonus.BackgroundColor3 = v.bonusDispo and Color3.fromRGB(200, 120, 40) or Color3.fromRGB(80, 80, 90)
	soldeBoutique.Text = v.pieces .. " pieces"
	if v.maintenant then
		decalageHorloge = v.maintenant - os.time()
	end
	majCoffres()
	if majDeck then
		majDeck()
	end
	for id, t in pairs(tuiles) do
		local card = Cards.byId[id]
		if v.cartes[id] then
			-- NIVEAU : exemplaires possedes / requis, et bouton AMELIORER si possible
			local n = (v.niveaux and v.niveaux[id]) or 1
			local ex = (v.exemplaires and v.exemplaires[id]) or 0
			t.niveau.Text = "Niv. " .. n
			t.niveau.Visible = true
			if n >= v.niveauMax then
				t.etat.Text = "NIVEAU MAX"
				t.action.Visible = false
			else
				local besoin, cout = v.besoinExemplaires[n], v.coutNiveau[n]
				t.etat.Text = ex .. "/" .. besoin .. " exemplaires"
				t.action.Visible = true
				t.action.Text = "AMELIORER " .. cout
				local possible = ex >= besoin and v.pieces >= cout
				t.action.BackgroundColor3 = possible and Color3.fromRGB(230, 150, 30) or Color3.fromRGB(90, 90, 100)
			end
		else
			t.niveau.Visible = false
			t.action.Text = "ACHETER"
			t.etat.Text = card.prix .. " pieces"
			t.action.Visible = true
			t.action.BackgroundColor3 = v.pieces >= card.prix and Color3.fromRGB(60, 170, 80) or Color3.fromRGB(90, 90, 100)
		end
	end
	for _, c in ipairs(offresRobux:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for _, offre in ipairs(v.offresRobux) do
		local b = bouton(offresRobux, offre.nom .. " (Robux)", UDim2.new(0.32, 0, 1, 0), UDim2.new(), Color3.fromRGB(0, 160, 90))
		b.MouseButton1Click:Connect(function()
			afficher(Boutique:InvokeServer("robux", offre.index).vue)
		end)
	end
end

for _, card in ipairs(Cards.list) do
	local tuile = Instance.new("Frame")
	tuile.BackgroundColor3 = card.color
	tuile.Parent = grille
	coin(tuile)
	texte(tuile, card.name, UDim2.new(0.9, 0, 0.34, 0), UDim2.new(0.05, 0, 0.05, 0))
	-- elixir a gauche, niveau a droite : sur toute la largeur, les deux textes se chevauchaient (capture 2026-09-14)
	texte(tuile, card.cost .. " elixir", UDim2.new(0.52, 0, 0.13, 0), UDim2.new(0.06, 0, 0.42, 0), Color3.fromRGB(230, 210, 255))
	local etat = texte(tuile, "", UDim2.new(0.9, 0, 0.14, 0), UDim2.new(0.05, 0, 0.58, 0), OR)
	local action = bouton(tuile, "ACHETER", UDim2.new(0.8, 0, 0.2, 0), UDim2.new(0.1, 0, 0.76, 0), Color3.fromRGB(60, 170, 80))
	local niveau = texte(tuile, "", UDim2.new(0.32, 0, 0.13, 0), UDim2.new(0.62, 0, 0.42, 0), Color3.fromRGB(255, 255, 255))
	niveau.Visible = false
	action.MouseButton1Click:Connect(function()
		local debloquee = vue and vue.cartes[card.id]
		local r = Boutique:InvokeServer(debloquee and "ameliorer" or "acheter", card.id)
		afficher(r.vue)
		if r.ok then
			Sons.jouer("coffre", 0.8) -- meme sensation de gain qu'une ouverture de coffre
			soldeBoutique.Text = debloquee and (card.name .. " : niveau " .. (r.vue.niveaux[card.id] or 1)) or ("Debloquee : " .. card.name)
		else
			Sons.jouer("refus")
			soldeBoutique.Text = "Impossible : " .. tostring(r.motif)
		end
		task.delay(1.5, function() afficher(vue) end)
	end)
	tuiles[card.id] = { etat = etat, action = action, niveau = niveau }
end

-- DECK ------------------------------------------------------------------------------------------
-- Le joueur choisit les cartes qu'il emporte. Le client ne fait que PROPOSER : c'est
-- Economie.choisirDeck (serveur) qui verifie que chaque carte est bien possedee, et qui
-- enregistre. Tant que le joueur possede moins de cartes qu'il n'y a de places, aucun choix
-- n'existe : l'ecran le dit et le bouton reste inactif.
local deckEcran = Instance.new("Frame")
deckEcran.Size = UDim2.fromScale(0.86, 0.84)
deckEcran.Position = UDim2.fromScale(0.07, 0.08)
deckEcran.BackgroundColor3 = FOND
deckEcran.Visible = false
deckEcran.Parent = gui
coin(deckEcran, 18)

texte(deckEcran, "MON DECK", UDim2.new(0.6, 0, 0.09, 0), UDim2.new(0.2, 0, 0.02, 0), OR)
local deckCompteur = texte(deckEcran, "", UDim2.new(0.5, 0, 0.05, 0), UDim2.new(0.25, 0, 0.11, 0))
local deckFermer = bouton(deckEcran, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 12), Color3.fromRGB(170, 50, 50))
local deckValider = bouton(deckEcran, "ENREGISTRER", UDim2.new(0.36, 0, 0.09, 0), UDim2.new(0.32, 0, 0.87, 0), Color3.fromRGB(60, 170, 80))

-- 0.66 de haut s'arrete juste au-dessus du bouton ENREGISTRER (place a 0.87) : la grille ne peut
-- plus passer dessous, elle defile.
local deckGrille = grilleDefilante(deckEcran, UDim2.new(0.94, 0, 0.66, 0), UDim2.new(0.03, 0, 0.18, 0), 0.3, 0.03)

local choix = {}      -- id -> true : carte selectionnee dans l'ecran
local nbChoix = 0
local tuilesDeck = {}

local function basculer(id)
	if choix[id] then
		choix[id] = nil
		nbChoix -= 1
	elseif nbChoix < (vue and vue.deckTaille or 8) then
		choix[id] = true
		nbChoix += 1
	end
	majDeck()
end

for _, card in ipairs(Cards.list) do
	local tuile = Instance.new("TextButton")
	tuile.BackgroundColor3 = card.color
	tuile.Text = ""
	tuile.AutoButtonColor = true
	tuile.Parent = deckGrille
	coin(tuile)
	local bord = Instance.new("UIStroke")
	bord.Thickness = 4
	bord.Color = OR
	bord.Transparency = 1
	bord.Parent = tuile
	texte(tuile, card.name, UDim2.new(0.9, 0, 0.4, 0), UDim2.new(0.05, 0, 0.06, 0))
	texte(tuile, card.cost .. " elixir", UDim2.new(0.9, 0, 0.18, 0), UDim2.new(0.05, 0, 0.5, 0), Color3.fromRGB(230, 210, 255))
	local etatDeck = texte(tuile, "", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.72, 0), OR)
	tuile.MouseButton1Click:Connect(function()
		if vue and vue.cartes[card.id] then
			basculer(card.id)
		end
	end)
	tuilesDeck[card.id] = { tuile = tuile, bord = bord, etat = etatDeck }
end

-- definit la variable declaree plus haut (afficher l'appelle)
majDeck = function()
	if not vue or not deckEcran.Visible then
		return
	end
	local taille = vue.deckTaille or 8
	local possedees = 0
	for _, card in ipairs(Cards.list) do
		local t = tuilesDeck[card.id]
		local possede = vue.cartes[card.id] == true
		if possede then
			possedees += 1
		end
		t.tuile.BackgroundTransparency = possede and 0 or 0.65
		t.bord.Transparency = choix[card.id] and 0 or 1
		t.etat.Text = possede and (choix[card.id] and "DANS LE DECK" or "") or "verrouillee"
	end
	if possedees < taille then
		deckCompteur.Text = possedees .. " cartes sur " .. taille .. " : debloque-en pour choisir"
		deckValider.Text = "PAS ASSEZ DE CARTES"
		deckValider.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	else
		deckCompteur.Text = nbChoix .. " / " .. taille .. " cartes choisies"
		deckValider.Text = "ENREGISTRER"
		deckValider.BackgroundColor3 = nbChoix == taille and Color3.fromRGB(60, 170, 80) or Color3.fromRGB(90, 90, 100)
	end
end

-- selection de depart = le deck effectivement emporte, tel que le serveur le voit
local function chargerChoix()
	choix, nbChoix = {}, 0
	local taille = (vue and vue.deckTaille) or 8
	for _, id in ipairs((vue and vue.deck) or {}) do
		if nbChoix < taille then
			choix[id] = true
			nbChoix += 1
		end
	end
end

deckValider.MouseButton1Click:Connect(function()
	local taille = (vue and vue.deckTaille) or 8
	if nbChoix ~= taille then
		deckCompteur.Text = "choisis " .. taille .. " cartes (" .. nbChoix .. " pour l'instant)"
		return
	end
	local liste = {}
	for _, card in ipairs(Cards.list) do
		if choix[card.id] then
			table.insert(liste, card.id)
		end
	end
	local r = Boutique:InvokeServer("deck", liste)
	afficher(r.vue)
	if r.ok then
		chargerChoix()
		majDeck()
		deckCompteur.Text = "deck enregistre !"
	else
		deckCompteur.Text = "Refuse : " .. tostring(r.motif)
	end
end)

deckFermer.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	deckEcran.Visible = false
	accueil.Visible = true
end)

for i = 1, 4 do
	local cadre = Instance.new("Frame")
	cadre.Size = UDim2.new(0.23, 0, 1, 0)
	cadre.Parent = rangee
	coin(cadre)
	local titre = texte(cadre, "vide", UDim2.new(0.9, 0, 0.36, 0), UDim2.new(0.05, 0, 0.06, 0))
	local etat = bouton(cadre, "", UDim2.new(0.9, 0, 0.44, 0), UDim2.new(0.05, 0, 0.5, 0), Color3.fromRGB(25, 25, 35))
	etat.MouseButton1Click:Connect(function()
		local c = vue and vue.coffres[i]
		if not c then
			return
		end
		local action = c.fin == 0 and "demarrerCoffre" or "ouvrirCoffre"
		local r = Boutique:InvokeServer(action, i)
		if r.gain then
			Sons.jouer("coffre")
			message.Text = "+" .. r.gain.pieces .. " pieces  +  " .. r.gain.exemplaires .. " x " .. Cards.byId[r.gain.exemplaireCarte].name
				.. (r.gain.carte and ("  +  carte " .. Cards.byId[r.gain.carte].name .. " !") or "")
		elseif not r.ok then
			Sons.jouer("refus")
			message.Text = "Coffre : " .. tostring(r.motif)
		end
		afficher(r.vue)
	end)
	emplacements[i] = { cadre = cadre, titre = titre, etat = etat }
end
task.spawn(function()
	while true do
		task.wait(1)
		if accueil.Visible then
			majCoffres()
		end
	end
end)

-- OUVERTURE ANIMEE D'UN PANNEAU : il arrive en glissant depuis le bas sur 0,2 s. On anime la
-- POSITION et pas la transparence : dans Roblox, un fondu sur un cadre ne touche pas ses enfants,
-- le texte resterait net sur un fond qui s'efface. `Visible` est mis tout de suite, pour que les
-- sondes de test qui le lisent voient l'etat reel sans attendre la fin de l'animation.
local function ouvrirPanneau(p)
	local finale = p.Position
	p.Position = finale + UDim2.new(0, 0, 0.05, 0)
	p.Visible = true
	TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = finale }):Play()
end

-- NAVIGATION ------------------------------------------------------------------------------------
local function ouvrirAccueil()
	Sons.boucle("hub")
	accueil.Visible = true
	boutique.Visible = false
	deckEcran.Visible = false
	boutonMenu.Visible = false
	afficher(Boutique:InvokeServer("profil").vue)
end

boutonJouer.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local r = Boutique:InvokeServer("jouer")
	Sons.boucle("combat")
	if r.ok then
		accueil.Visible = false
		boutonMenu.Visible = true
	else
		message.Text = "Les deux camps sont pris : tu regardes la partie"
		accueil.Visible = false
		boutonMenu.Visible = true
	end
end)
boutonDeck.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	-- L'accueil passe DERRIERE : sans cela, sa rangee de coffres (« Gagne une partie ») depasse
	-- sous le panneau et son texte est rogne (vu sur capture-hub.png, 2026-09-16).
	accueil.Visible = false
	ouvrirPanneau(deckEcran)
	afficher(Boutique:InvokeServer("profil").vue)
	chargerChoix()
	majDeck()
end)
boutonBoutique.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	accueil.Visible = false
	ouvrirPanneau(boutique)
	afficher(Boutique:InvokeServer("profil").vue)
end)
fermer.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	boutique.Visible = false
	accueil.Visible = true
end)
boutonMenu.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	Boutique:InvokeServer("quitter")
	ouvrirAccueil()
end)
boutonBonus.MouseButton1Click:Connect(function()
	local r = Boutique:InvokeServer("bonus")
	Sons.jouer(r.ok and "coffre" or "refus")
	message.Text = r.ok and "+50 pieces !" or ("Bonus : " .. tostring(r.motif))
	afficher(r.vue)
end)

-- le solde affiche suit les recompenses de fin de partie
local ls = player:WaitForChild("leaderstats", 30)
if ls then
	for _, v in ipairs(ls:GetChildren()) do
		v.Changed:Connect(function()
			if accueil.Visible or boutique.Visible or deckEcran.Visible then
				afficher(Boutique:InvokeServer("profil").vue)
			end
		end)
	end
end

if test and not forcerHub then
	accueil.Visible = false
	boutonMenu.Visible = true
	print("[HUB] copie de test : hub ferme")
else
	ouvrirAccueil()
	if ReplicatedStorage:FindFirstChild("BRR_BOUTIQUE") then
		accueil.Visible = false
		boutique.Visible = true
	end
	if ReplicatedStorage:FindFirstChild("BRR_DECK") then
		-- meme chemin que le bouton DECK, pour que la capture montre l'ecran REEL
		accueil.Visible = false
		deckEcran.Visible = true
		chargerChoix()
		majDeck()
	end
	print("[HUB] accueil ouvert")
end
