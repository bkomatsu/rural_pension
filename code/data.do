*------------------------------------------------------------------------------*
* Dataset consolidation
*------------------------------------------------------------------------------*

*------------------------------------------------------------------------------*
**# 1. Sampling weights
*------------------------------------------------------------------------------*

	import excel using "${input_pof}/Pos_estratos_totais.xlsx", clear cellrange("A6:E5507") firstrow
	drop uf
	ren COD_UPAUFSEQDV COD_UPA
	save "${data}/Pos_estratos_totais", replace

*------------------------------------------------------------------------------*
**# 2. Deflator (INPC)
*------------------------------------------------------------------------------*

	* Consumer price index data obtained from IBGE
	* Data by metropolitan region/state capital and month, from 2012/01 to 2019/12
	* Importing data
	import excel using "${input_other}/tabela1100.xlsx", clear
	
	* Organizing data
	drop in 1/4
	drop in l
	gen mes = _n - trunc((_n -1) / 12)*12
	gen ano = real(ustrright(C,4))
	replace A = A[_n-1] if A == ""
	replace B = B[_n-1] if B == ""
	replace D = "" if D == "..."
	destring D, replace
	ren A codt
	gen uf = real(ustrleft(codt,2))
	destring codt, replace

	* Selecting territories if data for 2014
	gen v = D != . & mes == 9 & ano == 2014
	egen v2 = max(v), by(codt)
	drop if v2 == 0
	drop v v2
	
	* Calculating deflator
	gen capital = uf if codt > 10000
	keep if (ano >= 2015 & ano <= 2017) | (ano == 2014 & mes >= 9) | (ano == 2018 & mes == 1)
	bys codt (ano mes): gen ind_a = 1 + D / 100 if _n == 1
	bys codt (ano mes): replace ind_a = ind_a[_n-1] * (1 + D / 100) if _n > 1
	gen v = ind_a if ano == 2018 & mes == 1
	egen v2 = max(v), by(codt)
	gen def = v2 / ind_a

	keep if ano == 2014 & mes == 9
	keep uf def
	
	* Generating deflator for all states
	gen id = 1
	reshape wide def, i(id) j(uf)

	foreach i of numlist 11/14 16 17 21 22 24 25 27 28 42 51 {
		gen def`i' = .
	}

	reshape long def, i(id) j(uf)
	drop id

	gen mr = trunc(uf/10)
	egen def_m = mean(def), by(mr)
	replace def = def_m if def == .
	drop mr def_m

	save "${data}/def", replace


*------------------------------------------------------------------------------*
**# 3. Poverty Line (Rocha, Franco, and IETS)
*------------------------------------------------------------------------------*

	* Poverty lines obtained from Rocha, Franco, and IETS
	
	* Organizing data
	import excel using "${input_other}/pnad_-_linhas_de_pobreza_-_1985-2014.xls", clear
	keep A AZ
	drop in 1/6
	drop if A == ""
	drop in l
	destring AZ, replace

	gen regiao = A if AZ == .
	replace regiao = regiao[_n-1] if regiao == ""
	drop if AZ == .
	compress

	ren A area_s
	replace area_s = lower(area_s)
	replace area_s = subinstr(area_s," ","",.)

	forvalues i = 11/17 {
		cap drop lp`i'
		gen lp`i' = AZ if regiao == "Norte" & inlist(area_s, "urbano","rural")
	}
	replace lp15 = AZ if area == "belém"

	forvalues i = 21/29 {
		cap drop lp`i'
		gen lp`i' = AZ if regiao == "Nordeste" & inlist(area_s, "urbano","rural")
	}
	replace lp23 = AZ if area == "fortaleza"
	replace lp26 = AZ if area == "recife"
	replace lp29 = AZ if area == "salvador"

	forvalues i = 31/32 {
		cap drop lp`i'
		gen lp`i' = AZ if regiao == "Minas G./Esp.S." & inlist(area_s, "urbano","rural")
	}
	replace lp31 = AZ if area == "belohorizonte"

	gen lp33 = AZ if regiao == "Rio de Janeiro"
	gen lp35 = AZ if regiao == "São Paulo"

	forvalues i = 41/43 {
		cap drop lp`i'
		gen lp`i' = AZ if regiao == "Sul" & inlist(area_s, "urbano","rural")
	}
	replace lp41 = AZ if area == "curitiba"
	replace lp43 = AZ if area == "p.alegre"

	forvalues i = 50/53 {
		cap drop lp`i'
		gen lp`i' = AZ if regiao == "Centro-Oeste" & inlist(area_s, "urbano","rural")
	}
	replace lp53 = AZ if area == "brasília"
	replace lp52 = AZ if area == "goiânia"

	gen area = 2 if area_s == "urbano"
	replace area = 3 if area_s == "rural"
	replace area = 1 if area == .

	replace lp53 = . if area > 1
	drop area_s AZ regiao

	gen id = _n
	reshape long lp, i(area id) j(uf)
	drop id
	drop if lp == .

	sort uf area

	merge m:1 uf using "${data}/def.dta", nogen
	replace lp = lp * def
	drop def

	save "${data}/lp.dta", replace


*------------------------------------------------------------------------------*
**# 4. Final dataset for main analysis
*------------------------------------------------------------------------------*

* Final data is at the person level, with multiple variables for expenses and income

	*--------------------------------------------------------------------------*
	**# 4.1. Joining datasets
	*--------------------------------------------------------------------------*
	
	* Final dataset will be at the person level, data will be joined at the person
	* and family levels
	
	use "${input_pof}/DOMICILIO", clear
	keep $dom V6199
	tempfile dom
	save `dom'
	

	* Individual data
	use "${input_pof}/MORADOR.dta", clear

	* Total expenses dataset
	join, by($uc ) from("${data}/despesas_grupos.dta") nogen

	* Total expenses by form of acquisition
	join, by($uc ) from("${data}/despesas_grupos_aqm.dta") nogen

	* Total expenses by place of acquisition
	join, by($uc ) from("${data}/despesas_grupos_locinf.dta") nogen

	* Expenses in specific categories
	join, by($uc ) from("${data}/despesas_spec_cat.dta") nogen

	* Total income
	join, by($uc ) from("${data}/rendimentos_uc_grupos.dta") nogen

	* Individual income by aggregate groups
	join, by($morador ) from("${data}/rendimentos_morador_grupos.dta") nogen

	* Individual income by fine groups
	join, by($morador ) from("${data}/rendimentos_morador_codigos.dta") nogen

	* Durable goods inventory data
	join, by($uc ) from("${data}/despesas_dur.dta") nogen

	* Expenses with housing
	join, by($uc ) from("${data}/despesas_hab.dta")  nogen

	* Food security variables
	join, by($dom) from(`dom') nogen
	 
	* POF strata
	join, by(COD_UPA ESTRATO_POF) from("${data}/Pos_estratos_totais") nogen

	* Generating areas to join poverty lines data
	gen area = .
	replace area = 1 if ESTRATO_POF >= 1501 & ESTRATO_POF <= 1505
	replace area = 1 if ESTRATO_POF >= 2301 & ESTRATO_POF <= 2309
	replace area = 1 if ESTRATO_POF >= 2601 & ESTRATO_POF <= 2606
	replace area = 1 if ESTRATO_POF >= 2901 & ESTRATO_POF <= 2909
	replace area = 1 if ESTRATO_POF >= 3101 & ESTRATO_POF <= 3109
	replace area = 1 if ESTRATO_POF >= 3301 & ESTRATO_POF <= 3318
	replace area = 1 if ESTRATO_POF >= 3501 & ESTRATO_POF <= 3515
	replace area = 1 if ESTRATO_POF >= 4101 & ESTRATO_POF <= 4108
	replace area = 1 if ESTRATO_POF >= 4301 & ESTRATO_POF <= 4309
	replace area = 1 if ESTRATO_POF >= 5201 & ESTRATO_POF <= 5206
	replace area = 1 if ESTRATO_POF >= 5301 & ESTRATO_POF <= 5306

	replace area = 1 if ESTRATO_POF >= 5307 & ESTRATO_POF <= 5308

	replace area = 2 if inlist(ESTRATO_POF, 1101, 1102)
	replace area = 2 if ESTRATO_POF == 1201
	replace area = 2 if ESTRATO_POF >= 1301 & ESTRATO_POF <= 1307
	replace area = 2 if ESTRATO_POF >= 1401 & ESTRATO_POF <= 1402
	replace area = 2 if ESTRATO_POF >= 1601 & ESTRATO_POF <= 1603
	replace area = 2 if ESTRATO_POF == 1701
	replace area = 2 if ESTRATO_POF >= 2101 & ESTRATO_POF <= 2104
	replace area = 2 if ESTRATO_POF >= 2201 & ESTRATO_POF <= 2203
	replace area = 2 if ESTRATO_POF >= 2401 & ESTRATO_POF <= 2403
	replace area = 2 if ESTRATO_POF >= 2501 & ESTRATO_POF <= 2505
	replace area = 2 if ESTRATO_POF >= 2701 & ESTRATO_POF <= 2704
	replace area = 2 if ESTRATO_POF >= 2801 & ESTRATO_POF <= 2803
	replace area = 2 if ESTRATO_POF >= 3201 & ESTRATO_POF <= 3205
	replace area = 2 if ESTRATO_POF >= 4201 & ESTRATO_POF <= 4204
	replace area = 2 if ESTRATO_POF >= 5001 & ESTRATO_POF <= 5003
	replace area = 2 if ESTRATO_POF >= 5101 & ESTRATO_POF <= 5103

	replace area = 2 if ESTRATO_POF >= 1103 & ESTRATO_POF <= 1107
	replace area = 2 if ESTRATO_POF == 1202
	replace area = 2 if ESTRATO_POF >= 1308 & ESTRATO_POF <= 1310
	replace area = 2 if ESTRATO_POF == 1403
	replace area = 2 if ESTRATO_POF >= 1506 & ESTRATO_POF <= 1511
	replace area = 2 if ESTRATO_POF == 1604
	replace area = 2 if ESTRATO_POF >= 1702 & ESTRATO_POF <= 1705
	replace area = 2 if ESTRATO_POF >= 2105 & ESTRATO_POF <= 2113
	replace area = 2 if ESTRATO_POF >= 2204 & ESTRATO_POF <= 2209
	replace area = 2 if ESTRATO_POF >= 2310 & ESTRATO_POF <= 2320
	replace area = 2 if ESTRATO_POF >= 2404 & ESTRATO_POF <= 2408
	replace area = 2 if ESTRATO_POF >= 2506 & ESTRATO_POF <= 2511
	replace area = 2 if ESTRATO_POF >= 2607 & ESTRATO_POF <= 2615
	replace area = 2 if ESTRATO_POF >= 2705 & ESTRATO_POF <= 2708
	replace area = 2 if ESTRATO_POF >= 2804 & ESTRATO_POF <= 2806
	replace area = 2 if ESTRATO_POF >= 2910 & ESTRATO_POF <= 2925
	replace area = 2 if ESTRATO_POF >= 3110 & ESTRATO_POF <= 3130
	replace area = 2 if ESTRATO_POF >= 3206 & ESTRATO_POF <= 3211
	replace area = 2 if ESTRATO_POF >= 3319 & ESTRATO_POF <= 3330
	replace area = 2 if ESTRATO_POF >= 3516 & ESTRATO_POF <= 3536
	replace area = 2 if ESTRATO_POF >= 4109 & ESTRATO_POF <= 4124
	replace area = 2 if ESTRATO_POF >= 4205 & ESTRATO_POF <= 4217
	replace area = 2 if ESTRATO_POF >= 4310 & ESTRATO_POF <= 4324
	replace area = 2 if ESTRATO_POF >= 5004 & ESTRATO_POF <= 5009
	replace area = 2 if ESTRATO_POF >= 5104 & ESTRATO_POF <= 5112
	replace area = 2 if ESTRATO_POF >= 5207 & ESTRATO_POF <= 5217

	replace area = 3 if ESTRATO_POF >= 1108 & ESTRATO_POF <= 1111
	replace area = 3 if ESTRATO_POF >= 1203 & ESTRATO_POF <= 1204
	replace area = 3 if ESTRATO_POF >= 1311 & ESTRATO_POF <= 1316
	replace area = 3 if ESTRATO_POF >= 1404 & ESTRATO_POF <= 1405
	replace area = 3 if ESTRATO_POF >= 1512 & ESTRATO_POF <= 1519
	replace area = 3 if ESTRATO_POF >= 1605 & ESTRATO_POF <= 1607
	replace area = 3 if ESTRATO_POF >= 1706 & ESTRATO_POF <= 1708
	replace area = 3 if ESTRATO_POF >= 2114 & ESTRATO_POF <= 2125
	replace area = 3 if ESTRATO_POF >= 2210 & ESTRATO_POF <= 2217
	replace area = 3 if ESTRATO_POF >= 2321 & ESTRATO_POF <= 2330
	replace area = 3 if ESTRATO_POF >= 2409 & ESTRATO_POF <= 2412
	replace area = 3 if ESTRATO_POF >= 2512 & ESTRATO_POF <= 2518
	replace area = 3 if ESTRATO_POF >= 2616 & ESTRATO_POF <= 2624
	replace area = 3 if ESTRATO_POF >= 2709 & ESTRATO_POF <= 2713
	replace area = 3 if ESTRATO_POF >= 2807 & ESTRATO_POF <= 2810
	replace area = 3 if ESTRATO_POF >= 2926 & ESTRATO_POF <= 2942
	replace area = 3 if ESTRATO_POF >= 3131 & ESTRATO_POF <= 3149
	replace area = 3 if ESTRATO_POF >= 3212 & ESTRATO_POF <= 3215
	replace area = 3 if ESTRATO_POF >= 3331 & ESTRATO_POF <= 3337
	replace area = 3 if ESTRATO_POF >= 3537 & ESTRATO_POF <= 3553
	replace area = 3 if ESTRATO_POF >= 4125 & ESTRATO_POF <= 4135
	replace area = 3 if ESTRATO_POF >= 4218 & ESTRATO_POF <= 4226
	replace area = 3 if ESTRATO_POF >= 4325 & ESTRATO_POF <= 4335
	replace area = 3 if ESTRATO_POF >= 5010 & ESTRATO_POF <= 5013
	replace area = 3 if ESTRATO_POF >= 5113 & ESTRATO_POF <= 5118
	replace area = 3 if ESTRATO_POF >= 5218 & ESTRATO_POF <= 5225

	gen uf = UF
	join, by(uf area ) from("${data}/lp.dta")
	drop if _merge == 1
	drop _merge
	drop uf
	  
	*--------------------------------------------------------------------------*
	**# 4.2. Creating variables for the analysis
	*--------------------------------------------------------------------------*

	* Retirement dummy - INSS
	gen aposentado = 1 if (											///
		(rendimento_i_mes_54004 > 0 & rendimento_i_mes_54004 != .)|	///
		(rendimento_i_mes_55003 > 0 & rendimento_i_mes_55003 != .)	///
		)
	replace aposentado = 0 if aposentado == .

	* High-school degree
	gen high_school = INSTRUCAO ==5 | INSTRUCAO == 6 | INSTRUCAO == 7

	* Race composition
	gen ppi = inlist(V0405,2,4,5) if V0405 < 9

	* Alfab
	gen alf = V0414 == 1

	* Dummies de sexo
	tab V0404, gen(sexo)
	
	* Income from old-age pension - INSS
	egen pensions = rowtotal(rendimento_i_mes_54004 rendimento_i_mes_55003)

	* Family size
	gen tag = 1  
	egen tamanho = total(tag), by($uc)
	drop tag

	* Age - discrete variable
	gen idade = V0403

	* Group expenditure variables
	
	* Aggregate expenditure variables
	
	egen ndg = rowtotal(	/// Non-durable goods and services:
		despesa_1101 		/// Food
		despesa_1103 		/// Clothing
		despesa_1105 		/// Hygiene and personal care
		despesa_1108  		/// Recreation and culture
		despesa_1109 		/// Tobacco
		despesa_1110		/// Personal services
		)
	
	egen oth = rowtotal(	/// Other expenses
		despesa_1102 		/// Housing
		despesa_1104 		/// Transport
		despesa_1111 		/// Other
		despesa_12 			/// Other current expenses
		despesa_2			/// Assets increase
		despesa_3			/// Liabilities reduction
		)
		
	egen edhc = rowtotal(despesa_1106 despesa_1107)	// Education and health

	egen prp = rowtotal(	/// Housing, Transport and expenses with property
		despesa_21 			///
		despesa_22 			///
		despesa_32 			///
		despesa_1102 		///
		despesa_1104)

	egen inv = rowtotal(	/// Household investment in real state
		despesa_21 			///
		despesa_22 			///
		despesa_32)

	foreach i in aqo aqav aqap out for inf {
		egen inv_`i' = rowtotal(	/// Household investment in real state
			despesa_`i'_21 			///
			despesa_`i'_22 			///
			despesa_`i'_32)
		
	}
	
	* Consumo não durável por tipo e local de aquisição
	foreach i in aqo aqav aqap inf for out {
		
		egen ndg_`i' = rowtotal(	/// Non-durable goods and services:
			despesa_`i'_1101 		/// Food
			despesa_`i'_1103 		/// Clothing
			despesa_`i'_1105 		/// Hygiene and personal care
			despesa_`i'_1108  		/// Recreation and culture
			despesa_`i'_1109 		/// Tobacco
			despesa_`i'_1110		/// Personal services
			)
			
	}

	egen ndg_loc = rowtotal(ndg_for ndg_inf)
	egen ndg_aqm = rowtotal(ndg_aqav ndg_aqap)
	egen inv_aqm = rowtotal(inv_aqav inv_aqap)
	egen despesa_aqm_dr0 = rowtotal(despesa_aqav_dr0 despesa_aqap_dr0)
	egen despesa_aqm_dr1 = rowtotal(despesa_aqav_dr1 despesa_aqap_dr1)
	egen despesa_aqm_dr2 = rowtotal(despesa_aqav_dr2 despesa_aqap_dr2)
	egen despesa_loc_1101 = rowtotal(despesa_for_1101 despesa_inf_1101)
	egen despesa_aqm_1101 = rowtotal(despesa_aqav_1101 despesa_aqap_1101)
	
	* Variable list
	global xplist ndg oth prp inv edhc 			///
		ndg_aqo ndg_aqm ndg_aqav ndg_aqap		///
		ndg_inf ndg_for	ndg_loc ndg_out			///
		inv_aqav inv_aqap inv_aqm inv_aqo		///
		inv_out inv_for inv_inf 				///
		despesa_12 despesa_23 					///
		despesa_31								///
		despesa_1101 despesa_1103 				///
		despesa_1105 despesa_1108 				///
		despesa_1109 despesa_1110				///
		despesa_dr0 despesa_dr1 despesa_dr2		///
		despesa_aqav_dr0 despesa_aqap_dr0 despesa_aqm_dr0 despesa_aqo_dr0 ///
		despesa_aqav_dr1 despesa_aqap_dr1 despesa_aqm_dr1 despesa_aqo_dr1 ///
		despesa_aqav_dr2 despesa_aqap_dr2 despesa_aqm_dr2 despesa_aqo_dr2 ///
		despesa_inf_dr0 despesa_for_dr0 despesa_out_dr0 ///
		despesa_inf_dr1 despesa_for_dr1 despesa_out_dr1 ///
		despesa_inf_dr2 despesa_for_dr2 despesa_out_dr2 ///
		despesa_aqo_1101 despesa_aqap_1101 despesa_aqav_1101 despesa_aqm_1101	///
		despesa_inf_1101 despesa_for_1101 despesa_out_1101 despesa_loc_1101 	///
		despesa_sc*								///
		despesa_0
		
	* Labeling variables
	local suflpc " - Ln per capita"
	local sufipc " - IHS per capita"
	local sufpc " - Per capita"
	local sufp " - Prop. positive"
	
	local labdespesa_0 "Expenditure"

	local labdespesa_1 "Current Expenses"
	local labdespesa_2 "Assets increase"
	local labdespesa_3 "Liabilities reduction"

	local labdespesa_11 "Consumption"
	local labdespesa_12 "Other current exp."
	local labdespesa_21 "Property"
	local labdespesa_22 "Reforms"
	local labdespesa_23 "Other investments"
	local labdespesa_31 "Loans"
	local labdespesa_32 "Mortgage"

	local labdespesa_1101 "Food"
	local labdespesa_1102 "Housing"
	local labdespesa_1103 "Clothing"
	local labdespesa_1104 "Transport"
	local labdespesa_1105 "Hygiene and personal care"
	local labdespesa_1106 "Healthcare"
	local labdespesa_1107 "Education"
	local labdespesa_1108 "Recreation and culture"
	local labdespesa_1109 "Tobacco"
	local labdespesa_1110 "Personal services"
	local labdespesa_1111 "Miscellaneous expenses"

	local labdespesa_1201 "Taxes"
	local labdespesa_1202 "Labor contrib."
	local labdespesa_1203 "Banking fees"
	local labdespesa_1204 "Child support and donations"
	local labdespesa_1205 "Private pension"
	local labdespesa_1206 "Other current exp."

	* Desagregação de 1201
	local labdespesa_sc1 "Real State-related Taxes"		
	local labdespesa_sc2 "Vehicle-related Taxes"
	local labdespesa_sc3 "Labor-related taxes"

	* Desagregação de 1204
	local labdespesa_sc4 "Child support and personal donations"
	local labdespesa_sc5 "Donations to third parties"

	* Desagregação de 1102 e 1104
	local labdespesa_dr0 "Current expenses in home appliances, housing and transport"
	local labdespesa_dr1 "Purchases in home appliances, housing and transport"
	local labdespesa_dr2 "Maintenance in home appliances, housing and transport"

	* Desagregação de 1102 e 1104 e formas de aquisição
	local labdespesa_aqav_dr0 "Current expenses in home appliances, housing and transport - monetary, lumpsum"
	local labdespesa_aqap_dr0 "Current expenses in home appliances, housing and transport - monetary, installments"
	local labdespesa_aqm_dr0 "Current expenses in home appliances, housing and transport - monetary"
	local labdespesa_aqo_dr0 "Current expenses in home appliances, housing and transport - non-monetary"
	local labdespesa_aqav_dr1 "Purchases in home appliances, housing and transport - monetary, lumpsum"
	local labdespesa_aqap_dr1 "Purchases in home appliances, housing and transport - monetary, installments"
	local labdespesa_aqm_dr1 "Purchases in home appliances, housing and transport - monetary"
	local labdespesa_aqo_dr1 "Purchases in home appliances, housing and transport - non-monetary"
	local labdespesa_aqav_dr2 "Maintenance in home appliances, housing and transport - monetary, lumpsum"
	local labdespesa_aqap_dr2 "Maintenance in home appliances, housing and transport - monetary, installments"
	local labdespesa_aqm_dr2 "Maintenance in home appliances, housing and transport - monetary"
	local labdespesa_aqo_dr2 "Maintenance in home appliances, housing and transport - non-monetary"
	
	local labdespesa_for_dr0 "Current expenses in home appliances, housing and transport - formal places"
	local labdespesa_inf_dr0 "Current expenses in home appliances, housing and transport - informal places"
	local labdespesa_out_dr0 "Current expenses in home appliances, housing and transport - other places"
	local labdespesa_for_dr1 "Purchases in home appliances, housing and transport - formal places"
	local labdespesa_inf_dr1 "Purchases in home appliances, housing and transport - informal places"
	local labdespesa_out_dr1 "Purchases in home appliances, housing and transport - other places"
	local labdespesa_for_dr2 "Maintenance in home appliances, housing and transport - formal places"
	local labdespesa_inf_dr2 "Maintenance in home appliances, housing and transport - informal places"
	local labdespesa_out_dr2 "Maintenance in home appliances, housing and transport - other places"
		
	local labdespesa_aqav_1101 "Food - monetary, lumpsum"
	local labdespesa_aqap_1101 "Food - monetary, installments"
	local labdespesa_aqm_1101 "Food - monetary"
	local labdespesa_aqo_1101 "Food - non-monetary"
	local labdespesa_for_1101 "Food - formal places"
	local labdespesa_inf_1101 "Food - informal places"
	local labdespesa_out_1101 "Food - undefined places"
	local labdespesa_loc_1101 "Food - defined places"
	
	* Consumption groups
	local labndg "Nondurable goods"
	local laboth "Other expenses"
	local labprp "Expenses with property"
	local labinv "Investment in real state"
	local labedhc "Education and health"
	
	local labndg_aqo "Nondurable goods - Non-monetary"
	local labndg_aqav "Nondurable goods - Monetary, lump sum"
	local labndg_aqap "Nondurable goods - Monetary, installments"
	local labndg_aqm "Nondurable goods - Monetary"
	local labndg_inf "Nondurable goods - Informal place"
	local labndg_for "Nondurable goods - Formal place"
	local labndg_loc "Nondurable goods - Existing place"
	local labndg_out "Nondurable goods - No place"
	
	local labinv_aqav "Investment in real state - Monetary, lump sum"
	local labinv_aqap "Investment in real state - Monetary, installments"
	local labinv_aqo "Investment in real state - Non-monetary"
	
	local labinv_out "Investment in real state - non-defined places"
	local labinv_for "Investment in real state - formal"
	local labinv_inf "Investment in real state - informal"
	
	local labinv_ac_aqav "Acquisition of durable goods - Monetary, lump sum"
	local labinv_ac_aqap "Acquisition of durable goods - Monetary, installments"
	local labinv_ac_aqo "Acquisition of durable goods - Non-monetary"
	
	* Transformations
	foreach v of varlist $xplist {
		
		if strpos("`v'","despesa") > 0 {
			local name = subinstr("`v'","despesa_","",.)
			local lname "labdespesa_`name'"
		}
		else {
			local name = "`v'"
			local lname "lab`v'"
		}
		
		* Log of per capita variable
		gen lpc_`name' = log(1 + `v' / tamanho)
		label var lpc_`name' "``lname''`suflpc'"
		
		* IHS
		gen ipc_`name' = log(`v'/tamanho + ((`v'/tamanho)^2 + 1)^0.5)
		label var ipc_`name' "``lname''`sufipc'"
		
		* Proportion of positive expenditure
		gen p_`name' = `v' > 0
		label var p_`name' "``lname''`sufp'"
		
		* Per capita variable
		gen pc_`name' = `v' / tamanho
		label var pc_`name' "``lname''`sufpc'"
		
	}


	* Income variables
		
	* Aggregating income sources
	egen rendimento_oth = rowtotal(rendimento_i_mes_13 rendimento_i_mes_14)
	egen rendimento_tra = rowtotal(rendimento_i_mes_126 rendimento_i_mes_125 rendimento_i_mes_124 )
	egen rendimento_nli = rowtotal(rendimento_i_mes_12 rendimento_oth)
	egen rendimento_tot = rowtotal(rendimento_i_mes_11 rendimento_nli)
	egen empr = rowtotal(rendimento_i_mes_55016 rendimento_i_mes_54012 rendimento_i_mes_54013)
	
	* Labeling variables
	local suflin " - Ln"
	local sufiin " - IHS"
	local sufpin " - Prop. positive"
	local labrendimento_i_mes_11 "Labor income"
	local labrendimento_i_mes_12 "Income from transfers"
	local labrendimento_i_mes_13 "Income from rent"
	local labrendimento_i_mes_14 "Income from other sources"
	local labrendimento_i_mes_111 "Labor income - employee"
	local labrendimento_i_mes_112 "Labor income - employer"
	local labrendimento_i_mes_113 "Labor income - self-employed"
	local labrendimento_i_mes_121 "Income from federal pensions"
	local labrendimento_i_mes_122 "Income from other public pensions"
	local labrendimento_i_mes_123 "Income from private pensions"
	local labrendimento_i_mes_124 "Income from social programs"
	local labrendimento_i_mes_125 "Income from other pensions"
	local labrendimento_i_mes_126 "Income from other transfers"
	local labrendimento_i_mes_55016 "Income from loans"
	local labrendimento_oth "Income from rent and oter sources"
	local labrendimento_tra "Income from transfers"
	local labrendimento_nli "Non-labor income"
	local labrendimento_tot "Total individual income"
	local labempr "Income from loans and donations"
	
	foreach v of varlist 											///
		rendimento_i_mes_11 	///
		rendimento_i_mes_111 	///
		rendimento_i_mes_112 	///
		rendimento_i_mes_113 	///
		rendimento_i_mes_121 	///
		rendimento_i_mes_122 	///
		rendimento_i_mes_123 	///
		rendimento_nli 	///
		rendimento_oth 	///
		rendimento_tra	///
		rendimento_tot	///
		empr			///	
		{
		
		label var `v' "`lab`v''"
		
		local nome = subinstr("`v'","rendimento_","",.)
		
		* log(y + 1) transformation of income and earnings categories
		gen lin_`nome' = log(1 + `v')
		label var lin_`nome' "`lab`v''`suflin'"
	  
		* IHS transformation of income and earnings categories
		gen iin_`nome' = log(`v' + (`v'^2 + 1)^0.5)
		label var iin_`nome' "`lab`v''`sufiin'"
	  
		* Dummies for income sources
		gen pin_`nome' = `v' > 0
		label var pin_`nome' "`lab`v''`sufpin'"

	}

	* Total family income
	gen tin = RENDA_TOTAL
	replace tin = 0 if tin == .
	
	* Log of per capita income
	gen lin_tin = log(1 + tin / tamanho)

	* IHS transformation of per capita income
	gen iin_tin = log(tin/tamanho + ((tin/tamanho)^2 + 1)^0.5)

	* Proportion of positive income
	gen pin_tin = tin > 0

	* Per capita total income
	gen pc_tin = tin / tamanho

	* Working status
	gen po = V0407 == 1 if V0407 <= 2
	
	* Adjusting labor market variables for people who might work
	foreach i of numlist 11 111 112 113 {
		replace dren_`i' = . if po == .
	}
	
	replace horas_0 = . if po == .
	replace horas_111 = . if po == .
	replace horas_112 = . if po == .
	replace horas_113 = . if po == .
	gen po_nr = po - dren_11
	
	* Age equal or above threshold
	gen m55 = idade >= 55

	* Poverty
	egen rmon_uc = rowtotal(rend_uc_11 rend_uc_12 rend_uc_13 rend_uc_14)
	gen pc_rmon = rmon_uc / tamanho
	gen lin_rmon = log(1 + pc_rmon)
	gen iin_rmon = log(pc_rmon + ((pc_rmon)^2 + 1)^0.5)

	gen poor = pc_rmon <= lp

	* Sample selection
	gen ref_fem = 1 if inlist(V0306, 1, 2, 3) & V0404 == 2
	egen ref_fem_t = total(ref_fem ), by($uc)

	gen ref_mas = 1 if inlist(V0306, 1, 2, 3) & V0404 == 1
	egen ref_mas_t = total(ref_mas ), by($uc)

	* Filters
	gen am_fem = 			///
		ref_fem_t == 1 & 	///
		ref_fem == 1 & 		///
		V0404 == 2 & 		///
		TIPO_SITUACAO_REG == 2 & 	///
		idade <= $imax & 			///
		idade >=$imin & 			///
		idade !=. &					///
		RENDA_TOTAL != 0 &			///
		ndg != 0

	gen am_mas = 			///
		ref_mas_t == 1 & 	///
		ref_mas == 1 & 		///
		V0404 == 1 & 		///
		TIPO_SITUACAO_REG == 2 & 	///
		idade <= $imax & 			///
		idade >=$imin & 			///
		idade !=. &					///
		RENDA_TOTAL != 0 &			///
		ndg != 0
	
	* Food security
	qui tab V6199, gen(sa)		

	* Per capita HH income excluding federal pensions
	gen pc_rapos = (tin - rend_uc_121) / tamanho

	* Individual income excluding federal pensions
	egen rendimento_12sa = rowtotal(rendimento_i_mes_122 rendimento_i_mes_123 rendimento_tra rendimento_oth)
	
	* Poverty calculated with no federal pension
	egen rmonsa_uc = rowtotal(rend_uc_11 rend_uc_122 rend_uc_123 rend_uc_124 rend_uc_125 rend_uc_126 rend_uc_13 rend_uc_14)
	gen pc_rmonsa = rmonsa_uc / tamanho
	gen poor_sa = pc_rmonsa <= lp
	
	* Savings
	gen saving = pc_tin - pc_0

	* Age normalized by age cutoffs
	gen idade_p = idade - 55 if am_fem == 1
	replace idade_p = idade - 60 if am_mas == 1

	* Subsamples
	
	* Family has a woman in the sample
	egen am_fem_uc = max(am_fem), by($uc )

	* Family has a man in the sample
	egen am_mas_uc = max(am_mas), by($uc )

	* Couple's age
	gen v = idade if am_fem == 1
	egen idade_femuc = max(v), by($uc )
	drop v 

	gen v = idade if am_mas == 1
	egen idade_masuc = max(v), by($uc )
	drop v 

	* Subsample 1 - Women who live with no partner
	cap drop am_uc_al1 
	gen am_uc_al1 = 1 if am_fem == 1 & am_mas_uc == 0

	* Subsample 2 - Women who live with a partner, excluding those whose partner is 5 years older
	cap drop am_uc_al2
	gen am_uc_al2 = 1 if am_fem == 1 & am_mas_uc == 1 & (idade_masuc - idade_femuc) != 5

	* Subsample 3 - Women who live with a partner, excluding those whose partner is less than 5 years older
	cap drop am_uc_al3
	gen am_uc_al3 = 1 if am_fem == 1 & am_mas_uc == 1 & (idade_masuc - idade_femuc) < 5

	* Subsample 4 - Women who live with a partner, excluding those whose partner is more than 5 years older
	cap drop am_uc_al4
	gen am_uc_al4 = 1 if am_fem == 1 & am_mas_uc == 1 & (idade_masuc - idade_femuc) > 5

	* Variables used in the analysis
	keep 						///
		alf 					///
		am_fem					///
		am_uc_al1				///
		am_uc_al2				///
		am_uc_al3				///
		am_uc_al4				///
		ANOS_ESTUDO				///
		aposentado				///
		dren_11					///
		dren_111				///
		dren_112				///
		dren_113				///
		horas_0					///
		horas_111				///
		horas_112				///
		horas_113				///
		idade					///
		idade_p					///
		iin_tin					///
		ipc_0					///
		ipc_edhc				///
		ipc_ndg					///
		ipc_oth					///
		lin_empr				///
		lin_i_mes_11			///
		lin_i_mes_111			///
		lin_i_mes_112			///
		lin_i_mes_113			///
		lin_i_mes_121			///
		lin_i_mes_122			///
		lin_i_mes_123			///
		lin_nli					///
		lin_oth					///
		lin_tin					///
		lin_tra					///
		lpc_0					///
		lpc_1101				///
		lpc_1103				///
		lpc_1105				///
		lpc_1108				///
		lpc_1109				///
		lpc_1110				///
		lpc_23					///
		lpc_31					///
		lpc_aqap_1101			///
		lpc_aqap_dr1			///
		lpc_aqav_1101			///
		lpc_aqav_dr1			///
		lpc_aqm_1101			///
		lpc_aqo_1101			///
		lpc_aqo_dr1				///
		lpc_dr0					///
		lpc_dr1					///
		lpc_dr2					///
		lpc_edhc				///
		lpc_for_1101			///
		lpc_inf_1101			///
		lpc_inv					///
		lpc_inv_aqap			///
		lpc_inv_aqav			///
		lpc_inv_aqo				///
		lpc_loc_1101			///
		lpc_ndg					///
		lpc_oth					///
		lpc_out_1101			///
		lpc_sc1					///
		lpc_sc2					///
		lpc_sc3					///
		lpc_sc4					///
		lpc_sc5					///
		m55						///
		p_31					///
		p_inv					///
		p_dr0					///
		p_dr1 					///
		p_dr2 					///
		p_23					///
		p_sc1					///
		p_sc2					///
		p_sc3					///
		p_sc4					///
		p_sc5					///
		pc_0					///
		pc_edhc					///
		pc_ndg					///
		pc_oth					///
		pc_rapos				///
		pc_rmon					///
		pc_tin					///
		pensions				///
		PESO_FINAL				///
		pin_empr				///
		pin_i_mes_11			///
		pin_i_mes_111			///
		pin_i_mes_112			///
		pin_i_mes_113			///
		pin_i_mes_121			///
		pin_i_mes_122			///
		pin_i_mes_123			///
		pin_nli					///
		pin_oth					///
		pin_tra					///
		po						///
		po_nr					///
		poor					///
		poor_sa					///
		ppi						///
		pqt1-pqt99				///
		qt151-qt1599			///
		qtt1-qtt99				///
		rendimento_12sa			///
		rendimento_i_mes_11		///
		rendimento_i_mes_111	///
		rendimento_i_mes_112	///
		rendimento_i_mes_113	///
		rendimento_i_mes_121	///
		rendimento_i_mes_122	///
		rendimento_i_mes_123	///
		rendimento_i_mes_124	///
		rendimento_i_mes_125	///
		rendimento_i_mes_126	///
		rendimento_i_mes_13		///
		rendimento_i_mes_14		///
		rendimento_i_mes_54004	///
		rendimento_i_mes_55003	///
		rendimento_nli			///
		rendimento_oth			///
		rendimento_tra			///
		sa1						///
		sa2						///
		sa3						///
		sa4						///
		saving					///
		tamanho					///
		TIPO_SITUACAO_REG


	save "${data}/base.dta", replace
