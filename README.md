# US-occupational-wage-analysis-sas
Multiple regression analysis of U.S. occupational wage using BLS data and SAS
# U.S. Occupational Wage Analysis in SAS

I used multiple linear regression to study how total employment,
jobs per 1,000 jobs, and location quotient relate to mean annual wages
across occupations and states.

I cleaned the May 2025 Bureau of Labor Statistics OEWS dataset to
33,271 observations, checked regression assumptions, and fit a model
using log-transformed wages and employment. The final model explained
1.46% of the variation in log annual wages. Unequal residual variance
remained after the transformation.

## How to run

1. Download the May 2025 **All data (XLSX)** workbook from the
   [BLS OEWS data tables](https://www.bls.gov/oes/tables.htm).
2. Upload the workbook to SAS Studio and open
   `us_occupational_wage_analysis.sas`.
3. Update the `DATAFILE` path at the top of the script and run it.
