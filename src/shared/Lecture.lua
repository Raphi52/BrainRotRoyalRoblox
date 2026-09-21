-- LIRE LA PARTIE : ce que le joueur doit pouvoir savoir de son adversaire, en fonctions PURES.
--
-- Trois manques mesures dans l'audit PvP :
--  1. AUCUNE IDEE DE L'ELIXIR D'EN FACE. C'est pourtant la seule question qui decide d'une
--     contre-attaque : « peut-il encore repondre ? ». Sans repere, on pousse au hasard.
--  2. AUCUNE TRACE DE CE QU'IL A JOUE. Compter le cycle adverse est le coeur du genre ; le jeu
--     n'en gardait rien, donc personne ne pouvait anticiper le retour de sa carte cle.
--  3. AUCUNE ALERTE SUR SES PROPRES TOURS. Une tour tombait pendant qu'on regardait l'autre voie.
--
-- CHOIX ASSUME : l'elixir adverse est une ESTIMATION construite sur du VISIBLE (le temps ecoule et
-- les cartes qu'on a vu poser), jamais une lecture de son compteur reel. Elle derive donc quand il
-- pose hors de vue d'un joueur distrait — c'est voulu, la lecture reste une competence.
local Lecture = {}

Lecture.MAX_ELIXIR = 10
Lecture.CARTES_VUES = 4 -- combien de cartes adverses on garde a l'ecran

-- ESTIMATION D'ELIXIR : depart + ce que la regeneration a rendu - ce qu'on l'a vu depenser.
-- Bornee entre 0 et le plafond, arrondie VERS LE BAS : on ne promet jamais plus que le certain.
function Lecture.elixirEstime(depart, regenCumulee, depenseVue)
	local e = (depart or 0) + (regenCumulee or 0) - (depenseVue or 0)
	return math.max(0, math.min(Lecture.MAX_ELIXIR, math.floor(e)))
end

-- PEUT-IL REPONDRE ? Vrai si l'estimation suffit a payer une carte de ce cout.
function Lecture.peutRepondre(estimation, cout)
	return (estimation or 0) >= (cout or 0)
end

-- LES DERNIERES CARTES VUES, la plus recente EN TETE. `jouees` est la liste chronologique
-- { id = ..., t = ... } tenue par le serveur ; on n'en rend que les dernieres.
function Lecture.dernieresCartes(jouees, combien)
	local n = combien or Lecture.CARTES_VUES
	local l = {}
	for i = #(jouees or {}), 1, -1 do
		if #l >= n then
			break
		end
		table.insert(l, jouees[i])
	end
	return l
end

-- CETTE CARTE EST-ELLE DEJA PASSEE ? Rend le nombre de fois qu'on l'a vue.
function Lecture.dejaVue(jouees, id)
	local n = 0
	for _, c in ipairs(jouees or {}) do
		if c.id == id then
			n = n + 1
		end
	end
	return n
end

-- MARQUE AFFICHEE A COTE D'UNE CARTE ADVERSE DEJA VUE.
--
-- Defaut mesure le 2026-09-21 : le panneau listait les dernieres cartes posees par l'adversaire,
-- mais toutes se lisaient pareil. Or une carte vue DEUX fois dit quelque chose de precis : son
-- deck tourne, elle va revenir vite, et il a d'autant moins de surprises en reserve. Le compte
-- existait dans le code (Lecture.dejaVue) et n'etait affiche NULLE PART — personne ne l'appelait.
--
-- Rend une chaine vide au premier passage : marquer « x1 » partout n'apprendrait rien et
-- salirait les quatre lignes.
function Lecture.marqueVue(n)
	local c = math.floor(tonumber(n) or 0)
	if c < 2 then
		return ""
	end
	return " x" .. c
end

-- ALERTE SUR UNE TOUR. Deux causes, et la plus grave l'emporte :
--   - elle est BASSE (part de points de vie restants) ;
--   - elle ENCAISSE fort en ce moment (degats des dernieres secondes, en part de son maximum).
-- Rend nil, "attention" ou "critique". Une tour morte ne declenche plus rien.
Lecture.SEUIL_BAS = 0.5       -- moitie de vie : attention
Lecture.SEUIL_CRITIQUE = 0.25 -- quart de vie : critique
Lecture.COUP_DUR = 0.12       -- 12 % de sa vie encaissee dans la fenetre : critique
Lecture.FENETRE = 3           -- secondes de la fenetre de degats
function Lecture.alerteTour(vivante, pv, pvMax, degatsRecents)
	if not vivante or (pvMax or 0) <= 0 then
		return nil
	end
	local part = math.max(0, (pv or 0)) / pvMax
	local coup = (degatsRecents or 0) / pvMax
	if part <= Lecture.SEUIL_CRITIQUE or coup >= Lecture.COUP_DUR then
		return "critique"
	end
	if part <= Lecture.SEUIL_BAS or coup > 0 then
		return "attention"
	end
	return nil
end

-- ETAT DE SANTE D'UNE TOUR, POUR L'AFFICHAGE. Defaut mesure le 2026-09-20 : la barre au-dessus
-- d'une tour etait une bande unie qui raccourcit. Rien n'y marquait les SEUILS qui decident
-- pourtant du jeu (l'alerte se declenche a la moitie, puis au quart), et aucun chiffre ne disait
-- ou en etait la tour : « elle tient encore ? » se jugeait a l'oeil, sur trois pixels.
-- Les memes constantes servent a l'alerte et a l'affichage : la barre ne peut pas dire autre
-- chose que ce que le jeu fait.
Lecture.SEUILS_AFFICHES = { 0.5, 0.25 } -- traits marques sur la barre, du plus haut au plus bas

function Lecture.niveauVie(pv, pvMax)
	if (pvMax or 0) <= 0 then
		return "critique"
	end
	local part = math.max(0, (pv or 0)) / pvMax
	if part <= Lecture.SEUIL_CRITIQUE then
		return "critique"
	elseif part <= Lecture.SEUIL_BAS then
		return "bas"
	end
	return "sain"
end

-- Couleur du CHIFFRE de vie (la barre, elle, garde la couleur du camp : c'est elle qui dit a qui
-- appartient la tour, et la repeindre ferait perdre cette information).
function Lecture.teinteVie(niveau)
	if niveau == "critique" then
		return { 255, 90, 90 }
	elseif niveau == "bas" then
		return { 255, 195, 90 }
	end
	return { 120, 235, 150 }
end

-- « 52 % » : une part lisible, arrondie au plus proche, jamais negative ni au-dessus de 100.
function Lecture.texteVie(pv, pvMax)
	if (pvMax or 0) <= 0 then
		return "0 %"
	end
	local part = math.max(0, math.min(1, (pv or 0) / pvMax))
	return tostring(math.floor(part * 100 + 0.5)) .. " %"
end

-- L'ALERTE DU CAMP : la plus grave de ses tours, avec le COTE a regarder (« gauche », « droite »,
-- « roi »). Sans cote, le joueur cherche la menace au mauvais endroit — l'alerte serait un bruit
-- de plus. `tours` : { { vivante, pv, pvMax, degatsRecents, x, roi } }.
function Lecture.alerteCamp(tours)
	local rang = { attention = 1, critique = 2 }
	local pire, pireNiveau, pireCote = nil, 0, nil
	for _, t in ipairs(tours or {}) do
		local niveau = Lecture.alerteTour(t.vivante, t.pv, t.pvMax, t.degatsRecents)
		if niveau and rang[niveau] > pireNiveau then
			pire, pireNiveau = niveau, rang[niveau]
			pireCote = t.roi and "roi" or ((t.x or 0) < 0 and "gauche" or "droite")
		end
	end
	if not pire then
		return nil
	end
	return pire, pireCote
end

-- Phrase affichee, deduite du niveau et du cote (le client ne la compose pas lui-meme).
function Lecture.texteAlerte(niveau, cote)
	if not niveau then
		return nil
	end
	local ou = (cote == "roi") and "TA TOUR DU ROI" or ("TA TOUR " .. string.upper(cote or ""))
	if niveau == "critique" then
		return ou .. " VA TOMBER !"
	end
	return ou .. " est attaquee"
end

-- DEGATS RECENTS : somme des coups encore dans la fenetre. Le serveur empile { t, montant } ;
-- cette fonction rend la somme utile ET la liste nettoyee, pour qu'elle ne grossisse jamais.
function Lecture.degatsRecents(coups, maintenant, fenetre)
	local f = fenetre or Lecture.FENETRE
	local total, restants = 0, {}
	for _, c in ipairs(coups or {}) do
		if (maintenant - c.t) <= f then
			total = total + c.montant
			table.insert(restants, c)
		end
	end
	return total, restants
end

return Lecture
