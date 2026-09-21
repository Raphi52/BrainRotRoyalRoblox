-- MISE EN PAGE DE L'ECRAN DE DUEL, en fonctions PURES.
--
-- Le defaut corrige : toutes les positions etaient ecrites en PIXELS FIXES. Sur un ecran large,
-- tout tenait ; sur une fenetre etroite — un telephone en portrait, une fenetre reduite — les
-- blocs se marchaient dessus : la lecture de l'adversaire sous les boutons de menu, l'historique
-- des cartes sous la barre d'emotes, le nom de l'arene par-dessus le score. On ne s'en apercevait
-- qu'en changeant de machine.
--
-- Ici, la mise en page est une DONNEE : une liste de rectangles nommes, calculee a partir de la
-- taille de l'ecran. Elle devient donc verifiable — tools/test_mise.py balaie des dizaines de
-- formats et refuse le moindre chevauchement. Le client se contente d'appliquer.
local Mise = {}

Mise.MARGE = 12
Mise.HAUT_BOUTONS = 64      -- rangee MENU / REGLES / SON, dessinee par le hub
-- Largeur de cette meme rangee. Mesure a l'ecran (capture du 2026-09-20) : sur un ecran etroit, la
-- pile centrale remontait a 12 px du haut et passait DERRIERE les boutons du hub — le score et le
-- chrono devenaient illisibles. Ces boutons vivent dans un autre script : on reserve leur place.
Mise.LARGEUR_BOUTONS = 330
Mise.LARGE_CONFORT = 900    -- en dessous, on passe en mise en page COMPACTE
Mise.HAUT_CONFORT = 620     -- en dessous, on sacrifie les informations secondaires

-- Colonnes laterales : largeur qui suit l'ecran, sans jamais mordre sur le centre.
function Mise.largeurColonne(L)
	return math.max(120, math.min(230, math.floor(L * 0.22)))
end

-- Bande centrale reservee au chrono, au score et au lieu : ce qui ne doit JAMAIS etre recouvert.
function Mise.largeurCentre(L)
	return math.max(180, math.min(460, math.floor(L * 0.42)))
end

local function bloc(nom, x, y, l, h)
	-- aucune dimension nulle ou negative ne doit sortir d'ici : un cadre de largeur -23 ne
	-- s'affiche pas, il se REPLIE, et le texte deborde n'importe ou.
	return { nom = nom, x = math.max(0, math.floor(x)), y = math.max(0, math.floor(y)),
		l = math.max(1, math.floor(l)), h = math.max(1, math.floor(h)) }
end

-- LES BLOCS, dans l'ordre de priorite. `visible = false` : l'ecran est trop petit pour cette
-- information — on la retire PLUTOT que de la laisser en recouvrir une autre.
--
-- REGLE DE REPARTITION (trouvee par le banc : a 900 px de large, la barre d'emotes recouvrait le
-- chrono) : les deux COLONNES prennent leur place d'abord, le centre reçoit ce qui reste. Si ce
-- reste devient illisible, ce sont les emotes qui DESCENDENT sous la pile centrale — jamais le
-- chrono qui se fait recouvrir.
-- Taille minimale prise en compte. Mesure a l'ecran (2026-09-20) : au tout premier calcul, Roblox
-- rend un ecran de 1x1 (la vue n'est pas encore dimensionnee) — la mise en page produisait alors
-- des blocs de LARGEUR NEGATIVE. Ils se corrigeaient au redimensionnement suivant, mais l'image
-- de depart etait cassee.
Mise.MIN_LARGEUR = 320
Mise.MIN_HAUTEUR = 240

function Mise.blocs(L, H)
	L = math.max(Mise.MIN_LARGEUR, math.floor(tonumber(L) or 1280))
	H = math.max(Mise.MIN_HAUTEUR, math.floor(tonumber(H) or 720))
	local m = Mise.MARGE
	local col = Mise.largeurColonne(L)
	local petit = L < Mise.LARGE_CONFORT
	local court = H < Mise.HAUT_CONFORT
	local out = {}

	-- place demandee par les colonnes (gauche = lecture, droite = emotes)
	local largeEmotes = math.min(col + 60, math.floor(L * 0.28))
	-- La pile centrale est CENTREE : c'est donc la colonne la plus large qui commande des DEUX
	-- cotes. En comptant chaque colonne separement, le centre debordait de quelques pixels sur la
	-- barre d'emotes — trois pixels suffisent a recouvrir un chiffre (trouve par le banc a 900 px).
	local placeCote = math.max(col, largeEmotes)
	local reste = L - 2 * placeCote - 4 * m
	local emotesEnHaut = reste >= 180
	local centre = math.max(180, math.min(Mise.largeurCentre(L),
		emotesEnHaut and reste or (L - 2 * col - 4 * m)))
	local xCentre = math.floor((L - centre) / 2)

	-- pile centrale, du plus gros au plus petit. Si elle ne peut pas passer A COTE de la rangee de
	-- boutons du hub (ecran etroit), elle commence EN DESSOUS.
	local y = (xCentre < Mise.LARGEUR_BOUTONS + m) and Mise.HAUT_BOUTONS or m
	local function empiler(nom, h, montrer)
		local b = bloc(nom, xCentre, y, centre, h)
		b.visible = montrer ~= false
		table.insert(out, b)
		if b.visible then
			y = y + h + 2
		end
		return b
	end
	empiler("chrono", court and 26 or 34)
	empiler("score", court and 20 or 26)
	empiler("lieu", 20, not court)          -- arene + decor : agreable, pas vital
	empiler("progression", 16, not court)   -- trophees + saison
	empiler("fiche", 18, not petit)         -- qui est en face, en chiffres
	local basPile = y

	-- ECRAN TRES ETROIT (sous ~460 px) : meme reduites, deux colonnes plus une pile centrale ne
	-- tiennent pas cote a cote — la lecture passait sous le score (trouve par le banc a 360 px).
	-- On empile alors TOUT verticalement : la pile centrale, puis la lecture, puis les emotes.
	local enColonnes = reste >= 180 or (L - 2 * col - 4 * m) >= 180
	-- colonne GAUCHE : lecture de l'adversaire, puis latence. Sous la rangee de boutons du hub.
	local yG = enColonnes and Mise.HAUT_BOUTONS or math.max(Mise.HAUT_BOUTONS, basPile)
	local hLecture = petit and 74 or 96
	local bl = bloc("lecture", m, yG, col, hLecture)
	bl.visible = true
	table.insert(out, bl)
	local bp = bloc("ping", m, yG + hLecture + 4, math.min(col, 120), 18)
	bp.visible = true
	table.insert(out, bp)

	-- colonne DROITE : emotes, puis mon propre historique. Les emotes descendent SOUS la pile
	-- centrale quand l'ecran est trop etroit pour les mettre cote a cote.
	local yEmotes = emotesEnHaut and m or (enColonnes and basPile or (yG + hLecture + 26))
	local be = bloc("emotes", math.max(m, L - largeEmotes - m), yEmotes, math.min(largeEmotes, L - 2 * m), 40)
	be.visible = true
	table.insert(out, be)
	local bm = bloc("mesCartes", L - col - m, yEmotes + 40 + 8, col, 72)
	-- sur un ecran etroit, les deux colonnes finiraient par se toucher : on garde la lecture de
	-- l'adversaire (elle decide des poses) et on retire la sienne, qu'on connait deja.
	bm.visible = not petit
	table.insert(out, bm)

	-- panneau des cartes, en bas au centre
	local largeMain = math.min(608, L - 2 * m)
	local hautMain = court and 130 or 170
	local bmain = bloc("main", math.floor((L - largeMain) / 2), H - hautMain - 6, largeMain, hautMain)
	bmain.visible = true
	table.insert(out, bmain)
	-- ZONE RESERVEE (pas un bloc a poser) : la rangee de boutons du hub. Elle entre dans la
	-- verification de chevauchement, pour qu'aucun bloc ne vienne se cacher derriere.
	local bh = bloc("boutonsHub", m, m, math.min(Mise.LARGEUR_BOUTONS, L - 2 * m), Mise.HAUT_BOUTONS - m)
	bh.visible = true
	bh.reserve = true
	table.insert(out, bh)
	return out
end

-- ECRAN DE FIN DE PARTIE : resultat, gain, recapitulatif, resume partageable, bouton « Rejouer ».
--
-- Meme defaut que le reste, en pire : ces blocs etaient poses a des offsets ECRITS A LA MAIN sous
-- le recapitulatif. A chaque bloc ajoute en dessous, « Rejouer » repassait par-dessus le suivant —
-- d'abord le recapitulatif, puis le resume partageable (capture du 2026-09-20), puis la main de
-- cartes. Corriger le nombre une fois de plus n'aurait fait que deplacer le prochain conflit.
--
-- Ici la pile est CALCULEE : on part du bas (juste au-dessus de la main de cartes) et on empile
-- vers le haut. Quand la place manque, on RETIRE dans un ordre assume : d'abord le recapitulatif
-- (ses chiffres sont repris dans le resume partageable), puis la ligne de gain, et le resume en
-- tout dernier — c'est la seule chose qu'on emporte hors du jeu.
Mise.HAUTEURS_FIN = { titre = 86, gain = 30, recap = 130, partage = 92, rejouer = 60 }
Mise.SACRIFICE_FIN = { "recap", "gain", "partage" }

function Mise.fin(L, H)
	L = math.max(Mise.MIN_LARGEUR, math.floor(tonumber(L) or 1280))
	H = math.max(Mise.MIN_HAUTEUR, math.floor(tonumber(H) or 720))
	local m = Mise.MARGE
	local hauteurs = Mise.HAUTEURS_FIN
	-- LA MAIN DE CARTES EST RETIREE : la partie est finie, ces cartes ne se posent plus. Tant
	-- qu'on la gardait, la pile de fin devait se serrer au-dessus d'elle — et sur un ecran bas
	-- (240 px, trouve par le banc), meme le titre et « Rejouer » ne tenaient plus.
	local bas = H - m
	local haut = Mise.HAUT_BOUTONS + m      -- et ne monte pas derriere les boutons du hub
	-- LA BARRE D'EMOTES RESTE : on salue son adversaire APRES la partie, c'est meme le moment le
	-- plus naturel pour le faire. Elle devient donc une zone a ne pas recouvrir — sur un ecran
	-- etroit, la pile de fin passait dessous et « +10 pieces » se lisait au travers des boutons
	-- (capture du 2026-09-20).
	local bem = Mise.trouver(Mise.blocs(L, H), "emotes")
	local largeur = math.min(460, L - 2 * m)
	local xPile = math.floor((L - largeur) / 2)
	if bem and bem.visible and bem.x < xPile + largeur and xPile < bem.x + bem.l then
		haut = math.max(haut, bem.y + bem.h + 8) -- la pile commence sous les emotes
	end

	-- ordre d'affichage, de haut en bas
	local ordre = { "titre", "gain", "recap", "partage", "rejouer" }
	local montre = {}
	for _, nom in ipairs(ordre) do
		montre[nom] = true
	end
	local function total()
		local t, n = 0, 0
		for _, nom in ipairs(ordre) do
			if montre[nom] then
				t = t + hauteurs[nom]
				n = n + 1
			end
		end
		return t + math.max(0, n - 1) * 8
	end
	for _, nom in ipairs(Mise.SACRIFICE_FIN) do
		if total() <= bas - haut then
			break
		end
		montre[nom] = false
	end

	-- empilage : centre verticalement dans la place restante, sans jamais depasser en haut.
	local y = math.max(haut, math.floor((haut + bas - total()) / 2))
	local out = {}
	for _, nom in ipairs(ordre) do
		local largeBloc = (nom == "rejouer") and math.min(220, largeur) or largeur
		local b = bloc("fin" .. nom, math.floor((L - largeBloc) / 2), y, largeBloc, hauteurs[nom])
		b.visible = montre[nom]
		table.insert(out, b)
		if b.visible then
			y = y + hauteurs[nom] + 8
		end
	end
	-- zones a ne pas recouvrir, pour que Mise.chevauchements ait de quoi mordre
	local jeu = Mise.blocs(L, H)
	local bmain = Mise.trouver(jeu, "main")
	if bmain then
		bmain.visible = false -- retiree pendant l'ecran de fin
		bmain.reserve = true
		table.insert(out, bmain)
	end
	if bem then
		bem.reserve = true
		table.insert(out, bem)
	end
	local bh = Mise.trouver(jeu, "boutonsHub")
	if bh then
		bh.reserve = true
		table.insert(out, bh)
	end
	return out
end

local function croise(a, b)
	return a.x < b.x + b.l and b.x < a.x + a.l and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Paires de blocs VISIBLES qui se recouvrent. Une liste vide est la seule reponse acceptable.
function Mise.chevauchements(blocs)
	local out = {}
	for i = 1, #blocs do
		for j = i + 1, #blocs do
			local a, b = blocs[i], blocs[j]
			if a.visible and b.visible and croise(a, b) then
				table.insert(out, a.nom .. "/" .. b.nom)
			end
		end
	end
	return out
end

-- Blocs qui sortent de l'ecran : un texte a moitie hors cadre est illisible.
function Mise.hors(blocs, L, H)
	local out = {}
	for _, b in ipairs(blocs) do
		if b.visible and (b.x < 0 or b.y < 0 or b.x + b.l > L or b.y + b.h > H) then
			table.insert(out, b.nom)
		end
	end
	return out
end

function Mise.trouver(blocs, nom)
	for _, b in ipairs(blocs) do
		if b.nom == nom then
			return b
		end
	end
	return nil
end

return Mise
