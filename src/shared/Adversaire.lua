-- QUI EST EN FACE : humain ou robot, et de quel niveau. Fonctions PURES.
--
-- Le defaut corrige : le seul indice qu'on affrontait une machine etait le mot « Bot » dans la
-- ligne de score — a cote du pseudo d'un vrai joueur, la difference se voyait a peine. Un joueur
-- pouvait donc enchainer des parties contre le robot sans le savoir : il croyait battre des
-- humains, et le jour ou il en croisait un vrai, il ne comprenait pas la correction.
-- L'inverse est vrai aussi : perdre contre « quelqu'un » qui est une machine, sans le savoir,
-- donne l'impression d'un jeu truque.
--
-- On le dit donc DEUX FOIS : pendant la recherche (« personne pour l'instant, robot dans N s ») et
-- au coup d'envoi (« Tu affrontes le robot — niveau aguerri »). Et son NIVEAU est nomme : le robot
-- s'adapte aux trophees du joueur, autant que ce soit lisible plutot que mysterieux.
local Adversaire = {}

Adversaire.NOM_ROBOT = "Robot"

-- Noms des paliers de difficulte, en clair (Robot.PALIERS porte des identifiants techniques).
Adversaire.NIVEAUX = {
	debutant = "debutant",
	normal = "normal",
	aguerri = "aguerri",
	expert = "expert",
}

function Adversaire.estRobot(nomHumain)
	return not (type(nomHumain) == "string" and nomHumain ~= "")
end

-- NOM AFFICHE dans la ligne de score : le pseudo d'un humain, ou « Robot (aguerri) ».
function Adversaire.nom(nomHumain, palier)
	if not Adversaire.estRobot(nomHumain) then
		return nomHumain
	end
	local n = Adversaire.NIVEAUX[palier or ""]
	if n then
		return Adversaire.NOM_ROBOT .. " (" .. n .. ")"
	end
	return Adversaire.NOM_ROBOT
end

-- NOM COURT, pour la LIGNE DE SCORE. Mesure a l'ecran (capture du 2026-09-20) : « Robot
-- (debutant) » y etait recouvert par le badge pose a cote, et l'information apparaissait DEUX
-- fois. Le score porte donc le nom court ; le palier et les chiffres vivent dans la fiche.
function Adversaire.nomCourt(nomHumain)
	if Adversaire.estRobot(nomHumain) then
		return Adversaire.NOM_ROBOT
	end
	return nomHumain
end

-- BADGE court, a cote du score : « ROBOT » ou nil pour un humain (aucun badge inutile).
function Adversaire.badge(nomHumain)
	if Adversaire.estRobot(nomHumain) then
		return "ROBOT"
	end
	return nil
end

-- ANNONCE DU COUP D'ENVOI. Rend nil face a un humain : on n'annonce pas ce qui va de soi.
function Adversaire.annonce(nomHumain, palier)
	if not Adversaire.estRobot(nomHumain) then
		return nil
	end
	local n = Adversaire.NIVEAUX[palier or ""]
	if n then
		return "Tu affrontes le robot — niveau " .. n
	end
	return "Tu affrontes le robot"
end

-- PENDANT LA RECHERCHE : ce qui reste avant de basculer sur le robot. On ANNONCE la bascule au
-- lieu de la subir : un joueur qui prefere attendre un humain peut relancer une recherche.
function Adversaire.attente(secondesRestantes)
	local r = math.max(0, math.ceil(secondesRestantes or 0))
	if r <= 0 then
		return "Personne pour l'instant : tu affrontes le robot."
	end
	return string.format("Recherche d'un adversaire... robot dans %d s", r)
end

-- FICHE DE L'ADVERSAIRE, montree pendant le duel. On affrontait un NOM, sans savoir si c'etait un
-- debutant ou quelqu'un qui joue depuis six mois — donc sans savoir si perdre etait normal, ni si
-- gagner valait quelque chose. Deux chiffres suffisent : ses trophees et le niveau moyen de son
-- deck (celui-la meme qui sert a l'appariement).
--   trophees : nil = inconnu (on n'invente pas)
--   niveau   : niveau MOYEN de son deck, nil = inconnu
function Adversaire.fiche(nomHumain, palier, trophees, niveau)
	local bouts = {}
	-- LA MENTION « ROBOT » VIT ICI, en tete de fiche : en badge separe pose sur la ligne de score,
	-- elle en recouvrait la fin (capture du 2026-09-20).
	if Adversaire.estRobot(nomHumain) then
		table.insert(bouts, Adversaire.badge(nomHumain))
	end
	table.insert(bouts, Adversaire.nom(nomHumain, palier))
	if trophees ~= nil then
		table.insert(bouts, string.format("%d trophees", math.floor(trophees)))
	end
	if niveau ~= nil then
		table.insert(bouts, string.format("cartes niveau %d", math.floor(niveau)))
	end
	return table.concat(bouts, "  ·  ")
end

-- ECART DE NIVEAU, dit franchement. Un duel ou l'on part avec deux niveaux de retard n'est pas
-- perdu d'avance, mais le joueur a le droit de le SAVOIR — sinon il met sa defaite sur son propre
-- dos. nil quand l'ecart est negligeable ou inconnu : on ne cherche pas d'excuse a sa place.
Adversaire.ECART_NOTABLE = 2
function Adversaire.ecartNiveau(monNiveau, sonNiveau)
	if monNiveau == nil or sonNiveau == nil then
		return nil
	end
	local d = math.floor(sonNiveau) - math.floor(monNiveau)
	if d >= Adversaire.ECART_NOTABLE then
		return string.format("Ses cartes ont %d niveaux de plus que les tiennes", d)
	end
	if -d >= Adversaire.ECART_NOTABLE then
		return string.format("Tes cartes ont %d niveaux de plus que les siennes", -d)
	end
	return nil
end

-- Ce qui s'affiche APRES coup, dans le bilan : une victoire contre le robot ne vaut pas une
-- victoire contre un humain, et le joueur doit pouvoir faire la difference.
--
-- `bonus` (facultatif) : pieces en plus pour une victoire contre un HUMAIN (Economie.BONUS_HUMAIN).
-- `victoire` (facultatif) : la partie est-elle gagnee ? Defaut mesure le 2026-09-21 : ce bonus de
-- 20 pieces n'etait dit NULLE PART — ni avant de choisir le robot, ni apres la partie. Le joueur
-- prenait le robot par facilite sans savoir ce qu'il y laissait. Sans ces deux arguments, la
-- mention reste celle d'avant.
-- DIVISEUR DES TROPHEES contre le robot, lisible : une part de 1/3 se dit « divises par 3 ».
-- Rend nil quand il n'y a pas de reduction (part absente ou >= 1).
function Adversaire.diviseurRobot(partRobot)
	local p = tonumber(partRobot)
	if not p or p <= 0 or p >= 1 then
		return nil
	end
	return math.floor(1 / p + 0.5)
end

-- `partRobot` (facultatif) : part des trophees gagnes contre le robot (Arenes.PART_ROBOT). Regle
-- posee le 2026-09-21 — une victoire contre le robot rapporte le TIERS des trophees — et affichee
-- NULLE PART : l'ecran de fin montrait « +10 trophees » sans dire pourquoi pas 30.
function Adversaire.mention(nomHumain, bonus, victoire, partRobot)
	local b = math.floor(tonumber(bonus) or 0)
	if Adversaire.estRobot(nomHumain) then
		local div = Adversaire.diviseurRobot(partRobot)
		local bouts = {}
		if victoire and div then
			table.insert(bouts, "trophees divises par " .. div)
		end
		if victoire and b > 0 then
			table.insert(bouts, "pas de bonus de +" .. b)
		end
		if #bouts > 0 then
			return "(contre le robot : " .. table.concat(bouts, ", ") .. ")"
		end
		return "(partie contre le robot)"
	end
	if victoire and b > 0 then
		return "(victoire contre un joueur : +" .. b .. " pieces de bonus)"
	end
	return nil
end

-- MENTION DE FIN contre un JOUEUR, avec la raison de l'enjeu (ecart de trophees). S'appuie sur
-- `mention` et y ajoute ce qui explique un gain plus gros ou plus petit que +30.
function Adversaire.mentionJoueur(nomHumain, bonus, victoire, facteurVictoire)
	local base = Adversaire.mention(nomHumain, bonus, victoire)
	if Adversaire.estRobot(nomHumain) then
		return base
	end
	local raison = victoire and Adversaire.raisonEnjeu(facteurVictoire) or nil
	if not raison then
		return base
	end
	if base then
		return base:sub(1, -2) .. ", " .. raison .. ")"
	end
	return "(" .. raison .. ")"
end

-- LE REGLAGE D'ATTENTE, dit avec ce qu'il change : attendre un vrai joueur peut rapporter plus.
function Adversaire.texteAttente(attendreHumain, bonus, partRobot)
	local b = math.floor(tonumber(bonus) or 0)
	local div = Adversaire.diviseurRobot(partRobot)
	local avantages = {}
	if b > 0 then
		table.insert(avantages, "+" .. b .. " pieces")
	end
	if div then
		table.insert(avantages, div .. " fois plus de trophees")
	end
	local gain = #avantages > 0
		and (" Une victoire contre un joueur rapporte " .. table.concat(avantages, " et ") .. ".") or ""
	if attendreHumain then
		return "Tu attendras un vrai joueur (jusqu'a 3 min), avec une sortie a tout moment." .. gain
	end
	return "Sans adversaire au bout de 20 s, tu joueras contre le robot." .. gain
end

-- L'ENJEU EN TROPHEES, dit AVANT la partie. Regle posee le 2026-09-21 dans Arenes : contre un
-- joueur, l'enjeu suit l'ecart de trophees (battre plus fort rapporte plus, perdre contre plus
-- faible coute plus) ; contre le robot, le tiers. Rien ne l'affichait : le joueur decouvrait son
-- gain a la fin, sans savoir s'il avait joue gros ou petit. `gain` et `perte` sont les variations
-- REELLES calculees par Arenes.variation — ce texte ne recalcule rien.
function Adversaire.enjeu(gain, perte)
	local g = math.floor(tonumber(gain) or 0)
	local p = math.abs(math.floor(tonumber(perte) or 0))
	if g == 0 and p == 0 then
		return ""
	end
	if p == 0 then
		return "Enjeu : +" .. g .. " trophees si tu gagnes"
	end
	return "Enjeu : +" .. g .. " trophees si tu gagnes, -" .. p .. " si tu perds"
end

-- POURQUOI cet enjeu contre un joueur : l'ecart qui le gonfle ou le reduit. nil quand l'enjeu est
-- celui de base (a 5 % pres) : on ne commente pas l'ordinaire.
function Adversaire.raisonEnjeu(facteurVictoire)
	local f = tonumber(facteurVictoire)
	if not f or math.abs(f - 1) < 0.05 then
		return nil
	end
	local pct = math.floor(math.abs(f - 1) * 100 + 0.5)
	if f > 1 then
		return "adversaire plus fort : +" .. pct .. " % de trophees"
	end
	return "adversaire plus faible : -" .. pct .. " % de trophees"
end

-- LISTE DU SERVEUR (onglet CLAN) : elle ne donnait que des noms. Les trophees de chacun sont
-- pourtant publics (leaderstats.Trophees, replique a tous) et decident de l'enjeu d'un duel :
-- on les affiche, du plus fort au plus faible. `membres` : { { nom, trophees, moi } }.
function Adversaire.lignesMembres(membres)
	local l = {}
	for _, m in ipairs(membres or {}) do
		table.insert(l, m)
	end
	table.sort(l, function(x, y)
		local tx, ty = tonumber(x.trophees) or -1, tonumber(y.trophees) or -1
		if tx ~= ty then
			return tx > ty
		end
		return tostring(x.nom) < tostring(y.nom)
	end)
	local out = {}
	for i, m in ipairs(l) do
		local t = tonumber(m.trophees)
		out[i] = i .. ". " .. tostring(m.nom) .. (m.moi and "  (toi)" or "")
			.. (t and ("   " .. math.floor(t) .. " trophees") or "")
	end
	return out
end

return Adversaire
