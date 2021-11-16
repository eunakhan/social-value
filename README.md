##READ THIS FIRST: LICENSING
This software, and the algorithm within, are available for non-commercial, academic and research purposes only. To license the algorithm and code for commercial use, please contact The USC Stevens Center for Innovation at CONTACT INFO HERE.

For non-commercial users:
This software is Copyright © 2021 The University of Southern California. All Rights Reserved.
Permission to use, copy, modify, and distribute this software and its documentation for educational, research
and non-profit purposes, without fee, and without a written agreement is hereby granted, provided that the
above copyright notice, this paragraph and the following three paragraphs appear in all copies.
Permission to make commercial use of this software may be obtained by contacting:
USC Stevens Center for Innovation
University of Southern California
1150 S. Olive Street, Suite 2300
Los Angeles, CA 90115, USA
This software program and documentation are copyrighted by The University of Southern California. The
software program and documentation are supplied "as is", without any accompanying services from USC. USC
does not warrant that the operation of the program will be uninterrupted or error-free. The end-user
understands that the program was developed for research purposes and is advised not to rely exclusively on the
program for any reason.
IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO ANY PARTY FOR
DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST
PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE
UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE. THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED 
5
HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS NO
OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
MODIFICATIONS.


# Instructions          
This ReadMe file explains the computation of Social Value on the accompanying demo dataset using the supplied code. Please see the accompanying paper published in the Journal of Advertising <ADD HYPERLINK WHEN AVAILABLE> for a thorough explanation of the phenomenon and the metrics generated here. Please cite that paper when publishing related research or content. <CITATION INFO, DOI, ETC.>

## INTRODUCTION

The accompanying software can be used to mine "Social Value" (which is defined in the paper "Social Value: A Computational Model for Measuring Influence on Purchases and Actions for Individuals and Systems") of users in a system. In short, Social Value is the collective behavioral impact a person has on others in their network. In other words, the amount (of money or time or anything else that is objectively quantifiable) that a person causes others in a system to spend is called their Social Value. The software contains a python code named ```compute_sv_func.py``` which contains the function ```compute_sv()``` to compute the Social Value along with some other related metrics for each users in a given system. There are a series of other metrics for being influenced and for actions not related to others' behavior. Please see the Journal paper for details and context.


## A BRIEF DESCRIPTION OF THE APPROACH


Note: A demo dataset is also included along with the software. The demo dataset can be used as an walkthrough example in order to better understand how to use the accompanying code. This dataset is real, and anonymized data, provided courtesy of Wargaming, Inc. It is from players of their game World of Tanks. We offer significant thanks to them for their support of research.

The approach used in the accompanying code achieves the objective via the following process -

1) Learn a model which predicts the value of users as a response of various covariates describing these users' participation as well as social behavior in the system.
- This step requires as input a comma-separated-value file with covariates (features) and response for each user on one row.
- See example file, ```demodatafeatures.csv``` (number of users: 73,433,  8 covariates + 1 response for each user) where the 4th column, ```session_length``` is used as the response for demo purposes.
- Right now the code only supports continuous responses.

2) Use the model to estimate, for each user, the expected contribution of the social behavior based covariates on the response.

3) Use social network information as well as the values obtained in step #2 to compute Social Value (as well as other related measures and metrics) for each user.
- This step requires as input a comma-separated-value file with each edge on one row. The network is assumed to be directed with non-negative edge weights.
- Each row in the file represents one edge and has the form -
```edgeSourceID, edgeDestinationID, edgeWeight```
- See example file: ```demodatanetwork.csv```, number of edges among users in ```demodatafeatures.csv```: 2,277,685

4) Write results to a comma-separated-value file which can be viewed in Microsoft excel or any other spreadsheet data processing tool.

5) Along with the Social Value results, the code also returns various information about how well the model predicts the response value. The general idea is, the better the model predicts the response value, the better the confidence in the Social Value results.

Datasets having (1) covariates measuring asocial as well as social factors along with a suitable value based response for a population of users, as well as (2) network information for these users
are ideal candidate datasets for this software.

## Input and Output
The prototype of the function is,

```
computeSV(ValueFeaturesFile, NetworkFile,  socialFeatures, 
          EmptyNeighborhoodFeatureValues, idColumn = 0, ValueColumn = None,
          ResultsFileName="SVResults.csv" )
```
**Input parameters:**

- **ValueFeaturesFile:** Location/filename for comma-separated-value file with covariates (features) and response for each user on one row. This file may contain header.
- **NetworkFile:** Location/filename for comma-separated-value file with each edge (with their weights) of the social network on one row, i.e., ```sourceID, destinationID, edgeWeight```. This file may contain header.
- **SocialFeatures:** A list of indices of all the social featues in ```ValueFeaturesFile```.
- **EmptyNeighborhoodFeatureValues:** A list of values that SocialFeatures will take for a user with no neighbors.
- **idColumn:** The index of the user identifier (UserId) column in ```ValueFeaturesFile``` (If no value provided then defaults to the first column in ValueFeaturesFile).
- **ValueColumn:** The index of the user value response column in ```ValueFeaturesFile``` (If no value provided then defaults to the last column in ```ValueFeaturesFile```).
- **ResultsFileName:** Name of the comma-separated-value file into which all the results will be written. (If no value is provided then defaults to ```SVResults.csv```)

**Output:**
The code computes,
- Social Value, Asocial Value, Influenceability, Network Power, Personal Spend, Total Value for each user in the system. These are written in the ```ResultsFileName``` file.
- Edgewise Social Value (Social Value of each person on another) which is written in the file named ```SVResults_directed_sv.csv```.

The code also returns a tuple which consists of the following items in order:
- A dataframe listing the minimum, maximum, standard deviation, mean and total for each of the above mentioned metrics.
- How much social the system is (in percentage).
- The R-squared value for the model (learned in step 1 mentioned above) prediction.
- The accuracy percentage of the model (learned in step 1 mentioned above).


## HOW TO USE THE CODE

The code is written in python3 and can be run using any python interpreter given that the packages (pandas, numpy, sklearn) are installed properly.

Put all the code and data in the working directory. 
The following commands can then be run in the python interpreter to execute the code for the demodata and compute Social Value as well as other related measures -

```
> import compute_sv_func
> res = computeSV("demodatafeatures.csv", "demodatanetwork.csv", [5,6,7,8], [0,0,0,31], 0, 3, "SVResultsOnDemoData.csv")
```

The first command loads up the function for computing Social Value in Python's environment and makes it available to use.
The second command invokes the Social Value computation function. 

In the demo data we have four social features:
  1. neighborhood_age_in_weeks: Average membership age of neighbors  
  2. neighborhood_num_sessions: Average number of sessions of neighbors
  3. neighborhood_session_length: Average session length of neighbors
  4. neighborhood_days_inactive: Average number of days of inactivity of neighbors. In case of a user having no neighbors, values of 0,0,0 and 31 respectively are assigned to each of the social features.

The results for the demo data are written to the output file SVResultsOnDemoData.csv, which can be viewed in Microsoft excel.

To print the statistics of the different columns (social value, asocial value, etc.), type,
```
> res[0]
```

To get the percentage of social value, type,
```
> res[1]
```

To print the R-squared value of the model, write:
```
> res[2]
```

To print the accuracy of the model, write:
```
> res[3]
```
