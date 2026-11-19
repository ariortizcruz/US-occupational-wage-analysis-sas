/* Update DATAFILE below to point to the workbook on your SAS server. */
proc import datafile="/your/sas/folder/all_data_M_2025.xlsx"
    out=work.bls_raw
    dbms=xlsx
    replace;
    sheet="All May 2025 data";
    getnames=yes;
run;

proc contents data=work.bls_raw;
run;


/* Step 2: Clean the BLS Dataset */

data work.bls_clean;
    set work.bls_raw;

    /* Keep only detailed occupations */
    if strip(O_GROUP) ne "detailed" then delete;

    /* Keep only state-level observations */
    if strip(vvalue(AREA_TYPE)) ne "2" then delete;

    /* Keep cross-industry observations */
    if strip(vvalue(NAICS)) ne "000000" then delete;

    /* Keep all-ownership estimates */
    if strip(vvalue(OWN_CODE)) ne "1235" then delete;

    /* Convert variables to numeric */
    wage = input(compress(vvalue(A_MEAN), ',$ '), ?? best32.);
    employment = input(compress(vvalue(TOT_EMP), ',$ '), ?? best32.);
    jobs_per_1000 = input(strip(vvalue(JOBS_1000)), ?? best32.);
    location_quotient = input(strip(vvalue(LOC_QUOTIENT)), ?? best32.);

    /* Remove observations with missing values */
    if nmiss(wage, employment, jobs_per_1000,
             location_quotient) > 0 then delete;

    /* Remove invalid values */
    if wage <= 0 or employment <= 0 then delete;
    if jobs_per_1000 <= 0 or location_quotient <= 0 then delete;

run;

/* Count observations after cleaning */

proc means data=work.bls_clean n;
    var wage;
    title "Number of Observations After Cleaning";
run;

/* Display the first 10 observations */

proc print data=work.bls_clean(obs=10);
    var AREA_TITLE OCC_TITLE wage employment
        jobs_per_1000 location_quotient;
    title "First 10 Cleaned Observations";
run;







/* Step 3: Check for duplicate observations */

proc sort data=work.bls_clean out=work.bls_sorted;
    by AREA_TITLE OCC_CODE;
run;

data work.duplicates;
    set work.bls_sorted;
    by AREA_TITLE OCC_CODE;

    if not (first.OCC_CODE and last.OCC_CODE);
run;

/* Count duplicates */
proc means data=work.duplicates n;
    var wage;
    title "Number of Duplicate Observations";
run;

/* Display duplicates if any */
proc print data=work.duplicates(obs=20);
    var AREA_TITLE OCC_CODE OCC_TITLE;
    title "Duplicate Occupation-State Records";
run;


/* Step 4A: Descriptive Statistics */

proc means data=work.bls_clean
    n mean std min median max maxdec=2;

    var wage employment jobs_per_1000
        location_quotient;

    title "Descriptive Statistics for BLS Wage Data";
run;


/* Step 4B: Correlation Analysis */

proc corr data=work.bls_clean pearson;
    var wage employment jobs_per_1000
        location_quotient;

    title "Correlations Between Wages and Predictors";
run;


/* Step 4C: Wage vs Employment */

proc sgplot data=work.bls_clean;
    scatter x=employment y=wage;
    reg x=employment y=wage;

    xaxis label="Total Employment";
    yaxis label="Mean Annual Wage ($)";

    title "Mean Annual Wage vs Total Employment";
run;


/* Step 4D: Wage vs Location Quotient */

proc sgplot data=work.bls_clean;
    scatter x=location_quotient y=wage;
    reg x=location_quotient y=wage;

    xaxis label="Location Quotient";
    yaxis label="Mean Annual Wage ($)";

    title "Mean Annual Wage vs Location Quotient";
run;



/* Step 4E: Wage vs Jobs Per 1,000 */

proc sgplot data=work.bls_clean;
    scatter x=jobs_per_1000 y=wage;
    reg x=jobs_per_1000 y=wage;

    xaxis label="Employment Per 1,000 Jobs";
    yaxis label="Mean Annual Wage ($)";

    title "Mean Annual Wage vs Jobs Per 1,000 Jobs";
run;

/* Step 5A: Initial Multiple Regression Model */

ods graphics on;

proc reg data=work.bls_clean plots(only)=diagnostics;
model wage = employment jobs_per_1000
     location_quotient / vif clb;
output out=work.model_diagnostics
 p=predicted
 r=residual
 student=student_resid
 cookd=cooks_d;
title "Initial Multiple Regression Model";
run; quit;

ods graphics off;

/* STEP 6: Regression Diagnostics */

/* 6A: Fit model and generate diagnostic statistics */

ods graphics on;

proc reg data=work.bls_clean plots(only)=(diagnostics residuals(smooth) qq);
model wage = employment jobs_per_1000
     location_quotient / vif clb;
output out=work.diagnostics
 p=predicted
 r=residual
 student=student_resid
 cookd=cooks_d
 h=leverage;
title "Initial Model Regression Diagnostics";
run;
quit;

/* 6B: Check normality of residuals */

proc univariate data=work.diagnostics normal;
var residual;
histogram residual / normal;
qqplot residual / normal(mu=est sigma=est);
title "Normality of Regression Residuals";
run;

/* 6C: Check constant variance and linearity */

proc sgplot data=work.diagnostics;
scatter x=predicted y=residual;
loess x=predicted y=residual;
refline 0 / axis=y;
xaxis label="Predicted Annual Wage";
yaxis label="Residual";
title "Residuals vs Predicted Values";
run;

/* 6D: Check influential observations */

proc means data=work.diagnostics
n mean std min max;
var student_resid cooks_d leverage;
title "Influence and Outlier Statistics";
run;

/* 6E: Display observations with largest Cook's D */

proc sort data=work.diagnostics
out=work.influence_sorted;
by descending cooks_d;
run;

proc print data=work.influence_sorted(obs=10);
var AREA_TITLE OCC_TITLE wage student_resid cooks_d leverage;
title "Top 10 Most Influential Observations";
run;

ods graphics off;

/* STEP 7A: Create Transformed Variables */

data work.bls_transformed;
set work.bls_clean;

/* Natural logarithm transformations */
log_wage = log(wage);
log_employment = log(employment);
run;

/* Check transformed variables */

proc means data=work.bls_transformed
n mean std min max maxdec=3;
var log_wage log_employment
  jobs_per_1000 location_quotient;
title "Summary of Transformed Variables";
run;

/* STEP 7B: Transformed Multiple Regression */

ods graphics on;

proc reg data=work.bls_transformed
plots(only)=(diagnostics residuals(smooth) qq);
model log_wage =
 log_employment
 jobs_per_1000
 location_quotient
 / vif clb;
output out=work.log_diagnostics
 p=log_predicted
 r=log_residual
 student=log_student
 cookd=log_cooks
 h=log_leverage;
title "Transformed Multiple Regression Model";
run; quit;

ods graphics off;

/* STEP 7C: Normality of Transformed Residuals */

ods graphics on;

proc univariate data=work.log_diagnostics normal;
var log_residual;
histogram log_residual / normal;
qqplot log_residual / normal(mu=est sigma=est);
title "Normality of Transformed Model Residuals";
run;

/* Residuals vs Predicted Log Wages */

proc sgplot data=work.log_diagnostics;
scatter x=log_predicted y=log_residual;
loess x=log_predicted y=log_residual;
refline 0 / axis=y;
xaxis label="Predicted Log Annual Wage";
yaxis label="Residual";
title "Transformed Model Residuals vs Predicted";
run;

ods graphics off;

/* STEP 7D: Influence Statistics */

proc means data=work.log_diagnostics
n mean std min max maxdec=5;
var log_student log_cooks log_leverage;
title "Transformed Model Influence Statistics";
run;

/* Sort by Cook's Distance */

proc sort data=work.log_diagnostics
out=work.log_influence_sorted;
by descending log_cooks;
run;

/* Show the 10 most influential observations */

proc print data=work.log_influence_sorted(obs=10);
var AREA_TITLE OCC_TITLE wage log_student log_cooks log_leverage;
title "Top 10 Influential Observations";
run;
