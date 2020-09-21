#!/bin/bash

# CoMA Pipeline
# Copyright (C) 2020 Sebastian Hupfauf, Mohammad Etemadi

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# contact
# ------
# coma-mikrobiologie@uibk.ac.at

echo -e "\n********************************************************************************"
echo "      Welcome to CoMA, the pipeline for amplicon sequencing data analysis!           "
echo -e "********************************************************************************\n"
echo -e "User: "$name
echo -e "Project: "$path"\n"
echo -e "________________________________________________________________________________\n"

proc=$(head -n 1 /home/coma/$name/$path/Data/proc.txt 2>> $wd/$name/$path/${date}_detailed.log) || proc=$(cat /proc/cpuinfo | grep processor | wc -l)

#Sample description

(zenity --no-wrap --question --title $path --text "Do you want to assign your files and choose the number of CPUs?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Data

proc=$(zenity --text "How many CPUs du you want to use?" --title $path --scale --value=1 --min-value=1 --max-value=$proc --step=1 2>> $wd/$name/$path/${date}_detailed.log)

echo $proc > proc.txt

(zenity --no-wrap --question --title $path --text "Are you using paired-end reads (a forward and reverse file per sample)?
Click 'No' if you have single-end reads (only a single file per sample)." &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

sequence=$(zenity --forms --title=$path --text='Please describe your samples' --add-entry="What is the common file name ending of your forward files? 
e.g. _R1_001.fastq.gz or _FW_001.fastq.gz:" --add-entry="What is the common file name ending ending of your reverse files? 
e.g. _R2_001.fastq.gz or _REV_001.fastq.gz:" 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

f=$(awk -F '[|]' '{print $1}' <<<$sequence)
r=$(awk -F '[|]' '{print $2}' <<<$sequence)
echo $f > pattern.txt
echo $r >> pattern.txt

cp /usr/local/Pipeline/filelist.py ./
python3 filelist.py $f name.txt $proc 2>> $wd/$name/$path/${date}_detailed.log
rm filelist.py

echo -e "\nUsed CPUs: " $proc

echo -e "\nCommon part of forward sequences: " $f
echo "Common part of reverse sequences: " $r

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nDONE! Name files are assigned. (Duration: "$dur"s)"
echo -e "\n________________________________________________________________________________\n"

fi

else

pat=$(zenity --forms --title=$path --text='Please describe your samples' --add-entry="What is the common file name ending of your files? 
e.g. _001.fastq.gz or .fastq.gz:" 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo $pat > pattern.txt

cp /usr/local/Pipeline/filelist.py ./
python3 filelist.py $pat name.txt $proc 2>> $wd/$name/$path/${date}_detailed.log
rm filelist.py

cd
cd $name
cd $path
cd Data

mkdir -p processed_reads

for file in $(<name.txt)
do
cp ${file}$pat processed_reads/ 2>> $wd/$name/$path/${date}_detailed.log
mv processed_reads/${file}$pat processed_reads/${file}.fastq.gz 2>> $wd/$name/$path/${date}_detailed.log
gunzip --force processed_reads/${file}.fastq.gz 2>> $wd/$name/$path/${date}_detailed.log
done

echo -e "\nUsed CPUs: " $proc

echo -e "\nCommon part of all sequences: " $pat

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nDONE! Name files are assigned. (Duration: "$dur"s)"
echo -e "\n________________________________________________________________________________\n"

fi
fi
fi

#Merging

if [[ $(wc -l </home/coma/$name/$path/Data/pattern.txt) = 2 ]]
then

(zenity --no-wrap --question --title $path --text "Do you want to merge your files?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

start=$(date +%s)
echo -e "\nMerging process proceeding ..."

cd
cd $name
cd $path
cd Data

mkdir -p processed_reads

f=$(head -n 1 pattern.txt)
r=$(tail -n 1 pattern.txt)

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
pandaseq -f ${file}$f -r ${file}$r -F -w processed_reads/${file}.fastq -g processed_reads/${file}.log &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nMerging completed! (Duration: "$dur"s)"
echo -e "\n________________________________________________________________________________\n"

fi
fi

#Quality Check of input files


(zenity --no-wrap --question --title $path --text "Do you want to check the quality of the input files?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

start=$(date +%s)

cd
cd $name
cd $path
cd Data

mkdir -p quality_reports
cd quality_reports
mkdir -p quality_before_filtering
cd ..

echo -e "\nQuality check of input files proceeding ..."

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-lite -fastq processed_reads/${file}.fastq -graph_data quality_reports/quality_before_filtering/${file}.gd -out_good null -out_bad null &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-graphs-noPCA -i quality_reports/quality_before_filtering/${file}.gd -html_all -o quality_reports/quality_before_filtering/${file} &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

end=$(date +%s)
dur=$(($end-$start))

echo -e '\nQuality report created! (Duration: '$dur's) 
Open the .html files to view the detailed quality report in your browser.'
echo -e "\n________________________________________________________________________________\n"

fi

#Trimming

(zenity --no-wrap --question --title $path --text "Do you want to trim your files (e.g. barcode, primers etc.) and/or apply quality filtering?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then
           
cd
cd $name
cd $path
cd Data

out=$(zenity --forms --title=$path --text="Please provide the parameters for the trimming/quality filtering process:" --add-entry="Trim from forward side (5' end):" --add-entry="Trim from reverse side (3' end):" --add-entry="Maximum fragment length:" --add-entry="Minimum fragment length:" --add-entry="Minimum average PHRED quality score:" --add-entry="Maximum number of ambiguous bases:" 2>> $wd/$name/$path/${date}_detailed.log)
if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nTrimming process proceeding ..."
echo

tl=$(awk -F '[|]' '{print $1}' <<<$out)
tr=$(awk -F '[|]' '{print $2}' <<<$out)
maxl=$(awk -F '[|]' '{print $3}' <<<$out)
minl=$(awk -F '[|]' '{print $4}' <<<$out)
mq=$(awk -F '[|]' '{print $5}' <<<$out)
amb=$(awk -F '[|]' '{print $6}' <<<$out)

mkdir -p filtered_reads
cd filtered_reads
mkdir -p good_sequences
mkdir -p discarded_sequences
cd ..

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-lite -fastq processed_reads/${file}.fastq -out_good filtered_reads/good_sequences/${file} -out_bad filtered_reads/discarded_sequences/${file} -trim_left $tl -trim_right $tr -max_len $maxl -min_len $minl  -min_qual_mean $mq -ns_max_n $amb -out_format 5 -log &>> $wd/$name/$path/${date}_detailed.log &
#echo "
#File: "$file &>> $wd/$name/$path/${date}_detailed.log
#echo "____________________________________________________________________________________
#" &>> $wd/$name/$path/${date}_detailed.log
done
done
wait

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nDone! (Duration: "$dur"s) Your files were trimmed/quality filtered using the following settings:"
echo
echo "Trim from forward side (5' end): " $tl
echo "Trim from reverse side (3' end): " $tr
echo "Maximum fragment length: " $maxl
echo "Minimum fragment length: " $minl
echo "Minimum average PHRED quality score: " $mq
echo "Maximum number of ambiguous bases: " $amb
echo -e "\n________________________________________________________________________________\n"

fi
fi

#Quality good seq

(zenity --no-wrap --question --title $path --text "Do you want to check the quality of your trimmed/quality filtered files?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

start=$(date +%s)
             
cd
cd $name
cd $path
cd Data
mkdir -p quality_reports
cd quality_reports
mkdir -p good_sequences
cd ..

echo -e "\nQuality control of trimmed reads proceeding ..."

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-lite -fastq filtered_reads/good_sequences/${file}.fastq -graph_data quality_reports/good_sequences/${file}.gd -out_good null -out_bad null &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-graphs-noPCA -i quality_reports/good_sequences/${file}.gd -html_all -o quality_reports/good_sequences/${file} &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

#Quality bad seq

cd
cd $name
cd $path
cd Data
mkdir -p quality_reports
cd quality_reports
mkdir -p discarded_sequences
cd ..

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-lite -fastq filtered_reads/discarded_sequences/${file}.fastq -graph_data quality_reports/discarded_sequences/${file}.gd -out_good null -out_bad null &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

for thread in $(<threads.txt)
do
for file in $(<${thread})
do
prinseq-graphs-noPCA -i quality_reports/discarded_sequences/${file}.gd -html_all -o quality_reports/discarded_sequences/${file} &>> $wd/$name/$path/${date}_detailed.log &
done
done
wait

end=$(date +%s)
dur=$(($end-$start))

echo -e '\nQuality report created! (Duration: '$dur's) 
Open the .html files to view the detailed quality report of the good sequences 
in your browser.'
echo -e "\n________________________________________________________________________________\n"

fi

#Blasting using lotus: http://psbweb05.psb.ugent.be/lotus/tutorial_R.html

(zenity --no-wrap --question --title $path --text "Do you want to align your sequences and make a taxonomic assignment?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Data

cp /usr/local/Pipeline/create_map.py ./
python3 create_map.py name.txt map.txt &>> $wd/$name/$path/${date}_detailed.log
rm create_map.py

sim=$(zenity --text "Please choose an aligner tool:" --title $path --list --column "Aligner" --column "Database" "RDP" "search against the RDP database" "blast" "you can choose between various databases (including custom DB)" "lambda" "you can choose between various databases (including custom DB)" --separator="," --height=250 --width=600 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $sim = "RDP" ]
then

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log

ref="RDP"

elif [ $sim = "blast" ]
then

ref=$(zenity --text "Please choose a reference database:

Databases can be combined, with the first having the highest prioirty (e.g. PR2,SLV would 
first use PR2 to assign OTUs and all unassigned OTUs would be searched for with SILVA).

For detailed information on custom databases and how they need to be formatted, please visit:
http://psbweb05.psb.ugent.be/lotus/images/CustomDB_LotuS.pdf 

ATTENTION: A custom database cannot be combined with any other database!

- SLV: Silva LSU (23/28S) or SSU (16/18S)
- GG: Greengenes (only 16S available)
- UNITE: ITS focused on fungi
- PR2: SSU focused on Protists
- HITdb: database specialized only on human gut microbiota
- beetax: bee gut specific database
- CD: custom database
" --title $path --height=250 --width=600 --entry 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

if [ $ref = "CD" ]
then

customdb=$(zenity --title "Please choose your database file (in fasta format):" --file-selection 2>> $wd/$name/$path/${date}_detailed.log)

cd
cd $( dirname $customdb)

if [[ $? -ne 1 ]]
then 

customtax=$(zenity --title "Please choose your taxonomy file:" --file-selection 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

cd

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -refDB $customdb  -tax4refDB $customtax -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log

fi
fi

elif [[ $ref == *"SLV"* ]]
then

type=$(zenity --text "Which Silva database do you want to use?" --title $path --list --column "" --column "" "LSU" "Database for large ribosomal subunit (23/28S)" "SSU" "Database for small ribosomal subunit (16/18S)" --height=250 --width=600 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -refDB $ref -amplicon_type $type -greengenesSpecies 0 -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log #-tax_group fungi

fi

else

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -refDB $ref -greengenesSpecies 0 -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log

fi
fi

elif [ $sim = "lambda" ]
then

cd
cd $name
cd $path

ref=$(zenity --text "Please choose a reference database:

Databases can be combined, with the first having the highest prioirty (e.g. PR2,SLV would 
first use PR2 to assign OTUs and all unassigned OTUs would be searched for with SILVA).

For detailed information on custom databases and how they need to be formatted, please visit:
http://psbweb05.psb.ugent.be/lotus/images/CustomDB_LotuS.pdf 

ATTENTION: A custom database cannot be combined with any other database!

- SLV: Silva LSU (23/28S) or SSU (16/18S)
- GG: Greengenes (only 16S available)
- UNITE: ITS focused on fungi
- PR2: SSU focused on Protists
- HITdb: database specialized only on human gut microbiota
- beetax: bee gut specific database
- CD: custom database
" --title $path --height=250 --width=600 --entry 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

if [ $ref = "CD" ]
then

customdb=$(zenity --title "Please choose your database file (in fasta format):" --file-selection 2>> $wd/$name/$path/${date}_detailed.log)

cd
cd $( dirname $customdb)

if [[ $? -ne 1 ]]
then 

customtax=$(zenity --title "Please choose your taxonomy file:" --file-selection 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

cd

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -refDB $customdb  -tax4refDB $customtax -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log

fi
fi

elif [[ $ref == *"SLV"* ]]
then

type=$(zenity --text "Which Silva database do you want to use?" --title $path --list --column "" --column "" "LSU" "Database for large ribosomal subunit (23/28S)" "SSU" "Database for small ribosomal subunit (16/18S)" --height=250 --width=600 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -refDB $ref -amplicon_type $type -greengenesSpecies 0 -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log

fi

else

start=$(date +%s)

echo -e "\nSequence alignment and taxonomic assignment proceeding ..."

lotus.pl -c /usr/local/Pipeline/lotus_pipeline/lOTUs.cfg -p miSeq -thr $proc -simBasedTaxo $sim -refDB $ref -greengenesSpecies 0 -i /home/$c/$name/$path/Data/filtered_reads/good_sequences/ -m /home/$c/$name/$path/Data/map.txt -o /home/$c/$name/$path/Results -s /usr/local/Pipeline/lotus_pipeline/sdm_miSeq.txt &>> $wd/$name/$path/${date}_detailed.log

fi
fi
fi

cd
cd $name
cd $path
cd Results

if [ -f "OTU.biom" ]
then
biom convert -i OTU.biom -o otu_table.txt --to-tsv --header-key taxonomy  &>> $wd/$name/$path/${date}_detailed.log

cp /usr/local/Pipeline/report.py ./
python3 report.py &>> $wd/$name/$path/${date}_detailed.log
rm report.py

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nSequence alignment and taxonomic assignment were successful! (Duration: "$dur"s) 
Output files are created using following settings:"
echo
echo "Aligner: " $sim

if [[ $ref == *"SLV"* ]]
then
echo "Reference database(s): "$ref" ("$type")"
else
echo "Reference database(s): " $ref
fi

echo -e "\n________________________________________________________________________________\n"

else
echo -e "An ERROR raised during the blasting process!"

echo -e "\n________________________________________________________________________________\n"
fi
fi
fi

###Post processing

#Singleton removal

(zenity --no-wrap --question --title $path --text "Do you want to remove rare OTUs from your dataset?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

depth=$(zenity --text "Please enter the minimum number of reads for an OTU to be retained:" --title $path --scale --min-value=0 --max-value=100000 --step=1 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

samples=$(zenity --text "Please enter the minimum number of samples in which an OTU must be present to be retained:" --title $path --scale --min-value=0 --max-value=100000 --step=1 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then  

start=$(date +%s)

cd
cd $name
cd $path
cd Results

echo -e "\nRemoval of rare OTUs proceeding ..."

mv OTU.biom OTU_original.biom
mv otu_table.txt otu_table_original.txt

filter_otus_from_otu_table.py -i OTU_original.biom -o OTU.biom -n $depth -s $samples &>> $wd/$name/$path/${date}_detailed.log
biom convert -i OTU.biom -o otu_table.txt --to-tsv --header-key taxonomy &>> $wd/$name/$path/${date}_detailed.log

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nProcess succeeded! (Duration: "$dur"s) Rare OTUs are removed from your 
dataset using the following settings:"
echo
echo "Minimum sum of reads within all samples: " $depth
echo "Minimum sample occurences: " $samples
echo -e "\n________________________________________________________________________________\n"
fi
fi
fi

#Rarefaction curves

(zenity --no-wrap --question --title $path --text "Do you want to generate rarefraction curves?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

calc=$(zenity --text "Please choose a calculator for rarefaction analysis:" --title $path --list --column "Calculator" --column "" "otu" "Observed taxonomic units" "chao" "Chao1 richness estimator" "shannon" "Shannon-Wiener diversity index" "simpson" "Simpson diversity index" "coverage" "Good's coverage for OTU" --separator="," --height=225 --width=400 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

fformat=$(zenity --text "Please choose a file format:" --title $path --list --column "File format" --column "" "EPS" "Encapsulated Postscript" "JPEG" "Joint Photographic Experts Group" "PDF" "Portable Document Format" "PNG" "Portable Network Graphics" "PS" "Postscript" "RAW" "Raw bitmap" "RGBA" "RGBA bitmap" "SVG" "Scalable Vector Graphics" "SVGZ" "Compressed SVG" "TIFF" "Tagged Image File Format" --separator="," --height=300 --width=400 2>> $wd/$name/$path/${date}_detailed.log)

if [ $fformat = "JPEG" ] || [ $fformat = "PNG" ] || [ $fformat = "RAW" ] || [ $fformat = "RGBA" ] || [ $fformat = "TIFF" ]
then

dpi=$(zenity --text "Pixel density [dpi]" --title $path --entry 2>> $wd/$name/$path/${date}_detailed.log)

else
dpi=100

fi


start=$(date +%s)

if [ $calc = "otu" ]
then
calc="sobs"
fi

echo -e "\nRarefaction curves are now created ..."

cd
cd $name
cd $path
cd Results
mkdir -p rarefaction_curves
cd rarefaction_curves

cp ../otu_table.txt ./
cp /usr/local/Pipeline/create_shared_file.py ./
cp /usr/local/Pipeline/rarefactionplot.py ./

python3 create_shared_file.py otu_table.txt otu.shared &>> $wd/$name/$path/${date}_detailed.log
mothur "#rarefaction.single(shared=otu.shared, calc=$calc, processors=$proc)" &>> $wd/$name/$path/${date}_detailed.log
python3 rarefactionplot.py $calc $fformat $dpi &>> $wd/$name/$path/${date}_detailed.log

rm create_shared_file.py
rm rarefactionplot.py
rm otu_table.txt
rm otu.shared

end=$(date +%s)
dur=$(($end-$start))

echo -e '\nProcess succeeded! (Duration: '$dur's)
\nCalculator: '$calc
echo -e "\n________________________________________________________________________________\n"
fi
fi

#Subsampling

(zenity --no-wrap --question --title $path --text "Do you want to make a subsampling of your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/reads.py ./
python3 reads.py otu_table.txt 2>> $wd/$name/$path/${date}_detailed.log

sub=$(zenity --text "Please enter the number of reads for the subsampling:" --title $path --entry 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nSubsampling process proceeding ..."

mv OTU.biom OTU_without_subsampling.biom
mv otu_table.txt otu_table_without_subsampling.txt

single_rarefaction.py -i OTU_without_subsampling.biom -o OTU.biom -d $sub  &>> $wd/$name/$path/${date}_detailed.log
biom convert -i OTU.biom -o otu_table.txt --to-tsv --header-key taxonomy &>> $wd/$name/$path/${date}_detailed.log

rm reads.py

end=$(date +%s)
dur=$(($end-$start))

echo -e '\nProcess succeeded! (Duration: '$dur's) Your samples are subsampled to the length of:' $sub
echo -e "\n________________________________________________________________________________\n"
fi
fi

#Renaming

(zenity --no-wrap --question --title $path --text "Do you want to rename your samples/groups?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

echo -e "\nRenaming of samples in progress ..."

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/rename.py ./
python3 rename.py otu_table.txt 2>> $wd/$name/$path/${date}_detailed.log
biom convert -i otu_table.txt -o OTU.biom --to-hdf5 --table-type="OTU table" --process-obs-metadata taxonomy &>> $wd/$name/$path/${date}_detailed.log

rm rename.py

echo -e '\nProcess succeeded! Your samples are renamed now!'
echo -e "\n________________________________________________________________________________\n"

fi

#Mapping

(zenity --no-wrap --question --title $path --text "Do you want to add metadata (e.g. environmental data) to your samples?

These information can be used in the upcoming steps to group the samples specifically." &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/mapping.py ./
python3 mapping.py otu_table.txt mapping.txt 2>> $wd/$name/$path/${date}_detailed.log
rm mapping.py

fi

#Summary Report

(zenity --no-wrap --question --title $path --text "Do you want to generate a summary report of the phylogenetic diversity?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

(zenity --no-wrap --question --title $path --text "Do you want to use the information in the mapping file to group your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/map_group.py ./
python3 map_group.py otu_table.txt mapping.txt current_otu_table.txt 2>> $wd/$name/$path/${date}_detailed.log
rm map_group.py

else

cd
cd $name
cd $path
cd Results

cp otu_table.txt ./current_otu_table.txt

fi

(zenity --no-wrap --question --title $path --text "Do you want a general summary?
Click 'No' for summary on a specific taxon!" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

sr=$(zenity --text "For which kingdom do you want to create the summary?" --title $path --list --checklist --column "" --column "Kingdom" "" "Archaea" "" "Bacteria" "" "Fungi" "" "Eukaryota" "" "Total" --separator="," --height=250 --width=600 2>> $wd/$name/$path/${date}_detailed.log)

entries=$(zenity --forms --title=$path --text='How many taxa do you wish to show for each taxonomic level?' --add-entry="Top" 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nSummary report is beeing created now ..."

for kingdom in $(echo $sr | sed "s/,/ /g")
do

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/otu_summary.py ./
cp /usr/local/Pipeline/kingdom_table.py ./
python3 kingdom_table.py current_otu_table.txt $kingdom.txt $kingdom &>> $wd/$name/$path/${date}_detailed.log
python3 otu_summary.py $kingdom.txt summary_report_$kingdom.txt $entries 2>> $wd/$name/$path/${date}_detailed.log
rm kingdom_table.py
rm otu_summary.py
rm $kingdom.txt

done

rm current_otu_table.txt &>> $wd/$name/$path/${date}_detailed.log

end=$(date +%s)
dur=$(($end-$start))

echo -e '\nProcess succeeded! (Duration: '$dur's) Summary file(s) created!'
echo -e "\n________________________________________________________________________________\n"

fi

else

taxon=$(zenity --forms --title=$path --text='Please enter the name of the Taxon' --add-entry="Taxon: e.g. Firmicutes" 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

entries=$(zenity --forms --title=$path --text='How many taxa do you wish to show for each taxonomic level?' --add-entry="Top" 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nSummary report is beeing created now ..."

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/otu_summary.py ./
cp /usr/local/Pipeline/specific_taxon.py ./
python3 specific_taxon.py current_otu_table.txt $taxon 2>> $wd/$name/$path/${date}_detailed.log
python3 otu_summary.py $taxon.txt summary_report_$taxon.txt $entries 2>> $wd/$name/$path/${date}_detailed.log
rm specific_taxon.py
rm otu_summary.py
rm current_otu_table.txt &>> $wd/$name/$path/${date}_detailed.log
rm $taxon.txt

end=$(date +%s)
dur=$(($end-$start))

echo -e '\nProcess succeeded! (Duration: '$dur's) Summary file created!'
echo -e "\n________________________________________________________________________________\n"
fi
fi
fi
fi

: '
#Online graphics - CURENTLY NOT WORKING

(zenity --question --title $path --text "Do you want to compute online graphics for your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

start=$(date +%s)

echo -e "\nOnline graphics are beeing created now ..."

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/archaea.py ./
python archaea.py otu_table.txt otu_table_archaea.txt otu_table_bacteria.txt &>> $wd/$name/$path/${date}_detailed.log
rm archaea.py
rm -f OTU_archaea.biom
biom convert -i otu_table_archaea.txt -o OTU_archaea.biom --to-hdf5 --table-type="OTU table" --process-obs-metadata taxonomy &>> $wd/$name/$path/${date}_detailed.log
biom convert -i otu_table_bacteria.txt -o OTU_bacteria.biom --to-hdf5 --table-type="OTU table" --process-obs-metadata taxonomy &>> $wd/$name/$path/${date}_detailed.log

summarize_taxa_through_plots.py -i OTU.biom -o Plots_complete -f 2 &>> $wd/$name/$path/${date}_detailed.log
summarize_taxa_through_plots.py -i OTU_archaea.biom -o Plots_archaea -f 2 &>> $wd/$name/$path/${date}_detailed.log

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nProcess succeeded! (Duration: "$dur"s)\n
You can access an area chart as well as a bar chart by opening the .html files 
in your browser."
echo -e "\n________________________________________________________________________________\n"
fi
'

#Taxa plots

(zenity --no-wrap --question --title $path --text "Do you want to create plots of the most important taxa?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

(zenity --no-wrap --question --title $path --text "Do you want to use the information in the mapping file to group your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/map_group.py ./
python3 map_group.py otu_table.txt mapping.txt current_otu_table.txt 2>> $wd/$name/$path/${date}_detailed.log
rm map_group.py

else

cd
cd $name
cd $path
cd Results

cp otu_table.txt ./current_otu_table.txt

fi

(zenity --no-wrap --question --title $path --text "Do you want general plots?
Click 'No' for plots of a specific taxon!" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

ki=$(zenity --text "For which kingdom do you want to create the plots?" --title $path --list --checklist --column "" --column "Kingdom" "" "Archaea" "" "Bacteria" "" "Fungi" "" "Eukaryota" "" "Total" --separator="," --height=250 --width=600 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

(zenity --no-wrap --question --title $path --text "Do you want to include unassigned taxa in the plots?" &>> $wd/$name/$path/${date}_detailed.log) && answer="Yes" || answer="No"

fformat=$(zenity --text "Please choose a file format:" --title $path --list --column "File format" --column "" "EPS" "Encapsulated Postscript" "JPEG" "Joint Photographic Experts Group" "PDF" "Portable Document Format" "PNG" "Portable Network Graphics" "PS" "Postscript" "RAW" "Raw bitmap" "RGBA" "RGBA bitmap" "SVG" "Scalable Vector Graphics" "SVGZ" "Compressed SVG" "TIFF" "Tagged Image File Format" --separator="," --height=300 --width=400 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $fformat = "JPEG" ] || [ $fformat = "PNG" ] || [ $fformat = "RAW" ] || [ $fformat = "RGBA" ] || [ $fformat = "TIFF" ]
then

params=$(zenity --forms --title=$path --text="Please provide the parameters for the plots:" --add-entry="Threshold [% of reads]" --add-entry="Pixel density [dpi]" 2>> $wd/$name/$path/${date}_detailed.log)

thresh=$(awk -F '[|]' '{print $1}' <<<$params)
dpi=$(awk -F '[|]' '{print $2}' <<<$params)

else
thresh=$(zenity --text "Threshold [% of reads]" --title $path --entry 2>> $wd/$name/$path/${date}_detailed.log)
dpi=100

fi

if [[ $? -ne 1 ]]
then 

start=$(date +%s)

echo -e "\nPlots are beeing created ..."

for kd in $(echo $ki | sed "s/,/ /g")
do

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/kingdom_table.py ./
python3 kingdom_table.py current_otu_table.txt $kd.txt $kd &>> $wd/$name/$path/${date}_detailed.log
rm kingdom_table.py

mkdir -p taxa_plots
cd taxa_plots

mkdir -p $kd
cd $kd
cp /usr/local/Pipeline/otuplots.py ./
cp ../../$kd.txt ./
python3 otuplots.py $kd.txt $thresh $fformat $dpi $answer &>> $wd/$name/$path/${date}_detailed.log
rm otuplots.py
rm $kd.txt

cd
cd $name
cd $path
cd Results

rm $kd.txt

done

rm current_otu_table.txt &>> $wd/$name/$path/${date}_detailed.log

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nProcess succeeded! (Duration: "$dur"s) Plots are created with a threshold of "$thresh"%."
echo -e "\n________________________________________________________________________________\n"
fi
fi
fi

else

tax=$(zenity --forms --title=$path --text='Please enter the name of the Taxon' --add-entry="Taxon: e.g. Firmicutes" 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then 

(zenity --no-wrap --question --title $path --text "Do you want to include unassigned taxa in the plots?" &>> $wd/$name/$path/${date}_detailed.log) && answer="Yes" || answer="No"

fformat=$(zenity --text "Please choose a file format:" --title $path --list --column "File format" --column "" "EPS" "Encapsulated Postscript" "JPEG" "Joint Photographic Experts Group" "PDF" "Portable Document Format" "PNG" "Portable Network Graphics" "PS" "Postscript" "RAW" "Raw bitmap" "RGBA" "RGBA bitmap" "SVG" "Scalable Vector Graphics" "SVGZ" "Compressed SVG" "TIFF" "Tagged Image File Format" --separator="," --height=300 --width=400 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $fformat = "JPEG" ] || [ $fformat = "PNG" ] || [ $fformat = "RAW" ] || [ $fformat = "RGBA" ] || [ $fformat = "TIFF" ]
then

params=$(zenity --forms --title=$path --text="Please provide the parameters for the plots:" --add-entry="Threshold [% of reads]" --add-entry="Pixel density [dpi]" 2>> $wd/$name/$path/${date}_detailed.log)

thresh=$(awk -F '[|]' '{print $1}' <<<$params)
dpi=$(awk -F '[|]' '{print $2}' <<<$params)

else
thresh=$(zenity --text "Threshold [% of reads]" --title $path --entry 2>> $wd/$name/$path/${date}_detailed.log)
dpi=100

fi

if [[ $? -ne 1 ]]
then 

start=$(date +%s)
echo -e "\nPlots are beeing created ..."

cd
cd $name
cd $path
cd Results

cp /usr/local/Pipeline/specific_taxon.py ./
python3 specific_taxon.py current_otu_table.txt $tax 2>> $wd/$name/$path/${date}_detailed.log
rm specific_taxon.py

mkdir -p taxa_plots
cd taxa_plots

mkdir -p $tax
cd $tax
cp /usr/local/Pipeline/otuplots.py ./
cp ../../$tax.txt ./
python3 otuplots.py $tax.txt $thresh $fformat $dpi $answer &>> $wd/$name/$path/${date}_detailed.log
rm otuplots.py
rm $tax.txt

cd
cd $name
cd $path
cd Results

rm $tax.txt
rm current_otu_table.txt &>> $wd/$name/$path/${date}_detailed.log

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nProcess succeeded! (Duration: "$dur"s) Plots are created with a threshold of "$thresh"%."
echo -e "\n________________________________________________________________________________\n"

fi
fi
fi
fi
fi

#Venn plots

(zenity --no-wrap --question --title $path --text "Do you want to create Venn plots for comparison of included taxa?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Results
mkdir -p Venn_plots
cd Venn_plots

cp /usr/local/Pipeline/venn_plot.py ./
cp ../otu_table.txt ./

if [[ -f "../mapping.txt" ]]
then
python3 venn_plot.py otu_table.txt ../mapping.txt 2>> $wd/$name/$path/${date}_detailed.log
else
python3 venn_plot.py otu_table.txt 2>> $wd/$name/$path/${date}_detailed.log
fi

rm venn_plot.py
rm otu_table.txt

fi

#Alpha diversity

(zenity --no-wrap --question --title $path --text "Do you want to calculate/plot the alpha diversity of your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

metric=$(zenity --text "Please choose a metric for the alpha diversity calculation:" --title $path --list --column "Metric" --column "" "OTU" "Number of distinct OTUs" "Shannon" "Shannon-Wiener index" "Simpson" "Simpson's index" "Pielou" "Pielou's evenness index" "Goods_coverage" "Good's coverage of counts" "Chao1" "Chao1 richness estimator" "Faith_PD" "Faith's phylogenetic diversity" --separator="," --height=300 --width=180 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

(zenity --no-wrap --question --title $path --text "Do you want to use the information in the mapping file to group your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cd
cd $name
cd $path
cd Results
mkdir -p alpha_diversity

cd alpha_diversity
cp /usr/local/Pipeline/alphadiversity_mapped.py ./

if [[ -f "../mapping.txt" ]]
then
python3 alphadiversity_mapped.py ../otu_table.txt $metric ../mapping.txt ../Tree.tre 2>> $wd/$name/$path/${date}_detailed.log
else
echo -e "\nYou are missing a map file, process terminated!"
echo -e "\n________________________________________________________________________________\n"
fi
rm alphadiversity_mapped.py

else

cd
cd $name
cd $path
cd Results
mkdir -p alpha_diversity

cd alpha_diversity
cp /usr/local/Pipeline/alphadiversity.py ./
python3 alphadiversity.py ../otu_table.txt $metric ../Tree.tre 2>> $wd/$name/$path/${date}_detailed.log
rm alphadiversity.py

fi
fi
fi

#Beta diversity

(zenity --no-wrap --question --title $path --text "Do you want to calculate/plot the beta diversity of your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

beta=$(zenity --text "How do you want to depict the results of the beta diversity analysis?" --title $path --list --column "" --column "" "PCoA" "Ordination using Principal Coordinates Analysis" "HCA" "Hierarchical Cluster Analysis" --separator="," --height=180 --width=180 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $beta = "PCoA" ]
then

cd
cd $name
cd $path
cd Results
mkdir -p beta_diversity
cd beta_diversity
mkdir -p ordination
cd ordination

metric=$(zenity --text "Please choose a metric for calculating the distance between your samples:" --title $path --list --column "Metric" --column "Remark" "Weighted_unifrac" "Phylogeny based metric - suggested for microbiome data" "Unweighted_unifrac" "Phylogeny based metric - suggested for microbiome data" "Minkowski" "Requires a p-norm (1, 2, 3, ...)" "Euclidean" "Corresponds to Minkowski distance with p = 2" "Manhattan" "Corresponds to Minkowski distance with p = 1" "Cosine" "" "Jaccard" "For presence/absence data - suggested for microbiome data" "Dice" "For presence/absence data" "Canberra" "" "Chebyshev" "Corresponds to Minkowski distance with infinitely high p" "Braycurtis" "Suggested for microbiome data" --separator="," --height=380 --width=280 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $metric = "Weighted_unifrac" ] || [ $metric = "Unweighted_unifrac" ]
then

(zenity --no-wrap --question --title $path --text "Do you want to use metadata from the mapping file in order to color your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cp /usr/local/Pipeline/ordination_mapped.py ./
python3 ordination_mapped.py ../../otu_table.txt $metric ../../mapping.txt ../../Tree.tre 2>> $wd/$name/$path/${date}_detailed.log
rm ordination_mapped.py

else

cp /usr/local/Pipeline/ordination.py ./
python3 ordination.py ../../otu_table.txt $metric ../../Tree.tre 2>> $wd/$name/$path/${date}_detailed.log
rm ordination.py

fi

elif [ $metric = "Minkowski" ]

then

p=$(zenity --text "P-norm:" --title $path --entry 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

(zenity --no-wrap --question --title $path --text "Do you want to use meta data from the mapping file in order to color your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cp /usr/local/Pipeline/ordination_mapped.py ./
python3 ordination_mapped.py ../../otu_table.txt $metric ../../mapping.txt $p 2>> $wd/$name/$path/${date}_detailed.log
rm ordination_mapped.py

else

cp /usr/local/Pipeline/ordination.py ./
python3 ordination.py ../../otu_table.txt $metric $p 2>> $wd/$name/$path/${date}_detailed.log
rm ordination.py

fi
fi

else

(zenity --no-wrap --question --title $path --text "Do you want to use meta data from the mapping file in order to color your samples?" &>> $wd/$name/$path/${date}_detailed.log) && shell="Yes" || shell="No"

if [ $shell = "Yes" ]
then

cp /usr/local/Pipeline/ordination_mapped.py ./
python3 ordination_mapped.py ../../otu_table.txt $metric ../../mapping.txt 2>> $wd/$name/$path/${date}_detailed.log
rm ordination_mapped.py

else

cp /usr/local/Pipeline/ordination.py ./
python3 ordination.py ../../otu_table.txt $metric 2>> $wd/$name/$path/${date}_detailed.log
rm ordination.py

fi
fi
fi

else
meth=$(zenity --text "Please choose a method for the HCA:" --title $path --list --column "Method" --column "Alternative name" "single" "Minimum" "complete" "Maximum" "average" "UPGMA" "weighted" "WPGMA" "centroid" "UPGMC" "median" "WPGMC" "ward" "Incremental" --separator="," --height=280 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $meth = "centroid" ] || [ $meth = "median" ] || [ $meth = "ward" ]
then

metr="euclidean"

else 

metr=$(zenity --text "Please choose a metric for measuring the distance between points:" --title $path --list --column "Metric" "euclidean" "cosine" "cityblock" "correlation" "jaccard" "braycurtis" "dice" --separator="," --height=280 --width=180 2>> $wd/$name/$path/${date}_detailed.log)

fi

if [[ $? -ne 1 ]]
then

(zenity --no-wrap --question --title $path --text "Do you want to plot the distance of each node in the dendrogram?" &>> $wd/$name/$path/${date}_detailed.log) && anno="Yes" || anno="No"

fformat=$(zenity --text "Please choose a file format:" --title $path --list --column "File format" --column "" "EPS" "Encapsulated Postscript" "JPEG" "Joint Photographic Experts Group" "PDF" "Portable Document Format" "PNG" "Portable Network Graphics" "PS" "Postscript" "RAW" "Raw bitmap" "RGBA" "RGBA bitmap" "SVG" "Scalable Vector Graphics" "SVGZ" "Compressed SVG" "TIFF" "Tagged Image File Format" --separator="," --height=300 --width=400 2>> $wd/$name/$path/${date}_detailed.log)

if [[ $? -ne 1 ]]
then

if [ $fformat = "JPEG" ] || [ $fformat = "PNG" ] || [ $fformat = "RAW" ] || [ $fformat = "RGBA" ] || [ $fformat = "TIFF" ]
then

dpi=$(zenity --text "Pixel density [dpi]" --title $path --entry 2>> $wd/$name/$path/${date}_detailed.log)

else
dpi=100

fi

if [[ $? -ne 1 ]]
then

start=$(date +%s)

echo -e "\nCluster analysis proceeding ..."

cd
cd $name
cd $path
cd Results
mkdir -p beta_diversity
cd beta_diversity
mkdir -p cluster_analysis
cd cluster_analysis

cp /usr/local/Pipeline/cluster.py ./
cp /usr/local/Pipeline/create_shared_file.py ./
python3 create_shared_file.py ../../otu_table.txt otu.shared &>> $wd/$name/$path/${date}_detailed.log
python3 cluster.py otu.shared $meth $metr $anno $fformat $dpi 2>> $wd/$name/$path/${date}_detailed.log
rm cluster.py
rm create_shared_file.py
rm otu.shared

end=$(date +%s)
dur=$(($end-$start))

echo -e "\nProcess succeeded! Dendrogram created! (Duration: "$dur"s)"
echo
echo "Clustering method: " $meth
echo "Clustering metric: " $metr
echo -e "\n________________________________________________________________________________\n"
fi
fi
fi
fi
fi
fi
fi

zenity --no-wrap --text "Thank you for using CoMA, the NGS analysis pipeline! 

(C) 2020 
Sebastian Hupfauf
Mohammad Etemadi" --title $path --info &>> $wd/$name/$path/${date}_detailed.log
