#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $1 ]
then
    $DIR/../libki_create.pl model DB DBIC::Schema Libki::Schema::DB create=static components=TimeStamp,EncodedColumn,Numeric dbi:mysql:$1:$2:$3 $4 $5 cursor_class=DBIx::Class::Cursor::Cached overwrite_modifications=1
    mysqldump -d -u $4 -p$5 -h $2 -P $3 $1 | sed 's/ AUTO_INCREMENT=[0-9]*//g' > $DIR/../../installer/schema.sql
elif [[ $LIBKI_DB_DATABASE && $LIBKI_DB_HOST && $LIBKI_DB_PORT && $LIBKI_DB_USER && $LIBKI_DB_PASSWORD ]]
then
    $DIR/../libki_create.pl model DB DBIC::Schema Libki::Schema::DB create=static components=TimeStamp,EncodedColumn,Numeric dbi:mysql:$LIBKI_DB_DATABASE:$LIBKI_DB_HOST:$LIBKI_DB_PORT $LIBKI_DB_USER $LIBKI_DB_PASSWORD cursor_class=DBIx::Class::Cursor::Cached overwrite_modifications=1
    mysqldump -d -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE | sed 's/ AUTO_INCREMENT=[0-9]*//g' > $DIR/../../installer/schema.sql
else
    echo "update_schema.sh database host port username password"
fi
