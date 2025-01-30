*------------------------------------------------------------------------------*
* Replicating codes for the article 
* "Assessing the Permanent Income Hypothesis in Poor Areas: 
* The Case of Rural Pensions in Brazil"
*------------------------------------------------------------------------------*

* Folders

* Main folder contains two subfolders:
* - code: codes to run the analysis
* - input: raw data from POF (in the subfolder "pof") and other data (in the subfolder "extra")

* This code will create two more subfolders in the main folder:
* - data: stores the datasets created from raw POF data
* - results: stores tables and figures derived from the analysis

* We use user-developed command "rddisttestk", by Bringham Frandsen 
* (https://economics.byu.edu/faculty-and-staff/frandsen/software)
	
* User input
cd "" // Set main folder
global personal_folder ""	// set folder where "rddisttsetk" is installed

* Linking folder to Stata
sysdir set PERSONAL "${personal_folder}"

* Creating folders
mkdir data
mkdir results
mkdir results/tables
mkdir results/figures

global data "./data"
global input_pof "./input/pof"
global input_other "./input/other"
global results_tables "./results/tables"
global results_figures "./results/figures"

* Identifyers for household, family, and person in POF
global dom COD_UPA NUM_DOM	// household identifier
global uc COD_UPA NUM_DOM NUM_UC	// family identifier
global morador COD_UPA NUM_DOM NUM_UC COD_INFORMANTE	// person identifier

* Age limits for the sample
global imin 30	// minimum age
global imax 90	// maximum age

* Age cutoffs for rural pension
global cfem 55	// age cutoff for females
global cmas 60	// age cutoff for males

* Run, in order:
do "./code/expenditure.do"
do "./code/income.do"
do "./code/data.do"
do "./code/functions.do"
do "./code/results.do"
