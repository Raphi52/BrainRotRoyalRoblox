-- GESTES DE POSE, en fonctions PURES.
--
-- Deux manques de l'audit :
--  1. AUCUN GLISSER-DEPOSER. Il fallait taper la carte, puis taper l'arene — deux gestes la ou le
--     genre entier en demande un seul. Au doigt, c'est deux fois plus lent et deux fois plus rate.
--  2. AUCUNE ANNULATION. Une carte choisie par erreur restait armee : le geste suivant, meme a
--     l'autre bout de l'ecran, la posait. On perdait la carte ET l'elixir.
--
-- Ces regles vivent ici pour etre verifiables hors Studio (tools/test_geste.py) : le client ne
-- fait que brancher des evenements dessus.
local Geste = {}

-- Au-dela de ce deplacement (en pixels) depuis l'appui, ce n'est plus un clic mais un glisse.
-- 12 px : assez pour tolerer le tremblement d'un doigt, assez peu pour que l'intention se lise.
Geste.SEUIL_GLISSE = 12

function Geste.distance(x1, y1, x2, y2)
	local dx, dy = (x2 or 0) - (x1 or 0), (y2 or 0) - (y1 or 0)
	return math.sqrt(dx * dx + dy * dy)
end

-- Quel geste vient de se terminer ? « clic » (on garde la carte armee, mode deux temps) ou
-- « glisse » (on pose la ou le doigt s'est leve).
function Geste.type(xDepart, yDepart, xFin, yFin)
	if Geste.distance(xDepart, yDepart, xFin, yFin) >= Geste.SEUIL_GLISSE then
		return "glisse"
	end
	return "clic"
end

-- ANNULATION : relacher SUR le panneau de cartes (la zone d'ou vient la carte) veut dire « je
-- renonce ». C'est le geste naturel — on repose la carte la ou on l'a prise — et il evite la
-- pose accidentelle en bas de l'ecran, qui est de toute facon hors zone.
--   yFin, hauteurEcran : en pixels ; hautPanneau : ordonnee du haut du panneau de cartes.
function Geste.annuleSurPanneau(yFin, hautPanneau)
	if yFin == nil or hautPanneau == nil then
		return false
	end
	return yFin >= hautPanneau
end

-- Touches et boutons qui annulent : echap, clic droit. Liste FERMEE : le client passe le nom de
-- la touche, jamais un comportement.
Geste.ANNULATIONS = { Escape = true, MouseButton2 = true }
function Geste.annuleParTouche(nom)
	return Geste.ANNULATIONS[nom] == true
end

-- DECISION COMPLETE d'un relachement. Rend l'action : "poser", "garder", "annuler".
--   surPanneau : le doigt s'est leve sur la main de cartes
--   surArene   : le rayon a touche l'arene
function Geste.relachement(typeGeste, surPanneau, surArene)
	if surPanneau then
		return "annuler"
	end
	if typeGeste == "glisse" then
		-- un glisse qui finit hors de l'arene n'est pas une pose ratee : c'est un renoncement
		return surArene and "poser" or "annuler"
	end
	-- simple clic : on garde la carte armee, la pose se fera au geste suivant (mode deux temps,
	-- qui reste le plus sur pour poser loin, a la souris)
	return "garder"
end

-- Ce qu'on dit au joueur quand il annule : une annulation muette ressemble a un bug.
function Geste.texteAnnulation()
	return "Carte reposee"
end

return Geste
