# Load the data
geno_import <- read.csv("./genotype_data.csv", 
                        header = T, 
                        stringsAsFactors = F,
                        row.names = 1)

for(i in 1:ncol(geno_import)) {
  geno_import[, i] <- as.character(geno_import[, i])
  geno_import[geno_import[, i] == "TRUE", i] = "T" 
}
head(geno_import[, 253:254])


# Grab the genotypes at our first two nucleotide positions
geno_in <- geno_import[, 1:2]
head(geno_in)


# The frequency of each allele at the first two nucleotide positions
geno_count <- table(c(geno_in[, 1], geno_in[, 2]))
geno_count


# Find the least frequent allele (minor allele)
minor_allele <- names(geno_count[geno_count == min(geno_count)])
minor_allele


# Count the nucleotide positions showing the minor allele across samples = minor allele frequency
xa_result <- (geno_in[,1] == minor_allele) + (geno_in[,2] == minor_allele)
xa_result


# Construct a function that calculates the frequency of minor alleles across samples at the two nucleotide positions
xa_converter <- function(geno_in){ 
  # Estimate the frequency of each allele of a genotype spanning the two nucleotide positions
  geno_count <- table(c(geno_in[, 1],geno_in[, 2]))
  
  # Find the name of the least frequent allele (minor allele)
  minor_allele <- names(geno_count[geno_count == min(geno_count)])[1]
  
  # Estimate the frequency of the minor allele of a genotype spanning the two nucleotide positions per sample
  xa_result <- (geno_in[, 1] == minor_allele) + (geno_in[, 2] == minor_allele) # Return an integer vector taking the value 0, 1, or 2 of the sample size length 
  return(xa_result)
}


# Apply the function `xa_converter()` to each genotype
xa_matrix <- matrix(NA, nrow = nrow(geno_import), ncol = ncol(geno_import)/2)
  # What are the rows and columns? row: sample; column: nucleotide position
  # Why divide by 2? a genotype spanning two nucleotide positions: A1A2

for (i in 1:(ncol(geno_import)/2)){
    xa_matrix[, i] <- xa_converter(geno_import[, c(2*i - 1, 2*i)]) # Grab pairs of columns; (1,2), (3,4)...(399,400); Each column of xa_matrix is an integer vector taking the value 0, 1, or 2 of the sample size length 
}
xa_matrix <- xa_matrix - 1 # Center on 0
xa_matrix[1:10, 1:10]


# Write an expanded function that handle diverse situations in the class and dim of the imported data, the frequencies of minor and major alleles, the threshold of the minor allele frequency, and dummary variables in the additive genetic model
xa_converter <- function(geno_in, maf_limit = 0.01, return_minor_allele = F){
  # Combine a pair of two nucleotide positions to each genotype which is a vector of double letter elements: AA, AG, GG, ...
  if(class(geno_in) == "matrix" | class(geno_in) == "data.frame"){
    if(ncol(geno_in) > 1){
      geno <- paste0(geno_in[, 1], geno_in[, 2])
    } else {
      geno <- as.vector(geno_in)
    }
  } else {
    geno <- geno_in
  }
  
  return_coding <- rep(NA, length(geno))
  
  # Determine the minor and major alleles
  geno_undone <- unlist(strsplit(paste0(geno_in[, 1], geno_in[, 2]), ''))
  geno_count <- table(geno_undone)
  maf <- min(geno_count)[1]/length(geno) # maf: minor allele frequency
  if(length(geno_count) == 1 | maf < maf_limit){
   return(return_coding) 
  } else if(geno_count[1] == geno_count[2]){
    minor_allele <- sample(names(geno_count), 1)
    major_allele <- names(geno_count)[names(geno_count) != minor_allele]
  } else {
    minor_allele <- names(geno_count[geno_count == min(geno_count)])
    major_allele <- names(geno_count[geno_count == max(geno_count)])
  }

  # Categorize genotypes to the "dummy variables" centered on 0 (for additive genetic model)
  # The additive genetic model assumes that the effects of two alleles at a given locus (location on a chromosome) are additive, meaning that the more copies of the "good" allele a person has, the better their trait value will be.
  return_coding[geno == paste0(minor_allele, minor_allele)] <- 1
  return_coding[geno == paste0(minor_allele, major_allele) | geno == paste0(major_allele, minor_allele) ] <- 0
  return_coding[geno == paste0(major_allele, major_allele)] <- -1
  
  if(return_minor_allele){
    return(list(return_coding, minor_allele))
  } else {
    return(return_coding)
  }
}

xa_matrix <- matrix(NA, nrow = nrow(geno_import), ncol = ncol(geno_import)/2)

for (i in 1:(ncol(geno_import)/2)){
    xa_matrix[, i] <- xa_converter(geno_import[,c(2*i - 1, 2*i)]) # Grab pairs of columns; (1,2), (3,4)...(399,400); Each column of xa_matrix is the returned vector `return_coding`, which is an integer vector taking the value 1, 0, or -1 of the sample size length   
}

xa_matrix[1:10, 1:10]


# If we have sites with NA's
turn_xa <- t(xa_matrix)
turn_xa <- turn_xa[complete.cases(turn_xa),]
xa_matrix <- t(turn_xa)


# Write a function for the dominance model (Xd coding) 
## Method 1:
xa_matrix <- matrix(NA, nrow = nrow(geno_import), ncol = ncol(geno_import)/2)

for (i in 1:(ncol(geno_import)/2)){
  xa_matrix[, i] <- xa_converter(geno_import[, c(2*i - 1, 2*i)]) # Grab pairs of columns; (1,2), (3,4)...(399,400); Each column of xa_matrix is an integer vector taking the value 0, 1, or 2 of the sample size length 
}

xa_matrix <- xa_matrix - 1 
xa_matrix[1:10, 1:10]

xd_converter_from_xa = function(xa_matrix) {
  num_pop = nrow(xa_matrix)
  num_genes = ncol(xa_matrix)
  xd = matrix(nrow = nrow(xa_matrix), ncol = ncol(xa_matrix))
  for (j in 1:num_pop) {
    xd[j, ] = ifelse(abs(xa_matrix[j, ]), -1, 1) 
    # Individual's genotype is homozygous (abs(xa_matrix[j, ]) == 1) or heterozygous (abs(xa_matrix[j, ]) == 0) 
  }
  return(xd)
}

xd_matrix_from_xa = xd_converter_from_xa(xa_matrix)


## Method 2:
xd_converter <- function(geno_in) {
  xd_result <- ifelse(geno_in[, 1] == geno_in[, 2], -1, 1)
  return(xd_result)
}

xd_matrix <- matrix(NA, nrow = nrow(geno_import), ncol = ncol(geno_import) / 2)

count = 1
for (i in seq(2, ncol(geno_import), by = 2)) {
  xd_matrix[, count] <- xd_converter(geno_in = geno_import[, c(i - 1, i)]) # Code dummy variables for Xd
  count = count + 1
}


## Improve the method 2: filter out any genotypes where the minor allele frequency is less than 0.1
filter_alleles = function(geno_dat, threshold = .1) {
  to_drop = c()
  for (i in 1:(ncol(geno_dat) / 2)) {
    geno_count <- table(c(geno_dat[, 2*i - 1], geno_dat[, 2*i]))
    minor_allele <- names(geno_count[geno_count == min(geno_count)])[1] 
    # Grab first element in case we end up with a tie
    minor_allele_freq = geno_count[minor_allele] / (2*nrow(geno_dat))
    cat("i ", i,
        "minor allele" , minor_allele,
        "freq", minor_allele_freq,
        "\n")
    if (minor_allele_freq < threshold) {
      to_drop = append(to_drop, 2*i - 1)
      to_drop = append(to_drop, 2*i)
      # e.g., (1,2), (3,4)...(399,400)
    }
    
  }
  return(geno_dat[, -to_drop]) # Drop a pair of columns mapping to a genotype
}

filtered_geno_dat = filter_alleles(geno_dat = geno_import, threshold = .1)
xd_matrix_filtered = matrix(NA, nrow = nrow(filtered_geno_dat), ncol = ncol(filtered_geno_dat) / 2)

count = 1
for (i in seq(2, ncol(filtered_geno_dat), by = 2)) {
  xd_matrix_filtered[, count] <- xd_converter(filtered_geno_dat[, c(i - 1, i)])
  count = count + 1
}


# Create a plot for the sample #10 (xd_filtered[10,]): x axis is the (relative) position along the genome; y axis is the value for X_d 
library(ggplot2)
ggplot(data.frame(y = xd_matrix_filtered[10, ], x = seq(1, ncol(xd_matrix_filtered)))) + 
  geom_point(aes(x, y)) + 
  labs(x = "genome position", 
       y = "Xd", 
       title = paste(
         "Patient 10 \n ",
         ncol(xd_matrix_filtered),
         "genes remaining post filtering by 0.1 maf"
  )
)

