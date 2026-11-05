/**
 * Modele de Schelling sur grille
 * Modele 1 du tutoriel GAMA (A. Drogoul, B. Gaudou, P. Taillandier),
 * adaptation JD Kant et M. Franceschetti.
 * TME 2 - partie 1 : ajout du pourcentage de similarite et d'une experience batch.
 */

model SchellingGrid

global {
	float density <- 0.5;
	float similar_wanted <- 0.7;
	int distance <- 1;
	int nb_people <- 0;

	bool is_converged -> people all_match (each.is_happy);

	// % de similarite global : voisins de meme couleur / nombre total de voisins
	float percent_similar -> (people sum_of (each.nb_neighbours)) = 0
		? 0.0
		: 100 * (people sum_of (each.nb_neighbours_same)) / (people sum_of (each.nb_neighbours));

	// condition d'arret du batch. Sous GAMA 2025 le "until:" n'est verifie que de temps en temps :
	// en mode batch on fige la simulation des que fini est vrai.
	int max_cycles <- 200;
	bool batch_mode <- false;
	bool fini <- false;
	bool gel <- false;

	// export de la carte finale pour les figures du rapport
	bool exporter <- false;
	bool exporte <- false;

	init {
		nb_people <- int(length(house) * density);
		loop h over: nb_people among shuffle(house) {
			create people {
				my_house <- h;
				location <- h.location;
				h.is_empty <- false;
			}
		}
	}

	// En batch les simulations tournent en parallele et and/or y provoquent des erreurs
	// aleatoires sous GAMA 2025 ("wrong casting"), d'ou les if imbriques dans le code des simulations.
	reflex verifier_fin {
		fini <- is_converged;
		if (cycle > max_cycles) { fini <- true; }
		if (fini) {
			if (batch_mode) { gel <- true; }
		}
	}

	reflex export_carte when: exporter {
		if (fini) {
			if (not exporte) {
				string nom <- "export/carte_sw" + similar_wanted + "_dist" + distance + ".csv";
				save ["x", "y", "rouge"] to: nom format: "csv" rewrite: true header: false;
				ask people {
					int rouge <- 0;
					if (color = #red) { rouge <- 1; }
					save [my_house.grid_x, my_house.grid_y, rouge] to: nom format: "csv" rewrite: false header: false;
				}
				exporte <- true;
			}
		}
	}
}

grid house width: 30 height: 30 neighbors: 8 {
	bool is_empty <- true;
}

species people {
	house my_house;
	rgb color <- #yellow;
	bool is_happy;
	int nb_neighbours <- 0;
	int nb_neighbours_diff <- 0;
	int nb_neighbours_same <- 0;

	init {
		if (flip(0.5)) { color <- #red; }
	}

	reflex move when: not is_happy {
		if (not gel) {
			my_house.is_empty <- true;
			my_house <- one_of(house where each.is_empty);
			location <- my_house.location;
			my_house.is_empty <- false;
		}
	}

	reflex compute_happiness when: not gel {
		list<house> neighbor_houses <- my_house neighbors_at distance;
		list<people> neighbours_pp <- neighbor_houses accumulate (people inside each) where (each != nil);
		nb_neighbours <- length(neighbours_pp);
		nb_neighbours_diff <- neighbours_pp count (each.color != color);
		nb_neighbours_same <- nb_neighbours - nb_neighbours_diff;
		// heureux si au moins similar_wanted % des voisins sont de sa couleur (regle NetLogo)
		is_happy <- true;
		if (nb_neighbours > 0) {
			is_happy <- nb_neighbours_same >= similar_wanted * nb_neighbours;
		}
	}

	aspect default {
		draw circle(1.0) color: color;
	}
}

experiment Schelling_Grid type: gui {
	parameter "density" var: density <- 0.5;
	parameter "similar_wanted" var: similar_wanted <- 0.3;
	parameter "distance" var: distance <- 1;

	output {
		display map {
			grid house border: rgb(0, 0, 0);
			species people;
		}
		display charts {
			chart "Evolution" type: series background: #white y_range: [0, 100] {
				data "% happy" style: line value: 100 * (people count each.is_happy) / nb_people color: #green;
				data "% similar" style: line value: percent_similar color: #red;
			}
		}
		monitor "NbTotalAgents" value: nb_people refresh: false;
		monitor "PercentHappy" value: 100 * (people count each.is_happy) / nb_people;
		monitor "PercentSimilar" value: percent_similar;
		monitor "is_converged" value: is_converged;
	}
}

// % de similarite a l'equilibre en fonction de similar_wanted (transparent 23 du cours 2)
experiment Exploration type: batch repeat: 5 keep_seed: false until: fini {
	parameter "Mode batch" var: batch_mode among: [true];
	parameter "density" var: density among: [0.5];
	parameter "distance" var: distance among: [3];
	parameter "similar_wanted" var: similar_wanted among: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];

	method exploration;

	list<point> courbe <- [];

	init {
		save ["similar_wanted", "percent_similar"] to: "resultats_similarite.csv" format: "csv" rewrite: true header: false;
	}

	// Sous GAMA 2025 ce reflex n'est appele qu'une fois, avec toutes les simulations :
	// on regroupe donc les repetitions par valeur de similar_wanted.
	reflex enregistrer {
		loop v over: remove_duplicates(simulations collect each.similar_wanted) sort_by each {
			int sw <- round(v * 100);
			float moyenne <- ((simulations where (each.similar_wanted = v)) mean_of each.percent_similar) with_precision 1;
			add {sw, moyenne} to: courbe;
			write "similar_wanted = " + sw + " % : similarite = " + moyenne + " %";
			save [sw, moyenne] to: "resultats_similarite.csv" format: "csv" rewrite: false header: false;
		}
	}

	permanent {
		display resultats background: #white {
			chart "%similar" type: xy x_range: [0, 100] y_range: [40, 100]
					x_label: "similar_wanted (%)" y_label: "%similar" {
				data "%similar" value: courbe style: line marker_shape: marker_square color: #red;
			}
		}
	}
}

// Export des cartes finales utilisees pour les figures du rapport
experiment Export_Figures type: batch repeat: 1 keep_seed: false until: fini {
	parameter "Exporter" var: exporter among: [true];
	parameter "density" var: density among: [0.7];
	parameter "distance" var: distance among: [1];
	parameter "similar_wanted" var: similar_wanted among: [0.3, 0.5, 0.7, 0.8];
	method exploration;
}
