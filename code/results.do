*------------------------------------------------------------------------------*
* Results of the Paper
*------------------------------------------------------------------------------*

use "${data}/base.dta", clear

*------------------------------------------------------------------------------*
**# 1. Descriptive Statistics
*------------------------------------------------------------------------------*

	label var m55 "Age >= 55"
	label var aposentado "Retired"
	label var po "Working"
	label var dren_11 "Paid work"
	label var po_nr "Unpaid work"
	label var horas_0 "Weekly working hours"
	label var dren_111 "Working as employee"
	label var dren_112 "Working as employer"
	label var dren_113 "Working as self-employed"

	label var horas_111 "Weekly working hours as employee"
	label var horas_112 "Weekly working hours as employer"
	label var horas_113 "Weekly working hours as self-employed"

	label var poor_sa "Poverty with no federal pension"
	label var pc_rapos "Household p.c. income with no federal pension"
	label var rendimento_12sa "Individual non-labor inc. with no federal pension"

	label var poor "Poverty"
	label var pc_rmon "Household p.c. monetary inc."
	label var pc_tin "Household p.c. income"

	label var rendimento_i_mes_11 "Individual labor inc."
	label var rendimento_i_mes_111 "Employee"
	label var rendimento_i_mes_112 "Employer"
	label var rendimento_i_mes_113 "Self-Employed"

	label var rendimento_nli "Individual non-labor inc."
	label var rendimento_i_mes_121 "Federal pensions"
	label var rendimento_i_mes_122 "Other public pensions"
	label var rendimento_i_mes_123 "Private pensions"
	label var rendimento_tra "Social transfers"
	label var rendimento_oth "Other sources"

	label var pc_0 "Total expenditure"
	label var pc_ndg "Non-Durables"
	label var pc_edhc "Education/Healthcare"
	label var pc_oth "Other curr. exp."
		

	global vars_p m55 aposentado po dren_11 po_nr horas_0 poor poor_sa

	global vars	///
		pc_tin	///
		pc_rapos 			///
		rendimento_i_mes_11 		/// Labor Income
		rendimento_nli 		/// Total non-labor income
		rendimento_12sa		///
			rendimento_i_mes_121 	/// Federal pensions
			rendimento_i_mes_122 	/// Other public pensions
			rendimento_i_mes_123 	/// Private pensions
			rendimento_tra 	/// Social transfers
			rendimento_oth 	/// Other sources
		pc_0 	///
		pc_ndg 	///
		pc_edhc 				/// Education and healthcare
		pc_oth					 // Other
		
	
	* Dummy variables
	estpost tabstat $vars_p if idade_p != 0 & am_fem == 1 [w = PESO_FINAL],  statistics(n mean sd p50 count) columns(statistics)
	eststo teste
	esttab teste using "${results_tables}/t1.csv", 									///
		cells(																		///
			"mean(fmt(%3.2fc) label(Mean)) sd(fmt(%3.2fc) label(SD.)) p50(fmt(%3.2fc) label(P50)) count(fmt(%7.0fc) label(Obs.))") ///
		label nostar nonum noobs title("Summary statistics")						 ///
		replace plain csv

	* Value variables
	estpost tabstat $vars if idade_p != 0 & am_fem == 1 [w = PESO_FINAL], listwise statistics(n mean sd p50 count) columns(statistics)
	eststo teste
	esttab teste using "${results_tables}/t1.csv", 									///
		cells(																		///
			"mean(fmt(%7.0fc) label(Mean)) sd(fmt(%7.0fc) label(SD.)) p50(fmt(%7.0fc) label(P50)) count(fmt(%7.0fc) label(Obs.))") ///
		label nostar nonum noobs title("Summary statistics")						 ///
		append plain csv

		
	* Overall Statistics
	sum rendimento_i_mes_11 if po == 1 & am_fem == 1 [w = PESO_FINAL], d
	sum rendimento_i_mes_121 if po == 1 & am_fem == 1 & rendimento_i_mes_121 > 0 [w = PESO_FINAL], d
	sum dren_113 if po == 1 & am_fem == 1 [w = PESO_FINAL]
	
	* Statistics by age group
	estpost tabstat dren_11 po_nr if idade_p != 0 & am_fem == 1 & idade != 55 [w = PESO_FINAL],  statistics(n mean sd p50 count) columns(statistics) by(m55)
	
	
*------------------------------------------------------------------------------*
**# 2. Descriptive graph
*------------------------------------------------------------------------------*

* Age bandwidth
local bw = 2

preserve
	
	gen bins = trunc((idade_p - 0)/ `bw') * `bw' + 0 + (`bw'/2)
			
	gcollapse (mean) 													///
		rendimento_i_mes_54004 rendimento_i_mes_55003 					///
		pensions rendimento_i_mes_111 rendimento_i_mes_112 				///
		rendimento_i_mes_113 rendimento_i_mes_121 rendimento_i_mes_122 	///
		rendimento_i_mes_123 rendimento_i_mes_124 rendimento_i_mes_125 	///
		rendimento_i_mes_126  											///
		rendimento_i_mes_13 rendimento_i_mes_14							///
		[aw = PESO_FINAL] 												///
		if am_fem == 1 													///
		, by(bins)
	
	gen rp = pensions
	gen r111 = rendimento_i_mes_111 + rendimento_i_mes_112 + rendimento_i_mes_113 + rp
	gen r121= (rendimento_i_mes_121 - rendimento_i_mes_54004) + r111
	gen r124 = rendimento_i_mes_124 + r121
	gen r125 = rendimento_i_mes_125 + (rendimento_i_mes_126 - rendimento_i_mes_55003) + 	///
		rendimento_i_mes_123 + rendimento_i_mes_122 + rendimento_i_mes_13 + rendimento_i_mes_14 + r124 
	
	di "ok"
	
	tw	///
		(bar rp bins, barwidth(`bw'))			///
		(rbar rp r111 bins, barwidth(`bw'))			///
		(rbar r111 r121 bins, barwidth(`bw'))			///
		(rbar r121 r124 bins, barwidth(`bw'))			///
		(rbar r124 r125 bins, barwidth(`bw'))				///
		, xline(0) xlabel(-25(10)30)				///
		xtitle("Age to Cutoff") ytitle("R$") 						///
		graphregion(color(white))						///
		legend(order(									///
			1 "Public pensions"							///
			2 "Wages"									///
			3 "Public disability pensions"				///
			4 "Social programs"							///		
			5 "Other sources"							///
			) position(6) cols(3))
	graph export "${results_figures}/Figure_1.eps", replace
	graph export "${results_figures}/Figure_1.png", replace
	window manage close graph
			
restore
*/

*------------------------------------------------------------------------------*
**# 3. Econometric Analysis
*------------------------------------------------------------------------------*

*------------------------------------------------------------------------------*
**# 3.1. Balancing tests
*------------------------------------------------------------------------------*
	
	* Labels
	label var tamanho "Family's size"
	label var ANOS_ESTUDO "Years of education"
	label var alf "Literacy"
	label var ppi "Afro- or Native-Brazilians"
		
	* Regressions
	eststo clear
	rdpension tamanho ANOS_ESTUDO ppi alf if idade_p != 0 & am_fem == 1, pension(aposentado) weight(PESO_FINAL) age(0)
	outrd second_* using "${results_tables}/t2.csv", age(0)

	* iv. graphs
	plotpension tamanho using "${results_figures}/Figure_2a.eps" if idade_p != 0 & am_fem == 1, ytitle(Number of individuals) weight(PESO_FINAL) subf age(0)
	plotpension ANOS_ESTUDO using "${results_figures}/Figure_2b.eps" if idade_p != 0 & am_fem == 1, ytitle(Years) weight(PESO_FINAL) subf age(0)
	plotpension alf using "${results_figures}/Figure_2c.eps" if idade_p != 0 & am_fem == 1, ytitle(Percentage points) weight(PESO_FINAL) subf age(0)
	plotpension ppi using "${results_figures}/Figure_2d.eps" if idade_p != 0 & am_fem == 1, ytitle(Percentage points) weight(PESO_FINAL) subf age(0)
	
	plotpension tamanho using "${results_figures}/Figure_2a.png" if idade_p != 0 & am_fem == 1, ytitle(Number of individuals) weight(PESO_FINAL) subf age(0)
	plotpension ANOS_ESTUDO using "${results_figures}/Figure_2b.png" if idade_p != 0 & am_fem == 1, ytitle(Years) weight(PESO_FINAL) subf age(0)
	plotpension alf using "${results_figures}/Figure_2c.png" if idade_p != 0 & am_fem == 1, ytitle(Percentage points) weight(PESO_FINAL) subf age(0)
	plotpension ppi using "${results_figures}/Figure_2d.png" if idade_p != 0 & am_fem == 1, ytitle(Percentage points) weight(PESO_FINAL) subf age(0)
	
	
*------------------------------------------------------------------------------*
**# 3.2. Plots of Main Results
*------------------------------------------------------------------------------*

	plotpension aposentado using "${results_figures}/Figure_3a.eps" if idade_p != 0 & am_fem == 1, ytitle(Percentage points) weight(PESO_FINAL) subf age(0)
	plotpension lin_tin using "${results_figures}/Figure_3b.eps" if idade_p != 0 & am_fem == 1, ytitle(Family income p.c. (log)) subf weight(PESO_FINAL) age(0)
	plotpension lpc_ndg using "${results_figures}/Figure_3c.eps" if idade_p != 0 & am_fem == 1, ytitle(Current expenses p.c. (log)) subf weight(PESO_FINAL) age(0)
	plotpension lpc_1101 using "${results_figures}/Figure_3d.eps" if idade_p != 0 & am_fem == 1, ytitle(Food expenses p.c. (log)) subf weight(PESO_FINAL) age(0)

	plotpension aposentado using "${results_figures}/Figure_3a.png" if idade_p != 0 & am_fem == 1, ytitle(Percentage points) subf weight(PESO_FINAL) age(0)
	plotpension lin_tin using "${results_figures}/Figure_3b.png" if idade_p != 0 & am_fem == 1, ytitle(Family income p.c. (log)) subf weight(PESO_FINAL) age(0)
	plotpension lpc_ndg using "${results_figures}/Figure_3c.png" if idade_p != 0 & am_fem == 1, ytitle(Current expenses p.c. (log)) subf weight(PESO_FINAL) age(0)
	plotpension lpc_1101 using "${results_figures}/Figure_3d.png" if idade_p != 0 & am_fem == 1, ytitle(Food expenses p.c. (log)) subf weight(PESO_FINAL) age(0)

	
*------------------------------------------------------------------------------*
**# 3.3. Main Results
*------------------------------------------------------------------------------*
	
	*--------------------------------------------------------------------------*
	**# 3.3.1. Table 3 - First Stage Regressions
	*--------------------------------------------------------------------------*
	
		eststo clear
		rdpension lin_tin iin_tin if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd first_* using "${results_tables}/t3.csv", estlab("Age > 55") age(0)
		
	* -------------------------------------------------------------------------*
	**# 3.3.2. Table 4 - Rural Pension, Income, and Expenditure
	* -------------------------------------------------------------------------*
	
	* Loop on variable type
	foreach j in l i {
		
		* Dependent variables
		global vlist `j'in_tin `j'pc_0 `j'pc_ndg `j'pc_edhc `j'pc_oth

		if "`j'" == "i" local sit `"append rmtitle"'
		else local sit `""'
		
		* ii. Log variables - weighted 
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/t4.csv", estlab("Pensions") `sit' age(0)
		
	}
	

	* -------------------------------------------------------------------------*
	**# 3.3.3. Table 5 - Rural Pension and Loans
	* -------------------------------------------------------------------------*
		
		* Log
		global vlist lin_empr lpc_31
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/t5.csv", estlab("Pensions")  age(0)
		
		* Percent
		global vlist pin_empr p_31
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/t5.csv", estlab("Pensions") append rmtitle  age(0)
		
	* -------------------------------------------------------------------------*
	**# 3.3.4. Table 6 - Rural Pension and Expenses on Non-Durable Goods by Education
	* -------------------------------------------------------------------------*
	
		* Loop on variable type
		foreach j in l i {
			
			if "`j'" == "i" local sit `"append rmtitle"'
			else local sit `""'
			
			eststo clear
			rdpension `j'pc_ndg if idade_p != 0 & am_fem == 1 & ANOS_ESTUDO <= 5, pension(aposentado) tag("low") weight(PESO_FINAL) age(0)
			rdpension `j'pc_ndg if idade_p != 0 & am_fem == 1 & ANOS_ESTUDO > 5, pension(aposentado) tag("high") weight(PESO_FINAL) age(0)
			
			outrd *second_* using "${results_tables}/t6.csv", estlab("Pensions") `sit' age(0)
			
		}
	
	* -------------------------------------------------------------------------*
	**# 3.3.5. Table 7 - Rural Pension and Components of Non-Durable Goods
	* -------------------------------------------------------------------------*
	
		* Dependent variables
		global vlist lpc_1101 lpc_1103 lpc_1105 lpc_1108 lpc_1109 lpc_1110
		
		* Total
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("total") weight(PESO_FINAL) age(0)
		outrd *second_* using "${results_tables}/t7.csv", estlab("Pensions") age(0)
		
		* Low schooling
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1 & ANOS_ESTUDO <= 5, pension(aposentado) tag("low") weight(PESO_FINAL) age(0)
		outrd *second_* using "${results_tables}/t7.csv", estlab("Pensions") append rmtitle age(0)
		
		* High schooling
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1 & ANOS_ESTUDO > 5, pension(aposentado) tag("high") weight(PESO_FINAL) age(0)
		outrd *second_* using "${results_tables}/t7.csv", estlab("Pensions") append rmtitle age(0)	
	
	
	* -------------------------------------------------------------------------*
	**# 3.3.6. Table 8 - Components of Non-Durable Goods - Monetary and Non-Monetary acquisition
	* -------------------------------------------------------------------------*
		
		* Dependent variables
		global vlist lpc_aqo_1101 lpc_aqm_1101 lpc_aqav_1101 lpc_aqap_1101

		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/t8.csv", estlab("Pensions") age(0)
	
			
	* -------------------------------------------------------------------------*
	**# 3.3.7. Table 9 - Rural Pension and Food Security
	* -------------------------------------------------------------------------*
		
		* Dependent variables
		global vlist sa1 sa2 sa3 sa4
		
		eststo clear
		rdpension ${vlist} if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/t9.csv", estlab("Pensions") age(0)
	
	* -------------------------------------------------------------------------*
	**# 3.3.8. Table 10 - Rural Pension and Labor Market Outcomes
	* -------------------------------------------------------------------------*

		* Occupation
		global vlist po po_nr dren_11 dren_111 dren_112 dren_113
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/t10.csv", estlab("Pensions") age(0)
		
		* Working hours
		global vlist horas_0 horas_111 horas_112 horas_113
			
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/t10.csv", estlab("Pensions") append rmtitle age(0)
		
	* -------------------------------------------------------------------------*
	**# 3.3.9. Table 11 - Rural Pension and Components of Investment
	* -------------------------------------------------------------------------*
	
		* Log
		global vlist lpc_inv lpc_dr1 lpc_dr2 lpc_23
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0) covs(${covs})
		outrd second_* using "${results_tables}/t11.csv", estlab("Pensions") age(0)
		
		* Percent
		global vlist p_inv p_dr1 p_dr2 p_23
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0) covs(${covs})
		outrd second_* using "${results_tables}/t11.csv", estlab("Pensions") append rmtitle age(0)
	
	
* -----------------------------------------------------------------------------*
**# 4. Appendix
* -----------------------------------------------------------------------------*

	* -------------------------------------------------------------------------*
	**# 4.1. Table A1 - Robustness with Subsamples
	* -------------------------------------------------------------------------*
		
		* Dependent variables
		global vlist lin_tin lpc_0 lpc_ndg lpc_edhc lpc_oth

		eststo clear
		rdpension $vlist if idade_p != 0 & am_uc_al1 == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/ta1.csv", estlab("Pensions") age(0)
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_uc_al2 == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/ta1.csv", estlab("Pensions") append rmtitle age(0)
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_uc_al3 == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/ta1.csv", estlab("Pensions") append rmtitle age(0)
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_uc_al4 == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/ta1.csv", estlab("Pensions") append rmtitle age(0)
		
	* -------------------------------------------------------------------------*
	**# 4.2. Table A2 - Rural Pension and Food Expenses by Place of Acquisition
	* -------------------------------------------------------------------------*
		
		* Dependent variables
		global vlist lpc_out_1101 lpc_loc_1101 lpc_for_1101 lpc_inf_1101

		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/ta2.csv", estlab("Pensions") age(0)	
	
	* -------------------------------------------------------------------------*
	**# 4.3. Table A3 - Rural Pension and Components of Individual Labor Income
	* -------------------------------------------------------------------------*
	
		* Log
		global vlist lin_i_mes_11 lin_i_mes_111 lin_i_mes_112 lin_i_mes_113
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/ta3.csv", estlab("Pensions") age(0)
		
		* Percent
		global vlist pin_i_mes_11 pin_i_mes_111 pin_i_mes_112 pin_i_mes_113
		
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/ta3.csv", estlab("Pensions") append rmtitle age(0)
		
	* -------------------------------------------------------------------------*
	**# 4.4. Table A4 - Rural Pension and Components of Individual Non-Labor Income
	* -------------------------------------------------------------------------*
	
	* Log
	global vlist lin_nli lin_i_mes_121 lin_i_mes_122 lin_i_mes_123 lin_tra lin_oth
	
	eststo clear
	rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
	outrd second_* using "${results_tables}/ta4.csv", estlab("Pensions") age(0)
	
	* Percent
	global vlist pin_nli pin_i_mes_121 pin_i_mes_122 pin_i_mes_123 pin_tra pin_oth
	
	eststo clear
	rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
	outrd second_* using "${results_tables}/ta4.csv", estlab("Pensions") append rmtitle age(0)
	
	* -------------------------------------------------------------------------*
	**# 4.5. Table A5 - Rural Pension and Components of Investment - form of acquisition
	* -------------------------------------------------------------------------*
	
		global vlist lpc_inv_aqo lpc_inv_aqav lpc_inv_aqap lpc_aqo_dr1 lpc_aqav_dr1 lpc_aqap_dr1 

		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) first age(0)
		outrd second_* using "${results_tables}/ta5.csv", estlab("Pensions") age(0)
		
	* -------------------------------------------------------------------------*
	**# 4.6. Table A6 - Rural Pension, Current expenses in Housing and Transport, Taxes and Donations
	* -------------------------------------------------------------------------*
	
	* Loop on variable type
	foreach j in lpc p {
		
		global vlist `j'_dr0 `j'_sc1 `j'_sc2 `j'_sc3 `j'_sc4 `j'_sc5
		
		if "`j'" == "p" local sit `"append rmtitle"'
		else local sit `""'
		
		* ii. Log variables - weighted 
		eststo clear
		rdpension $vlist if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") weight(PESO_FINAL) age(0)
		outrd second_* using "${results_tables}/ta6.csv", estlab("Pensions") `sit' age(0)
	
	}
		
	* -------------------------------------------------------------------------*
	**# 4.7. Tables A7 to A9 - Rural Pension and Acquisition of Durable Goods
	* -------------------------------------------------------------------------*
	
	foreach nome in qt15 qtt pqt {
		
		* Durable Goods bought from 2015 on - weighted estimations
		eststo clear
		rdpension  																	///
			`nome'*																	///
			if idade_p != 0 & am_fem == 1, pension(aposentado) tag("") mat weight(PESO_FINAL) age(0)
				
		matrix dur_`nome' = res
	}
	
	* Exporting results
	local ind 7
	foreach nome in qt15 qtt pqt {

		preserve

		clear
		svmat dur_`nome'
		gen id = _n
		label define lab_id 												///
			1 "Stove" 2 "Refrigerator" 3 "Shower" 4 "Water filter"		///
			5 "Dish-washer" 6 "Microwave oven" 7 "Electric oven" 		///
			8 "Iron" 9 "Washing machine" 10 "TV" 11 "Sound-system"		///
			12 "PC" 13 "Fan" 14 "Bed" 15 "Wardrobe/cabinet"				///
			16 "Kitchen table" 17 "Couch" 18 "Automobile" 				///
			19 "Motorcycle" 20 "Bicycle" 21 "Other"
		label values id lab_id
		decode id, gen(id_s)
		order id_s, first
		
		foreach v of varlist dur_`nome'1-dur_`nome'4 {
			format %4.3f `v'
		}

		tostring dur_`nome'5, format(%7.0fc) replace force

		gen ordem = dur_`nome'1
		tostring dur_`nome'1 dur_`nome'2 , replace format(%4.3f) force
		replace dur_`nome'1 = dur_`nome'1 + cond(dur_`nome'4 < 0.01, "***", cond(dur_`nome'4 < 0.05, "**", cond(dur_`nome'4 < 0.10, "*", "")))
		replace dur_`nome'2 = "(" + dur_`nome'2 + ")"
		gen star = dur_`nome'4 < 0.10
		drop dur_`nome'3 dur_`nome'4

		gsort -star -ordem

		drop ordem star id

		expdur using "${results_tables}/ta`ind'.csv", pref("dur_`nome'") idvar(id_s) replace
		
		restore
		local ind = `ind' + 1
	}
	
	
	* -------------------------------------------------------------------------*
	**# 4.8. Fig. A.3. Robustness Check on the Impact of Rural Pension on Expenses in Non-Durable Goods and Services
	* -------------------------------------------------------------------------*

		eststo clear
		
		* Specifications
		local esp1 "p(2)"
		local esp2 "p(1) bwselect(msetwo)"
		local esp3 "p(1) bwselect(cerrd)"
		local esp4 "p(1) bwselect(cersum)"
		local esp5 "p(1) covs(tamanho ANOS_ESTUDO ppi alf)"
		
		* Loop for each specification
		forvalues i = 1/5 {
			
			* Optimal bandwidth
			*-------------------------------------------------------------------
			rdbwselect lpc_ndg idade_p if idade_p != 0 & am_fem == 1 , 	///
				masspoints(adjust) c(0) fuzzy(aposentado) `esp`i'' 		///
				weights(PESO_FINAL) 
			*-------------------------------------------------------------------
			
			* Bandwidth
			if inlist(`i', 1, 5) {
				local bwr = e(h_mserd)
				local bwl = e(h_mserd)
			}
			else if `i' == 2 {
				local bwr = e(h_msetwo_r)
				local bwl = e(h_msetwo_l)
			}
			else if `i' == 3 {
				local bwr = e(h_cerrd)
				local bwl = e(h_cerrd)
			}
			else if `i' == 4 {
				local bwr = e(h_cersum)
				local bwl = e(h_cersum)
			}
			
			* Regression
			*-------------------------------------------------------------------
			eststo second_`i': rdrobust lpc_ndg idade_p 					///
				if idade_p != 0 & am_fem == 1, 								///
				masspoints(adjust) c(0) fuzzy(aposentado) `esp`i'' 			///
				weights(PESO_FINAL) `covs_opt'
			*-------------------------------------------------------------------
			
			* Storing results
			if `i' == 1 matrix res = e(b), e(ci_l_rb), e(ci_r_rb), `i'
			else matrix res = res \ (e(b), e(ci_l_rb), e(ci_r_rb), `i')
						
			* Dependent variable means in each side of the cutoff
			sum lpc_ndg if idade >= 55 - `bwl' & idade < 55 [w = PESO_FINAL]
			local mean_left = r(mean)  
			sum lpc_ndg if idade > 55 & idade <= 55 + `bwr' [w = PESO_FINAL]
			local mean_right = r(mean)  

			estadd scalar bandr `bwr': second_`i'
			estadd scalar bandl `bwl': second_`i'
			estadd scalar mean_left `mean_left' : second_`i'
			estadd scalar mean_right `mean_right' : second_`i'
			estadd local ic = "[" + string(`e(ci_l_rb)',"%4.3f") + "," + string(`e(ci_r_rb)',"%4.3f") + "]"
			
		}
		
		* Graph
			preserve
						
				clear
				svmat res
				
				label define lab_gr			///
					1 "2nd degree poly."	///
					2 "Two-sided bw."		///
					3 "CER optimal bw."		///
					4 "CER sum optimal bw."	///
					5 "Covariates"	
				
				label values res4 lab_gr
				
				tw	///
					(scatter res4 res1 , mcolor(gs6))						///
					(rcap res2 res3 res4, lcolor(gs6) horizontal)			///
				,															///
				yline(0.0, 													///
						lcolor(red) lwidth(vthin) lpattern(dash)			///
				)															///
				graphregion(color(white))									///
				ylabel(, 													///
					valuelabel glwidth(vthin) glpattern(dot) glcolor(gray)	///
					angle(horizontal) labsize(vlarge))										///
				xlabel(-1(0.5)1, glwidth(vthin) glpattern(dot) glcolor(gray) labsize(vlarge))	///
				xline(-1(0.5)1,												/// 
						lstyle(grid) lw(vthin) lcolor(gray) lpattern(dot)	///
				)															///
				xline(0,													/// 
						lstyle(grid) lw(vthin) lcolor(red) lpattern(dash)	///
				)															///
				xscale(noextend)											///
				yscale(noextend reverse)									///
				legend(off)													///
				xtitle("Coefficient", size(vlarge))										///
				ytitle("")
				
				graph export "${results_figures}/Figure_A3.eps", replace
				graph export "${results_figures}/Figure_A3.png", replace
				window manage close graph
				
			restore
			
		* Construindo tabela com as estimativas de Fuzzy RDD
		
		* Exporting results
		outrd second_* using "${results_tables}/fa3.csv", estlab("Pensions") bwt

	* -------------------------------------------------------------------------*
	**# 4.9. Fig. A4 - Bandwidth Robustness Test for the Impact of Rural Pension on Expenses on Non-Durables
	* -------------------------------------------------------------------------*
		
		* Tabela de robustez
		eststo clear
		
		* Estimando janela ótima para armazena a bandwidth
		*------------------------------------------------------------------*
		rdbwselect lpc_ndg idade_p if idade_p != 0 & am_fem == 1				///
			, masspoints(adjust) c(0) fuzzy(aposentado) p(1) weights(PESO_FINAL) covs(${covs})
		*------------------------------------------------------------------*
		
		* Bandwidths
		local bh=e(h_mserd)
		local bb=e(b_mserd)
		
		* Indicador
		local ind 1
		forvalues i = 0.4(0.2)1.6 {
			
			local bht = `i' * `bh'
			local bbt = `bb'
			
			* Regressão
			*--------------------------------------------------------------*
			eststo second_`ind': 										///
				rdrobust lpc_ndg idade_p if idade_p != 0 & am_fem == 1		///
				, masspoints(adjust) c(0) fuzzy(aposentado) 			///
				h(`bht' `bht') b(`bbt' `bbt') weights(PESO_FINAL) covs(${covs})
			*--------------------------------------------------------------*
			
			if `ind' == 1 matrix res = e(b), e(ci_l_rb), e(ci_r_rb), `i'
			else matrix res = res \ (e(b), e(ci_l_rb), e(ci_r_rb), `i')
			
			local ind = `ind' + 1
		}
		
		* Graph
		preserve
					
			clear
			svmat res
			tw	///
				(scatter res1 res4, mcolor(gs6))						///
				(scatter res1 res4 if res4 == 1, mcolor(red))			///
				(rcap res2 res3 res4, lcolor(gs6))						///
				(rcap res2 res3 res4 if res4 == 1, lcolor(red))			///
			,															///
			yline(0.0, 													///
					lcolor(red) lwidth(vthin) lpattern(dash)			///
			)															///
			graphregion(color(white))									///
			ylabel(, glwidth(vthin) glpattern(dot) glcolor(gray) labsize(vlarge))		///
			xlabel(0.4(0.2)1.6, glwidth(vthin) glpattern(dot) glcolor(gray) labsize(vlarge))		///
			xline(0.4(0.2)1.6,											/// 
					lstyle(grid) lw(vthin) lcolor(gray) lpattern(dot)	///
			)															///
			xscale(noextend)											///
			yscale(noextend)											///
			legend(off)													///
			xtitle("Multiple of Optimal Bandwidth", size(vlarge))						///
			ytitle("Coefficient", size(vlarge))
			
			graph export "${results_figures}/Figure_A4.eps", replace
			graph export "${results_figures}/Figure_A4.png", replace
			window manage close graph
			
		restore
	
	


	* -------------------------------------------------------------------------*
	**# 4.10. Fig. A1 - Manipulation Test
	* -------------------------------------------------------------------------*

	* We use user-developed command "rddisttestk", by Bringham Frandsen 
	* (https://economics.byu.edu/faculty-and-staff/frandsen/software)
	
	rddisttestk idade_p if TIPO_SITUACAO_REG == 2 & idade <= $imax & idade >=$imin & idade_p !=. & am_fem == 1 , threshold(0) k(0)
	local p0 = round(r(p),0.001)
	rddisttestk idade_p if TIPO_SITUACAO_REG == 2 & idade <= $imax & idade >=$imin & idade_p !=. & am_fem == 1 , threshold(0) k(0.01)
	local p1 = round(r(p),0.001)
	rddisttestk idade_p if TIPO_SITUACAO_REG == 2 & idade <= $imax & idade >=$imin & idade_p !=. & am_fem == 1 , threshold(0) k(0.02)
	local p2 = round(r(p),0.001)
	
	twoway 									///
		(histogram idade_p 					///
			if TIPO_SITUACAO_REG == 2 & 	///
				idade <= $imax & 			///
				idade >=$imin & idade_p !=.	///
				& am_fem == 1 			 	///
			, 								///
			fcolor(gray%35) 				///
			lcolor(black)	 				///
			lwidth(vthin)	 				///
			width(1) 						///
			xline(0, 						///
				lcolor(maroon) 				///
				lpattern(solid) 			///
				lwidth(1.25pt)				///
			) 								///
			xtitle("Age to Cutoff")					///
			ytitle("")						///
		) 									///
		(pcarrowi 0.03 0.5 0.03 5			///
			, 								///
			color(black) 					///
			lwidth(thin) 					///
			text(0.03 6 "Age to cutoff = 0", 		///
				place(e) size(small))		///
			)								///
		, 									///
		subtitle(							///
			"Manipulation test ({it:k} = 0) p-value = `p0'" 	///
			"Manipulation test ({it:k} = .01) p-value = `p1'" 	///
			"Manipulation test ({it:k} = .02) p-value = `p2'"	///
		) 														///
		legend(off)												///
		graphregion(color(white))								///
		xline(20(20)100,										/// 
			lstyle(grid) lw(vthin) lcolor(gray) lpattern(dot)	///
		)														///
		xscale(noextend)										///
		yscale(noextend)								///
		ylabel(,										///
			angle(horizontal) 							///
			glwidth(vthin) 								///
			glpattern(dot) 								///
			glcolor(gray)								///
		)
		
	qui gr export "${results_figures}/Figure_A1.eps", replace
	qui gr export "${results_figures}/Figure_A1.png", replace
	window manage close graph
	*/
	
	*--------------------------------------------------------------------------*
	**# 4.11. Fig A2 - Average per capita Income and per capita Expenses by Age Group
	*--------------------------------------------------------------------------*
	
	gen fi5 = trunc((idade - 30)/5) if idade >= 30 & idade <= 89
	
	local lab_text = ""
	forvalues i = 0/11{

		local ini = 30 + 5*`i'
		local fim = `ini' + 4
		
		local lab_text = `"`lab_text' `i' "`ini'-`fim'""'
	}
	label define lfi5 `lab_text', replace
	label value fi5 lfi5

	estpost tabstat pc_tin if am_fem == 1 [w = PESO_FINAL], s(p50)
	matrix res = e(p50)
	local pob = res[1,1]
	
	gen savingr = saving / pc_tin
	gen savingr_poor = savingr if pc_tin <= `pob'
	gen pc_0_poor = pc_0 if pc_tin <= `pob'
	gen pc_tin_poor = pc_tin if pc_tin <= `pob'
	
	preserve
		
		foreach v of varlist 										///
			savingr savingr_poor 										///
			pc_tin pc_tin_poor 										///
			pc_0 pc_0_poor										///
			{
			qui sum `v' [w = PESO_FINAL] if am_fem == 1, d
			replace `v' = . if `v' >= r(p99) | `v' <= r(p1)
		}
		
		keep if am_fem == 1
			
		gcollapse (mean) 											///
			savingr savingr_poor 										///
			pc_tin pc_tin_poor 										///
			pc_0 pc_0_poor	 [w = PESO_FINAL] if am_fem == 1, by(fi5)
		
		
		tw	///
			(line pc_tin pc_tin_poor pc_0 pc_0_poor fi5,		///
				lcolor(navy navy maroon maroon) 					///
				lpattern(dash solid dash solid) 					///
				), 													///
					xline(5, lpattern(dash)) xlabel(0(1)11, angle (90) valuelabel)	///
					yline(0, lcolor(g10)) ylabel(0(500)1500)							///
					xtitle("Age") ytitle("R$") 						///
					graphregion(color(white))						///
					legend(order(									///
						1 "Income - Total"							///
						2 "Income - Low income"						///			
						3 "Expenses - Total"						///
						4 "Expenses - Low income"					///
						) position(6) cols(2))
				
		graph export "${results_figures}/Figure_A2.eps", replace
		graph export "${results_figures}/Figure_A2.png", replace
		window manage close graph

	restore
