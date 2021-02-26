#!/bin/bash
# Build BQ GeoJSON dataset from OSM dump file
# The driver will categorize features into 5 layers :

# points : “node” features that have significant tags attached.
# lines : “way” features that are recognized as non-area.
# multilinestrings : “relation” features that form a multilinestring
# (type = ‘multilinestring’ or type = ‘route’).
# multipolygons : “relation” features that form a multipolygon
# (type = ‘multipolygon’ or type = ‘boundary’), and “way” features that
# are recognized as area.
# other_relations : “relation” features that do not belong to the above 2 layers.
# Note: for recent GDAL option "OGR_INTERLEAVED_READING=YES" is not required
# Use as
# time sh osm2geojsoncsv germany-latest.osm.pbf germany-latest
set -e




#if [ "$#" -ne 2 ]
#then
#    echo "Use as:\n\t$0 INPUT_FILENAME_OSM_PBF OUTPUT_BASENAME"
#    exit 1
#fi

# input file name
OSMNAME="$1"
# use custom GDAL configuration
OGRCONFIG="$2"
# output file basename (without extension)
#NAME="$2"

# check input file
if [ ! -f "$OSMNAME" ]
then
    echo "Input file '$1' doesn't exist"
    exit 1
fi
# check input file
if [ ! -r "$OSMNAME" ]
then
    echo "Input file '$1' is not readable"
    exit 1
fi
if [ ! -s "$OSMNAME" ]
then
    echo "Input file '$1' is empty"
    exit 1
fi

BASENAME=$(basename "$OSMNAME")
if [ $(basename "$BASENAME" .pbf) = "$BASENAME" ]
then
    echo "Input file '$1' is not PBF Format ('Protocolbuffer Binary Format') file"
    exit 1
fi

# the option below can be helpful for some hardware configurations:
# --config OSM_COMPRESS_NODES YES
# GDAL_CACHEMAX and OSM_MAX_TMPFILE_SIZE defined in MB
# for GDAL_CACHEMAX=4000 and OSM_MAX_TMPFILE_SIZE=4000 recommended RAM=60GB

for ogrtype in GEOMETRY POINT LINESTRING POLYGON MULTIPOLYGON
do
    echo "Processing ${ogrtype}"

    ogr2ogr \
    -skipfailures \
    -lco "OVERWRITE=yes" \
    -f 'PostgreSQL' PG:"host='$PG_HOST' port='$PG_PORT' dbname='$PG_DBNAME' user='$PG_USER' password='$PG_PASSWORD'" \
    "$OSMNAME" \
    -sql "select AsGeoJSON(geometry) AS geometry, $osm_fields, replace(all_tags,X'0A','') as all_tags from $ogrtype where ST_IsValid(geometry) = 1" \
    --config OGR_INTERLEAVED_READING YES \
    --config OSM_CONFIG_FILE "$OGRCONFIG" \
    --config GDAL_CACHEMAX 2000 \
    --config OSM_MAX_TMPFILE_SIZE 2000 \
    -progress \
    -nlt $ogrtype
done
wait
echo "Complete"
