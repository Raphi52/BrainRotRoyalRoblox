-- Cartes Italian Brainrot
--
-- `morceaux` = la SILHOUETTE du personnage : des blocs simples accroches au corps (ecart `pos`,
-- `taille`, `couleur`, `forme` parmi bloc/boule/cylindre, `rot` en degres). Le serveur les pose
-- dans `habiller` et les fait suivre le corps. Choix assume : geometrie faite ici plutot qu'un
-- modele importe du catalogue Roblox — aucun telechargement, aucun identifiant d'asset a
-- maintenir, et rien qui disparaisse si son auteur le retire.
-- targets : "any" (tout) ou "buildings" (tours uniquement)
-- Le cube `size` reste la zone de contact mais est INVISIBLE : les morceaux dessinent tout le
-- personnage (2026-09-14 : vu de loin, le cube colore dominait la silhouette).
-- echelle : grossit les morceaux (visuel seul, la zone de contact ne change pas).
-- hauteurModele / modeleRotY : hauteur visee (studs) et correction de rotation du modele de la Boutique.
-- prix : carte a debloquer en boutique (pieces). Sans prix, la carte est offerte des le depart.
-- range < 5 = melee : ne peut pas toucher les unites volantes
local Cards = {
	{
		id = "Tralalero", hauteurModele = 4.5, modeleRotY = 0, name = "Tralalero Tralala", cost = 3, echelle = 1,
		hp = 650, dmg = 95, range = 3.5, speed = 11, atkSpeed = 1.0, count = 1,
		color = Color3.fromRGB(70, 150, 255), size = Vector3.new(3, 3, 4),
		targets = "any", desc = "Requin en Nike, rapide et solide",
		morceaux = {
			{ pos = Vector3.new(0, 0.3, 0), taille = Vector3.new(2.6, 2.2, 4.6), couleur = Color3.fromRGB(70, 150, 255) },
			{ pos = Vector3.new(0, -0.3, -0.2), taille = Vector3.new(2.2, 1.2, 4), couleur = Color3.fromRGB(235, 240, 250) },
			{ pos = Vector3.new(0, 0.3, -2.6), taille = Vector3.new(2.4, 2, 1.8), forme = "boule", couleur = Color3.fromRGB(70, 150, 255) },
			{ pos = Vector3.new(0, -0.4, -2.9), taille = Vector3.new(1.8, 0.3, 1), couleur = Color3.fromRGB(255, 255, 255) },
			{ pos = Vector3.new(0, 2.3, 0.2), taille = Vector3.new(0.5, 2.4, 1.8), rot = Vector3.new(-20, 0, 0), couleur = Color3.fromRGB(50, 120, 230) },
			{ pos = Vector3.new(0, 0.9, 2.9), taille = Vector3.new(0.5, 2.4, 1.4), rot = Vector3.new(25, 0, 0), couleur = Color3.fromRGB(50, 120, 230) },
			{ pos = Vector3.new(-1.35, 0.8, -2.8), taille = Vector3.new(0.5, 0.5, 0.5), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(1.35, 0.8, -2.8), taille = Vector3.new(0.5, 0.5, 0.5), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.9, -1.7, -0.6), taille = Vector3.new(1.2, 0.9, 2.4), couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(0.9, -1.7, -0.6), taille = Vector3.new(1.2, 0.9, 2.4), couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(-1.52, -1.6, -0.6), taille = Vector3.new(0.1, 0.4, 1.6), couleur = Color3.fromRGB(255, 60, 60) },
			{ pos = Vector3.new(1.52, -1.6, -0.6), taille = Vector3.new(0.1, 0.4, 1.6), couleur = Color3.fromRGB(255, 60, 60) },
		},
	},
	{
		id = "Bombardiro", prix = 500, hauteurModele = 3.5, modeleRotY = 90, name = "Bombardiro Crocodilo", cost = 5,
		hp = 1100, dmg = 210, range = 3, speed = 8, atkSpeed = 2.0, count = 1,
		color = Color3.fromRGB(60, 120, 50), size = Vector3.new(5, 2, 4),
		targets = "buildings", flying = true, splash = 5, desc = "Bombardier volant, vise les tours",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2.2, 1.8, 5), couleur = Color3.fromRGB(80, 150, 70) },
			{ pos = Vector3.new(0, 0, -3.4), taille = Vector3.new(1.6, 1, 2.6), couleur = Color3.fromRGB(90, 165, 80) },
			{ pos = Vector3.new(-0.5, 0.6, -2.4), taille = Vector3.new(0.5, 0.5, 0.5), forme = "boule", couleur = Color3.fromRGB(255, 230, 80) },
			{ pos = Vector3.new(0.5, 0.6, -2.4), taille = Vector3.new(0.5, 0.5, 0.5), forme = "boule", couleur = Color3.fromRGB(255, 230, 80) },
			{ pos = Vector3.new(0, -0.45, -3.6), taille = Vector3.new(1.4, 0.15, 2), couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(-4, 0.2, 0), taille = Vector3.new(5.5, 0.4, 2.4), couleur = Color3.fromRGB(110, 120, 110), materiau = "Metal" },
			{ pos = Vector3.new(4, 0.2, 0), taille = Vector3.new(5.5, 0.4, 2.4), couleur = Color3.fromRGB(110, 120, 110), materiau = "Metal" },
			{ pos = Vector3.new(-2.6, -0.6, -0.3), taille = Vector3.new(2.4, 1, 1), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(60, 60, 65), materiau = "Metal" },
			{ pos = Vector3.new(2.6, -0.6, -0.3), taille = Vector3.new(2.4, 1, 1), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(60, 60, 65), materiau = "Metal" },
			{ pos = Vector3.new(0, 1.2, 2.4), taille = Vector3.new(0.3, 1.8, 1.2), couleur = Color3.fromRGB(80, 150, 70) },
			{ pos = Vector3.new(0, 0.3, 2.8), taille = Vector3.new(3, 0.3, 1), couleur = Color3.fromRGB(110, 120, 110), materiau = "Metal" },
			{ pos = Vector3.new(0, -1.3, 0.3), taille = Vector3.new(1.8, 0.8, 0.8), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(40, 40, 40), materiau = "Metal" },
		},
	},
	{
		id = "TungSahur", hauteurModele = 6, modeleRotY = 0, name = "Tung Tung Tung Sahur", cost = 4,
		hp = 950, dmg = 120, range = 3.5, speed = 8, atkSpeed = 1.2, count = 1,
		color = Color3.fromRGB(150, 100, 60), size = Vector3.new(2, 6, 2),
		targets = "any", splash = 3, desc = "Coup de batte en zone",
		morceaux = {
			{ pos = Vector3.new(0, 0.3, 0), taille = Vector3.new(5, 2.2, 2.2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(195, 150, 100), materiau = "Wood" },
			{ pos = Vector3.new(-0.5, 1.6, -1.05), taille = Vector3.new(0.6, 0.6, 0.6), forme = "boule", couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(0.5, 1.6, -1.05), taille = Vector3.new(0.6, 0.6, 0.6), forme = "boule", couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(-0.5, 1.6, -1.3), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.5, 1.6, -1.3), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 0.7, -1.12), taille = Vector3.new(1.2, 0.25, 0.1), couleur = Color3.fromRGB(60, 30, 20) },
			{ pos = Vector3.new(1.5, 0.8, 0), taille = Vector3.new(0.5, 2.2, 0.5), rot = Vector3.new(0, 0, 40), couleur = Color3.fromRGB(170, 125, 80) },
			{ pos = Vector3.new(-1.5, 0.8, 0), taille = Vector3.new(0.5, 2.2, 0.5), rot = Vector3.new(0, 0, -40), couleur = Color3.fromRGB(170, 125, 80) },
			{ pos = Vector3.new(2.8, 2.6, 0), taille = Vector3.new(4.2, 0.9, 0.9), forme = "cylindre", rot = Vector3.new(0, 0, 35), couleur = Color3.fromRGB(110, 75, 45), materiau = "Wood" },
			{ pos = Vector3.new(-0.6, -2.8, 0), taille = Vector3.new(0.6, 1.4, 0.6), couleur = Color3.fromRGB(170, 125, 80) },
			{ pos = Vector3.new(0.6, -2.8, 0), taille = Vector3.new(0.6, 1.4, 0.6), couleur = Color3.fromRGB(170, 125, 80) },
		},
	},
	{
		id = "Patapim", prix = 800, hauteurModele = 6.5, modeleRotY = 0, name = "Brr Brr Patapim", cost = 5,
		hp = 2200, dmg = 120, range = 3, speed = 5.5, atkSpeed = 1.5, count = 1,
		color = Color3.fromRGB(40, 90, 30), size = Vector3.new(5, 5, 5),
		targets = "buildings", desc = "Tank foret, fonce sur les tours",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(4.4, 4, 4), couleur = Color3.fromRGB(70, 120, 50), materiau = "Grass" },
			{ pos = Vector3.new(0, 1, -2.2), taille = Vector3.new(3.6, 2.4, 1), couleur = Color3.fromRGB(200, 170, 140) },
			{ pos = Vector3.new(-0.8, 0.6, -3), taille = Vector3.new(1.3, 1.3, 1.3), forme = "boule", couleur = Color3.fromRGB(215, 180, 150) },
			{ pos = Vector3.new(0.8, 0.6, -3), taille = Vector3.new(1.3, 1.3, 1.3), forme = "boule", couleur = Color3.fromRGB(215, 180, 150) },
			{ pos = Vector3.new(-1, 2.2, -2.75), taille = Vector3.new(0.6, 0.6, 0.6), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(1, 2.2, -2.75), taille = Vector3.new(0.6, 0.6, 0.6), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 3.1, -0.4), taille = Vector3.new(4, 0.6, 3), couleur = Color3.fromRGB(40, 25, 15) },
			{ pos = Vector3.new(-1.4, 4, 0.6), taille = Vector3.new(0.5, 3, 0.5), rot = Vector3.new(0, 0, -25), couleur = Color3.fromRGB(90, 60, 35), materiau = "Wood" },
			{ pos = Vector3.new(1.4, 4.2, 0.2), taille = Vector3.new(0.5, 3.4, 0.5), rot = Vector3.new(0, 0, 20), couleur = Color3.fromRGB(90, 60, 35), materiau = "Wood" },
			{ pos = Vector3.new(0, 5.2, 0.4), taille = Vector3.new(3, 3, 3), forme = "boule", couleur = Color3.fromRGB(50, 140, 45), materiau = "Grass" },
			{ pos = Vector3.new(-1.2, -2.5, 0), taille = Vector3.new(1.2, 1.2, 1.6), couleur = Color3.fromRGB(90, 60, 35) },
			{ pos = Vector3.new(1.2, -2.5, 0), taille = Vector3.new(1.2, 1.2, 1.6), couleur = Color3.fromRGB(90, 60, 35) },
		},
	},
	{
		id = "Cappuccino", hauteurModele = 5.5, modeleRotY = 0, name = "Cappuccino Assassino", cost = 2,
		hp = 320, dmg = 130, range = 3, speed = 16, atkSpeed = 0.8, count = 1,
		color = Color3.fromRGB(110, 70, 40), size = Vector3.new(2, 3, 2),
		targets = "any", desc = "Assassin ultra rapide",
		morceaux = {
			{ pos = Vector3.new(0, 0.2, 0), taille = Vector3.new(2.6, 2, 2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(245, 240, 230) },
			{ pos = Vector3.new(0, 1.5, 0), taille = Vector3.new(0.2, 1.9, 1.9), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(120, 75, 40) },
			{ pos = Vector3.new(0, 1.75, 0), taille = Vector3.new(1.6, 1.6, 1.6), forme = "boule", couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(1.3, 0.2, 0), taille = Vector3.new(0.4, 1.4, 1), couleur = Color3.fromRGB(245, 240, 230) },
			{ pos = Vector3.new(0, 0.6, -1.02), taille = Vector3.new(2.05, 0.6, 0.1), couleur = Color3.fromRGB(30, 30, 40) },
			{ pos = Vector3.new(-0.4, 0.6, -1.1), taille = Vector3.new(0.35, 0.25, 0.1), couleur = Color3.fromRGB(255, 60, 60) },
			{ pos = Vector3.new(0.4, 0.6, -1.1), taille = Vector3.new(0.35, 0.25, 0.1), couleur = Color3.fromRGB(255, 60, 60) },
			{ pos = Vector3.new(-1.4, 0, -0.4), taille = Vector3.new(0.2, 1.6, 0.5), rot = Vector3.new(30, 0, 0), couleur = Color3.fromRGB(200, 200, 210), materiau = "Metal" },
			{ pos = Vector3.new(1.4, 0, -0.4), taille = Vector3.new(0.2, 1.6, 0.5), rot = Vector3.new(30, 0, 0), couleur = Color3.fromRGB(200, 200, 210), materiau = "Metal" },
			{ pos = Vector3.new(-0.5, -1.6, 0), taille = Vector3.new(0.5, 0.8, 1.2), couleur = Color3.fromRGB(40, 40, 50) },
			{ pos = Vector3.new(0.5, -1.6, 0), taille = Vector3.new(0.5, 0.8, 1.2), couleur = Color3.fromRGB(40, 40, 50) },
		},
	},
	{
		id = "Chimpanzini", hauteurModele = 4.5, modeleRotY = 180, name = "Chimpanzini Bananini", cost = 3,
		hp = 220, dmg = 60, range = 3, speed = 14, atkSpeed = 0.7, count = 3,
		color = Color3.fromRGB(240, 220, 60), size = Vector3.new(2, 2, 2),
		targets = "any", desc = "Trois singes-bananes",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2.6, 1.8, 1.8), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(250, 220, 60) },
			{ pos = Vector3.new(-1, 0.9, 0), taille = Vector3.new(0.4, 1.8, 0.8), rot = Vector3.new(0, 0, 35), couleur = Color3.fromRGB(250, 225, 70) },
			{ pos = Vector3.new(1, 0.9, 0), taille = Vector3.new(0.4, 1.8, 0.8), rot = Vector3.new(0, 0, -35), couleur = Color3.fromRGB(250, 225, 70) },
			{ pos = Vector3.new(0, 1.6, 0), taille = Vector3.new(1.5, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(140, 95, 60) },
			{ pos = Vector3.new(0, 1.45, -0.6), taille = Vector3.new(0.8, 0.8, 0.8), forme = "boule", couleur = Color3.fromRGB(210, 170, 130) },
			{ pos = Vector3.new(-0.85, 1.7, 0), taille = Vector3.new(0.6, 0.6, 0.6), forme = "boule", couleur = Color3.fromRGB(170, 125, 85) },
			{ pos = Vector3.new(0.85, 1.7, 0), taille = Vector3.new(0.6, 0.6, 0.6), forme = "boule", couleur = Color3.fromRGB(170, 125, 85) },
			{ pos = Vector3.new(-0.3, 1.8, -0.7), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.3, 1.8, -0.7), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, -1.4, 0), taille = Vector3.new(0.5, 0.4, 0.5), couleur = Color3.fromRGB(90, 70, 30) },
		},
	},
	{
		id = "Lirili", hauteurModele = 5.5, modeleRotY = 90, name = "Lirili Larila", cost = 3, echelle = 1,
		hp = 560, dmg = 95, range = 11, speed = 7, atkSpeed = 1.3, count = 1,
		color = Color3.fromRGB(120, 200, 120), size = Vector3.new(3, 4, 3),
		targets = "any", desc = "Elephant-cactus a distance",
		morceaux = {
			{ pos = Vector3.new(0, 0.2, 0), taille = Vector3.new(2.6, 2.8, 2.4), couleur = Color3.fromRGB(120, 190, 110) },
			{ pos = Vector3.new(0, 1.8, -0.8), taille = Vector3.new(2, 1.8, 1.8), couleur = Color3.fromRGB(130, 200, 120) },
			{ pos = Vector3.new(0, 0.9, -2), taille = Vector3.new(0.7, 2.4, 0.7), rot = Vector3.new(35, 0, 0), couleur = Color3.fromRGB(120, 185, 110) },
			{ pos = Vector3.new(-1.5, 1.9, -0.6), taille = Vector3.new(0.3, 1.8, 1.6), couleur = Color3.fromRGB(110, 175, 105) },
			{ pos = Vector3.new(1.5, 1.9, -0.6), taille = Vector3.new(0.3, 1.8, 1.6), couleur = Color3.fromRGB(110, 175, 105) },
			{ pos = Vector3.new(-0.5, 2.2, -1.72), taille = Vector3.new(0.35, 0.35, 0.35), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.5, 2.2, -1.72), taille = Vector3.new(0.35, 0.35, 0.35), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.8, 3, 0), taille = Vector3.new(0.15, 0.8, 0.15), couleur = Color3.fromRGB(250, 245, 200) },
			{ pos = Vector3.new(0.6, 3.1, 0.4), taille = Vector3.new(0.15, 0.8, 0.15), couleur = Color3.fromRGB(250, 245, 200) },
			{ pos = Vector3.new(1.35, 0.6, 0.5), taille = Vector3.new(0.8, 0.15, 0.15), couleur = Color3.fromRGB(250, 245, 200) },
			{ pos = Vector3.new(0, 1.2, 1.25), taille = Vector3.new(0.3, 1.2, 1.2), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(240, 235, 200) },
			{ pos = Vector3.new(-0.7, -1.8, 0), taille = Vector3.new(0.8, 0.3, 1.2), couleur = Color3.fromRGB(150, 100, 60) },
			{ pos = Vector3.new(0.7, -1.8, 0), taille = Vector3.new(0.8, 0.3, 1.2), couleur = Color3.fromRGB(150, 100, 60) },
		},
	},
	{
		id = "Ballerina", hauteurModele = 5, modeleRotY = -90, name = "Ballerina Cappuccina", cost = 2,
		hp = 320, dmg = 70, range = 9, speed = 10, atkSpeed = 0.9, count = 1,
		color = Color3.fromRGB(255, 150, 200), size = Vector3.new(2, 4, 2),
		targets = "any", desc = "Tireuse legere a distance",
		morceaux = {
			{ pos = Vector3.new(0, 0.5, 0), taille = Vector3.new(1, 1.6, 0.8), couleur = Color3.fromRGB(250, 200, 215) },
			{ pos = Vector3.new(0, 2.2, 0), taille = Vector3.new(1.6, 1.7, 1.7), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(250, 245, 235) },
			{ pos = Vector3.new(0, 3.05, 0), taille = Vector3.new(0.15, 1.5, 1.5), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(120, 75, 40) },
			{ pos = Vector3.new(1.05, 2.2, 0), taille = Vector3.new(0.3, 1, 0.8), couleur = Color3.fromRGB(250, 245, 235) },
			{ pos = Vector3.new(-0.35, 2.3, -0.87), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.35, 2.3, -0.87), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, -0.3, 0), taille = Vector3.new(0.5, 3.6, 3.6), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(255, 150, 205) },
			{ pos = Vector3.new(0, -0.1, 0), taille = Vector3.new(0.4, 3, 3), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(255, 190, 225) },
			{ pos = Vector3.new(-1, 1.9, 0), taille = Vector3.new(0.3, 1.8, 0.3), rot = Vector3.new(0, 0, 30), couleur = Color3.fromRGB(250, 215, 225) },
			{ pos = Vector3.new(1, 1.9, 0), taille = Vector3.new(0.3, 1.8, 0.3), rot = Vector3.new(0, 0, -30), couleur = Color3.fromRGB(250, 215, 225) },
			{ pos = Vector3.new(-0.3, -1.4, 0), taille = Vector3.new(0.3, 1.4, 0.3), couleur = Color3.fromRGB(250, 215, 225) },
			{ pos = Vector3.new(0.3, -1.4, 0), taille = Vector3.new(0.3, 1.4, 0.3), couleur = Color3.fromRGB(250, 215, 225) },
		},
	},
	{
		id = "Bobritto", hauteurModele = 4.5, modeleRotY = 0, name = "Bobritto Bandito", cost = 3,
		hp = 820, dmg = 85, range = 3.5, speed = 9, atkSpeed = 1.1, count = 1,
		color = Color3.fromRGB(120, 80, 50), size = Vector3.new(2.5, 3, 2.5),
		targets = "any", desc = "Castor gangster, encaisse et frappe",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2.4, 2.6, 2.2), couleur = Color3.fromRGB(125, 85, 55) },
			{ pos = Vector3.new(0, 0.1, -1.1), taille = Vector3.new(1.8, 1.4, 0.6), couleur = Color3.fromRGB(230, 225, 210) },
			{ pos = Vector3.new(0, 1.7, -0.3), taille = Vector3.new(1.7, 1.7, 1.7), forme = "boule", couleur = Color3.fromRGB(140, 95, 60) },
			{ pos = Vector3.new(-0.4, 1.9, -1.05), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.4, 1.9, -1.05), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.2, -1.1), taille = Vector3.new(0.7, 0.5, 0.2), couleur = Color3.fromRGB(250, 250, 245) },
			{ pos = Vector3.new(0, 2.5, -0.2), taille = Vector3.new(2, 0.4, 2), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(0, 2.9, -0.2), taille = Vector3.new(1.3, 0.8, 1.3), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(-1.35, 0.3, 0), taille = Vector3.new(0.5, 1.8, 0.6), rot = Vector3.new(0, 0, 15), couleur = Color3.fromRGB(125, 85, 55) },
			{ pos = Vector3.new(1.35, 0.3, 0), taille = Vector3.new(0.5, 1.8, 0.6), rot = Vector3.new(0, 0, -15), couleur = Color3.fromRGB(125, 85, 55) },
			{ pos = Vector3.new(0, -1.1, 1.8), taille = Vector3.new(1.4, 0.35, 2.6), rot = Vector3.new(-15, 0, 0), couleur = Color3.fromRGB(85, 60, 40) },
			{ pos = Vector3.new(-0.6, -1.7, 0), taille = Vector3.new(0.7, 0.7, 1.2), couleur = Color3.fromRGB(95, 65, 45) },
			{ pos = Vector3.new(0.6, -1.7, 0), taille = Vector3.new(0.7, 0.7, 1.2), couleur = Color3.fromRGB(95, 65, 45) },
		},
	},
	{
		id = "Trippi", hauteurModele = 3.5, modeleRotY = 0, name = "Trippi Troppi", cost = 2,
		hp = 260, dmg = 60, range = 3, speed = 15, atkSpeed = 0.75, count = 2,
		color = Color3.fromRGB(255, 120, 90), size = Vector3.new(2, 2, 2.5),
		targets = "any", desc = "Deux crevettes-chats harceleuses",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(1.8, 1.6, 3), couleur = Color3.fromRGB(255, 130, 100) },
			{ pos = Vector3.new(0, 0.5, 1.4), taille = Vector3.new(1.4, 1.2, 1.4), couleur = Color3.fromRGB(240, 105, 80) },
			{ pos = Vector3.new(0, 0.6, -1.5), taille = Vector3.new(1.5, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(255, 150, 120) },
			{ pos = Vector3.new(-0.5, 1.5, -1.4), taille = Vector3.new(0.5, 0.7, 0.2), rot = Vector3.new(0, 0, 20), couleur = Color3.fromRGB(240, 105, 80) },
			{ pos = Vector3.new(0.5, 1.5, -1.4), taille = Vector3.new(0.5, 0.7, 0.2), rot = Vector3.new(0, 0, -20), couleur = Color3.fromRGB(240, 105, 80) },
			{ pos = Vector3.new(-0.4, 0.8, -2.15), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.4, 0.8, -2.15), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.9, 0.4, -2.1), taille = Vector3.new(1.4, 0.08, 0.08), couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(0.9, 0.4, -2.1), taille = Vector3.new(1.4, 0.08, 0.08), couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(0, 0.9, 2.1), taille = Vector3.new(1.6, 0.9, 0.5), rot = Vector3.new(-30, 0, 0), couleur = Color3.fromRGB(255, 165, 140) },
			{ pos = Vector3.new(-0.7, -1, -0.4), taille = Vector3.new(0.25, 0.9, 0.25), couleur = Color3.fromRGB(240, 105, 80) },
			{ pos = Vector3.new(0.7, -1, -0.4), taille = Vector3.new(0.25, 0.9, 0.25), couleur = Color3.fromRGB(240, 105, 80) },
		},
	},
	{
		id = "Boneca", hauteurModele = 5.5, modeleRotY = 0, name = "Boneca Ambalabu", cost = 4,
		hp = 1500, dmg = 110, range = 3, speed = 6.5, atkSpeed = 1.4, count = 1,
		color = Color3.fromRGB(60, 60, 65), size = Vector3.new(3.5, 4, 3.5),
		targets = "buildings", desc = "Grenouille-pneu, roule vers les tours",
		morceaux = {
			{ pos = Vector3.new(0, -0.4, 0), taille = Vector3.new(0.9, 3.6, 3.6), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(45, 45, 50) },
			{ pos = Vector3.new(0, -0.4, 0), taille = Vector3.new(1, 2.2, 2.2), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(110, 115, 120), materiau = "Metal" },
			{ pos = Vector3.new(0, 1.8, -0.2), taille = Vector3.new(2, 1.8, 2), forme = "boule", couleur = Color3.fromRGB(90, 180, 80) },
			{ pos = Vector3.new(-0.7, 2.6, -0.2), taille = Vector3.new(0.9, 0.9, 0.9), forme = "boule", couleur = Color3.fromRGB(240, 240, 235) },
			{ pos = Vector3.new(0.7, 2.6, -0.2), taille = Vector3.new(0.9, 0.9, 0.9), forme = "boule", couleur = Color3.fromRGB(240, 240, 235) },
			{ pos = Vector3.new(-0.7, 2.6, -0.55), taille = Vector3.new(0.4, 0.4, 0.4), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.7, 2.6, -0.55), taille = Vector3.new(0.4, 0.4, 0.4), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.3, -1.1), taille = Vector3.new(1.3, 0.2, 0.2), couleur = Color3.fromRGB(40, 90, 35) },
			{ pos = Vector3.new(-1.5, 0.6, 0.3), taille = Vector3.new(1.2, 0.45, 0.45), rot = Vector3.new(0, 0, -25), couleur = Color3.fromRGB(80, 165, 70) },
			{ pos = Vector3.new(1.5, 0.6, 0.3), taille = Vector3.new(1.2, 0.45, 0.45), rot = Vector3.new(0, 0, 25), couleur = Color3.fromRGB(80, 165, 70) },
			{ pos = Vector3.new(-1.1, -1.6, 0.4), taille = Vector3.new(0.5, 1.4, 0.5), rot = Vector3.new(0, 0, -20), couleur = Color3.fromRGB(80, 165, 70) },
			{ pos = Vector3.new(1.1, -1.6, 0.4), taille = Vector3.new(0.5, 1.4, 0.5), rot = Vector3.new(0, 0, 20), couleur = Color3.fromRGB(80, 165, 70) },
		},
	},
	{
		id = "Glorbo", hauteurModele = 5, modeleRotY = 0, name = "Glorbo Fruttodrillo", cost = 4,
		hp = 620, dmg = 85, range = 8, speed = 7.5, atkSpeed = 1.6, count = 1,
		color = Color3.fromRGB(70, 170, 70), size = Vector3.new(3, 3, 4),
		targets = "any", splash = 3, desc = "Croco-pasteque, tir en zone",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2.8, 2.4, 4.4), couleur = Color3.fromRGB(70, 165, 70) },
			{ pos = Vector3.new(0, 1.1, 0.2), taille = Vector3.new(2.4, 2.4, 2.4), forme = "boule", couleur = Color3.fromRGB(45, 130, 50) },
			{ pos = Vector3.new(0, 1.1, 0.5), taille = Vector3.new(2, 2, 2), forme = "boule", couleur = Color3.fromRGB(230, 70, 80) },
			{ pos = Vector3.new(0, 0.2, -2.9), taille = Vector3.new(2.2, 1.2, 2.6), couleur = Color3.fromRGB(80, 175, 75) },
			{ pos = Vector3.new(0, -0.2, -3), taille = Vector3.new(2, 0.35, 2.4), couleur = Color3.fromRGB(250, 250, 250) },
			{ pos = Vector3.new(-0.6, 1.1, -2.6), taille = Vector3.new(0.45, 0.45, 0.45), forme = "boule", couleur = Color3.fromRGB(250, 245, 60) },
			{ pos = Vector3.new(0.6, 1.1, -2.6), taille = Vector3.new(0.45, 0.45, 0.45), forme = "boule", couleur = Color3.fromRGB(250, 245, 60) },
			{ pos = Vector3.new(0, 1.5, 0), taille = Vector3.new(0.4, 0.6, 2.6), couleur = Color3.fromRGB(35, 110, 40) },
			{ pos = Vector3.new(0, 0.4, 2.6), taille = Vector3.new(1.4, 1, 1.6), couleur = Color3.fromRGB(60, 150, 60) },
			{ pos = Vector3.new(-1.3, -1.2, -1), taille = Vector3.new(0.9, 0.8, 1.6), couleur = Color3.fromRGB(60, 150, 60) },
			{ pos = Vector3.new(1.3, -1.2, -1), taille = Vector3.new(0.9, 0.8, 1.6), couleur = Color3.fromRGB(60, 150, 60) },
			{ pos = Vector3.new(-1.3, -1.2, 1.2), taille = Vector3.new(0.9, 0.8, 1.6), couleur = Color3.fromRGB(60, 150, 60) },
			{ pos = Vector3.new(1.3, -1.2, 1.2), taille = Vector3.new(0.9, 0.8, 1.6), couleur = Color3.fromRGB(60, 150, 60) },
		},
	},
	{
		id = "Frigo", hauteurModele = 6, modeleRotY = 0, name = "Frigo Camelo", cost = 5,
		hp = 1900, dmg = 105, range = 7, speed = 6, atkSpeed = 1.1, count = 1,
		color = Color3.fromRGB(215, 225, 235), size = Vector3.new(3, 5, 2.5),
		targets = "any", desc = "Frigo-chameau, mur qui riposte de loin",
		morceaux = {
			{ pos = Vector3.new(0, 0.3, 0), taille = Vector3.new(2.8, 4.2, 2.2), couleur = Color3.fromRGB(225, 232, 240), materiau = "Metal" },
			{ pos = Vector3.new(0, 1.4, -1.15), taille = Vector3.new(2.5, 1.7, 0.15), couleur = Color3.fromRGB(200, 210, 220), materiau = "Metal" },
			{ pos = Vector3.new(1, 1.4, -1.25), taille = Vector3.new(0.18, 1.2, 0.18), couleur = Color3.fromRGB(120, 125, 130), materiau = "Metal" },
			{ pos = Vector3.new(0, -0.9, -1.15), taille = Vector3.new(2.5, 2.2, 0.15), couleur = Color3.fromRGB(200, 210, 220), materiau = "Metal" },
			{ pos = Vector3.new(0, 3.1, -0.6), taille = Vector3.new(1, 1.6, 1), rot = Vector3.new(-20, 0, 0), couleur = Color3.fromRGB(210, 175, 120) },
			{ pos = Vector3.new(0, 4.2, -1.3), taille = Vector3.new(1.1, 1.1, 1.8), couleur = Color3.fromRGB(215, 180, 125) },
			{ pos = Vector3.new(-0.3, 4.5, -2.1), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.3, 4.5, -2.1), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 2.6, 0.9), taille = Vector3.new(1.4, 1.2, 1.2), forme = "boule", couleur = Color3.fromRGB(200, 165, 110) },
			{ pos = Vector3.new(-0.9, -2.4, 0), taille = Vector3.new(0.6, 1.2, 0.6), couleur = Color3.fromRGB(200, 165, 110) },
			{ pos = Vector3.new(0.9, -2.4, 0), taille = Vector3.new(0.6, 1.2, 0.6), couleur = Color3.fromRGB(200, 165, 110) },
		},
	},
	{
		id = "Tigrullini", prix = 700, hauteurModele = 5, modeleRotY = 0, name = "Tigrullini Watermelini", cost = 4,
		hp = 700, dmg = 170, range = 13, speed = 8, atkSpeed = 1.5, count = 1,
		color = Color3.fromRGB(240, 150, 50), size = Vector3.new(2.5, 4, 2.5),
		targets = "any", desc = "Tigre-pasteque, tireur longue portee",
		morceaux = {
			{ pos = Vector3.new(0, 0.2, 0), taille = Vector3.new(2, 2.6, 1.8), couleur = Color3.fromRGB(240, 150, 50) },
			{ pos = Vector3.new(0, 0.6, -0.95), taille = Vector3.new(1.4, 1.6, 0.15), couleur = Color3.fromRGB(250, 235, 210) },
			{ pos = Vector3.new(-0.6, 0.9, 0), taille = Vector3.new(0.25, 2.2, 1.85), couleur = Color3.fromRGB(35, 30, 30) },
			{ pos = Vector3.new(0.6, 0.2, 0), taille = Vector3.new(0.25, 2.2, 1.85), couleur = Color3.fromRGB(35, 30, 30) },
			{ pos = Vector3.new(0, 2.3, -0.1), taille = Vector3.new(1.9, 1.9, 1.9), forme = "boule", couleur = Color3.fromRGB(70, 165, 70) },
			{ pos = Vector3.new(0, 2.3, -0.5), taille = Vector3.new(1.6, 1.6, 1.4), forme = "boule", couleur = Color3.fromRGB(230, 70, 80) },
			{ pos = Vector3.new(-0.45, 2.5, -1.15), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.45, 2.5, -1.15), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.7, 3.2, 0), taille = Vector3.new(0.6, 0.6, 0.3), couleur = Color3.fromRGB(45, 130, 50) },
			{ pos = Vector3.new(0.7, 3.2, 0), taille = Vector3.new(0.6, 0.6, 0.3), couleur = Color3.fromRGB(45, 130, 50) },
			{ pos = Vector3.new(0.9, 0.9, -1.2), taille = Vector3.new(0.35, 0.35, 3.2), couleur = Color3.fromRGB(90, 95, 100), materiau = "Metal" },
			{ pos = Vector3.new(-0.5, -1.8, 0), taille = Vector3.new(0.55, 1.2, 0.8), couleur = Color3.fromRGB(225, 135, 45) },
			{ pos = Vector3.new(0.5, -1.8, 0), taille = Vector3.new(0.55, 1.2, 0.8), couleur = Color3.fromRGB(225, 135, 45) },
		},
	},
	{
		id = "Vacca", prix = 1200, hauteurModele = 6, modeleRotY = 0, name = "La Vacca Saturno Saturnita", cost = 6,
		hp = 900, dmg = 150, range = 4, speed = 7, atkSpeed = 1.7, count = 1,
		color = Color3.fromRGB(230, 200, 120), size = Vector3.new(5, 3, 4),
		targets = "any", flying = true, splash = 4, desc = "Vache-Saturne volante, frappe tout en zone",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2.8, 2.6, 4.4), couleur = Color3.fromRGB(245, 240, 230) },
			{ pos = Vector3.new(-0.8, 0.9, -0.6), taille = Vector3.new(1.2, 0.9, 1.4), couleur = Color3.fromRGB(35, 30, 30) },
			{ pos = Vector3.new(0.9, -0.3, 1), taille = Vector3.new(1.1, 1.2, 1.6), couleur = Color3.fromRGB(35, 30, 30) },
			{ pos = Vector3.new(0, 0.4, -2.7), taille = Vector3.new(2, 1.8, 1.6), couleur = Color3.fromRGB(245, 240, 230) },
			{ pos = Vector3.new(0, -0.3, -3.3), taille = Vector3.new(1.5, 1, 0.8), couleur = Color3.fromRGB(250, 170, 175) },
			{ pos = Vector3.new(-0.5, 1, -3.3), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.5, 1, -3.3), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.9, 1.5, -2.6), taille = Vector3.new(0.3, 0.9, 0.3), rot = Vector3.new(0, 0, -30), couleur = Color3.fromRGB(240, 225, 190) },
			{ pos = Vector3.new(0.9, 1.5, -2.6), taille = Vector3.new(0.3, 0.9, 0.3), rot = Vector3.new(0, 0, 30), couleur = Color3.fromRGB(240, 225, 190) },
			{ pos = Vector3.new(0, 0.1, 0), taille = Vector3.new(9, 0.35, 9), forme = "cylindre", rot = Vector3.new(0, 0, 8), couleur = Color3.fromRGB(235, 205, 130) },
			{ pos = Vector3.new(0, 0.1, 0), taille = Vector3.new(7, 0.45, 7), forme = "cylindre", rot = Vector3.new(0, 0, 8), couleur = Color3.fromRGB(215, 180, 110) },
			{ pos = Vector3.new(0, -1.4, 0.6), taille = Vector3.new(1.6, 1, 1.2), couleur = Color3.fromRGB(250, 170, 175) },
			{ pos = Vector3.new(0, 0.6, 2.7), taille = Vector3.new(0.3, 1.6, 0.6), rot = Vector3.new(25, 0, 0), couleur = Color3.fromRGB(240, 225, 190) },
		},
	},
	{
		id = "Bombombini", hauteurModele = 4, modeleRotY = 90, name = "Bombombini Gusini", cost = 4,
		hp = 520, dmg = 125, range = 6.5, speed = 9.5, atkSpeed = 1.4, count = 1,
		color = Color3.fromRGB(235, 235, 240), size = Vector3.new(4, 2.5, 4),
		targets = "any", flying = true, splash = 2.5, desc = "Oie-bombardier, largue en zone",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(1.8, 1.8, 5), couleur = Color3.fromRGB(240, 240, 245) },
			{ pos = Vector3.new(0, 0.6, -2.2), taille = Vector3.new(1.4, 1.4, 1.4), forme = "boule", couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(0, 0.5, -3), taille = Vector3.new(0.5, 0.4, 1.1), couleur = Color3.fromRGB(250, 160, 40) },
			{ pos = Vector3.new(-0.4, 0.9, -2.7), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.4, 0.9, -2.7), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-2.6, 0.2, 0.2), taille = Vector3.new(3.4, 0.25, 1.6), couleur = Color3.fromRGB(225, 228, 235), materiau = "Metal" },
			{ pos = Vector3.new(2.6, 0.2, 0.2), taille = Vector3.new(3.4, 0.25, 1.6), couleur = Color3.fromRGB(225, 228, 235), materiau = "Metal" },
			{ pos = Vector3.new(-1.5, -0.4, 0.4), taille = Vector3.new(0.7, 0.7, 1.6), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(90, 95, 105), materiau = "Metal" },
			{ pos = Vector3.new(1.5, -0.4, 0.4), taille = Vector3.new(0.7, 0.7, 1.6), forme = "cylindre", rot = Vector3.new(0, 90, 0), couleur = Color3.fromRGB(90, 95, 105), materiau = "Metal" },
			{ pos = Vector3.new(0, -0.9, 0.6), taille = Vector3.new(0.8, 0.8, 2.2), couleur = Color3.fromRGB(70, 75, 85), materiau = "Metal" },
			{ pos = Vector3.new(0, 0.6, 2.4), taille = Vector3.new(1.6, 0.25, 1.2), couleur = Color3.fromRGB(230, 232, 240), materiau = "Metal" },
			{ pos = Vector3.new(0, 1.1, 2.4), taille = Vector3.new(0.25, 1.1, 1.1), couleur = Color3.fromRGB(230, 232, 240), materiau = "Metal" },
		},
	},
	{
		id = "Cocofanto", hauteurModele = 6.5, modeleRotY = 0, name = "Cocofanto Elefanto", cost = 5,
		hp = 2400, dmg = 180, range = 3.5, speed = 6.5, atkSpeed = 1.35, count = 1,
		color = Color3.fromRGB(150, 105, 60), size = Vector3.new(4, 4, 4),
		targets = "any", desc = "Elephant-noix de coco, mur vivant",
		morceaux = {
			{ pos = Vector3.new(0, 0.4, 0), taille = Vector3.new(3.6, 3.4, 4.4), forme = "boule", couleur = Color3.fromRGB(120, 80, 45) },
			{ pos = Vector3.new(0, 0.4, -0.3), taille = Vector3.new(3.2, 3, 4), forme = "boule", couleur = Color3.fromRGB(150, 105, 60) },
			{ pos = Vector3.new(0, 1, -2.1), taille = Vector3.new(2.4, 2.4, 2.4), forme = "boule", couleur = Color3.fromRGB(165, 120, 70) },
			{ pos = Vector3.new(0, 0.1, -2.8), taille = Vector3.new(0.9, 2.4, 0.9), rot = Vector3.new(25, 0, 0), couleur = Color3.fromRGB(150, 105, 60) },
			{ pos = Vector3.new(-1.5, 1.2, -1.9), taille = Vector3.new(0.3, 1.8, 1.8), couleur = Color3.fromRGB(135, 92, 52) },
			{ pos = Vector3.new(1.5, 1.2, -1.9), taille = Vector3.new(0.3, 1.8, 1.8), couleur = Color3.fromRGB(135, 92, 52) },
			{ pos = Vector3.new(-0.55, 1.4, -3), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.55, 1.4, -3), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.9, 0.2, -2.9), taille = Vector3.new(0.3, 0.3, 1.4), rot = Vector3.new(20, 0, 0), couleur = Color3.fromRGB(250, 248, 240) },
			{ pos = Vector3.new(0.9, 0.2, -2.9), taille = Vector3.new(0.3, 0.3, 1.4), rot = Vector3.new(20, 0, 0), couleur = Color3.fromRGB(250, 248, 240) },
			{ pos = Vector3.new(-1.1, -2, -1.2), taille = Vector3.new(1.1, 1.4, 1.1), couleur = Color3.fromRGB(135, 92, 52) },
			{ pos = Vector3.new(1.1, -2, -1.2), taille = Vector3.new(1.1, 1.4, 1.1), couleur = Color3.fromRGB(135, 92, 52) },
			{ pos = Vector3.new(-1.1, -2, 1.2), taille = Vector3.new(1.1, 1.4, 1.1), couleur = Color3.fromRGB(135, 92, 52) },
			{ pos = Vector3.new(1.1, -2, 1.2), taille = Vector3.new(1.1, 1.4, 1.1), couleur = Color3.fromRGB(135, 92, 52) },
		},
	},
	{
		id = "Burbaloni", hauteurModele = 4.5, modeleRotY = 0, name = "Burbaloni Luliloli", cost = 3,
		hp = 950, dmg = 75, range = 3, speed = 9, atkSpeed = 1.0, count = 1,
		color = Color3.fromRGB(190, 145, 90), size = Vector3.new(3, 3, 3),
		targets = "any", desc = "Capybara en noix de coco, encaisse",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(3.2, 3.2, 3.2), forme = "boule", couleur = Color3.fromRGB(125, 85, 50) },
			{ pos = Vector3.new(0, 1.3, -0.4), taille = Vector3.new(2.2, 1.6, 2.2), forme = "boule", couleur = Color3.fromRGB(200, 155, 95) },
			{ pos = Vector3.new(0, 1.2, -1.3), taille = Vector3.new(1.1, 0.9, 0.9), couleur = Color3.fromRGB(180, 135, 80) },
			{ pos = Vector3.new(-0.45, 1.6, -1.35), taille = Vector3.new(0.26, 0.26, 0.26), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.45, 1.6, -1.35), taille = Vector3.new(0.26, 0.26, 0.26), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.8, 2.1, -0.2), taille = Vector3.new(0.5, 0.5, 0.4), forme = "boule", couleur = Color3.fromRGB(150, 110, 65) },
			{ pos = Vector3.new(0.8, 2.1, -0.2), taille = Vector3.new(0.5, 0.5, 0.4), forme = "boule", couleur = Color3.fromRGB(150, 110, 65) },
			{ pos = Vector3.new(0, 1.7, 0.9), taille = Vector3.new(2.6, 0.5, 1.4), couleur = Color3.fromRGB(110, 75, 42) },
			{ pos = Vector3.new(-1, -1.5, -0.8), taille = Vector3.new(0.6, 0.9, 0.7), couleur = Color3.fromRGB(165, 120, 72) },
			{ pos = Vector3.new(1, -1.5, -0.8), taille = Vector3.new(0.6, 0.9, 0.7), couleur = Color3.fromRGB(165, 120, 72) },
			{ pos = Vector3.new(-1, -1.5, 0.8), taille = Vector3.new(0.6, 0.9, 0.7), couleur = Color3.fromRGB(165, 120, 72) },
			{ pos = Vector3.new(1, -1.5, 0.8), taille = Vector3.new(0.6, 0.9, 0.7), couleur = Color3.fromRGB(165, 120, 72) },
		},
	},
	{
		id = "Bananita", hauteurModele = 4, modeleRotY = 90, name = "Bananita Dolfinita", cost = 2,
		hp = 280, dmg = 115, range = 9, speed = 12, atkSpeed = 1.1, count = 1,
		color = Color3.fromRGB(250, 220, 70), size = Vector3.new(2, 2, 3.5),
		targets = "any", desc = "Dauphin-banane, tireuse vive",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(1.6, 1.6, 4), couleur = Color3.fromRGB(250, 220, 70) },
			{ pos = Vector3.new(0, 0.4, -1.8), taille = Vector3.new(1.4, 1.4, 1.8), forme = "boule", couleur = Color3.fromRGB(250, 225, 85) },
			{ pos = Vector3.new(0, 0.1, -2.7), taille = Vector3.new(0.6, 0.45, 1.2), couleur = Color3.fromRGB(240, 205, 60) },
			{ pos = Vector3.new(-0.4, 0.7, -2.2), taille = Vector3.new(0.24, 0.24, 0.24), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.4, 0.7, -2.2), taille = Vector3.new(0.24, 0.24, 0.24), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.1, -0.2), taille = Vector3.new(0.25, 1, 1.2), rot = Vector3.new(-20, 0, 0), couleur = Color3.fromRGB(235, 200, 55) },
			{ pos = Vector3.new(-1, -0.1, 0.2), taille = Vector3.new(1.4, 0.2, 0.9), rot = Vector3.new(0, 0, -15), couleur = Color3.fromRGB(240, 210, 60) },
			{ pos = Vector3.new(1, -0.1, 0.2), taille = Vector3.new(1.4, 0.2, 0.9), rot = Vector3.new(0, 0, 15), couleur = Color3.fromRGB(240, 210, 60) },
			{ pos = Vector3.new(0, 0.2, 2.2), taille = Vector3.new(1.8, 0.25, 1), couleur = Color3.fromRGB(230, 195, 50) },
			{ pos = Vector3.new(0, 0.6, 2.4), taille = Vector3.new(0.35, 0.6, 0.5), couleur = Color3.fromRGB(120, 95, 40) },
		},
	},
	{
		id = "Giraffa", prix = 900, hauteurModele = 8, modeleRotY = 0, name = "Giraffa Celeste", cost = 5,
		hp = 760, dmg = 210, range = 15, speed = 6, atkSpeed = 1.8, count = 1,
		color = Color3.fromRGB(245, 200, 90), size = Vector3.new(3, 6, 3),
		targets = "any", desc = "Girafe celeste, portee record",
		morceaux = {
			{ pos = Vector3.new(0, -0.4, 0), taille = Vector3.new(2.4, 2.4, 3.6), couleur = Color3.fromRGB(245, 200, 90) },
			{ pos = Vector3.new(-0.7, 0.2, -0.9), taille = Vector3.new(1.2, 0.9, 1.1), couleur = Color3.fromRGB(150, 95, 40) },
			{ pos = Vector3.new(0.8, -0.8, 0.8), taille = Vector3.new(1.1, 1, 1.2), couleur = Color3.fromRGB(150, 95, 40) },
			{ pos = Vector3.new(0, 1.9, -1.3), taille = Vector3.new(0.9, 3.6, 0.9), rot = Vector3.new(12, 0, 0), couleur = Color3.fromRGB(245, 205, 95) },
			{ pos = Vector3.new(0, 3.9, -2), taille = Vector3.new(1, 1.1, 2), couleur = Color3.fromRGB(248, 210, 100) },
			{ pos = Vector3.new(-0.3, 4.3, -2.9), taille = Vector3.new(0.26, 0.26, 0.26), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.3, 4.3, -2.9), taille = Vector3.new(0.26, 0.26, 0.26), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(-0.35, 4.8, -1.8), taille = Vector3.new(0.2, 0.7, 0.2), couleur = Color3.fromRGB(140, 90, 38) },
			{ pos = Vector3.new(0.35, 4.8, -1.8), taille = Vector3.new(0.2, 0.7, 0.2), couleur = Color3.fromRGB(140, 90, 38) },
			{ pos = Vector3.new(0, 1.2, 0), taille = Vector3.new(4.6, 0.2, 4.6), forme = "cylindre", rot = Vector3.new(0, 0, 10), couleur = Color3.fromRGB(150, 200, 250) },
			{ pos = Vector3.new(-1, -2.2, -1.2), taille = Vector3.new(0.7, 2.2, 0.7), couleur = Color3.fromRGB(235, 190, 80) },
			{ pos = Vector3.new(1, -2.2, -1.2), taille = Vector3.new(0.7, 2.2, 0.7), couleur = Color3.fromRGB(235, 190, 80) },
			{ pos = Vector3.new(-1, -2.2, 1.2), taille = Vector3.new(0.7, 2.2, 0.7), couleur = Color3.fromRGB(235, 190, 80) },
			{ pos = Vector3.new(1, -2.2, 1.2), taille = Vector3.new(0.7, 2.2, 0.7), couleur = Color3.fromRGB(235, 190, 80) },
		},
	},
	{
		id = "Zibra", hauteurModele = 4.5, modeleRotY = 0, name = "Zibra Zubra Zibralini", cost = 3,
		hp = 460, dmg = 90, range = 3, speed = 13, atkSpeed = 0.9, count = 2,
		color = Color3.fromRGB(245, 245, 250), size = Vector3.new(2.5, 2.5, 3.5),
		targets = "any", desc = "Deux zebres, charge rapide",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(1.8, 1.8, 3.4), couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(0, 0.05, -0.8), taille = Vector3.new(1.85, 1.85, 0.4), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(0, 0.05, 0.1), taille = Vector3.new(1.85, 1.85, 0.4), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(0, 0.05, 1), taille = Vector3.new(1.85, 1.85, 0.4), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(0, 1.2, -1.5), taille = Vector3.new(0.8, 1.6, 1.6), rot = Vector3.new(20, 0, 0), couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(-0.3, 1.7, -2.1), taille = Vector3.new(0.22, 0.22, 0.22), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.3, 1.7, -2.1), taille = Vector3.new(0.22, 0.22, 0.22), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.9, -1.1), taille = Vector3.new(0.3, 0.8, 1.2), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(0, 0.8, 1.7), taille = Vector3.new(0.3, 1, 0.5), rot = Vector3.new(30, 0, 0), couleur = Color3.fromRGB(30, 30, 35) },
			{ pos = Vector3.new(-0.65, -1.5, -1.1), taille = Vector3.new(0.45, 1.6, 0.45), couleur = Color3.fromRGB(240, 240, 245) },
			{ pos = Vector3.new(0.65, -1.5, -1.1), taille = Vector3.new(0.45, 1.6, 0.45), couleur = Color3.fromRGB(240, 240, 245) },
			{ pos = Vector3.new(-0.65, -1.5, 1.1), taille = Vector3.new(0.45, 1.6, 0.45), couleur = Color3.fromRGB(240, 240, 245) },
			{ pos = Vector3.new(0.65, -1.5, 1.1), taille = Vector3.new(0.45, 1.6, 0.45), couleur = Color3.fromRGB(240, 240, 245) },
		},
	},
	{
		id = "Orcalero", hauteurModele = 5, modeleRotY = 0, name = "Orcalero Orcala", cost = 4,
		hp = 1300, dmg = 145, range = 3.5, speed = 9, atkSpeed = 1.2, count = 1,
		color = Color3.fromRGB(35, 35, 45), size = Vector3.new(3, 3, 4.5),
		targets = "any", desc = "Orque en baskets, cogneuse solide",
		morceaux = {
			{ pos = Vector3.new(0, 0.3, 0), taille = Vector3.new(2.8, 2.6, 5), couleur = Color3.fromRGB(35, 35, 45) },
			{ pos = Vector3.new(0, -0.5, -0.2), taille = Vector3.new(2.3, 1.2, 4.2), couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(0, 0.4, -2.8), taille = Vector3.new(2.4, 2.2, 1.6), forme = "boule", couleur = Color3.fromRGB(35, 35, 45) },
			{ pos = Vector3.new(-0.7, 0.9, -3.2), taille = Vector3.new(0.7, 0.4, 0.2), couleur = Color3.fromRGB(250, 250, 255) },
			{ pos = Vector3.new(0.7, 0.9, -3.2), taille = Vector3.new(0.7, 0.4, 0.2), couleur = Color3.fromRGB(250, 250, 255) },
			{ pos = Vector3.new(0, -0.3, -3.3), taille = Vector3.new(1.8, 0.35, 0.9), couleur = Color3.fromRGB(250, 250, 255) },
			{ pos = Vector3.new(0, 2, 0.2), taille = Vector3.new(0.35, 1.6, 1.2), rot = Vector3.new(-15, 0, 0), couleur = Color3.fromRGB(30, 30, 38) },
			{ pos = Vector3.new(-1.6, -0.2, -0.4), taille = Vector3.new(1.6, 0.3, 1.2), rot = Vector3.new(0, 0, -20), couleur = Color3.fromRGB(32, 32, 42) },
			{ pos = Vector3.new(1.6, -0.2, -0.4), taille = Vector3.new(1.6, 0.3, 1.2), rot = Vector3.new(0, 0, 20), couleur = Color3.fromRGB(32, 32, 42) },
			{ pos = Vector3.new(-0.7, -1.8, -0.4), taille = Vector3.new(0.9, 0.7, 1.9), couleur = Color3.fromRGB(250, 60, 60) },
			{ pos = Vector3.new(0.7, -1.8, -0.4), taille = Vector3.new(0.9, 0.7, 1.9), couleur = Color3.fromRGB(250, 60, 60) },
			{ pos = Vector3.new(0, 0.3, 2.9), taille = Vector3.new(2.4, 0.3, 1.1), couleur = Color3.fromRGB(30, 30, 38) },
		},
	},
	{
		id = "Tralaleritos", hauteurModele = 3.5, modeleRotY = 0, name = "Los Tralaleritos", cost = 4,
		hp = 500, dmg = 95, range = 3.5, speed = 12, atkSpeed = 1.0, count = 3,
		color = Color3.fromRGB(60, 130, 230), size = Vector3.new(2.2, 2.2, 3),
		targets = "any", desc = "Trois bebes requins en baskets",
		morceaux = {
			{ pos = Vector3.new(0, 0.2, 0), taille = Vector3.new(1.8, 1.6, 3.2), couleur = Color3.fromRGB(60, 130, 230) },
			{ pos = Vector3.new(0, -0.3, -0.1), taille = Vector3.new(1.5, 0.8, 2.8), couleur = Color3.fromRGB(235, 240, 250) },
			{ pos = Vector3.new(0, 0.25, -1.8), taille = Vector3.new(1.6, 1.4, 1.3), forme = "boule", couleur = Color3.fromRGB(60, 130, 230) },
			{ pos = Vector3.new(0, -0.25, -2.1), taille = Vector3.new(1.2, 0.25, 0.7), couleur = Color3.fromRGB(255, 255, 255) },
			{ pos = Vector3.new(-0.35, 0.6, -2.2), taille = Vector3.new(0.2, 0.2, 0.2), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.35, 0.6, -2.2), taille = Vector3.new(0.2, 0.2, 0.2), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.4, 0.1), taille = Vector3.new(0.25, 1, 0.9), rot = Vector3.new(-15, 0, 0), couleur = Color3.fromRGB(50, 115, 210) },
			{ pos = Vector3.new(-1.1, 0, -0.2), taille = Vector3.new(1.1, 0.22, 0.9), rot = Vector3.new(0, 0, -18), couleur = Color3.fromRGB(55, 122, 220) },
			{ pos = Vector3.new(1.1, 0, -0.2), taille = Vector3.new(1.1, 0.22, 0.9), rot = Vector3.new(0, 0, 18), couleur = Color3.fromRGB(55, 122, 220) },
			{ pos = Vector3.new(-0.45, -1.2, -0.3), taille = Vector3.new(0.6, 0.55, 1.4), couleur = Color3.fromRGB(250, 250, 255) },
			{ pos = Vector3.new(0.45, -1.2, -0.3), taille = Vector3.new(0.6, 0.55, 1.4), couleur = Color3.fromRGB(250, 250, 255) },
			{ pos = Vector3.new(0, 0.2, 1.9), taille = Vector3.new(1.6, 0.25, 0.8), couleur = Color3.fromRGB(50, 115, 210) },
		},
	},
	{
		id = "Nuclearo", prix = 1500, hauteurModele = 7, modeleRotY = 0, name = "Nuclearo Dinossauro", cost = 6,
		hp = 2300, dmg = 230, range = 4, speed = 5.5, atkSpeed = 1.7, count = 1,
		color = Color3.fromRGB(120, 230, 90), size = Vector3.new(4, 5, 4.5),
		targets = "any", splash = 3.5, desc = "Dino nucleaire, frappe en zone",
		morceaux = {
			{ pos = Vector3.new(0, 0.4, 0), taille = Vector3.new(3, 3.4, 4.2), couleur = Color3.fromRGB(95, 190, 75) },
			{ pos = Vector3.new(0, 0, -0.3), taille = Vector3.new(2.4, 2, 3.6), couleur = Color3.fromRGB(180, 245, 120), materiau = "Neon" },
			{ pos = Vector3.new(0, 2.6, -1.3), taille = Vector3.new(1.8, 1.8, 3), couleur = Color3.fromRGB(110, 210, 85) },
			{ pos = Vector3.new(0, 2.1, -2.4), taille = Vector3.new(1.6, 0.6, 1.4), couleur = Color3.fromRGB(240, 245, 250) },
			{ pos = Vector3.new(-0.5, 3.1, -2.6), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(250, 240, 60), materiau = "Neon" },
			{ pos = Vector3.new(0.5, 3.1, -2.6), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(250, 240, 60), materiau = "Neon" },
			{ pos = Vector3.new(0, 2.6, 0.4), taille = Vector3.new(0.4, 1.2, 1), rot = Vector3.new(-25, 0, 0), couleur = Color3.fromRGB(220, 250, 140), materiau = "Neon" },
			{ pos = Vector3.new(0, 1.9, 1.2), taille = Vector3.new(0.4, 1, 0.9), rot = Vector3.new(-25, 0, 0), couleur = Color3.fromRGB(220, 250, 140), materiau = "Neon" },
			{ pos = Vector3.new(-1.4, 0.6, -1), taille = Vector3.new(0.9, 1.6, 0.9), couleur = Color3.fromRGB(110, 210, 85) },
			{ pos = Vector3.new(1.4, 0.6, -1), taille = Vector3.new(0.9, 1.6, 0.9), couleur = Color3.fromRGB(110, 210, 85) },
			{ pos = Vector3.new(-0.9, -2, -0.4), taille = Vector3.new(1.2, 1.8, 1.6), couleur = Color3.fromRGB(95, 190, 75) },
			{ pos = Vector3.new(0.9, -2, -0.4), taille = Vector3.new(1.2, 1.8, 1.6), couleur = Color3.fromRGB(95, 190, 75) },
			{ pos = Vector3.new(0, -0.6, 2.8), taille = Vector3.new(1, 1, 2.6), rot = Vector3.new(20, 0, 0), couleur = Color3.fromRGB(110, 210, 85) },
			{ pos = Vector3.new(0, 0.2, 4), taille = Vector3.new(0.7, 0.7, 1.6), rot = Vector3.new(35, 0, 0), couleur = Color3.fromRGB(180, 245, 120), materiau = "Neon" },
		},
	},
	{
		id = "Frulli", hauteurModele = 4, modeleRotY = 0, name = "Frulli Frulla", cost = 3,
		hp = 400, dmg = 100, range = 5.5, speed = 14, atkSpeed = 0.9, count = 1,
		color = Color3.fromRGB(255, 120, 180), size = Vector3.new(2.5, 3, 2.5),
		targets = "any", flying = true, desc = "Mixeur volant, harceleur rapide",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(1.8, 2.4, 1.8), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(255, 150, 195) },
			{ pos = Vector3.new(0, -1.3, 0), taille = Vector3.new(2.2, 0.8, 2.2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(70, 75, 85), materiau = "Metal" },
			{ pos = Vector3.new(0, 1.35, 0), taille = Vector3.new(0.35, 2, 2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(200, 205, 215), materiau = "Metal" },
			{ pos = Vector3.new(0, 0.3, -0.85), taille = Vector3.new(1.1, 0.9, 0.2), couleur = Color3.fromRGB(255, 255, 255) },
			{ pos = Vector3.new(-0.3, 0.45, -0.95), taille = Vector3.new(0.24, 0.24, 0.24), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.3, 0.45, -0.95), taille = Vector3.new(0.24, 0.24, 0.24), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, -0.1, -0.95), taille = Vector3.new(0.5, 0.25, 0.15), couleur = Color3.fromRGB(180, 60, 100) },
			{ pos = Vector3.new(-1.6, 1.5, 0), taille = Vector3.new(2.4, 0.15, 0.7), couleur = Color3.fromRGB(215, 220, 230), materiau = "Metal" },
			{ pos = Vector3.new(1.6, 1.5, 0), taille = Vector3.new(2.4, 0.15, 0.7), couleur = Color3.fromRGB(215, 220, 230), materiau = "Metal" },
			{ pos = Vector3.new(-1.1, -0.2, 0), taille = Vector3.new(0.4, 1.2, 0.4), rot = Vector3.new(0, 0, 25), couleur = Color3.fromRGB(240, 130, 175) },
			{ pos = Vector3.new(1.1, -0.2, 0), taille = Vector3.new(0.4, 1.2, 0.4), rot = Vector3.new(0, 0, -25), couleur = Color3.fromRGB(240, 130, 175) },
		},
	},
	{
		id = "Spaghettino", hauteurModele = 5, modeleRotY = 0, name = "Spaghettino Malfunziono", cost = 3,
		hp = 540, dmg = 105, range = 6.5, speed = 8, atkSpeed = 1.2, count = 1,
		color = Color3.fromRGB(245, 230, 190), size = Vector3.new(2.5, 3.5, 2.5),
		targets = "any", desc = "Assiette de pates deglinguee, crache la sauce",
		morceaux = {
			{ pos = Vector3.new(0, 0.6, 0), taille = Vector3.new(3, 0.5, 3), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(250, 250, 252) },
			{ pos = Vector3.new(0, 1, 0), taille = Vector3.new(2.4, 0.7, 2.4), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(245, 225, 160) },
			{ pos = Vector3.new(0, 1.4, 0), taille = Vector3.new(1.8, 0.5, 1.8), forme = "boule", couleur = Color3.fromRGB(215, 55, 45) },
			{ pos = Vector3.new(0, 2.1, -0.2), taille = Vector3.new(1.4, 1.4, 1.4), forme = "boule", couleur = Color3.fromRGB(240, 235, 225) },
			{ pos = Vector3.new(-0.35, 2.25, -0.85), taille = Vector3.new(0.26, 0.26, 0.26), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.4, 2.35, -0.8), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.75, -0.85), taille = Vector3.new(0.7, 0.2, 0.15), rot = Vector3.new(0, 0, 12), couleur = Color3.fromRGB(150, 60, 55) },
			{ pos = Vector3.new(-1.5, 0.2, 0), taille = Vector3.new(0.35, 1.8, 0.35), rot = Vector3.new(0, 0, 35), couleur = Color3.fromRGB(245, 225, 160) },
			{ pos = Vector3.new(1.5, 0.2, 0), taille = Vector3.new(0.35, 1.8, 0.35), rot = Vector3.new(0, 0, -35), couleur = Color3.fromRGB(245, 225, 160) },
			{ pos = Vector3.new(-0.5, -1.3, 0), taille = Vector3.new(0.3, 2, 0.3), couleur = Color3.fromRGB(245, 225, 160) },
			{ pos = Vector3.new(0.5, -1.3, 0), taille = Vector3.new(0.3, 2, 0.3), couleur = Color3.fromRGB(245, 225, 160) },
			{ pos = Vector3.new(-0.5, -2.3, -0.3), taille = Vector3.new(0.5, 0.35, 1), couleur = Color3.fromRGB(40, 40, 50) },
			{ pos = Vector3.new(0.5, -2.3, -0.3), taille = Vector3.new(0.5, 0.35, 1), couleur = Color3.fromRGB(40, 40, 50) },
		},
	},
	{
		id = "Trulimero", hauteurModele = 4, modeleRotY = 0, name = "Trulimero Trulicina", cost = 2,
		hp = 330, dmg = 75, range = 3, speed = 15, atkSpeed = 0.8, count = 2,
		color = Color3.fromRGB(90, 190, 210), size = Vector3.new(2, 2.5, 3),
		targets = "any", desc = "Deux poissons-danseuses, harcelent vite",
		morceaux = {
			{ pos = Vector3.new(0, 0.6, 0), taille = Vector3.new(1.6, 1.6, 2.8), couleur = Color3.fromRGB(90, 190, 210) },
			{ pos = Vector3.new(0, 0.8, -1.3), taille = Vector3.new(1.3, 1.3, 1.2), forme = "boule", couleur = Color3.fromRGB(105, 205, 225) },
			{ pos = Vector3.new(-0.3, 1, -1.8), taille = Vector3.new(0.24, 0.24, 0.24), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0.3, 1, -1.8), taille = Vector3.new(0.24, 0.24, 0.24), forme = "boule", couleur = Color3.fromRGB(15, 15, 20) },
			{ pos = Vector3.new(0, 1.7, 0), taille = Vector3.new(0.25, 0.9, 1.4), couleur = Color3.fromRGB(70, 165, 190) },
			{ pos = Vector3.new(-1, 0.6, 0.1), taille = Vector3.new(1, 0.2, 0.8), rot = Vector3.new(0, 0, -20), couleur = Color3.fromRGB(80, 175, 200) },
			{ pos = Vector3.new(1, 0.6, 0.1), taille = Vector3.new(1, 0.2, 0.8), rot = Vector3.new(0, 0, 20), couleur = Color3.fromRGB(80, 175, 200) },
			{ pos = Vector3.new(0, 0.6, 1.6), taille = Vector3.new(1.4, 0.25, 0.8), couleur = Color3.fromRGB(70, 165, 190) },
			{ pos = Vector3.new(-0.4, -0.9, 0), taille = Vector3.new(0.35, 1.8, 0.35), couleur = Color3.fromRGB(240, 235, 225) },
			{ pos = Vector3.new(0.4, -0.9, 0), taille = Vector3.new(0.35, 1.8, 0.35), couleur = Color3.fromRGB(240, 235, 225) },
			{ pos = Vector3.new(-0.4, -1.9, -0.2), taille = Vector3.new(0.45, 0.3, 0.8), couleur = Color3.fromRGB(240, 90, 140) },
			{ pos = Vector3.new(0.4, -1.9, -0.2), taille = Vector3.new(0.45, 0.3, 0.8), couleur = Color3.fromRGB(240, 90, 140) },
		},
	},
	{
		id = "Bicus", prix = 600, hauteurModele = 4.5, modeleRotY = 0, name = "Brri Brri Bicus Dicus", cost = 4,
		hp = 620, dmg = 135, range = 6, speed = 10, atkSpeed = 1.3, count = 1,
		color = Color3.fromRGB(175, 140, 235), size = Vector3.new(3, 3, 3),
		targets = "any", flying = true, desc = "Chauve-souris romaine, volante",
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2, 2.2, 2), forme = "boule", couleur = Color3.fromRGB(120, 90, 180) },
			{ pos = Vector3.new(0, 0.9, -0.5), taille = Vector3.new(1.6, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(175, 140, 235) },
			{ pos = Vector3.new(-0.55, 1.9, -0.4), taille = Vector3.new(0.5, 1.1, 0.3), rot = Vector3.new(0, 0, 15), couleur = Color3.fromRGB(150, 115, 210) },
			{ pos = Vector3.new(0.55, 1.9, -0.4), taille = Vector3.new(0.5, 1.1, 0.3), rot = Vector3.new(0, 0, -15), couleur = Color3.fromRGB(150, 115, 210) },
			{ pos = Vector3.new(-0.35, 1.05, -1.15), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(250, 220, 60), materiau = "Neon" },
			{ pos = Vector3.new(0.35, 1.05, -1.15), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(250, 220, 60), materiau = "Neon" },
			{ pos = Vector3.new(-0.2, 0.55, -1.15), taille = Vector3.new(0.15, 0.35, 0.1), couleur = Color3.fromRGB(255, 255, 255) },
			{ pos = Vector3.new(0.2, 0.55, -1.15), taille = Vector3.new(0.15, 0.35, 0.1), couleur = Color3.fromRGB(255, 255, 255) },
			{ pos = Vector3.new(-2.2, 0.4, 0.2), taille = Vector3.new(3, 0.2, 2), rot = Vector3.new(0, 0, 12), couleur = Color3.fromRGB(95, 70, 150) },
			{ pos = Vector3.new(2.2, 0.4, 0.2), taille = Vector3.new(3, 0.2, 2), rot = Vector3.new(0, 0, -12), couleur = Color3.fromRGB(95, 70, 150) },
			{ pos = Vector3.new(0, 1.9, 0.3), taille = Vector3.new(1.8, 0.25, 1.8), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(230, 200, 90) },
			{ pos = Vector3.new(0, -1.2, 0), taille = Vector3.new(0.9, 0.5, 0.9), couleur = Color3.fromRGB(120, 90, 180) },
		},
	},
	-- ===== BATIMENTS POSES =====
	-- Un batiment ne marche pas : il tient une voie, detourne les unites anti-tours et MEURT TOUT
	-- SEUL au bout de sa duree de vie (Batiments.usure). Sans cette usure, le poser serait gratuit.
	-- `batiment` : { type = "defense"|"collecteur"|"invocateur"|"leurre", duree, periode, gain, invoque }
	{
		id = "TorreCannoli", name = "Torre Cannoli", cost = 4, desc = "Batiment : canon defensif, 40 s",
		batiment = { type = "defense", duree = 40 },
		hp = 900, dmg = 130, range = 9, speed = 0, atkSpeed = 1.1, count = 1,
		targets = "any", color = Color3.fromRGB(225, 190, 120), size = Vector3.new(4, 5, 4),
		vitesseTir = 55,
		morceaux = {
			{ pos = Vector3.new(0, -1.6, 0), taille = Vector3.new(4.2, 1.2, 4.2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(150, 110, 70), materiau = "Wood" },
			{ pos = Vector3.new(0, 0.2, 0), taille = Vector3.new(3.4, 2.6, 3.4), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(235, 200, 130) },
			{ pos = Vector3.new(0, 1.8, 0), taille = Vector3.new(2.6, 1, 2.6), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(120, 80, 50), materiau = "Wood" },
			{ pos = Vector3.new(0, 1.9, -1.8), taille = Vector3.new(2.6, 0.9, 0.9), forme = "cylindre", rot = Vector3.new(90, 0, 0), couleur = Color3.fromRGB(70, 70, 75), materiau = "Metal" },
			{ pos = Vector3.new(-1.3, 0.4, -1.5), taille = Vector3.new(0.4, 0.4, 0.4), forme = "boule", couleur = Color3.fromRGB(255, 230, 90), materiau = "Neon" },
			{ pos = Vector3.new(1.3, 0.4, -1.5), taille = Vector3.new(0.4, 0.4, 0.4), forme = "boule", couleur = Color3.fromRGB(255, 230, 90), materiau = "Neon" },
		},
	},
	{
		id = "PompaElixir", prix = 700, name = "Pompa Elixir", cost = 6, desc = "Batiment : rend 1 elixir toutes les 8 s",
		batiment = { type = "collecteur", duree = 60, periode = 8, gain = 1 },
		hp = 800, dmg = 0, range = 0, speed = 0, atkSpeed = 0, count = 1,
		targets = "any", color = Color3.fromRGB(190, 110, 245), size = Vector3.new(4, 4, 4),
		morceaux = {
			{ pos = Vector3.new(0, -1.3, 0), taille = Vector3.new(4, 1, 4), couleur = Color3.fromRGB(90, 70, 110) },
			{ pos = Vector3.new(0, 0.3, 0), taille = Vector3.new(2.8, 3, 2.8), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(190, 110, 245) },
			{ pos = Vector3.new(0, 2, 0), taille = Vector3.new(1.6, 1.6, 1.6), forme = "boule", couleur = Color3.fromRGB(235, 160, 255), materiau = "Neon" },
			{ pos = Vector3.new(-1.7, 0.2, 0), taille = Vector3.new(0.5, 1.8, 0.5), couleur = Color3.fromRGB(120, 120, 130), materiau = "Metal" },
			{ pos = Vector3.new(1.7, 0.2, 0), taille = Vector3.new(0.5, 1.8, 0.5), couleur = Color3.fromRGB(120, 120, 130), materiau = "Metal" },
		},
	},
	{
		id = "NidoBrainrot", prix = 900, name = "Nido Brainrot", cost = 5, desc = "Batiment : pond des singes toutes les 9 s",
		batiment = { type = "invocateur", duree = 36, periode = 9, invoque = "Chimpanzini", nombre = 2 },
		hp = 850, dmg = 0, range = 0, speed = 0, atkSpeed = 0, count = 1,
		targets = "any", color = Color3.fromRGB(180, 140, 70), size = Vector3.new(4, 3, 4),
		morceaux = {
			{ pos = Vector3.new(0, -0.8, 0), taille = Vector3.new(4.2, 1.6, 4.2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(140, 100, 55), materiau = "Wood" },
			{ pos = Vector3.new(0, 0.6, 0), taille = Vector3.new(3.4, 1.2, 3.4), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(180, 140, 70), materiau = "Wood" },
			{ pos = Vector3.new(-0.7, 1.3, 0), taille = Vector3.new(1, 1, 1), forme = "boule", couleur = Color3.fromRGB(250, 235, 190) },
			{ pos = Vector3.new(0.7, 1.3, 0.4), taille = Vector3.new(1, 1, 1), forme = "boule", couleur = Color3.fromRGB(250, 235, 190) },
		},
	},
	{
		id = "MuroSpaghetti", name = "Muro Spaghetti", cost = 2, desc = "Batiment : mur de pates, retient tout 20 s",
		batiment = { type = "leurre", duree = 20 },
		hp = 1400, dmg = 0, range = 0, speed = 0, atkSpeed = 0, count = 1,
		targets = "any", color = Color3.fromRGB(240, 210, 130), size = Vector3.new(5, 3, 2),
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(5, 2.6, 1.8), couleur = Color3.fromRGB(240, 210, 130) },
			{ pos = Vector3.new(-1.6, 1.4, 0), taille = Vector3.new(1.4, 0.6, 1.8), couleur = Color3.fromRGB(215, 180, 100) },
			{ pos = Vector3.new(0.2, 1.5, 0), taille = Vector3.new(1.2, 0.7, 1.8), couleur = Color3.fromRGB(225, 190, 110) },
			{ pos = Vector3.new(1.8, 1.3, 0), taille = Vector3.new(1.3, 0.5, 1.8), couleur = Color3.fromRGB(205, 170, 95) },
		},
	},
	-- ===== UNITES A EFFET =====
	-- Chacune porte un effet du module Statuts : bouclier, soin, poison, ralentissement, explosion
	-- a la mort. Ce sont les reponses qui manquaient au jeu — retarder, proteger, soigner, punir
	-- un tas serre — la ou tout se jouait jusqu'ici au seul rapport points de vie / degats.
	{
		id = "ScudoBanana", name = "Scudo Banana", cost = 3, desc = "Bouclier de peau de banane, encaisse avant les PV",
		hp = 420, dmg = 105, range = 3, speed = 9, atkSpeed = 1.0, count = 1,
		bouclier = 520,
		targets = "any", color = Color3.fromRGB(245, 225, 90), size = Vector3.new(3, 4, 3),
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2, 2.6, 2), couleur = Color3.fromRGB(245, 225, 90) },
			{ pos = Vector3.new(0, 1.7, 0), taille = Vector3.new(1.5, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(250, 240, 160) },
			{ pos = Vector3.new(-0.35, 1.8, -0.75), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(20, 20, 25) },
			{ pos = Vector3.new(0.35, 1.8, -0.75), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(20, 20, 25) },
			{ pos = Vector3.new(-1.5, 0.2, -0.4), taille = Vector3.new(0.4, 2.6, 2), rot = Vector3.new(0, 0, 8), couleur = Color3.fromRGB(190, 150, 60), materiau = "Wood" },
			{ pos = Vector3.new(1.3, 0.1, -0.2), taille = Vector3.new(0.4, 1.6, 0.4), rot = Vector3.new(0, 0, -25), couleur = Color3.fromRGB(215, 195, 70) },
			{ pos = Vector3.new(-0.5, -1.8, 0), taille = Vector3.new(0.6, 1, 0.8), couleur = Color3.fromRGB(215, 195, 70) },
			{ pos = Vector3.new(0.5, -1.8, 0), taille = Vector3.new(0.6, 1, 0.8), couleur = Color3.fromRGB(215, 195, 70) },
		},
	},
	{
		id = "DottorePizza", prix = 600, name = "Dottore Pizza", cost = 4, desc = "Soigne les allies autour de lui",
		hp = 520, dmg = 55, range = 6, speed = 9, atkSpeed = 1.4, count = 1,
		soin = { montant = 55, rayon = 6, periode = 1 },
		targets = "any", color = Color3.fromRGB(120, 235, 160), size = Vector3.new(2, 4, 2),
		vitesseTir = 45,
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2, 2.4, 1.6), couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(0, 1.7, 0), taille = Vector3.new(1.5, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(250, 220, 180) },
			{ pos = Vector3.new(0, 2.4, 0), taille = Vector3.new(1.7, 0.3, 1.7), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(240, 240, 245) },
			{ pos = Vector3.new(0, 0.6, -0.85), taille = Vector3.new(0.9, 0.25, 0.1), couleur = Color3.fromRGB(80, 200, 120) },
			{ pos = Vector3.new(0, 0.6, -0.9), taille = Vector3.new(0.25, 0.9, 0.1), couleur = Color3.fromRGB(80, 200, 120) },
			{ pos = Vector3.new(-1.2, 0.2, -0.3), taille = Vector3.new(0.4, 1.6, 0.4), rot = Vector3.new(20, 0, 0), couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(1.2, 0.2, -0.3), taille = Vector3.new(0.4, 1.6, 0.4), rot = Vector3.new(20, 0, 0), couleur = Color3.fromRGB(245, 245, 250) },
			{ pos = Vector3.new(-0.45, -1.7, 0), taille = Vector3.new(0.5, 1, 0.7), couleur = Color3.fromRGB(60, 70, 90) },
			{ pos = Vector3.new(0.45, -1.7, 0), taille = Vector3.new(0.5, 1, 0.7), couleur = Color3.fromRGB(60, 70, 90) },
		},
	},
	{
		id = "BombaSalsiccia", name = "Bomba Salsiccia", cost = 3, desc = "Explose en mourant, degats en zone",
		hp = 480, dmg = 70, range = 3, speed = 13, atkSpeed = 1.2, count = 1,
		mort = { degats = 260, rayon = 4.5 },
		targets = "any", color = Color3.fromRGB(215, 95, 70), size = Vector3.new(2, 3, 2),
		morceaux = {
			{ pos = Vector3.new(0, 0.2, 0), taille = Vector3.new(2.2, 2, 2.2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(190, 75, 60) },
			{ pos = Vector3.new(0, 1.5, 0), taille = Vector3.new(1.4, 1.4, 1.4), forme = "boule", couleur = Color3.fromRGB(230, 120, 95) },
			{ pos = Vector3.new(-0.35, 1.6, -0.6), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(20, 20, 25) },
			{ pos = Vector3.new(0.35, 1.6, -0.6), taille = Vector3.new(0.28, 0.28, 0.28), forme = "boule", couleur = Color3.fromRGB(20, 20, 25) },
			{ pos = Vector3.new(0, 2.3, 0), taille = Vector3.new(0.25, 0.8, 0.25), rot = Vector3.new(0, 0, 20), couleur = Color3.fromRGB(60, 50, 45) },
			{ pos = Vector3.new(0.2, 2.9, 0), taille = Vector3.new(0.5, 0.5, 0.5), forme = "boule", couleur = Color3.fromRGB(255, 170, 60), materiau = "Neon" },
			{ pos = Vector3.new(-0.45, -1.5, 0), taille = Vector3.new(0.5, 0.9, 0.7), couleur = Color3.fromRGB(150, 60, 45) },
			{ pos = Vector3.new(0.45, -1.5, 0), taille = Vector3.new(0.5, 0.9, 0.7), couleur = Color3.fromRGB(150, 60, 45) },
		},
	},
	{
		id = "ReginaGhiaccio", prix = 800, name = "Regina Ghiaccio", cost = 4, desc = "Tireuse de glace : ralentit ce qu'elle touche",
		hp = 700, dmg = 125, range = 7.5, speed = 9, atkSpeed = 1.1, count = 1,
		effet = { lent = { part = 0.35, duree = 2.5 } },
		targets = "any", color = Color3.fromRGB(150, 220, 255), size = Vector3.new(2, 4, 2),
		vitesseTir = 50,
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2, 2.6, 1.8), couleur = Color3.fromRGB(120, 190, 240) },
			{ pos = Vector3.new(0, 1.8, 0), taille = Vector3.new(1.5, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(235, 250, 255) },
			{ pos = Vector3.new(0, 2.7, 0), taille = Vector3.new(1.2, 0.8, 1.2), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(180, 235, 255), materiau = "Neon" },
			{ pos = Vector3.new(-0.35, 1.9, -0.75), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(40, 90, 140) },
			{ pos = Vector3.new(0.35, 1.9, -0.75), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(40, 90, 140) },
			{ pos = Vector3.new(-1.3, 0.4, -0.5), taille = Vector3.new(0.35, 2.4, 0.35), rot = Vector3.new(25, 0, 0), couleur = Color3.fromRGB(200, 240, 255), materiau = "Neon" },
			{ pos = Vector3.new(0, -1.7, 0), taille = Vector3.new(1.8, 1.2, 1.6), couleur = Color3.fromRGB(90, 160, 215) },
		},
	},
	{
		id = "SerpenteVeleno", name = "Serpente Veleno", cost = 3, desc = "Ses morsures empoisonnent dans la duree",
		hp = 440, dmg = 60, range = 3.5, speed = 12, atkSpeed = 0.9, count = 2,
		effet = { poison = { degats = 28, duree = 4, tic = 0.5 } },
		targets = "any", color = Color3.fromRGB(120, 210, 90), size = Vector3.new(2, 2, 3),
		morceaux = {
			{ pos = Vector3.new(0, -0.3, 0.6), taille = Vector3.new(1.4, 1.2, 3), couleur = Color3.fromRGB(100, 180, 75) },
			{ pos = Vector3.new(0, 0.6, -0.9), taille = Vector3.new(1.2, 1.2, 1.6), couleur = Color3.fromRGB(130, 215, 95) },
			{ pos = Vector3.new(-0.3, 0.8, -1.6), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(255, 220, 60), materiau = "Neon" },
			{ pos = Vector3.new(0.3, 0.8, -1.6), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(255, 220, 60), materiau = "Neon" },
			{ pos = Vector3.new(0, 0.2, -1.9), taille = Vector3.new(0.6, 0.15, 0.8), couleur = Color3.fromRGB(200, 70, 90) },
			{ pos = Vector3.new(0, -0.5, 2.3), taille = Vector3.new(0.7, 0.7, 1.6), couleur = Color3.fromRGB(80, 150, 60) },
		},
	},
	{
		id = "AquilaFrizzante", name = "Aquila Frizzante", cost = 4, desc = "Aigle gazeuse : vole et tire en mouvement",
		hp = 430, dmg = 95, range = 6.5, speed = 12, atkSpeed = 1.0, count = 1, flying = true,
		targets = "any", color = Color3.fromRGB(255, 165, 70), size = Vector3.new(3, 2, 3),
		vitesseTir = 60,
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(1.8, 1.6, 2.6), couleur = Color3.fromRGB(235, 140, 55) },
			{ pos = Vector3.new(0, 0.7, -1.4), taille = Vector3.new(1.3, 1.3, 1.3), forme = "boule", couleur = Color3.fromRGB(250, 245, 235) },
			{ pos = Vector3.new(0, 0.5, -2.1), taille = Vector3.new(0.5, 0.5, 0.9), couleur = Color3.fromRGB(255, 200, 60) },
			{ pos = Vector3.new(-0.3, 0.95, -1.85), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(25, 25, 30) },
			{ pos = Vector3.new(0.3, 0.95, -1.85), taille = Vector3.new(0.25, 0.25, 0.25), forme = "boule", couleur = Color3.fromRGB(25, 25, 30) },
			{ pos = Vector3.new(-2, 0.3, 0.2), taille = Vector3.new(2.6, 0.2, 1.6), rot = Vector3.new(0, 0, 14), couleur = Color3.fromRGB(215, 120, 45) },
			{ pos = Vector3.new(2, 0.3, 0.2), taille = Vector3.new(2.6, 0.2, 1.6), rot = Vector3.new(0, 0, -14), couleur = Color3.fromRGB(215, 120, 45) },
			{ pos = Vector3.new(0, 0.2, 1.7), taille = Vector3.new(1.4, 0.2, 1.2), couleur = Color3.fromRGB(240, 170, 80) },
		},
	},
	{
		id = "MinatoreMozzarella", prix = 1100, name = "Minatore Mozzarella", cost = 4, desc = "Creuse : se pose partout dans l'arene",
		hp = 900, dmg = 160, range = 3, speed = 11, atkSpeed = 1.1, count = 1,
		poseLibre = true,
		targets = "any", color = Color3.fromRGB(250, 250, 240), size = Vector3.new(2, 4, 2),
		morceaux = {
			{ pos = Vector3.new(0, 0, 0), taille = Vector3.new(2, 2.4, 1.8), couleur = Color3.fromRGB(250, 250, 240) },
			{ pos = Vector3.new(0, 1.7, 0), taille = Vector3.new(1.5, 1.5, 1.5), forme = "boule", couleur = Color3.fromRGB(252, 250, 235) },
			{ pos = Vector3.new(0, 2.5, 0), taille = Vector3.new(1.9, 0.5, 1.9), forme = "cylindre", rot = Vector3.new(0, 0, 90), couleur = Color3.fromRGB(255, 205, 70) },
			{ pos = Vector3.new(0, 2.75, -0.5), taille = Vector3.new(0.45, 0.45, 0.45), forme = "boule", couleur = Color3.fromRGB(255, 255, 180), materiau = "Neon" },
			{ pos = Vector3.new(-0.35, 1.8, -0.75), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(25, 25, 30) },
			{ pos = Vector3.new(0.35, 1.8, -0.75), taille = Vector3.new(0.3, 0.3, 0.3), forme = "boule", couleur = Color3.fromRGB(25, 25, 30) },
			{ pos = Vector3.new(1.4, 0.3, -0.6), taille = Vector3.new(0.3, 2.2, 0.5), rot = Vector3.new(35, 0, 0), couleur = Color3.fromRGB(140, 145, 155), materiau = "Metal" },
			{ pos = Vector3.new(-0.45, -1.7, 0), taille = Vector3.new(0.5, 1, 0.8), couleur = Color3.fromRGB(110, 90, 70) },
			{ pos = Vector3.new(0.45, -1.7, 0), taille = Vector3.new(0.5, 1, 0.8), couleur = Color3.fromRGB(110, 90, 70) },
		},
	},
	-- ===== SORTS =====
	-- Un SORT ne pose aucune unite : il frappe (ou renforce) une ZONE, n'importe ou dans l'arene,
	-- y compris chez l'ennemi. C'etait le manque n^o 1 du jeu : sans sorts, un groupe serre de
	-- petites unites n'avait aucune reponse, et une tour a 200 PV ne pouvait pas etre achevee.
	-- `sort` porte tout l'effet : rayon (studs), degats, et pour la rage le gain et sa duree.
	-- degatsTour : les sorts font moins mal aux TOURS qu'aux unites (regle classique du genre,
	-- sinon deux sorts suffisent a raser une tour sans jamais attaquer).
	{
		id = "PizzaBombarda", name = "Pizza Bombarda", cost = 4, desc = "Sort : grosse explosion en zone",
		sort = { effet = "degats", rayon = 4.5, degats = 340, degatsTour = 0.35, couleur = Color3.fromRGB(255, 120, 40) },
		color = Color3.fromRGB(255, 120, 40),
		hp = 0, dmg = 340, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "FreccineSpaghetti", name = "Freccine Spaghetti", cost = 3, desc = "Sort : volee large, degats moyens",
		sort = { effet = "degats", rayon = 7, degats = 165, degatsTour = 0.3, couleur = Color3.fromRGB(240, 225, 150) },
		color = Color3.fromRGB(240, 225, 150),
		hp = 0, dmg = 165, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "FuriaBrainrot", prix = 400, name = "Furia Brainrot", cost = 2, desc = "Sort : tes unites plus rapides et plus fortes",
		sort = { effet = "rage", rayon = 6, degats = 0, gain = 0.35, duree = 7, couleur = Color3.fromRGB(215, 90, 255) },
		color = Color3.fromRGB(215, 90, 255),
		hp = 0, dmg = 0, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "GelatoGlaciale", name = "Gelato Glaciale", cost = 4, desc = "Sort : gele tout ce qui bouge dans la zone",
		sort = { effet = "gel", rayon = 5, degats = 90, degatsTour = 0.3, duree = 1.8, couleur = Color3.fromRGB(150, 225, 255) },
		color = Color3.fromRGB(150, 225, 255),
		hp = 0, dmg = 90, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "VelenoPizza", prix = 700, name = "Veleno Pizza", cost = 4, desc = "Sort : flaque qui empoisonne pendant 8 s",
		sort = { effet = "poison", rayon = 5.5, degats = 0, degatsTour = 0.3, duree = 8, tic = 0.5, parTic = 22, couleur = Color3.fromRGB(150, 220, 90) },
		color = Color3.fromRGB(150, 220, 90),
		hp = 0, dmg = 0, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "CuraLimone", name = "Cura Limone", cost = 3, desc = "Sort : soigne tes unites dans la zone",
		sort = { effet = "soin", rayon = 5, degats = 0, soin = 300, couleur = Color3.fromRGB(245, 240, 120) },
		color = Color3.fromRGB(245, 240, 120),
		hp = 0, dmg = 0, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "TroncoBanano", name = "Tronco Banano", cost = 2, desc = "Sort : tronc qui roule, pousse et blesse au sol",
		sort = { effet = "degats", rayon = 3.8, degats = 215, degatsTour = 0.2, recul = 4, solSeulement = true, couleur = Color3.fromRGB(160, 110, 60) },
		color = Color3.fromRGB(160, 110, 60),
		hp = 0, dmg = 215, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
	{
		id = "FulmineFormaggio", prix = 1000, name = "Fulmine Formaggio", cost = 5, desc = "Sort : la foudre frappe les 3 plus solides",
		sort = { effet = "degats", rayon = 4, degats = 480, degatsTour = 0.35, cibles = 3, couleur = Color3.fromRGB(255, 240, 120) },
		color = Color3.fromRGB(255, 240, 120),
		hp = 0, dmg = 480, range = 0, speed = 0, atkSpeed = 0, count = 0, targets = "any",
		size = Vector3.new(1, 1, 1),
	},
}

-- RARETE. Elle se DEDUIT du prix de deblocage : offerte = commune, moins de 800 pieces = rare,
-- moins de 1200 = epique, au-dela = legendaire. Rien a maintenir a la main, donc aucune carte ne
-- peut se retrouver sans rarete — et ajouter une carte payante la classe toute seule.
-- Sert a la couleur du cadre des tuiles (main, boutique, deck) : le joueur voit d'un coup d'oeil
-- ce qui est rare, ce qui manquait completement.
local RARETES = {
	commune = { nom = "Commune", couleur = Color3.fromRGB(170, 180, 200) },
	rare = { nom = "Rare", couleur = Color3.fromRGB(90, 190, 255) },
	epique = { nom = "Epique", couleur = Color3.fromRGB(190, 110, 255) },
	-- ORANGE-OR : a (255,190,60) la legendaire se confondait avec l'or des PIECES (capture de la
	-- revelation du 2026-09-21). Elle a desormais sa propre teinte, partout ou la rarete se dessine.
	legendaire = { nom = "Legendaire", couleur = Color3.fromRGB(255, 140, 30) },
}

-- CHAMPIONS (2026-09-21) : cartes a CAPACITE ACTIVABLE (module Champions). Chacun reprend la
-- silhouette et le MODELE 3D de sa carte de base (champ `modele`), en plus grand, couronne doree
-- sur la tete. Un seul par deck (Economie). `capacite` = cle de Champions.CAPACITES.
local function champion(baseId, champ)
	local base
	for _, c in ipairs(Cards) do
		if c.id == baseId then
			base = c
		end
	end
	local c = {}
	for k, v in pairs(base) do
		c[k] = v
	end
	c.morceaux = {}
	for _, m in ipairs(base.morceaux or {}) do
		table.insert(c.morceaux, m)
	end
	-- sommet de la silhouette de base, DONNE par le champion (mesure sur ses morceaux)
	local haut = champ.couronneY or 3
	-- couronne doree : bandeau + trois pointes, posee au sommet de la silhouette
	local OR = Color3.fromRGB(255, 205, 60)
	table.insert(c.morceaux, { pos = Vector3.new(0, haut + 0.25, 0), taille = Vector3.new(1.6, 0.5, 1.6), couleur = OR })
	for i = -1, 1 do
		table.insert(c.morceaux, { pos = Vector3.new(i * 0.6, haut + 0.75, 0), taille = Vector3.new(0.35, 0.6, 0.35), couleur = OR })
	end
	c.modele = baseId
	for k, v in pairs(champ) do
		c[k] = v
	end
	table.insert(Cards, c)
end
-- DUELLISTE : peu de PV, gros coups ; sa survie vient de son Bouclier royal (capacite), pas de ses PV.
champion("Tralalero", { id = "RoiTralalero", name = "Roi Tralalero", prix = 1500, cost = 4,
	hp = 640, dmg = 260, speed = 12, echelle = 1.3, hauteurModele = 6, capacite = "bouclierRoyal", couronneY = 3.5,
	desc = "CHAMPION - capacite : Bouclier royal (2 elixir)" })
champion("Patapim", { id = "PatapimAncien", name = "Patapim l'Ancien", prix = 1500, cost = 6,
	-- COMBATTANT (et non plus fonceur de tours comme sa carte de base) : il se defend, et son
	-- Rugissement gele ce qui l entoure.
	hp = 2400, dmg = 210, atkSpeed = 1.5, splash = 3, targets = "any", echelle = 1.2, hauteurModele = 7.5, capacite = "rugissement", couronneY = 6.7,
	desc = "CHAMPION - capacite : Rugissement, gele les ennemis proches (2 elixir)" })

local function rareteDe(prix)
	if not prix then
		return "commune"
	elseif prix < 800 then
		return "rare"
	elseif prix < 1200 then
		return "epique"
	end
	return "legendaire"
end

local byId = {}
for _, c in ipairs(Cards) do
	c.rarete = rareteDe(c.prix)
	byId[c.id] = c
end

return { list = Cards, byId = byId, RARETES = RARETES, rareteDe = rareteDe }
