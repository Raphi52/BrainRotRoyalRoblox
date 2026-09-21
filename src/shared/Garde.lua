-- DERNIERE GARDE : le sursaut de la tour du Roi quand il ne reste plus qu'elle.
--
-- Defaut MESURE le 2026-09-20, serie de 20 parties a niveaux egaux, robots aguerris :
--     15 parties sur 20 se terminent AVANT la fin du temps, c'est-a-dire par la chute du Roi.
--     Temps restant a la fin : 106, 70, 60, 59, 58, 55, 53, 38, 19, 10, 9, 8, 6, 5, 4, puis
--     cinq parties au temps mort.
-- Trois parties sur quatre finissent donc en KO. Ce n'est pas une partie serree qui bascule :
-- c'est une partie qui s'arrete. Une fois les deux tours de princesse tombees, plus rien ne
-- ralentit l'attaquant — le Roi tire moins loin (12 contre 14) et pas plus vite, et il tombe.
-- Le camp mene n'a aucun moment pour se refaire, et celui qui mene n'a plus rien a jouer.
--
-- La regle ici ne donne AUCUN point de vie et ne change AUCUN degat : elle accelere la CADENCE
-- du Roi, et seulement quand ses deux tours de princesse sont tombees. Trois raisons de choisir
-- la cadence plutot que les points de vie :
--   * des points de vie en plus allongeraient toutes les parties sans rien rendre lisible ;
--   * des degats en plus tueraient d'un coup des unites qui passaient avant, ce qui change des
--     echanges deja regles ailleurs (Frappe) ;
--   * la cadence SE VOIT et s'entend — le Roi se met a tirer vite, le joueur comprend que la
--     derniere garde a commence, et l'attaquant sait qu'il doit finir.
--
-- Bornes : le sursaut est PLAFONNE (FACTEUR_MAX) et il ne s'applique jamais a une tour de
-- princesse ni a un batiment pose. Il n'y a pas de duree : il dure tant que la situation dure,
-- et il disparait si le camp recupere une tour (ce qui n'arrive pas aujourd'hui, mais la regle
-- ne doit pas dependre de cette absence).
--
-- Fonctions pures, verifiees hors Studio (tools/test_garde.py) ; le serveur applique.
local Garde = {}

-- Multiplicateur de cadence du Roi en derniere garde. 1,5 = il tire une fois et demie plus
-- souvent. Choisi pour compenser la portee moindre du Roi (12 contre 14) sans en faire une
-- forteresse : a 1,5 il rend environ ce qu'une tour de princesse apportait en presence, pas les
-- deux qu'il a perdues.
Garde.FACTEUR = 1.5
Garde.FACTEUR_MAX = 2 -- borne dure : au-dela, le Roi seul defendrait mieux que trois tours

-- La derniere garde est-elle engagee pour ce camp ?
-- `tours` : liste de { estRoi, vivante }. Vrai quand le Roi est encore debout et qu'AUCUNE tour
-- de princesse ne l'est plus. Un camp sans Roi n'a plus de garde : la partie est finie.
function Garde.engagee(tours)
	if type(tours) ~= "table" then
		return false
	end
	local roiVivant, princesseVivante = false, false
	for _, t in ipairs(tours) do
		if t and t.vivante ~= false then
			if t.estRoi then
				roiVivant = true
			else
				princesseVivante = true
			end
		end
	end
	return roiVivant and not princesseVivante
end

-- Facteur de cadence a appliquer a UNE tour donnee, selon l'etat de son camp.
-- Rend 1 pour tout ce qui n'est pas le Roi en derniere garde : la regle ne deborde jamais.
function Garde.facteur(tour, tours)
	if not tour or tour.estRoi ~= true then
		return 1
	end
	if tour.vivante == false then
		return 1
	end
	if not Garde.engagee(tours) then
		return 1
	end
	return math.clamp(Garde.FACTEUR, 1, Garde.FACTEUR_MAX)
end

-- DELAI entre deux tirs, une fois la garde appliquee. On divise le delai par le facteur : tirer
-- 1,5 fois plus souvent, c'est attendre 1,5 fois moins longtemps.
-- Le delai rendu n'est jamais nul ni negatif, meme si on lui passe n'importe quoi.
function Garde.delai(delaiBase, facteur)
	local d = tonumber(delaiBase) or 0
	local f = math.clamp(tonumber(facteur) or 1, 1, Garde.FACTEUR_MAX)
	if d <= 0 then
		return 0
	end
	return d / f
end

-- CE QU'ON EN DIT AU JOUEUR.
--
-- Defaut mesure le 2026-09-21 : la regle EXISTE et change les combats (le Roi tire 1,5 fois plus
-- vite), mais elle n'etait NULLE PART a l'ecran — seulement dans un journal serveur. L'attaquant
-- voit son unite fondre sans comprendre, le defenseur ne sait pas qu'il vient de gagner un sursis.
-- Le commentaire en tete de ce module dit « la cadence SE VOIT » : elle se voit, mais elle ne se
-- COMPREND pas tant que rien ne la nomme.
function Garde.titre(pourMoi)
	if pourMoi then
		return "DERNIERE GARDE : ton Roi defend plus vite"
	end
	return "DERNIERE GARDE ADVERSE : son Roi defend plus vite"
end

-- Ligne courte affichee tant que la garde dure, avec le chiffre reel : le joueur doit pouvoir
-- decider s'il pousse ou s'il attend, pas seulement savoir que « quelque chose a change ».
function Garde.mention(pourMoi)
	local qui = pourMoi and "Ton Roi" or "Son Roi"
	-- Le facteur est ecrit a la virgule (convention FR des ecrans du jeu).
	return qui .. " tire x" .. string.gsub(tostring(Garde.FACTEUR), "%.", ",") .. " plus vite"
end

-- COULEUR du bandeau : ma garde rassure (or), celle d'en face avertit (rouge).
function Garde.teinte(pourMoi)
	if pourMoi then
		return { 255, 205, 90 }
	end
	return { 255, 120, 110 }
end

return Garde
