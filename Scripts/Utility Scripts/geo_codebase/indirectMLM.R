#### Load Packages ####
library( lme4 )

#### Bootstrapping Function for Analysis ####
indirect.mlm <- function( data, indices, y, x, mediator, group.id, covariates=NULL, 
                          uncentered.x=T, 
                          random.a=T, random.b=T, random.c=T, 
                          between.x=F, between.m=F ) {
  # Create resampled dataset
  resampled.data <- data[array(indices),]
  
  # Centre variables
  # Predictor
  if ( uncentered.x == T ) {
    x.by.id <- as.data.frame( tapply(resampled.data[,x], resampled.data[,group.id], mean, na.rm=T ) )
    names( x.by.id ) <- "x.by.id"
    x.by.id[group.id] <- row.names(x.by.id)
    resampled.data <- merge( resampled.data, x.by.id, by=group.id )
    resampled.data[paste("c.", x, sep="")] <- resampled.data[x] - resampled.data["x.by.id"]
  }
  
  # Mediator
  mediator.by.id <- as.data.frame( tapply(resampled.data[,mediator], resampled.data[,group.id], mean, na.rm=T ) )
  names(mediator.by.id ) <- "mediator.by.id"
  mediator.by.id[group.id] <- row.names( mediator.by.id )
  resampled.data <- merge( resampled.data, mediator.by.id, by=group.id )
  resampled.data[paste("c.", mediator, sep="")] <- resampled.data[mediator] - resampled.data["mediator.by.id"]
  
  # Create between-group variables
  if (between.x == T) {
    if ( uncentered.x == T ) {
      resampled.data[paste("c.average.", x, sep="")] <- resampled.data["x.by.id"] - mean( unlist(resampled.data["x.by.id"]), na.rm=T )
    }
    if (uncentered.x == F ) {
      between.x = F
      cat("Cannot calculate between-group effect for predictor without the uncentered, raw values of the predictor. Please provide the raw values of the predictor if you want to calculate the between-group effect for the predictor. Proceeding without calculating a between-group effect for slope a (i.e., as if 'between.x=F').")
    }
  }
  if (between.m == T) {
    resampled.data[paste("c.average.", mediator, sep="")] <- resampled.data["mediator.by.id"] - mean( unlist(resampled.data["mediator.by.id"]), na.rm=T )
  }
  
  # Create fixed effects formulas
  a.path.formula <- as.formula(paste(mediator, " ~ (1", ifelse(random.a, paste( " + ", x, sep=""), ""), "|", group.id, ") + ", ifelse(!is.null(covariates), paste(paste(covariates, collapse=" + "), " + ", sep=""), ""), x, ifelse( between.x==T, paste(" + c.average.", x, sep=""), ""), sep=""))
  b.path.formula <- as.formula(paste(y, " ~ (1", ifelse(random.c&&!random.b, paste( " + ", x, sep=""), ifelse(random.c&&random.b, paste(" + ", x, " + c.", mediator, sep=""), ifelse(!random.c&&random.b, paste(" + ", "c.", mediator, sep=""), ""))), "|", group.id, ") + ", ifelse(!is.null(covariates), paste(paste(covariates, collapse=" + "), " + ", sep=""), ""), x, ifelse( between.x==T, paste(" + c.average.", x, sep=""), ""), " + ", paste("c.", mediator, sep=""), ifelse( between.m==T, paste(" + c.average.", mediator, sep=""), ""), sep=""))
  c.path.formula <- as.formula(paste(y, " ~ (1", ifelse(random.c, paste( " + ", x, sep=""), ""), "|", group.id, ") + ", ifelse(!is.null(covariates), paste(paste(covariates, collapse=" + "), " + ", sep=""), ""), x, ifelse( between.x==T, paste(" + c.average.", x, sep=""), ""), sep=""))

  # Run models with resampled dataset 
  model.a <- do.call( "lmer", list( formula=a.path.formula, data=resampled.data, na.action="na.exclude", REML=F) )
  model.b <- do.call( "lmer", list( formula=b.path.formula, data=resampled.data, na.action="na.exclude", REML=F) )
  model.c <- do.call( "lmer", list( formula=c.path.formula, data=resampled.data, na.action="na.exclude", REML=F) )

  # Save Fixed Slopes
  fixed.slope.within.a <- coef(summary(model.a))[x,1]
  fixed.slope.within.b <- coef(summary(model.b))[paste("c.", mediator, sep=""),1]
  fixed.slope.between.a <- NA
  fixed.slope.between.b <- NA
  if (between.x == T ) { fixed.slope.between.a <- coef(summary(model.a))[paste("c.average.", x, sep=""),1] }
  if (between.m == T ) { fixed.slope.between.b <- coef(summary(model.b))[paste("c.average.", mediator, sep=""),1] }
  fixed.slope.c <- coef(summary(model.c))[x,1]
  fixed.slope.c.prime <- coef(summary(model.b))[x,1]
  
  # Save Random Slopes
  random.slope.a <- NA
  random.slope.b <- NA
  random.slope.c.prime <- NA
  if (random.a==T) { random.slope.a <- as.numeric(unlist(coef(model.a)[group.id][[1]][x])) }
  if (random.b==T) { random.slope.b <- as.numeric(unlist(coef(model.b)[group.id][[1]][paste("c.", mediator, sep="")])) }
  if (random.c==T) { random.slope.c.prime <- as.numeric(unlist(coef(model.b)[group.id][[1]][x])) }
  
  #"Population Covariance" of random slopes
  random.covariance <- NA
  if (random.a==T&random.b==T) {random.covariance <- cov( random.slope.a, random.slope.b )}
  
  #Within-Group Indirect Effects
  within.indirect.effect <- mean( random.slope.a * random.slope.b, na.rm=T )
  within.indirect.effect.biased <- fixed.slope.within.a*fixed.slope.within.b
  within.indirect.bias <- abs( within.indirect.effect.biased - within.indirect.effect )

  #Between-Group Indirect Effects
  between.indirect.effect <- NA
  between.indirect.effect <- ifelse( between.x==T&between.m==T, fixed.slope.between.a*fixed.slope.between.b,
                                     ifelse( between.x==F&between.m==T, mean( random.slope.a * fixed.slope.between.b, na.rm=T ),
                                     ifelse( between.x==T&between.m==F, mean( fixed.slope.between.a * random.slope.b, na.rm=T ),
                                     NA) ) )
  between.indirect.effect.biased <- NA
  between.indirect.effect.biased <- ifelse( between.x==T&between.m==T, fixed.slope.between.a*fixed.slope.between.b,
                                            ifelse( between.x==F&between.m==T, mean( fixed.slope.within.a * fixed.slope.between.b, na.rm=T ),
                                            ifelse( between.x==T&between.m==F, mean( fixed.slope.between.a * fixed.slope.within.b, na.rm=T ),
                                            NA) ) )
  between.indirect.bias <- abs( between.indirect.effect - between.indirect.effect.biased )
  
  # Total Effects
  total.effect <- mean( random.slope.a * random.slope.b + random.slope.c.prime, na.rm=T )
  if (random.c==F) {total.effect <- mean( random.slope.a * random.slope.b + fixed.slope.c.prime, na.rm=T )}
  total.effect.bias <- abs( fixed.slope.c - total.effect )
  
  return( c( fixed.slope.c, fixed.slope.c.prime, fixed.slope.within.a, fixed.slope.between.a, fixed.slope.within.b, fixed.slope.between.b, 
             random.covariance, within.indirect.effect, within.indirect.effect.biased, within.indirect.bias, between.indirect.effect, 
             between.indirect.effect.biased, between.indirect.bias, total.effect, total.effect.bias) )
}

#### Output Function ####
indirect.mlm.summary <- function( boot.object ) {
  with( boot.object, {
  if ((is.null(call$random.a)||(call$random.a=="T")) & (is.null(call$random.b)||call$random.b=="T")) {
    cat( "#### Population Covariance ####\n" )
    cat( paste("Covariance of Random Slopes a and b: ", round(t0[ 7], 3), " [", round(boot.ci( boot.object, index= 7, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 7, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( "\n\n" )
    cat( "#### Indirect Effects ####\n" )
    cat( "# Within-subject Effects\n" )
    cat( paste("Unbiased Estimate of Within-subjects Indirect Effect: ", round(t0[ 8], 3), " [", round(boot.ci( boot.object, index= 8, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 8, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( paste("Biased Estimate of Within-subjects Indirect Effect: ", round(t0[ 9], 3), " [", round(boot.ci( boot.object, index= 9, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 9, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( paste("Bias in Within-subjects Indirect Effect: ", round(t0[ 10], 3), " [", round(boot.ci( boot.object, index= 10, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 10, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( "\n" )
    if ( (!is.null(call$between.x)&&call$between.x=="T") || (!is.null(call$between.m)&&call$between.m=="T") ) {
      cat( "# Between-subject Effects\n" )
      cat( paste("Unbiased Estimate of Between-subjects Indirect Effect: ", round(t0[ 11], 3), " [", round(boot.ci( boot.object, index= 11, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 11, type="perc" )$perc[5], 3), "]", "\n", sep="") )
      cat( paste("Biased Estimate of Between-subjects Indirect Effect: ", round(t0[ 12], 3), " [", round(boot.ci( boot.object, index= 12, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 12, type="perc" )$perc[5], 3), "]", "\n", sep="") )
      cat( paste("Bias in Between-subjects Indirect Effect: ", round(t0[ 13], 3), " [", round(boot.ci( boot.object, index= 13, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 13, type="perc" )$perc[5], 3), "]", "\n", sep="") )
      cat( "\n" )
    }
  }
  else {
    cat( "#### Indirect Effects ####\n" )
    cat( paste("Within-subjects Indirect Effect: ", round(t0[ 9], 3), " [", round(boot.ci( boot.object, index= 9, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 9, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( "\n" )
    if ( (!is.null(call$between.x)&&call$between.x=="T") | (!is.null(call$between.m)&&call$between.m=="T") ) {
      cat( "# Between-subject Effects\n" )
      cat( paste("Between-subjects Indirect Effect: ", round(t0[ 12], 3), " [", round(boot.ci( boot.object, index= 12, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 12, type="perc" )$perc[5], 3), "]", "\n", sep="") )
      cat("\n")
    }
  }
  cat("\n")
  cat( "#### Total Effect ####\n" )
  if (((!is.null(call$random.a)&&call$random.a==T)||is.null(call$random.a)) && ((!is.null(call$random.b)&&call$random.b==T)||is.null(call$random.b))) {
    cat( paste("Unbiased Estimate of Total Effect: ", round(t0[ 14], 3), " [", round(boot.ci( boot.object, index= 14, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 14, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( paste("Biased Total Effect of X on Y (c path): ", round(t0[ 1], 3), " [", round(boot.ci( boot.object, index= 1, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 1, type="perc" )$perc[5], 3), "]", "\n", sep="") )
    cat( paste("Bias in Total Effect: ", round(t0[ 15], 3), " [", round(boot.ci( boot.object, index= 15, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 15, type="perc" )$perc[5], 3), "]", "\n", sep="") )
  }
  else {
    cat( paste("Total Effect of X on Y (c path): ", round(t0[ 1], 3), " [", round(boot.ci( boot.object, index= 1, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 1, type="perc" )$perc[5], 3), "]", "\n", sep="") )
  }
  cat("\n")
  cat("\n")
  cat( "#### Direct Effects ####\n" )
  cat( paste("Direct Effect of Predictor on Dependent Variable (c' path): ", round(t0[ 2], 3), " [", round(boot.ci( boot.object, index= 2, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 2, type="perc" )$perc[5], 3), "]", "\n", sep="") )
  cat( paste("Within-subjects Effect of Predictor on Mediator (a path for group-mean centered predictor): ", round(t0[ 3], 3), " [", round(boot.ci( boot.object, index= 3, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 3, type="perc" )$perc[5], 3), "]", "\n", sep="") )
  if ( (!is.null(call$between.x)&&call$between.x=="T") ) {cat( paste("Between-subjects Effect of Predictor on Mediator (a path for grand-mean centered average predictor): ", round(t0[ 4], 3), " [", round(boot.ci( boot.object, index= 4, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 4, type="perc" )$perc[5], 3), "]", "\n", sep="") ) }
  cat( paste("Within-subjects Effect of Mediator on Dependent Variable (b path for group-mean centered mediator): ", round(t0[ 5], 3), " [", round(boot.ci( boot.object, index= 5, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 5, type="perc" )$perc[5], 3), "]", "\n", sep="") )
  if (!is.null(call$between.m)&&call$between.m=="T") {cat( paste("Between-subjects Effect of Mediator on Dependent Variable (b path for grand-mean centered average mediator): ", round(t0[ 6], 3), " [", round(boot.ci( boot.object, index= 6, type="perc" )$perc[4], 3), ", " , round(boot.ci( boot.object, index= 6, type="perc" )$perc[5], 3), "]", "\n", sep="") ) }
  })
}
