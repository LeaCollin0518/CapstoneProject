#!/usr/bin/env bash

__DIR__="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")" # directory of this script
mkdir -p "${__DIR__}/epa_data"
cd "${__DIR__}/epa_data"

epa_url='https://aqs.epa.gov/aqsweb/airdata/daily_88101_'

for i in `seq 2000 2016`; do
	curl -OL "${epa_url}$i.zip"
done

for zipfile in *zip; do
	unzip "${zipfile}"
	rm "${zipfile}"
done
