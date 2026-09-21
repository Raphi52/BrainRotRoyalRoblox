-- STATUTS TEMPORAIRES : gel, ralentissement, poison, bouclier, soin, regeneration.
--
-- Pourquoi ce module existe : jusqu'ici une unite n'avait que deux etats, vivante ou morte. Aucune
-- carte ne pouvait la RETARDER, l'empoisonner ni la proteger — donc aucune defense ne reposait sur
-- le temps, seulement sur les points de vie bruts. C'est ce qui rendait chaque echange purement
-- arithmetique : le plus gros tas gagnait, toujours.
--
-- Tout ce qui se DECIDE est ici, en fonctions PURES (aucune API Roblox), donc verifiable hors
-- Studio (tools/test_statuts.py). Le serveur ne fait qu'appliquer et dessiner.
--
-- Forme d'un porteur de statuts (le serveur passe son entite telle quelle) :
--   { statuts = { gel = { fin = t }, lent = { fin = t, part = 0.35 }, ... } }
-- `fin` est une date sur la meme horloge que celle passee aux fonctions : rien ici ne lit le temps.
local Statuts = {}

-- Bornes. Aucune valeur recue d'une carte ne sort de la : une carte mal reglee ne peut pas geler
-- une unite pour toute la partie ni la ralentir jusqu'a l'immobilite.
Statuts.GEL_MAX = 5              -- secondes
Statuts.LENT_PART_MAX = 0.8      -- on ne descend jamais sous 20 % de la vitesse
Statuts.POISON_TIC = 0.5         -- un tic de poison toutes les demi-secondes
Statuts.INVULN_POSE = 0.35       -- secondes d'invulnerabilite a l'apparition (anti « sort a la pose »)

local function table_statuts(porteur)
	porteur.statuts = porteur.statuts or {}
	return porteur.statuts
end

-- APPLIQUER un statut. Re-appliquer le MEME statut PROLONGE (on garde la fin la plus lointaine et
-- l'effet le plus fort) au lieu de s'empiler : sans cela, trois sorts de glace successifs gelaient
-- une unite trois fois plus longtemps que la somme annoncee sur les cartes.
--   nom   : "gel" | "lent" | "poison" | "regen" | "rage"
--   infos : { duree = n, part = n, degats = n, tic = n }
function Statuts.appliquer(porteur, nom, infos, maintenant)
	if not porteur or not nom then
		return nil
	end
	local t = maintenant or 0
	local duree = math.max(0, tonumber(infos and infos.duree) or 0)
	if nom == "gel" then
		duree = math.min(duree, Statuts.GEL_MAX)
	end
	if duree <= 0 then
		return nil
	end
	local s = table_statuts(porteur)
	local ancien = s[nom]
	local part = math.min(tonumber(infos and infos.part) or 0, Statuts.LENT_PART_MAX)
	local nouveau = {
		fin = t + duree,
		part = part,
		degats = tonumber(infos and infos.degats) or 0,
		tic = tonumber(infos and infos.tic) or Statuts.POISON_TIC,
		prochainTic = t + (tonumber(infos and infos.tic) or Statuts.POISON_TIC),
	}
	if ancien and ancien.fin > nouveau.fin then
		nouveau.fin = ancien.fin
	end
	if ancien and (ancien.part or 0) > nouveau.part then
		nouveau.part = ancien.part
	end
	if ancien and ancien.prochainTic then
		nouveau.prochainTic = ancien.prochainTic
	end
	s[nom] = nouveau
	return nouveau
end

-- Le statut est-il ACTIF maintenant ? Un statut expire ne laisse aucune trace : pas de vitesse
-- residuelle, pas de demi-gel.
function Statuts.actif(porteur, nom, maintenant)
	local s = porteur and porteur.statuts and porteur.statuts[nom]
	if not s then
		return false
	end
	return (maintenant or 0) < s.fin
end

-- RETIRER un statut (la rage PURGE le ralentissement : c'est ce qui donne une reponse au gel).
function Statuts.retirer(porteur, nom)
	if porteur and porteur.statuts then
		porteur.statuts[nom] = nil
	end
end

-- L'unite peut-elle AGIR (marcher, attaquer) ? Le gel arrete tout ; rien d'autre.
function Statuts.peutAgir(porteur, maintenant)
	return not Statuts.actif(porteur, "gel", maintenant)
end

-- FACTEUR DE VITESSE, ralentissement et rage combines. Gele : 0, sans discontinuite a la sortie.
-- Le resultat reste dans [0, 3] : une carte ne peut pas rendre une unite injouable a suivre.
function Statuts.facteurVitesse(porteur, maintenant, rage)
	if Statuts.actif(porteur, "gel", maintenant) then
		return 0
	end
	local f = tonumber(rage) or 1
	local lent = porteur and porteur.statuts and porteur.statuts.lent
	if lent and (maintenant or 0) < lent.fin then
		f = f * (1 - math.min(lent.part or 0, Statuts.LENT_PART_MAX))
	end
	if f < 0 then
		f = 0
	elseif f > 3 then
		f = 3
	end
	return f
end

-- POISON / REGENERATION : combien de PV ce porteur perd (positif) ou regagne (negatif) depuis le
-- dernier appel. Rend 0 tant que le tic n'est pas echu — les degats tombent par paliers visibles,
-- pas image par image (sinon le chiffre de degats clignote sans etre lisible).
function Statuts.tic(porteur, nom, maintenant)
	local s = porteur and porteur.statuts and porteur.statuts[nom]
	if not s then
		return 0
	end
	local t = maintenant or 0
	if t >= s.fin then
		porteur.statuts[nom] = nil
		return 0
	end
	local total = 0
	local pas = math.max(s.tic or Statuts.POISON_TIC, 0.05)
	while s.prochainTic and t >= s.prochainTic do
		total = total + (s.degats or 0)
		s.prochainTic = s.prochainTic + pas
	end
	return total
end

-- ===== BOUCLIER =====
-- Un bouclier encaisse AVANT les points de vie et ne se regenere pas. C'est ce qui rend une petite
-- unite capable d'ABSORBER un sort : sans lui, tout sort de zone effacait les groupes sans reponse.
function Statuts.poserBouclier(porteur, valeur)
	if not porteur then
		return 0
	end
	porteur.bouclier = math.max(0, tonumber(valeur) or 0)
	porteur.bouclierMax = porteur.bouclier
	return porteur.bouclier
end

-- REPARTIT un coup entre bouclier et points de vie. Rend (degatsSurPV, boucliersRestant, casse).
-- `casse` vaut vrai a l'instant ou le bouclier tombe : le serveur en fait un eclat visible.
function Statuts.encaisser(porteur, degats)
	local d = math.max(0, tonumber(degats) or 0)
	local b = math.max(0, tonumber(porteur and porteur.bouclier) or 0)
	if b <= 0 then
		return d, 0, false
	end
	if d < b then
		porteur.bouclier = b - d
		return 0, porteur.bouclier, false
	end
	porteur.bouclier = 0
	return d - b, 0, true
end

-- ETAT VISIBLE DU BOUCLIER : quelle PART en reste-t-il (0 a 1) ? Le rendu s'y accroche, si bien
-- qu'une coque epaisse dit « il tiendra encore » et une coque presque effacee « le prochain coup
-- passe ». Sans cette part, le bouclier n'etait visible qu'a l'instant ou il CASSAIT — trop tard
-- pour decider quoi que ce soit.
function Statuts.partBouclier(porteur)
	local max = tonumber(porteur and porteur.bouclierMax) or 0
	if max <= 0 then
		return 0
	end
	local reste = math.max(0, tonumber(porteur.bouclier) or 0)
	return math.min(1, reste / max)
end

-- OPACITE de la coque, deduite de cette part. Bornee des DEUX cotes : une coque totalement opaque
-- cacherait le personnage (on ne saurait plus quelle carte on affronte), une coque totalement
-- transparente ne se verrait pas du tout.
Statuts.BOUCLIER_OPACITE_PLEIN = 0.35
Statuts.BOUCLIER_OPACITE_VIDE = 0.9

function Statuts.opaciteBouclier(porteur)
	local part = Statuts.partBouclier(porteur)
	return Statuts.BOUCLIER_OPACITE_VIDE
		+ (Statuts.BOUCLIER_OPACITE_PLEIN - Statuts.BOUCLIER_OPACITE_VIDE) * part
end

-- EPAISSEUR de la coque, en part de la taille du corps : elle MAIGRIT en encaissant, jusqu'a
-- coller au personnage juste avant de ceder.
Statuts.BOUCLIER_MARGE_PLEIN = 1.45
Statuts.BOUCLIER_MARGE_VIDE = 1.05

function Statuts.epaisseurBouclier(porteur)
	local part = Statuts.partBouclier(porteur)
	return Statuts.BOUCLIER_MARGE_VIDE
		+ (Statuts.BOUCLIER_MARGE_PLEIN - Statuts.BOUCLIER_MARGE_VIDE) * part
end

-- ===== SOIN =====
-- Un soin ne depasse JAMAIS les PV maximaux et ne ressuscite pas : un soigneur derriere un tank
-- prolonge une poussee, il ne la rend pas eternelle.
function Statuts.soigner(porteur, montant)
	if not porteur or porteur.alive == false then
		return 0
	end
	local max = tonumber(porteur.maxHp) or 0
	local hp = tonumber(porteur.hp) or 0
	local gain = math.max(0, math.min(tonumber(montant) or 0, max - hp))
	porteur.hp = hp + gain
	return gain
end

-- ===== INVULNERABILITE A LA POSE =====
-- Defaut mesure : un sort lance PILE sur la zone de pose effacait l'unite avant meme qu'elle
-- touche le sol. Une courte grace rend la pose lisible sans proteger quoi que ce soit d'autre.
function Statuts.invulnerable(porteur, maintenant)
	local pose = porteur and porteur.poseT
	if not pose then
		return false
	end
	return (maintenant or 0) - pose < Statuts.INVULN_POSE
end

-- ===== DEGATS DE MORT =====
-- Certaines cartes EXPLOSENT en mourant. La regle vit ici pour que le banc puisse la verifier sans
-- Studio : rend la liste des index touches dans `objets` (meme forme que Sorts.cibles).
function Statuts.explosionMort(carte, objets, campMort, x, z)
	local e = carte and carte.mort
	if not e or (e.degats or 0) <= 0 then
		return {}, 0
	end
	local touches = {}
	for i, o in ipairs(objets or {}) do
		if o.camp ~= campMort then
			local dx, dz = o.x - x, o.z - z
			if math.sqrt(dx * dx + dz * dz) <= (e.rayon or 0) then
				table.insert(touches, i)
			end
		end
	end
	return touches, e.degats
end

return Statuts
