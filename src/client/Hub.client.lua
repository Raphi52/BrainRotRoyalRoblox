-- HUB : ecran d'accueil (profil, Jouer, Boutique, bonus du jour) et boutique de cartes.
-- Tout achat passe par la RemoteFunction « Boutique » : le serveur verifie prix et solde, le client
-- ne fait qu'afficher la reponse. Les offres Robux n'apparaissent que si le createur a renseigne
-- leurs identifiants (Economie.lua).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SocialService = game:GetService("SocialService")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cards"))
-- Habillage sonore de l'accueil : clic, coffre ouvert, achat refuse.
local Sons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sons"))
-- ARENES : nom du palier de trophees, progression, et verrou d'achat (tools/test_arenes.py).
local Arenes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Arenes"))
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

-- HABILLAGE PREMIUM (2026-09-20) --------------------------------------------------------------
-- fix-ok: cause mesuree du rendu « plat » signale par le joueur — le hub ne contenait AUCUN
-- degrade (0 UIGradient dans src/) et UN seul contour, tout etait en aplat de couleur unie ;
-- c'est ce qui manque face au jeu de reference, pas la structure des ecrans. Les trois fabriques
-- ci-dessous ajoutent la couche visuelle absente (degrade, contour cartoon, lueur doree) et sont
-- appliquees aux elements DEJA construits : aucune logique n'est touchee.
local function degrade(o, haut, bas, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(haut, bas)
	g.Rotation = rotation or 90
	g.Parent = o
	return g
end

local function contour(o, epaisseur, couleur, transparence, mode)
	local st = Instance.new("UIStroke")
	st.Thickness = epaisseur or 3
	st.Color = couleur or Color3.fromRGB(12, 14, 24)
	st.Transparency = transparence or 0
	-- fix-ok: en mode Border, un UIStroke pose sur un TextLabel a fond transparent dessine quand
	-- meme le RECTANGLE du label (capture 13:20 : cadres fantomes autour de « 100 pieces »,
	-- « vide », « Gagne une partie »). Contextual ne trace que le texte.
	st.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	st.Parent = o
	return st
end

local function sombre(c, f)
	return Color3.fromRGB(math.floor(c.R * 255 * f), math.floor(c.G * 255 * f), math.floor(c.B * 255 * f))
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
	l.TextStrokeTransparency = 1
	l.TextXAlignment = alignement or Enum.TextXAlignment.Center
	l.Parent = parent
	-- contour de texte epais : lisible sur n'importe quel fond, c'est la typo du jeu de reference.
	contour(l, 2, Color3.fromRGB(10, 12, 20), 0.15, Enum.ApplyStrokeMode.Contextual)
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
	coin(b, 14)
	-- relief : le haut du bouton s'eclaircit, le bas s'assombrit, et un contour sombre epais
	-- detache la forme du fond (le trait cartoon du jeu de reference).
	degrade(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	contour(b, 3)
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

ligneProfil.Visible = false -- remplacee par le bandeau ressources permanent, en haut.
local boutonJouer = bouton(accueil, "JOUER", UDim2.new(0.34, 0, 0.13, 0), UDim2.new(0.33, 0, 0.38, 0), Color3.fromRGB(60, 170, 80))
-- BOUTIQUE et DECK cote a cote sur la ligne du milieu (l'accueil garde la meme hauteur)
-- Plus de boutons BOUTIQUE / DECK sur l'accueil : la barre d'onglets du bas les remplace.
local boutonBonus = bouton(accueil, "BONUS DU JOUR", UDim2.new(0.34, 0, 0.07, 0), UDim2.new(0.33, 0, 0.66, 0), Color3.fromRGB(200, 120, 40))
local message = texte(accueil, "", UDim2.new(0.8, 0, 0.04, 0), UDim2.new(0.1, 0, 0.56, 0), OR)

-- DEFIER UN AMI : l'invitation Roblox fait arriver l'ami sur CE serveur ; les deux premiers
-- joueurs d'un serveur s'affrontent. Les appels SocialService echouent dans Studio : pcall.
local boutonInviter = bouton(accueil, "INVITER", UDim2.new(0.14, 0, 0.07, 0), UDim2.new(0.02, 0, 0.04, 0), Color3.fromRGB(40, 150, 170))
boutonInviter.MouseButton1Click:Connect(function()
	local ok, peut = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not (ok and peut) then
		message.Text = "Invitation impossible ici (jeu non publie ou invitations bloquees)"
		return
	end
	local okP = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if not okP then
		message.Text = "Invitation impossible pour le moment"
	end
end)

-- CLASSEMENT : top 10 des trophees tous serveurs confondus, a droite des boutons.
local titreTop = texte(accueil, "TOP 10", UDim2.new(0.14, 0, 0.04, 0), UDim2.new(0.82, 0, 0.36, 0), OR)
local lignesClassement = {}
for i = 1, 10 do
	lignesClassement[i] = texte(accueil, "", UDim2.new(0.16, 0, 0.028, 0), UDim2.new(0.82, 0, 0.40 + (i - 1) * 0.032, 0),
		Color3.fromRGB(220, 225, 235), Enum.TextXAlignment.Left)
end
local function majClassement(liste)
	liste = liste or {}
	for i = 1, 10 do
		local l = liste[i]
		-- une place NON pourvue reste affichee en gris : la colonne garde ses 10 lignes, sinon
		-- l'ecran CLAN se vide de moitie des que le classement est court (capture cap-clan-final).
		lignesClassement[i].Text = l and string.format("%d. %s  %d", l.rang, l.nom, l.trophees)
			or (i .. ". -")
		lignesClassement[i].TextColor3 = l and Color3.fromRGB(220, 225, 235) or Color3.fromRGB(110, 120, 148)
		lignesClassement[i].ZIndex = 2
	end
	if #liste == 0 then
		lignesClassement[1].Text = "classement indisponible ici"
	end
end

-- COFFRES : 4 emplacements sous les boutons. Le serveur donne l'heure de fin ; le client ne fait
-- qu'afficher le compte a rebours, et c'est le serveur qui refuse une ouverture trop tot.
local COULEUR_COFFRE = { bois = Color3.fromRGB(140, 95, 55), argent = Color3.fromRGB(150, 160, 175), ["or"] = Color3.fromRGB(220, 170, 40) }
local NOM_COFFRE = { bois = "BOIS", argent = "ARGENT", ["or"] = "OR" }
local rangee = Instance.new("Frame")
rangee.BackgroundTransparency = 1
-- fix-ok: a 0.16 de haut, le dessin du coffre ne faisait que ~15 px : couvercle et corps se
-- lisaient comme deux barres plates (capture cap-r2-coffres.png 15:15). La rangee remonte dans
-- l'espace libre sous JOUER (qui finit a 0.51) et double de hauteur ; elle finit a 0.80, juste
-- au-dessus du titre « TON DECK » (0.805).
rangee.Size = UDim2.new(0.7, 0, 0.28, 0)
rangee.Position = UDim2.new(0.15, 0, 0.52, 0)
rangee.Parent = accueil
local rangeeLayout = Instance.new("UIListLayout")
rangeeLayout.FillDirection = Enum.FillDirection.Horizontal
rangeeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rangeeLayout.Padding = UDim.new(0.02, 0)
rangeeLayout.Parent = rangee
local emplacements = {}
-- Les coffres sont montres a DEUX endroits (BATAILLE et EVENEMENTS) : deux rangees d'objets
-- distinctes, un seul etat serveur. majCoffres met a jour tous les jeux declares ici.
local emplacementsEvenements = {}
-- Reference declaree ICI parce que la boucle d'horloge (ecrite plus bas, mais AVANT la
-- construction de l'ecran) la lit : en Luau une variable utilisee avant son `local` est un
-- global nil, et le compte a rebours ne se rafraichirait jamais sur l'onglet EVENEMENTS.
-- L'ecran lui-meme garde sa declaration habituelle, plus bas.
local refEvenements
local jeuxCoffres = { emplacements, emplacementsEvenements }
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
	-- fix-ok: la 2e rangee de la boutique etait coupee en deux (cap-final-boutique.png). CAUSE
	-- MESUREE : la hauteur de cellule etait donnee en PROPORTION, et dans un ScrollingFrame une
	-- proportion se mesure sur le CANEVAS, pas sur la zone visible — la hauteur reelle d'une
	-- rangee ne tombait donc jamais juste dans la fenetre (rangee 295 px pour 392 px visibles).
	-- On passe la hauteur en PIXELS, calculee sur la taille reellement affichee du cadre : la
	-- zone visible contient alors un nombre ENTIER de rangees, aucune carte n'est tronquee.
	local rangeesVisibles = math.max(1, math.floor(1 / (hauteurCellule + ecartVertical) + 0.5))
	local partEcart = ecartVertical / (hauteurCellule + ecartVertical)
	local rangees = math.ceil(#Cards.list / COLONNES)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.23, 0, 0, 0)
	layout.CellPadding = UDim2.new(0.02, 0, 0, 0)
	local function caler()
		local h = cadre.AbsoluteSize.Y
		if h <= 0 then return end
		local pas = h / rangeesVisibles
		local ecartPx = math.floor(pas * partEcart)
		-- fix-ok: n rangees occupent n cellules + (n-1) ecarts, PAS n fois (cellule + ecart) : il
		-- restait un ecart de libre en bas, et la rangee suivante y montrait une tranche de
		-- quelques pixels (capture cap-boutique-grille.png). On retire les ecarts de la hauteur
		-- AVANT de diviser : les rangees visibles remplissent alors exactement la fenetre.
		local cellPx = math.floor((h - (rangeesVisibles - 1) * ecartPx) / rangeesVisibles)
		layout.CellSize = UDim2.new(0.23, 0, 0, cellPx)
		layout.CellPadding = UDim2.new(0.02, 0, 0, ecartPx)
		cadre.CanvasSize = UDim2.new(0, 0, 0, rangees * (cellPx + ecartPx) - ecartPx)
	end
	caler()
	cadre:GetPropertyChangedSignal("AbsoluteSize"):Connect(caler)
	layout.Parent = cadre
	return cadre
end

-- La grille descend jusqu'aux offres Robux : la bande 0.80 -> 0.97 etait un grand vide quand
-- aucune offre n'est configuree (capture cap-v3-boutique.png). Trois rangees ENTIERES tiennent
-- dans la zone visible (1 / (0.30 + 0.03) ~ 3), donc plus de carte coupee en bas.
local grille = grilleDefilante(boutique, UDim2.new(0.94, 0, 0.72, 0), UDim2.new(0.03, 0, 0.18, 0), 0.30, 0.03)

local offresRobux = Instance.new("Frame")
offresRobux.BackgroundTransparency = 1
offresRobux.Size = UDim2.new(0.94, 0, 0.075, 0)
offresRobux.Position = UDim2.new(0.03, 0, 0.915, 0)
offresRobux.Parent = boutique
local layoutRobux = Instance.new("UIListLayout")
layoutRobux.FillDirection = Enum.FillDirection.Horizontal
layoutRobux.Padding = UDim.new(0.02, 0)
layoutRobux.Parent = offresRobux

local vue = nil
local majDeck -- ecran DECK, defini plus bas : afficher() le rafraichit s'il existe deja
local majDeckBataille -- rangee du deck courant sur l'ecran BATAILLE, definie plus bas
local majClan, majEvenements -- pastilles chiffrees des ecrans CLAN et EVENEMENTS, definies plus bas
local tuiles = {}

local function majCoffres()
	if not vue then
		return
	end
	local maintenant = os.time() + decalageHorloge
	for _, jeu in ipairs(jeuxCoffres) do
	for i = 1, 4 do
		local e = jeu[i]
		local c = vue.coffres[i]
		if e then
		if not c then
			-- emplacement libre : le coffre reste DESSINE mais en silhouette grise et effacee.
			-- Le masquer completement laissait quatre cases vides (capture cap-v3-bataille.png) :
			-- la rangee ne se lisait plus comme des emplacements a coffre.
			e.coffre.boite.Visible = true
			e.coffre.couvercle.BackgroundColor3 = Color3.fromRGB(70, 76, 105)
			e.coffre.corps.BackgroundColor3 = Color3.fromRGB(52, 57, 82)
			e.coffre.bande.BackgroundColor3 = Color3.fromRGB(86, 92, 122)
			e.coffre.serrure.BackgroundColor3 = Color3.fromRGB(86, 92, 122)
			for _, part in ipairs({ e.coffre.couvercle, e.coffre.corps, e.coffre.bande, e.coffre.serrure }) do
				part.BackgroundTransparency = 0.45
			end
			e.titre.Text = "vide"
			e.etat.Text = "Gagne une partie"
			e.etat.BackgroundTransparency = 1
			-- fix-ok: emplacement vide = bouton sans fond, mais son UIStroke en mode Border restait
			-- peint : un rectangle flottant autour de « Gagne une partie » (capture 14:12). Le
			-- contour suit le fond.
			local stV = e.etat:FindFirstChildOfClass("UIStroke")
			if stV then stV.Enabled = false end
		else
			-- le TYPE de coffre se lit a sa couleur : le corps est assombri pour que le couvercle
			-- ressorte (c'est ce contraste qui donne le relief, pas un aplat unique).
			local teinte = COULEUR_COFFRE[c.type]
			e.coffre.boite.Visible = true
			-- le coffre revient en pleine couleur apres etre passe en silhouette (emplacement libre)
			e.coffre.bande.BackgroundColor3 = OR
			e.coffre.serrure.BackgroundColor3 = OR
			for _, part in ipairs({ e.coffre.couvercle, e.coffre.corps, e.coffre.bande, e.coffre.serrure }) do
				part.BackgroundTransparency = 0
			end
			e.coffre.couvercle.BackgroundColor3 = teinte
			e.coffre.corps.BackgroundColor3 = sombre(teinte, 0.78)
			e.titre.Text = NOM_COFFRE[c.type]
			e.etat.BackgroundTransparency = 0.2
			local stP = e.etat:FindFirstChildOfClass("UIStroke")
			if stP then stP.Enabled = true end
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
	end
end

-- Declares ICI, assignes plus bas avec la barre d'onglets : les fonctions ecrites avant eux
-- (recherche d'adversaire) les masquent, et en Luau une variable utilisee avant son `local`
-- est un global nil qui fait planter le script.
local bandeau, liseraBarre
local majBandeau
-- declaree ici, definie plus bas (l'onglet EVENEMENTS est construit apres `afficher`).
-- NOM DISTINCT de `majEvenements` (pastille d'onglet, declaree plus haut) : le meme nom
-- ecrasait cette fonction-la et les quetes restaient vides (vu a la capture, 2026-09-20).
local majQuetes

local function afficher(v)
	if not v then
		return
	end
	vue = v
	if majQuetes then
		majQuetes(v)
	end
	-- SERIE EN COURS : affichee des la 2e victoire d'affilee, avec ce qu'elle rapporte en plus.
	-- Sans elle, le joueur ne voit jamais ce qu'il perd en s'arretant maintenant.
	local serie = (v.serie or 0) >= 2 and string.format("   |   serie %d (+%d pieces)", v.serie,
		math.min(v.serie - 1, v.serieMax or 5) * 10) or ""
	-- ARENE : le palier atteint, et ce qui reste avant le suivant. Les trophees n'etaient
	-- qu'un nombre : rien ne disait ou l'on en etait ni ce que la montee rapporterait.
	local arene = Arenes.actuelle(v.trophees or 0)
	local suivante = Arenes.suivante(v.trophees or 0)
	local versLaSuite = suivante
		and string.format("   |   %s dans %d trophees (+%d pieces)", suivante.nom,
			suivante.seuil - (v.trophees or 0), suivante.recompense)
		or "   |   derniere arene"
	ligneProfil.Text = string.format("%d pieces   |   %d trophees   |   %s%s%s",
		v.pieces, v.trophees, arene.nom, versLaSuite, serie)
	ligneInfo.Text = string.format("%d victoires sur %d parties%s", v.victoires, v.parties,
		v.sauvegarde and "" or "   (progression non sauvegardee dans Studio)")
	boutonBonus.Text = v.bonusDispo and "BONUS DU JOUR : +50" or "BONUS DEJA PRIS"
	boutonBonus.BackgroundColor3 = v.bonusDispo and Color3.fromRGB(200, 120, 40) or Color3.fromRGB(80, 80, 90)
	soldeBoutique.Text = v.pieces .. " pieces"
	if majBandeau then
		majBandeau(v)
	end
	if v.maintenant then
		decalageHorloge = v.maintenant - os.time()
	end
	majCoffres()
	if majDeck then
		majDeck()
	end
	if majDeckBataille then
		majDeckBataille()
	end
	if majClan then
		majClan()
	end
	if majEvenements then
		majEvenements()
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
			-- VERROU D'ARENE : une carte rattachee a un palier de trophees ne s'achete pas avant
			-- de l'avoir atteint. La tuile le DIT, au lieu de laisser cliquer sur un bouton qui
			-- refuse : le joueur voyait sinon « Impossible » sans savoir pourquoi.
			local ouverte, areneRequise = Arenes.carteDebloquee(card.id, v.trophees or 0)
			if not ouverte then
				t.action.Text = "ARENE " .. tostring(areneRequise)
				t.etat.Text = card.prix .. " pieces — a debloquer plus haut"
				t.action.Visible = true
				t.action.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
			else
				t.action.Text = "ACHETER"
				t.etat.Text = card.prix .. " pieces"
				t.action.Visible = true
				t.action.BackgroundColor3 = v.pieces >= card.prix and Color3.fromRGB(60, 170, 80) or Color3.fromRGB(90, 90, 100)
			end
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
	-- CADRE DE RARETE : gris commune, bleu rare, violet epique, or legendaire. Sans lui, 28 tuiles
	-- se ressemblaient toutes et rien ne disait ce qui valait la peine d'etre achete.
	local rar = Cards.RARETES[card.rarete]
	if rar then
		local bordRarete = Instance.new("UIStroke")
		bordRarete.Thickness = card.rarete == "commune" and 2 or 3
		bordRarete.Color = rar.couleur
		bordRarete.Parent = tuile
		-- fix-ok: le nom occupait 0.02 -> 0.36 en hauteur et la rarete etait posee a 0.32 : les deux
		-- textes se recouvraient sur 4 % de la tuile (lettres de la rarete melees au nom, capture
		-- 14:33). Le nom est raccourci a 0.03 -> 0.29, la rarete part a 0.30 : plus aucun recouvrement.
		texte(tuile, rar.nom, UDim2.new(0.9, 0, 0.1, 0), UDim2.new(0.05, 0, 0.30, 0), rar.couleur)
	end
	texte(tuile, card.name, UDim2.new(0.9, 0, 0.26, 0), UDim2.new(0.05, 0, 0.03, 0))
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
-- 0.50 de haut : la collection occupe le haut de l'ecran, la rangee du deck courant se pose
-- dessous (0.70), au-dessus du bouton ENREGISTRER (0.87) — l'ordre du jeu de reference.
local deckGrille = grilleDefilante(deckEcran, UDim2.new(0.94, 0, 0.50, 0), UDim2.new(0.03, 0, 0.16, 0), 0.3, 0.03)

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
	local rarDeck = Cards.RARETES[card.rarete]
	if rarDeck then
		local bordRarete = Instance.new("UIStroke")
		bordRarete.Thickness = card.rarete == "commune" and 2 or 3
		bordRarete.Color = rarDeck.couleur
		bordRarete.Parent = tuile
	end
	local bord = Instance.new("UIStroke")
	bord.Thickness = 4
	bord.Color = OR
	bord.Transparency = 1
	bord.Parent = tuile
	-- largeur 0.56 et non 0.9 : la pastille de niveau occupe desormais le coin haut droit,
	-- et le nom la recouvrait (capture cap-cartes-collection.png du 2026-09-20).
	texte(tuile, card.name, UDim2.new(0.56, 0, 0.4, 0), UDim2.new(0.05, 0, 0.06, 0))
	texte(tuile, card.cost .. " elixir", UDim2.new(0.9, 0, 0.18, 0), UDim2.new(0.05, 0, 0.5, 0), Color3.fromRGB(230, 210, 255))
	local etatDeck = texte(tuile, "", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.72, 0), OR)
	-- NIVEAU de la carte, comme dans la collection du jeu de reference : pastille sombre en haut
	-- a droite. L'onglet CARTES montrait la collection SANS les niveaux, alors que la vue serveur
	-- les porte deja (v.niveaux) — le joueur devait passer par la boutique pour les lire.
	local pastilleNiv = Instance.new("Frame")
	pastilleNiv.Size = UDim2.new(0.34, 0, 0.2, 0)
	pastilleNiv.Position = UDim2.new(0.62, 0, 0.04, 0)
	pastilleNiv.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
	pastilleNiv.BackgroundTransparency = 0.15
	pastilleNiv.ZIndex = 3
	pastilleNiv.Parent = tuile
	coin(pastilleNiv, 6)
	local niveauDeck = texte(pastilleNiv, "", UDim2.new(0.9, 0, 0.8, 0), UDim2.new(0.05, 0, 0.1, 0), OR)
	niveauDeck.ZIndex = 4
	tuile.MouseButton1Click:Connect(function()
		if vue and vue.cartes[card.id] then
			basculer(card.id)
		end
	end)
	tuilesDeck[card.id] = { tuile = tuile, bord = bord, etat = etatDeck, niveau = niveauDeck, pastille = pastilleNiv }
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
		-- niveau lu de la VUE serveur : une carte non possedee n'a pas de niveau, sa pastille
		-- disparait plutot que d'afficher un « Niv. 1 » qui n'existe pas.
		t.pastille.Visible = possede
		t.niveau.Text = possede and ("Niv. " .. ((vue.niveaux and vue.niveaux[card.id]) or 1)) or ""
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

-- VRAI COFFRE DESSINE : un aplat de couleur ne ressemblait pas a un coffre. On dessine un
-- couvercle bombe pose sur un corps, une bande doree verticale, des ferrures et une serrure ;
-- le relief vient des degrades (haut clair / bas sombre) et du contour cartoon epais.
-- `dessinerCoffre` rend les pieces a recolorer pour que majCoffres change le type de coffre.
local function dessinerCoffre(parent)
	local boite = Instance.new("Frame")
	boite.BackgroundTransparency = 1
	boite.Size = UDim2.new(0.8, 0, 0.54, 0)
	boite.Position = UDim2.new(0.1, 0, 0.20, 0)
	boite.Parent = parent

	local corps = Instance.new("Frame")
	corps.Size = UDim2.new(1, 0, 0.58, 0)
	corps.Position = UDim2.new(0, 0, 0.42, 0)
	corps.BackgroundColor3 = Color3.fromRGB(140, 95, 55)
	corps.Parent = boite
	coin(corps, 6)
	degrade(corps, Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 110, 110))
	contour(corps, 3)

	-- couvercle : plus large que le corps et arrondi en haut, c'est lui qui fait lire « coffre »
	local couvercle = Instance.new("Frame")
	couvercle.Size = UDim2.new(1.08, 0, 0.48, 0)
	couvercle.Position = UDim2.new(-0.04, 0, 0, 0)
	couvercle.BackgroundColor3 = Color3.fromRGB(140, 95, 55)
	couvercle.Parent = boite
	coin(couvercle, 14)
	degrade(couvercle, Color3.fromRGB(255, 255, 255), Color3.fromRGB(135, 135, 135))
	contour(couvercle, 3)

	-- bande doree verticale au centre, du couvercle jusqu'au bas du corps
	local bande = Instance.new("Frame")
	bande.Size = UDim2.new(0.18, 0, 1, 0)
	bande.Position = UDim2.new(0.41, 0, 0, 0)
	bande.BackgroundColor3 = OR
	bande.ZIndex = 2
	bande.Parent = boite
	degrade(bande, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 130, 60))
	contour(bande, 2)

	-- serrure : pastille doree a la jonction couvercle / corps
	local serrure = Instance.new("Frame")
	serrure.Size = UDim2.new(0, 18, 0, 18)
	serrure.Position = UDim2.new(0.5, -9, 0.42, -9)
	serrure.BackgroundColor3 = OR
	serrure.ZIndex = 3
	serrure.Parent = boite
	coin(serrure, 9)
	degrade(serrure, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 115, 40))
	contour(serrure, 2)

	-- on rend AUSSI la boite : masquer seulement corps et couvercle laissait la bande doree et la
	-- serrure flotter toutes seules sur un emplacement vide (capture cap-r1-bataille.png 15:04).
	return { boite = boite, corps = corps, couvercle = couvercle, bande = bande, serrure = serrure }
end

local function construireCoffres(parentRangee, cible)
for i = 1, 4 do
	local cadre = Instance.new("Frame")
	cadre.Size = UDim2.new(0.23, 0, 1, 0)
	cadre.BackgroundColor3 = Color3.fromRGB(28, 32, 58)
	cadre.Parent = parentRangee
	coin(cadre)
	degrade(cadre, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 124, 170))
	contour(cadre, 2, Color3.fromRGB(12, 14, 24), 0.2)
	local coffre = dessinerCoffre(cadre)
	local titre = texte(cadre, "vide", UDim2.new(0.9, 0, 0.14, 0), UDim2.new(0.05, 0, 0.03, 0))
	local etat = bouton(cadre, "", UDim2.new(0.9, 0, 0.18, 0), UDim2.new(0.05, 0, 0.78, 0), Color3.fromRGB(25, 25, 35))
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
	cible[i] = { cadre = cadre, titre = titre, etat = etat, coffre = coffre }
end
end
construireCoffres(rangee, emplacements)
task.spawn(function()
	while true do
		task.wait(1)
		if accueil.Visible or (refEvenements and refEvenements.Visible) then
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

-- ONGLETS (declares ici, construits en bas de fichier) : la navigation les utilise.
-- barreOnglets : la barre du bas ; majOnglets(nom) : bascule l'onglet actif.
local barreOnglets
local majOnglets

-- NAVIGATION ------------------------------------------------------------------------------------
local function ouvrirAccueil()
	Sons.boucle("hub")
	accueil.Visible = true
	boutique.Visible = false
	deckEcran.Visible = false
	boutonMenu.Visible = false
	if majOnglets then
		-- CAUSE RACINE de trois captures perdues (2026-09-20) : `ouvrirAccueil` forcait TOUJOURS
		-- l'onglet BATAILLE, y compris quand la copie de test demande un autre onglet par
		-- BRR_ONGLET — et il est rappele apres le crochet de capture. Il respecte la demande.
		local demande = ReplicatedStorage:FindFirstChild("BRR_ONGLET")
		majOnglets((demande and demande.Value ~= "" and demande.Value) or "bataille")
	end
	afficher(Boutique:InvokeServer("profil").vue)
	task.spawn(function()
		majClassement(Boutique:InvokeServer("classement").classement)
	end)
end

boutonJouer.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local r = Boutique:InvokeServer("jouer")
	if r.attente then
		-- Recherche d'un adversaire en ligne : le serveur donne le robot au bout de ~20 s.
		message.Text = "Recherche d'un adversaire..."
		local etat = "attente"
		while etat == "attente" do
			task.wait(1)
			etat = Boutique:InvokeServer("attente").etat
		end
		if etat == "teleport" then
			message.Text = "Adversaire trouve ! Depart vers l'arene..."
			return
		end
		message.Text = "Personne pour l'instant : tu affrontes le robot"
	end
	Sons.boucle("combat")
	if r.ok then
		accueil.Visible = false
		boutonMenu.Visible = true
		if barreOnglets then barreOnglets.Visible = false end
		liseraBarre.Visible = false
		bandeau.Visible = false
	else
		message.Text = "Les deux camps sont pris : tu regardes la partie"
		accueil.Visible = false
		boutonMenu.Visible = true
		if barreOnglets then barreOnglets.Visible = false end
		liseraBarre.Visible = false
		bandeau.Visible = false
	end
end)
local function ouvrirEcranDeck()
	Sons.jouer("clic")
	-- L'accueil passe DERRIERE : sans cela, sa rangee de coffres (« Gagne une partie ») depasse
	-- sous le panneau et son texte est rogne (vu sur capture-hub.png, 2026-09-16).
	accueil.Visible = false
	ouvrirPanneau(deckEcran)
	afficher(Boutique:InvokeServer("profil").vue)
	chargerChoix()
	majDeck()
end

local function ouvrirEcranBoutique()
	Sons.jouer("clic")
	accueil.Visible = false
	ouvrirPanneau(boutique)
	afficher(Boutique:InvokeServer("profil").vue)
end
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

-- ONGLETS STYLE CLASH ROYALE -----------------------------------------------------------------
-- Cinq onglets en bas d'ecran, dans l'ordre du jeu de reference : BOUTIQUE, CARTES, BATAILLE,
-- CLAN, EVENEMENTS. Chaque onglet montre UN cadre plein ecran au-dessus de la barre ; la barre
-- remplace les anciens boutons de l'accueil et les croix de fermeture (il n'y en a pas dans le
-- jeu de reference). Tout est construit APRES les cadres qu'il manipule : en Luau, une variable
-- utilisee avant son `local` casse tout le script (commit 20d91d3).
local HAUTEUR_BARRE = 0.12

local function panneauOnglet(titre)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1 - HAUTEUR_BARRE, 0)
	f.Position = UDim2.fromScale(0, 0)
	f.BackgroundColor3 = FOND
	f.Visible = false
	f.Parent = gui
	if titre then
		texte(f, titre, UDim2.new(0.6, 0, 0.09, 0), UDim2.new(0.2, 0, 0.02, 0), OR)
	end
	return f
end

-- Les ecrans deja existants passent en plein ecran au-dessus de la barre.
for _, f in ipairs({ boutique, deckEcran }) do
	f.Size = UDim2.new(1, 0, 1 - HAUTEUR_BARRE, 0)
	f.Position = UDim2.fromScale(0, 0)
end
-- Plus de croix : on change d'ecran par les onglets.
fermer.Visible = false
deckFermer.Visible = false
-- L'accueil devient l'onglet BATAILLE : ses anciens raccourcis vers boutique et deck sont
-- remplaces par la barre d'onglets, et leurs boutons ont ete supprimes.

-- DECK COURANT SUR BATAILLE : dans le jeu de reference, les 8 cartes emportees sont visibles
-- sous les coffres, avant de lancer la partie. La donnee existe deja (`vue.deck` / `vue.deckTaille`
-- envoyes par le serveur) : aucune nouvelle action serveur n'est necessaire. Un clic ouvre
-- l'onglet CARTES pour le modifier.
texte(accueil, "TON DECK", UDim2.new(0.3, 0, 0.035, 0), UDim2.new(0.12, 0, 0.805, 0), OR, Enum.TextXAlignment.Left)
-- RANGEE DU DECK COURANT : montree sur BATAILLE et, depuis l'audit, SOUS la collection dans
-- l'onglet CARTES — le jeu de reference met la collection en haut et le deck en bas.
-- Une seule fabrique, deux rangees d'objets, un seul etat (vue.deck).
local jeuxDeck = {}
local function construireRangeeDeck(parent, taille, position)
local rangeeDeck = Instance.new("Frame")
rangeeDeck.BackgroundTransparency = 1
rangeeDeck.Size = taille
rangeeDeck.Position = position
rangeeDeck.Parent = parent
local layoutDeck = Instance.new("UIListLayout")
layoutDeck.FillDirection = Enum.FillDirection.Horizontal
layoutDeck.HorizontalAlignment = Enum.HorizontalAlignment.Left
layoutDeck.Padding = UDim.new(0.008, 0)
layoutDeck.Parent = rangeeDeck

local casesDeck = {}
for i = 1, 8 do
	local case = Instance.new("TextButton")
	case.Size = UDim2.new(0.115, 0, 1, 0)
	case.Text = ""
	case.AutoButtonColor = true
	case.BackgroundColor3 = Color3.fromRGB(30, 34, 62)
	case.Parent = rangeeDeck
	coin(case, 8)
	degrade(case, Color3.fromRGB(255, 255, 255), Color3.fromRGB(130, 130, 130))
	contour(case, 2)
	local nom = texte(case, "", UDim2.new(0.9, 0, 0.42, 0), UDim2.new(0.05, 0, 0.52, 0))
	-- gout d'elixir en haut a gauche, comme sur les cartes du jeu de reference
	local pastille = Instance.new("Frame")
	pastille.Size = UDim2.new(0, 20, 0, 20)
	pastille.Position = UDim2.new(0, 3, 0, 3)
	pastille.BackgroundColor3 = Color3.fromRGB(190, 90, 230)
	pastille.ZIndex = 2
	pastille.Parent = case
	coin(pastille, 10)
	contour(pastille, 2)
	local cout = texte(pastille, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	cout.ZIndex = 3
	case.MouseButton1Click:Connect(function()
		Sons.jouer("clic")
		if majOnglets then
			majOnglets("cartes")
		end
	end)
	casesDeck[i] = { case = case, nom = nom, pastille = pastille, cout = cout }
end
table.insert(jeuxDeck, casesDeck)
end
construireRangeeDeck(accueil, UDim2.new(0.76, 0, 0.13, 0), UDim2.new(0.12, 0, 0.845, 0))
texte(deckEcran, "TON DECK", UDim2.new(0.3, 0, 0.035, 0), UDim2.new(0.05, 0, 0.675, 0), OR, Enum.TextXAlignment.Left)
construireRangeeDeck(deckEcran, UDim2.new(0.9, 0, 0.14, 0), UDim2.new(0.05, 0, 0.715, 0))

local deckVide = texte(accueil, "", UDim2.new(0.5, 0, 0.04, 0), UDim2.new(0.12, 0, 0.90, 0), Color3.fromRGB(190, 200, 220), Enum.TextXAlignment.Left)

majDeckBataille = function()
	local liste = (vue and vue.deck) or {}
	local taille = (vue and vue.deckTaille) or 8
	for _, casesDeck in ipairs(jeuxDeck) do
	for i = 1, 8 do
		local d = casesDeck[i]
		local card = liste[i] and Cards.byId[liste[i]]
		d.case.Visible = i <= taille
		if card then
			d.case.BackgroundColor3 = card.color
			d.nom.Text = card.name
			d.cout.Text = tostring(card.cost)
			d.pastille.Visible = true
		else
			d.case.BackgroundColor3 = Color3.fromRGB(30, 34, 62)
			d.nom.Text = ""
			d.cout.Text = ""
			d.pastille.Visible = false
		end
	end
	end
	deckVide.Text = #liste == 0 and "Aucun deck : va dans CARTES pour en choisir un." or ""
end
majDeckBataille()

-- CLAN : membres du serveur, classement et invitation.
local clanEcran = panneauOnglet("CLAN")
titreTop.Parent = clanEcran
titreTop.Size = UDim2.new(0.3, 0, 0.05, 0)
titreTop.Position = UDim2.new(0.35, 0, 0.13, 0)
for i = 1, 10 do
	lignesClassement[i].Parent = clanEcran
	lignesClassement[i].Size = UDim2.new(0.5, 0, 0.045, 0)
	lignesClassement[i].Position = UDim2.new(0.28, 0, 0.20 + (i - 1) * 0.05, 0)
end
-- MEMBRES DU SERVEUR : colonne de gauche. Le classement passe a droite pour leur laisser la place.
titreTop.Position = UDim2.new(0.52, 0, 0.13, 0)
titreTop.Size = UDim2.new(0.3, 0, 0.05, 0)
for i = 1, 10 do
	lignesClassement[i].Position = UDim2.new(0.55, 0, 0.20 + (i - 1) * 0.05, 0)
	lignesClassement[i].Size = UDim2.new(0.38, 0, 0.045, 0)
end
texte(clanEcran, "SUR CE SERVEUR", UDim2.new(0.3, 0, 0.05, 0), UDim2.new(0.1, 0, 0.13, 0), OR)
-- LIGNES DE FOND : les deux colonnes tiennent 10 places. Sans fond, une liste a 1 nom laissait
-- un trou de la moitie de l'ecran (capture cap-clan-final.png) ; les bandes alternees montrent
-- les places LIBRES au lieu du vide, et le cadre se lit meme avec un seul joueur connecte.
local function bandesListe(x)
	for i = 1, 10 do
		local b = Instance.new("Frame")
		b.Size = UDim2.new(0.40, 0, 0.048, 0)
		b.Position = UDim2.new(x - 0.02, 0, 0.198 + (i - 1) * 0.05, 0)
		b.BackgroundColor3 = Color3.fromRGB(38, 44, 76)
		b.BackgroundTransparency = (i % 2 == 0) and 0.72 or 0.5
		b.BorderSizePixel = 0
		b.ZIndex = 1
		b.Parent = clanEcran
		coin(b, 6)
	end
end
bandesListe(0.07)
bandesListe(0.55)

local lignesMembres = {}
for i = 1, 10 do
	lignesMembres[i] = texte(clanEcran, "", UDim2.new(0.38, 0, 0.045, 0),
		UDim2.new(0.07, 0, 0.20 + (i - 1) * 0.05, 0), Color3.fromRGB(220, 225, 235), Enum.TextXAlignment.Left)
	lignesMembres[i].ZIndex = 2
end
-- Les trophees des autres joueurs ne sont pas repliques au client : on affiche le nom, et le
-- compte de joueurs. C'est la seule donnee sure sans nouvelle action serveur.
local function majMembres()
	local liste = Players:GetPlayers()
	for i = 1, 10 do
		local j = liste[i]
		lignesMembres[i].Text = j and (i .. ". " .. j.DisplayName .. (j == player and "  (toi)" or "")) or "place libre"
		lignesMembres[i].TextColor3 = j and Color3.fromRGB(220, 225, 235) or Color3.fromRGB(110, 120, 148)
	end
	if #liste > 10 then
		lignesMembres[10].Text = "... et " .. (#liste - 10) .. " autres"
	end
end
majMembres()
Players.PlayerAdded:Connect(majMembres)
Players.PlayerRemoving:Connect(function()
	task.defer(majMembres)
end)

-- ECUSSON ET ENTETE DE CLAN : l'ecran n'avait qu'une liste de noms et un grand vide en haut.
-- L'ecusson est dessine (pas d'image a charger) : losange dore sur fond bleu, contour cartoon.
local ecusson = Instance.new("Frame")
-- hauteur 0.10 et non 0.13 : au-dela, l'ecusson mordait sur le titre « SUR CE SERVEUR » (y 0.13)
ecusson.Size = UDim2.new(0.09, 0, 0.10, 0)
ecusson.Position = UDim2.new(0.04, 0, 0.005, 0)
ecusson.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
ecusson.Parent = clanEcran
coin(ecusson, 10)
degrade(ecusson, Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 110, 140))
contour(ecusson, 3, OR, 0.1)
local blason = Instance.new("Frame")
blason.Size = UDim2.new(0.5, 0, 0.5, 0)
blason.Position = UDim2.new(0.25, 0, 0.25, 0)
blason.Rotation = 45
blason.BackgroundColor3 = OR
blason.ZIndex = 2
blason.Parent = ecusson
degrade(blason, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 120, 40))
contour(blason, 2)
texte(clanEcran, "CLAN BRAINROT", UDim2.new(0.34, 0, 0.05, 0), UDim2.new(0.14, 0, 0.012, 0), OR, Enum.TextXAlignment.Left)
local clanEffectif = texte(clanEcran, "", UDim2.new(0.34, 0, 0.035, 0), UDim2.new(0.14, 0, 0.068, 0),
	Color3.fromRGB(190, 200, 220), Enum.TextXAlignment.Left)

-- PASTILLES CHIFFREES : trophees / victoires / parties, les seules donnees de clan que le
-- serveur connait vraiment. Elles remplissent la bande vide sous les deux colonnes.
local function pastilleChiffre(parent, x, y, titre, couleur)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0.26, 0, 0.11, 0)
	f.Position = UDim2.new(x, 0, y, 0)
	f.BackgroundColor3 = Color3.fromRGB(26, 30, 56)
	f.Parent = parent
	coin(f, 12)
	degrade(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 124, 170))
	contour(f, 2, couleur, 0.2)
	texte(f, titre, UDim2.new(0.9, 0, 0.32, 0), UDim2.new(0.05, 0, 0.08, 0), couleur)
	return texte(f, "0", UDim2.new(0.9, 0, 0.44, 0), UDim2.new(0.05, 0, 0.46, 0))
end
local clanTrophees = pastilleChiffre(clanEcran, 0.07, 0.72, "TROPHEES", Color3.fromRGB(235, 90, 110))
local clanVictoires = pastilleChiffre(clanEcran, 0.37, 0.72, "VICTOIRES", Color3.fromRGB(80, 210, 160))
local clanParties = pastilleChiffre(clanEcran, 0.67, 0.72, "PARTIES", Color3.fromRGB(120, 170, 255))

majClan = function()
	if not vue then
		return
	end
	clanTrophees.Text = tostring(vue.trophees)
	clanVictoires.Text = tostring(vue.victoires)
	clanParties.Text = tostring(vue.parties)
end
local function majEffectif()
	local n = #Players:GetPlayers()
	clanEffectif.Text = n .. (n > 1 and " joueurs en ligne" or " joueur en ligne")
end
majEffectif()
Players.PlayerAdded:Connect(majEffectif)
Players.PlayerRemoving:Connect(function()
	task.defer(majEffectif)
end)

boutonInviter.Parent = clanEcran
boutonInviter.Size = UDim2.new(0.26, 0, 0.075, 0)
boutonInviter.Position = UDim2.new(0.37, 0, 0.855, 0)
local clanInfo = texte(clanEcran, "Invite un ami : il arrive sur ce serveur et tu peux le defier.",
	UDim2.new(0.8, 0, 0.035, 0), UDim2.new(0.1, 0, 0.945, 0), Color3.fromRGB(180, 190, 210))

-- EVENEMENTS : le bonus du jour (recompense quotidienne du jeu de reference).
local evenementsEcran = panneauOnglet("EVENEMENTS")
refEvenements = evenementsEcran
-- L'ecran n'avait qu'un bouton perdu au centre. Trois TUILES d'evenement occupent maintenant la
-- largeur ; chacune montre un chiffre REEL de la vue serveur (bonus disponible, serie en cours,
-- coffres prets a ouvrir) : rien n'est invente cote client.
local function tuileEvenement(x, titre, couleur)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0.28, 0, 0.26, 0)
	f.Position = UDim2.new(x, 0, 0.14, 0)
	f.BackgroundColor3 = Color3.fromRGB(26, 30, 56)
	f.Parent = evenementsEcran
	coin(f, 14)
	degrade(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(115, 120, 165))
	contour(f, 3, couleur, 0.15)
	texte(f, titre, UDim2.new(0.9, 0, 0.14, 0), UDim2.new(0.05, 0, 0.05, 0), couleur)
	local val = texte(f, "-", UDim2.new(0.9, 0, 0.26, 0), UDim2.new(0.05, 0, 0.22, 0))
	local det = texte(f, "", UDim2.new(0.9, 0, 0.22, 0), UDim2.new(0.05, 0, 0.50, 0), Color3.fromRGB(185, 195, 215))
	return f, val, det
end
local tuileBonus, bonusVal, bonusDet = tuileEvenement(0.04, "BONUS DU JOUR", OR)
local _, serieVal, serieDet = tuileEvenement(0.36, "SERIE", Color3.fromRGB(235, 130, 60))
local _, coffresVal, coffresDet = tuileEvenement(0.68, "COFFRES", Color3.fromRGB(120, 170, 255))

-- MEME rangee de coffres que l'ecran BATAILLE : memes visuels, meme compte a rebours, meme
-- action serveur. Les objets sont distincts, l'etat vient d'une seule source (vue.coffres).
local rangeeCoffresEv = Instance.new("Frame")
rangeeCoffresEv.BackgroundTransparency = 1
rangeeCoffresEv.Size = UDim2.new(0.9, 0, 0.19, 0)
rangeeCoffresEv.Position = UDim2.new(0.05, 0, 0.42, 0)
rangeeCoffresEv.Parent = evenementsEcran
local layoutCoffresEv = Instance.new("UIListLayout")
layoutCoffresEv.FillDirection = Enum.FillDirection.Horizontal
layoutCoffresEv.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutCoffresEv.Padding = UDim.new(0.02, 0)
layoutCoffresEv.Parent = rangeeCoffresEv
construireCoffres(rangeeCoffresEv, emplacementsEvenements)

boutonBonus.Parent = tuileBonus
boutonBonus.Size = UDim2.new(0.86, 0, 0.22, 0)
boutonBonus.Position = UDim2.new(0.07, 0, 0.74, 0)
local messageEvenements = texte(evenementsEcran, "", UDim2.new(0.8, 0, 0.04, 0), UDim2.new(0.1, 0, 0.955, 0), OR)

-- QUETES DU JOUR + COFFRE GRATUIT. Avant, cet onglet ne portait QUE le bonus quotidien : un seul
-- rendez-vous par jour, pris en trois secondes. Les quetes donnent un but pendant la session, le
-- coffre gratuit (toutes les 4 h) donne une raison de repasser dans la journee.
local lignesQuetes = {}
texte(evenementsEcran, "QUETES DU JOUR", UDim2.new(0.6, 0, 0.045, 0), UDim2.new(0.2, 0, 0.615, 0), OR)
for i = 1, 3 do
	local y = 0.665 + (i - 1) * 0.052
	local ligne = texte(evenementsEcran, "", UDim2.new(0.52, 0, 0.045, 0), UDim2.new(0.08, 0, y, 0),
		Color3.fromRGB(215, 222, 235))
	ligne.TextXAlignment = Enum.TextXAlignment.Left
	local jauge = Instance.new("Frame")
	jauge.Size = UDim2.new(0.18, 0, 0.022, 0)
	jauge.Position = UDim2.new(0.40, 0, y + 0.012, 0)
	jauge.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
	jauge.BorderSizePixel = 0
	jauge.Parent = evenementsEcran
	local remplissage = Instance.new("Frame")
	remplissage.Size = UDim2.new(0, 0, 1, 0)
	remplissage.BackgroundColor3 = OR
	remplissage.BorderSizePixel = 0
	remplissage.Parent = jauge
	local action = bouton(evenementsEcran, "OK", UDim2.new(0.12, 0, 0.04, 0), UDim2.new(0.60, 0, y, 0),
		Color3.fromRGB(60, 170, 80))
	action.Visible = false
	lignesQuetes[i] = { ligne = ligne, jauge = remplissage, action = action, id = nil }
	action.MouseButton1Click:Connect(function()
		local id = lignesQuetes[i].id
		if not id then
			return
		end
		local r = Boutique:InvokeServer("quete", id)
		afficher(r.vue)
		messageEvenements.Text = r.ok and ("Quete finie : +" .. tostring(r.motif) .. " pieces")
			or ("Refus : " .. tostring(r.motif))
		Sons.jouer(r.ok and "coffre" or "refus")
	end)
end

texte(evenementsEcran, "COFFRE GRATUIT", UDim2.new(0.6, 0, 0.035, 0), UDim2.new(0.2, 0, 0.825, 0), Color3.fromRGB(120, 170, 255))
local infoCoffreGratuit = texte(evenementsEcran, "", UDim2.new(0.8, 0, 0.03, 0), UDim2.new(0.1, 0, 0.862, 0),
	Color3.fromRGB(180, 190, 210))
local boutonCoffreGratuit = bouton(evenementsEcran, "RECUPERER", UDim2.new(0.26, 0, 0.05, 0),
	UDim2.new(0.37, 0, 0.898, 0), Color3.fromRGB(230, 150, 30))
boutonCoffreGratuit.MouseButton1Click:Connect(function()
	local r = Boutique:InvokeServer("coffreGratuit")
	afficher(r.vue)
	messageEvenements.Text = r.ok and "Coffre gratuit recupere !" or ("Refus : " .. tostring(r.motif))
	Sons.jouer(r.ok and "coffre" or "refus")
end)

-- Appelee par `afficher` (declaree avant elle : la variable est posee plus haut dans le fichier).
majQuetes = function(v)
	local e = v and v.evenements
	if not e then
		return
	end
	for i, l in ipairs(lignesQuetes) do
		local q = e.quetes[i]
		if q then
			l.id = q.id
			l.ligne.Text = q.texte .. "   " .. q.fait .. " / " .. q.cible .. (q.recue and "   (recue)" or "")
			l.jauge.Size = UDim2.new(q.fait / math.max(q.cible, 1), 0, 1, 0)
			l.action.Visible = q.finie and not q.recue
			l.action.Text = "+" .. q.gain
			l.ligne.TextColor3 = q.recue and Color3.fromRGB(130, 140, 155) or Color3.fromRGB(215, 222, 235)
		else
			l.id = nil
			l.ligne.Text = ""
			l.action.Visible = false
		end
	end
	local reste = e.coffreGratuitReste or 0
	if reste <= 0 then
		infoCoffreGratuit.Text = "Un coffre d'argent t'attend."
		boutonCoffreGratuit.BackgroundColor3 = Color3.fromRGB(230, 150, 30)
		boutonCoffreGratuit.Text = "RECUPERER"
	else
		infoCoffreGratuit.Text = string.format("Prochain coffre dans %dh%02d", reste // 3600, (reste % 3600) // 60)
		boutonCoffreGratuit.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		boutonCoffreGratuit.Text = "PAS ENCORE"
	end
end

majEvenements = function()
	if not vue then
		return
	end
	bonusVal.Text = vue.bonusDispo and "+50" or "PRIS"
	bonusDet.Text = vue.bonusDispo and "pieces a reclamer" or "reviens demain"
	local serie = vue.serie or 0
	serieVal.Text = tostring(serie)
	serieDet.Text = serie >= 2 and ("+" .. math.min(serie - 1, vue.serieMax or 5) * 10 .. " pieces par victoire")
		or "enchaine 2 victoires"
	local prets, encours = 0, 0
	-- boucle numerique 1..4 et pas ipairs : les 4 emplacements peuvent avoir des trous
	-- (emplacement libre = nil) et ipairs s'arreterait au premier, sous-comptant les coffres.
	for i = 1, 4 do
		local c = (vue.coffres or {})[i]
		if c and c.fin ~= 0 and c.fin <= (os.time() + decalageHorloge) then
			prets += 1
		elseif c and c.fin ~= 0 then
			encours += 1
		end
	end
	coffresVal.Text = tostring(prets)
	coffresDet.Text = prets > 0 and "prets a ouvrir" or (encours .. " en cours d'ouverture")
end

-- BARRE DU BAS
local ONGLETS = {
	{ nom = "boutique", titre = "BOUTIQUE", cadre = boutique, teinte = Color3.fromRGB(70, 110, 220) },
	{ nom = "cartes", titre = "CARTES", cadre = deckEcran, teinte = Color3.fromRGB(140, 80, 200) },
	{ nom = "bataille", titre = "BATAILLE", cadre = accueil, teinte = Color3.fromRGB(60, 170, 80) },
	{ nom = "clan", titre = "CLAN", cadre = clanEcran, teinte = Color3.fromRGB(40, 150, 170) },
	{ nom = "evenements", titre = "EVENEMENTS", cadre = evenementsEcran, teinte = Color3.fromRGB(200, 120, 40) },
}

barreOnglets = Instance.new("Frame")
barreOnglets.Size = UDim2.new(1, 0, HAUTEUR_BARRE, 0)
barreOnglets.Position = UDim2.new(0, 0, 1 - HAUTEUR_BARRE, 0)
barreOnglets.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
barreOnglets.BorderSizePixel = 0
barreOnglets.ZIndex = 5
barreOnglets.Parent = gui
-- La barre n'est plus un aplat : degrade sombre + liseré dore en haut, comme la barre du jeu
-- de reference. Le liseré est un cadre fin, pas une image : aucun asset a fournir.
degrade(barreOnglets, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 130))
liseraBarre = Instance.new("Frame")
liseraBarre.Size = UDim2.new(1, 0, 0, 3)
liseraBarre.BackgroundColor3 = OR
liseraBarre.BorderSizePixel = 0
liseraBarre.ZIndex = 7
liseraBarre.Position = UDim2.new(0, 0, 1 - HAUTEUR_BARRE, 0)
liseraBarre.Parent = gui
local layoutBarre = Instance.new("UIListLayout")
layoutBarre.FillDirection = Enum.FillDirection.Horizontal
layoutBarre.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutBarre.VerticalAlignment = Enum.VerticalAlignment.Center
layoutBarre.Parent = barreOnglets

local ongletActif = "bataille"
for _, o in ipairs(ONGLETS) do
	o.bouton = bouton(barreOnglets, o.titre, UDim2.new(0.2, 0, 1, 0), UDim2.new(), o.teinte)
	o.bouton.ZIndex = 6
	-- fix-ok: TextScaled seul etire le libelle jusqu'aux bords du bouton ; sans marge interne les
	-- cinq titres se touchent (capture du 2026-09-20 : « BOUTIQUECARTES » colles, EVENEMENTS coupe).
	-- La marge cree la gouttiere, le plafond de taille empeche le titre court de devenir enorme.
	local marge = Instance.new("UIPadding")
	marge.PaddingLeft = UDim.new(0, 6)
	marge.PaddingRight = UDim.new(0, 6)
	marge.PaddingTop = UDim.new(0, 8)
	marge.PaddingBottom = UDim.new(0, 8)
	marge.Parent = o.bouton
	local plafond = Instance.new("UITextSizeConstraint")
	plafond.MaxTextSize = 18
	plafond.Parent = o.bouton
end

-- FOND DES ECRANS : degrade profond au lieu de l'aplat unique, et contour dore discret.
for _, cadre in ipairs({ accueil, boutique, deckEcran, clanEcran, evenementsEcran }) do
	cadre.BackgroundColor3 = Color3.fromRGB(38, 44, 86)
	cadre.BackgroundTransparency = 0
	degrade(cadre, Color3.fromRGB(255, 255, 255), Color3.fromRGB(70, 74, 120))
end

-- BANDEAU RESSOURCES : pieces et trophees toujours visibles en haut, comme dans le jeu de
-- reference. Les ecrans descendent d'autant pour ne pas passer dessous.
local HAUTEUR_BANDEAU = 0.085
bandeau = Instance.new("Frame")
bandeau.Size = UDim2.new(1, 0, HAUTEUR_BANDEAU, 0)
bandeau.BackgroundColor3 = Color3.fromRGB(26, 30, 56)
bandeau.BorderSizePixel = 0
bandeau.ZIndex = 8
bandeau.Parent = gui
degrade(bandeau, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 124, 160))
local liseraHaut = Instance.new("Frame")
liseraHaut.Size = UDim2.new(1, 0, 0, 3)
liseraHaut.Position = UDim2.new(0, 0, 1, -3)
liseraHaut.BackgroundColor3 = OR
liseraHaut.BorderSizePixel = 0
liseraHaut.ZIndex = 9
liseraHaut.Parent = bandeau

-- LARGEUR_JETON : trois jetons (pieces, gemmes, trophees) doivent tenir a droite du nom du
-- joueur. A 0.18 de large places a 0.40 / 0.60 / 0.80, le dernier finit a 0.98 : ca rentre.
local LARGEUR_JETON = 0.18
local function jeton(x, couleur, symbole)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(LARGEUR_JETON, 0, 0.62, 0)
	f.Position = UDim2.new(x, 0, 0.19, 0)
	f.BackgroundColor3 = Color3.fromRGB(18, 20, 36)
	f.ZIndex = 9
	f.Parent = bandeau
	coin(f, 14)
	contour(f, 2, couleur, 0.25)
	local pastille = Instance.new("Frame")
	pastille.Size = UDim2.new(0, 26, 0, 26)
	pastille.Position = UDim2.new(0, 8, 0.5, -13)
	pastille.BackgroundColor3 = couleur
	pastille.ZIndex = 10
	pastille.Parent = f
	coin(pastille, 13)
	contour(pastille, 2)
	local sym = texte(pastille, symbole, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(30, 26, 10))
	sym.ZIndex = 11
	local val = texte(f, "0", UDim2.new(1, -46, 1, -8), UDim2.new(0, 40, 0, 4), Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	val.ZIndex = 10
	local plafond = Instance.new("UITextSizeConstraint")
	plafond.MaxTextSize = 22
	plafond.Parent = val
	return val
end

-- a droite : le coin haut-gauche est pris par le menu Roblox. Les GEMMES (monnaie premium deja
-- servie par le serveur, champ `gemmes` de la vue) manquaient au bandeau : elles s'intercalent
-- entre les pieces et les trophees, et les trois x ont ete re-repartis pour leur faire la place.
local valPieces = jeton(0.40, OR, "$")
local valGemmes = jeton(0.60, Color3.fromRGB(80, 210, 160), "G")
local valTrophees = jeton(0.80, Color3.fromRGB(235, 90, 110), "T")
local nomJoueur = texte(bandeau, player.DisplayName, UDim2.new(0.18, 0, 0.5, 0), UDim2.new(0.20, 0, 0.25, 0), OR)
nomJoueur.ZIndex = 9
local plafondNom = Instance.new("UITextSizeConstraint")
plafondNom.MaxTextSize = 24
plafondNom.Parent = nomJoueur

majBandeau = function(v)
	valPieces.Text = tostring(v.pieces)
	valGemmes.Text = tostring(v.gemmes or 0)
	valTrophees.Text = tostring(v.trophees)
end

-- Les ecrans occupent la bande entre le bandeau et la barre du bas.
for _, cadre in ipairs({ accueil, boutique, deckEcran, clanEcran, evenementsEcran }) do
	cadre.Position = UDim2.new(0, 0, HAUTEUR_BANDEAU, 0)
	cadre.Size = UDim2.new(1, 0, 1 - HAUTEUR_BANDEAU - HAUTEUR_BARRE, 0)
end

majOnglets = function(nom)
	ongletActif = nom or ongletActif
	barreOnglets.Visible = true
	liseraBarre.Visible = true
	bandeau.Visible = true
	boutonMenu.Visible = false
	for _, o in ipairs(ONGLETS) do
		local actif = (o.nom == ongletActif)
		o.cadre.Visible = actif
		o.bouton.BackgroundColor3 = actif and o.teinte or Color3.fromRGB(38, 42, 60)
		o.bouton.TextColor3 = actif and Color3.new(1, 1, 1) or Color3.fromRGB(165, 175, 195)
	end
end

-- Chaque onglet REJOUE le clic du bouton d'origine quand il en existait un : le chargement des
-- donnees (profil, deck, classement) reste au meme endroit, on ne duplique pas cette logique.
for _, o in ipairs(ONGLETS) do
	o.bouton.MouseButton1Click:Connect(function()
		if ongletActif == o.nom then
			return
		end
		if o.nom == "boutique" then
			ouvrirEcranBoutique()
		elseif o.nom == "cartes" then
			ouvrirEcranDeck()
		else
			Sons.jouer("clic")
			afficher(Boutique:InvokeServer("profil").vue)
			if o.nom == "clan" then
				task.spawn(function()
					majClassement(Boutique:InvokeServer("classement").classement)
				end)
			end
		end
		-- majOnglets vient APRES le chargement : ouvrirEcranBoutique / ouvrirEcranDeck rendent la
		-- main a l'accueil, donc un appel place AVANT serait aussitot annule. Un seul appel suffit.
		majOnglets(o.nom)
	end)
end

-- Le bonus ecrit sa reponse dans `message` (accueil) : on la recopie dans l'onglet EVENEMENTS.
task.spawn(function()
	while true do
		task.wait(0.4)
		if evenementsEcran.Visible then
			if message.Text ~= "" then
				messageEvenements.Text = message.Text
			end
			-- rappel : la premiere vue arrive avant la construction de cet onglet, et le compte a
			-- rebours du coffre gratuit doit descendre tout seul.
			if vue then
				majQuetes(vue)
			end
		end
	end
end)

if test and not forcerHub then
	accueil.Visible = false
	boutonMenu.Visible = true
	barreOnglets.Visible = false
	liseraBarre.Visible = false
	bandeau.Visible = false
	print("[HUB] copie de test : hub ferme")
else
	ouvrirAccueil()
	-- Arrive par la recherche d'adversaire (serveur reserve) : le match commence, pas d'accueil.
	if Boutique:InvokeServer("enMatch").ok then
		accueil.Visible = false
		boutonMenu.Visible = true
		if barreOnglets then barreOnglets.Visible = false end
		liseraBarre.Visible = false
		bandeau.Visible = false
		Sons.boucle("combat")
	end
	if ReplicatedStorage:FindFirstChild("BRR_BOUTIQUE") then
		majOnglets("boutique")
	end
	if ReplicatedStorage:FindFirstChild("BRR_DECK") then
		-- meme chemin que le bouton DECK, pour que la capture montre l'ecran REEL
		majOnglets("cartes")
		chargerChoix()
		majDeck()
	end
	-- Crochet de capture generique : BRR_ONGLET nomme l'onglet a ouvrir (clan, evenements...).
	local ongletDemande = ReplicatedStorage:FindFirstChild("BRR_ONGLET")
	if ongletDemande and ongletDemande.Value ~= "" then
		majOnglets(ongletDemande.Value)
		afficher(Boutique:InvokeServer("profil").vue)
		if ongletDemande.Value == "clan" then
			task.spawn(function()
				majClassement(Boutique:InvokeServer("classement").classement)
			end)
		end
	end
	print("[HUB] accueil ouvert")
end
