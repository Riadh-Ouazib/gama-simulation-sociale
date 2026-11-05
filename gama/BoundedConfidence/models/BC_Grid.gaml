/**
 * Modele Bounded Confidence sur grille (Deffuant et al. 2001, section 3)
 * Chaque cellule de la grille 29x29 est un agent ; il ne discute qu'avec ses 4 voisins
 * (Von Neumann). La regle d'influence est la meme que dans BC_Base.
 * TME 2 - questions 2.5 et 2.6
 */

model BoundedConfidence_Grid

global {
	int grid_size <- 29;
	float threshold <- 0.3;          // d
	float convergenceParam <- 0.3;   // mu
	int stop_cycle <- 120;           // 1 cycle = 841 rencontres, 100 000 iterations ~ 120 cycles

	// Clusters spatiaux : composantes connexes ou deux voisins sont relies si |x - x'| < d
	int nb_clusters <- 0;
	int nb_big_clusters <- 0;        // plus de 1 % des agents
	int nb_isolated <- 0;            // aucun voisin a moins de d : l'agent ne bougera plus
	int largest_id <- -1;
	int largest_size <- 0;
	float largest_opinion <- 0.0;
	bool percolates <- false;        // le plus grand cluster relie deux bords opposes
	bool is_stable <- false;         // deux voisins ont soit la meme opinion, soit un ecart >= d

	// batchs (voir BC_Base)
	int max_cycles <- 2000;
	bool batch_mode <- false;
	bool fini <- false;
	bool gel <- false;
	int cycle_fin <- -1;

	// export de la grille pour les figures du rapport
	bool exporter <- false;
	int export_cycle <- 1000;

	float mean_opinion -> cell mean_of each.opinion;
	float pct_largest -> 100 * largest_size / length(cell);

	reflex stop_simulation {
		if (stop_cycle != -1) {
			if (cycle > stop_cycle) { do pause; }
		}
	}

	reflex analyse when: not gel {
		do analyse_clusters;
	}

	// parcours en largeur pour etiqueter les clusters
	action analyse_clusters {
		ask cell { cluster_id <- -1; }
		int id <- 0;
		int n_big <- 0;
		int n_iso <- 0;
		int best <- 0;
		bool stable <- true;
		int min_size <- int(length(cell) * 0.01) + 1;

		loop c over: cell {
			if (c.cluster_id = -1) {
				c.cluster_id <- id;
				list<cell> membres <- [c];
				int tete <- 0;
				loop while: tete < length(membres) {
					cell x <- membres[tete];
					tete <- tete + 1;
					list<cell> voisins <- x.neighbors;
					loop v over: voisins {
						float ecart <- abs(v.opinion - x.opinion);
						if (ecart < threshold) {
							if (ecart > 0.001) { stable <- false; }
							if (v.cluster_id = -1) {
								v.cluster_id <- id;
								add v to: membres;
							}
						}
					}
				}
				int taille <- length(membres);
				if (taille = 1) { n_iso <- n_iso + 1; }
				if (taille >= min_size) { n_big <- n_big + 1; }
				if (taille > best) {
					best <- taille;
					largest_id <- id;
					largest_opinion <- (membres mean_of each.opinion) with_precision 3;
					percolates <- false;
					if (membres one_matches (each.grid_y = 0)) {
						if (membres one_matches (each.grid_y = grid_size - 1)) { percolates <- true; }
					}
					if (membres one_matches (each.grid_x = 0)) {
						if (membres one_matches (each.grid_x = grid_size - 1)) { percolates <- true; }
					}
				}
				id <- id + 1;
			}
		}
		nb_clusters <- id;
		nb_big_clusters <- n_big;
		nb_isolated <- n_iso;
		largest_size <- best;
		is_stable <- stable;

		fini <- stable;
		if (cycle >= max_cycles) { fini <- true; }
		if (fini) {
			if (cycle_fin = -1) { cycle_fin <- cycle; }
			if (batch_mode) { gel <- true; }
		}
	}

	reflex export_grille when: exporter {
		if (cycle = export_cycle) {
			string nom <- "export/grille_d" + threshold + "_mu" + convergenceParam + ".csv";
			save ["x", "y", "opinion", "cluster"] to: nom format: "csv" rewrite: true header: false;
			ask cell {
				save [grid_x, grid_y, opinion, cluster_id] to: nom format: "csv" rewrite: false header: false;
			}
			gel <- true;
		}
	}
}

// neighbors: 8 pour un voisinage de Moore
grid cell width: grid_size height: grid_size neighbors: 4 {
	float opinion <- rnd(1.0) min: 0.0 max: 1.0;
	int cluster_id <- -1;

	init {
		do update_color;
	}

	// niveaux de gris : 0 = noir, 1 = blanc
	action update_color {
		int g <- int(255 * opinion);
		color <- rgb(g, g, g);
	}

	reflex discute when: not gel {
		cell neighbor <- one_of(neighbors);
		if (neighbor != nil) {
			if (abs(neighbor.opinion - opinion) < threshold) {
				float temp <- opinion;
				opinion <- opinion + convergenceParam * (neighbor.opinion - opinion);
				neighbor.opinion <- neighbor.opinion + convergenceParam * (temp - neighbor.opinion);
				ask neighbor { do update_color; }
			}
		}
		do update_color;
	}

	aspect plus_grand_cluster {
		draw shape color: (cluster_id = largest_id) ? #red : color border: #white;
	}
}


// Figure 5 : d = 0.3, mu = 0.3 ; Figure 6 : d = 0.15, mu = 0.3
experiment BC_Grid type: gui {
	parameter "Taille de la grille" var: grid_size <- 29;
	parameter "Threshold" var: threshold <- 0.3;
	parameter "Convergence speed" var: convergenceParam <- 0.3;
	parameter "Stop at Cycle" var: stop_cycle <- 120;

	output {
		display Grille {
			grid cell border: #white;
		}
		display Plus_grand_cluster {
			species cell aspect: plus_grand_cluster;
		}
		// Figure 7 : 101 classes (100 x opinion arrondie)
		display Histogramme {
			chart "Histogramme des opinions" type: histogram background: #white {
				loop i from: 0 to: 100 {
					data "" + i value: cell count (round(each.opinion * 100) = i) color: #gray;
				}
			}
		}
		display Evolution {
			chart "Time chart" type: series background: #white series_label_position: none {
				loop c over: cell {
					data "" + int(c) value: c.opinion color: #blue;
				}
			}
		}
		monitor "Nombre de clusters" value: nb_clusters;
		monitor "Clusters > 1 %" value: nb_big_clusters;
		monitor "Agents isoles" value: nb_isolated;
		monitor "Plus grand cluster (%)" value: pct_largest with_precision 1;
		monitor "Opinion du plus grand cluster" value: largest_opinion;
		monitor "Percolation" value: percolates;
		monitor "Equilibre" value: is_stable;
		monitor "Opinion moyenne" value: mean_opinion with_precision 3;
	}
}

// 2.6 : statistiques sur les clusters en fonction de d et mu
experiment Grid_Stats type: batch repeat: 5 keep_seed: false until: fini {
	parameter "Mode batch" var: batch_mode among: [true];
	parameter "Max cycles" var: max_cycles among: [2000];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "Threshold" var: threshold among: [0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5];
	parameter "Convergence speed" var: convergenceParam among: [0.1, 0.3, 0.5];

	method exploration;

	init {
		save ["d", "mu", "nb_clusters", "nb_big_clusters", "nb_isolated", "pct_largest", "pct_percolation", "cycles", "pct_stable"]
			to: "grid_stats.csv" format: "csv" rewrite: true header: false;
	}

	reflex enregistrer {
		loop d over: remove_duplicates(simulations collect each.threshold) sort_by each {
			loop m over: remove_duplicates(simulations collect each.convergenceParam) sort_by each {
				list<BoundedConfidence_Grid_model> sims <- simulations where ((each.threshold = d) and (each.convergenceParam = m));
				if (!empty(sims)) {
					float clus <- (sims mean_of each.nb_clusters) with_precision 1;
					float big <- (sims mean_of each.nb_big_clusters) with_precision 1;
					float iso <- (sims mean_of each.nb_isolated) with_precision 1;
					float larg <- (sims mean_of each.pct_largest) with_precision 1;
					float perc <- (100 * (sims count each.percolates) / length(sims)) with_precision 0;
					float cyc <- (sims mean_of each.cycle_fin) with_precision 0;
					float stab <- (100 * (sims count each.is_stable) / length(sims)) with_precision 0;
					write "d=" + d + " mu=" + m + " : " + clus + " clusters, " + iso + " isoles, plus grand " + larg + " %";
					save [d, m, clus, big, iso, larg, perc, cyc, stab] to: "grid_stats.csv" format: "csv" rewrite: false header: false;
				}
			}
		}
	}
}

// Export des grilles utilisees pour les figures du rapport
experiment Export_Figures type: batch repeat: 1 keep_seed: false until: cycle > export_cycle + 5 {
	parameter "Exporter" var: exporter among: [true];
	parameter "Cycle exporte" var: export_cycle among: [1000];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "Threshold" var: threshold among: [0.15, 0.2, 0.3];
	parameter "Convergence speed" var: convergenceParam among: [0.3];
	method exploration;
}
