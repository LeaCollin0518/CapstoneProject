import requests
import urllib
import os

from zipfile import ZipFile
from urllib.request import urlopen


for i in range(2012, 2017):
	y = str(i)

	# in_f = 'CMAQ_DS_PM25_'+y+'_12km.zip'
	# out_f = 'CMAQ.DS.PM25.'+y+'.12km.csv'
	in_f = 'ds_input_cmaq_pm25_'+y+'.zip'
	out_f = 'ds.input.cmaq.pm25.'+y+'.csv'

	url = 'https://ofmpub.epa.gov/rsig/rsigserver?data/FAQSD/inputs/'+in_f
# download the file contents in binary format
	r = requests.get(url)

# open method to open a file on your system and write the contents
	with open(in_f, 'wb') as f:
		f.write(r.content)

# Copy a network object to a local file
	urllib.request.urlretrieve(url, in_f)

	curr_f =ZipFile(in_f)

	curr_f.extract(member= out_f)
	os.remove(in_f)
	print(y)
