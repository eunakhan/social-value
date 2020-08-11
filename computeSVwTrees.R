require(randomForest)
computesv <- function(ValueFeaturesFile, NetworkFile, 
                      idColumn = 1, ValueColumn = NULL, socialFeatures, 
                      EmptyNeighborhoodFeatureValues, ResultsFileName="SVResults.csv" ) {
  
  
  # Program parameters
  socialFeaturesDefaultValues <- EmptyNeighborhoodFeatureValues
  nTr <- 20
  sampFrac <- 0.25
  resultsFilename <- ResultsFileName
  featuresFileName <- ValueFeaturesFile
  networkFileName <- NetworkFile
  
  # Read CSV into R
  svdata <- read.csv(file=ValueFeaturesFile, header=TRUE,stringsAsFactors = FALSE)
  ndata <- read.csv(file=NetworkFile, header=TRUE,stringsAsFactors = FALSE)
  
  # Data prep: Remove records with missing values, scale the values in the data
  svdata <- na.omit(svdata)
  if (is.null(ValueColumn)) targetVariable <- ncol(svdata) else targetVariable <- ValueColumn
  
  svdatax <- svdata[,-c(idColumn,targetVariable)]
  svdatay <- svdata[,targetVariable]
  names(svdata)[idColumn] <- paste("userID")
  ndata <- na.omit(ndata)
  
  
  # Build forest model over whole dataset
  cat("Building forest...")
  cvmodelvals <- rfcv(trainx = svdatax, trainy = svdatay,cv.fold=10,
                      ntree = nTr, sampsize=ceiling(sampFrac*nrow(svdatax)) )
  
  rf_model = randomForest(svdatax, y = svdatay , ntree = nTr, importance = TRUE,sampsize=ceiling(sampFrac*nrow(svdatax)) )
  y_pred_rf = predict(rf_model , svdatax)
  cat(" done\n")
  
  #calculate accuracy for the random forest model using binning based on log10(playtime)
  y_actual = svdatay
  
  mod_y_actual = rapply(list(y_actual),function(x) ifelse(x==0, 0.01,x), how = "replace") #replace 0s by 0.01
  mod_y_actual = unlist(mod_y_actual)
  logged_y_actual = log10(mod_y_actual) #take log
  
  par(mar=c(1,1,1,1))
  h<-hist(logged_y_actual) #do binning 
  breaks = h$breaks
  bin_no = rep(-1, length(logged_y_actual))
  
  for (j in 1:length(logged_y_actual)){
    num = logged_y_actual[j]
    flag=FALSE
    
    for (i in 1:(length(breaks)-1)){ # check which bin it falls into
      left = breaks[i]
      right = breaks[i+1]
      if( (left<=num) & (num<right)){ # matches
        bin_no[j] = 10**(i-1) # this is weight, bin no is i.
        flag=TRUE
        break 
      }
    }
    
    if (flag==FALSE & num==breaks[length(breaks)]) 
      bin_no[j] = 10**(length(breaks)-1)

  }
  
  smoothing_factor = 0.01
  relative_error = rep(0, length(y_actual))
  
  for (i in 1:length(y_actual)){
    abs_error = abs(y_actual[i]-y_pred_rf[i])
    rel_err = abs_error / (y_actual[i]+smoothing_factor)
    relative_error[i] = rel_err * bin_no[i]
  }
  
  weighted_err = sum(relative_error)/sum(bin_no) 
  accuracy_perc = 100-weighted_err*100
  cat("accuracy %: ", accuracy_perc)
  
  
  # Prepare data with no neighbors being simulated 
  nonNeighborData <- svdata
  numSocialFeatures <- length(socialFeatures)
  defaultSocialDataBlock <- NULL
  numRecords <- nrow(svdata)
  for(j in 1:numSocialFeatures) {
    defaultSocialDataBlock <- 
      c(defaultSocialDataBlock,rep(socialFeaturesDefaultValues[j],numRecords))
  }
  nonNeighborData[,socialFeatures] <- defaultSocialDataBlock
  
  # Estimate target variable when simulating no neighbors
  estimatedNoSocialY <- predict(rf_model,nonNeighborData[,-c(idColumn,targetVariable)])
  
  # Estimate network power as difference in actual and no social simulated target variable values
  cat("\nComputing sv ...")
  networkPowerFull <- data.frame(svdata[,idColumn], pmax(0,(svdata[,targetVariable] - estimatedNoSocialY)) )
  
  # Join with edgeweight sums to get normalization factor which can be used to compute 
  # social value contribution for source node
  
  # Compute edge weight sums for each destination node. Using data frame ndata having
  # structure (source node, destination node, edgeweight)
  colnames(ndata) <- c("sourceNodeID","destinationNodeID","ew")
  aggrndata <- aggregate(ndata[,3] ~ ndata[,2], ndata, sum)
  names(aggrndata)[1] <- paste("destinationNodeID")
  
  # Normalize edgeweights in network data
  nndata <- merge(x=aggrndata,y=ndata, by="destinationNodeID")
  nndata$normalizedew <- nndata[,4] /nndata[,2]
  
  # Join network power with destination node in network 
  names(networkPowerFull)[1] <- paste("destinationNodeID")
  names(networkPowerFull)[2] <- paste("NetworkPower")
  ewsvresult <- merge(x=nndata,y=networkPowerFull,by="destinationNodeID")
  
  # Aggregate edge wise network power for computing social value as well as network power of source nodes
  ewsvresult$ewsv <- ewsvresult$normalizedew*ewsvresult$NetworkPower
  
  #FOR VALIDATION: write ewsvresult$sourceNodeID,ewsvresult$destinationNodeID, ewsvresult$ewsv to a file
  tempdf <- data.frame(source=ewsvresult$sourceNodeID, dest=ewsvresult$destinationNodeID, sv= ewsvresult$ewsv)
  write.csv(tempdf, "directed_sv.csv", quote=FALSE, row.names=FALSE)
  ####
  
  svresult <- aggregate(ewsv ~ sourceNodeID, ewsvresult, sum)
  names(svresult)[1] <- paste("userID")
  names(svresult)[2] <- paste("SocialValue")
  npresult <- aggregate(ewsv ~ destinationNodeID, ewsvresult, sum)
  names(npresult)[1] <- paste("userID")
  names(npresult)[2] <- paste("Influenceability") #***influenceability hobe, not Network power
  psresult <- data.frame(svdata$userID,svdata[,targetVariable])
  names(psresult)[1] <- paste("userID")
  names(psresult)[2] <- paste("PersonalSpend")
  
  # Put together influenceability, social value, personal spend in one record
  join1 <- merge(psresult, svresult, by="userID", all=TRUE)
  join1[is.na(join1)] <- 0
  resultstable <- merge(join1,npresult, by="userID", all=TRUE)
  resultstable[is.na(resultstable)] <- 0
  resultstable$AsocialValue <- resultstable$PersonalSpend - resultstable$Influenceability
  
  
  
  resultstable$NetworkPower <- resultstable$AsocialValue + resultstable$SocialValue 
  resultstable$TotalValue <- resultstable$SocialValue + resultstable$AsocialValue + resultstable$Influenceability
  
  #generate stats for each column
  metric_stat = c("Social Value", "Asocial Value", "Influenceability", "Network Power", "Personal Spend", "Total Value")
  
  minimum = c(min(resultstable$SocialValue), min(resultstable$AsocialValue), min(resultstable$Influenceability), min(resultstable$NetworkPower), min(resultstable$PersonalSpend), min(resultstable$TotalValue))
  
  maximum= c(max(resultstable$SocialValue), max(resultstable$AsocialValue), max(resultstable$Influenceability), max(resultstable$NetworkPower), max(resultstable$PersonalSpend), max(resultstable$TotalValue))
  
  std = c(sd(resultstable$SocialValue), sd(resultstable$AsocialValue), sd(resultstable$Influenceability), sd(resultstable$NetworkPower), sd(resultstable$PersonalSpend), sd(resultstable$TotalValue))
  
  mean= c(mean(resultstable$SocialValue), mean(resultstable$AsocialValue), mean(resultstable$Influenceability), mean(resultstable$NetworkPower), mean(resultstable$PersonalSpend), mean(resultstable$TotalValue))
  
  total = c(sum(resultstable$SocialValue), sum(resultstable$AsocialValue), sum(resultstable$Influenceability), sum(resultstable$NetworkPower), sum(resultstable$PersonalSpend), sum(resultstable$TotalValue))
  
  stat_df = data.frame(metric_stat, minimum, maximum, std, mean, total)
  
  social_percentage = sum(resultstable$SocialValue) / (sum(resultstable$SocialValue) + sum(resultstable$AsocialValue))
  
  cat(" done, writing results to file\n")
  
  # Results of SV computation are now available in results table
  write.csv(resultstable,file=resultsFilename,quote=FALSE,row.names=FALSE)
  
  return(list(rfmodel=rf_model,results=resultstable, rfcvmodelquality = cvmodelvals, predictions = y_pred_rf, stat=stat_df, social_percentage=social_percentage*100, accuracy_percentage=accuracy_perc))
  
}
