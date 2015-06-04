#!/bin/bash

if [ $1 ]
then
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    $DIR/../libki_create.pl model DB DBIC::Schema Libki::Schema::DB create=static components=TimeStamp,EncodedColumn,Numeric dbi:mysql:$1 $2 $3
else
    echo "update_schema.sh database username password"
fi

