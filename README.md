---
title: "TSIS: an R package to infer time-series isoform switch of alternative splicing"
subtitle: User manual
author: "Wenbin Guo"
date: "`r Sys.Date()`"
output:
  html_document:
    code_folding: show
    fig_caption: yes
    highlight: textmate
    theme: cerulean
    toc: yes
    toc_depth: 4
---


##Installation and loading

###Install dependency packages

```{r,eval=F}
install.packages(c("shiny", "shinythemes","ggplot2", "zoo","gtools"), dependencies=TRUE)

```

###Install TSIS package
Install [TSIS](https://github.com/wyguo/TSIS) package from github using [devtools](https://cran.r-project.org/web/packages/devtools/index.html) package.
```{r,eval=F}
##if devtools is not installed, typing
#install.packages('devtools')

library(devtools)
devtools::install_github("wyguo/TSIS")
```

###Loading

Once installed, TSIS package can be loaded as normal
```{r,eval=T}
library(TSIS)
```

##TSIS workflow

###Prepare the input data
Three types of dataset are required for TSIS analysis.

- Dataset 1: Time-series isoform expression data with $T$ time points and $R$ replicates, with rownames of isoforms and colnames of samples. The expression can be in the format of read counts, TPM (transcript per million), isoform expression ratio to genes, etc.

- Dataset 2: Gene and isoform mapping table corresponding to Dataset 1, with first column of gene names and second column of isoform names.

- Dataset 3: Names of subset of isoforms. Users can output subset of the results by providing a list of isoforms.


The [TSIS](https://github.com/wyguo/TSIS) package provides example datasets of "AtRTD2" of 300 genes and 766 isoforms, with 26 time points, 3 biological replicates and 3 technique replicates. The experiments were designed to investigate the cold response of genome in Arabidopsis. The isoform expression is in TPM format. 
For the experiments and data quantification details, plase see the AtRTD2 paper [(Zhang, et al.,2016)](http://biorxiv.org/content/early/2016/05/06/051938). 

```{r,echo=T}
##26 time points, 3 biological replicates and 3 technical replicates, in total 234 sample points. 
AtRTD2$data.exp[1:10,1:3]
AtRTD2$mapping[1:10,]
colnames(AtRTD2$data.exp)[1:10]
```

The data loaded to this 
Shiny App must be in *.csv format for loading convenience. Users can downlad the [example datasets](https://github.com/wyguo/TSIS/examples) from https://github.com/wyguo/examples or by typing the following codes:

```{r,echo=T,eval=F}
AtRTD2.example(dir='data')
```
where "dir" is the folder to save the data in the working directory. If it does not exists, a new folder will be created with the name. 


###Score the isoform switch

####Step 1: search the intersections {#step1}

The expression for a pair of isoforms $iso_1$ and $iso_2$ may experience a number isoform switch in the whole time duration. Two methods have been included to search for these switch points where the isoforms reverse relative expression profiles. 

- Method 1: use average expression values across time points. Taking average values of the replicates for time points in the input isoform expression data.

```{r}
##use function TSIS::rowmean to take average values
data.exp.mean<-rowmean(t(AtRTD2$data.exp),group = paste0('T',rep(1:26,each=9)))
data.exp.mean<-t(data.exp.mean)
data.exp.mean[1:10,1:4]

##example, to find the intersection points of iso1 and iso2
iso1='AT1G13350_ID2'
iso2='AT1G13350_P1'

##x1 and x2 are the numeric values for two isoforms to search for the intersection points
##x.points and y.points are the x axis and y axis coordinate values for the time course intersection points. 
ts.intersection(x1=as.numeric(data.exp.mean[iso1,]),x2=as.numeric(data.exp.mean[iso2,]))

```

- Method 2: use nature spline curves to fit the time-series data and find intersection points of the fitted curves for each pair of isoforms. See details in \code{\link{ts.spline}} and \code{\link{ns}} in code{\link{splines}} package.

```{r,echo=T}
##use function TSIS::ts.spline to fit the samples with smooth curve.
##estimate the values at time points 1-26 on the fitted curves
data.exp.splined<-apply(AtRTD2$data.exp[1:10,],1,
                        function(x) ts.spline(x,t.start = 1,t.end = 26,nrep = 9,df = 18))
data.exp.splined<-t(data.exp.splined)
data.exp.splined[,1:4]

##x1 and x2 are the numeric values for two isoforms to search for the intersection points
##x.points and y.points are the x axis and y axis coordinate values for the time course intersection points. 
ts.intersection(x1=as.numeric(data.exp.splined[iso1,]),x2=as.numeric(data.exp.splined[iso2,]))
```

####Step 2: score the isoform switches

We defined 5 parameters to score the quality of isoform switch. The first two are the frequency of switch and the sum of average distance before and after switch, used as Score 1 and Score 2 in [iso-kTSP](https://bitbucket.org/regulatorygenomicsupf/iso-ktsp) (see [Figure 1(A)](#Figure1)
method for two condition comparisons [(Sebestyen, et al., 2015)](http://biorxiv.org/content/early/2014/07/04/006908). To investigate the switches of two isoforms $iso_i$ and $iso_j$ in two conditions $c_1$ and $c_2$, Score 1 is defined as
\[S_1(iso_i,iso_j|c_1,c_2)=|p(iso_1>iso2|c_1)+p(iso_1<iso_2|c_2)-1|,\]
where $p(iso_1>iso2|c_1)$ and $p(iso_1<iso_2|c_2)$ are the frequencies/probabilities that the samples of one isoform is greater or less than the other in corresponding conditions. Score 2 is defined as
\[S_2(iso_i,iso_j|c_1,c_2)=|mean.dist(iso_i,iso_2|c_1)|+|mean.dist(ios_1,iso_2|c_2)|,\]
where $mean.dist(iso_i,iso_2|c_1)$ and $mean.dist(ios_1,iso_2|c_2)$ are the mean distances of samples in conditions $c_1$ and $c_2$, respectively.

However, the time-series for a pair of isoforms may undergo a number of switch points in the time duration. To extend the iso-kTSP to TSIS, the time duration is divided in to intervals with the intersection points determined in [Step 1](#step1). For example, in [Figure 1(B)](#Figure1), the duration of four time points is divided into interval 1 to 3 with the intersection points of switch1 and switch2. For each pair of consecutive intervals before and after switch, they can be assimlated as two conditions to implement the calculation of Score 1 and Scoe 2.

The time-series isoform switches are more complex than the comparisons over two conditions. In addition to Score 1 and Score 2 for each switch point, we defined other 3 parameters as metrics of switch qualities. 

- p-value of paired t-test for the two isoform sample differences within each interval. For example, the p-value for interval2 is
```{r}
t.test(c(1,1,2,2,3,4),c(3,4,5,5,6,6),paired = T)$p.value
```

- Time points number within each interval. For example, there are 1 time point in interval 1 and 3, and 2 time points in interval 2. 

- Pearson correlation of two isoforms. For example, the correlation of $iso_i$ and $iso_j$ is 
```{r}
cor(c(1,2,3,3,5,6,4,5,6,1,2,3),c(4,5,6,1,2,4,1,2,3,4,5,6),method = 'pearson')
```

![](https://github.com/wyguo/TSIS/blob/master/vignettes/Figure1small.png)

**Figure 1: Isoform switch methods.** Expression data with 3 replicates for each condition/time point is simulated for isoforms $iso_1$ and $iso_2$. (A) is the iso-kTSP algorithm for comparisons of two conditions $c_1$ and $c_2$. The iso-kTSP is extended to time-series isoform switch (TSIS) in figure (B). The time-series with 4 time points is divided into 3 intervals with breaks of isoform switch poitns, which are the intersections of average exprssion of 3 replicates. The intervals are assimlated as the conditions in iso-kTPS. Thereby, the scores for each switch point can been determined based on the intervals before and after switch occurring. Additionally, 3 parameters in interval basis are defined to further filtrate switch results, the p-value of paird t-test for sample differences, the time points number in each interval and the Pearson correlation of two isoforms.

### Filtrate results 
A prospective isoform switch should be:

- Have high Score 1 of swtich frequency/probability.

- With proper value of Score 2 the sum of average distances.

- The samples in the intervals before and after switch are statistically different.

- The switch event lasting a few time points in both intervals before and after switch, i.e. the intervals should contain a number of time points. 

- For further details, users can investigate the co-expressed isoform pairs with high Pearson correlation. Note: the isoform pairs with high negative correlation may show better switch pattern if look at the time-series plots. 

### Subset of results
Users may need to investigate subset of isoforms for specific purpose. Three options have been build-in the TSIS package.

- Users can set the lower and upper boundaries of a region in the time duration to study the switches only within this region.

- Users can provide a name list of isoforms to only show the results cantain the isoforms in the list.

- Users can output subset of results with high ratios (the proportions of isoforms to the genes) isoforms.

### Scripts for scoring
All the steps of searching intersection points, scoring and filtering are intergrated in two functions TSIS::iso.switch and TSIS::score.filer. We use the datasets TSIS::AtRTD2 in the package as an example to do the analysis. Please go the documentation for function details. 

```{r}
##load the data
data.exp<-AtRTD2$data.exp
mapping<-AtRTD2$mapping
dim(data.exp)
dim(mapping)

```

####Scoring

Parameters for TSIS::iso.switch function:

- **data.exp, mapping**, input expression data frame and gene-isoform mapping data frame.

- **t.start, t.end, nrep**, start time point, end time point and number of replicates. The time step is assumed to be 1.

- **min.t.points**, pre-filtering, if the time points in all intervals < min.t.points, skip this pair of isoforms.

- **min.distance**, pre-filtering, if the sample distances in the time courses (mean expression or splined value) for intersection search all < min.distance, skip this pair of isoforms.

- **rank**, logical, to use rank of isoform expression for each sample (TRUE) or not (FALSE).

- **spline**, logical, to use spline method (TRUE) or mean expression (FALSE).

- **spline.df**, the degree of freedom used in spline method. See splines::ns for details. 

- **verbose**, logical, to track the progressing of runing (TRUE) or not (FALSE).

**Example 1: search intersection points with mean expression **

```{r}
##Scores
scores.mean2int<-iso.switch(data.exp=data.exp,mapping =mapping,
                     t.start=1,t.end=26,nrep=9,rank=F,
                     min.t.points =2,min.distance=1,spline =F,spline.df = 9,verbose = F)
```

**Example 2: search intersection points with spline method**
```{r}
##Scores
scores.spline2int<-suppressMessages(iso.switch(data.exp=data.exp,mapping =mapping,
                     t.start=1,t.end=26,nrep=9,rank=F,
                     min.t.points =2,min.distance=1,spline =T,spline.df = 9,verbose = F))
```

####Filtering

Parameters for TSIS::score.filter function:

- **scores**, the scores output from TSIS::iso.switch

- **prob.cutoff, dist.cutoff, t.points.cutoff, pval.cutoff, cor.cutoff**, the cut-offs corresponding to switch frequencies/probablities, sum of average distances, p-value and time points cut-offs for both intervals before and after switch and Pearson correlation.

- **data.exp, mapping**, the expression and gene-isoform mapping data.

- **sub.isoform.list**, a vector of isoform names to output subset of the corresponding results.

- **sub.isoform**, logical, to output subset of the results(TRUE) or not (FALSE). If TRUE, sub.isoform.list must be provided.

- **max.ratio**, logical, to show the subset of results with the isoforms of maximum ratios to the genes. If TRUE, data.exp and mapping data must be provided to calculate the isoform ratios to the genes. 

- **x.value.limit**, the region of x axis (time) for investigation. If there is no intersection point in this region, the isoform pair is filtered.



**Example 1, general filtering**

```{r}
##intersection from mean expression
scores.mean2int.filtered<-score.filter(scores = scores.mean2int,prob.cutoff = 0.5,dist.cutoff = 1,
                                       t.points.cutoff = 2,pval.cutoff = 0.01, cor.cutoff = 0.5,
                                       data.exp = NULL,mapping = NULL,sub.isoform.list = NULL,
                                       sub.isoform = F,max.ratio = F,x.value.limit = c(9,17) )

scores.mean2int.filtered[1:5,]

##intersection from spline method
scores.spline2int.filtered<-score.filter(scores = scores.spline2int,prob.cutoff = 0.5,
                                         dist.cutoff = 1,t.points.cutoff = 2,pval.cutoff = 0.01,
                                         cor.cutoff = 0.5,data.exp = NULL,mapping = NULL,
                                         sub.isoform.list = NULL,sub.isoform = F,max.ratio = F,
                                         x.value.limit = c(9,17) )
  
```

**Example 2, only show subset of results according to a isoform list**

```{r}
##intersection from mean expression
sub.isoform.list<-AtRTD2$sub.isoforms
sub.isoform.list[1:10]
scores.mean2int.filtered.subset<-score.filter(scores = scores.mean2int,prob.cutoff = 0.5,dist.cutoff = 1,
                                       t.points.cutoff = 2,pval.cutoff = 0.01, cor.cutoff = 0.5,
                                       data.exp = NULL,mapping = NULL,sub.isoform.list = sub.isoform.list,
                                       sub.isoform = T,max.ratio = F,x.value.limit = c(9,17) )

scores.mean2int.filtered.subset[1:5,]

```

####Visualization

Parameters for TSIS::plotTSIS function:

- **data.exp**, the isoform expression data

- **scores**, the scores output from TSIS::iso.switch or from TSIS::score.filter

- **iso1,iso2**, the names of a pair of isoforms. If not provided, the data.exp must be a two row data frame and the row names of data.exp will be used as iso1 and iso2.

- **gene.name**, the gene name show in the plot title. If not provided, the titile name is shown as iso1_vs_iso2

- **y.lab**, the y label of the plot

- **make.plotly**, logical, use plotly::ggplotly (TRUE) to have dynamic plot or ggplot2 to have static plot (FALSE). See the [plotly](https://plot.ly/r/) for details. 

- **t.start, t.end, nrep**, start time point, end time point and number of replicates. The time step is assumed to be 1.

- **x.lower.boundary, x.upper.boundary**, the lower and upper boundaries of the time region for investigation

- **show.region**, logical, to show the region (TRUE) for investigation or not (FALSE).

- **show.scores**, logical, to show the score labels on the plot (TRUE) or not (FALSE).

- **line.width, point.size**, the line width and point size for plots

- **error.type, show.errorbar, errorbar.size, errorbar.width**, parameters for error bars. The error.type options are "stderr" for standard error and "sd" for standard deviation.

- **spline, spline.df**, parameters for spline method, corresponding to the settings in TSIS::iso.switch

- **ribbon.plot**, logical, to show ribbon plot (TRUE) or error bar plot (FALSE). See ribbon plot details in [ggplot2::geom_smooth](http://docs.ggplot2.org/current/geom_smooth.html).


#####Error bar plot
```{r,eval=F,fig.width=8.5,fig.height=4}
plotTSIS(data2plot = data.exp,scores = scores.mean2int.filtered,iso1 = 'AT3G61600_P1',
        iso2 = 'AT3G61600_P2',gene.name = NULL,y.lab = 'Expression',make.plotly = F,
        t.start = 1,t.end = 26,nrep = 9,prob.cutoff = 0.5,x.lower.boundary = 9,
        x.upper.boundary = 17,show.region = T,show.scores = T,
        line.width =0.5,point.size = 3,error.type = 'stderr',show.errorbar = T,errorbar.size = 0.5,
        errorbar.width = 0.2,spline = F,spline.df = NULL,ribbon.plot = F )

```
![](https://github.com/wyguo/TSIS/blob/master/vignettes/error_bar.png)

#####Ribbon plot
```{r,eval=F,fig.width=8.5,fig.height=4}
plotTSIS(data2plot = data.exp,scores = scores.mean2int.filtered,iso1 = 'AT3G61600_P1',
        iso2 = 'AT3G61600_P2',gene.name = NULL,y.lab = 'Expression',make.plotly = F,
        t.start = 1,t.end = 26,nrep = 9,prob.cutoff = 0.5,x.lower.boundary = 9,
        x.upper.boundary = 17,show.region = T,show.scores = T,error.type = 'stderr',
        line.width =0.5,point.size = 3,show.errorbar = T,errorbar.size = 0.5,
        errorbar.width = 0.2,spline = F,spline.df = NULL,ribbon.plot = T )

```
![](https://github.com/wyguo/TSIS/blob/master/vignettes/ribbon.png)

##Shiny app- as easy as mouse click
All the functions of scoring, filtering, visulisation and saving results have been integrated into a [Shiny app](https://shiny.rstudio.com/). Users can implement the analysis as easy as mouse click. To start the app, simply typing the following code in the R console:

```{r,eval=F}
TSIS.app()
```


##References
Chang, W., et al. 2016. shiny: Web Application Framework for R. https://CRAN.R-project.org/package=shiny

Sebestyen, E., Zawisza, M. and Eyras, E. Detection of recurrent alternative splicing switches in tumor samples reveals novel signatures of cancer. Nucleic Acids Res 2015;43(3):1345-1356.

Zhang, R., et al. AtRTD2: A Reference Transcript Dataset for accurate quantification of alternative splicing and expression changes in Arabidopsis thaliana RNA-seq data. bioRxiv 2016.


##Session Info

```{r,eval=F}
## R version 3.2.5 (2016-04-14)
## Platform: i386-w64-mingw32/i386 (32-bit)
## Running under: Windows 7 (build 7601) Service Pack 1
## 
## attached base packages:
## [1] stats     graphics  grDevices utils     datasets  methods   base     
## 
## other attached packages:
## [1] TSIS_0.1.0
## 
## loaded via a namespace (and not attached):
##  [1] Rcpp_0.12.5     lattice_0.20-33 png_0.1-7       gtools_3.5.0   
##  [5] zoo_1.7-13      digest_0.6.10   rprojroot_1.1   grid_3.2.5     
##  [9] backports_1.0.4 magrittr_1.5    evaluate_0.10   stringi_1.1.1  
## [13] rmarkdown_1.2   splines_3.2.5   tools_3.2.5     stringr_1.0.0  
## [17] yaml_2.1.13     htmltools_0.3.5 knitr_1.15.1
```