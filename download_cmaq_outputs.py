import requests
import urllib
import os

from urllib.request import urlopen
import gzip
# import shutil


for i in range(2002, 2017):
	y = str(i)

	in_f = y+'_pm25_daily_average.txt.gz'
	out_f = y+'_pm25_daily_average 2.txt'
	url = 'https://ofmpub.epa.gov/rsig/rsigserver?data/FAQSD/outputs/'+in_f


	r = urllib.request.urlopen(url)

	with open(out_f, 'wb') as out:
		out.write(gzip.decompress(r.read()))


	print(y)
