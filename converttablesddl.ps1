param(
 
  	[string]
	$infilepath ,
  
  	[string]
	$outfilepath 
  
)
cd "C:\Program Files (x86)\Azure Synapse Pathway"
./aspcmd -i $infilepath -o $outfilepath
