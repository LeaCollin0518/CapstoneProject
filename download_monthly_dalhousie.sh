#!/usr/bin/env bash

__DIR__="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")" # directory of this script
mkdir -p "${__DIR__}/Data/dalhousie_v2/monthly"
cd "${__DIR__}/Data/dalhousie_v2/monthly"

dh_url='ftp://stetson.phys.dal.ca/Aaron/V4NA02/Monthly/ASCII/PM25/GWRwSPEC_PM25_NA_'

for i in `seq 2000 2016`; do
	for j in `seq -w 1 12`; do
		curl -OL "${dh_url}${i}${j}_${i}${j}-RH35-NoNegs.asc.zip"

	done
done

for zipfile in *zip; do
	unzip "${zipfile}"
	rm "${zipfile}"

done

rm *.prj
