-- FORMES LISSES pour les brainrots dessines sans modele 3D, en fonctions PURES.
--
-- Constat du 2026-09-21 : 11 des 28 brainrots (Ballerina, Glorbo, Bombombini, Cocofanto, Zibra,
-- Orcalero, Nuclearo, Frulli, Spaghettino, Trulimero, Bicus) n'ont AUCUN modele 3D dans la
-- Boutique Roblox — ni avec ni sans script, et aucun remplacant celebre n'en a non plus (recherche
-- sur 40 noms, tools/boutique/candidats/). Ils etaient donc assembles en BLOCS a aretes vives :
-- le rendu « cubique » que l'utilisateur ne veut plus voir.
--
-- Ici on ne touche PAS au catalogue (les tailles et positions de chaque morceau restent celles de
-- Cards.lua) : on decide seulement de la FORME dans laquelle chaque morceau est rendu. Un bloc
-- devient un ELLIPSOIDE de memes dimensions (maillage sphere mis a l'echelle de la piece), ce qui
-- garde la silhouette voulue tout en supprimant les aretes.
--
-- Deux exceptions, toutes deux mesurables :
--   * une forme DEJA declaree (boule, cylindre) est respectee : l'auteur l'a choisie ;
--   * une PLAQUE (piece tres fine : aile, nageoire, lame) reste un bloc lisse. Un ellipsoide tres
--     plat se reduit a une ligne vue de profil et la piece disparaitrait a l'ecran.
local Arrondi = {}

-- Sous ce rapport entre la plus petite et la plus grande dimension, la piece est une PLAQUE.
Arrondi.RATIO_PLAQUE = 0.22

-- Forme de rendu d'un morceau : "declaree" (on garde celle du catalogue), "plaque" ou "ellipsoide".
function Arrondi.forme(taille, formeDeclaree)
	if formeDeclaree ~= nil then
		return "declaree"
	end
	if not taille then
		return "ellipsoide"
	end
	local x, y, z = tonumber(taille.X) or 0, tonumber(taille.Y) or 0, tonumber(taille.Z) or 0
	local grand = math.max(x, y, z)
	local petit = math.min(x, y, z)
	if grand > 0 and petit / grand < Arrondi.RATIO_PLAQUE then
		return "plaque"
	end
	return "ellipsoide"
end

-- Le lissage s'applique-t-il a cette carte ? A toute UNITE dessinee faute de modele : les
-- brainrots d'abord, puis (2026-09-21) les sept unites qui n'en sont pas — Scudo Banana, Dottore
-- Pizza, Bomba Salsiccia, Regina Ghiaccio, Serpente Veleno, Aquila Frizzante, Minatore Mozzarella.
-- Elles restaient les dernieres a se deplacer en blocs dans une arene devenue ronde.
-- Les BATIMENTS et les SORTS gardent leur dessin : un canon ou un mur sont angulaires par nature.
function Arrondi.applicable(carte, aUnModele)
	if not carte or aUnModele then
		return false
	end
	return carte.sort == nil and carte.batiment == nil
end

-- MODELES ECARTES : ces six brainrots ONT un modele dans la Boutique, mais il est lui-meme en
-- BLOCS (style voxel) — verifie sur les apercus le 2026-09-21 (tools/boutique/planche-actuels.png).
-- Pour eux, le rendu lisse de leurs morceaux est plus proche du rendu premium voulu que le modele.
-- Liste explicite et non deduite : juger « en blocs » demande de REGARDER l'apercu, ce qu'aucune
-- mesure des pieces ne fait de facon fiable (Giraffa a 22 pieces, Tralaleritos une seule).
-- Les modeles restent dans tools/boutique/modeles.json : retirer un nom de cette liste les remet.
Arrondi.MODELES_EN_BLOCS = {
	Trippi = true, Frigo = true, Giraffa = true,
	Tralaleritos = true, Tigrullini = true, Bananita = true,
}

-- Le modele de la Boutique est-il RETENU pour cette carte ? Faux pour un modele en blocs.
function Arrondi.modeleRetenu(id)
	return Arrondi.MODELES_EN_BLOCS[id] ~= true
end

return Arrondi
