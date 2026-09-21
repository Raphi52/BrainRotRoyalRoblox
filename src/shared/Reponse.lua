-- REPONSE : quelle carte jouer CONTRE ce qui arrive.
--
-- Defaut mesure avant ce module, dans `botThink` : le robot prenait « la carte la plus CHERE
-- qu'il peut payer », avec un seul filtre — savoir viser les volants. Deux consequences :
--   * il ignorait tout ce que le jeu a appris depuis : anti-air x2, anti-groupe x1,8, auras de
--     soutien, assassins. Les regles existaient, l'adversaire ne s'en servait pas ;
--   * « la plus chere » n'est meme pas un bon critere : elle le pousse a vider son elixir sur une
--     grosse carte sans rapport avec ce qui le menace, alors qu'une petite carte bien choisie
--     repousse la meme attaque pour trois fois moins.
--
-- Ce module NOTE chaque carte jouable face a la situation. Il reste pur : il ne connait ni les
-- modules de regles ni le catalogue, on lui passe les TRAITS deja calcules. C'est ce qui permet
-- de le verifier hors Studio (tools/test_reponse.py) et d'eviter qu'il redecrive les regles.
local Reponse = {}

-- Poids des reponses. Ils se LISENT : un anti-air face a des volants vaut plus que tout le reste,
-- parce qu'une attaque aerienne non repondue coute une tour.
Reponse.BONUS_ANTI_AIR = 60
Reponse.BONUS_ANTI_GROUPE = 40
Reponse.BONUS_ASSASSIN = 25      -- face a un tireur installe
Reponse.BONUS_SOUTIEN = 15       -- des qu'il y a des allies a renforcer
-- Un soutien pose SEUL ne fait rien : il n'a personne a renforcer. C'est un mauvais choix, pas
-- une carte interdite — le malus doit donc rester FRANCHEMENT plus petit que les bonus, sinon la
-- carte devient morte. Mesure du 2026-09-20 : avec un malus de -50, les trois cartes de soutien
-- du jeu n'ont ete jouees AUCUNE fois sur une partie entiere. (Les porteurs etaient alors
-- Lirili, Spaghettino et Zibra ; Zibra a depuis perdu son aura — elle chargeait a 9 studs pour
-- un rayon de 6,5 — et Glorbo l'a remplacee. La mesure, elle, ne change pas.)
Reponse.MALUS_SOUTIEN_SEUL = -12
Reponse.BONUS_ZONE = 20          -- degats de zone contre un essaim, meme sans specialite
Reponse.MALUS_IMPUISSANT = -100  -- incapable de toucher la menace : presque jamais le bon choix
-- L'elixir compte, mais APRES la pertinence : a pertinence egale, on prefere la carte qui coute
-- le moins cher, pour garder de quoi repondre au coup suivant.
Reponse.POIDS_COUT = -2
-- Quand rien de special n'est menace, une carte plus consistante vaut un peu mieux qu'une autre :
-- c'est ce qui remplace l'ancien « la plus chere », mais en tres petit.
Reponse.POIDS_CORPS = 1

-- MENACE observee : ce que l'adversaire a deja sur le terrain.
--   objets : liste de { camp, pv, volant, enGroupe, portee, batiment }
-- Rend { pv, volante, essaim, tireur } pour le camp ADVERSE de `campMoi`.
-- `allies` compte AUSSI les unites du camp de celui qui decide : un soutien n'a de sens que s'il
-- y a quelqu'un a renforcer, et c'est la seule facon de le savoir.
function Reponse.menace(objets, campMoi, porteeTireur)
	local vue = { pv = 0, volante = false, essaim = false, tireur = false, allies = 0 }
	if not objets then
		return vue
	end
	local parPortee = porteeTireur or 5
	for _, o in ipairs(objets) do
		if o.camp == campMoi and not o.batiment then
			vue.allies = vue.allies + 1
		end
		if o.camp ~= campMoi and not o.batiment then
			vue.pv = vue.pv + (tonumber(o.pv) or 0)
			if o.volant then
				vue.volante = true
			end
			if o.enGroupe then
				vue.essaim = true
			end
			if (tonumber(o.portee) or 0) >= parPortee then
				vue.tireur = true
			end
		end
	end
	return vue
end

-- NOTE d'une carte face a la menace.
--   traits : { peutViserVolant, antiAir, antiGroupe, assassin, soutien, zone, cout, corps }
--            `corps` = une mesure de consistance (pv + degats), normalisee par l'appelant.
--   enAttaque : vrai quand le robot ATTAQUE (et non quand il defend).
function Reponse.note(traits, menace, enAttaque)
	if not traits then
		return -math.huge
	end
	local n = 0
	local m = menace or {}
	if m.volante then
		if not traits.peutViserVolant then
			n = n + Reponse.MALUS_IMPUISSANT
		elseif traits.antiAir then
			n = n + Reponse.BONUS_ANTI_AIR
		end
	end
	if m.essaim then
		if traits.antiGroupe then
			n = n + Reponse.BONUS_ANTI_GROUPE
		elseif traits.zone then
			n = n + Reponse.BONUS_ZONE
		end
	end
	if m.tireur and traits.assassin then
		n = n + Reponse.BONUS_ASSASSIN
	end
	-- SOUTIEN : ce qui compte n'est pas d'attaquer ou de defendre, c'est d'avoir QUELQU'UN a
	-- renforcer. Renforcer ses defenseurs est parfaitement legitime ; poser un tambour dans une
	-- moitie vide ne l'est pas. L'ancienne regle (« bon en attaque, catastrophique en defense »)
	-- rendait ces cartes injouables pour le robot, qui defend la plupart du temps.
	if traits.soutien then
		if (tonumber(m.allies) or 0) > 0 then
			n = n + Reponse.BONUS_SOUTIEN
		else
			n = n + Reponse.MALUS_SOUTIEN_SEUL
		end
	end
	n = n + (tonumber(traits.cout) or 0) * Reponse.POIDS_COUT
	n = n + (tonumber(traits.corps) or 0) * Reponse.POIDS_CORPS
	return n
end

-- MEILLEURE carte d'une main. `mains` : liste de { index, traits }. Rend l'index choisi, sa note,
-- et l'index du meilleur choix SANS tenir compte de la menace (utile au banc pour montrer ce que
-- le module change). Depart : en cas d'egalite stricte, le plus petit index — donc un choix
-- REPRODUCTIBLE, jamais dependant de l'ordre de parcours d'une table.
function Reponse.choisir(mains, menace, enAttaque)
	local best, bestNote = nil, -math.huge
	if not mains then
		return nil, bestNote
	end
	for _, m in ipairs(mains) do
		local n = Reponse.note(m.traits, menace, enAttaque)
		if n > bestNote then
			best, bestNote = m.index, n
		end
	end
	return best, bestNote
end

return Reponse
