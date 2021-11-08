#!/usr/bin/env python
# coding: utf-8




import pandas as pd
from sklearn.ensemble import RandomForestRegressor
import math
import numpy as np
import sklearn


def computeSV(ValueFeaturesFile, NetworkFile,  socialFeatures, 
                      EmptyNeighborhoodFeatureValues, idColumn = 0, ValueColumn = None,
              ResultsFileName="SVResults.csv" ):
    # Read CSV 
    svdata = pd.read_csv(ValueFeaturesFile)
    ndata = pd.read_csv(NetworkFile)
    
    # Data prep
    # Remove records with missing values
    svdata = svdata.dropna()
    ndata = ndata.dropna()
    
    
    if ValueColumn== None :
        targetVariable  = len(svdata.columns)-1 #default to last column 
    else:
        targetVariable = ValueColumn


    # prepare X and Y for model
    a = set(range(len(svdata.columns)))
    b = {idColumn,targetVariable}
    c=list(a-b)

    svdatax = svdata.iloc[:, c]
    svdatay = svdata.iloc[:, targetVariable]
    
    
    # Build random forest model over whole dataset
    #--------------------without tuning
    nTree = 100  
    sampFrac = 0.25
    numsamples = math.ceil(sampFrac*len(svdatax.index))

    print("Building forest...")
    rf = RandomForestRegressor(n_estimators = nTree)

    # Train the model on training data
    rf.fit(svdatax, svdatay)
    y_pred_rf = rf.predict(svdatax)

    print("done.")
    
    r2_score = sklearn.metrics.r2_score(svdatay, y_pred_rf)
    
    #calculate accuracy for the random forest model using binning based on log10(playtime)
    
    
    y_actual = svdatay.copy()
    y_actual = y_actual.replace(to_replace = 0, value=0.01)  #replace 0s by 0.01
    logged_y_actual= np.log10(y_actual) #take log

    h=np.histogram(logged_y_actual) #do binning #plt.hist same
    breaks = h[1]
    bin_no = [-1]*len(logged_y_actual)
    
    for j in range(0,len(logged_y_actual)):
        num = logged_y_actual[j]
        flag = False 

        for i in range(0, len(breaks)-1): # check which bin it falls into
            left = breaks[i]
            right = breaks[i+1]
            if (left<=num) & (num<right): # matches
                bin_no[j] = 10**i # this is weight, bin no is i.
                flag=True
                break 



        if flag==False and num==breaks[len(breaks)-1]: 
            bin_no[j] = 10**(len(breaks)-1)

      
    smoothing_factor = 0.01
    relative_error = [0]*len(y_actual) 

    for i in range(0,len(y_actual)):
        abs_error = abs(y_actual[i]-y_pred_rf[i])
        rel_err = abs_error / (y_actual[i]+smoothing_factor)
        relative_error[i] = rel_err * bin_no[i]



    weighted_err = sum(relative_error)/sum(bin_no) 
    accuracy_perc = 100-weighted_err*100


    # Prepare data with no neighbors being simulated 
    nonNeighborData = svdata
    numSocialFeatures = len(socialFeatures)
    defaultSocialDataBlock = None
    numRecords = len(svdata.index) 


    for j in range(0,numSocialFeatures) :
        feature = socialFeatures[j]
        nonNeighborData.iloc[:, feature] = EmptyNeighborhoodFeatureValues[j]
    
    
    # Estimate target variable when simulating no neighbors
    estimatedNoSocialY = rf.predict(nonNeighborData.iloc[:, c])
    
    # Estimate network power as difference in actual and no social simulated target variable values
    print("\nComputing sv ...")
    temp = svdata.iloc[:,targetVariable] - estimatedNoSocialY

    data = [ svdata.iloc[:,idColumn], temp.mask(temp<0, 0)]
    networkPowerFull = pd.concat(data, axis=1)
    
    networkPowerFull.columns = ['dest', 'NetworkPower_dest']


    # Join with edgeweight sums to get normalization factor which can be used to compute 
    # social value contribution for source node

    # Compute edge weight sums for each destination node. Using data frame ndata having
    # structure (source node, destination node, edgeweight)
    #normalize edge weights in network data
    ndata.columns = ['src', 'dest', 'weight']

    grouped = ndata.groupby('dest') #groupby destid
    grp_sum = grouped.aggregate(np.sum)


    grp_sum.reset_index(inplace=True)

    try:
        grp_sum = grp_sum.drop(['src'], axis=1) #deleting column sourceid
    except: 
        pass


    nndata = ndata.merge(grp_sum, how='left', on='dest', suffixes = ['_pair','_sumForDest'])

    nndata['normalized_ew'] = nndata['weight_pair'] / nndata['weight_sumForDest']

    nndata=nndata.fillna(0)
    
    
    ewsvresult = nndata.merge(networkPowerFull, how='left', on='dest')
    ewsvresult.head()
    ewsvresult['ewsv'] = ewsvresult['normalized_ew']*ewsvresult['NetworkPower_dest']
    ewsvresult.head()

    #FOR VALIDATION: write ewsvresult$sourceNodeID, ewsvresult$destinationNodeID, ewsvresult$ewsv to a file
    tempdf = pd.DataFrame()
    tempdf['source'] = ewsvresult['src']
    tempdf['dest'] = ewsvresult['dest']
    tempdf['sv'] = ewsvresult["ewsv"]
    tempdf.to_csv(ResultsFileName[:-4] + "_directed_sv.csv", header=True, index=None)
    
    
    #compute SV
    grouped = ewsvresult.groupby('src') #groupby src
    grp_sum = grouped.aggregate(np.sum)
    grp_sum.reset_index(inplace=True)

    svresult = pd.DataFrame()
    svresult["userID"]=grp_sum['src']
    svresult["SocialValue"] = grp_sum['ewsv']
    
    
    #compute Influencability
    grouped = ewsvresult.groupby('dest') #groupby dest
    grp_sum = grouped.aggregate(np.sum)
    grp_sum.reset_index(inplace=True)

    infresult = pd.DataFrame()
    infresult["userID"]=grp_sum['dest']
    infresult["Influenceability"] = grp_sum['ewsv']
    
    psresult= pd.DataFrame()
    psresult["userID"]=svdata.iloc[:,idColumn]
    psresult["PersonalSpend"] = svdata.iloc[:,targetVariable]
    
    merge1 = svresult.merge(psresult, on="userID", how="outer")
    merge1 = merge1.fillna(0)
    

    resultstable = merge1.merge(infresult, on="userID", how="outer")
    resultstable = resultstable.fillna(0)

    resultstable['AsocialValue'] = resultstable['PersonalSpend']-resultstable['Influenceability']

    resultstable['NetworkPower'] = resultstable['AsocialValue'] + resultstable['SocialValue']
    resultstable['TotalValue'] = resultstable['SocialValue'] + resultstable['AsocialValue'] + resultstable['Influenceability']

    # generate stats for each column
    metric_stat = ["Social Value", "Asocial Value", "Influenceability", "Network Power", "Personal Spend", "Total Value"]

    minimum = [min(resultstable['SocialValue']), min(resultstable['AsocialValue']), min(resultstable['Influenceability']), min(resultstable['NetworkPower']), min(resultstable['PersonalSpend']), min(resultstable['TotalValue'])]

    maximum= [max(resultstable['SocialValue']), max(resultstable['AsocialValue']), max(resultstable['Influenceability']), max(resultstable['NetworkPower']), max(resultstable['PersonalSpend']), max(resultstable['TotalValue'])]

    std = [np.std(resultstable['SocialValue']), np.std(resultstable['AsocialValue']), np.std(resultstable['Influenceability']), np.std(resultstable['NetworkPower']), np.std(resultstable['PersonalSpend']), np.std(resultstable['TotalValue'])]

    mean= [np.mean(resultstable['SocialValue']), np.mean(resultstable['AsocialValue']), np.mean(resultstable['Influenceability']), np.mean(resultstable['NetworkPower']), np.mean(resultstable['PersonalSpend']), np.mean(resultstable['TotalValue'])]

    total = [sum(resultstable['SocialValue']), sum(resultstable['AsocialValue']), sum(resultstable['Influenceability']), sum(resultstable['NetworkPower']), sum(resultstable['PersonalSpend']), sum(resultstable['TotalValue'])]

    data = {'Metric':metric_stat, 'Min':minimum, 'Max':maximum, 'Std': std, 'Mean': mean, 'Total':total}
    stat_df = pd.DataFrame(data)
    

    social_percentage = sum(resultstable['SocialValue']) / (sum(resultstable['SocialValue']) + sum(resultstable['AsocialValue']))
  
    print("done, writing results to file\n")
    
    resultstable.to_csv(ResultsFileName, header=True, index=None)

    return (stat_df, social_percentage*100, r2_score, accuracy_perc)
    


