-- BATIMENTS POSES : tours de defense, collecteurs d'elixir, invocateurs.
--
-- Pourquoi ce module existe : le jeu n'avait QUE des unites qui marchent. Impossible de tenir une
-- voie, de detourner un tank (une unite anti-tours fonce sur le batiment le plus proche), ni
-- d'investir son elixir pour en gagner plus tard. Trois piliers du genre manquaient d'un coup.
--
-- Regle cardinale d'equilibre : un batiment MEURT TOUT SEUL. Il perd des points de vie en continu
-- et disparait a la fin de sa duree de vie. Sans cela, poser un batiment serait gratuit : il
-- resterait la toute la partie.
--
-- Fonctions PURES (tools/test_batiments.py). Le serveur pose, dessine, et applique.
local Batiments = {}

Batiments.DUREE_MIN, Batiments.DUREE_MAX = 10, 90
-- Distance minimale entre deux batiments : sans elle, on empile trois collecteurs sur le meme
-- stud et la separation de foule les fait trembler a jamais.
Batiments.ECART_MINIMAL = 4
-- Bande interdite autour de la riviere : un batiment pose sur le pont bouchait le seul passage.
Batiments.BANDE_RIVIERE = 5

function Batiments.est(carte)
	return carte ~= nil and carte.batiment ~= nil
end

function Batiments.duree(carte)
	local b = carte and carte.batiment
	local d = tonumber(b and b.duree) or Batiments.DUREE_MIN
	return math.clamp(d, Batiments.DUREE_MIN, Batiments.DUREE_MAX)
end

-- PERTE DE VIE CONTINUE, en PV par seconde : les points de vie sont etales sur la duree de vie.
-- Ainsi un batiment tient exactement le temps annonce sur la carte quand personne ne le frappe.
function Batiments.usure(carte, pvMax)
	local d = Batiments.duree(carte)
	if d <= 0 then
		return 0
	end
	return (tonumber(pvMax) or 0) / d
end

-- POSE PERMISE ? Sa propre moitie (comme une unite), jamais sur la riviere, et pas colle a un
-- autre batiment. `autres` : liste de { x = n, z = n } des batiments deja poses du meme camp.
function Batiments.posePermise(camp, x, z, autres)
	local s = camp == 1 and -1 or 1
	if z * s < Batiments.BANDE_RIVIERE then
		return false -- sa moitie seulement, et pas la bande de la riviere
	end
	for _, a in ipairs(autres or {}) do
		local dx, dz = a.x - x, a.z - z
		if math.sqrt(dx * dx + dz * dz) < Batiments.ECART_MINIMAL then
			return false
		end
	end
	return true
end

-- ===== COLLECTEUR D'ELIXIR =====
-- Il rend `gain` elixir toutes les `periode` secondes. Le RENDEMENT total doit rester superieur
-- au cout de la carte, sinon personne ne le joue — mais de peu, sinon il n'y a plus que lui.
function Batiments.rendement(carte)
	local b = carte and carte.batiment
	if not b or b.type ~= "collecteur" then
		return 0
	end
	local periode = math.max(tonumber(b.periode) or 1, 0.1)
	return (tonumber(b.gain) or 0) * (Batiments.duree(carte) / periode)
end

-- Gain NET du collecteur sur sa vie entiere (ce qu'il rapporte moins ce qu'il a coute).
function Batiments.gainNet(carte)
	return Batiments.rendement(carte) - (tonumber(carte and carte.cost) or 0)
end

-- ===== PRODUCTION PERIODIQUE (collecteur ET invocateur) =====
-- Combien de fois le batiment a-t-il produit entre deux appels ? Rend le nombre de cycles echus et
-- met a jour l'etat. Compte par PALIERS (et non par regle de trois) pour qu'une image longue ne
-- fasse pas apparaitre trois unites d'un coup sans rien dessiner.
function Batiments.produire(etat, carte, maintenant)
	local b = carte and carte.batiment
	if not b or not etat then
		return 0
	end
	local periode = math.max(tonumber(b.periode) or 0, 0.1)
	if (tonumber(b.gain) or 0) <= 0 and (b.invoque == nil) then
		return 0
	end
	etat.prochain = etat.prochain or ((etat.poseT or maintenant or 0) + periode)
	local n = 0
	while (maintenant or 0) >= etat.prochain and n < 10 do
		n = n + 1
		etat.prochain = etat.prochain + periode
	end
	return n
end

-- ===== FIN DE VIE =====
-- Points de vie RESTANTS d'un batiment jamais attaque, `ecoule` secondes apres la pose.
function Batiments.pvRestants(carte, pvMax, ecoule)
	local max = tonumber(pvMax) or 0
	local reste = max - Batiments.usure(carte, max) * math.max(0, tonumber(ecoule) or 0)
	return math.max(0, reste)
end

function Batiments.expire(carte, ecoule)
	return (tonumber(ecoule) or 0) >= Batiments.duree(carte)
end

-- Un batiment pose ne donne JAMAIS de couronne a l'adversaire : seules les tours du depart
-- comptent. Sert au serveur, qui compte les couronnes sur les tours de `teams[camp].towers`.
function Batiments.donneCouronne()
	return false
end

return Batiments
