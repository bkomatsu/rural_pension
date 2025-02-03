*------------------------------------------------------------------------------*
* Income Data
*------------------------------------------------------------------------------*

* Creates income data, using IBGE income aggregation, with the following steps:

* 1. Read income correlations to IBGE aggregate categories
* 2. Create income dataset at family level, with variables for IBGE income categories
* 3. Create income dataset at person level, with variables for IBGE income categories

*------------------------------------------------------------------------------*
**# 1. POF income correlations
*------------------------------------------------------------------------------*

	import excel "${input_pof}/Tradutor_Rendimento.xls", firstrow clear
	keep if strlen(Codigo) == 5        // exclude non-monetary income and equity variation
	keep Codigo Nivel_* Descricao_*
	destring Codigo, replace
	save "${data}/tradutor_rendimento.dta", replace

*------------------------------------------------------------------------------*
**# 2. Income
*------------------------------------------------------------------------------*

	use "${input_pof}/RENDIMENTO_TRABALHO.dta", clear
	append using "${input_pof}/OUTROS_RENDIMENTOS.dta"
	keep if V8500_DEFLA != .
	gen rendimento_mes = (V8500_DEFLA*FATOR_ANUALIZACAO)/12 if !inlist(QUADRO, 53, 54)
	replace rendimento_mes = (V8500_DEFLA*V9011*FATOR_ANUALIZACAO)/12 if inlist(QUADRO, 53, 54)

	* 5-digit income code to merge with POF income correlations
	gen Codigo = round(V9001/100) 

	* Aggregation by family and product code
	gcollapse (sum) rendimento_mes, by($uc Codigo)   
	
	tempfile income
	save `income'
	
	*--------------------------------------------------------------------------*
	**# 2.1. Income - detailed classification
	*--------------------------------------------------------------------------*
	
	* Generating a dataset at the family level with family income classified with
	* detailed classification
	use `income', clear
	
	rename rendimento_mes rendimento_mes_
	reshape wide rendimento_mes_, i($uc) j(Codigo)
	
	* Completing data with families that did not have income
	tempfile df
	save `df'
	
	use "${data}/uc.dta", clear
	merge 1:1 $uc using `df'
	drop _merge

	foreach v of varlist rendimento_*{
		replace `v' = 0 if `v'==.
	}
	
	merge 1:1 $uc using `df'
	drop _merge
	
	foreach v of varlist rendimento_mes_* {
		replace `v' = 0 if `v'==.
	}
	
	save "${data}/rendimentos_uc_codigos.dta", replace
	
	*--------------------------------------------------------------------------*
	**# 2.2. Income - broad classification
	*--------------------------------------------------------------------------*
	
	* Generating a dataset at the family level with family income classified with
	* broad classification
	use `income', clear
	
	merge m:1 Codigo using "${data}/tradutor_rendimento.dta"
	keep if _merge == 3                    // excluding income categories with no entries or non-monetary/equity variation
	drop _merge

	* Generating total income by sublevels 2 and 3
	tempfile base
	save `base'

	foreach v of varlist Nivel_2 Nivel_3 {
		
		use `base', clear
		gcollapse (sum) rend_uc_ = rendimento_mes if `v' != ., by(`v' ${uc})
		greshape wide rend_uc_, i(${uc}) j(`v')
		
		tempfile b`v'
		save `b`v''
		
	}	

	use `bNivel_2', clear
	join, by(${uc}) from(`bNivel_3') nogen
	
	* Completing data with families that did not have income
	tempfile df
	save `df'
	
	use "${data}/uc.dta", clear
	merge 1:1 $uc using `df'
	drop _merge

	foreach v of varlist rend_uc_*{
		replace `v' = 0 if `v'==.
	}

	save "${data}/rendimentos_uc_grupos.dta", replace

*------------------------------------------------------------------------------*
**# 3. Individual income
*------------------------------------------------------------------------------*

	use "${input_pof}/RENDIMENTO_TRABALHO.dta", clear
	append using "${input_pof}/OUTROS_RENDIMENTOS.dta"
	keep if V8500_DEFLA != .
	gen rendimento_i_mes = (V8500_DEFLA*FATOR_ANUALIZACAO)/12 if !inlist(QUADRO, 53, 54)
	replace rendimento_i_mes = (V8500_DEFLA*V9011*FATOR_ANUALIZACAO)/12 if inlist(QUADRO, 53, 54)

	* 5-digit income code to merge with POF income correlations
	gen Codigo = round(V9001/100) 

	* Working payed hours
	gen horas = V5314 * V9011 * (51/12) if V5314 < 999
	replace horas = . if V5314 == 999
	replace horas = horas / 12 / (51/12)

	gen dren = 1
	
	* Aggregation by individual and product code
	gcollapse 										///
		(sum) 										///
			rendimento_i_mes_ = rendimento_i_mes 	///
			horas_ = horas 							///
		(max) 										///
			dren_ = dren							///
		, by($morador Codigo)

	tempfile income
	save `income'
	
	*--------------------------------------------------------------------------*
	**# 3.1. Individual income - detailed classification
	*--------------------------------------------------------------------------*
	
	* Generating a dataset at the family level with family income classified with
	* detailed classification
	use `income', clear
	
	greshape wide rendimento_i_mes_ horas_ dren_, i($morador) j(Codigo)
	
	* Completing data with individuals that did have income
	tempfile df
	save `df'
	
	use "${input_pof}/MORADOR.dta", clear
	keep $morador
	merge 1:1 $morador using `df'
	drop _merge
	
	foreach var of varlist rendimento_i_mes_* horas_* dren_* {
	  replace `var' = 0 if `var'==.
	}
	save "${data}/rendimentos_morador_codigos.dta", replace

	*--------------------------------------------------------------------------*
	**# 3.2. Individual income - broad classification
	*--------------------------------------------------------------------------*
	
	* Generating a dataset at the family level with family income classified with
	* broad classification
	use `income', clear
	
	merge m:1 Codigo using "${data}/tradutor_rendimento.dta"
	keep if _merge == 3                    // excluding income categories with no entries or non-monetary/equity variation
	drop _merge

	* Generating total income by sublevels 2 and 3
	tempfile base
	save `base'

	foreach v of varlist Nivel_0 Nivel_2 Nivel_3 {
		
		use `base', clear
		gcollapse (sum) 		///
			rendimento_i_mes_	///
			horas_				///
			(max)				///
			dren_				///
			if `v' != ., by(`v' ${morador})
		greshape wide rendimento_i_mes_ horas_ dren_, i(${morador}) j(`v')
		
		tempfile b`v'
		save `b`v''
		
	}	

	use `bNivel_0', clear
	join, by(${morador}) from(`bNivel_2') nogen
	join, by(${morador}) from(`bNivel_3') nogen
	
	* Completing data with individuals that did not have income
	tempfile df
	save `df'
	
	use "${input_pof}/morador.dta", clear
	keep ${morador}
	merge 1:1 ${morador} using `df'
	drop _merge
	
	foreach v of varlist rendimento_i_mes_* horas_* dren_* {
		replace `v' = 0 if `v'==.
	}

	save "${data}/rendimentos_morador_grupos.dta", replace
