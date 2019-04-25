#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $1 ]
then
    $DIR/../libki_create.pl model DB DBIC::Schema Libki::Schema::DB create=static components=TimeStamp,EncodedColumn,Numeric dbi:mysql:$1:$2:$3 $4 $5 cursor_class=DBIx::Class::Cursor::Cached
elif [[ $LIBKI_DB_DATABASE && $LIBKI_DB_HOST && $LIBKI_DB_PORT && $LIBKI_DB_USER && $LIBKI_DB_PASSWORD ]]
then
    $DIR/../libki_create.pl model DB DBIC::Schema Libki::Schema::DB create=static components=TimeStamp,EncodedColumn,Numeric dbi:mysql:$LIBKI_DB_DATABASE:$LIBKI_DB_HOST:$LIBKI_DB_PORT $LIBKI_DB_USER $LIBKI_DB_PASSWORD cursor_class=DBIx::Class::Cursor::Cached
else
    echo "update_schema.sh database host port username password"
fi
