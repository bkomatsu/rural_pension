* Program to export tables in a specified format
cap program drop outrd
program outrd
syntax anything using/[, rmtitle rmstats append estlab(string) bwt age(integer 55)]

if "`rmtitle'" != "" {
	local titles "nodepvars nonumbers nomtitles"
}
else {
	local titles ""
}

if "`rmstats'" != "" {
	local extralabels ""
	local extrameans ""
	local extrafmt ""
}
else {
	local extralabels `""Mean (age < `age')" "Mean (age > `age')""'
	local extrameans mean_left mean_right
	local extrafmt "2 2"
}

if "`bwt'" != "" {
	local bwtitle `""Bandwidth (age < `age')" "Bandwidth (age > `age')""'
	local bwfmt "2 2"
	local bwstats "bandl bandr"
}
else {
	local bwtitle `"Bandwidth"'
	local bwfmt "2"
	local bwstats band
}

if "`append'" != "" local sit append
else local sit replace

if "`estlab'" == "" local estlab "Pensions"
else local panel ""

esttab `anything' using "`using'",									///
	legend label scsv `sit' collabels(none) 						///
	nodepvars nomtitle												///
	star(* 0.10 ** 0.05 *** 0.01)									///
	keep(RD_Estimate)												///
	cells(b(star pvalue(m_pv) fmt(3) vacant({-})) se(par(( )) fmt(3)))	///
	coeflabels(RD_Estimate "`estlab'") 								///
	stats(`bwstats' `extrameans' N,									///
		fmt(`bwfmt' `extrafmt' %7.0fc) 								///
		labels(														///
			`bwtitle' 												///
			`extralabels'											///
			`"Observations"' 										///
		)															///
	) `titles'
	
	

end

* Program to run RDD regressions for the Brazilian rural pension
cap program drop rdpension
program rdpension, eclass
	
	syntax varlist [if], pension(varname) [first weight(varname) tag(string) mat cont age(integer 0) covs(varlist)]
	
	* Including weight option
	if "`weight'" != "" {
		local weight_opt "weights(`weight')"
		local weight_opt_sum "[w = `weight']"
	}
	else {
		local weight_opt ""
		local weight_opt_sum ""
	}
	
	if "`mat'" != "" local ind 1
	
	if "`cont'" != "" local v_idade idade_cont
	else local v_idade idade_p
	
	if "`covs'" != "" local covs_opt = "covs(`covs')"
	else local covs_opt ""
	
	* Loop on the dependent variables
	foreach var of varlist `varlist' {
		
		* Optimal bandwidth selection
		*----------------------------------------------------------------------*
		rdbwselect `var' `v_idade' `if', masspoints(adjust) c(`age') fuzzy(`pension') p(1) `weight_opt' `covs_opt'
		local bw = e(h_mserd)
		local bias = e(b_mserd)
		*----------------------------------------------------------------------*
		
		* Including first-stage regression
		if "`first'" != "" {
		
			* First-stage regression
			*------------------------------------------------------------------*
			eststo `tag'first_`var': 										///
				rdrobust `pension' `v_idade'									///
				`if', h(`bw' `bw') b(`bias' `bias') masspoints(adjust) c(`age') p(1) `weight_opt' `covs_opt'
			*------------------------------------------------------------------*
			
			local p = e(pv_rb)
			matrix m_pv = `p'
			matrix colnames m_pv = "RD_Estimate"
			estadd matrix m_pv = m_pv
			
		}
		
		* Two-stages regression
		*----------------------------------------------------------------------*
		no cap rdrobust `var' `v_idade'											///
			`if', masspoints(adjust) c(`age') fuzzy(`pension') p(1) `weight_opt' `covs_opt'
		
		*----------------------------------------------------------------------*
		
		if _rc != 0 {
				nullcol po
			}
		else {
			
			if "`mat'" != "" {
				
				if `ind' == 1 {
					matrix res = e(b), e(se_tau_cl), e(pv_cl), e(pv_rb), e(N)
					local ind 0
				}
				else matrix res = res \ (e(b), e(se_tau_cl), e(pv_cl), e(pv_rb), e(N))
			}
			
			* Dependent variable means
			if "`if'" != "" local if_s = subinstr("`if'","if ","& ",.)
			
			sum `var' if `v_idade' >= `age'-`bw'& `v_idade' < `age' `if_s' `weight_opt_sum'
			local mean_left = r(mean)  
			sum `var' if `v_idade' > `age' & `v_idade' <= `age' +`bw' `if_s' `weight_opt_sum'
			local mean_right = r(mean)  
			
			matrix V = e(se_tau_rb)^2
			local p = e(pv_rb)
			matrix m_pv = `p'
			matrix colnames m_pv = "RD_Estimate"
			
			ereturn repost V = V
			ereturn scalar p = `p'
			
			eststo `tag'second_`var'
			
			estadd scalar band `bw': `tag'second_`var'
			estadd scalar mean_left `mean_left' : `tag'second_`var'
			estadd scalar mean_right `mean_right' : `tag'second_`var'
			estadd local ic = 							///
				"[" + string(`e(ci_l_rb)',"%4.3f") + 	///
				"," + 									///
				string(`e(ci_r_rb)',"%4.3f") + 			///
				"]": `tag'second_`var'	
			estadd matrix m_pv = m_pv
					
			if "`first'" != "" {
				
				estadd scalar band `bw': `tag'first_`var'
				estadd scalar mean_left `mean_left' : `tag'first_`var'
				estadd scalar mean_right `mean_right' : `tag'first_`var'
				estadd local ic = 							///
					"[" + string(`e(ci_l_rb)',"%4.3f") + 	///
					"," + 									///
					string(`e(ci_r_rb)',"%4.3f") + 			///
					"]": `tag'first_`var'	
				
			}
		
		}
		
	} // end of loop on the dependent variables (var)
		
end


* Program to construct RD plots
cap program drop plotpension
program plotpension
	
	syntax varlist using/ [if], ytitle(string) [weight(varname) subf cont age(integer 0)]
		
	* Including weight option
	if "`weight'" != "" local weight_opt "[aw = `weight']"
	else local weight_opt ""
	
	if "`subf'" != "" {
		
		local size_opt = ", size(vlarge)"
		local xsize_opt = "xlabel(, labsize(vlarge))"
		local ysize_opt = "ylabel(, labsize(vlarge))"
		local note_opt = ""
	}
	else {
		local note_opt //`"note("Note: gray area is 95% confidence interval.")"'
	}
	
	tempvar tvar
	if "`ytitle'" == "Percentage points" gen `tvar' = `varlist' * 100	
	else gen `tvar' = `varlist'
	
	if "`cont'" != "" local v_idade idade_cont
	else local v_idade idade_p
	
	twoway  (lpolyci `tvar' `v_idade' if `v_idade' <  `age' `weight_opt'		///
				, clcolor(navy) ciplot(rline) alcolor(navy) alpattern(shortdash)) 							///
			(lpolyci `tvar' `v_idade' if `v_idade' > `age' `weight_opt'			///
				, clcolor(navy) ciplot(rline) alcolor(navy) alpattern(shortdash))			///
			`if' ,														///
			 xline(`age', lcolor(red) lwidth(vthin) ) 		///
			 ytitle(`ytitle'`size_opt') 								///
			 xtitle("Age to Cutoff"`size_opt') 										///
			 legend(off) 												///
			 bgcolor (white) graphregion(color(white))  				///
			 `note_opt' `xsize_opt' `ysize_opt'	
	
	qui gr export `using', replace
	window manage close graph
	
end


* Program to generate null column
cap program drop nullcol
program nullcol, eclass
	
	syntax varname, [tag(string)]
	
	matrix m_pv = J(1,1,.)
	matrix colnames m_pv = "RD_Estimate"
	
	matrix V = J(1,1,0)
	matrix b = J(1,1,0)
	matrix colnames V = "RD_Estimate"
	matrix colnames b = "teste"
	
	ereturn post V
	ereturn post b
	
	eststo `tag'second_`varlist'
	estadd matrix m_pv = m_pv
		
end


* Program to export columns - durable goods tables
cap program drop expdur
program expdur
	
	syntax using/, pref(string) idvar(varname) [replace]
	
	cap file close _all
	file open arquivo using `using', write `replace'
	// write top lines
	file write arquivo "Item,Estimate,SE,Obs." _n
		
	quietly describe
	local I = r(N)
	
	* Loop nas linhas
	forvalues i = 1/`I' {
		
		local valor = `idvar'[`i']
		local linha = `""`valor'""'
		
		di "ok1"
		
		* Loop nas colunas
		foreach j of numlist 1 2 5 {
			
			di "ok2"
			local valor = `pref'`j'[`i']
			
			di "ok2b"
			local linha = `"`linha',"' + `""`valor'""'
			
		}
		
		di "ok3"
		di `"`linha'"'
		file write arquivo `"`linha'"' _n
	}
	
	// clean up
	file close arquivo
		
		
end

