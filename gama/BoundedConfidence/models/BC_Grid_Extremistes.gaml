/**
 * Modele BC sur grille avec extremistes (extension 2.6)
 * Opinions dans [-1, 1] : les distances sont doublees par rapport a BC_Grid
 * (d = 0.6 ici correspond a d = 0.3 sur [0, 1]).
 * NE agents tires au hasard sont extremistes : opinion fixe a +1 (ou -1),
 * ils influencent leurs voisins proches mais ne sont jamais influences.
 */

model BoundedConfidence_Grid_Extremistes

global {
	int grid_size <- 29;
	float threshold <- 0.6;
	float convergenceParam <- 0.3;
	int stop_cycle <- 500;

	int NE <- 20;
	bool deux_camps <- false;    // true : la moitie des extremistes a -1

	// mesures sur les agents normaux
	list<cell> normaux -> cell where (not each.is_extremist);
	float mean_opinion -> normaux mean_of each.opinion;
	float pct_captures -> 100 * (normaux count (abs(each.opinion) > 0.8)) / max([1, length(normaux)]);
	float pct_captures_plus -> 100 * (normaux count (each.opinion > 0.8)) / max([1, length(normaux)]);
	float pct_captures_moins -> 100 * (normaux count (each.opinion < -0.8)) / max([1, length(normaux)]);

	bool is_stable <- false;

	// batchs (voir BC_Base)
	int max_cycles <- 1000;
	bool batch_mode <- false;
	bool fini <- false;
	bool gel <- false;
	int cycle_fin <- -1;

	// export de la grille pour les figures du rapport
	bool exporter <- false;
	int export_cycle <- 500;

	init {
		ask NE among list(cell) {
			is_extremist <- true;
			opinion <- 1.0;
			if (deux_camps) {
				if (flip(0.5)) { opinion <- -1.0; }
			}
			do update_color;
		}
	}

	reflex stop_simulation {
		if (stop_cycle != -1) {
			if (cycle > stop_cycle) { do pause; }
		}
	}

	// equilibre : deux voisins ont soit la meme opinion, soit un ecart >= d
	reflex test_equilibre when: not gel {
		bool stable <- true;
		loop c over: cell {
			list<cell> voisins <- c.neighbors;
			loop v over: voisins {
				float ecart <- abs(v.opinion - c.opinion);
				if (ecart < threshold) {
					if (ecart > 0.002) {
						stable <- false;
						break;
					}
				}
			}
			if (!stable) { break; }
		}
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
			string nom <- "export/extremistes_NE" + NE + "_d" + threshold + ".csv";
			save ["x", "y", "opinion", "extremiste"] to: nom format: "csv" rewrite: true header: false;
			ask cell {
				save [grid_x, grid_y, opinion, is_extremist] to: nom format: "csv" rewrite: false header: false;
			}
			gel <- true;
		}
	}
}

grid cell width: grid_size height: grid_size neighbors: 4 {
	float opinion <- rnd(-1.0, 1.0) min: -1.0 max: 1.0;
	bool is_extremist <- false;

	init {
		do update_color;
	}

	// extremistes en rouge (+1) ou bleu (-1), les autres en niveaux de gris
	action update_color {
		if (is_extremist) {
			if (opinion > 0) { color <- #red; } else { color <- #blue; }
		} else {
			int g <- int(255 * (opinion + 1) / 2);
			color <- rgb(g, g, g);
		}
	}

	reflex discute when: not gel {
		cell neighbor <- one_of(neighbors);
		if (neighbor != nil) {
			if (abs(neighbor.opinion - opinion) < threshold) {
				float temp <- opinion;
				if (not is_extremist) {
					opinion <- opinion + convergenceParam * (neighbor.opinion - opinion);
				}
				if (not neighbor.is_extremist) {
					neighbor.opinion <- neighbor.opinion + convergenceParam * (temp - neighbor.opinion);
					ask neighbor { do update_color; }
				}
			}
		}
		do update_color;
	}
}


experiment BC_Extremistes type: gui {
	parameter "Nombre d'extremistes (NE)" var: NE <- 20;
	parameter "Deux camps (-1 et +1)" var: deux_camps <- false;
	parameter "Threshold (sur [-1,1])" var: threshold <- 0.6;
	parameter "Convergence speed" var: convergenceParam <- 0.3;
	parameter "Stop at Cycle" var: stop_cycle <- 500;

	output {
		display Grille {
			grid cell border: #white;
		}
		display Mesures {
			chart "Influence des extremistes" type: series background: #white y_range: [-1, 1] {
				data "opinion moyenne" value: mean_opinion color: #black;
				data "% captures par +1 / 100" value: pct_captures_plus / 100 color: #red;
				data "% captures par -1 / 100" value: pct_captures_moins / 100 color: #blue;
			}
		}
		display Histogramme {
			chart "Opinions des agents normaux" type: histogram background: #white {
				loop i from: 0 to: 19 {
					data "" + ((-1 + i / 10) with_precision 1) value: normaux count ((each.opinion >= -1 + i / 10) and ((each.opinion < -1 + (i + 1) / 10) or (i = 19))) color: #gray;
				}
			}
		}
		monitor "Opinion moyenne des normaux" value: mean_opinion with_precision 3;
		monitor "% captures (|opinion| > 0.8)" value: pct_captures with_precision 1;
		monitor "% captures par +1" value: pct_captures_plus with_precision 1;
		monitor "% captures par -1" value: pct_captures_moins with_precision 1;
		monitor "Equilibre" value: is_stable;
	}
}

// 2.6.2 : effet de NE et de d (un seul camp a +1). NE = 0 sert de reference.
experiment Influence_NE type: batch repeat: 5 keep_seed: false until: fini {
	parameter "Mode batch" var: batch_mode among: [true];
	parameter "Max cycles" var: max_cycles among: [1000];
	parameter "Deux camps" var: deux_camps among: [false];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "Convergence speed" var: convergenceParam among: [0.3];
	parameter "NE" var: NE among: [0, 1, 5, 20, 80, 160];
	parameter "Threshold" var: threshold among: [0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.5];

	method exploration;

	init {
		save ["NE", "threshold", "pct_captures_plus", "mean_opinion", "cycles", "pct_stable"]
			to: "extremistes.csv" format: "csv" rewrite: true header: false;
	}

	reflex enregistrer {
		loop ne over: remove_duplicates(simulations collect each.NE) sort_by each {
			loop d over: remove_duplicates(simulations collect each.threshold) sort_by each {
				list<BoundedConfidence_Grid_Extremistes_model> sims <- simulations where ((each.NE = ne) and (each.threshold = d));
				if (!empty(sims)) {
					float captures <- (sims mean_of each.pct_captures_plus) with_precision 1;
					float moy <- (sims mean_of each.mean_opinion) with_precision 2;
					float cyc <- (sims mean_of each.cycle_fin) with_precision 0;
					float stab <- (100 * (sims count each.is_stable) / length(sims)) with_precision 0;
					write "NE=" + ne + " d=" + d + " : " + captures + " % captures, opinion moyenne " + moy;
					save [ne, d, captures, moy, cyc, stab] to: "extremistes.csv" format: "csv" rewrite: false header: false;
				}
			}
		}
	}
}

// Export des grilles utilisees pour les figures du rapport
experiment Export_Figures type: batch repeat: 1 keep_seed: false until: cycle > export_cycle + 5 {
	parameter "Exporter" var: exporter among: [true];
	parameter "Cycle exporte" var: export_cycle among: [500];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "NE" var: NE among: [20];
	parameter "Threshold" var: threshold among: [0.4, 0.8];
	parameter "Convergence speed" var: convergenceParam among: [0.3];
	method exploration;
}
