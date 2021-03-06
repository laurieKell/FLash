utils::globalVariables('laply')

#' tac , 
#' 
#' Calculates the Total Allowable Catch for a \code{biodyn} object and target harvest rate
#' by projecting the last year.
#'
#' @param  object an object of class \code{biodyn} or
#' @param  harvest an \code{FLQuant} object with harvest rate
#' @param ... other arguments
#' 
#' @return FLQuant object with TAC value(s)
#' 
#' @seealso \code{\link{hcr}},  \code{\link{fwd}}
#' 
#' @export
#' @rdname tac
#' @aliases tac tac-method tac,biodyn-method
#' 
#' @examples
#' \dontrun{
#' tac(bd,FLQuant(0.1,dimnames=list(year=dims(bd)$maxyear)))
#' }
#' 
setGeneric('tac', function(object,eql,...) standardGeneric('tac'))
setMethod( 'tac', signature(object='FLStock',eql='FLBRP'),
           function(object,eql,harvest,
                    sr.residuals=FLQuant(1,dimnames=dimnames(rec(object))), 
                    sr.residuals.mult=TRUE,
                    ...){

             yrs  =dimnames(harvest)$year  
             #maxY =max(as.numeric(yrs))
          
             #stock(object)=window(stock(object),end=maxY)
             #stock(object)[,ac(maxY)]=stock(object)[,ac(maxY-1)]-catch(object)[,ac(maxY-1)]+computePrd(object,stock(object)[,ac(maxY-1)])
             
             #catch(object)=propagate(catch(object),dims(object)$iter)  
             #harvest      =window(harvest,start=dims(object)$year-1)
             #harvest[,ac(dims(object)$year-1)]=harvest(object)[,ac(dims(object)$year-1)]
             
             #object=fwd(object, harvest=harvest(object)[,ac(dimnames(object)$year-1)])
             
             object=window(object, end=max(as.numeric(yrs)))
             object=fwd(object,f=harvest,
                        sr=list(params=params(eql),
                                model =model(eql)),
                        sr.residuals=sr.residuals)
             
             return(catch(object)[,yrs])})

#' hcrParam
#' 
#' Combines reference points into the HCR breakpts
#'
#' @param ftar an object of class \code{FLPar}
#' @param btrig an object of class \code{FLPar}
#' @param fmin an object of class \code{FLPar}
#' @param blim an object of class \code{FLPar}
#' 
#' @seealso \code{\link{hcr}}
#' 
#' @export
#' @rdname hcrParam
#'
#' @examples
#' \dontrun{
#' tac('logistic',FLPar(msy=100,k=500))
#' }
hcrParam=function(ftar,btrig,fmin,blim){
  
  setNms=function(x,nm,nits){
    
    names(dimnames(x))[1]='params'
    dimnames(x)[[1]]     =nm
    if (nits!=dims(x)$iter)
      x=propagate(x,nits)
    
    return(x)}
  
  nits=max(laply(list(ftar,btrig,fmin,blim), function(x) dims(x)$iter))
  
  ftar =setNms(ftar, nm='ftar', nits)
  btrig=setNms(btrig,nm='btrig',nits)
  fmin =setNms(fmin, nm='fmin', nits)
  blim =setNms(blim, nm='blim', nits)
  
  if (nits==1) res=FLPar(  array(c(ftar,btrig,fmin,blim),c(4,nits),dimnames=list(params=c('ftar','btrig','fmin','blim'),iter=seq(nits)))) else
               res=FLPar(t(array(c(ftar,btrig,fmin,blim),c(nits,4),dimnames=list(iter=seq(nits),params=c('ftar','btrig','fmin','blim')))))
  
  #units(res)='harvest'
  return(res)}
  #return(as(res,'FLQuant'))}
  
#' hcr
#' 
#' Harvest Control Rule, calculates F, or Total Allowable Catch (TAC) based on a hockey stock harvest control rule.
#'
#' @param object an object of class \code{biodyn} or
#' @param ... other parameters, i.e.
#' params \code{FLPar} object with hockey stick HCR parameters, see hcrParam
#' yrs numeric vector with yrs for HCR prediction
#' refYrs numeric vector with years used to for stock/ssb in HCR
#' tac \code{logical} should return value be TAC rather than F?
#' bndF \code{vector} with bounds (i.e.min and max values) on iter-annual variability on  F
#' bndTac \code{vector} with bounds (i.e. min and max values) on iter-annual variability on TAC
#'  
#' @aliases hcr,biodyn-method
#' 
#' @return \code{FLPar} object with value(s) for F or TAC if tac==TRUE
#' 
#' @seealso \code{\link{bmsy}}, \code{\link{fmsy}}, \code{\link{fwd}} and \code{\link{hcrParam}}
#' 
#' @export
#' @rdname hcr
#'
#' @examples
#' \dontrun{
#' bd   =sim()
#' 
#' bd=window(bd,end=29)
#' for (i in seq(29,49,1))
#' bd=fwd(bd,harvest=hcr(bd,refYrs=i,yrs=i+1)$hvt)
#' }
setGeneric('hcr', function(object,refs,...) standardGeneric('hcr'))
setMethod('hcr', signature(object='FLStock',refs='FLPar'),
 function(object,refs, 
           params=hcrParam(ftar =0.70*refs[,'harvest'],
                           btrig=0.80*refs[,'ssb'],
                           fmin =0.01*refs[,'harvest'],
                           blim =0.40*refs[,'ssb']),
           refYrs=max(as.numeric(dimnames(catch(object))$year)),
           stkYrs=refYrs,
           hcrYrs=max(as.numeric(dimnames(ssb(  object))$year)),
           tac   =FALSE,
           tacMn =TRUE,
           bndF  =NULL, #c(1,Inf), #not needed as fmin and maxF sort this
           bndTac=NULL, #c(1,Inf), #absolute
           iaF   =TRUE,            #relative
           iaTac =TRUE,            #relative
           maxF  =2,
           ...) {
  ## HCR
  dimnames(params)$params=tolower(dimnames(params)$params)
  params=as(params,'FLQuant')  
  #if (blim>=btrig) stop('btrig must be greater than blim')
  a=(params['ftar']-params['fmin'])/(params['btrig']-params['blim'])
  b=params['ftar']-a*params['btrig']

  ## Calc F
  # bug
  #val=(SSB%*%a) %+% b
  bNow=FLCore::apply(ssb(object)[,ac(stkYrs)],6,mean)
  
  rtn=(bNow%*%a)  
  rtn=FLCore::sweep(rtn,2:6,b,'+')

  fmin=as(params['fmin'],'FLQuant')
  ftar=as(params['ftar'],'FLQuant')
  for (i in seq(dims(object)$iter)){
    FLCore::iter(rtn,i)[]=max(FLCore::iter(rtn,i),FLCore::iter(fmin,i))
    FLCore::iter(rtn,i)[]=min(FLCore::iter(rtn,i),FLCore::iter(ftar,i))} 
  
  rtn=window(rtn,end=max(hcrYrs))
  #dimnames(rtn)$year=min(hcrYrs)  
  if (length(hcrYrs)>1){
    rtn=window(rtn,end=max(hcrYrs))
    rtn[,ac(hcrYrs)]=rtn[,ac(min(hcrYrs))]}
  
  ### Bounds ##################################################################################
  ## F
  if (!is.null(bndF)){  

      ref=FLCore::apply(harvest(object)[,ac(refYrs-1)],6,mean)
    
      rtn[,ac(min(hcrYrs))]=qmax(rtn[,ac(min(hcrYrs))],ref*bndF[1])
      rtn[,ac(min(hcrYrs))]=qmin(rtn[,ac(min(hcrYrs))],ref*bndF[2])
    
      if (length(hcrYrs)>1)        
        for (i in hcrYrs[-1]){
          if (iaF){
            rtn[,ac(i)]=qmax(rtn[,ac(i)],rtn[,ac(i-1)]*bndF[1])
            rtn[,ac(i)]=qmin(rtn[,ac(i)],rtn[,ac(i-1)]*bndF[2])
          }else{
            rtn[,ac(i)]=rtn[,ac(i-1)]}
  
      if (!is.null(maxF)) rtn=qmin(rtn,maxF)}}
   hvt=rtn
  
   
   ## TAC
   if (tac){
     
      ref=FLCore::apply(catch(object)[,ac(refYrs)],6,mean)

      object=window(object, end=max(as.numeric(hcrYrs)))
      object=fwd(object,harvest=harvest(object)[,ac(min(as.numeric(hcrYrs)-1))])
     
      rtn   =catch(fwd(object, harvest=rtn))[,ac(hcrYrs)]

      if (!is.null(bndTac)){  
        rtn[,ac(min(hcrYrs))]=qmax(rtn[,ac(min(hcrYrs))],ref*bndTac[1])
        rtn[,ac(min(hcrYrs))]=qmin(rtn[,ac(min(hcrYrs))],ref*bndTac[2])

        if (length(hcrYrs)>1)        
          for (i in hcrYrs[-1]){
            if (iaTac){
              rtn[,ac(i)]=qmax(rtn[,ac(i)],rtn[,ac(i-1)]*bndTac[1])
              rtn[,ac(i)]=qmin(rtn[,ac(i)],rtn[,ac(i-1)]*bndTac[2])
            }else{
              rtn[,ac(i)]=rtn[,ac(i-1)]}}
      
      if (tacMn) rtn[]=c(apply(rtn,3:6,mean))}}
  
      if (tac) rtn=list(hvt=hvt,tac=rtn,stock=stk) else rtn=list(hvt=hvt,ssb=bNow)
  
  return(rtn)})

#' hcrPlot
#'
#' Calculates break pointts for a hockey stick HCR
#'
#' @param object an object of class \code{biodyn} or
#' @param params \code{FLPar} object with hockey stock HCR parameters
#' @param maxB  =1
#' @param rel   =TRUE
#' 
#' @return a \code{FLPar} object with value(s) for HCR
#' 
#' @seealso \code{\link{hcr}},  \code{\link{msy}},  \code{\link{bmsy}}, \code{\link{fmsy}} 
#' 
#' @rdname hcrPlot
#' @aliases hcrPlot-method  hcrPlot,biodyn-method
#'
#' @examples
#' \dontrun{
#' simBiodyn()
#' }
#' 
setGeneric('hcrPlot', function(object,...) standardGeneric('hcrPlot'))
setMethod('hcrPlot', signature(object='FLBRP'),
 function(object,params=FLPar(ftar=0.7, btrig=0.7, fmin=0.01, blim=0.20),maxB=1,rel=TRUE){
  
  pts=rbind(cbind(refpt='Target',model.frame(rbind(bmsy(object)*c(params['btrig']),
                                                   fmsy(object)*c(params['ftar'])))),
            cbind(refpt='Limit', model.frame(rbind(bmsy(object)*c(params['blim']),
                                                   fmsy(object)*c(params['fmin'])))))
  pts.=pts
  pts.[1,'bmsy']=params(object)['k']*maxB
  pts.[2,'bmsy']=0
  pts.[,1]=c('')
  
  pts=rbind(pts.[1,],pts[1:2,],pts.[2,])
  
  names(pts)[2:3]=c('stock','harvest')
  
  if (rel){
    pts[,'stock']=pts[,'stock']/bmsy(object)
    pts[,'harvest']=pts[,'harvest']/fmsy(object)}
  
  pts})

