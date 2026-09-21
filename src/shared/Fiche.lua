-- FICHE D'UNE CARTE : ce qu'elle FAIT, en clair, deduit de ses propres donnees.
--
-- Defaut mesure le 2026-09-20 : aucun ecran ne disait ce que faisait une carte. Le champ `desc`
-- existait dans le catalogue depuis le debut et n'etait affiche NULLE PART — ni en boutique, ni
-- dans le deck, ni dans la main pendant la partie. Un joueur achetait « Regina Ghiaccio » sans
-- savoir qu'elle ralentit, posait « Scudo Banana » sans savoir qu'elle porte un bouclier, et
-- voyait un ennemi verdir sans jamais apprendre que c'etait du poison. Les effets venaient
-- pourtant d'etre rendus VISIBLES dans l'arene : il manquait de les NOMMER.
--
-- Regle de conception : chaque ligne est CALCULEE a partir des champs de la carte, jamais ecrite
-- a la main. Une carte dont on change les chiffres voit donc sa fiche changer toute seule, et
-- aucune fiche ne peut mentir sur le jeu. C'est verifie au banc (tools/test_fiche.py), qui
-- compare les nombres affiches a ceux du catalogue.
--
-- Fonctions PURES : aucune API Roblox ici.
local Fiche = {}

-- Nombre lisible : 0,35 -> « 35 % », 2.5 -> « 2,5 », 4.0 -> « 4 ». La virgule est la separatrice
-- decimale francaise, comme partout ailleurs dans le jeu.
local function nombre(n)
	local v = tonumber(n) or 0
	if v == math.floor(v) then
		return tostring(math.floor(v))
	end
	return (string.gsub(string.format("%.1f", v), "%.", ","))
end

local function pourcent(part)
	return tostring(math.floor((tonumber(part) or 0) * 100 + 0.5)) .. " %"
end

local function secondes(n)
	return nombre(n) .. " s"
end

-- ===== LIGNES D'EFFET =====
-- Rend la liste des effets de la carte, du plus decisif au plus accessoire. Une carte sans aucun
-- effet particulier rend une liste VIDE (et non une ligne « aucun effet », qui n'apprend rien).
-- `extras` (facultatif) porte ce qui ne vit PAS dans le catalogue : la specialite (anti-air,
-- anti-essaim) et le soutien sont declares par identifiant dans leurs propres modules, parce que
-- ce sont des regles de COMBAT. Les ecrans les lisent et les passent ici :
--   { specialite = ..., soutien = ..., descendance = ..., recul = ... }
-- Sans `extras`, la fiche reste celle du catalogue seul : ce module ne depend de rien.
function Fiche.lignes(card, extras)
	-- `extras.noms` (facultatif) : identifiant -> nom affichable, pour ecrire « laisse 2 Trippi
	-- Troppi » plutot que « laisse 2 Trippi ». Le module ne lit pas le catalogue lui-meme : il
	-- resterait pur, mais il dependrait alors de l'ordre de chargement des modules.
	local nomsCartes = extras and extras.noms
	local l = {}
	if not card then
		return l
	end

	-- SORTS : l'effet est le coeur de la carte, il passe en premier.
	local s = card.sort
	-- NIVEAU (extras.mult) : les chiffres de degats suivent le niveau du joueur. Defaut vu a l'ecran
	-- le 2026-09-21 (cap-fiche-sort-niveau.png) : l'en-tete disait « Degats 408 » (niveau 3) et la
	-- ligne juste dessous « DEGATS : 340 » (niveau 1) — la meme fiche, deux chiffres pour la meme
	-- chose. Tout ce qui est multiplie par le niveau en partie l'est ici aussi.
	local mult = (extras and tonumber(extras.mult)) or 1
	local function auNiveau(v)
		return math.floor((tonumber(v) or 0) * mult + 0.5)
	end
	if s then
		if s.effet == "gel" then
			table.insert(l, "GEL : fige tout dans " .. nombre(s.rayon) .. " studs pendant " .. secondes(s.duree))
		elseif s.effet == "poison" then
			local total = auNiveau(s.parTic) * ((tonumber(s.duree) or 0) / math.max(tonumber(s.tic) or 1, 0.01))
			table.insert(l, "POISON : " .. nombre(total) .. " degats etales sur " .. secondes(s.duree))
		elseif s.effet == "soin" then
			table.insert(l, "SOIN : rend " .. nombre(auNiveau(s.soin)) .. " PV a tes unites")
		elseif s.effet == "rage" then
			table.insert(l, "RAGE : +" .. pourcent(s.gain) .. " de vitesse et de cadence pendant " .. secondes(s.duree))
		elseif (tonumber(s.degats) or 0) > 0 then
			table.insert(l, "DEGATS : " .. nombre(auNiveau(s.degats)) .. " dans " .. nombre(s.rayon) .. " studs")
		end
		if s.cibles then
			table.insert(l, "Frappe les " .. nombre(s.cibles) .. " cibles les plus solides")
		end
		if s.solSeulement then
			table.insert(l, "Ne touche que le sol : un volant y echappe")
		end
		if s.recul then
			table.insert(l, "Repousse de " .. nombre(s.recul) .. " studs")
		end
		if (tonumber(s.degats) or 0) > 0 and s.degatsTour then
			table.insert(l, "Sur une tour : " .. pourcent(s.degatsTour) .. " des degats")
		end
		-- RENDEMENT (extras.rendementSort) : degats par elixir depense. La regle vit dans Sorts
		-- (Sorts.degatsParElixir) ; elle etait ecrite, commentee « sert au banc »... et appelee par
		-- PERSONNE. C'est pourtant le seul chiffre qui permet de comparer deux sorts de degats :
		-- 240 pour 4 elixir et 180 pour 3, ce n'est pas la meme carte, et la fiche ne le disait pas.
		local rendement = extras and tonumber(extras.rendementSort)
		if rendement and rendement > 0 then
			table.insert(l, "RENDEMENT : " .. nombre(rendement) .. " degats par elixir")
		end
		return l
	end

	-- BOUCLIER : il encaisse AVANT les points de vie, c'est ce qui change tout dans un echange.
	if (tonumber(card.bouclier) or 0) > 0 then
		table.insert(l, "BOUCLIER : " .. nombre(card.bouclier) .. " degats encaisses avant les PV")
	end

	-- EFFETS PORTES PAR SES COUPS.
	local eff = card.effet
	if eff then
		if eff.lent then
			table.insert(l, "RALENTIT : -" .. pourcent(eff.lent.part) .. " de vitesse pendant "
				.. secondes(eff.lent.duree))
		end
		if eff.poison then
			local p = eff.poison
			local total = (tonumber(p.degats) or 0) * ((tonumber(p.duree) or 0) / math.max(tonumber(p.tic) or 1, 0.01))
			table.insert(l, "EMPOISONNE : " .. nombre(total) .. " degats sur " .. secondes(p.duree))
		end
	end

	if card.soin then
		table.insert(l, "SOIGNE : " .. nombre(card.soin.montant) .. " PV toutes les "
			.. secondes(card.soin.periode) .. " dans " .. nombre(card.soin.rayon) .. " studs")
	end

	if card.mort then
		table.insert(l, "EXPLOSE EN MOURANT : " .. nombre(card.mort.degats) .. " dans "
			.. nombre(card.mort.rayon) .. " studs")
	end

	-- BATIMENTS : la duree de vie est LA donnee qui decide de leur valeur (ils meurent tout seuls).
	local b = card.batiment
	if b then
		if b.type == "collecteur" then
			table.insert(l, "BATIMENT : rend " .. nombre(b.gain) .. " elixir toutes les " .. secondes(b.periode))
			-- RENTABILITE (extras.rentabilite) : au bout de combien de secondes la pompe a
			-- rembourse son cout. Sans elle, le joueur devait diviser la duree de vie par la
			-- periode en pleine partie — c'est pourtant ce chiffre qui decide de la poser.
			local rent = extras and extras.rentabilite
			if type(rent) == "string" and rent ~= "" then
				table.insert(l, rent)
			end
		elseif b.type == "invocateur" then
			table.insert(l, "BATIMENT : invoque " .. nombre(b.nombre or 1) .. " unites toutes les "
				.. secondes(b.periode))
		elseif b.type == "leurre" then
			table.insert(l, "BATIMENT : retient les ennemis, ne frappe pas")
		else
			table.insert(l, "BATIMENT : defend sans bouger")
		end
		table.insert(l, "Duree de vie : " .. secondes(b.duree) .. ", puis il tombe tout seul")
	end

	-- DESCENDANCE : ce que l'unite laisse en MOURANT. C'est ce qui fait qu'une grosse carte vaut
	-- son prix — l'abattre ne suffit pas — et le joueur ne pouvait pas le deviner.
	local de = extras and extras.descendance
	if de then
		local fille = (nomsCartes and nomsCartes[de.fille]) or de.fille
		table.insert(l, "LAISSE " .. nombre(de.nombre) .. " " .. fille .. " en mourant")
	end
	-- RECUL : elle PROJETTE ce qu'elle frappe. Ce n'est pas des degats, c'est du TEMPS gagne, et
	-- rien dans ses statistiques ne le montrait.
	local re = extras and extras.recul
	if re and (tonumber(re.distance) or 0) > 0 then
		table.insert(l, "REPOUSSE : projette sa cible de " .. nombre(re.distance) .. " studs")
	end
	-- POINT FORT (extras.pointFort) : ce que ses CHIFFRES ont d'exceptionnel dans le catalogue.
	-- Quatre cartes n'ont aucune regle speciale : leur fiche n'affichait que des nombres bruts, et
	-- « portee 15 » ne dit rien tant qu'on ne l'a pas comparee aux 46 autres. La comparaison vit
	-- dans Reperes, calculee sur le vrai catalogue.
	local pf = extras and extras.pointFort
	if type(pf) == "string" and pf ~= "" then
		table.insert(l, pf)
	end
	-- CHARGE (extras.charge). Defaut mesure le 2026-09-21 : trois cartes prennent de l'ELAN — leur
	-- premier coup fait jusqu'a deux fois et demie plus mal apres une course — et RIEN ne le disait
	-- sur leur fiche. Or cette ligne change la facon de les jouer : on les pose LOIN derriere pour
	-- les lancer, et on les contre en les bloquant en route.
	local ch = extras and extras.charge
	if ch and (tonumber(ch.multiplicateur) or 1) > 1 then
		-- DEUX lignes courtes, et non une longue : sur une seule, la fin (« un obstacle lui vole
		-- son elan ») etait COUPEE par le bord du panneau — capture cap-charge-fiche.png du
		-- 2026-09-21. La parade est justement ce qu'il ne faut pas perdre.
		table.insert(l, "CHARGE : apres " .. nombre(ch.distance) .. " studs de course, premier coup x"
			.. nombre(ch.multiplicateur))
		table.insert(l, "PARADE : bloquer sa course lui vole son elan")
	end
	-- ASSASSIN (extras.assassin) : elle contourne le mur de melee pour aller au TIREUR. C'est toute
	-- la raison de la jouer, et sa fiche n'en disait rien.
	local asn = extras and extras.assassin
	if asn then
		table.insert(l, "ASSASSIN : vise en priorite les tireurs, meme proteges par une ligne")
	end
	-- SPECIALITE : une carte faite pour repondre a UNE menace. C'est l'information qui decide si
	-- l'on GARDE la carte en main au lieu de la jouer tout de suite.
	local sp = extras and extras.specialite
	if sp then
		local contre = sp.contre == "air" and "ce qui VOLE" or "les groupes"
		local nom = sp.contre == "air" and "ANTI-AIR" or "ANTI-ESSAIM"
		table.insert(l, nom .. " : degats x" .. nombre(sp.multiplicateur) .. " contre " .. contre)
	end
	-- SOUTIEN : elle ne vaut rien seule, elle rend les AUTRES meilleures. Sans cette ligne, ses
	-- statistiques la font passer pour une mauvaise carte.
	local so = extras and extras.soutien
	if so then
		local bouts = {}
		if (tonumber(so.degats) or 1) > 1 then
			table.insert(bouts, "+" .. pourcent(so.degats - 1) .. " degats")
		end
		if (tonumber(so.cadence) or 1) > 1 then
			table.insert(bouts, "+" .. pourcent(so.cadence - 1) .. " cadence")
		end
		-- Forme COURTE : la tuile de boutique n'a que 2 lignes, et « ... aux allies dans 6,5 »
		-- perdait son unite et son « (+1) » (capture shop2.png, 2026-09-21).
		table.insert(l, "SOUTIEN : allies " .. table.concat(bouts, ", ") .. " (" .. nombre(so.rayon) .. " studs)")
	end
	if card.poseLibre then
		table.insert(l, "Se pose N'IMPORTE OU dans l'arene")
	end
	if card.flying then
		table.insert(l, "Vole : seuls les tirs et les volants la touchent")
	end
	if card.targets == "buildings" then
		table.insert(l, "Ne vise que les tours et les batiments")
	end
	if card.splash then
		table.insert(l, "Degats de zone : " .. nombre(card.splash) .. " studs")
	end
	if (tonumber(card.count) or 1) > 1 then
		table.insert(l, "Arrive a " .. nombre(card.count))
	end
	return l
end

-- ===== STATISTIQUES BRUTES =====
-- Les chiffres que la tuile n'a jamais la place de montrer : points de vie, degats, portee,
-- vitesse, cadence. Un sort n'en a aucun (il ne pose pas d'unite) : on rend alors son cout par
-- degat, la seule mesure qui permette de le comparer aux autres sorts.
-- `mult` (facultatif) : multiplicateur de NIVEAU du joueur pour cette carte. Defaut mesure le
-- 2026-09-21 : la fiche affichait TOUJOURS les chiffres du niveau 1. Une carte montee au niveau 4
-- (+30 % de PV et de degats) montrait les memes nombres qu'une carte neuve — la fiche mentait a
-- celui qui avait paye pour l'ameliorer. Le serveur, lui, applique bien le niveau (GameServer,
-- multNiveau) aux PV et aux degats des unites.
function Fiche.stats(card, mult)
	if not card then
		return ""
	end
	local m = tonumber(mult) or 1
	if card.sort then
		local d = math.floor((tonumber(card.sort.degats) or 0) * m + 0.5)
		if d > 0 and (tonumber(card.cost) or 0) > 0 then
			return "Degats " .. nombre(d) .. "  ·  " .. nombre(d / card.cost) .. " par elixir"
		end
		return "Sort : aucun combat direct"
	end
	local bouts = {}
	if (tonumber(card.hp) or 0) > 0 then
		table.insert(bouts, "PV " .. nombre(math.floor(card.hp * m)))
	end
	if (tonumber(card.dmg) or 0) > 0 then
		table.insert(bouts, "Degats " .. nombre(math.floor(card.dmg * m)))
	end
	if (tonumber(card.range) or 0) > 0 then
		table.insert(bouts, "Portee " .. nombre(card.range))
	end
	if (tonumber(card.speed) or 0) > 0 then
		table.insert(bouts, "Vitesse " .. nombre(card.speed))
	end
	if (tonumber(card.atkSpeed) or 0) > 0 then
		table.insert(bouts, "Un coup toutes les " .. secondes(card.atkSpeed))
	end
	return table.concat(bouts, "  ·  ")
end

-- ===== CE QU'APPORTE LE NIVEAU SUIVANT =====
-- Defaut mesure le 2026-09-21 : la boutique affichait « AMELIORER 50 » et rien d'autre. Le joueur
-- payait sans savoir ce qu'il achetait — ni le pourcentage, ni les nouveaux chiffres.
--
-- Le niveau s'applique aussi aux degats d'un SORT depuis le 2026-09-21 (il ne s'y appliquait
-- pas : ameliorer Pizza Bombarda ne rapportait rien). La fiche annonce donc le gain de degats.
-- `bonus` = part gagnee par niveau (Economie.BONUS_PAR_NIVEAU), `maxi` = niveau maximum.
function Fiche.gainNiveau(card, niveau, bonus, maxi)
	if not card then
		return ""
	end
	local n = math.max(1, math.floor(tonumber(niveau) or 1))
	local b = tonumber(bonus) or 0
	if maxi and n >= maxi then
		return "NIVEAU MAX atteint"
	end
	local avant, apres = 1 + b * (n - 1), 1 + b * n
	if card.sort then
		local d = tonumber(card.sort.degats) or 0
		if d > 0 then
			return "NIVEAU " .. (n + 1) .. " : degats " .. nombre(math.floor(d * avant + 0.5))
				.. " -> " .. nombre(math.floor(d * apres + 0.5))
		end
		return ""
	end
	local bouts = {}
	if (tonumber(card.hp) or 0) > 0 then
		table.insert(bouts, "PV " .. nombre(math.floor(card.hp * avant)) .. " -> "
			.. nombre(math.floor(card.hp * apres)))
	end
	if (tonumber(card.dmg) or 0) > 0 then
		table.insert(bouts, "degats " .. nombre(math.floor(card.dmg * avant)) .. " -> "
			.. nombre(math.floor(card.dmg * apres)))
	end
	if #bouts == 0 then
		return ""
	end
	return "NIVEAU " .. (n + 1) .. " : " .. table.concat(bouts, ", ")
end

-- ===== TAILLE DU PANNEAU =====
-- Le panneau de partie avait une hauteur FIXE : sous une carte a un seul effet, il ouvrait un
-- grand vide au milieu de l'arene (capture cap-fiche-partie.png du 2026-09-20), et il aurait
-- tronque une carte a cinq lignes. La hauteur se DEDUIT donc du nombre de lignes.
--   en-tete   : nom, cout et statistiques
--   lignes    : une par effet
--   pied      : le bouton FERMER
-- Bornee des deux cotes : jamais plus petit que l'en-tete plus une ligne, jamais plus haut que
-- ce qu'un petit ecran peut montrer.
Fiche.PANNEAU_ENTETE = 114
Fiche.PANNEAU_LIGNE = 23
-- PIED du panneau, decompose : la marge entre la DERNIERE LIGNE et le bouton etait jusqu'ici
-- un reste de soustraction (8 px dans le hub, 12 en partie, capture du 2026-09-20 : le texte
-- frolait le bouton). Elle devient une valeur NOMMEE, que les deux ecrans utilisent pour
-- placer leur bouton — ils ne peuvent donc plus s'ecarter l'un de l'autre.
Fiche.PANNEAU_MARGE = 24   -- air entre la derniere ligne et le bouton
Fiche.PANNEAU_BOUTON = 40  -- hauteur du bouton FERMER
Fiche.PANNEAU_BAS = 16     -- air sous le bouton
Fiche.PANNEAU_PIED = Fiche.PANNEAU_MARGE + Fiche.PANNEAU_BOUTON + Fiche.PANNEAU_BAS
Fiche.PANNEAU_MIN = 190
Fiche.PANNEAU_MAX = 420

-- `entete` : hauteur de l'en-tete, en pixels. Le panneau du HUB en affiche un de plus que celui
-- de la partie (il montre aussi la rarete), d'ou le parametre plutot qu'une deuxieme regle —
-- deux regles finiraient par diverger, et un seul des deux ecrans serait corrige.
function Fiche.hauteurPanneau(nbLignes, entete)
	local n = math.max(1, math.floor(tonumber(nbLignes) or 1))
	local e = tonumber(entete) or Fiche.PANNEAU_ENTETE
	local h = e + n * Fiche.PANNEAU_LIGNE + Fiche.PANNEAU_PIED
	return math.max(Fiche.PANNEAU_MIN, math.min(Fiche.PANNEAU_MAX, h))
end

-- Hauteur de la ZONE DE LIGNES seule, pour que la liste occupe exactement sa place entre
-- l'en-tete et le bouton — sans chevaucher ni l'un ni l'autre.
function Fiche.hauteurListe(nbLignes, entete)
	local e = tonumber(entete) or Fiche.PANNEAU_ENTETE
	return Fiche.hauteurPanneau(nbLignes, e) - e - Fiche.PANNEAU_PIED
end

-- RESUME sur une ligne, pour une tuile etroite. `maxi` limite le nombre d'effets cites — au-dela,
-- on ajoute le compte de ce qui n'est pas montre plutot que de couper une phrase en deux.
function Fiche.resume(card, maxi, extras)
	local l = Fiche.lignes(card, extras)
	if #l == 0 then
		return card and card.desc or ""
	end
	local n = math.min(maxi or 2, #l)
	local bouts = {}
	for i = 1, n do
		table.insert(bouts, l[i])
	end
	local texte = table.concat(bouts, " · ")
	if #l > n then
		texte = texte .. " (+" .. (#l - n) .. ")"
	end
	return texte
end

-- ETIQUETTE COURTE, pour la main pendant la partie : un seul mot, celui qui decide. Rien a
-- afficher quand la carte n'a pas d'effet particulier — une etiquette vide vaut mieux qu'un
-- « normal » qui occupe la place sans rien dire.
-- NOM TEL QU'IL TIENT SUR UNE CARTE EN MAIN.
--
-- Defaut mesure le 2026-09-21 (capture cap-etiquettes.png) : « Zibra Zubra Zibralini » occupe a
-- lui seul TROIS lignes du bouton ; avec l'etiquette et le cout, la derniere ligne sortait de la
-- carte et le cout etait coupe. Abaisser la taille minimale du texte n'a pas suffi : c'est le
-- nombre de LIGNES qu'il faut reduire.
--
-- On garde les deux premiers mots — c'est ce qui identifie la carte dans une main de quatre — et
-- seulement au-dela de deux mots : « Bombardiro Crocodilo » reste entier. Le nom complet reste
-- affiche partout ailleurs (fiche, boutique, collection).
function Fiche.nomMain(nom)
	local n = tostring(nom or "")
	local mots = {}
	for mot in string.gmatch(n, "%S+") do
		table.insert(mots, mot)
	end
	if #mots <= 2 then
		return n
	end
	return mots[1] .. " " .. mots[2]
end

function Fiche.etiquette(card, extras)
	if not card then
		return ""
	end
	local s = card.sort
	if s then
		local mots = { gel = "GEL", poison = "POISON", soin = "SOIN", rage = "RAGE", degats = "SORT" }
		return mots[s.effet] or "SORT"
	end
	if card.batiment then
		return "BATIMENT"
	end
	if (tonumber(card.bouclier) or 0) > 0 then
		return "BOUCLIER"
	end
	if card.soin then
		return "SOIGNEUR"
	end
	if card.effet and card.effet.poison then
		return "POISON"
	end
	if card.effet and card.effet.lent then
		return "RALENTIT"
	end
	if card.mort then
		return "EXPLOSE"
	end
	if card.poseLibre then
		return "PARTOUT"
	end
	local sp = extras and extras.specialite
	if sp then
		return sp.contre == "air" and "ANTI-AIR" or "ANTI-ESSAIM"
	end
	if extras and extras.soutien then
		return "SOUTIEN"
	end
	-- CHARGE et ASSASSIN arrivent EN DERNIER, apres toutes les etiquettes existantes : elles
	-- comblent un vide (Cocofanto et Cappuccino n'en portaient aucune) sans jamais remplacer
	-- l'etiquette d'une carte qui en avait deja une. Deplacer les autres changerait ce que le
	-- joueur a appris a lire en main.
	if extras and extras.charge and (tonumber(extras.charge.multiplicateur) or 1) > 1 then
		return "CHARGE"
	end
	if extras and extras.assassin then
		return "ASSASSIN"
	end
	return ""
end

-- BOUTON D'AMELIORATION : « AMELIORER 50 » sur une carte a 0/2 exemplaires promettait un clic
-- refuse (« pas assez d'exemplaires »). Il dit ce qui MANQUE, les exemplaires d'abord : ce sont
-- eux qui bloquent le plus longtemps (capture shop.png, 2026-09-21).
function Fiche.texteAmelioration(ex, besoin, pieces, cout)
	ex, besoin, pieces, cout = tonumber(ex) or 0, tonumber(besoin) or 0, tonumber(pieces) or 0, tonumber(cout) or 0
	if ex < besoin then
		local m = besoin - ex
		return "IL MANQUE " .. m .. (m > 1 and " EXEMPLAIRES" or " EXEMPLAIRE")
	end
	if pieces < cout then
		return "IL MANQUE " .. (cout - pieces) .. " PIECES"
	end
	return "AMELIORER " .. cout
end

-- OU TROUVER LES EXEMPLAIRES : « IL MANQUE 2 EXEMPLAIRES » ne disait pas d'ou ils viennent. La
-- seule source est l'ouverture d'un coffre (Economie.ouvrirCoffre) : la ligne le dit tant qu'il
-- en manque, et redevient sobre des que le compte est bon.
function Fiche.texteExemplaires(ex, besoin)
	ex, besoin = tonumber(ex) or 0, tonumber(besoin) or 0
	local t = ex .. "/" .. besoin .. " exemplaires"
	if ex < besoin then
		t = t .. " - dans les coffres"
	end
	return t
end

-- BOUTON D'ACHAT : « ACHETER » sur une carte a 1100 pieces avec 100 en poche promettait un clic
-- refuse (capture bas-boutique.png, 2026-09-21). Il dit ce qui manque, comme AMELIORER.
function Fiche.texteAchat(pieces, prix)
	pieces, prix = tonumber(pieces) or 0, tonumber(prix) or 0
	if pieces < prix then
		return "IL MANQUE " .. (prix - pieces) .. " PIECES"
	end
	return "ACHETER"
end

return Fiche
