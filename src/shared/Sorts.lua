-- SORTS : les regles, en fonctions PURES (aucune API Roblox).
--
-- Un sort ne pose aucune unite. Il frappe — ou renforce — une ZONE, n'importe ou dans l'arene,
-- y compris chez l'ennemi. C'etait le manque le plus visible du jeu : un groupe serre de petites
-- unites n'avait aucune reponse, et une tour presque morte ne pouvait pas etre achevee de loin.
--
-- Tout ce qui se DECIDE (qui est touche, combien, la zone permise) est ici, donc verifiable hors
-- Studio (tools/test_sorts.py). Le serveur ne garde que ce qui se DESSINE.
local Sorts = {}

-- Un sort peut viser TOUTE l'arene : c'est ce qui le distingue d'une unite, dont la pose est
-- limitee a sa moitie. Seuls les bords comptent.
function Sorts.cibleValide(x, z, demiLargeur, demiLongueur)
	return math.abs(x) <= demiLargeur - 1 and math.abs(z) <= demiLongueur - 1
end

-- Cibles touchees : tout ce qui est ENNEMI (pour un sort de degats) ou ALLIE (pour la rage) et
-- se trouve dans le rayon, mesure au SOL (la hauteur ne protege pas : un volant est touche).
-- `objets` : liste de { camp = 1|2, x = n, z = n, batiment = bool }.
function Sorts.cibles(objets, campLanceur, centreX, centreZ, rayon, effet)
	local touches = {}
	for i, o in ipairs(objets) do
		local dx, dz = o.x - centreX, o.z - centreZ
		if math.sqrt(dx * dx + dz * dz) <= rayon then
			local allie = o.camp == campLanceur
			if effet == "rage" or effet == "soin" then
				-- la rage et le soin ne touchent QUE ses propres unites (jamais les tours : une tour ne
			-- marche pas, et la soigner rendrait toute attaque vaine)
				if allie and not o.batiment then
					table.insert(touches, i)
				end
			elseif not allie then
				table.insert(touches, i)
			end
		end
	end
	return touches
end

-- Degats appliques a UNE cible. Une TOUR encaisse moins qu'une unite (regle classique du genre) :
-- sans cela, deux sorts suffisaient a raser une tour sans jamais attaquer avec des unites.
function Sorts.degats(sort, estBatiment)
	local d = sort.degats or 0
	if estBatiment then
		-- arrondi AU PLUS PROCHE : 340 x 0,35 vaut 118,999... en virgule flottante, et un
		-- `floor` rendait 118 la ou la regle annonce 119 (vu au banc, 2026-09-20).
		return math.floor(d * (sort.degatsTour or 0.35) + 0.5)
	end
	return math.floor(d + 0.5)
end

-- RAGE : multiplicateur applique a la vitesse de marche et a la cadence d'attaque.
-- Rend 1 quand la rage est finie, sans discontinuite (pas de saut de vitesse a l'expiration).
function Sorts.multiplicateurRage(sort, depuis)
	local duree = sort and sort.duree or 0
	if not depuis or depuis < 0 or depuis >= duree then
		return 1
	end
	return 1 + (sort.gain or 0)
end

-- Valeur BRUTE d'un sort de degats, pour l'equilibrage : degats par elixir. Sert au banc, pas au
-- jeu — mais elle vit ici pour que la mesure et la regle ne divergent jamais.
function Sorts.degatsParElixir(carte)
	local s = carte.sort
	if not s or s.effet ~= "degats" or (carte.cost or 0) <= 0 then
		return 0
	end
	return (s.degats or 0) / carte.cost
end

-- ===== SORTS A CIBLES CHOISIES (la foudre) =====
-- La foudre ne frappe pas une zone au hasard : elle tombe sur les `n` cibles les plus SOLIDES de
-- la zone. C'est ce qui en fait une reponse aux batiments et aux gros tireurs, et non un sort de
-- nettoyage de plus. `objets` porte alors un champ `pv`.
function Sorts.plusSolides(objets, index, n)
	local l = {}
	for _, i in ipairs(index) do
		table.insert(l, i)
	end
	table.sort(l, function(a, b)
		local pa, pb = objets[a].pv or 0, objets[b].pv or 0
		if pa == pb then
			return a < b -- ordre stable : deux cibles a egalite ne changent pas d'avis
		end
		return pa > pb
	end)
	local garde = {}
	for k = 1, math.min(n or #l, #l) do
		table.insert(garde, l[k])
	end
	return garde
end

-- Certains sorts ne touchent QUE LE SOL (le tronc qui roule). Un volant leur passe au-dessus :
-- sans cette regle, un sort a 2 elixir repondait aussi bien aux volants qu'aux unites au sol.
function Sorts.auSol(objets, index)
	local garde = {}
	for _, i in ipairs(index) do
		if not objets[i].vole then
			table.insert(garde, i)
		end
	end
	return garde
end

-- RECUL : de combien de studs une cible est repoussee, dans la direction qui l'eloigne du centre.
-- Rend (dx, dz). Une cible pile au centre n'est pas poussee (direction indefinie), un batiment
-- jamais (il est ancre au sol).
function Sorts.recul(sort, objet, centreX, centreZ)
	local r = sort and sort.recul
	if not r or r <= 0 or not objet or objet.batiment then
		return 0, 0
	end
	local dx, dz = objet.x - centreX, objet.z - centreZ
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-4 then
		return 0, 0
	end
	return dx / d * r, dz / d * r
end

return Sorts
