-- BILAN DE FIN DE MATCH, en fonctions PURES.
--
-- Pourquoi : l'ecran de fin ne disait qu'un mot (« VICTOIRE ! »). Un joueur qui perdait ne savait
-- PAS pourquoi, et un joueur qui gagnait n'apprenait rien. Or les trois chiffres qui expliquent
-- presque toutes les defaites de ce genre de jeu sont mesurables :
--   1. L'ELIXIR GASPILLE : celui qui deborde du plafond pendant qu'on ne joue pas. C'est la faute
--      n^o 1 des debutants, et rien ne la leur montrait.
--   2. LES DEGATS AUX TOURS : ce qu'on a reellement fait passer, au-dela des couronnes.
--   3. CE QU'ON A JOUE : combien de cartes, pour quel cout moyen — un deck lourd mal joue se voit la.
--
-- Le serveur ne fait qu'APPELER ces fonctions ; tout le calcul est ici, donc verifiable hors
-- Studio (tools/test_bilan.py).
local Bilan = {}

function Bilan.neuf()
	return { gaspille = 0, depense = 0, cartes = 0, degatsTours = 0, couronnes = 0 }
end

-- GASPILLAGE : la part de la regeneration qui n'a PAS pu entrer dans la jauge (elle etait pleine).
-- `gain` = ce que la regeneration voulait donner, `applique` = ce qui est reellement entre.
function Bilan.gaspiller(b, gain, applique)
	if not b then
		return
	end
	local perdu = (gain or 0) - (applique or 0)
	if perdu > 0 then
		b.gaspille = b.gaspille + perdu
	end
end

function Bilan.jouer(b, cout)
	if not b then
		return
	end
	b.cartes = b.cartes + 1
	b.depense = b.depense + (cout or 0)
end

-- DEGATS AUX TOURS DE DEPART seulement : un canon pose ou une unite abattue ne disent rien de la
-- pression mise sur l'adversaire.
function Bilan.degatsTour(b, montant)
	if not b or (montant or 0) <= 0 then
		return
	end
	b.degatsTours = b.degatsTours + montant
end

-- COUT MOYEN des cartes reellement jouees (0 si aucune) : dit si le joueur a sorti du lourd ou du
-- leger, sans dependre du deck declare.
function Bilan.coutMoyen(b)
	if not b or b.cartes == 0 then
		return 0
	end
	return b.depense / b.cartes
end

-- LA PHRASE QUI SERT A PROGRESSER. Une seule, la plus utile, jamais une liste de reproches.
-- Les seuils sont en ELIXIR gaspille, c'est-a-dire en cartes perdues (une carte coute 2 a 6).
Bilan.GASPILLAGE_GRAVE = 12
Bilan.GASPILLAGE_NOTABLE = 6
Bilan.TROP_COURTE = "Partie trop courte pour juger ton jeu."
function Bilan.conseil(b, adverse)
	if not b then
		return nil
	end
	-- AUCUNE CARTE JOUEE (abandon adverse immediat, partie tres courte) : rien a juger. Le
	-- compliment « Bonne gestion » tombait sur un bilan vide (capture pleins-fin.png, 2026-09-21).
	if (b.cartes or 0) == 0 and (b.gaspille or 0) < Bilan.GASPILLAGE_GRAVE then
		return Bilan.TROP_COURTE
	end
	if b.gaspille >= Bilan.GASPILLAGE_GRAVE then
		return string.format("Tu as laisse deborder %d elixir : joue plus souvent, meme petit.",
			math.floor(b.gaspille))
	end
	if adverse and b.degatsTours == 0 and (adverse.degatsTours or 0) > 0 then
		return "Aucun degat sur ses tours : il faut aussi attaquer pour gagner."
	end
	if adverse and Bilan.coutMoyen(b) >= Bilan.coutMoyen(adverse) + 1.5 then
		return "Tes cartes coutent bien plus cher que les siennes : il te prend de vitesse."
	end
	if b.gaspille >= Bilan.GASPILLAGE_NOTABLE then
		return string.format("%d elixir gaspille : surveille ta jauge quand elle est pleine.",
			math.floor(b.gaspille))
	end
	return "Bonne gestion de l'elixir."
end

-- GASPILLAGE EN DIRECT ---------------------------------------------------------------------------
-- Le bilan de fin arrive TROP TARD pour corriger quoi que ce soit. La faute n^o 1 du debutant se
-- corrige pendant qu'il la commet : la jauge est pleine, l'elixir tombe a cote, et il ne le voit
-- pas parce qu'une jauge pleine ressemble a une bonne nouvelle.
Bilan.SEUIL_VISIBLE = 1   -- en dessous d'un elixir perdu, on ne dit rien (bruit inutile)
Bilan.SEUIL_ROUGE = 6     -- au-dela, ce n'est plus un accident : c'est une habitude

-- Rend le texte a afficher, ou nil. On ne parle QUE quand la jauge deborde : hors de ce moment,
-- rappeler un gaspillage passe ne sert a rien et culpabilise pour rien.
function Bilan.alerteGaspillage(gaspille, jaugePleine)
	if not jaugePleine then
		return nil
	end
	local g = math.floor((gaspille or 0) + 0.5)
	if g < Bilan.SEUIL_VISIBLE then
		return "JAUGE PLEINE — joue une carte"
	end
	return string.format("JAUGE PLEINE — %d elixir perdu%s", g, g > 1 and "s" or "")
end

-- Gravite, pour la couleur : « leger » tant que ca reste un accident, « grave » ensuite.
function Bilan.niveauGaspillage(gaspille)
	if (gaspille or 0) >= Bilan.SEUIL_ROUGE then
		return "grave"
	end
	return "leger"
end

-- VUE ENVOYEE AU CLIENT : des nombres deja arrondis, pour que l'affichage n'invente rien.
function Bilan.vue(b)
	if not b then
		return nil
	end
	return {
		gaspille = math.floor(b.gaspille + 0.5),
		depense = math.floor(b.depense + 0.5),
		cartes = b.cartes,
		degatsTours = math.floor(b.degatsTours + 0.5),
		coutMoyen = math.floor(Bilan.coutMoyen(b) * 10 + 0.5) / 10,
	}
end

-- COUT MOYEN LISIBLE : sans carte jouee il n'existe pas. « 0.0 » laissait croire a des cartes
-- gratuites (capture bilan-vide.png, 2026-09-21) : on ecrit un tiret, aligne sur 5 caracteres.
function Bilan.texteCout(vue)
	if not vue or (vue.cartes or 0) == 0 then
		return "    -"
	end
	return string.format("%5.1f", vue.coutMoyen or 0)
end

return Bilan
