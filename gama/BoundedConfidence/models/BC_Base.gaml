/**
 * Modele Bounded Confidence (Deffuant, Neau, Amblard, Weisbuch 2001), section 2.1
 * Melange complet : chaque agent peut rencontrer n'importe quel autre agent.
 * TME 2 - questions 2.1 a 2.4
 */

model BoundedConfidence_Base

global {
	int nAgents <- 100;
	float threshold <- 0.3;          // d
	float convergenceParam <- 0.5;   // mu
	int stop_cycle <- 100;           // -1 : pas d'arret

	// Analyse des groupes : on trie les opinions et on coupe des que deux opinions
	// consecutives sont a une distance >= d. Si chaque groupe a une largeur < d,
	// les groupes ne peuvent plus ni fusionner ni se separer : la structure est definitive.
	float min_peak_frac <- 0.01;     // un pic contient plus de 1 % des agents (on exclut isoles et ailes)
	int nb_peaks <- 0;
	int nb_groups <- 0;
	bool is_stable <- false;
	list<float> peak_positions <- [];

	// Batchs. Sous GAMA 2025 le "until:" n'est verifie que de temps en temps, les simulations
	// continuent donc apres leur fin : en mode batch on les fige des que fini est vrai.
	int max_cycles <- 500;
	bool batch_mode <- false;
	bool fini <- false;
	bool gel <- false;
	int cycle_fin <- -1;

	// Export des trajectoires pour les figures du rapport
	bool exporter <- false;
	int export_max <- 60;

	init {
		create SimpleAgent number: nAgents;
	}

	// Les and / or / ?: plantent parfois dans les simulations paralleles d'un batch
	// (GAMA 2025, "wrong casting") : on utilise des if imbriques.
	reflex stop_simulation {
		if (stop_cycle != -1) {
			if (cycle > stop_cycle) { do pause; }
		}
	}

	reflex update_peaks when: not gel {
		do analyse_groupes;
	}

	action analyse_groupes {
		list<float> ops <- (SimpleAgent collect each.opinion) sort_by each;
		if (length(ops) < 2) { fini <- true; return; }
		int min_size <- int(nAgents * min_peak_frac) + 1;
		int n <- 0;
		int ng <- 0;
		bool stable <- true;
		list<float> pos <- [];
		float debut <- ops[0];
		float somme <- ops[0];
		int taille <- 1;
		loop i from: 1 to: length(ops) - 1 {
			if ((ops[i] - ops[i - 1]) >= threshold) {
				ng <- ng + 1;
				if ((ops[i - 1] - debut) >= threshold) { stable <- false; }
				if (taille >= min_size) {
					n <- n + 1;
					add (somme / taille) with_precision 3 to: pos;
				}
				debut <- ops[i];
				somme <- ops[i];
				taille <- 1;
			} else {
				taille <- taille + 1;
				somme <- somme + ops[i];
			}
		}
		ng <- ng + 1;
		if ((last(ops) - debut) >= threshold) { stable <- false; }
		if (taille >= min_size) {
			n <- n + 1;
			add (somme / taille) with_precision 3 to: pos;
		}
		nb_peaks <- n;
		nb_groups <- ng;
		is_stable <- stable;
		peak_positions <- pos;

		fini <- stable;
		if (cycle >= max_cycles) { fini <- true; }
		if (fini) {
			if (cycle_fin = -1) { cycle_fin <- cycle; }
			if (batch_mode) { gel <- true; }
		}
	}

	reflex export_trajectoires when: exporter {
		if (gel) { return; }
		string nom <- "export/base_d" + threshold + "_mu" + convergenceParam;
		if (cycle <= export_max) {
			save SimpleAgent collect each.opinion to: nom + "_traj.csv" format: "csv" rewrite: false header: false;
		}
		if (cycle = export_max) {
			save SimpleAgent collect each.initial_opinion to: nom + "_init_final.csv" format: "csv" rewrite: true header: false;
			save SimpleAgent collect each.opinion to: nom + "_init_final.csv" format: "csv" rewrite: false header: false;
			gel <- true;
		}
	}
}

species SimpleAgent {
	float opinion <- rnd(1.0) min: 0.0 max: 1.0;
	float initial_opinion;

	init {
		initial_opinion <- opinion;
	}

	// chaque agent rencontre un autre agent tire au hasard : 1 cycle = nAgents rencontres
	reflex discute when: not gel {
		SimpleAgent neighbor <- one_of(SimpleAgent);
		if (neighbor != self) {
			if (abs(neighbor.opinion - opinion) < threshold) {
				float temp <- opinion;
				opinion <- opinion + convergenceParam * (neighbor.opinion - opinion);
				neighbor.opinion <- neighbor.opinion + convergenceParam * (temp - neighbor.opinion);
			}
		}
	}
}


// 2.2 : test avec 50 agents
experiment BC_Base_Test type: gui {
	parameter "Number of Agents" var: nAgents <- 50;
	parameter "Threshold" var: threshold <- 0.3;
	parameter "Convergence speed" var: convergenceParam <- 0.5;
	parameter "Stop at Cycle" var: stop_cycle <- 100;

	output {
		display BC_Base {
			chart "Time chart" type: series background: rgb('white') {
				loop a over: SimpleAgent {
					data "" + int(a) value: a.opinion color: rgb('blue');
				}
			}
		}
		monitor "Nombre de pics" value: nb_peaks;
		monitor "Position des pics" value: peak_positions;
		monitor "Nombre de groupes (isoles compris)" value: nb_groups;
		monitor "Structure definitive" value: is_stable;
		monitor "1/(2d)" value: 1 / (2 * threshold);
	}
}

// 2.3 : 1000 agents. Figure 1 : d = 0.5 ; Figure 2 : d = 0.2 ; Figure 3 : d = 0.1 (mu = 0.5 puis 0.05)
experiment BC_Base_1000 type: gui {
	parameter "Number of Agents" var: nAgents <- 1000;
	parameter "Threshold" var: threshold <- 0.3;
	parameter "Convergence speed" var: convergenceParam <- 0.5;
	parameter "Stop at Cycle" var: stop_cycle <- 200;

	output {
		display BC_Base {
			chart "Time chart" type: series background: rgb('white') series_label_position: none {
				loop a over: SimpleAgent {
					data "" + int(a) value: a.opinion color: rgb('green');
				}
			}
		}
		display Figure3 {
			chart "Opinion finale / opinion initiale" type: scatter background: #white
					x_range: [0, 1] y_range: [0, 1] x_label: "opinion initiale" y_label: "opinion" {
				data "agents" value: SimpleAgent collect {each.initial_opinion, each.opinion} color: #black marker_size: 0.3;
			}
		}
		monitor "Nombre de pics" value: nb_peaks;
		monitor "Position des pics" value: peak_positions;
		monitor "Nombre de groupes (isoles compris)" value: nb_groups;
		monitor "Structure definitive" value: is_stable;
		monitor "1/(2d)" value: 1 / (2 * threshold);
	}
}

// 2.3.2 : effet de d, mu et N sur le nombre de pics et le temps de convergence
experiment Effet_parametres type: batch repeat: 5 keep_seed: false until: fini {
	parameter "Mode batch" var: batch_mode among: [true];
	parameter "Max cycles" var: max_cycles among: [2000];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "Threshold" var: threshold among: [0.1, 0.2, 0.3, 0.5];
	parameter "Convergence speed" var: convergenceParam among: [0.05, 0.1, 0.3, 0.5];
	parameter "Number of Agents" var: nAgents among: [100, 1000];

	method exploration;

	init {
		save ["N", "d", "mu", "nb_peaks", "nb_groups", "cycles"] to: "effet_parametres.csv" format: "csv" rewrite: true header: false;
	}

	// Sous GAMA 2025 ce reflex n'est appele qu'une fois avec toutes les simulations :
	// on regroupe les repetitions par jeu de parametres.
	reflex enregistrer {
		loop n over: remove_duplicates(simulations collect each.nAgents) sort_by each {
			loop d over: remove_duplicates(simulations collect each.threshold) sort_by each {
				loop m over: remove_duplicates(simulations collect each.convergenceParam) sort_by each {
					list<BoundedConfidence_Base_model> sims <- simulations where ((each.nAgents = n) and (each.threshold = d) and (each.convergenceParam = m));
					if (!empty(sims)) {
						float pics <- (sims mean_of each.nb_peaks) with_precision 2;
						float groupes <- (sims mean_of each.nb_groups) with_precision 1;
						float cyc <- (sims mean_of each.cycle_fin) with_precision 0;
						write "N=" + n + " d=" + d + " mu=" + m + " : " + pics + " pics, " + groupes + " groupes, " + cyc + " cycles";
						save [n, d, m, pics, groupes, cyc] to: "effet_parametres.csv" format: "csv" rewrite: false header: false;
					}
				}
			}
		}
	}
}

// 2.4 : nombre de pics en fonction de d (Figure 4).
// repeat: 10 prend environ 1 min ; au-dela GAMA ralentit beaucoup (toutes les simulations
// sont lancees en meme temps), il vaut mieux relancer plusieurs fois et cumuler les fichiers.
experiment Figure4 type: batch repeat: 10 keep_seed: false until: fini {
	parameter "Mode batch" var: batch_mode among: [true];
	parameter "Max cycles" var: max_cycles among: [500];
	parameter "Number of Agents" var: nAgents among: [1000];
	parameter "Convergence speed" var: convergenceParam among: [0.5];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "Threshold" var: threshold among: [0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15,
		0.16, 0.17, 0.18, 0.19, 0.2, 0.22, 0.24, 0.25, 0.26, 0.27, 0.28, 0.29, 0.3, 0.35, 0.4, 0.45, 0.5];

	method exploration;

	// courbes[k-1] : points {d, nombre de simulations ayant k pics}, k = 7 pour "7 et plus"
	list<list<point>> courbes <- [[], [], [], [], [], [], []];
	list<rgb> couleurs <- [#black, #red, #blue, #green, #orange, #purple, #gray];
	list<point> courbe_moyenne <- [];
	list<point> courbe_pmax <- [];

	init {
		save ["d", "1 pic", "2 pics", "3 pics", "4 pics", "5 pics", "6 pics", "7+ pics", "moyenne", "nb simulations"]
			to: "figure4.csv" format: "csv" rewrite: true header: false;
	}

	reflex enregistrer {
		loop d over: remove_duplicates(simulations collect each.threshold) sort_by each {
			list<int> pics <- (simulations where (each.threshold = d)) collect each.nb_peaks;
			list<int> compte <- [];
			loop k from: 1 to: 7 {
				int c <- (k < 7) ? (pics count (each = k)) : (pics count (each >= 7));
				add c to: compte;
				list<point> courbe <- courbes[k - 1];
				add {d, c} to: courbe;
			}
			float moy <- mean(pics) with_precision 2;
			add {d, moy} to: courbe_moyenne;
			add {d, 1 / (2 * d)} to: courbe_pmax;
			write "d=" + d + " : " + compte + " (moyenne " + moy + ")";
			save [d, compte[0], compte[1], compte[2], compte[3], compte[4], compte[5], compte[6], moy, length(pics)]
				to: "figure4.csv" format: "csv" rewrite: false header: false;
		}
	}

	permanent {
		display Figure4 background: #white {
			chart "Nombre de simulations ayant k pics" type: xy x_range: [0, 0.5]
					x_label: "d" y_label: "simulations" {
				loop k from: 0 to: 6 {
					data (k = 6) ? "7+ pics" : ("" + (k + 1) + " pic(s)") value: courbes[k] style: line color: couleurs[k];
				}
			}
		}
		display Moyenne background: #white {
			chart "Nombre moyen de pics" type: xy x_range: [0, 0.5] y_range: [0, 10]
					x_label: "d" y_label: "pics" {
				data "moyenne" value: courbe_moyenne style: line marker_shape: marker_square color: #red;
				data "1/(2d)" value: courbe_pmax style: line color: #blue;
			}
		}
	}
}

// Export des donnees utilisees pour les figures du rapport (dossier models/export)
experiment Export_Figures type: batch repeat: 1 keep_seed: false until: cycle > export_max + 5 {
	parameter "Exporter" var: exporter among: [true];
	parameter "Cycles exportes" var: export_max among: [300];
	parameter "Stop at Cycle" var: stop_cycle among: [-1];
	parameter "Number of Agents" var: nAgents among: [1000];
	parameter "Threshold" var: threshold among: [0.1, 0.2, 0.5];
	parameter "Convergence speed" var: convergenceParam among: [0.05, 0.5];
	method exploration;
}
