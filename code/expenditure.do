*------------------------------------------------------------------------------*
* Expenditure Data
*------------------------------------------------------------------------------*

* Creates consumption data, using IBGE product aggregation, with the following steps:

* 1. Create dataset with all families
* 2. Read expenditure correlations to IBGE aggregate categories
* 3. Read place of purchase correlations
* 3. Create consumption expenditure datasets
* 4. Create deductions/tax expenditure datasets
* 5. Appends all expenditures, aggregate at family level, with variables for IBGE consumption categories
* 6. Create dataset at family level, with variables for expenses with current durable goods
* 7. Create dataset at family level, with variables for expenses with investment in durable goods
* 8. Create dataset at family level, with information on durable goods

*------------------------------------------------------------------------------*
**# 1. Family dataset
*------------------------------------------------------------------------------*
	
	* Dataset used to complete income and expenses data with zeros
	use "${input_pof}/MORADOR.dta", clear
	keep $uc
	duplicates drop
	save "${data}/uc.dta", replace
	
*------------------------------------------------------------------------------*
**# 2. POF expenditure correlations
*------------------------------------------------------------------------------*

	import excel "${input_pof}/Tradutor_Despesa_Geral.xls", sheet("Planilha1") firstrow clear
	save "${data}/tradutor_despesa.dta", replace

*------------------------------------------------------------------------------*
**# 3. Place of purchase correlations
*------------------------------------------------------------------------------*
	
	* 2009 POF Croswalk
	* Code obtained from the replication codes of Bachas, Gadenne, and Jensen (2024)
	import excel using "${input_other}/BR_POF_crosswalk_TOR_3dig.xlsx", clear firstrow
	keep local_3dig TOR_original_name concatenated
	ren local_3dig codloc3
	ren concatenated descloc2009
	tempfile cw09
	save `cw09'

	* 2017-2018 POF Place of purchase registry
	import excel using "${input_pof}/Cadastro de Locais de Aquisição.xls", clear firstrow

	d, varlist
	local v1 codloc
	local v2 descloc
	local ind 1
	foreach v in `r(varlist)' {
		ren `v' `v`ind''
		
		local ind = `ind' + 1
	}

	gen codloc3 = ustrleft(codloc, 3)
	drop codloc
	bysort codloc: gen id = _n
	reshape wide descloc, i(codloc3) j(id)

	forvalues i = 1/31 {
		if `i' == 1 local codigo = `"descloc`i'"'
		else local codigo = `"`codigo' + ", " + descloc`i'"'
	}
	gen descloc = `codigo'
	drop descloc1-descloc31
	
	merge 1:1 codloc3 using `cw09'
	drop if _merge == 2

	* Completing classification
	replace TOR_original_name = "small market" if codloc3 == "006"
	replace TOR_original_name = "health institution" if codloc3 == "042"
	replace TOR_original_name = "internet" if codloc3 == "163"
	replace TOR_original_name = "health institution" if codloc3 == "166"
	replace TOR_original_name = "health institution" if codloc3 == "164"
	replace TOR_original_name = "health institution" if codloc3 == "167"
	replace TOR_original_name = "fair" if codloc3 == "168"
	replace TOR_original_name = "fair" if codloc3 == "169"
	replace TOR_original_name = "small shop" if codloc3 == "165"
	replace TOR_original_name = "specialized shop" if codloc3 == "135"

	drop descloc2009 _merge

	gen informal = .
	replace informal = 1 if inlist(TOR_original_name,"bar-cafe","fair","from farm","grocery store","market","own production")
	replace informal = 1 if inlist(TOR_original_name,"own production_from other household","private service","recreation events","small market","small shop","street seller")
	replace informal = 0 if informal == . & TOR_original_name != "unspecified"
	keep codloc3 informal
	destring codloc3, replace

	save "${data}/BR_POF_crosswalk_TOR_3dig_2017", replace

*------------------------------------------------------------------------------*
**# 3. Expenditure datasets
*------------------------------------------------------------------------------*
 
	clear   
	append using "${input_pof}/DESPESA_COLETIVA.dta"
	append using "${input_pof}/CADERNETA_COLETIVA.dta"
	append using "${input_pof}/ALUGUEL_ESTIMADO.dta"
	append using "${input_pof}/DESPESA_INDIVIDUAL.dta"

	* Average monthly expenditures
	* Some values are originally expressed in months, so it is necessary to multiply them by the number of months received (V9011)
	gen despesa_mes = (V8000_DEFLA*FATOR_ANUALIZACAO)/12 if !inlist(QUADRO, 0, 10, 19, 44, 47, 48, 49, 50)
	replace despesa_mes = (V8000_DEFLA*V9011*FATOR_ANUALIZACAO)/12 if inlist(QUADRO, 0, 10, 19, 44, 47, 48, 49, 50)
	  
	* 5-digit product code to merge with POF expenditure correlations
	gen Codigo = round(V9001/100) 

	* We aggregate expenditures by product code and family for our main analysis.
	* For supplementary analysis, we additionally, we aggregate them by form of 
	* acquisition and place of acquisition

	tempfile expenses
	save `expenses'


	*--------------------------------------------------------------------------*
	**## 3.1. Expenditure aggregated by family and product code
	*--------------------------------------------------------------------------*

		use `expenses', clear
		collapse (sum) despesa_mes, by($uc Codigo)

		gen Variavel = "V8000_DEFLA"

		save "${data}/despesas_padrao.dta", replace


	*--------------------------------------------------------------------------*
	**## 3.2. Expenditure aggregated by family and product code and form of acquisition
	*--------------------------------------------------------------------------*

		use `expenses', clear
		
		* Forms of acquisition - monetary or other
		* Generating suffixes
		gen aqm = "_aqav" if inrange(V9002,1,2)
		replace aqm = "_aqap" if inrange(V9002,3,6)
		replace aqm = "_aqo" if inrange(V9002,7,11)
				
		collapse (sum) despesa_mes, by($uc Codigo aqm)
		greshape wide despesa_mes, i($uc Codigo) j(aqm) string

		gen Variavel = "V8000_DEFLA"

		save "${data}/despesas_padrao_aqm.dta", replace

	*--------------------------------------------------------------------------*
	**## 3.3. Expenditure aggregated by family and product code and place of acquisition
	*--------------------------------------------------------------------------*

		use `expenses', clear
		
		* Place of acquisition
		gen codloc3 = trunc(V9004/100)

		* Correlation of places of acquisition to formal or informal
		join, from("${data}/BR_POF_crosswalk_TOR_3dig_2017") by(codloc3)
		drop if _merge == 2
		drop _merge
		
		* Ajustments
		replace informal = 0 if inlist(V9004,509)	// Markets
		replace informal = 0 if QUADRO == 19 & V1904 != .
		replace informal = 1 if QUADRO == 19 & V1904 == .
		
		* Generating suffixes
		gen locinf = "_inf" if informal == 1
		replace locinf = "_for" if informal == 0
		replace locinf = "_out" if informal == .

		collapse (sum) despesa_mes, by($uc Codigo locinf)
		greshape wide despesa_mes, i($uc Codigo) j(locinf) string
		replace despesa_mes_for = 0 if despesa_mes_for == .
		replace despesa_mes_inf = 0 if despesa_mes_inf == .
		replace despesa_mes_out = 0 if despesa_mes_out == .

		gen Variavel = "V8000_DEFLA"

		save "${data}/despesas_padrao_locinf.dta", replace

*------------------------------------------------------------------------------*
**# 4. Expenses with deductions - income tax, pension, etc (V1904_DEFLA, V531112_DEFLA, V531122_DEFLA, V531132_DEFLA, V8501_DEFLA)
*------------------------------------------------------------------------------*

	clear 
	append using "${input_pof}/OUTROS_RENDIMENTOS.dta"
	append using "${input_pof}/RENDIMENTO_TRABALHO.dta"
	append using "${input_pof}/DESPESA_COLETIVA.dta"
	
	keep if (V1904_DEFLA!=.)|(V531112_DEFLA!=.)|(V531122_DEFLA!=.)|(V531132_DEFLA!=.)|(V8501_DEFLA!=.)

	foreach var of varlist V1904_DEFLA V531112_DEFLA V531122_DEFLA V531132_DEFLA V8501_DEFLA {

	  gen despesa_mes`var' = (`var'*FATOR_ANUALIZACAO)/12 if !inlist(QUADRO, 0, 10, 19, 44, 47, 48, 49, 50, 53, 54)
	  replace despesa_mes`var' = (`var'*V9011*FATOR_ANUALIZACAO)/12 if inlist(QUADRO, 0, 10, 19, 44, 47, 48, 49, 50, 53, 54)

	}
	
	* 5-digit product code to merge with POF expenditure correlations
	gen Codigo = round(V9001/100)

	tempfile dedexp
	save `dedexp'
	
	*--------------------------------------------------------------------------*
	**## 4.1. Expenses with deductions aggregated by family and product code
	*--------------------------------------------------------------------------*

		use `dedexp', clear
		gcollapse (sum) despesa_mes*, by($uc Codigo)

		reshape long despesa_mes, i($uc Codigo) j(Variavel, string)

		save "${data}/despesas_deducoes.dta", replace


	*--------------------------------------------------------------------------*
	**## 4.2. Expenses with deductions aggregated by family, product code, and form of acquisition
	*--------------------------------------------------------------------------*
		
		* All expenses with deductions are monetary
		use `dedexp', clear
		
		* Forms of acquisition - monetary or other
		* Generating suffixes
		gen aqm = "_aqav" if inrange(V9002,1,2)
		replace aqm = "_aqap" if inrange(V9002,3,6)
		replace aqm = "_aqo" if inrange(V9002,7,11)
		replace aqm = "_aqmis" if V9002 == .
				
		gcollapse (sum) despesa_mes*, by($uc Codigo aqm)
		reshape long despesa_mes, i($uc Codigo aqm) j(Variavel, string)
		greshape wide despesa_mes, i($uc Codigo Variavel) j(aqm) string
		
		save "${data}/despesas_deducoes_aqm.dta", replace

	*--------------------------------------------------------------------------*
	**## 4.3. Expenses with deductions aggregated by family, product code, and place of acquisition
	*--------------------------------------------------------------------------*
		
		* Formal expenses with deductions are those with tax and pension of
		* hired domestic workers
		use `dedexp', clear
		
		* Place of acquisition
		gen codloc3 = trunc(V9004/100)
		
		* Correlation of places of acquisition to formal or informal
		join, from("${data}/BR_POF_crosswalk_TOR_3dig_2017") by(codloc3)
		drop if _merge == 2
		drop _merge

		* Modifications proposed by 
		replace informal = 0 if inlist(V9004,509) // Mercado
		replace informal = 0 if QUADRO == 19 & V1904 != .
		replace informal = 1 if QUADRO == 19 & V1904 == .
		
		* Generating suffixes
		gen locinf = "_inf" if informal == 1
		replace locinf = "_for" if informal == 0
		replace locinf = "_out" if informal == .
		
		* 
		collapse (sum) despesa_mes*, by($uc Codigo locinf)
		reshape long despesa_mes, i($uc Codigo locinf) j(Variavel, string)
		reshape wide despesa_mes, i($uc Codigo Variavel) j(locinf, string)
		replace despesa_mes_for = 0 if despesa_mes_for == .
		replace despesa_mes_inf = 0 if despesa_mes_inf == .
		replace despesa_mes_out = 0 if despesa_mes_out == .

		save "${data}/despesas_deducoes_locinf.dta", replace

*------------------------------------------------------------------------------*
**# 5. Appending expenses datasets
*------------------------------------------------------------------------------* 
	
	*--------------------------------------------------------------------------*
	**## 5.1. Total
	*--------------------------------------------------------------------------*

		* Appending expenses datasets
		use	"${data}/despesas_padrao.dta", clear
		append using "${data}/despesas_deducoes.dta"

		* Correlation of consumption categories
		merge m:1 Codigo Variavel using "${data}/tradutor_despesa.dta"
		drop if _merge == 1      // zeros produced by reshaping
		drop if _merge == 2      // there are no expenses for few consumption categories
		drop _merge
		
		* Generating total expenses by each sublevel
		tempfile base
		save `base'

		foreach v of varlist Nivel_0 Nivel_1 Nivel_2 Nivel_3 Nivel_4 {
			
			use `base', clear
			gcollapse (sum) despesa_ = despesa_mes if `v' != ., by(`v' ${uc})
			greshape wide despesa_, i(${uc}) j(`v')
			
			tempfile b`v'
			save `b`v''
			
		}	

		use `bNivel_0', clear
		join, by(${uc}) from(`bNivel_1') nogen
		join, by(${uc}) from(`bNivel_2') nogen
		join, by(${uc}) from(`bNivel_3') nogen
		join, by(${uc}) from(`bNivel_4') nogen
		
		* Completing data with families that did not have expenses
		* All families had at least one expense
		tempfile df
		save `df'
		
		use "${data}/uc", clear
		merge 1:1 ${uc} using `df'
		foreach v of varlist despesa_* {
			replace `v' = 0 if `v' == .
		}
		drop _merge
		
		save "${data}/despesas_grupos.dta", replace 


	*--------------------------------------------------------------------------*
	**## 5.2. By form of acquisition
	*--------------------------------------------------------------------------*
		
		* Appending expenses datasets
		use	"${data}/despesas_padrao_aqm.dta", clear
		append using "${data}/despesas_deducoes_aqm.dta"
		
		* Correlation of consumption categories
		merge m:1 Codigo Variavel using "${data}/tradutor_despesa.dta"
		drop if _merge == 1      // zeros produced by reshaping
		drop if _merge == 2      // there are no expenses for few consumption categories
		drop _merge
			
		* Generating expenses for non-durable categories:
		* Food: 1101
		* Clothing: 1103
		* Hygiene and personal care: 1105
		* Recreation and culture: 1108
		* Tobacco: 1109
		* Personal services: 1110
		tempfile base
		save `base'
		
		gcollapse (sum) 	///
			despesa_aqav_ = despesa_mes_aqav 	///
			despesa_aqap_ = despesa_mes_aqap 	///
			despesa_aqo_ = despesa_mes_aqo 		///
			despesa_aqmis_ = despesa_mes_aqmis 	///
			if inlist(Nivel_3,1101,1103,1105,1108,1109,1110), by(Nivel_3 ${uc})
		greshape wide despesa_aqav_ despesa_aqap_ despesa_aqo_ despesa_aqmis_, i(${uc}) j(Nivel_3)
		
		foreach i in 1101 1103 1105 1108 1109 1110 {
			replace despesa_aqav_`i' = 0 if despesa_aqav_`i' == .
			replace despesa_aqap_`i' = 0 if despesa_aqap_`i' == .
			replace despesa_aqo_`i' = 0 if despesa_aqo_`i' == .
			replace despesa_aqmis_`i' = 0 if despesa_aqmis_`i' == .
		}
		
		tempfile ndg
		save `ndg'
		
		* Generating expenses for durable categories:
		* Real state acquisition: 21
		* Reforms: 22
		* Other investment: 32
		use `base', clear
		
		gcollapse (sum) 	///
			despesa_aqav_ = despesa_mes_aqav 	///
			despesa_aqap_ = despesa_mes_aqap 	///
			despesa_aqo_ = despesa_mes_aqo 		///
			despesa_aqmis_ = despesa_mes_aqmis 	///
			if inlist(Nivel_2,21,22,32), by(Nivel_2 ${uc})
		greshape wide despesa_aqav_ despesa_aqap_ despesa_aqo_ despesa_aqmis_, i(${uc}) j(Nivel_2)
		
		foreach i in 21 22 32 {
			replace despesa_aqav_`i' = 0 if despesa_aqav_`i' == .
			replace despesa_aqap_`i' = 0 if despesa_aqap_`i' == .
			replace despesa_aqo_`i' = 0 if despesa_aqo_`i' == .
			replace despesa_aqmis_`i' = 0 if despesa_aqmis_`i' == .
		}
		
		tempfile dg
		save `dg'
		
		* Generating expenses for investment:
		* Real state: 1102
		* Transport: 1104
		use `base', clear
		
		* Expenses with maintenance (investment)
		gen drxp = inlist(Descricao_4, 			///
			"Eletrodomesticos", 			///
			"Mobiliario e artigos do  lar",	///
			"Aquisicao de veiculos"			///
			)
		replace drxp = 2 if inlist(Descricao_4, ///
			"Consertos de artigos do lar", 	///
			"Manutencao do lar", 			///
			"Manutencao e acessorios"		///
			)
			
		gcollapse (sum) 	///
			despesa_aqav_dr = despesa_mes_aqav 	///
			despesa_aqap_dr = despesa_mes_aqap 	///
			despesa_aqo_dr = despesa_mes_aqo 		///
			despesa_aqmis_dr = despesa_mes_aqmis 	///
			if inlist(Nivel_3,1102,1104), by(${uc} drxp)
		greshape wide despesa_aqav_dr despesa_aqap_dr despesa_aqo_dr despesa_aqmis_dr, i(${uc}) j(drxp)
		
		forvalues i = 0/2 {
			replace despesa_aqav_dr`i' = 0 if despesa_aqav_dr`i' == .
			replace despesa_aqap_dr`i' = 0 if despesa_aqap_dr`i' == .
			replace despesa_aqo_dr`i' = 0 if despesa_aqo_dr`i' == .
			replace despesa_aqmis_dr`i' = 0 if despesa_aqmis_dr`i' == .
		}
				
		* Joining bases
		merge 1:1 ${uc} using `ndg', nogen
		merge 1:1 ${uc} using `dg', nogen
		
		* Completing data with families that did not have expenses
		tempfile df
		save `df'
				
		use "${data}/uc", clear
		merge 1:1 ${uc} using `df'
		foreach v of varlist despesa_* {
			replace `v' = 0 if `v' == .
		}
		drop _merge
		
		* No missing values
		drop despesa_aqmis_dr* 
		
		save "${data}/despesas_grupos_aqm.dta", replace 

	*--------------------------------------------------------------------------*
	**## 5.3. By place of acquisition
	*--------------------------------------------------------------------------*
	
		* Appending expenses datasets
		use	"${data}/despesas_padrao_locinf.dta", clear
		append using "${data}/despesas_deducoes_locinf.dta"
		
		* Correlation of consumption categories
		merge m:1 Codigo Variavel using "${data}/tradutor_despesa.dta"
		drop if _merge == 1      // zeros produced by reshaping
		drop if _merge == 2      // there are no expenses for few consumption categories
		drop _merge
		
		* Generating expenses for non-durable categories:
		* Food: 1101
		* Clothing: 1103
		* Hygiene and personal care: 1105
		* Recreation and culture: 1108
		* Tobacco: 1109
		* Personal services: 1110
		* Loans: 31
		
		tempfile base
		save `base'
		
		* Generating total expenses by sublevel 3
		
		gcollapse (sum) 						///
			despesa_inf_ = despesa_mes_inf 	///
			despesa_for_ = despesa_mes_for 	///
			despesa_out_ = despesa_mes_out 	///
			if inlist(Nivel_3,1101,1103,1105,1108,1109,1110), by(Nivel_3 ${uc})
		greshape wide despesa_inf_ despesa_for_ despesa_out_, i(${uc}) j(Nivel_3)
		
		foreach i in 1101 1103 1105 1108 1109 1110 {
			replace despesa_inf_`i' = 0 if despesa_inf_`i' == .
			replace despesa_for_`i' = 0 if despesa_for_`i' == .
			replace despesa_out_`i' = 0 if despesa_out_`i' == .
		}
		
		tempfile ndg
		save `ndg'
		
		* Generating expenses for investment:
		* Real state: 1102
		* Transport: 1104
		use `base', clear
		
		* Expenses with maintenance (investment)
		gen drxp = inlist(Descricao_4, 			///
			"Eletrodomesticos", 			///
			"Mobiliario e artigos do  lar",	///
			"Aquisicao de veiculos"			///
			)
		replace drxp = 2 if inlist(Descricao_4, ///
			"Consertos de artigos do lar", 	///
			"Manutencao do lar", 			///
			"Manutencao e acessorios"		///
			)
			
		gcollapse (sum) 						///
			despesa_inf_dr = despesa_mes_inf 	///
			despesa_for_dr = despesa_mes_for 	///
			despesa_out_dr = despesa_mes_out 	///
			if inlist(Nivel_3,1102,1104), by(drxp ${uc})
		greshape wide despesa_inf_dr despesa_for_dr despesa_out_dr, i(${uc}) j(drxp)
		
		forvalues i = 0/2 {
			replace despesa_inf_dr`i' = 0 if despesa_inf_dr`i' == .
			replace despesa_for_dr`i' = 0 if despesa_for_dr`i' == .
			replace despesa_out_dr`i' = 0 if despesa_out_dr`i' == .
		}
		
		tempfile dg
		save `dg'
		
		* Generating expenses for durable categories:
		* Real state acquisition: 21
		* Reforms: 22
		* Other investment: 32
		use `base', clear
		
		gcollapse (sum) 						///
			despesa_inf_ = despesa_mes_inf 	///
			despesa_for_ = despesa_mes_for 	///
			despesa_out_ = despesa_mes_out 	///
			if inlist(Nivel_2,21,22,32), by(Nivel_2 ${uc})
		greshape wide despesa_inf_ despesa_for_ despesa_out_, i(${uc}) j(Nivel_2)
		
		foreach i of numlist 21 22 32 {
			replace despesa_inf_`i' = 0 if despesa_inf_`i' == .
			replace despesa_for_`i' = 0 if despesa_for_`i' == .
			replace despesa_out_`i' = 0 if despesa_out_`i' == .
		}
		
		
		* Joining bases
		merge 1:1 ${uc} using `ndg', nogen
		merge 1:1 ${uc} using `dg', nogen
				
		* Completing data with families that did not have expenses
		tempfile df
		save `df'
				
		use "${data}/uc", clear
		merge 1:1 ${uc} using `df'
		foreach v of varlist despesa_* {
			replace `v' = 0 if `v' == .
		}
		drop _merge
		
		save "${data}/despesas_grupos_locinf.dta", replace 

 
*------------------------------------------------------------------------------*
**# 6. Specific expenses
*------------------------------------------------------------------------------* 
	
	* Correlation of specific categories of expenses
	import excel using "${input_other}/specific_categories.xlsx", clear sheet("spec_cat") firstrow
	keep if spec_cat != .
	keep Codigo Variavel spec_cat

	tempfile spec_cat
	save `spec_cat'

	* Expenses datasets
	use	"${data}/despesas_padrao.dta", clear
	append using "${data}/despesas_deducoes.dta"	
	
	* Correlation of consumption categories
	merge m:1 Codigo Variavel using "${data}/tradutor_despesa.dta"
	drop if _merge == 1      // zeros produced by reshaping
	drop if _merge == 2      // there are no expenses for few consumption categories
	drop _merge
	
	* Two categories of expenses: taxes and donations
	keep if inlist(Nivel_3, 1201, 1204)
	
	merge m:1 Codigo Variavel using `spec_cat'
	
	gcollapse (sum) despesa_mes, by(${uc} spec_cat)
	drop if COD_UPA == .

	ren despesa_mes despesa_sc

	greshape wide despesa_sc, i(${uc}) j(spec_cat)

	forvalues i = 1/5 {
		replace despesa_sc`i' = 0 if despesa_sc`i' == .
	}

	label var despesa_sc1 "Impostos relacionados a imóveis"
	label var despesa_sc2 "Impostos relacionados a veículos"
	label var despesa_sc3 "Outros impostos"
	label var despesa_sc4 "Pensões e Doações para outras UCs"
	label var despesa_sc5 "Doações para terceiros"

	* Completing data with families that did not have expenses
	tempfile df
	save `df'
			
	use "${data}/uc", clear
	merge 1:1 ${uc} using `df'
	foreach v of varlist despesa_sc* {
		replace `v' = 0 if `v' == .
	}
	drop _merge
		
	* salvo a base de despesas gerais
	save "${data}/despesas_spec_cat.dta", replace 

*------------------------------------------------------------------------------*
**# 7. Expenses with durable goods
*------------------------------------------------------------------------------* 

	* Expenses datasets
	use	"${data}/despesas_padrao.dta", clear
	append using "${data}/despesas_deducoes.dta"	

	* Correlation of consumption categories
	merge m:1 Codigo Variavel using "${data}/tradutor_despesa.dta"
	drop if _merge == 1      // zeros produced by reshaping
	drop if _merge == 2      // there are no expenses for few consumption categories
	drop _merge
	
	* Two categories of expenses: housing and transport
	keep if inlist(Nivel_3, 1102, 1104)
	
	* Expenses with maintenance (investment)
	gen drxp = inlist(Descricao_4, 			///
			"Eletrodomesticos", 			///
			"Mobiliario e artigos do  lar",	///
			"Aquisicao de veiculos"			///
			)
	replace drxp = 2 if inlist(Descricao_4, ///
			"Consertos de artigos do lar", 	///
			"Manutencao do lar", 			///
			"Manutencao e acessorios"		///
			)
	
	* Aggregating at the level of family, dummy for investment, and category of expenses
	gcollapse (sum) despesa_mes, by(${uc} drxp)

	ren despesa_mes despesa_dr

	greshape wide despesa_dr, i(${uc}) j(drxp)

	forvalues j = 0/2 {
		replace despesa_dr`i'`j' = 0 if despesa_dr`i'`j' == .
	}
	
	label var despesa_dr1 "Purchase"
	label var despesa_dr2 "Maintenance"
	label var despesa_dr0 "Current expenses"
	
	* Completing data with families that did not have expenses
	tempfile df
	save `df'
			
	use "${data}/uc", clear
	merge 1:1 ${uc} using `df'
	foreach v of varlist despesa_dr* {
		replace `v' = 0 if `v' == .
	}
	drop _merge
	
	* salvo a base de despesas gerais
	save "${data}/despesas_hab.dta", replace 


*------------------------------------------------------------------------------*
**# 8. Durable goods inventory
*------------------------------------------------------------------------------* 

	* Correlation of specific categories of durables
	import excel using "${input_pof}/specific_categories.xlsx", clear sheet("dur") firstrow
	keep if dur != .
	ren CÓDIGODOPRODUTO V9001
	keep QUADRO V9001 dur

	tempfile dur
	save `dur'

	* Durable goods inventory
	use	"${input_pof}/INVENTARIO.dta", clear

	merge m:1 QUADRO V9001 using `dur'
	
	* Number of durable goods acquired from 2015 onward
	gen qt15 = V9005 if inlist(V1404, 2015, 2016, 2017, 2018)
	
	* Total number of durable goods
	gen qtt = V9005
	
	* Dummy for a positive number of durable goods
	gen pqt = V9005 > 0 & V9005 != .

	* Aggregating at the level of family and category of durable good
	gcollapse (sum) qt15 qtt pqt, by(${uc} dur)
	
	* Reshaping
	greshape wide qt15 qtt pqt, i(${uc}) j(dur)

	foreach nome in qt15 qtt pqt {
		foreach i of numlist 1/20 99 {
			replace `nome'`i' = 0 if `nome'`i' == .
		}
	}

	foreach nome in qt15 qtt pqt {
		label var `nome'1 "Stove"
		label var `nome'2 "Refrigerator"
		label var `nome'3 "Shower"
		label var `nome'4 "Water filter"
		label var `nome'5 "Dish-washer"
		label var `nome'6 "Microwave oven"
		label var `nome'7 "Electric oven"
		label var `nome'8 "Iron"
		label var `nome'9 "Washing machine"
		label var `nome'10 "TV"
		label var `nome'11 "Sound-system"
		label var `nome'12 "PC"
		label var `nome'13 "Fan"
		label var `nome'14 "Bed"
		label var `nome'15 "Wardrobe/cabinet"
		label var `nome'16 "Kitchen table"
		label var `nome'17 "Couch"
		label var `nome'18 "Automobile"
		label var `nome'19 "Motorcycle"
		label var `nome'20 "Bicycle"
		label var `nome'99 "Other"
	}
	
	* Completing data with families that did not have expenses
	tempfile df
	save `df'
			
	use "${data}/uc", clear
	merge 1:1 ${uc} using `df'
	foreach v of varlist qt15* qtt* pqt* {
		replace `v' = 0 if `v' == .
	}
	drop _merge
	
	* salvo a base de despesas gerais
	save "${data}/despesas_dur.dta", replace 

