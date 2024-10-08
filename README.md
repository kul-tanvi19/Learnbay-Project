# Machine Breakdown and Maintenance Analysis

![23988211-ingenieur-et-electricien-travail-avec-industriel-l-eau-pompes-entretien-un-service-concept-isometrique-isole-dessin-anime-vecteur-vectoriel](https://github.com/user-attachments/assets/72715fc2-2ad5-44d5-a722-a802c6926456)

## Table of Content
  - [Objective](#Objective)
  - [Datasource](#Datasource)
  - [Data Preparation and Analysis](#Data-Preparation-and-Analysis)
  - [Data Visualization](#Data-Visualization)
  - [Insights](#Insights)
  - [Recommendations](#Recommendations)

## Objective
To conduct an analysis to identify the factors that impact machine downtime, repair costs, and productivity.

## Datasource
Dataset contains approx. 178k rows and 45 number of columns. 

## Data Preparation and Analysis
Utilized SQL for data analysis and Power BI to create interactive data visualization report.
- Bellow are the questions to address :
    1. Analyze the Machines by their age and calculates the average number of breakdowns for each age group to see if older machines tend to break down more often.
    2. Identify the top 5 breakdown-prone machines and their associated downtime.
    3. Find the pattern of the cost impact of breakdowns by machine state.
    4. Identify the impact of machine location on breakdown frequency.
    5. compares the breakdown frequency of machines that underwent preventive maintenance against those that didn't, to assess the impact of maintenance on machine reliability.

## Data Visualization
- Machine Summary Report
  ![image](https://github.com/user-attachments/assets/13a23971-6e3f-4a92-bdd5-9d852403add9)

- Machine Breakdown Summary Report
  ![image](https://github.com/user-attachments/assets/58377df8-937c-458e-b54b-d95c6d48368d)


## Insights 
- Older machines have higher breakdowns, while newer ones have fewer.
- Machines with the highest breakdown counts have lower downtime.
- Machines in Operation state with Completed maintenance have the highest breakdowns & costs, with Haryana, Punjab, and Rajasthan leading in counts.

## Recommendations
- Prioritize frequent preventive maintenance for older machines and continuously monitor them to catch issues early and prevent breakdowns. If a machine frequently requires maintenance and drives up costs, consider replacing it.
- For machines with maximum downtime despite fewer breakdowns, identify factors contributing to high downtime, such as machine age or maintenance cycle, to address the specific issues effectively.
- We need to analyze factors such as machine usage, maintenance quality, and environmental conditions. Understanding these aspects will help identify underlying issues and improve overall performance.











