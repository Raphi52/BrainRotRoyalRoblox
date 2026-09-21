-- PARTAGER UNE FIN DE PARTIE, en fonctions PURES.
--
-- Le defaut corrige : rien ne sortait du jeu. Une victoire serree, une remontee, un adversaire
-- coriace — tout disparaissait a l'ecran suivant. On ne pouvait ni la montrer, ni la comparer,
-- ni meme s'en souvenir precisement.
--
-- CE QUE CE MODULE N'EST PAS : un replay. Rejouer une partie demanderait d'enregistrer chaque
-- pose et chaque coup, et de les rejouer a l'identique — un autre chantier, bien plus lourd. Ici
-- on partage un RESUME : les faits de la partie, lisibles par un humain, et un CODE compact qui
-- porte les memes chiffres et se relit (Partage.lire). Dire « code de match » sans preciser
-- serait promettre un replay qu'on ne livre pas.
local Partage = {}

Partage.VERSION = "BRR1"

Partage.ISSUES = { victoire = "V", defaite = "D", egalite = "E" }
Partage.ISSUES_INVERSE = { V = "victoire", D = "defaite", E = "egalite" }

local function borne(n, mini, maxi)
	n = math.floor(tonumber(n) or 0)
	return math.max(mini, math.min(maxi, n))
end

-- CODE COMPACT : « BRR1-V30-152-17-2 ». Version, issue + couronnes, duree, elixir gaspille,
-- cartes jouees. Tout tient sur une ligne qu'on peut dicter ou coller dans un message.
function Partage.code(d)
	d = d or {}
	local issue = Partage.ISSUES[d.issue or ""] or "E"
	return table.concat({
		Partage.VERSION,
		issue .. tostring(borne(d.couronnesMoi, 0, 3)) .. tostring(borne(d.couronnesLui, 0, 3)),
		tostring(borne(d.duree, 0, 9999)),
		tostring(borne(d.gaspille, 0, 999)),
		tostring(borne(d.cartes, 0, 999)),
	}, "-")
end

-- RELECTURE d'un code. Rend une table, ou nil si le code n'est pas des notres. Un code qu'on ne
-- sait pas relire ne doit pas produire des chiffres inventes.
function Partage.lire(code)
	if type(code) ~= "string" then
		return nil
	end
	local v, issue, cm, cl, duree, gasp, cartes =
		string.match(code, "^(%u+%d)%-(%u)(%d)(%d)%-(%d+)%-(%d+)%-(%d+)$")
	if v ~= Partage.VERSION or not Partage.ISSUES_INVERSE[issue] then
		return nil
	end
	return {
		issue = Partage.ISSUES_INVERSE[issue],
		couronnesMoi = tonumber(cm), couronnesLui = tonumber(cl),
		duree = tonumber(duree), gaspille = tonumber(gasp), cartes = tonumber(cartes),
	}
end

-- DUREE en minutes:secondes, comme le chrono de la partie.
function Partage.duree(secondes)
	local s = borne(secondes, 0, 9999)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- RESUME LISIBLE, celui qu'on colle dans un message. Court : cinq lignes, pas un rapport.
function Partage.resume(d)
	d = d or {}
	local issue = d.issue or "egalite"
	local titre = (issue == "victoire" and "Victoire") or (issue == "defaite" and "Defaite") or "Egalite"
	local lignes = {
		string.format("Brainrot Royale — %s %d-%d contre %s",
			titre, borne(d.couronnesMoi, 0, 3), borne(d.couronnesLui, 0, 3),
			tostring(d.adversaire or "Robot")),
		string.format("Duree %s  ·  %d cartes jouees  ·  %d elixir gaspille",
			Partage.duree(d.duree), borne(d.cartes, 0, 999), borne(d.gaspille, 0, 999)),
	}
	if d.degatsTours then
		table.insert(lignes, string.format("Degats sur ses tours : %d", borne(d.degatsTours, 0, 999999)))
	end
	-- Arene et decor : on n'assemble que ce qui EXISTE. Concatener a l'aveugle laissait une ligne
	-- qui commencait par le separateur, sans rien devant (banc du 2026-09-20).
	local lieu = {}
	if d.arene and d.arene ~= "" then table.insert(lieu, tostring(d.arene)) end
	if d.decor and d.decor ~= "" then table.insert(lieu, tostring(d.decor)) end
	if #lieu > 0 then
		table.insert(lignes, table.concat(lieu, "  ·  "))
	end
	table.insert(lignes, "Code : " .. Partage.code(d))
	return table.concat(lignes, "\n")
end

-- Ce qu'on ecrit sur le bouton : il SELECTIONNE le texte (un jeu Roblox ne peut pas ecrire dans
-- le presse-papier). Le dire evite de promettre une copie qui n'arrive pas.
function Partage.libelleBouton()
	return "Selectionner pour copier"
end

return Partage
