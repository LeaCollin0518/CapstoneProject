#!/usr/bin/env bash

__DIR__="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")" # directory of this script
mkdir -p "${__DIR__}/Data/dalhousie_v2/annual"
cd "${__DIR__}/Data/dalhousie_v2/annual"

dh_url='http://fizz.phys.dal.ca/~atmos/datasets/EST2019/GWRwSPEC_PM25_NA_'

for i in `seq 2000 2016`; do
	curl -OL "${dh_url}${i}01_${i}12-RH35-NoNegs.asc.zip"
done

for zipfile in *zip; do
	y=${zipfile%.zip}
	unzip "${zipfile}" -d $y
	rm "${zipfile}"

done
