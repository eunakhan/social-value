# svcode
Computation of social value on WG dataset (3-22-18 v1.1)

## INTRODUCTION

The accompanying software can be used to mine "Social worth" of users in a system. Consider a system consisting of several users interacting with each other. These users are participants in the system and their participation creates "worth". This value for each user can be measured and/or estimated. The objective is to quantify the effect of social factors on this value from the users.


## A BRIEF DESCRIPTION OF THE APPROACH

Note: A demo dataset is also included along with the software. The demo dataset can be used as an walkthrough example in order to better understand how to use the accompanying code.

The approach used in the accompanying code achieves the objective via the following process -

1) Learn a model which predicts the value of users as a response of various covariates describing these users' participation as well as social behavior in the system.
Input: This step requires as input a comma separated value file with covariates and response for each user on one row.
(See example file: demodatafeatures.csv, # of users: 73,433,  8 covariates + 1 response for each user.
In the example file, the 4th column, session_length is used as the response for demo purposes)

2) Use the model to estimate, for each user, the expected contribution of the social behavior based covariates on the response.

3) Use social network information as well as the values obtained in step #2 to compute social worth (as well as other related measures and metrics) for each user.
Input: This step requires as input a comma separated file with each edge on one row. The network is assumed to be directed with non-negative edge weights.
Each row in the file represents one edge and has the form -
edgeSourceID, edgeDestinationID, edgeWeight
(See example file: demodatanetwork.csv, number of edges among users in demodatafeatures.csv: 2,277,685) -

4) Write results to a comma-separated-value file which can be viewed in Microsoft excel or any other spreadsheet data processing tool.

5) Along with the sv results, the code also returns various information about how well the model predicts the response value. The general idea is, the better the model predicts the response value,
the better the confidence in the sv results.
Note: Quantifying the effect of the quality of the model on the sv value estimation confidence is one of the main focus area and a work in progress.

Technically the method can work on a continuous or binary response but right now the code only supports continuous responses. Support for multiple class/categorical responses will be added in the near future.
Datasets having (1) covariates measuring asocial as well as social factors along with a suitable value based response for a population of users, as well as (2) network information for these users
are ideal candidate datasets for this software.


## HOW TO USE THE CODE

The code is written in R and can be run using RStudio. If not available, R and the free version of RStudio can be downloaded and installed from [R-project](https://www.r-project.org/) and [RStudio](https://www.rstudio.com/products/rstudio/download/#download) respectively.

Set your working directory in RStudio to be the location on your laptop/PC where you plan on running the analysis. Copy all the accompanying code (as well as the demodata if using it)
into the working directory. The following commands can now be run in RStudio to execute the code and compute social worth as well as other related measures -

```
> source("computeSVwTrees.R")
> resultset <-
       computesv( ValueFeaturesFile, NetworkFile, idColumn = 1, ValueColumn = NULL, socialFeatures, EmptyNeighborhoodFeatureValues, ResultsFileName = "SVResults.csv" )
```

The first command loads up the function, for computing social worth, in RStudio's environment and makes it available to use.
The second command invokes the social worth computation function. This function returns a dataframe, stored in variable resultset,
which lists the asocial value, social value, personal spend as well as influenceability of each user. These values are also written to an output file
which can be opened in Microsoft excel or any other spreadsheet viewer.

The method requires various information as input and also writes the results to a file. All of this can be controlled via the arguments passed to the method.


Arguments -

- **ValueFeaturesFile:** Location/filename for comma separated value file with covariates and response for each user on one row.
- **NetworkFile:** Location/filename for comma separated file with each edge of the social network on one row.
- **idColumn:** The index of the user identifier/ UserId column in ValueFeaturesFile (If no value provided then defaults to the first column in ValueFeaturesFile).
- **ValueColumn:** The index of the user value response column in ValueFeaturesFile (If no value provided then defaults to the last column in ValueFeaturesFile).
- **SocialFeatures:** A vector of indexes of all the social featues in ValueFeaturesFile.
- **EmptyNeighborhoodFeatureValues:** A vector of values that SocialFeatures will take for a user with no neighbors.
- **ResultsFileName:** The comma-separated-value file into which all the results will be written. (If no value is provided then defaults to SVResults.csv)


Example for demodata -

```
> source("computeSVwTrees.R")
> results <-
       computesv( ValueFeaturesFile="demodatafeatures.csv", NetworkFile="demodatanetwork.csv", idColumn = 1, ValueColumn = 4, socialFeatures = c(6,7,8,9),
		EmptyNeighborhoodFeatureValues = c(0,0,0,31), ResultsFileName="SVResultsOnDemoData.csv" )
```

In the demo data we have four social features:
  1. neighborhood_age_in_weeks: Average membership age of neighbors  
  2. neighborhood_num_sessions: Average number of sessions of neighbors
  3. neighborhood_session_length: Average session length of neighbors
  4. neighborhood_days_inactive: Average number of days of inactivity of neighbors. In case of a user having no neighbors, values of 0,0,0 and 31 respectively are assigned to each of the social features.

The results for the demo data are written to the output file SVResultsOnDemoData.csv, which can be viewed in Microsoft excel.


## DIAGNOSTICS (NOT ADDED YET BUT WILL BE COMING VERY SOON)

The root-mean-squared-error, R-sqaured measure, mean absolute deviance and the mean absolute percentage error are returned as measures of goodness of fit of the model predicting value for users.
Generally, the lower the error, the better the features are able to explain the user values and consequently the more confident the social worth value estimation.
