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
-- Saison : numero, temps restant et SOMMET atteint — tout etait envoye, rien n'etait affiche.
local Saison = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Saison"))
-- Prive : code de duel entre amis (regles pures, tools/test_duel_prive.py).
local Prive = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prive"))
-- Egalise : duel ou les deux camps passent au meme niveau de cartes.
local Egalise = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Egalise"))
-- Adversaire : dire si on attend un humain ou si le robot arrive.
local Adversaire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Adversaire"))
-- FICHES : ce que fait une carte, DEDUIT de ses donnees (tools/test_fiche.py).
local Fiche = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fiche"))
-- Sorts : le rendement d'un sort de degats, affiche sur sa fiche.
local Sorts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sorts"))
-- SPECIALITE et SOUTIEN sont declares par identifiant dans leurs propres modules (regles de
-- COMBAT, pas donnees de carte) : on les lit ici et on les passe a la fiche.
local Specialite = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Specialite"))
local Soutien = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Soutien"))
-- DESCENDANCE et RECUL : memes regles de combat declarees par identifiant, meme traitement.
local Descendance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Descendance"))
local Recul = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Recul"))
-- REGLES COMMUNES : ce qui vaut pour toutes les cartes (elixir double, prolongation, zone de
-- pose, avantage de terrain). Les textes sont calcules par Manuel a partir de ces constantes.
local Regles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regles"))
local Terrain = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terrain"))
local Manuel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Manuel"))
-- Lecture : le panneau « lire l'adversaire » du jeu, dont le manuel explique le fonctionnement.
local Lecture = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lecture"))
-- Journal : les dernieres parties du joueur (tools/test_journal.py).
local Journal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Journal"))
-- Cycle : le diagnostic du deck (cout moyen, reponses aux volants) — regles pures.
local Cycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cycle"))
-- TUTORIEL : la regle de fin (la partie d'apprentissage se termine, le menu revient tout seul).
local Tutoriel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tutoriel"))
-- MiseMenu : positions de l'accueil en DONNEES, verifiees par tools/test_menu.py. Poser un bloc a
-- la main a deja produit une rangee de coffres qui recouvrait le duel prive (capture 2026-09-21).
local MiseMenu = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MiseMenu"))
-- Duree d'une partie : elle vit dans le SERVEUR (GameServer : MATCH_TIME) et le hub n'y a pas
-- acces. Le banc tools/test_manuel.py compare les deux et rougit si elles divergent : c'est ce
-- controle, et non ce commentaire, qui garantit que l'ecran ne ment pas.
local DUREE_MATCH_AFFICHEE = 180
local function extrasDe(id)
	-- Le module BATIMENTS est charge ICI, dans la fonction, et non en variable du fichier : le
	-- corps principal de ce script est EXACTEMENT au plafond des 200 variables locales de Lua
	-- (mesure du 2026-09-20 : « Out of local registers », le menu ne se chargeait plus). Les
	-- variables d'une fonction ont leur propre compte, et `require` est mis en cache par Roblox.
	local Batiments = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Batiments"))
	-- `noms` : la fiche ecrit « laisse 2 Trippi Troppi » et non l'identifiant brut.
	local noms = {}
	for _, c in ipairs(Cards.list) do
		noms[c.id] = c.name
	end
	return {
		specialite = Specialite.profil(id), soutien = Soutien.profil(id),
		descendance = Descendance.profil(id), recul = Recul.profil(id), noms = noms,
		-- RENDEMENT D'UN SORT : la regle vit dans Sorts, la fiche ne fait que l'afficher.
		rendementSort = Cards.byId[id] and Sorts.degatsParElixir(Cards.byId[id]) or nil,
		-- CHARGE et ASSASSIN : deux regles de combat qui changent la facon de jouer la carte et
		-- qui n'etaient sur AUCUNE fiche. Modules charges ICI, dans la fonction : le corps de ce
		-- script est au plafond des 200 variables locales de Lua.
		charge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Charge")).profil(id),
		-- POINT FORT : la place de ses chiffres dans le catalogue reel (« la plus longue portee
		-- du jeu »). Calcule par Reperes, jamais ecrit a la main.
		pointFort = (function()
			local R = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reperes"))
			return R.texte(R.points(Cards.byId[id], Cards.list))
		end)(),
		assassin = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Assassin")).estAssassin(id) or nil,
		-- RENTABILITE D'UN COLLECTEUR : la regle vit dans Batiments, la fiche ne fait que l'ecrire.
		rentabilite = Cards.byId[id] and Batiments.texteRentabilite(Cards.byId[id]) or nil,
	}
end
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

-- Ces quatre elements tiennent dans UNE table : le corps du fichier touche la limite de Lua
-- (200 variables locales), et chaque nouvel element d'ecran doit desormais se regrouper.
local montee = {}
-- RAPPEL DU COFFRE GRATUIT, range DANS `montee` (les reperes de progression de l'accueil) et non
-- dans ses propres variables : ce fichier est EXACTEMENT a 200 locales, le plafond de Lua. Une
-- seule locale de plus et le menu ne se chargeait PLUS DU TOUT — journal Studio du 2026-09-20 :
-- « Hub:2432: Out of local registers ... exceeded limit 200 », capture a l'appui (le joueur
-- tombait sur l'ecran de match au lieu du menu).
montee.rappel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rappel"))
-- Declaree ICI et non a cote de sa construction : `afficher`, plus haut, l'utilise.
local finSaison = {}
-- BARRE DE MONTEE EN ARENE. `Arenes.progression` rend la part du chemin parcouru entre le palier
-- actuel et le suivant (0 a 1) : elle etait ecrite, testee... et appelee par PERSONNE. La ligne de
-- texte disait bien « Vallee du couchant dans 40 trophees », mais un chiffre ne se compare pas
-- d'un coup d'oeil : on ne voyait pas si l'on etait au debut du palier ou a deux victoires de la
-- montee. La barre le montre sans lire.
-- NOM DU PALIER ET CHEMIN RESTANT. La ligne de profil qui les portait est passee invisible quand
-- le bandeau permanent a repris les soldes (« remplacee par le bandeau ressources ») : le bandeau
-- montre les trophees, mais plus l'ARENE ni ce qu'il reste a faire pour monter. L'information
-- avait disparu de l'ecran sans que personne ne s'en apercoive.
montee.arene = texte(accueil, "", UDim2.new(0.8, 0, 0.035, 0), UDim2.new(0.1, 0, 0.222, 0),
	Color3.fromRGB(230, 214, 170))
montee.arene.TextScaled = false
montee.arene.TextSize = 15

-- LIGNE DE SAISON, sous la barre d'arene. Le numero, le temps restant et le sommet etaient
-- calcules et envoyes au menu, mais affiches NULLE PART : le joueur decouvrait la remise a zero
-- de ses trophees sans avoir jamais su qu'une saison tournait.
montee.saison = texte(accueil, "", UDim2.new(0.8, 0, 0.03, 0), UDim2.new(0.1, 0, 0.192, 0),
	Color3.fromRGB(175, 190, 215))
montee.saison.TextScaled = false
montee.saison.TextSize = 13

-- BADGE DE LIGUE (2026-09-21) : losange a la couleur de la ligue, sa lettre, et « Ligue Or
-- 1640 / 2200 » a cote. Les arenes s'arretent a 2000 trophees ; la ligue donne un but au-dela.
montee.ligue = {}
do
	local l = montee.ligue
	l.cadre = Instance.new("Frame")
	l.cadre.Name = "Ligue"
	l.cadre.BackgroundTransparency = 1
	l.cadre.Parent = accueil
	MiseMenu.placer(l.cadre, MiseMenu.ACCUEIL.ligue, UDim2)
	l.badge = Instance.new("Frame")
	l.badge.Name = "BadgeLigue"
	l.badge.AnchorPoint = Vector2.new(0.5, 0.5)
	l.badge.SizeConstraint = Enum.SizeConstraint.RelativeYY
	l.badge.Size = UDim2.fromScale(0.62, 0.62)
	l.badge.Position = UDim2.fromScale(0.15, 0.5) -- meme centre que la lettre
	l.badge.Rotation = 45
	l.badge.Parent = l.cadre
	coin(l.badge, 5)
	contour(l.badge, 3, Color3.fromRGB(12, 14, 24), 0)
	degrade(l.badge, Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120))
	-- lettre : soeur du losange (un enfant tournerait avec lui), meme centre
	l.lettre = texte(l.cadre, "", UDim2.fromScale(0.3, 0.5), UDim2.fromScale(0, 0.25))
	l.lettre.ZIndex = 3
	l.nom = texte(l.cadre, "", UDim2.fromScale(0.66, 0.5), UDim2.fromScale(0.34, 0.02),
		Color3.fromRGB(235, 225, 190), Enum.TextXAlignment.Left)
	l.texte = texte(l.cadre, "", UDim2.fromScale(0.66, 0.4), UDim2.fromScale(0.34, 0.54),
		Color3.fromRGB(200, 205, 220), Enum.TextXAlignment.Left)
end
-- 5e ligne du bilan de saison : la ligue avant / apres la remise a zero
function montee.ligneSaison(bilan)
	local Ligues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ligues"))
	return Ligues.ligneSaison(bilan.avant, bilan.apres)
end

montee.fond = Instance.new("Frame")
montee.fond.Size = UDim2.new(0.44, 0, 0.022, 0)
montee.fond.Position = UDim2.new(0.28, 0, 0.262, 0)
montee.fond.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
montee.fond.BorderSizePixel = 0
montee.fond.Parent = accueil
coin(montee.fond, 6)
montee.fond.ClipsDescendants = true
montee.jauge = Instance.new("Frame")
montee.jauge.Size = UDim2.new(0, 0, 1, 0)
montee.jauge.BackgroundColor3 = OR
montee.jauge.BorderSizePixel = 0
montee.jauge.Parent = montee.fond

ligneProfil.Visible = false -- remplacee par le bandeau ressources permanent, en haut.
local boutonJouer = bouton(accueil, "JOUER", UDim2.new(0.34, 0, 0.13, 0), UDim2.new(0.33, 0, 0.38, 0), Color3.fromRGB(60, 170, 80))
-- ATTENDRE UN HUMAIN. La bascule vers le robot a 20 s etait SUBIE : ce reglage la repousse, et
-- le bouton « JOUER CONTRE LE ROBOT » ci-dessous permet d'en sortir a tout moment.
local attendreHumain = false
local boutonPatience = bouton(accueil, "SI PERSONNE : ROBOT", UDim2.new(0.24, 0, 0.045, 0), UDim2.new(0.515, 0, 0.665, 0), Color3.fromRGB(60, 85, 110))
boutonPatience.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	attendreHumain = not attendreHumain
	boutonPatience.Text = attendreHumain and "SI PERSONNE : J'ATTENDS" or "SI PERSONNE : ROBOT"
	-- Le reglage dit ce qu'il CHANGE : une victoire contre un joueur rapporte un bonus (vue serveur).
	message.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Adversaire"))
		.texteAttente(attendreHumain, vue and vue.bonusHumain, vue and vue.partRobot)
end)

-- ANNULER LA RECHERCHE. Une fois JOUER presse, le joueur etait PRISONNIER de l'attente : aucun
-- moyen de revenir au menu, et un second appui relancait une deuxieme boucle d'attente sur le
-- meme joueur. Ce bouton sort de la file, et JOUER se desactive pendant la recherche.
local boutonAnnuler = bouton(accueil, "ANNULER LA RECHERCHE", UDim2.new(0.22, 0, 0.06, 0), UDim2.new(0.27, 0, 0.515, 0), Color3.fromRGB(150, 70, 70))
boutonAnnuler.Visible = false
-- SORTIE DE SECOURS pendant l'attente : prendre le robot maintenant, sans annuler ni recommencer.
local boutonRobotVite = bouton(accueil, "JOUER CONTRE LE ROBOT", UDim2.new(0.22, 0, 0.06, 0), UDim2.new(0.51, 0, 0.515, 0), Color3.fromRGB(95, 80, 60))
boutonRobotVite.Visible = false
-- BOUTIQUE et DECK cote a cote sur la ligne du milieu (l'accueil garde la meme hauteur)
-- Plus de boutons BOUTIQUE / DECK sur l'accueil : la barre d'onglets du bas les remplace.
-- REVOIR LE TUTORIEL : discret, sous le bouton JOUER. Le tutoriel est impose a la premiere
-- partie ; ce bouton sert a le rejouer ensuite. Le serveur arme la relance, la partie suivante
-- le joue (action « tutoriel »).
-- Pose en HAUT A DROITE : a 0.525 il passait DERRIERE la rangee de coffres et n'etait plus
-- qu'un fragment de lettres (capture cap-tuto-bouton.png). Ce coin est la seule zone libre.
-- La DUREE est annoncee sur le bouton : sans elle, on ne sait pas si on s'engage pour une minute
-- ou pour dix, et dans le doute on ne clique pas. Le chiffre vient du module, pas d'un texte ecrit
-- a la main : ajouter une etape au tutoriel changera ce libelle tout seul.
local boutonTuto = bouton(accueil, "REVOIR LE TUTORIEL - " .. Tutoriel.texteDuree(), UDim2.new(0.19, 0, 0.055, 0), UDim2.new(0.79, 0, 0.045, 0), Color3.fromRGB(70, 80, 120))
boutonTuto.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local r = Boutique:InvokeServer("tutoriel")
	message.Text = r.ok and ("Tutoriel arme : lance une partie pour le revoir (" .. Tutoriel.texteDuree(true) .. ").")
		or ("Tutoriel : " .. tostring(r.motif))
	afficher(r.vue)
end)

local boutonBonus = bouton(accueil, "BONUS DU JOUR", UDim2.new(0.34, 0, 0.07, 0), UDim2.new(0.33, 0, 0.66, 0), Color3.fromRGB(200, 120, 40))
-- REGLES DU JEU : l'ecran est construit plus bas (il a besoin des modules de regles) ; le clic
-- y est branche a ce moment-la, d'ou la variable avancee.
local ouvrirRegles
-- Sous REVOIR LE TUTORIEL, en haut a droite : c'est la seule bande libre de l'accueil. Place
-- au centre (0,745), il passait DERRIERE la rangee de coffres et « TON DECK » — invisible,
-- donc inutilisable (capture cap-regles-bouton.png du 2026-09-20).
local boutonRegles = bouton(accueil, "REGLES DU JEU", UDim2.new(0.19, 0, 0.055, 0),
	UDim2.new(0.79, 0, 0.115, 0), Color3.fromRGB(70, 90, 150))
boutonRegles.MouseButton1Click:Connect(function()
	if ouvrirRegles then
		ouvrirRegles()
	end
end)
local ouvrirJournal
-- DERNIERES PARTIES : troisieme bouton de la meme colonne libre, sous REGLES DU JEU. Le profil ne
-- gardait que deux compteurs (parties, victoires) : rien ne disait si ca allait mieux ou moins
-- bien en ce moment, ni contre qui la derniere partie s'etait jouee.
local boutonJournal = bouton(accueil, "DERNIERES PARTIES", UDim2.new(0.19, 0, 0.055, 0),
	UDim2.new(0.79, 0, 0.185, 0), Color3.fromRGB(60, 110, 120))
boutonJournal.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	if ouvrirJournal then
		ouvrirJournal()
	end
end)
local ouvrirSon
local basculerSon -- le GESTE du bouton MUSIQUE / BRUITAGES, partage avec le crochet de capture
-- SON : quatrieme bouton de la colonne. Defaut mesure le 2026-09-20 : musique et bruitages se
-- jouaient sans qu'aucun ecran ne permette de les couper. Un joueur qui ecoute autre chose, ou
-- qui joue a cote de quelqu'un, devait couper le son de tout son appareil.
local boutonSon = bouton(accueil, "SON", UDim2.new(0.19, 0, 0.055, 0),
	UDim2.new(0.79, 0, 0.255, 0), Color3.fromRGB(95, 85, 60))
boutonSon.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	if ouvrirSon then
		ouvrirSon()
	end
end)
local message = texte(accueil, "", UDim2.new(0.8, 0, 0.04, 0), UDim2.new(0.1, 0, 0.56, 0), OR)
-- COFFRE GRATUIT : un coffre est offert toutes les 4 h, et RIEN ne le disait hors du fond de
-- l'onglet EVENEMENTS. On le dit a l'accueil, la ou le joueur passe entre deux parties.
-- Pleine largeur SOUS la ligne de profil : a gauche (0,02 / 0,73) le texte etait coupe net et
-- passait sous les coffres (capture cap-coffre4.png du 2026-09-20).
montee.coffreLigne = texte(accueil, "", UDim2.new(0.8, 0, 0.035, 0), UDim2.new(0.1, 0, 0.325, 0),
	Color3.fromRGB(255, 190, 70))

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
-- REMONTEE AUTREFOIS « DANS L'ESPACE LIBRE SOUS JOUER » — qui ne l'etait pas : le duel prive et
-- « SI PERSONNE : ROBOT » s'y trouvaient deja, et passaient SOUS les coffres (capture 2026-09-21).
-- Toutes les positions de l'accueil viennent desormais de MiseMenu, verifie par tools/test_menu.py.
rangee.Parent = accueil
MiseMenu.placer(rangee, MiseMenu.ACCUEIL.coffres, UDim2)
MiseMenu.placer(boutonJouer, MiseMenu.ACCUEIL.jouer, UDim2)
MiseMenu.placer(boutonAnnuler, MiseMenu.ACCUEIL.annuler, UDim2)
MiseMenu.placer(boutonRobotVite, MiseMenu.ACCUEIL.robotVite, UDim2)
MiseMenu.placer(boutonPatience, MiseMenu.ACCUEIL.patience, UDim2)
MiseMenu.placer(message, MiseMenu.ACCUEIL.message, UDim2)
MiseMenu.placer(ligneInfo, MiseMenu.ACCUEIL.info, UDim2)
MiseMenu.placer(montee.saison, MiseMenu.ACCUEIL.saison, UDim2)
MiseMenu.placer(montee.arene, MiseMenu.ACCUEIL.arene, UDim2)
MiseMenu.placer(montee.coffreLigne, MiseMenu.ACCUEIL.coffreLigne, UDim2)
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

-- REGLES PENDANT LA PARTIE. Defaut mesure le 2026-09-20 : le manuel n'existait qu'au menu, donc
-- il ne pouvait etre lu qu'a froid — jamais au moment ou la question se pose (« pourquoi l'elixir
-- va-t-il deux fois plus vite ? », « pourquoi ne puis-je pas poser la ? »). Pour le consulter, il
-- fallait QUITTER la partie, c'est-a-dire l'abandonner. Le panneau vit deja dans cet ecran (il
-- n'est pas un enfant de l'accueil) : il suffisait de le rendre atteignable a cote de MENU.
-- Le clic ne pose AUCUNE carte : GameClient ignore les gestes que l'interface a deja traites
-- (garde `processed`), donc lire les regles ne gaspille ni carte ni elixir.
local boutonAide = bouton(gui, "REGLES", UDim2.new(0, 110, 0, 44), UDim2.new(0, 130, 0, 12), Color3.fromRGB(58, 52, 96))
boutonAide.Visible = false
boutonAide.MouseButton1Click:Connect(function()
	if ouvrirRegles then
		ouvrirRegles()
	end
end)
-- Il apparait et disparait AVEC le bouton MENU : les deux ne valent que pendant la partie. Se
-- brancher sur sa visibilite evite d'oublier un des huit endroits qui la changent.
-- SON EN PARTIE : c'est la, plus qu'au menu, qu'on veut couper la musique sans quitter.
local boutonSonJeu = bouton(gui, "SON", UDim2.new(0, 90, 0, 44), UDim2.new(0, 248, 0, 12), Color3.fromRGB(95, 85, 60))
boutonSonJeu.Visible = false
boutonSonJeu.MouseButton1Click:Connect(function()
	if ouvrirSon then
		ouvrirSon()
	end
end)
boutonMenu:GetPropertyChangedSignal("Visible"):Connect(function()
	boutonAide.Visible = boutonMenu.Visible
	boutonSonJeu.Visible = boutonMenu.Visible
end)

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
-- CE QUI RESTE A PRENDRE, et CE QUE LA PROCHAINE ARENE OUVRIRA. La boutique n'affichait que le
-- solde : devant 47 tuiles, le joueur ne savait ni ce qu'il peut s'offrir maintenant, ni ce qui
-- l'attend plus haut. Deux lignes sous le solde, a gauche pour ne pas toucher le titre centre.
montee.boutiquePortee = texte(boutique, "", UDim2.new(0.44, 0, 0.038, 0), UDim2.new(0.02, 0, 0.035, 0),
	Color3.fromRGB(255, 205, 110), Enum.TextXAlignment.Left)
montee.boutiqueArene = texte(boutique, "", UDim2.new(0.44, 0, 0.034, 0), UDim2.new(0.02, 0, 0.078, 0),
	Color3.fromRGB(175, 185, 205), Enum.TextXAlignment.Left)
local fermer = bouton(boutique, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 12), Color3.fromRGB(170, 50, 50))

-- Grilles DEFILANTES (2026-09-16) : le catalogue a grossi a 15 cartes et la grille debordait
-- sous le bouton ENREGISTRER (vu sur capture-deck2.png). Une hauteur figee ne tient que pour un
-- nombre de cartes donne ; le defilement tient pour n'importe lequel.
-- Les cellules sont en Scale, donc mesurees sur la partie VISIBLE du cadre : le canevas vaut
-- (nombre de rangees x hauteur de rangee), ce qui depasse 1 des qu'il y a plus de rangees que
-- l'ecran n'en montre.
local COLONNES = 4
-- `marge` (pixels, optionnelle) : marge INTERIEURE. Le ScrollingFrame rogne tout ce qui depasse, et un
-- contour de tuile se dessine a l'EXTERIEUR : sans marge, la bordure de la 1re rangee etait coupee
-- (photo de l'onglet CARTES du 2026-09-21).
local function grilleDefilante(parent, taille, position, hauteurCellule, ecartVertical, marge)
	local cadre = Instance.new("ScrollingFrame")
	cadre.BackgroundTransparency = 1
	cadre.BorderSizePixel = 0
	cadre.Size = taille
	cadre.Position = position
	cadre.ScrollBarThickness = 8
	cadre.ScrollBarImageColor3 = OR
	cadre.CanvasSize = UDim2.new()
	cadre.Parent = parent
	marge = marge or 0
	if marge > 0 then
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, marge)
		pad.PaddingBottom = UDim.new(0, marge)
		pad.PaddingLeft = UDim.new(0, marge)
		pad.PaddingRight = UDim.new(0, marge + 8) -- + la barre de defilement
		pad.Parent = cadre
	end
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
		local h = cadre.AbsoluteSize.Y - 2 * marge -- hauteur UTILE, marges retirees
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
		cadre.CanvasSize = UDim2.new(0, 0, 0, rangees * (cellPx + ecartPx) - ecartPx + 2 * marge)
	end
	caler()
	cadre:GetPropertyChangedSignal("AbsoluteSize"):Connect(caler)
	layout.Parent = cadre
	return cadre
end

-- La grille descend jusqu'aux offres Robux : la bande 0.80 -> 0.97 etait un grand vide quand
-- aucune offre n'est configuree (capture cap-v3-boutique.png). Trois rangees ENTIERES tiennent
-- dans la zone visible (1 / (0.30 + 0.03) ~ 3), donc plus de carte coupee en bas.
-- Tuile portee de 0,30 a 0,36 de haut : il fallait la place pour dire ce que la carte FAIT
-- (bouclier, poison, gel...). Jusqu'ici la tuile ne montrait que son nom et son prix.
-- marge 5 px : meme rognage de la bordure de la 1re rangee que dans la collection (photo du 2026-09-21)
local grille = grilleDefilante(boutique, UDim2.new(0.94, 0, 0.72, 0), UDim2.new(0.03, 0, 0.18, 0), 0.36, 0.03, 5)

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

-- Module des coffres charge DANS la fonction : le corps de ce script est au plafond des 200
-- variables locales de Lua (mesure du 2026-09-20, le menu ne se chargeait plus).
local function majCoffres()
	if not vue then
		return
	end
	local Coffres = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Coffres"))
	local maintenant = os.time() + decalageHorloge
	-- EMPLACEMENTS PLEINS : la prochaine victoire ne rapportera pas de coffre. C'etait perdu en
	-- silence ; l'accueil le dit AVANT la partie, avec ce qu'il faut faire.
	if montee.coffresPleins then
		local n = 0
		for i = 1, 4 do
			if vue.coffres[i] then
				n = n + 1
			end
		end
		montee.coffresPleins.Text = Coffres.alertePlein(n, 4)
	end
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
			if e.detail then
				e.detail.Text = ""
			end
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
			-- Les chiffres viennent du serveur (vue.coffresInfos), la mise en mots du module.
			if e.detail then
				local info = vue.coffresInfos and vue.coffresInfos[c.type]
				-- Deux lignes : ce qu'il contient, puis ce qu'il fait attendre.
				local suite = ""
				if info then
					suite = "\n" .. Coffres.duree(info.duree) .. " d'attente"
				end
				e.detail.Text = Coffres.ligne(info) .. suite
			end
			e.etat.BackgroundTransparency = 0.2
			local stP = e.etat:FindFirstChildOfClass("UIStroke")
			if stP then stP.Enabled = true end
			if c.fin == 0 then
				e.etat.Text = Coffres.etatAttente(Coffres.unEnCours(vue.coffres, maintenant))
			elseif c.fin > maintenant then
				e.etat.Text = Coffres.texteEnCours(c.fin - maintenant, vue.sansAleatoirePayant)
				if not Coffres.doitConfirmer(montee.confirmeCoffre, i, maintenant) then
					e.etat.Text = Coffres.texteConfirmer(c.fin - maintenant)
				end
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

-- FIN DU TUTORIEL : un joueur neuf vient d'apprendre a POSER une carte, mais rien ne lui a dit
-- ce qui decide vraiment une partie (elixir double, prolongation, terrain, zone de pose). Le
-- moment ou il revient du tutoriel est le SEUL ou il est disponible pour le lire : plus tard, il
-- enchaine les parties et n'ouvrira jamais un ecran de regles de lui-meme.
-- On ne declenche que sur la TRANSITION « pas fait » -> « fait » : un joueur qui a deja son
-- tutoriel derriere lui ne se fait pas ouvrir un panneau a chaque retour au menu.
local tutoFaitPrecedent = nil
local reglesMontreesApresTuto = false
local reglesAMontrer = false -- bascule vue en pleine partie : on ouvre au retour au menu
-- `accueilVisible` : l'ecran des regles ne doit JAMAIS s'ouvrir par-dessus l'arene. Le profil
-- peut etre rafraichi en pleine partie (recompenses, soldes) : si la bascule tombe a ce
-- moment-la, on RETIENT l'ouverture et on la joue au retour au menu.
local function verifierFinTutoriel(v)
	local fait = v ~= nil and v.tutoFait == true
	if tutoFaitPrecedent == false and fait then
		reglesAMontrer = true
	end
	tutoFaitPrecedent = fait
	if reglesAMontrer and not reglesMontreesApresTuto and accueil.Visible and ouvrirRegles then
		reglesMontreesApresTuto = true -- une seule fois par session
		reglesAMontrer = false
		print("[HUB] fin du tutoriel : ouverture des regles")
		ouvrirRegles()
	end
end

local function afficher(v)
	if not v then
		return
	end
	vue = v
	-- REGLAGES SONORES DU PROFIL : appliques des que la vue arrive, donc des l'entree dans le jeu.
	-- Sans cela, un joueur qui a coupe la musique la retrouverait allumee a chaque connexion.
	if v.son then
		Sons.regler(v.son.musique, v.son.bruitages)
	end
	verifierFinTutoriel(v)
	if majQuetes then
		majQuetes(v)
	end
	-- COFFRE GRATUIT : le texte et sa couleur viennent du module, l'ecran n'en decide rien.
	do
		local reste = v.evenements and v.evenements.coffreGratuitReste or 0
		local typeC = v.evenements and v.evenements.coffreGratuitType or "argent"
		montee.coffreLigne.Text = montee.rappel.texte(reste, typeC, #(v.coffres or {}) >= 4)
		local t = montee.rappel.teinte(reste)
		montee.coffreLigne.TextColor3 = Color3.fromRGB(t[1], t[2], t[3])
		-- La pastille ne compte pas que le coffre : chaque quete du jour TERMINEE et pas encore
		-- reclamee s'y ajoute. Elle porte le CHIFFRE, qui dit s'il vaut la peine d'y aller.
		if montee.coffrePastille then
			local aPrendre = v.evenements and v.evenements.quetes or nil
			montee.coffrePastille.Visible = montee.rappel.pastille(reste, aPrendre, v.bonusDispo, #(v.coffres or {}) >= 4)
			montee.coffreCompte.Text = montee.rappel.compte(reste, aPrendre, v.bonusDispo, #(v.coffres or {}) >= 4)
		end
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
	-- La barre suit la MEME regle que la ligne de texte : une seule source, aucun risque qu'elles
	-- se contredisent. Derniere arene : la barre est pleine, il n'y a plus rien a atteindre.
	-- Combien de VICTOIRES, et plus seulement combien de trophees : depuis que le robot ne rapporte
	-- que le tiers (Arenes), la reponse triple selon l'adversaire. Module charge a l'usage : ce
	-- fichier est au plafond des 200 variables locales de Lua.
	montee.arene.Text = arene.nom .. "   -   "
		.. require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression")).texte(
			suivante and suivante.nom, suivante and (suivante.seuil - (v.trophees or 0)),
			Arenes.GAIN_VICTOIRE, Arenes.PART_ROBOT)
	montee.saison.Text = Saison.texteSaison(v.saison, v.saisonReste, v.tropheesMax)
	montee.derniereVue = v
	if montee.majPass then -- construit plus bas dans le fichier : la 1re vue arrive peut-etre avant
		montee.majPass(v.pass)
	end
	if montee.majCosmetiques then
		montee.majCosmetiques(v)
	end
	do
		local Ligues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ligues"))
		local lg = Ligues.actuelle(v.trophees or 0)
		local c = Color3.fromRGB(lg.couleur[1], lg.couleur[2], lg.couleur[3])
		montee.ligue.badge.BackgroundColor3 = c
		montee.ligue.lettre.Text = lg.lettre
		-- « Ligue Or » en grand, palier dessous (Ligues.texte coupe en deux a l'endroit du nom)
		local t = Ligues.texte(v.trophees or 0)
		local nom, reste = t:match("^(.-)  (.*)$") -- nom et palier separes par deux espaces
		montee.ligue.nom.Text = nom or lg.nom
		montee.ligue.texte.Text = reste or t
		montee.ligue.nom.TextColor3 = c:Lerp(Color3.new(1, 1, 1), 0.3)
	end
	-- BILAN DE FIN DE SAISON : present une seule fois, juste apres la bascule.
	if v.bilanSaison and not finSaison.ecran.Visible and not finSaison.montre then
		finSaison.montre = true
		for i, ligne in ipairs(finSaison.lignes) do
			ligne.Text = Saison.lignesBilan(v.bilanSaison)[i]
				or (i == 5 and montee.ligneSaison(v.bilanSaison)) or ""
		end
		finSaison.ecran.Visible = true
		Sons.jouer("coffre")
		print("[HUB] fin de saison : bilan affiche")
	end
	montee.jauge.Size = UDim2.new(Arenes.progression(v.trophees or 0), 0, 1, 0)
	montee.fond.Visible = suivante ~= nil
	boutonBonus.Text = v.bonusDispo and "BONUS DU JOUR : +50" or "BONUS DEJA PRIS"
	boutonBonus.BackgroundColor3 = v.bonusDispo and Color3.fromRGB(200, 120, 40) or Color3.fromRGB(80, 80, 90)
	soldeBoutique.Text = v.pieces .. " pieces"
	-- Les deux lignes de la boutique : ce qui est a portee AUJOURD'HUI (des pieces) et ce que la
	-- prochaine arene ouvrira (des trophees). Les regles viennent des modules, pas d'un calcul local.
	do
		local portee = montee.collection.aPortee(v.cartes, Cards.list, function(id)
			return (Arenes.carteDebloquee(id, v.trophees or 0))
		end, v.pieces or 0)
		montee.boutiquePortee.Text = montee.collection.texteBoutique(portee)
		local suivante = Arenes.suivante(v.trophees or 0)
		local nouvelles = {}
		if suivante then
			for _, id in ipairs(suivante.deblocage) do
				table.insert(nouvelles, Cards.byId[id] and Cards.byId[id].name or id)
			end
		end
		montee.boutiqueArene.Text = suivante
			and montee.collection.texteProchaineArene(suivante.nom,
				suivante.seuil - (v.trophees or 0), nouvelles)
			or ""
	end
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
				t.etat.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fiche")).texteExemplaires(ex, besoin)
				t.action.Visible = true
				t.action.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fiche")).texteAmelioration(ex, besoin, v.pieces, cout)
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
				t.etat.Text = Arenes.texteVerrou(card.prix, card.id, v.trophees or 0)
				t.action.Visible = true
				t.action.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
			else
				t.action.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fiche")).texteAchat(v.pieces, card.prix)
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
	-- Largeur partagee entre les offres (espacement 0.02) : 0.32 fixe tenait 3 offres, et le pass
	-- VIP en fait une 4e qui sortait de la bande.
	for _, offre in ipairs(v.offresRobux) do
		local b = bouton(offresRobux, offre.nom .. " (Robux)",
			UDim2.new((1 - 0.02 * (#v.offresRobux - 1)) / #v.offresRobux, 0, 1, 0), UDim2.new(), Color3.fromRGB(0, 160, 90))
		b.MouseButton1Click:Connect(function()
			afficher(Boutique:InvokeServer("robux", offre.index).vue)
		end)
		-- PASTILLE DE L'OFFRE (champ `genre` de la vue) : le meme dessin que les jetons du bandeau
		-- (pieces « $ » or, gemmes « G » vert), et « x2 » violet pour le VIP. Tout est DESSINE :
		-- aucune image a televerser sur le compte du createur.
		local sorte = ({ pieces = { "$", OR }, gemmes = { "G", Color3.fromRGB(80, 210, 160) },
			vip = { "x2", Color3.fromRGB(190, 120, 255) } })[offre.genre or "pieces"] or { "$", OR }
		local pastille = Instance.new("Frame")
		pastille.Name = "Pastille"
		pastille.Size = UDim2.fromScale(0.2, 0.8)
		pastille.Position = UDim2.fromScale(0.03, 0.1)
		pastille.BackgroundColor3 = sorte[2]
		pastille.ZIndex = b.ZIndex + 1
		pastille.Parent = b
		local carre = Instance.new("UIAspectRatioConstraint")
		carre.Parent = pastille
		coin(pastille, 100)
		contour(pastille, 2)
		-- symbole aux deux tiers, centre : a pleine taille, son contour sombre masquait la couleur
		texte(pastille, sorte[1], UDim2.fromScale(0.64, 0.64), UDim2.fromScale(0.18, 0.18), Color3.fromRGB(30, 26, 10)).ZIndex = b.ZIndex + 2
		-- Le libelle passe dans une etiquette A DROITE de la pastille : une marge (UIPadding) sur le
		-- bouton deplacait aussi la pastille, qui masquait le debut du texte (capture du 2026-09-27).
		local libelle = texte(b, b.Text, UDim2.fromScale(0.72, 0.9), UDim2.fromScale(0.25, 0.05), Color3.new(1, 1, 1))
		libelle.ZIndex = b.ZIndex + 1
		b.Text = ""
	end
end

-- ===== FICHE COMPLETE D'UNE CARTE (au clic sur sa tuile) =====
-- La tuile n'a la place que de DEUX effets, puis elle ecrit « (+1) » : sur Bombardiro, une ligne
-- entiere restait cachee, et aucun gui ne montrait les statistiques brutes (PV, degats, portee,
-- vitesse, cadence). Ici, tout est lu d'un coup, sur la carte que l'on vient de toucher.
-- En-tete du panneau du HUB : une ligne de plus que celui de la partie (il montre aussi la
-- rarete). C'est le seul ecart entre les deux ecrans ; la regle de hauteur, elle, est commune.
local ENTETE_FICHE_HUB = 146
local detail = Instance.new("Frame")
detail.Name = "DetailCarte"
-- Taille en PIXELS et non en part d'ecran : la hauteur est recalculee a chaque ouverture
-- (Fiche.hauteurPanneau) pour coller au nombre de lignes. En proportions, une carte a un seul
-- effet ouvrait un panneau aussi grand qu'une carte a quatre.
detail.Size = UDim2.new(0, 560, 0, 300)
detail.Position = UDim2.new(0.5, -280, 0.5, -150)
detail.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
detail.BorderSizePixel = 0
detail.Visible = false
detail.ZIndex = 50
detail.Parent = gui
coin(detail, 16)
contour(detail, 3, Color3.fromRGB(255, 215, 110), 0)

local detailTitre = texte(detail, "", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 12))
detailTitre.ZIndex = 51
local detailRarete = texte(detail, "", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 58))
detailRarete.ZIndex = 51
local detailCout = texte(detail, "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 84),
	Color3.fromRGB(230, 210, 255))
detailCout.ZIndex = 51
local detailStats = texte(detail, "", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 114),
	Color3.fromRGB(190, 200, 220))
detailStats.ZIndex = 51
detailStats.TextScaled = false
detailStats.TextSize = 15

-- Les lignes d'effet s'empilent : une par ligne, toutes visibles, sans « (+1) ».
local detailListe = Instance.new("Frame")
detailListe.BackgroundTransparency = 1
detailListe.Size = UDim2.new(1, -28, 0, 100)
detailListe.Position = UDim2.new(0, 14, 0, ENTETE_FICHE_HUB)
detailListe.ZIndex = 51
detailListe.Parent = detail
local detailLayout = Instance.new("UIListLayout")
detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
detailLayout.Padding = UDim.new(0, 4)
detailLayout.Parent = detailListe

-- Taille et place tirees du module, comme en partie : la marge au-dessus du bouton est la
-- meme sur les deux ecrans, et elle ne peut plus deriver.
local detailFermer = bouton(detail, "FERMER", UDim2.new(0, 170, 0, Fiche.PANNEAU_BOUTON),
	UDim2.new(0.5, -85, 1, -(Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS)),
	Color3.fromRGB(90, 90, 110))
detailFermer.ZIndex = 52
detailFermer.MouseButton1Click:Connect(function()
	detail.Visible = false
end)

local function ouvrirDetail(card)
	if not card then
		return
	end
	detailTitre.Text = card.name
	local rar = Cards.RARETES[card.rarete]
	detailRarete.Text = rar and rar.nom or ""
	detailRarete.TextColor3 = rar and rar.couleur or Color3.new(1, 1, 1)
	detailCout.Text = card.cost .. " elixir"
	-- Les chiffres AU NIVEAU DU JOUEUR, et non ceux du niveau 1 : une carte amelioree affichait
	-- les memes nombres qu'une carte neuve.
	do
		local niv = (vue and vue.niveaux and vue.niveaux[card.id]) or 1
		local bonus = (vue and vue.bonusParNiveau) or 0
		detailStats.Text = Fiche.stats(card, 1 + bonus * (niv - 1))
	end
	for _, e in ipairs(detailListe:GetChildren()) do
		if e:IsA("TextLabel") then
			e:Destroy()
		end
	end
	-- TOUTES les lignes, pas seulement les deux premieres : c'est la raison d'etre de cet gui.
	-- Les chiffres de la fiche SUIVENT le niveau du joueur, lignes d'effet comprises : l'en-tete
	-- disait « Degats 408 » et la ligne dessous « DEGATS : 340 » (capture du 2026-09-21).
	local ex = extrasDe(card.id)
	do
		local niv = (vue and vue.niveaux and vue.niveaux[card.id]) or 1
		ex.mult = 1 + ((vue and vue.bonusParNiveau) or 0) * (niv - 1)
		if ex.rendementSort then
			ex.rendementSort = ex.rendementSort * ex.mult
		end
	end
	local lignes = Fiche.lignes(card, ex)
	if #lignes == 0 then
		table.insert(lignes, card.desc or "")
	end
	-- CE QU'APPORTE L'AMELIORATION, seulement pour une carte POSSEDEE (on n'ameliore pas ce qu'on
	-- n'a pas). Le bouton disait « AMELIORER 50 » et rien d'autre.
	if vue and vue.cartes and vue.cartes[card.id] then
		local gain = Fiche.gainNiveau(card, (vue.niveaux and vue.niveaux[card.id]) or 1,
			vue.bonusParNiveau, vue.niveauMax)
		if gain ~= "" then
			table.insert(lignes, gain)
		end
	end
	for i, ligne in ipairs(lignes) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 22)
		l.LayoutOrder = i
		l.Text = "• " .. ligne
		l.TextScaled = false
		l.TextSize = 15
		l.TextWrapped = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.fromRGB(235, 225, 170)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 51
		l.Parent = detailListe
	end
	-- HAUTEUR AJUSTEE, meme regle que le panneau de partie (Fiche.hauteurPanneau), avec l'en-tete
	-- plus haut du hub.
	local hauteur = Fiche.hauteurPanneau(#lignes, ENTETE_FICHE_HUB)
	detail.Size = UDim2.new(0, 560, 0, hauteur)
	detail.Position = UDim2.new(0.5, -280, 0.5, -math.floor(hauteur / 2))
	detailListe.Size = UDim2.new(1, -28, 0, Fiche.hauteurListe(#lignes, ENTETE_FICHE_HUB))
	detail.Visible = true
end

for _, card in ipairs(Cards.list) do
	local tuile = Instance.new("Frame")
	tuile.BackgroundColor3 = card.color
	tuile.Parent = grille
	coin(tuile)
	-- TOUTE LA TUILE OUVRE SA FICHE. Pose avant les autres enfants : le bouton ACHETER, cree
	-- plus bas, reste donc au-dessus et garde ses clics.
	local zoneDetail = Instance.new("TextButton")
	zoneDetail.Text = ""
	zoneDetail.BackgroundTransparency = 1
	zoneDetail.Size = UDim2.new(1, 0, 1, 0)
	zoneDetail.Parent = tuile
	zoneDetail.MouseButton1Click:Connect(function()
		ouvrirDetail(card)
	end)
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
		texte(tuile, rar.nom, UDim2.new(0.57, 0, 0.1, 0), UDim2.new(0.40, 0, 0.30, 0), rar.couleur)
	end
	-- IMAGE DE LA CARTE (2026-09-21) : la collection n'etait que des aplats portant un nom. La
	-- figurine (modele, silhouette ou embleme : Figurine.lua) prend la gauche de la tuile ; nom,
	-- rarete, cout, niveau et effet passent dans la colonne de droite (0,40 -> 0,97).
	do
		local fig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine"))
		local vueTuile = fig.vue(tuile, 2)
		vueTuile.Size = UDim2.new(0.36, 0, 0.66, 0)
		vueTuile.Position = UDim2.new(0.02, 0, 0.03, 0)
		fig.rendre(vueTuile, card.id)
	end
	texte(tuile, card.name, UDim2.new(0.57, 0, 0.26, 0), UDim2.new(0.40, 0, 0.03, 0))
	-- elixir a gauche, niveau a droite : sur toute la largeur, les deux textes se chevauchaient (capture 2026-09-14)
	texte(tuile, card.cost .. " elixir", UDim2.new(0.30, 0, 0.13, 0), UDim2.new(0.40, 0, 0.42, 0), Color3.fromRGB(230, 210, 255))
	-- CE QUE FAIT LA CARTE : deduit de ses donnees par le module Fiche, jamais ecrit a la main.
	-- Une carte dont on change les chiffres voit sa fiche changer toute seule.
	local effet = texte(tuile, Fiche.resume(card, 1, extrasDe(card.id)), UDim2.new(0.57, 0, 0.16, 0), UDim2.new(0.40, 0, 0.53, 0),
		Color3.fromRGB(235, 225, 170))
	effet.TextWrapped = true
	effet.TextScaled = false
	effet.TextSize = 11
	-- Colonne etroite depuis l'image (2026-09-21) : deux traits se coupaient au milieu d'un mot
	-- (capture cap-cartes-boutique.png). Un seul trait, et « … » s'il deborde ; la fiche dit le reste.
	effet.TextTruncate = Enum.TextTruncate.AtEnd
	-- etat decale a 0,74 : a 0,72 la deuxieme ligne d'effet touchait le prix (capture 2026-09-20)
	local etat = texte(tuile, "", UDim2.new(0.9, 0, 0.10, 0), UDim2.new(0.05, 0, 0.71, 0), OR)
	local action = bouton(tuile, "ACHETER", UDim2.new(0.8, 0, 0.15, 0), UDim2.new(0.1, 0, 0.83, 0), Color3.fromRGB(60, 170, 80))
	local niveau = texte(tuile, "", UDim2.new(0.25, 0, 0.13, 0), UDim2.new(0.72, 0, 0.42, 0), Color3.fromRGB(255, 255, 255))
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
-- PROGRESSION DE LA COLLECTION. Le jeu compte 40 cartes et rien ne disait combien on en possede :
-- il fallait compter les tuiles ternes a l'oeil. Le seul chiffre existant (« X cartes sur 8 »)
-- parle du DECK et entretenait meme la confusion. A GAUCHE du titre : la zone y est libre (le
-- titre est centre, la croix de fermeture est a droite).
montee.collection = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Collection"))
montee.collectionLigne = texte(deckEcran, "", UDim2.new(0.28, 0, 0.04, 0), UDim2.new(0.02, 0, 0.035, 0),
	Color3.fromRGB(255, 205, 110), Enum.TextXAlignment.Left)
-- BARRE sous la ligne : le rapport possedees / total se lit sans lire le chiffre.
montee.collectionFond = Instance.new("Frame")
montee.collectionFond.Size = UDim2.new(0.28, 0, 0.012, 0)
montee.collectionFond.Position = UDim2.new(0.02, 0, 0.082, 0)
montee.collectionFond.BackgroundColor3 = Color3.fromRGB(38, 42, 60)
montee.collectionFond.BorderSizePixel = 0
montee.collectionFond.Parent = deckEcran
coin(montee.collectionFond, 4)
montee.collectionJauge = Instance.new("Frame")
montee.collectionJauge.Size = UDim2.new(0, 0, 1, 0)
montee.collectionJauge.BackgroundColor3 = Color3.fromRGB(255, 190, 70)
montee.collectionJauge.BorderSizePixel = 0
montee.collectionJauge.Parent = montee.collectionFond
coin(montee.collectionJauge, 4)
-- DIAGNOSTIC DU DECK, sous le compteur. `Cycle.coutMoyen` existait et etait teste au banc, mais
-- n'etait appele NULLE PART : l'ecran montrait huit vignettes sans le chiffre que tout joueur
-- regarde en premier, ni le trou qui coute le plus de parties (aucune reponse aux volants).
local deckResume = texte(deckEcran, "", UDim2.new(0.8, 0, 0.04, 0), UDim2.new(0.1, 0, 0.155, 0),
	Color3.fromRGB(205, 212, 228))
deckResume.ZIndex = 3
deckResume.TextScaled = false
deckResume.TextSize = 15
local deckFermer = bouton(deckEcran, "X", UDim2.new(0, 44, 0, 44), UDim2.new(1, -56, 0, 12), Color3.fromRGB(170, 50, 50))
local deckValider = bouton(deckEcran, "ENREGISTRER", UDim2.new(0.36, 0, 0.09, 0), UDim2.new(0.32, 0, 0.87, 0), Color3.fromRGB(60, 170, 80))

-- 0.66 de haut s'arrete juste au-dessus du bouton ENREGISTRER (place a 0.87) : la grille ne peut
-- plus passer dessous, elle defile.
-- 0.50 de haut : la collection occupe le haut de l'ecran, la rangee du deck courant se pose
-- dessous (0.70), au-dessus du bouton ENREGISTRER (0.87) — l'ordre du jeu de reference.
local deckGrille = grilleDefilante(deckEcran, UDim2.new(0.94, 0, 0.46, 0), UDim2.new(0.03, 0, 0.20, 0), 0.3, 0.03, 5)

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

-- CAPTURE (build.py --deck --deck-modifie) : un clic sur une carte du deck, jamais enregistre.
if ReplicatedStorage:FindFirstChild("BRR_DECK_MODIFIE") then
	task.delay(12, function()
		local id = vue and vue.deck and vue.deck[1]
		if id then
			basculer(id)
			print("[DECK] carte retiree sans enregistrer :", id)
			-- --deck-sortie : on complete avec une autre carte possedee, puis on QUITTE l'ecran.
			if ReplicatedStorage:FindFirstChild("BRR_DECK_SORTIE") then
				for autre in pairs(vue.cartes) do
					if not choix[autre] and autre ~= id then
						basculer(autre)
						print("[DECK] carte ajoutee :", autre)
						break
					end
				end
				task.wait(2)
				deckEcran.Visible = false
				accueil.Visible = true
			end
		end
	end)
end

for _, card in ipairs(Cards.list) do
	local tuile = Instance.new("TextButton")
	tuile.BackgroundColor3 = card.color
	tuile.Text = ""
	tuile.AutoButtonColor = true
	tuile.Parent = deckGrille
	coin(tuile)
	-- UN SEUL contour : couleur de RARETE, et or epais quand la carte est choisie. Deux UIStroke sur
	-- la meme tuile ont un ordre de rendu NON DEFINI (docs Roblox, UI appearance modifiers) : la
	-- selection transparente masquait la rarete (photo de l'onglet CARTES du 2026-09-21).
	local bord = Instance.new("UIStroke")
	bord.Thickness = card.rarete == "commune" and 2 or 3
	bord.Color = (Cards.RARETES[card.rarete] or Cards.RARETES.commune).couleur
	-- BORDER force : sur un TextButton, un UIStroke est en mode Contextual par defaut et entoure le
	-- TEXTE — vide ici, donc rien ne se dessinait (photo de l onglet CARTES du 2026-09-21).
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = tuile
	-- largeur 0.56 et non 0.9 : la pastille de niveau occupe desormais le coin haut droit,
	-- et le nom la recouvrait (capture cap-cartes-collection.png du 2026-09-20).
	texte(tuile, card.name, UDim2.new(0.56, 0, 0.4, 0), UDim2.new(0.05, 0, 0.06, 0))
	texte(tuile, card.cost .. " elixir", UDim2.new(0.52, 0, 0.18, 0), UDim2.new(0.05, 0, 0.5, 0), Color3.fromRGB(230, 210, 255))
	local etatDeck = texte(tuile, "", UDim2.new(0.52, 0, 0.2, 0), UDim2.new(0.05, 0, 0.72, 0), OR)
	-- IMAGE DE LA CARTE, a droite, sous la pastille de niveau et le « ? » (poses cote a cote) : cout et etat s'arretent a 0,57.
	do
		local fig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine"))
		local vueTuile = fig.vue(tuile, 2)
		-- Toute la colonne de droite sous la pastille : a 0,52 de haut (sous le « ? »), la figurine
		-- ne faisait qu'une quarantaine de pixels (capture cap-cartes-deck.png du 2026-09-21).
		vueTuile.Size = UDim2.new(0.35, 0, 0.72, 0)
		vueTuile.Position = UDim2.new(0.63, 0, 0.27, 0)
		fig.rendre(vueTuile, card.id)
	end
	-- NIVEAU de la carte, comme dans la collection du jeu de reference : pastille sombre en haut
	-- a droite. L'onglet CARTES montrait la collection SANS les niveaux, alors que la vue serveur
	-- les porte deja (v.niveaux) — le joueur devait passer par la boutique pour les lire.
	local pastilleNiv = Instance.new("Frame")
	pastilleNiv.Size = UDim2.new(0.22, 0, 0.2, 0)
	pastilleNiv.Position = UDim2.new(0.62, 0, 0.04, 0)
	pastilleNiv.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
	pastilleNiv.BackgroundTransparency = 0.15
	pastilleNiv.ZIndex = 3
	pastilleNiv.Parent = tuile
	coin(pastilleNiv, 6)
	local niveauDeck = texte(pastilleNiv, "", UDim2.new(0.9, 0, 0.8, 0), UDim2.new(0.05, 0, 0.1, 0), OR)
	niveauDeck.ZIndex = 4
	-- FICHE COMPLETE : petit bouton « ? » dans le coin. Le clic sur la TUILE sert deja a mettre
	-- la carte dans le deck — le voler pour ouvrir une fiche casserait le geste principal de
	-- l'ecran. Le joueur choisit donc ses cartes SANS quitter l'ecran pour aller lire la boutique.
	-- sous la pastille de niveau (0,04 -> 0,24) et non en bas : a 0,74 le bouton frolait le
	-- libelle « DANS LE DECK » (capture cap-deck-fiche.png du 2026-09-20).
	local infoDeck = bouton(tuile, "?", UDim2.new(0.12, 0, 0.2, 0), UDim2.new(0.86, 0, 0.04, 0),
		Color3.fromRGB(45, 50, 80))
	infoDeck.ZIndex = 5
	infoDeck.MouseButton1Click:Connect(function()
		ouvrirDetail(card)
	end)
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
		-- choisie : or epais ; sinon la couleur de sa rarete
		t.bord.Color = choix[card.id] and OR or (Cards.RARETES[card.rarete] or Cards.RARETES.commune).couleur
		t.bord.Thickness = choix[card.id] and 4 or (card.rarete == "commune" and 2 or 3)
		t.etat.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Collection")).etatDeck(
			possede, choix[card.id] == true, nbChoix >= taille,
			Arenes.tropheesManquants(card.id, vue.trophees or 0), card.prix)
		-- niveau lu de la VUE serveur : une carte non possedee n'a pas de niveau, sa pastille
		-- disparait plutot que d'afficher un « Niv. 1 » qui n'existe pas.
		t.pastille.Visible = possede
		t.niveau.Text = possede and ("Niv. " .. ((vue.niveaux and vue.niveaux[card.id]) or 1)) or ""
	end
	-- Le resume porte sur le deck EN COURS DE CONSTRUCTION (les cartes cochees), pas sur celui
	-- deja enregistre : c'est pendant le choix qu'il sert a quelque chose.
	local choisies = {}
	for _, card in ipairs(Cards.list) do
		if choix[card.id] then
			table.insert(choisies, card.id)
		end
	end
	local resume = Cycle.resumeDeck(choisies,
		function(id) return Cards.byId[id] and Cards.byId[id].cost end,
		function(id) return Cards.byId[id] ~= nil and Regles.peutViserVolant(Cards.byId[id]) end)
	deckResume.Text = Cycle.texteResume(resume)
	-- L'alerte REMPLACE le resume : un deck sans reponse aerienne a un probleme avant d'avoir un
	-- cout moyen, et deux lignes se seraient marche dessus.
	if resume.alerte then
		deckResume.Text = resume.alerte .. "  -  " .. deckResume.Text
		deckResume.TextColor3 = Color3.fromRGB(255, 150, 90)
	else
		deckResume.TextColor3 = Color3.fromRGB(205, 212, 228)
	end
	-- COLLECTION : le compte porte sur TOUT le catalogue, et separe ce qui s'achete (des pieces)
	-- de ce qui attend une arene (des trophees). Melanger les deux ferait croire a un mur d'argent.
	do
		local bilan = montee.collection.bilan(vue.cartes, Cards.list, function(id)
			return (Arenes.carteDebloquee(id, vue.trophees or 0))
		end)
		montee.collectionLigne.Text = montee.collection.texte(bilan)
		montee.collectionJauge.Size = UDim2.new(montee.collection.part(bilan), 0, 1, 0)
	end
	if possedees < taille then
		deckCompteur.Text = possedees .. " cartes sur " .. taille .. " : debloque-en pour choisir"
		deckValider.Text = "PAS ASSEZ DE CARTES"
		deckValider.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	else
		deckCompteur.Text = nbChoix .. " / " .. taille .. " cartes choisies"
		if montee.collection.deckModifie(choix, vue.deck, taille) then
			deckCompteur.Text = deckCompteur.Text .. "  -  NON ENREGISTRE"
			deckValider.Text = "ENREGISTRER"
			deckValider.BackgroundColor3 = nbChoix == taille and Color3.fromRGB(60, 170, 80) or Color3.fromRGB(90, 90, 100)
		else
			deckValider.Text = "DECK ENREGISTRE"
			deckValider.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
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
		-- CHANGE EN PLEINE RECHERCHE : on le DIT, sinon le joueur ne sait pas si son nouveau deck
		-- part avec lui dans le match qui se forme.
		deckCompteur.Text = r.fileMiseAJour and "deck enregistre — il part avec toi dans la file !"
			or "deck enregistre !"
	else
		deckCompteur.Text = "Refuse : " .. tostring(r.motif)
	end
end)

-- SORTIE DE L'ECRAN DECK AVEC DES CHANGEMENTS : ils etaient PERDUS en silence (chargerChoix a la
-- reouverture). Deck complet : on l'enregistre tout seul et on le dit a l'accueil. Deck
-- incomplet : impossible a enregistrer, on dit qu'il n'a pas change.
deckEcran:GetPropertyChangedSignal("Visible"):Connect(function()
	if deckEcran.Visible or not vue then
		return
	end
	local taille = vue.deckTaille or 8
	if not montee.collection.deckModifie(choix, vue.deck, taille) then
		return
	end
	if nbChoix ~= taille then
		message.Text = "Deck incomplet (" .. nbChoix .. "/" .. taille .. ") : ton ancien deck est garde"
		chargerChoix()
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
	message.Text = r.ok and "Deck enregistre automatiquement" or ("Deck refuse : " .. tostring(r.motif))
	print("[DECK] sortie avec changements :", r.ok and "enregistre" or tostring(r.motif))
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

-- OUVERTURE DE COFFRE MISE EN SCENE (2026-09-21) : avant, une seule ligne de texte sous les
-- coffres. Plein ecran : le coffre tremble de plus en plus fort, un flash blanc l'ouvre, puis les
-- cartes (face cachee) se retournent une a une, encadrees et eclairees de la couleur de leur
-- rarete ; la carte NOUVELLE garde le dernier retournement. Un clic ferme la scene.
-- QUOI et QUAND viennent du module Ouverture (teste par tools/test_ouverture.py).
function montee.ouverture(gain)
	local Ouverture = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ouverture"))
	local liste = Ouverture.cartes(gain, Cards)
	if #liste == 0 then
		return
	end
	local function c3(c)
		return typeof(c) == "Color3" and c or Color3.fromRGB(c[1], c[2], c[3])
	end
	local scene = Instance.new("TextButton")
	scene.Name = "OuvertureCoffre"
	scene.AutoButtonColor = false
	scene.Text = ""
	scene.Size = UDim2.fromScale(1, 1)
	scene.BackgroundColor3 = Color3.fromRGB(8, 10, 22)
	scene.BackgroundTransparency = 0.12
	scene.ZIndex = 80
	scene.Parent = gui
	degrade(scene, Color3.fromRGB(60, 50, 110), Color3.fromRGB(10, 10, 20))
	local coffre = Instance.new("Frame")
	coffre.BackgroundTransparency = 1
	coffre.AnchorPoint = Vector2.new(0.5, 0.5)
	coffre.Position = UDim2.fromScale(0.5, 0.5)
	coffre.Size = UDim2.fromScale(0.34, 0.5)
	coffre.ZIndex = 81
	coffre.Parent = scene
	dessinerCoffre(coffre)
	for _, d in ipairs(coffre:GetDescendants()) do
		if d:IsA("GuiObject") then d.ZIndex = 82 end
	end
	Sons.jouer("coffre")
	-- 1) TREMBLEMENT qui monte
	local debut = os.clock()
	while os.clock() - debut < Ouverture.TREMBLE do
		local t = os.clock() - debut
		local a = Ouverture.tremblement(t)
		coffre.Rotation = math.sin(t * 38) * a
		coffre.Position = UDim2.new(0.5, math.sin(t * 51) * a * 0.8, 0.5, 0)
		task.wait()
	end
	coffre.Rotation = 0
	-- 2) FLASH blanc, le coffre disparait dans la lumiere
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.ZIndex = 95
	flash.Parent = scene
	coffre:Destroy()
	TweenService:Create(flash, TweenInfo.new(Ouverture.FLASH * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }):Play()
	Sons.jouer("tourDetruite")
	-- 3) CARTES face cachee, retournees une a une
	local n = #liste
	local largeur, ecart = 0.19, 0.03
	local x0 = 0.5 - (n * largeur + (n - 1) * ecart) / 2
	local tuiles = {}
	for i, c in ipairs(liste) do
		local t = Instance.new("Frame")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(x0 + (i - 1) * (largeur + ecart) + largeur / 2, 0.5)
		t.Size = UDim2.fromScale(largeur, 0.46)
		t.BackgroundColor3 = Color3.fromRGB(40, 36, 80)
		t.ZIndex = 84
		t.Parent = scene
		coin(t, 14)
		degrade(t, Color3.fromRGB(95, 80, 170), Color3.fromRGB(30, 26, 60))
		local bord = contour(t, 4, Color3.fromRGB(12, 14, 24), 0)
		local dos = texte(t, "?", UDim2.fromScale(0.6, 0.5), UDim2.fromScale(0.2, 0.25), Color3.fromRGB(255, 215, 90))
		dos.ZIndex = 85
		tuiles[i] = { t = t, bord = bord, dos = dos, c = c }
	end
	for i, x in ipairs(tuiles) do
		task.wait(math.max(0, debut + Ouverture.instant(i) - os.clock())) -- horaire du module, sans derive
		local plein = x.t.Size
		local demi = TweenInfo.new(Ouverture.RETOURNE / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(x.t, demi, { Size = UDim2.new(0, 0, plein.Y.Scale, 0) }):Play()
		task.wait(Ouverture.RETOURNE / 2)
		-- face revelee : couleur de rarete partout (fond, bord, lueur)
		local couleur = c3(x.c.couleur)
		x.dos:Destroy()
		x.t:FindFirstChildOfClass("UIGradient"):Destroy()
		x.t.BackgroundColor3 = Color3.new(1, 1, 1) -- le degrade MULTIPLIE le fond : sur fond sombre, la rarete virait au noir (capture du 2026-09-21)
		degrade(x.t, couleur, sombre(couleur, 0.45))
		x.bord.Color = couleur:Lerp(Color3.new(1, 1, 1), 0.35)
		x.bord.Thickness = x.c.nouvelle and 7 or 5
		local titre = texte(x.t, x.c.titre, UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.22))
		titre.ZIndex = 86
		local sous = texte(x.t, x.c.sous, UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.58))
		sous.ZIndex = 86
		local rar = Cards.RARETES[x.c.rarete]
		if rar then
			local r = texte(x.t, rar.nom, UDim2.fromScale(0.9, 0.11), UDim2.fromScale(0.05, 0.8), Color3.new(1, 1, 1))
			r.ZIndex = 86
		end
		TweenService:Create(x.t, TweenInfo.new(Ouverture.RETOURNE / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = plein }):Play()
		if x.c.nouvelle and ReplicatedStorage:FindFirstChild("BRR_PHOTO_JEU") then
			-- PHOTO DE TEST : 0,45 s apres le retournement de la carte NOUVELLE (eclair du halo encore
			-- visible, etincelles deja parties). Signal local : le script de capture tourne sur ce client.
			task.delay(0.45, function()
				ReplicatedStorage:SetAttribute("BRR_PHOTO", os.clock())
			end)
		end
		if x.c.nouvelle then
			-- FINAL : une carte NOUVELLE ne se contente pas d'un bord plus epais. Halo tournant de sa
			-- couleur de rarete derriere elle, eclair dore, et la carte grossit (1,15) au premier plan.
			local halo = Instance.new("Frame")
			halo.Name = "HaloNouvelle"
			halo.AnchorPoint = Vector2.new(0.5, 0.5)
			halo.Position = x.t.Position
			halo.SizeConstraint = Enum.SizeConstraint.RelativeYY
			halo.Size = UDim2.fromScale(0.62, 0.62)
			halo.BackgroundTransparency = 1
			halo.ZIndex = 83
			halo.Parent = scene
			for k = 0, 2 do -- trois carres decales de 30 degres : une etoile a 12 branches
				local b = Instance.new("Frame")
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Position = UDim2.fromScale(0.5, 0.5)
				b.Size = UDim2.fromScale(1, 1)
				b.Rotation = k * 30
				b.BackgroundColor3 = couleur:Lerp(Color3.new(1, 1, 1), 0.25)
				b.BackgroundTransparency = 0.45 + k * 0.1
				b.ZIndex = 83
				b.Parent = halo
			end
			TweenService:Create(halo, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }):Play()
			local pop = Instance.new("UIScale")
			pop.Scale = 0.6
			pop.Parent = x.t
			TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1.15 }):Play()
			x.t.ZIndex = 88
			for _, d in ipairs(x.t:GetDescendants()) do
				if d:IsA("GuiObject") then d.ZIndex = 89 end
			end
			-- ECLAIR LIMITE AU HALO : un disque de lumiere qui s'ouvre derriere la carte et s'efface. Plein
			-- ecran, il teintait tout d'or, cartes communes comprises (capture du 2026-09-21).
			local eclairHalo = Instance.new("Frame")
			eclairHalo.Name = "EclairHalo"
			eclairHalo.AnchorPoint = Vector2.new(0.5, 0.5)
			eclairHalo.Position = x.t.Position
			eclairHalo.SizeConstraint = Enum.SizeConstraint.RelativeYY
			eclairHalo.Size = UDim2.fromScale(0.2, 0.2)
			eclairHalo.BackgroundColor3 = couleur:Lerp(Color3.new(1, 1, 1), 0.45)
			eclairHalo.BackgroundTransparency = 0.05
			eclairHalo.ZIndex = 82
			eclairHalo.Parent = scene
			local rond = Instance.new("UICorner")
			rond.CornerRadius = UDim.new(0.5, 0)
			rond.Parent = eclairHalo
			TweenService:Create(eclairHalo, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(0.95, 0.95), BackgroundTransparency = 1 }):Play()
			-- LEGENDAIRE : reflet qui balaie la carte, et ETINCELLES qui jaillissent en boucle tant que
			-- la scene est ouverte. C'est ce qui la distingue d'une carte ordinaire au premier regard.
			if x.c.rarete == "legendaire" then
				local reflet = x.t:FindFirstChildOfClass("UIGradient")
				if reflet then
					reflet.Rotation = 60
					TweenService:Create(reflet, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Rotation = 120 }):Play()
				end
				task.spawn(function()
					local n = 0
					while scene.Parent do
						n += 1
						-- LOSANGE DESSINE (carre tourne de 45 degres) et non un caractere : l'etoile « ✦ » manquait
						-- a la police et s'affichait en carre vide (capture du 2026-09-21)
						local e = Instance.new("Frame")
						e.Name = "Etincelle"
						e.BorderSizePixel = 0
						e.Rotation = 45
						e.BackgroundColor3 = n % 2 == 0 and Color3.fromRGB(255, 245, 200) or Color3.fromRGB(255, 170, 60)
						e.AnchorPoint = Vector2.new(0.5, 0.5)
						e.SizeConstraint = Enum.SizeConstraint.RelativeYY
						e.Size = UDim2.fromScale(0.022, 0.022)
						e.Position = x.t.Position
						e.ZIndex = 90
						e.Parent = scene
						local a = n * 2.4 -- angle d'or : elles se repartissent tout autour
						local cible = x.t.Position + UDim2.fromScale(math.cos(a) * 0.17, math.sin(a) * 0.28)
						TweenService:Create(e, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Position = cible, BackgroundTransparency = 1, Rotation = 225 }):Play()
						task.delay(1, function()
							e:Destroy()
						end)
						task.wait(0.07)
					end
				end)
			end
		end
		Sons.jouer(x.c.nouvelle and "tourDetruite" or "coffre")
		print("[OUVERTURE] carte " .. i .. " revelee : " .. x.c.titre .. " " .. x.c.sous .. " (" .. tostring(x.c.rarete) .. ")")
	end
	local suite = texte(scene, "Touche pour continuer", UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.25, 0.85),
		Color3.fromRGB(215, 222, 240))
	suite.ZIndex = 86
	scene.MouseButton1Click:Connect(function()
		scene:Destroy()
	end)
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
	montee.clicCoffre = montee.clicCoffre or {}
	montee.clicCoffre[i] = function()
		local c = vue and vue.coffres[i]
		if not c then
			return
		end
		local action = c.fin == 0 and "demarrerCoffre" or "ouvrirCoffre"
		if c.fin ~= 0 and c.fin > os.time() + decalageHorloge then
			action = "accelererCoffre" -- en cours : ouverture immediate contre des gemmes
			local Coffres = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Coffres"))
			local maintenant = os.time() + decalageHorloge
			if vue.sansAleatoirePayant then
				-- tirage payant interdit dans son pays (Economie.aleatoirePayantInterdit) : on dit
				-- l'attente, rien n'est propose a l'achat (le serveur refuserait de toute facon).
				message.Text = Coffres.texteAttendre(c.fin - maintenant)
				return
			end
			if Coffres.doitConfirmer(montee.confirmeCoffre, i, maintenant) then
				-- 1er clic : on affiche le prix, rien n'est depense.
				montee.confirmeCoffre = { index = i, jusqua = maintenant + Coffres.CONFIRMATION_S }
				etat.Text = Coffres.texteConfirmer(c.fin - maintenant)
				message.Text = "Clique encore pour ouvrir ce coffre contre " .. Coffres.coutGemmes(c.fin - maintenant) .. " gemmes"
				print("[GEMMES] confirmation demandee :", etat.Text)
				task.delay(Coffres.CONFIRMATION_S + 0.5, function()
					if montee.confirmeCoffre and montee.confirmeCoffre.index == i then
						montee.confirmeCoffre = nil
						afficher(vue)
					end
				end)
				return
			end
			montee.confirmeCoffre = nil
		end
		local r = Boutique:InvokeServer(action, i)
		if r.gain then
			task.spawn(montee.ouverture, r.gain)
			message.Text = "+" .. r.gain.pieces .. " pieces"
				.. (r.gain.exemplaireCarte and ("  +  " .. r.gain.exemplaires .. " x " .. Cards.byId[r.gain.exemplaireCarte].name)
					or "  (deck au maximum : exemplaires changes en pieces)")
				.. (r.gain.carte and ("  +  carte " .. Cards.byId[r.gain.carte].name .. " !") or "")
		elseif not r.ok then
			Sons.jouer("refus")
			message.Text = "Coffre : " .. tostring(r.motif)
		end
		afficher(r.vue)
	end
	etat.MouseButton1Click:Connect(montee.clicCoffre[i])
	-- CAPTURE (build.py --ouverture) : ouvre le coffre PRET (n° 3 de --coffres), comme un joueur.
	if ReplicatedStorage:FindFirstChild("BRR_OUVERTURE") and i == 3 and not montee.ouvertureLancee then
		montee.ouvertureLancee = true
		task.delay(10, function()
			print("[OUVERTURE] clic simule sur le coffre 3")
			montee.clicCoffre[3]()
		end)
	end
	-- CAPTURE (build.py --clics=N) : N clics sur le coffre 2 (en cours), comme un joueur.
	local clics = ReplicatedStorage:FindFirstChild("BRR_CLICS")
	if clics and i == 2 and not montee.clicsLances then
		montee.clicsLances = true -- la rangee peut etre construite 2 fois : un seul lot de clics
		task.delay(10, function()
			for _ = 1, clics.Value do
				montee.clicCoffre[2]()
				print("[GEMMES] clic simule sur le coffre 2")
				task.wait(1)
			end
		end)
	end
	-- CE QU'IL Y A DEDANS, sous le titre. Le joueur doit choisir quel coffre lancer (un seul
	-- s'ouvre a la fois, de 15 min a 3 h) et ne voyait ni les pieces, ni les exemplaires, ni la
	-- chance d'y trouver une carte verrouillee : il decidait a l'aveugle.
	-- SOUS le coffre, juste au-dessus du bouton : pose a 0,175 le texte passait DERRIERE le dessin
	-- du coffre, dont la bande doree le coupait en deux (capture cap-coffres2.png du 2026-09-21).
	local detail = texte(cadre, "", UDim2.new(0.92, 0, 0.145, 0), UDim2.new(0.04, 0, 0.615, 0),
		Color3.fromRGB(215, 222, 240))
	detail.TextScaled = false
	detail.TextSize = 11
	detail.TextWrapped = true
	-- FOND SOMBRE et au-dessus du coffre : pose sur le dessin, le texte etait coupe en deux par la
	-- bande doree et la serrure (captures cap-coffres2/3/4.png du 2026-09-21). Un bandeau derriere
	-- le texte le rend lisible quel que soit le coffre dessine dessous.
	detail.BackgroundColor3 = Color3.fromRGB(14, 16, 28)
	detail.BackgroundTransparency = 0.25
	detail.ZIndex = 6
	coin(detail, 5)
	cible[i] = { cadre = cadre, titre = titre, etat = etat, coffre = coffre, detail = detail }
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

local rechercheEnCours = false
local rechercheAnnulee = false
boutonRobotVite.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local r = Boutique:InvokeServer("robotMaintenant")
	message.Text = r.ok and "Robot demande : la partie commence." or "Trop tard : un adversaire arrive."
end)
boutonAnnuler.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	rechercheAnnulee = true
	Boutique:InvokeServer("quitter")
	boutonAnnuler.Visible = false
	boutonJouer.Visible = true
	message.Text = "Recherche annulee."
end)
boutonJouer.MouseButton1Click:Connect(function()
	if rechercheEnCours then
		return -- deja en file : un second appui ouvrait une deuxieme boucle d'attente
	end
	Sons.jouer("clic")
	local r = Boutique:InvokeServer("jouer", attendreHumain and "patient" or nil)
	-- QUITTEUR EN SERIE : le serveur refuse de relancer une recherche et dit combien de temps il
	-- reste. Sans ce message, le bouton JOUER paraitrait simplement casse.
	if r.attenteAbandon and r.attenteAbandon > 0 then
		if message then
			message.Text = r.motif or ""
			message.Visible = true
		end
		Sons.jouer("refus")
		return
	end
	if r.attente then
		-- Recherche d'un adversaire en ligne : le serveur donne le robot au bout de ~20 s.
		rechercheEnCours, rechercheAnnulee = true, false
		boutonJouer.Visible = false
		boutonAnnuler.Visible = true
		boutonRobotVite.Visible = true
		local depuis = os.clock()
		local etat = "attente"
		local enFile, avantRobot = 0, 20
		while etat == "attente" and not rechercheAnnulee do
			-- le temps ECOULE s'affiche : une attente muette de 20 s passe pour un jeu bloque.
			-- Au-dela de 12 s, la file accepte un ecart de niveau de plus (Matchmaking.PATIENCE_NIVEAU) :
			-- le dire evite de croire que rien ne se passe.
			local ecoule = math.floor(os.clock() - depuis)
			-- On ANNONCE la bascule vers le robot au lieu de la subir : le joueur voit venir, et
			-- peut relancer une recherche s'il veut un humain.
			-- L'ATTENTE PATIENTE le dit, sinon le joueur croirait le compte a rebours casse.
			local base = attendreHumain
				and string.format("Recherche d'un VRAI joueur... %d s (robot dans %d s)", ecoule, avantRobot)
				or (ecoule >= 12
				and string.format("Recherche elargie... %d s (adversaires de niveau plus varie)", ecoule)
				or Adversaire.attente(avantRobot))
			-- COMBIEN CHERCHENT AVEC MOI : une attente muette laisse croire que le jeu est vide.
			-- On se compte soi-meme, donc « 1 » veut dire « personne d'autre pour l'instant ».
			if enFile > 1 then
				base = base .. string.format("  ·  %d joueurs en recherche", enFile)
			elseif enFile == 1 then
				base = base .. "  ·  tu es seul en recherche"
			end
			message.Text = base
			-- Le deck reste modifiable PENDANT la recherche : la barre d'onglets ne se cache pas,
			-- et le serveur met l'entree de file a jour (action « deck »).
			if barreOnglets then
				barreOnglets.Visible = true
			end
			task.wait(1)
			local r2 = Boutique:InvokeServer("attente")
			etat, enFile = r2.etat, r2.enFile or 0
			avantRobot = r2.avantRobot or 0
		end
		rechercheEnCours = false
		boutonAnnuler.Visible = false
		boutonRobotVite.Visible = false
		boutonJouer.Visible = true
		if rechercheAnnulee then
			return
		end
		if etat == "teleport" then
			message.Text = "Adversaire trouve ! Depart vers l'arene..."
			return
		end
		message.Text = Adversaire.attente(0)
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
-- DUEL PRIVE ENTRE AMIS --------------------------------------------------------------------------
-- On ne pouvait affronter QUE l'inconnu tire par la file. Ici : un code a partager, et un champ
-- pour entrer celui d'un ami. Le serveur verifie tout (le client n'ouvre aucune porte).
local boutonPrive = bouton(accueil, "DUEL PRIVE", UDim2.new(0.16, 0, 0.055, 0), UDim2.new(0.245, 0, 0.60, 0), Color3.fromRGB(95, 70, 160))
local codeAffiche = texte(accueil, "", UDim2.new(0.34, 0, 0.05, 0), UDim2.new(0.33, 0, 0.665, 0), OR)
codeAffiche.Visible = false

local champCode = Instance.new("TextBox")
champCode.Size = UDim2.new(0.16, 0, 0.055, 0)
champCode.Position = UDim2.new(0.425, 0, 0.60, 0)
champCode.BackgroundColor3 = Color3.fromRGB(28, 32, 50)
champCode.TextColor3 = Color3.new(1, 1, 1)
champCode.PlaceholderText = "CODE AMI"
champCode.Text = ""
champCode.TextScaled = true
champCode.Font = Enum.Font.GothamBold
champCode.ClearTextOnFocus = false
champCode.Parent = accueil
coin(champCode, 12)

local boutonRejoindre = bouton(accueil, "REJOINDRE", UDim2.new(0.16, 0, 0.055, 0), UDim2.new(0.605, 0, 0.60, 0), Color3.fromRGB(60, 130, 170))

-- NIVEAUX EGALISES : un interrupteur, pas un menu. Entre amis, la question n'est pas « qui a le
-- plus joue » mais « qui joue le mieux » — ce mode retire l'inventaire de l'equation, et le dit.
local egaliseActif = false
local boutonEgalise = bouton(accueil, "NIVEAUX EGALISES : NON", UDim2.new(0.24, 0, 0.045, 0), UDim2.new(0.245, 0, 0.665, 0), Color3.fromRGB(70, 60, 110))
boutonEgalise.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	egaliseActif = not egaliseActif
	boutonEgalise.Text = egaliseActif and "NIVEAUX EGALISES : OUI" or "NIVEAUX EGALISES : NON"
	message.Text = egaliseActif
		and ("Duel prive egalise : toutes les cartes au niveau " .. Egalise.NIVEAU .. ", hors classement.")
		or "Duel prive normal : chacun garde ses niveaux."
end)

boutonPrive.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local r = Boutique:InvokeServer("duelPrive", egaliseActif and "egalise" or nil)
	if r.ok and r.code then
		-- le code est AFFICHE en gros et groupe (« K7R-4M ») : il doit se lire a voix haute.
		codeAffiche.Text = "CODE A PARTAGER : " .. Prive.joli(r.code)
		codeAffiche.Visible = true
		message.Text = "Duel prive cree : donne ce code a ton ami, l'arene t'attend."
	else
		Sons.jouer("refus")
		message.Text = tostring(r.motif or "Duel prive indisponible.")
	end
end)

boutonRejoindre.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local saisi = Prive.normaliser(champCode.Text)
	if not Prive.valide(saisi) then
		Sons.jouer("refus")
		message.Text = Prive.motif("invalide")
		return
	end
	local r = Boutique:InvokeServer("rejoindreCode", saisi)
	if r.ok then
		message.Text = "Code accepte : depart vers l'arene de ton ami..."
	else
		Sons.jouer("refus")
		message.Text = tostring(r.motif or "Code refuse.")
	end
end)

-- DUEL ENTRE AMIS : UN bouton sur l'accueil, et ses controles dans un panneau. Ces cinq controles,
-- toujours visibles au centre, n'y tenaient pas : ils finissaient SOUS la rangee de coffres (capture
-- 2026-09-21). Ils ne servent qu'a qui veut affronter un ami, ils peuvent attendre un clic.
-- Les controles sont DEPLACES, pas recrees : leurs gestionnaires ci-dessus restent inchanges.
-- Bloc `do` : ses variables ne pesent pas sur la limite Luau de 200 variables locales du fichier.
do
	-- VOILE : une fenetre doit ASSOMBRIR ce qu'elle recouvre. Sans lui, les bords du titre et des
	-- lignes d'information depassaient autour du panneau, a pleine intensite (capture 2026-09-21).
	-- Il capte aussi les clics : on ne lance pas une partie par megarde derriere le panneau ouvert.
	local voile = Instance.new("TextButton")
	voile.Name = "VoileAmis"
	voile.Text = ""
	voile.AutoButtonColor = false
	voile.BackgroundColor3 = Color3.fromRGB(4, 6, 14)
	voile.BackgroundTransparency = 0.35
	voile.BorderSizePixel = 0
	voile.Size = UDim2.new(1, 0, 1, 0)
	voile.Position = UDim2.new(0, 0, 0, 0)
	voile.ZIndex = 19
	voile.Visible = false
	voile.Parent = accueil
	local panneau = Instance.new("Frame")
	panneau.Name = "PanneauAmis"
	panneau.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
	panneau.BorderSizePixel = 0
	panneau.Visible = false
	-- Au premier plan dans les DEUX modes d'empilement de Roblox : le panneau ET chacun de ses
	-- enfants portent un plan eleve, sans dependre du reglage par defaut de l'ecran.
	panneau.ZIndex = 20
	panneau.Parent = accueil
	MiseMenu.placer(panneau, MiseMenu.ACCUEIL.panneauAmis, UDim2)
	coin(panneau, 16)

	local titreAmis = texte(panneau, "DUEL ENTRE AMIS", UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), OR)
	MiseMenu.placer(titreAmis, MiseMenu.PANNEAU.titre, UDim2)
	local fermerAmis = bouton(panneau, "X", UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(150, 60, 70))
	MiseMenu.placer(fermerAmis, MiseMenu.PANNEAU.fermer, UDim2)

	boutonPrive.Parent = panneau
	champCode.Parent = panneau
	boutonRejoindre.Parent = panneau
	boutonEgalise.Parent = panneau
	codeAffiche.Parent = panneau
	MiseMenu.placer(boutonPrive, MiseMenu.PANNEAU.prive, UDim2)
	MiseMenu.placer(champCode, MiseMenu.PANNEAU.code, UDim2)
	MiseMenu.placer(boutonRejoindre, MiseMenu.PANNEAU.rejoindre, UDim2)
	MiseMenu.placer(boutonEgalise, MiseMenu.PANNEAU.egalise, UDim2)
	MiseMenu.placer(codeAffiche, MiseMenu.PANNEAU.codeAffiche, UDim2)
	-- CE QUE MET EN JEU LE DUEL : texte du module Duel, remis a jour a chaque bascule.
	do
		local aide = texte(panneau, "", UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(190, 200, 225))
		MiseMenu.placer(aide, MiseMenu.PANNEAU.aide, UDim2)
		aide.TextWrapped = true
		local function majAide()
			local D = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Duel"))
			local E = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Egalise"))
			aide.Text = D.texteAide(egaliseActif, E.NIVEAU)
		end
		majAide()
		boutonEgalise.MouseButton1Click:Connect(function()
			task.defer(majAide)
		end)
	end
	for _, enfant in ipairs(panneau:GetChildren()) do
		if enfant:IsA("GuiObject") then
			enfant.ZIndex = 21
		end
	end

	local boutonAmis = bouton(accueil, "DUEL ENTRE AMIS", UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(95, 70, 160))
	MiseMenu.placer(boutonAmis, MiseMenu.ACCUEIL.duelAmis, UDim2)
	boutonAmis.MouseButton1Click:Connect(function()
		Sons.jouer("clic")
		panneau.Visible = not panneau.Visible
	end)
	fermerAmis.MouseButton1Click:Connect(function()
		Sons.jouer("clic")
		panneau.Visible = false
	end)
	-- Le voile suit le panneau, quelle que soit la facon dont il s'ouvre ou se ferme.
	panneau:GetPropertyChangedSignal("Visible"):Connect(function()
		voile.Visible = panneau.Visible
	end)
	-- COPIE DE TEST (build.py --autotest --amis) : panneau ouvert d'emblee, pour le capturer — une
	-- capture ne sait pas cliquer.
	if ReplicatedStorage:FindFirstChild("BRR_AMIS") then
		panneau.Visible = true
	end
end

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
-- QUITTER UNE PARTIE EN COURS COMPTE MAINTENANT COMME UNE DEFAITE (le serveur donne la victoire
-- a l'adversaire humain). Un seul clic sur MENU, souvent presse par erreur, ne doit donc plus
-- suffire : il faut confirmer. Contre le robot, rien n'est perdu et le premier clic suffit.
local menuArme = 0
boutonMenu.MouseButton1Click:Connect(function()
	Sons.jouer("clic")
	local duel = Boutique:InvokeServer("enMatch").ok
	if duel and os.clock() - menuArme > 3 then
		menuArme = os.clock()
		message.Text = "Abandonner la partie ? Appuie encore sur MENU (defaite)."
		boutonMenu.Text = "ABANDONNER ?"
		task.delay(3, function()
			if os.clock() - menuArme >= 3 then
				boutonMenu.Text = "MENU"
			end
		end)
		return
	end
	menuArme = 0
	boutonMenu.Text = "MENU"
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
-- PORTRAIT 3D DU PERSONNAGE dans la carte : le MODELE DU JEU (ReplicatedStorage.Modeles), rendu dans
-- une vue 3D — et non la vignette du catalogue, qui aurait reintroduit une dependance exterieure que
-- Cards.lua refuse explicitement (voir src/shared/Portrait.lua). Rangee dans `jeuxDeck` plutot que
-- dans une variable : ce fichier est a la limite Luau de 200 variables locales.
jeuxDeck.portrait = function(vue, id)
	-- Le rendu vit dans src/shared/Figurine.lua, partage avec la partie : modele 3D, sinon silhouette
	-- en morceaux (comme en jeu), sinon embleme du sort. Charge a l'usage : aucune variable locale de
	-- plus dans ce fichier, qui est a la limite Luau de 200.
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Figurine")).rendre(vue, id)
end
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
	local bordCase = contour(case, 2)
	local portrait = Instance.new("ViewportFrame")
	portrait.Name = "Portrait"
	portrait.BackgroundTransparency = 1
	-- PLEINE CARTE : dans la seule moitie haute, le personnage ne faisait qu'une vingtaine de pixels
	-- (capture du 2026-09-21). Le nom passe DEVANT, sur un bandeau sombre qui le garde lisible.
	portrait.Size = UDim2.new(1, 0, 1, 0)
	portrait.Position = UDim2.new(0, 0, 0, 0)
	portrait.Ambient = Color3.fromRGB(170, 170, 185)
	portrait.LightColor = Color3.fromRGB(255, 250, 240)
	portrait.LightDirection = Vector3.new(-1, -1.4, 1)
	portrait.Visible = false
	portrait.Parent = case
	local bandeau = Instance.new("Frame")
	bandeau.Name = "Bandeau"
	bandeau.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
	bandeau.BackgroundTransparency = 0.35
	bandeau.BorderSizePixel = 0
	bandeau.Size = UDim2.new(1, 0, 0.42, 0)
	bandeau.Position = UDim2.new(0, 0, 0.58, 0)
	bandeau.ZIndex = 2
	bandeau.Parent = case
	local nom = texte(case, "", UDim2.new(0.9, 0, 0.38, 0), UDim2.new(0.05, 0, 0.6, 0))
	nom.ZIndex = 3
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
	casesDeck[i] = { case = case, nom = nom, pastille = pastille, cout = cout, portrait = portrait, bord = bordCase }
end
table.insert(jeuxDeck, casesDeck)
end
construireRangeeDeck(accueil, UDim2.new(0.76, 0, 0.13, 0), UDim2.new(0.12, 0, 0.845, 0))
-- ALERTE EMPLACEMENTS PLEINS, entre la rangee de coffres et « TON DECK » (zone libre).
montee.coffresPleins = texte(accueil, "", UDim2.new(0.62, 0, 0.026, 0), UDim2.new(0.25, 0, 0.805, 0),
	Color3.fromRGB(255, 150, 90), Enum.TextXAlignment.Center)
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
		jeuxDeck.portrait(d.portrait, card and card.id or nil)
		-- BORDURE DE RARETE (orange-or pour une legendaire) ; case vide : contour sombre d'origine
		local rar = card and Cards.RARETES[card.rarete]
		d.bord.Color = rar and rar.couleur or Color3.fromRGB(12, 14, 24)
		d.bord.Thickness = rar and (card.rarete == "commune" and 2 or 4) or 2
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

-- PERSONNAGE VEDETTE : le meme rendu que les cartes du deck, en grand, dans la colonne de gauche.
-- Place ICI, apres la definition de `jeuxDeck.portrait` : appele plus haut (dans le bloc du duel
-- entre amis), `jeuxDeck` valait encore nil — le script s'arretait sur l'erreur, et tout ce qui le
-- suit (deck, onglets, bandeau de ressources) n'etait jamais construit (capture du 2026-09-21).
do
	local vedette = Instance.new("ViewportFrame")
	vedette.Name = "Vedette"
	vedette.BackgroundTransparency = 1
	vedette.Ambient = Color3.fromRGB(170, 170, 185)
	vedette.LightColor = Color3.fromRGB(255, 250, 240)
	vedette.LightDirection = Vector3.new(-1, -1.4, 1)
	vedette.Parent = accueil
	MiseMenu.placer(vedette, MiseMenu.ACCUEIL.vedette, UDim2)
	jeuxDeck.portrait(vedette, "Tralalero")
end

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
-- Les trophees de chacun viennent de leaderstats.Trophees (dossier replique a TOUS les clients
-- par Roblox) : la liste est triee du plus fort au plus faible et dit l'ecart avec toi.
local function majMembres()
	local liste = Players:GetPlayers()
	local membres = {}
	for _, j in ipairs(liste) do
		local ls = j:FindFirstChild("leaderstats")
		local tr = ls and ls:FindFirstChild("Trophees")
		table.insert(membres, { nom = j.DisplayName, trophees = tr and tr.Value or nil, moi = j == player })
	end
	local lignes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Adversaire")).lignesMembres(membres)
	for i = 1, 10 do
		lignesMembres[i].Text = lignes[i] or "place libre"
		lignesMembres[i].TextColor3 = lignes[i] and Color3.fromRGB(220, 225, 235) or Color3.fromRGB(110, 120, 148)
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
	majMembres() -- les trophees ont pu changer depuis l'arrivee des joueurs
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
-- (appel sans variable : ce texte n'est jamais relu, et le fichier est a la limite Luau de 200
-- variables locales — une variable qui ne sert a rien y prenait une place utile)
texte(clanEcran, "Invite un ami : il arrive sur ce serveur et tu peux le defier.",
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
		messageEvenements.Text = r.ok and ("Quete finie : +" .. tostring(r.motif) .. " pieces"
			.. ((r.gemmes or 0) > 0 and ("  +" .. r.gemmes .. " gemmes") or ""))
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
			l.action.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quetes")).recompense(q.gain, q.gemmes)
			l.ligne.TextColor3 = q.recue and Color3.fromRGB(130, 140, 155) or Color3.fromRGB(215, 222, 235)
		else
			l.id = nil
			l.ligne.Text = ""
			l.action.Visible = false
		end
	end
	local reste = e.coffreGratuitReste or 0
	if reste <= 0 then
		infoCoffreGratuit.Text = #(v.coffres or {}) >= 4 and "Pret, mais tes 4 emplacements sont pleins : ouvre d'abord un coffre."
			or "Un coffre d'argent t'attend."
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
-- ===== ECRAN DES REGLES DU JEU =====
-- Quatre mecaniques decident des parties et n'etaient expliquees NULLE PART : l'elixir double,
-- la prolongation, la zone de pose qui s'ouvre quand une tour tombe, et l'avantage de terrain.
-- Elles ne tiennent pas sur une fiche de carte (elles seraient repetees a l'identique sur les 40
-- cartes) : elles ont donc leur ecran, atteignable depuis l'accueil.
--
-- Les textes viennent du module Manuel, qui les CALCULE a partir des constantes reelles lues ici.
-- Un reglage qui change change le manuel avec lui : cet ecran ne peut pas mentir sur le jeu.
local function valeursDuJeu()
	return {
		dureeMatch = DUREE_MATCH_AFFICHEE,
		doublePart = Regles.DOUBLE_ELIXIR_PART,
		multDouble = Regles.MULT_DOUBLE,
		multProlongation = Regles.MULT_PROLONGATION,
		prolongationPart = Regles.PROLONGATION_PART,
		terrainRayon = Terrain.RAYON,
		terrainReduction = Terrain.REDUCTION,
		elixirMax = 10,
		-- combien de cartes adverses le panneau de lecture garde a l'ecran : la valeur vient du
		-- module qui la fait respecter, pas d'un chiffre recopie dans le texte.
		cartesVues = Lecture.CARTES_VUES,
		-- UNE COURONNE VIENT-ELLE AUSSI DES BATIMENTS POSES ? La reponse vit dans Batiments, pas
		-- dans le texte du manuel. Module charge DANS la fonction : le corps de ce script est au
		-- plafond des 200 variables locales de Lua.
		batimentCouronne = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Batiments")).donneCouronne(),
		-- LA POSE : les deux chiffres viennent des modules qui les appliquent, jamais recopies.
		deploiement = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Deploiement")).DUREE,
		invulnPose = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Statuts")).INVULN_POSE,
		-- DERNIERE GARDE : le chiffre vient du module qui l'applique, jamais recopie.
		gardeFacteur = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Garde")).FACTEUR,
		-- PROGRESSION : chiffres des modules qui les appliquent.
		emplacements = 4, -- Economie.EMPLACEMENTS (serveur) ; verifie par test_manuel_progression
		minutesParGemme = require(ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Coffres")).MINUTES_PAR_GEMME,
		gemmesQuete = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quetes")).GEMMES,
	}
end

local reglesEcran = Instance.new("Frame")
reglesEcran.Name = "ReglesDuJeu"
reglesEcran.Size = UDim2.new(0, 640, 0, 560)
reglesEcran.Position = UDim2.new(0.5, -320, 0.5, -280)
reglesEcran.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
reglesEcran.BorderSizePixel = 0
reglesEcran.Visible = false
reglesEcran.ZIndex = 50
reglesEcran.Parent = gui
coin(reglesEcran, 16)
contour(reglesEcran, 3, Color3.fromRGB(255, 215, 110), 0)

texte(reglesEcran, "REGLES DU JEU", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 12), OR).ZIndex = 51

-- Liste DEFILANTE : le manuel grandira avec le jeu, et un cadre fixe finirait par tronquer.
local reglesListe = Instance.new("ScrollingFrame")
-- La liste s'arrete AU-DESSUS du bouton : a -128 elle passait dessous et la derniere section
-- etait masquee par lui (capture cap-regles.png du 2026-09-20). 64 en haut, puis le pied
-- complet du module (marge + bouton + bas), comme les panneaux de fiche.
reglesListe.Size = UDim2.new(1, -28, 1, -(64 + Fiche.PANNEAU_PIED))
reglesListe.Position = UDim2.new(0, 14, 0, 64)
reglesListe.BackgroundTransparency = 1
reglesListe.BorderSizePixel = 0
reglesListe.ScrollBarThickness = 6
reglesListe.CanvasSize = UDim2.new(0, 0, 0, 0)
reglesListe.AutomaticCanvasSize = Enum.AutomaticSize.Y
reglesListe.ZIndex = 51
reglesListe.Parent = reglesEcran
local reglesLayout = Instance.new("UIListLayout")
reglesLayout.SortOrder = Enum.SortOrder.LayoutOrder
reglesLayout.Padding = UDim.new(0, 10)
reglesLayout.Parent = reglesListe
-- HAUTEUR DEFILABLE = hauteur REELLE du contenu. AutomaticCanvasSize ne suivait pas les blocs de
-- texte qui s'agrandissent en s'enroulant : barre tout en bas, la derniere section (PROGRESSION)
-- restait coupee (capture regles-prog.png, 2026-09-21). La mise en page mesure son contenu : on
-- s'aligne sur SA mesure, a chaque changement.
reglesListe.AutomaticCanvasSize = Enum.AutomaticSize.None
reglesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	reglesListe.CanvasSize = UDim2.new(0, 0, 0, reglesLayout.AbsoluteContentSize.Y + 12)
end)

for i, section in ipairs(Manuel.sections(valeursDuJeu())) do
	local bloc = Instance.new("Frame")
	bloc.BackgroundTransparency = 1
	-- HAUTEUR LIBRE : a 72 px fixes, une section de plus de deux lignes etait rognee et venait
	-- toucher le titre suivant. Le bloc grandit avec son texte, la liste defile pour le reste.
	bloc.Size = UDim2.new(1, -8, 0, 0)
	bloc.AutomaticSize = Enum.AutomaticSize.Y
	bloc.LayoutOrder = i
	bloc.ZIndex = 51
	bloc.Parent = reglesListe
	local t = texte(bloc, section.titre, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), OR,
		Enum.TextXAlignment.Left)
	t.ZIndex = 52
	t.TextScaled = false
	t.TextSize = 17
	local c = texte(bloc, section.texte, UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 0, 24),
		Color3.fromRGB(225, 228, 238), Enum.TextXAlignment.Left)
	c.ZIndex = 52
	c.TextScaled = false
	c.TextSize = 15
	c.TextWrapped = true
	c.TextYAlignment = Enum.TextYAlignment.Top
	c.AutomaticSize = Enum.AutomaticSize.Y
end

local reglesFermer = bouton(reglesEcran, "FERMER", UDim2.new(0, 170, 0, Fiche.PANNEAU_BOUTON),
	UDim2.new(0.5, -85, 1, -(Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS)), Color3.fromRGB(90, 90, 110))
reglesFermer.ZIndex = 52
reglesFermer.MouseButton1Click:Connect(function()
	reglesEcran.Visible = false
end)

function ouvrirRegles()
	reglesEcran.Visible = true
end

-- ECRAN DES DERNIERES PARTIES ---------------------------------------------------------------
-- Meme forme que le manuel (panneau centre, liste defilante, un seul bouton FERMER) : le joueur
-- n'a pas a apprendre deux fois la meme chose. Les LIGNES et le RESUME sont calcules par le
-- module Journal, jamais ecrits ici : l'ecran ne peut donc pas raconter autre chose que le profil.
local journalEcran = Instance.new("Frame")
journalEcran.Name = "DernieresParties"
journalEcran.Size = UDim2.new(0, 640, 0, 460)
journalEcran.Position = UDim2.new(0.5, -320, 0.5, -230)
journalEcran.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
journalEcran.BorderSizePixel = 0
journalEcran.Visible = false
journalEcran.ZIndex = 50
journalEcran.Parent = gui
coin(journalEcran, 16)
contour(journalEcran, 3, Color3.fromRGB(255, 215, 110), 0)

texte(journalEcran, "DERNIERES PARTIES", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 12), OR).ZIndex = 51
local journalResume = texte(journalEcran, "", UDim2.new(1, -28, 0, 22), UDim2.new(0, 14, 0, 56),
	Color3.fromRGB(205, 212, 228))
journalResume.ZIndex = 51
journalResume.TextScaled = false
journalResume.TextSize = 15

local journalListe = Instance.new("ScrollingFrame")
journalListe.Size = UDim2.new(1, -28, 1, -(86 + Fiche.PANNEAU_PIED))
journalListe.Position = UDim2.new(0, 14, 0, 86)
journalListe.BackgroundTransparency = 1
journalListe.BorderSizePixel = 0
journalListe.ScrollBarThickness = 6
journalListe.CanvasSize = UDim2.new(0, 0, 0, 0)
journalListe.AutomaticCanvasSize = Enum.AutomaticSize.Y
journalListe.ZIndex = 51
journalListe.Parent = journalEcran
local journalLayout = Instance.new("UIListLayout")
journalLayout.SortOrder = Enum.SortOrder.LayoutOrder
journalLayout.Padding = UDim.new(0, 6)
journalLayout.Parent = journalListe

local journalFermer = bouton(journalEcran, "FERMER", UDim2.new(0, 170, 0, Fiche.PANNEAU_BOUTON),
	UDim2.new(0.5, -85, 1, -(Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS)), Color3.fromRGB(90, 90, 110))
journalFermer.ZIndex = 52
journalFermer.MouseButton1Click:Connect(function()
	journalEcran.Visible = false
end)

function ouvrirJournal()
	-- On RELIT le profil a l'ouverture : la partie qui vient de finir doit y etre, pas l'etat
	-- charge au demarrage du hub.
	local v = Boutique:InvokeServer("profil").vue or {}
	local liste = v.journal or {}
	local maintenant = v.maintenant or os.time()
	for _, enfant in ipairs(journalListe:GetChildren()) do
		if enfant:IsA("TextLabel") then
			enfant:Destroy()
		end
	end
	journalResume.Text = v.journalResume or Journal.resume(liste)
	if #liste == 0 then
		local vide = texte(journalListe, "Joue une partie : elle s'affichera ici.",
			UDim2.new(1, -8, 0, 26), UDim2.new(0, 0, 0, 0), Color3.fromRGB(165, 175, 195),
			Enum.TextXAlignment.Left)
		vide.ZIndex = 52
		vide.TextScaled = false
		vide.TextSize = 15
	end
	for i, e in ipairs(liste) do
		local rgb = Journal.teinte(e.issue)
		local l = texte(journalListe, Journal.ligne(e, maintenant), UDim2.new(1, -8, 0, 26),
			UDim2.new(0, 0, 0, 0), Color3.fromRGB(rgb[1], rgb[2], rgb[3]), Enum.TextXAlignment.Left)
		l.LayoutOrder = i
		l.ZIndex = 52
		l.TextScaled = false
		l.TextSize = 16
	end
	journalEcran.Visible = true
end

-- Ce panneau garde ses variables dans un BLOC `do ... end` : le corps principal du fichier
-- touchait la limite de Lua (200 variables locales) et REFUSAIT de compiler. Seul
-- `ouvrirSon`, declare plus haut, en sort.
do
	-- ECRAN DU SON ---------------------------------------------------------------------------------
	-- Deux interrupteurs, pas un curseur : la question posee est « ca sonne ou pas », et un curseur
	-- demanderait un geste precis sur telephone. Les deux se reglent A PART — les bruitages PORTENT de
	-- l'information (une tour qui tombe, une carte refusee), la musique non.
	local sonEcran = Instance.new("Frame")
	sonEcran.Name = "ReglagesSon"
	sonEcran.Size = UDim2.new(0, 460, 0, 250)
	sonEcran.Position = UDim2.new(0.5, -230, 0.5, -125)
	sonEcran.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
	sonEcran.BorderSizePixel = 0
	sonEcran.Visible = false
	sonEcran.ZIndex = 50
	sonEcran.Parent = gui
	coin(sonEcran, 16)
	contour(sonEcran, 3, Color3.fromRGB(255, 215, 110), 0)
	texte(sonEcran, "SON", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 0, 12), OR).ZIndex = 51

	local sonMusique = bouton(sonEcran, "MUSIQUE : OUI", UDim2.new(0, 400, 0, 46), UDim2.new(0, 30, 0, 66),
		Color3.fromRGB(60, 80, 130))
	sonMusique.ZIndex = 52
	local sonBruitages = bouton(sonEcran, "BRUITAGES : OUI", UDim2.new(0, 400, 0, 46), UDim2.new(0, 30, 0, 122),
		Color3.fromRGB(60, 80, 130))
	sonBruitages.ZIndex = 52

	local COUPE = Color3.fromRGB(80, 60, 70)
	local ALLUME = Color3.fromRGB(60, 80, 130)
	local function majSon()
		-- Les libelles viennent du module : les deux ecrans ne peuvent pas les ecrire differemment.
		sonMusique.Text = Sons.libelle("musique")
		sonBruitages.Text = Sons.libelle("bruitages")
		sonMusique.BackgroundColor3 = Sons.reglages.musique and ALLUME or COUPE
		sonBruitages.BackgroundColor3 = Sons.reglages.bruitages and ALLUME or COUPE
	end

	-- Un changement s'applique TOUT DE SUITE chez le client, puis part au serveur pour etre garde.
	-- L'inverse (attendre la reponse) ferait un interrupteur qui repond avec un temps de retard.
		basculerSon = function(quoi)
		local m, b = nil, nil
		if quoi == "musique" then
			m = not Sons.reglages.musique
		else
			b = not Sons.reglages.bruitages
		end
		Sons.regler(m, b)
		majSon()
		Sons.jouer("clic")
		task.spawn(function()
			Boutique:InvokeServer("son", { musique = Sons.reglages.musique, bruitages = Sons.reglages.bruitages })
		end)
		print("[HUB] son : musique=" .. tostring(Sons.reglages.musique)
			.. " bruitages=" .. tostring(Sons.reglages.bruitages))
	end
	sonMusique.MouseButton1Click:Connect(function() basculerSon("musique") end)
	sonBruitages.MouseButton1Click:Connect(function() basculerSon("bruitages") end)

	local sonFermer = bouton(sonEcran, "FERMER", UDim2.new(0, 170, 0, Fiche.PANNEAU_BOUTON),
		UDim2.new(0.5, -85, 1, -(Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS)), Color3.fromRGB(90, 90, 110))
	sonFermer.ZIndex = 52
	sonFermer.MouseButton1Click:Connect(function()
		sonEcran.Visible = false
	end)

	function ouvrirSon()
		majSon()
		sonEcran.Visible = true
	end

end

-- PANNEAU DE FIN DE SAISON -----------------------------------------------------------------------
-- La bascule se produit au CHARGEMENT du profil : trophees ramenes vers le plancher, pieces
-- versees, en silence. Le joueur rouvrait le jeu avec 300 trophees de moins sans un mot — la
-- punition se voyait, la recompense non. Le panneau s'ouvre UNE fois, puis le serveur oublie le
-- bilan (action « saisonVue »).
-- PASS DE SAISON (2026-09-21) : ecran plein, ouvert par le bouton PASS DE SAISON de l'accueil.
-- Une bande de 20 paliers a faire defiler : piste GRATUITE en haut, PREMIUM (or) en bas. Chaque
-- case dit sa recompense et son etat : verrouillee, A PRENDRE (bouton), prise. Regles, points et
-- recompenses : module PassSaison ; le serveur reverifie tout (Economie.reclamerPalier).
-- Tout vit dans `montee`, dans une FONCTION : ses variables ne comptent pas dans les 200 du fichier.
;(function()
	local PassSaison = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PassSaison"))
	local P = {}
	montee.pass = P
	P.bouton = bouton(accueil, "PASS DE SAISON", UDim2.new(0.12, 0, 0.045, 0), UDim2.new(0.02, 0, 0.48, 0),
		Color3.fromRGB(150, 90, 220))
	MiseMenu.placer(P.bouton, MiseMenu.ACCUEIL.pass, UDim2)
	P.pastille = texte(P.bouton, "", UDim2.fromOffset(26, 26), UDim2.new(1, -16, 0, -10), Color3.new(1, 1, 1))
	P.pastille.BackgroundTransparency = 0
	P.pastille.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	P.pastille.Visible = false
	P.pastille.ZIndex = 5
	coin(P.pastille, 13)

	P.ecran = Instance.new("Frame")
	P.ecran.Name = "PanneauPass"
	P.ecran.Size = UDim2.fromScale(0.92, 0.84)
	P.ecran.Position = UDim2.fromScale(0.04, 0.08)
	P.ecran.BackgroundColor3 = Color3.fromRGB(22, 20, 44)
	P.ecran.Visible = false
	P.ecran.ZIndex = 60
	P.ecran.Parent = gui
	coin(P.ecran, 16)
	degrade(P.ecran, Color3.fromRGB(70, 50, 130), Color3.fromRGB(14, 14, 30))
	contour(P.ecran, 3, OR, 0)
	local function z(o, n)
		o.ZIndex = n
		return o
	end
	z(texte(P.ecran, "PASS DE SAISON", UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.03, 0.02), OR, Enum.TextXAlignment.Left), 61)
	P.sousTitre = z(texte(P.ecran, "", UDim2.fromScale(0.55, 0.045), UDim2.fromScale(0.03, 0.105),
		Color3.fromRGB(200, 205, 225), Enum.TextXAlignment.Left), 61)
	-- barre d'avancee dans le palier en cours
	P.jaugeFond = Instance.new("Frame")
	P.jaugeFond.Size = UDim2.fromScale(0.55, 0.03)
	P.jaugeFond.Position = UDim2.fromScale(0.03, 0.165)
	P.jaugeFond.BackgroundColor3 = Color3.fromRGB(35, 34, 60)
	P.jaugeFond.ZIndex = 61
	P.jaugeFond.Parent = P.ecran
	coin(P.jaugeFond, 6)
	P.jauge = Instance.new("Frame")
	P.jauge.Size = UDim2.fromScale(0, 1)
	P.jauge.BackgroundColor3 = Color3.fromRGB(150, 230, 90)
	P.jauge.ZIndex = 62
	P.jauge.Parent = P.jaugeFond
	coin(P.jauge, 6)
	-- sous la liste des joueurs de Roblox, qui couvre le coin haut droit (capture du 2026-09-21)
	P.premium = z(bouton(P.ecran, "PREMIUM", UDim2.fromScale(0.22, 0.08), UDim2.fromScale(0.64, 0.135), OR), 61)
	-- PASTILLE « P » du pass de saison premium : la 5e offre Robux, vendue ici et non en boutique.
	do
		local pastille = Instance.new("Frame")
		pastille.Name = "Pastille"
		pastille.Size = UDim2.fromScale(0.2, 0.8)
		pastille.Position = UDim2.fromScale(0.03, 0.1)
		-- violet fonce : une pastille claire sur le bouton dore ne se voyait pas (capture du 2026-09-27)
		pastille.BackgroundColor3 = Color3.fromRGB(60, 40, 120)
		pastille.ZIndex = 62
		pastille.Parent = P.premium
		Instance.new("UIAspectRatioConstraint").Parent = pastille
		coin(pastille, 100)
		contour(pastille, 2)
		texte(pastille, "P", UDim2.fromScale(0.64, 0.64), UDim2.fromScale(0.18, 0.18), OR).ZIndex = 63
		-- libelle a droite de la pastille (voir les offres de la boutique) ; majPass l'ecrit ici
		P.premiumTexte = texte(P.premium, P.premium.Text, UDim2.fromScale(0.72, 0.9), UDim2.fromScale(0.25, 0.05), Color3.new(1, 1, 1))
		P.premiumTexte.ZIndex = 62
		P.premium.Text = ""
	end
	P.fermer = z(bouton(P.ecran, "X", UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.91, 0.135),
		Color3.fromRGB(170, 60, 70)), 61)
	P.message = z(texte(P.ecran, "", UDim2.fromScale(0.9, 0.045), UDim2.fromScale(0.05, 0.935), OR), 61)
	-- libelles dans une colonne A GAUCHE de la bande : poses au-dessus, « PREMIUM » passait sous le
	-- numero du palier 1 (capture du 2026-09-21)
	z(texte(P.ecran, "GRATUIT", UDim2.fromScale(0.1, 0.05), UDim2.fromScale(0.015, 0.37),
		Color3.fromRGB(190, 200, 220)), 61)
	z(texte(P.ecran, "PREMIUM", UDim2.fromScale(0.1, 0.05), UDim2.fromScale(0.015, 0.75), OR), 61)

	P.bande = Instance.new("ScrollingFrame")
	P.bande.Size = UDim2.fromScale(0.85, 0.68)
	P.bande.Position = UDim2.fromScale(0.125, 0.24)
	P.bande.BackgroundTransparency = 1
	P.bande.ScrollingDirection = Enum.ScrollingDirection.X
	P.bande.ScrollBarThickness = 8
	P.bande.CanvasSize = UDim2.fromScale(PassSaison.PALIERS * 0.2, 0)
	P.bande.ZIndex = 61
	P.bande.Parent = P.ecran
	P.cases = {}
	local largeur = 1 / PassSaison.PALIERS
	for i = 1, PassSaison.PALIERS do
		local colonne = Instance.new("Frame")
		colonne.BackgroundTransparency = 1
		colonne.Size = UDim2.fromScale(largeur, 1)
		colonne.Position = UDim2.fromScale((i - 1) * largeur, 0)
		colonne.ZIndex = 61
		colonne.Parent = P.bande
		local num = z(texte(colonne, tostring(i), UDim2.fromScale(0.4, 0.1), UDim2.fromScale(0.3, 0.44)), 63)
		num.BackgroundTransparency = 0
		num.BackgroundColor3 = Color3.fromRGB(45, 42, 80)
		coin(num, 10)
		P.cases[i] = { num = num }
		for _, piste in ipairs({ "gratuit", "premium" }) do
			local y = piste == "gratuit" and 0.0 or 0.57
			local c = Instance.new("Frame")
			c.Size = UDim2.fromScale(0.88, 0.41)
			c.Position = UDim2.fromScale(0.06, y)
			c.BackgroundColor3 = piste == "premium" and Color3.fromRGB(95, 70, 20) or Color3.fromRGB(40, 48, 78)
			c.ZIndex = 62
			c.Parent = colonne
			coin(c, 10)
			local bord = contour(c, 3, piste == "premium" and OR or Color3.fromRGB(120, 140, 190), 0.1)
			local r = PassSaison.recompense(i, piste)
			local quoi = z(texte(c, r.texte, UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.1)), 63)
			local etat = z(texte(c, "", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.5),
				Color3.fromRGB(200, 205, 225)), 63)
			local prendre = z(bouton(c, "PRENDRE", UDim2.fromScale(0.86, 0.3), UDim2.fromScale(0.07, 0.64),
				Color3.fromRGB(60, 170, 80)), 64)
			prendre.Visible = false
			prendre.MouseButton1Click:Connect(function()
				local rep = Boutique:InvokeServer("pass", { palier = i, piste = piste })
				Sons.jouer(rep.ok and "coffre" or "refus")
				P.message.Text = rep.ok and ("Palier " .. i .. " : +" .. tostring(rep.motif)) or ("Pass : " .. tostring(rep.motif))
				if rep.vue then
					afficher(rep.vue)
				end
			end)
			P.cases[i][piste] = { cadre = c, bord = bord, quoi = quoi, etat = etat, prendre = prendre }
		end
	end

	function montee.majPass(pv)
		if not pv then
			return
		end
		-- pv.reste dit deja « Saison 45 : 1 j 13 h » (la 1re version repetait la saison, capture du 2026-09-21)
		P.sousTitre.Text = string.format("%s restants  -  Palier %d / %d  (%d / %d points)",
			tostring(pv.reste or "?"), pv.palier or 0, PassSaison.PALIERS, pv.dans or 0, pv.sur or 0)
		P.jauge.Size = UDim2.fromScale((pv.sur or 0) > 0 and pv.dans / pv.sur or 1, 1)
		P.premiumTexte.Text = pv.premium and "PREMIUM ACTIF" or "PREMIUM"
		local etat = { points = pv.points, reclames = pv.reclames }
		for i = 1, PassSaison.PALIERS do
			local atteint = i <= (pv.palier or 0)
			P.cases[i].num.BackgroundColor3 = atteint and Color3.fromRGB(150, 230, 90) or Color3.fromRGB(45, 42, 80)
			for _, piste in ipairs({ "gratuit", "premium" }) do
				local k = P.cases[i][piste]
				-- le coffre d'or premium devient un gain fixe la ou le tirage payant est interdit
				k.quoi.Text = PassSaison.recompense(i, piste, pv.sansAleatoirePayant).texte
				local pris = pv.reclames and pv.reclames[piste] and pv.reclames[piste][tostring(i)]
				local verrou = piste == "premium" and not pv.premium
				local ok = PassSaison.peutReclamer(etat, i, piste, pv.premium)
				k.prendre.Visible = ok == true
				k.etat.Text = pris and "PRIS" or (verrou and "PREMIUM") or (atteint and "" or ("palier " .. i))
				k.cadre.BackgroundTransparency = (pris or (not atteint) or verrou) and 0.45 or 0
				k.bord.Color = ok == true and Color3.fromRGB(150, 230, 90)
					or (piste == "premium" and OR or Color3.fromRGB(120, 140, 190))
			end
		end
		local n = PassSaison.aPrendre(etat, pv.premium)
		P.pastille.Visible = n > 0
		P.pastille.Text = tostring(n)
	end

	P.bouton.MouseButton1Click:Connect(function()
		P.ecran.Visible = true
	end)
	P.fermer.MouseButton1Click:Connect(function()
		P.ecran.Visible = false
	end)
	P.premium.MouseButton1Click:Connect(function()
		local rep = Boutique:InvokeServer("passPremium")
		if not rep.ok then
			P.message.Text = tostring(rep.motif)
		end
	end)
	montee.majPass(montee.derniereVue and montee.derniereVue.pass)
	-- CAPTURE (build.py --pass-points=N) : ouvre le pass et prend le palier 1 gratuit, comme un joueur
	if ReplicatedStorage:FindFirstChild("BRR_PASS_POINTS") and ReplicatedStorage:FindFirstChild("BRR_HUB") then -- en partie, il couvrirait l ecran de fin
		task.delay(9, function()
			P.ecran.Visible = true
			local rep = Boutique:InvokeServer("pass", { palier = 1, piste = "gratuit" })
			print("[PASS] reclamation simulee du palier 1 :", rep.ok, rep.motif)
			if rep.vue then
				afficher(rep.vue)
			end
		end)
	end
end)()

-- COSMETIQUES (2026-09-21) : skins de TOURS et emotes PREMIUM, en GEMMES. Ouvert depuis la
-- BOUTIQUE. Chaque skin a son APERCU 3D (ViewportFrame) : une vraie petite tour, corps a la couleur
-- de MON camp, ornements du skin. Aucun effet sur le jeu (module Cosmetiques, test_cosmetiques.py).
-- Dans une FONCTION : ses variables ne comptent pas dans les 200 locales du fichier.
;(function()
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Cosmetiques = require(Shared:WaitForChild("Cosmetiques"))
	local Emotes = require(Shared:WaitForChild("Emotes"))
	local K = {}
	montee.cosmetiques = K
	local BLEU = Color3.fromRGB(70, 130, 230) -- mon camp : le corps de la tour garde cette couleur
	local function c3(t)
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	local function z(o, n)
		o.ZIndex = n
		return o
	end

	K.bouton = bouton(boutique, "COSMETIQUES", UDim2.new(0.19, 0, 0.05, 0), UDim2.new(0.79, 0, 0.11, 0),
		Color3.fromRGB(150, 90, 220))

	K.ecran = Instance.new("Frame")
	K.ecran.Name = "PanneauCosmetiques"
	K.ecran.Size = UDim2.fromScale(0.92, 0.84)
	K.ecran.Position = UDim2.fromScale(0.04, 0.08)
	K.ecran.BackgroundColor3 = Color3.fromRGB(22, 20, 44)
	K.ecran.Visible = false
	K.ecran.ZIndex = 70
	K.ecran.Parent = gui
	coin(K.ecran, 16)
	degrade(K.ecran, Color3.fromRGB(80, 50, 140), Color3.fromRGB(14, 14, 30))
	contour(K.ecran, 3, OR, 0)
	z(texte(K.ecran, "COSMETIQUES", UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.03, 0.02), OR, Enum.TextXAlignment.Left), 71)
	z(texte(K.ecran, "Apparence seulement : aucun effet sur la partie", UDim2.fromScale(0.55, 0.04),
		UDim2.fromScale(0.03, 0.1), Color3.fromRGB(200, 205, 225), Enum.TextXAlignment.Left), 71)
	-- sous la liste des joueurs de Roblox (coin haut droit), comme le pass
	-- solde SOUS le sous-titre, a gauche : en haut a droite, la liste des joueurs de Roblox le cachait
	K.gemmes = z(texte(K.ecran, "", UDim2.fromScale(0.3, 0.05), UDim2.fromScale(0.03, 0.148), Color3.fromRGB(140, 230, 255), Enum.TextXAlignment.Left), 71)
	K.fermer = z(bouton(K.ecran, "X", UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.91, 0.13), Color3.fromRGB(170, 60, 70)), 71)
	K.message = z(texte(K.ecran, "", UDim2.fromScale(0.9, 0.045), UDim2.fromScale(0.05, 0.94), OR), 71)

	-- APERCU 3D d'une tour : memes regles que appliquerSkinTour cote serveur (corps du camp,
	-- creneaux / toit / drapeau du skin, liseret neon).
	local function apercu(parent, s)
		local vf = Instance.new("ViewportFrame")
		vf.Size = UDim2.fromScale(0.9, 0.58)
		vf.Position = UDim2.fromScale(0.05, 0.04)
		vf.BackgroundColor3 = Color3.fromRGB(30, 40, 70)
		vf.BackgroundTransparency = 0.3
		vf.Ambient = Color3.fromRGB(170, 170, 185)
		vf.LightColor = Color3.new(1, 1, 1)
		vf.LightDirection = Vector3.new(-1, -1.4, -0.6)
		vf.ZIndex = 73
		vf.Parent = parent
		coin(vf, 10)
		local function piece(taille, cf, couleur, mat, forme)
			local p = Instance.new("Part")
			p.Anchored = true
			p.Size = taille
			p.CFrame = cf
			p.Color = couleur
			p.Material = Enum.Material[mat]
			if forme then
				p.Shape = forme
			end
			p.Parent = vf
			return p
		end
		piece(Vector3.new(6.2, 1, 6.2), CFrame.new(0, 0.5, 0), Color3.fromRGB(140, 135, 125), "Cobblestone")
		piece(Vector3.new(5, 7, 5), CFrame.new(0, 4.5, 0), BLEU, s.corps)
		for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
			piece(Vector3.new(1.2, 1.2, 1.2), CFrame.new(c[1] * 1.9, 8.6, c[2] * 1.9), c3(s.creneaux), s.creneauxMat)
		end
		piece(Vector3.new(3.5, 3.5, 3.5), CFrame.new(0, 9.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			s.toit and c3(s.toit) or BLEU:Lerp(Color3.new(0, 0, 0), 0.25), s.toitMat, Enum.PartType.Cylinder)
		piece(Vector3.new(0.2, 3.5, 0.2), CFrame.new(0, 11.5, 0), Color3.fromRGB(80, 60, 40), "Wood")
		piece(Vector3.new(1.8, 1.1, 0.1), CFrame.new(0.9, 12.6, 0), s.drapeau and c3(s.drapeau) or BLEU, "Fabric")
		if s.accent then
			piece(Vector3.new(5.3, 0.35, 5.3), CFrame.new(0, 7.7, 0), c3(s.accent), "Neon")
		end
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(Vector3.new(13, 12, 17), Vector3.new(0, 6, 0))
		cam.Parent = vf
		vf.CurrentCamera = cam
		return vf
	end

	-- GRILLE : 4 colonnes. D'abord les skins (classique compris, pour pouvoir y revenir), puis les emotes.
	local articles = {}
	for _, s in ipairs(Cosmetiques.SKINS) do
		table.insert(articles, { id = s.id, type = "skin", nom = s.nom, prix = s.prix, skin = s })
	end
	for _, e in ipairs(Emotes.LISTE) do
		if e.prix then
			table.insert(articles, { id = e.id, type = "emote", nom = e.texte, prix = e.prix, libelle = e.libelle })
		end
	end
	local grille = Instance.new("ScrollingFrame")
	grille.Size = UDim2.fromScale(0.94, 0.72)
	grille.Position = UDim2.fromScale(0.03, 0.21)
	grille.BackgroundTransparency = 1
	grille.ScrollBarThickness = 8
	grille.ZIndex = 71
	grille.Parent = K.ecran
	local lignes = math.ceil(#articles / 4)
	grille.CanvasSize = UDim2.fromScale(0, math.max(1, lignes * 0.52))
	K.cartes = {}
	for i, a in ipairs(articles) do
		local col, lig = (i - 1) % 4, math.floor((i - 1) / 4)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0.235, 0, 0.47 / math.max(1, lignes * 0.52), 0)
		f.Position = UDim2.new(col * 0.25 + 0.005, 0, lig * 0.52 / math.max(1, lignes * 0.52), 0)
		f.BackgroundColor3 = Color3.fromRGB(36, 34, 70)
		f.ZIndex = 72
		f.Parent = grille
		coin(f, 12)
		local bord = contour(f, 3, a.type == "emote" and OR or Color3.fromRGB(150, 110, 240), 0.1)
		if a.type == "skin" then
			apercu(f, a.skin)
		else
			-- EMOTE : la bulle telle qu'elle s'affichera au-dessus du Roi
			local bulle = z(texte(f, a.nom, UDim2.fromScale(0.86, 0.4), UDim2.fromScale(0.07, 0.12), Color3.fromRGB(20, 20, 30)), 74)
			bulle.BackgroundTransparency = 0
			bulle.BackgroundColor3 = Color3.new(1, 1, 1)
			coin(bulle, 14)
			z(texte(f, "EMOTE  " .. a.libelle, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.54), OR), 74)
		end
		z(texte(f, a.type == "skin" and a.nom or "", UDim2.fromScale(0.92, 0.12), UDim2.fromScale(0.04, 0.63)), 74)
		local action = z(bouton(f, "", UDim2.fromScale(0.86, 0.19), UDim2.fromScale(0.07, 0.78), OR), 75)
		action.MouseButton1Click:Connect(function()
			local c = K.vue or {}
			local possede = c.possedes and c.possedes[a.id]
			if possede and a.type == "emote" then
				return
			end
			local rep = Boutique:InvokeServer("cosmetique", { id = a.id, equiper = possede and a.type == "skin" })
			Sons.jouer(rep.ok and "coffre" or "refus")
			K.message.Text = rep.ok and (possede and (a.nom .. " equipe") or (a.nom .. " : a toi !"))
				or ("Cosmetiques : " .. tostring(rep.motif))
			if rep.vue then
				afficher(rep.vue)
			end
		end)
		K.cartes[i] = { a = a, action = action, bord = bord }
	end

	function montee.majCosmetiques(v)
		if not v then
			return
		end
		local c = Cosmetiques.normaliser(v.cosmetiques)
		K.vue = c
		K.gemmes.Text = tostring(v.gemmes or 0) .. " gemmes"
		for _, k in ipairs(K.cartes) do
			local a = k.a
			local possede = c.possedes[a.id] == true
			local equipe = a.type == "skin" and c.skin == a.id
			if equipe then
				k.action.Text = "EQUIPE"
				k.action.BackgroundColor3 = Color3.fromRGB(60, 170, 80)
			elseif possede then
				k.action.Text = a.type == "skin" and "EQUIPER" or "POSSEDEE"
				k.action.BackgroundColor3 = Color3.fromRGB(90, 90, 120)
			else
				k.action.Text = a.prix .. " GEMMES"
				k.action.BackgroundColor3 = (v.gemmes or 0) >= a.prix and Color3.fromRGB(60, 150, 230) or Color3.fromRGB(90, 70, 80)
			end
			k.bord.Color = equipe and Color3.fromRGB(150, 230, 90) or (a.type == "emote" and OR or Color3.fromRGB(150, 110, 240))
			k.bord.Thickness = equipe and 5 or 3
		end
	end

	K.bouton.MouseButton1Click:Connect(function()
		K.ecran.Visible = true
	end)
	K.fermer.MouseButton1Click:Connect(function()
		K.ecran.Visible = false
	end)
	montee.majCosmetiques(montee.derniereVue)
	-- CAPTURE (build.py --cosmetiques) : ouvre l'ecran et achete le skin d'or, comme un joueur
	if ReplicatedStorage:FindFirstChild("BRR_COSMETIQUES") then
		task.delay(9, function()
			K.ecran.Visible = true
			local rep = Boutique:InvokeServer("cosmetique", { id = "or" })
			print("[COSMETIQUE] achat simule du skin d'or :", rep.ok, rep.motif)
			if rep.vue then
				afficher(rep.vue)
			end
		end)
	end
end)()

-- Comme le reste des ajouts recents, il tient dans UNE table : le corps du fichier touche la
-- limite de Lua (200 variables locales).
do
	finSaison.ecran = Instance.new("Frame")
	finSaison.ecran.Name = "FinDeSaison"
	finSaison.ecran.Size = UDim2.new(0, 520, 0, 300)
	finSaison.ecran.Position = UDim2.new(0.5, -260, 0.5, -150)
	finSaison.ecran.BackgroundColor3 = Color3.fromRGB(22, 26, 44)
	finSaison.ecran.BorderSizePixel = 0
	finSaison.ecran.Visible = false
	finSaison.ecran.ZIndex = 60
	finSaison.ecran.Parent = gui
	coin(finSaison.ecran, 16)
	contour(finSaison.ecran, 3, Color3.fromRGB(255, 215, 110), 0)
	texte(finSaison.ecran, "FIN DE SAISON", UDim2.new(1, -24, 0, 42), UDim2.new(0, 12, 0, 14), OR).ZIndex = 61
	finSaison.lignes = {}
	for i = 1, 5 do -- 5e ligne : la ligue avant/apres la remise a zero
		local l = texte(finSaison.ecran, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0, 62 + (i - 1) * 34),
			Color3.fromRGB(225, 230, 245))
		l.ZIndex = 61
		l.TextScaled = false
		l.TextSize = 17
		finSaison.lignes[i] = l
	end
	local fermer = bouton(finSaison.ecran, "MERCI", UDim2.new(0, 170, 0, Fiche.PANNEAU_BOUTON),
		UDim2.new(0.5, -85, 1, -(Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS)), Color3.fromRGB(90, 90, 110))
	fermer.ZIndex = 62
	fermer.MouseButton1Click:Connect(function()
		finSaison.ecran.Visible = false
		Sons.jouer("clic")
		-- Le serveur oublie le bilan : sans cela, il reviendrait a chaque ouverture du menu.
		task.spawn(function()
			Boutique:InvokeServer("saisonVue")
		end)
	end)
end

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
	-- PASTILLE « il y a quelque chose a prendre » sur EVENEMENTS : le coffre gratuit revient
	-- toutes les 4 h et rien ne le signalait hors de cet onglet. Elle n'apparait QUE quand le
	-- coffre est la — une pastille permanente ne voudrait plus rien dire.
	if o.nom == "evenements" then
		montee.coffrePastille = Instance.new("Frame")
		montee.coffrePastille.Size = UDim2.new(0, 24, 0, 24)
		montee.coffrePastille.Position = UDim2.new(1, -38, 0, 10) -- le dernier onglet touche le bord : a -24 la pastille etait rognee (cap-coffre6.png)
		montee.coffrePastille.BackgroundColor3 = Color3.fromRGB(255, 190, 70)
		montee.coffrePastille.ZIndex = 8
		montee.coffrePastille.Visible = false
		montee.coffrePastille.Parent = o.bouton
		coin(montee.coffrePastille, 12)
		montee.coffreCompte = texte(montee.coffrePastille, "", UDim2.fromScale(1, 1),
			UDim2.fromScale(0, 0), Color3.fromRGB(40, 30, 5))
		montee.coffreCompte.ZIndex = 9
		-- Le chiffre est mis a l'echelle : sans plafond il debordait du rond (cap-pastille.png du
		-- 2026-09-20, ou le « 2 » mordait sur le bord). Pose sans variable locale : ce fichier est
		-- au plafond des 200 locales de Lua.
		montee.coffrePlafond = Instance.new("UITextSizeConstraint")
		montee.coffrePlafond.MaxTextSize = 15
		montee.coffrePlafond.Parent = montee.coffreCompte
		-- La barre d'onglets est construite APRES le premier `afficher` : sans ce rattrapage, la
		-- pastille restait eteinte jusqu'au profil suivant (capture cap-coffre4.png).
		if vue and vue.evenements then
			montee.coffrePastille.Visible = montee.rappel.pastille(vue.evenements.coffreGratuitReste or 0,
				vue.evenements.quetes, vue.bonusDispo, #(vue.coffres or {}) >= 4)
			montee.coffreCompte.Text = montee.rappel.compte(vue.evenements.coffreGratuitReste or 0,
				vue.evenements.quetes, vue.bonusDispo, #(vue.coffres or {}) >= 4)
		end
	end
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

-- AIDE DES GEMMES : un clic sur le jeton ouvre une bulle (regle venue de Coffres/Quetes), un
-- second la ferme. Rangee dans `montee` : le corps du script est au plafond des 200 locales.
do
	local zone = Instance.new("TextButton")
	zone.Text = ""
	zone.BackgroundTransparency = 1
	zone.Size = UDim2.fromScale(1, 1)
	zone.ZIndex = 12
	zone.Parent = valGemmes.Parent
	local bulle = texte(bandeau.Parent, "", UDim2.new(0.34, 0, 0, 44), UDim2.new(0.44, 0, HAUTEUR_BANDEAU, 4),
		Color3.fromRGB(220, 255, 240))
	bulle.BackgroundColor3 = Color3.fromRGB(14, 40, 34)
	bulle.BackgroundTransparency = 0.05
	bulle.TextWrapped = true
	bulle.TextScaled = false
	bulle.TextSize = 14
	bulle.ZIndex = 20
	bulle.Visible = false
	coin(bulle, 10)
	montee.bulleGemmes = bulle
	zone.MouseButton1Click:Connect(function()
		bulle.Visible = not bulle.Visible
	end)
	if ReplicatedStorage:FindFirstChild("BRR_AIDE_GEMMES") then
		bulle.Visible = true -- capture (build.py --aide-gemmes)
	end
end

majBandeau = function(v)
	valPieces.Text = tostring(v.pieces)
	valGemmes.Text = tostring(v.gemmes or 0)
	montee.bulleGemmes.Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Coffres")).texteGemmes(
		v.gemmes or 0, require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quetes")).GEMMES,
		v.sansAleatoirePayant)
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

-- FIN DU TUTORIEL : LE MENU REVIENT TOUT SEUL.
-- Mesure du 2026-09-20 : les cinq etapes finies, le debutant restait dans l'arene et devait
-- trouver le bouton MENU, puis confirmer un ABANDON, pour rentrer. Le serveur termine desormais
-- la partie et le dit dans son etat (`tutoTermine`) ; on rejoue ici le geste du bouton MENU apres
-- un court delai, le temps de lire l'ecran de fin. C'est ce retour qui ouvre ensuite les regles.
local etatTuto = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State")
local tutoFinVueA = nil
local retourTutoFait = false
etatTuto.OnClientEvent:Connect(function(s)
	if not s or s.tutoTermine ~= true or retourTutoFait then
		return
	end
	tutoFinVueA = tutoFinVueA or os.clock()
	if Tutoriel.retourMenu(true, retourTutoFait, os.clock() - tutoFinVueA) then
		retourTutoFait = true
		print("[HUB] tutoriel termine : retour automatique au menu")
		ouvrirAccueil()
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
	-- CAPTURE DE LA FICHE COMPLETE (build.py --detail=ScudoBanana) : ouvre l'ecran de detail
	-- sur une carte nommee, sinon aucune capture ne pourrait montrer un ecran qui s'ouvre au clic.
	-- CAPTURE DE L'ECRAN DES REGLES (build.py --regles) : il s'ouvre au clic, donc aucune
	-- capture ne le montrerait sans ce crochet.
	-- CAPTURE DE LA FIN DU TUTORIEL (build.py --regles-tuto) : on rejoue la vraie TRANSITION
	-- « pas fait » -> « fait » en passant par la meme fonction que l'ecran, et non par un
	-- raccourci — sinon la capture prouverait un chemin qui n'existe pas en vrai.
	-- TUTORIEL JOUE EN ENTIER (build.py --tuto) : personne n'est la pour appuyer sur JOUER, on
	-- lance la partie par le MEME chemin que le bouton. Le RETOUR au menu, lui, n'est plus rejoue
	-- ici : le jeu le fait de lui-meme a la fin du tutoriel.
	if ReplicatedStorage:FindFirstChild("BRR_TUTO") then
		task.spawn(function()
			-- Personne pour appuyer sur JOUER non plus : on lance la partie par le MEME chemin que
			-- le bouton (action « jouer » du serveur), puis le tutoriel demarre tout seul.
			task.wait(2)
			Boutique:InvokeServer("jouer")
			-- Le bouton JOUER ferme l'accueil en meme temps qu'il lance la partie : sans ces
			-- lignes, la copie de test restait « au menu » pendant le match, et l'ecran des
			-- regles s'ouvrait AVANT le retour au menu (journal du 2026-09-20, 57 s contre 63 s).
			accueil.Visible = false
			boutonMenu.Visible = true
			if barreOnglets then barreOnglets.Visible = false end
			liseraBarre.Visible = false
			bandeau.Visible = false
			print("[HUB] partie lancee (comme le bouton JOUER)")
			-- Rien d'autre a faire : la fin du tutoriel termine la partie cote serveur et le
			-- retour au menu se fait tout seul (`tutoTermine`). La capture prouve donc le VRAI
			-- chemin, pas un raccourci de test.
		end)
	end
	if ReplicatedStorage:FindFirstChild("BRR_REGLES_TUTO") then
		verifierFinTutoriel({ tutoFait = false })
		verifierFinTutoriel({ tutoFait = true })
	end
	if ReplicatedStorage:FindFirstChild("BRR_REGLES") then
		ouvrirRegles()
		-- CAPTURE DU BAS DU MANUEL (build.py --regles-bas) : la liste defile, donc les dernieres
		-- sections ne tiennent pas sur une photo du haut. On pose le defilement au maximum (la
		-- valeur est bornee toute seule par la taille reelle du contenu).
		if ReplicatedStorage:FindFirstChild("BRR_REGLES_BAS") then
			-- apres 1 s : la hauteur automatique de la liste n'est pas encore calculee au defer, et
			-- la derniere section (PROGRESSION) restait hors champ (capture regles-prog.png).
			task.delay(1, function()
				reglesListe.CanvasPosition = Vector2.new(0, 100000)
			end)
		end
	end
	-- CAPTURE DE L'ECRAN DES DERNIERES PARTIES (build.py --journal) : il s'ouvre au clic. On
	-- appelle la fonction du bouton, et le contenu vient du VRAI profil du serveur.
	if ReplicatedStorage:FindFirstChild("BRR_JOURNAL") then
		task.spawn(function()
			-- Avec --tuto, on laisse la partie de tutoriel se jouer et se terminer : le journal
			-- n'a de contenu QUE si une partie a vraiment eu lieu. On ferme d'abord l'ecran des
			-- regles ouvert par la fin du tutoriel, comme le ferait le joueur en appuyant sur
			-- FERMER, puis on ouvre le journal.
			if ReplicatedStorage:FindFirstChild("BRR_TUTO") then
				task.wait(80)
				reglesEcran.Visible = false
			end
			ouvrirJournal()
		end)
	end
	-- CAPTURE (build.py --liste-bas) : chaque liste defilante descendue TOUT en bas, pour voir si
	-- sa derniere ligne est coupee. Apres 3 s, le temps que les hauteurs soient calculees.
	if ReplicatedStorage:FindFirstChild("BRR_LISTE_BAS") then
		task.delay(3, function()
			for _, l in ipairs({ grille, deckGrille, journalListe }) do
				l.CanvasPosition = Vector2.new(0, 100000)
			end
			print("[LISTE] bas : grille", grille.CanvasSize.Y.Offset, "journal", journalListe.AbsoluteCanvasSize.Y)
		end)
	end
	local carteDetail = ReplicatedStorage:FindFirstChild("BRR_DETAIL")
	if carteDetail and carteDetail.Value ~= "" then
		ouvrirDetail(Cards.byId[carteDetail.Value])
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
		-- MEME CHEMIN QUE LE BOUTON D'ONGLET : il charge les donnees de l'ecran. Appeler majOnglets seul
		-- montrait l'onglet CARTES avec une selection VIDE (« 0 / 8 cartes choisies - NON ENREGISTRE »
		-- sous un deck plein, photo du 2026-09-21) : un etat qu'aucun joueur ne voit.
		if ongletDemande.Value == "cartes" then
			ouvrirEcranDeck()
		elseif ongletDemande.Value == "boutique" then
			ouvrirEcranBoutique()
		end
		majOnglets(ongletDemande.Value)
		afficher(Boutique:InvokeServer("profil").vue)
		-- PHOTO PRISE PAR LE JEU (build.py --photo-jeu) : l'onglet est affiche et rempli, on la demande
		if ReplicatedStorage:FindFirstChild("BRR_PHOTO_JEU") then
			task.delay(1.5, function()
				ReplicatedStorage:SetAttribute("BRR_PHOTO", os.clock())
			end)
		end
		if ongletDemande.Value == "clan" then
			task.spawn(function()
				majClassement(Boutique:InvokeServer("classement").classement)
			end)
		end
	end
	print("[HUB] accueil ouvert")
end

-- VUE POUSSEE PAR LE SERVEUR (Remotes.Vue) : apres l'achat d'un pass Roblox, aucun solde ne
-- bouge, donc rien d'autre ne rafraichissait l'ecran. Aucune variable locale ajoutee ici : le
-- corps de ce script est au plafond des 200 locales de Luau.
task.spawn(function()
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Vue").OnClientEvent:Connect(function(v)
		if v then
			afficher(v)
		end
	end)
end)

-- CAPTURE DES REGLAGES SONORES (build.py --son) : l'ecran s'ouvre au clic. On appelle la
-- fonction du bouton, et on COUPE la musique pour que la photo montre les deux etats a la fois
-- (un interrupteur allume et un coupe) plutot que deux fois le meme.
if ReplicatedStorage:FindFirstChild("BRR_SON") then
	task.spawn(function()
		task.wait(12)
		ouvrirSon()
		-- On rejoue le CLIC sur MUSIQUE (meme fonction que le bouton) : le reglage part donc au
		-- serveur, et le profil ne le rallume pas au rafraichissement suivant.
		basculerSon("musique")
	end)
end

-- CAPTURE DES REGLES EN PLEINE PARTIE (build.py --regles-partie) : le bouton REGLES s'ouvre au
-- CLIC, et la copie de test n'a personne pour cliquer. On appelle donc sa propre fonction de clic
-- (celle que le bouton declenche), une fois la partie lancee. Le panneau et sa position sont ceux
-- du vrai jeu : rien n'est mis en scene pour la photo.
if ReplicatedStorage:FindFirstChild("BRR_REGLES_PARTIE") then
	task.spawn(function()
		task.wait(14) -- le temps que le coup d'envoi passe et que la partie soit vraiment engagee
		print("[HUB] partie en cours : ouverture des regles (comme le bouton REGLES)")
		ouvrirRegles()
	end)
end
