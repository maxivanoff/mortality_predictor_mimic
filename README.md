# Mortality Predictor using MIMIC-III database

This is an ongoing project that aims to develop a set of models that predict whether the patient will survive in the intensive care unit (ICU) given its demographic and medical data. The project relies on the Medical Information Mart for Intensive Care ([MIMIC-III](https://physionet.org/content/mimiciii/1.4/)) database.

## Getting Started

### Prerequisites: database

In order to access the MIMIC-III database, you will need to complete the CITI “Data or Specimens Only Research” course at [CITI Program](https://www.citiprogram.org/index.cfm?pageID=154&icat=0&ac=0). After the course completion, you need to register for an account on [PhysioNet](https://physionet.org) and submit an application for credentialed access to MIMIC-III database. Once the application is approved, you will receive an email containing instructions for downloading the database. 


Before deciding whether or not to carry out an analysis on the full dataset, one can explore the [MIMIC-III demo database](https://physionet.org/content/mimiciii-demo/1.4/) that allows to review the structure and content of the full MIMIC-III database.

### Prerequisites: packages

Several external packages are needed to run the code

* psycopg2
* numpy, pandas
* sklearn, PyTorch
* matplotlib, searborn

## Content

The final code is in the project_code.ipynb and the remaining IPython notebooks contain additional coding and explorations. Please see the textual description of the project in project_report.pdf. The file project_proposal.pdf contains on original proposal for this project.
