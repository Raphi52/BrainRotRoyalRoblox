-- FRAPPE : comment les bonus de degats se COMPOSENT, et jusqu'ou.
--
-- Le jeu a maintenant plusieurs regles qui majorent un meme coup :
--   * Soutien   — une aura alliee, jusqu'a x1,5
--   * Specialite— anti-air / anti-groupe, jusqu'a x2,5
--   * Charge    — l'elan d'une unite lancee, jusqu'a x3
-- Chacune est bornee de son cote, mais elles se MULTIPLIAIENT sans aucun plafond commun :
-- x1,5 x 2,5 x 3 = **x11,25** possible en theorie. Aujourd'hui la meilleure combinaison
-- reellement jouable atteint x3,25 (Cocofanto lance, sous une aura), donc personne ne s'en
-- apercevait — mais la prochaine carte qui cumulerait les trois ferait n'importe quoi, et c'est
-- exactement le genre de defaut qu'on ne voit qu'une fois le jeu publie.
--
-- Ce module ne retire rien a ce qui existe : il pose le plafond commun et rend la composition
-- lisible en un seul endroit. Fonctions pures (tools/test_frappe.py).
local Frappe = {}

-- Plafond COMMUN. Une combinaison reussie doit recompenser fort, sans permettre d'effacer une
-- tour en un coup. Choisi au-dessus de la meilleure combinaison actuelle (x3,25) : aucune
-- situation du jeu d'aujourd'hui n'est affaiblie par ce garde-fou.
Frappe.PLAFOND = 4

-- Compose une liste de multiplicateurs. Rend le multiplicateur final ET si le plafond a mordu
-- (le serveur peut alors le tracer : un plafond qui mord souvent est un signal d'equilibrage).
function Frappe.composer(multiplicateurs)
	local total = 1
	if multiplicateurs then
		for _, m in ipairs(multiplicateurs) do
			local v = tonumber(m) or 1
			if v > 0 then
				total = total * v
			end
		end
	end
	if total > Frappe.PLAFOND then
		return Frappe.PLAFOND, true
	end
	if total < 1 then
		return 1, false -- aucun bonus ne peut AFFAIBLIR un coup : ce n'est pas leur role
	end
	return total, false
end

-- Degats finaux, en nombre entier.
function Frappe.degats(base, multiplicateur)
	local d = tonumber(base) or 0
	local m = tonumber(multiplicateur) or 1
	if m < 1 then
		m = 1
	end
	if m > Frappe.PLAFOND then
		m = Frappe.PLAFOND
	end
	if d <= 0 then
		return 0
	end
	return math.floor(d * m + 0.5)
end

return Frappe
