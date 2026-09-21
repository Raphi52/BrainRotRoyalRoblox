-- OUVERTURE DE COFFRE MISE EN SCENE (2026-09-21). Avant : une seule ligne de texte
-- (« +37 pieces + 4 x Tung Tung ») sous la rangee de coffres. C'est pourtant LE moment qui fait
-- revenir les joueurs. Le client joue : coffre qui tremble -> flash -> cartes face cachee qui se
-- retournent une a une, encadrees de la couleur de leur rarete. Ce module dit QUOI reveler et
-- QUAND ; il ne touche a aucune instance (teste hors Roblox par tools/test_ouverture.py).
local Ouverture = {}

Ouverture.TREMBLE = 1.1      -- s : le coffre tremble de plus en plus fort
Ouverture.FLASH = 0.35       -- s : eclair blanc qui ouvre le coffre
Ouverture.INTERVALLE = 0.6   -- s entre deux cartes retournees
Ouverture.RETOURNE = 0.32    -- s : duree d'un retournement (demi-tour x2)

local OR = { 255, 205, 60 }

-- Les cartes a reveler, dans l'ordre du suspense : pieces, puis exemplaires, puis la carte NOUVELLE
-- (la plus rare garde le dernier retournement, comme dans le jeu de reference).
-- gain = retour de Economie.ouvrirCoffre ; cartes = module Cards (byId, RARETES).
function Ouverture.cartes(gain, cartes)
	local l = {}
	if not gain then
		return l
	end
	if (gain.pieces or 0) > 0 then
		table.insert(l, { titre = "+" .. gain.pieces, sous = "pieces", couleur = OR, rarete = "pieces" })
	end
	local function rar(id)
		local c = cartes.byId[id]
		local r = c and cartes.RARETES[c.rarete]
		return c, r
	end
	if gain.exemplaireCarte and (gain.exemplaires or 0) > 0 then
		local c, r = rar(gain.exemplaireCarte)
		if c then
			table.insert(l, { titre = "x" .. gain.exemplaires, sous = c.name, carte = c.id,
				couleur = r and r.couleur or OR, rarete = c.rarete })
		end
	end
	if gain.carte then
		local c, r = rar(gain.carte)
		if c then
			table.insert(l, { titre = "NOUVELLE!", sous = c.name, carte = c.id,
				couleur = r and r.couleur or OR, rarete = c.rarete, nouvelle = true })
		end
	end
	return l
end

-- Instant (s depuis le debut de la scene) ou la carte i commence a se retourner.
function Ouverture.instant(i)
	return Ouverture.TREMBLE + Ouverture.FLASH + (i - 1) * Ouverture.INTERVALLE
end

-- Amplitude du tremblement (degres) a l'instant t : monte jusqu'au flash, puis s'arrete.
function Ouverture.tremblement(t)
	if t < 0 or t >= Ouverture.TREMBLE then
		return 0
	end
	return 2 + 12 * (t / Ouverture.TREMBLE)
end

return Ouverture
