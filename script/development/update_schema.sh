#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $1 ]
then
    LIBKI_DB_DATABASE=$1
    LIBKI_DB_HOST=$2
    LIBKI_DB_PORT=$3
    LIBKI_DB_USER=$4
    LIBKI_DB_PASSWORD=$5
fi

if [[ $LIBKI_DB_DATABASE && $LIBKI_DB_HOST && $LIBKI_DB_PORT && $LIBKI_DB_USER && $LIBKI_DB_PASSWORD ]]
then
    # Update the Libki schema files
    $DIR/../libki_create.pl model DB DBIC::Schema Libki::Schema::DB create=static components=TimeStamp,EncodedColumn,Numeric dbi:mysql:$LIBKI_DB_DATABASE:$LIBKI_DB_HOST:$LIBKI_DB_PORT $LIBKI_DB_USER $LIBKI_DB_PASSWORD cursor_class=DBIx::Class::Cursor::Cached overwrite_modifications=1

    # Save a copy of the current database schema
    mysqldump --no-data -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE | sed 's/ AUTO_INCREMENT=[0-9]*//g' > /tmp/libki_current_schema.sql

    # Save a copy of the current database data
    mysqldump --no-create-info -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE | sed 's/ AUTO_INCREMENT=[0-9]*//g' > /tmp/libki_current_data.sql

    # Drop and recreate the empty database
    mysql -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE -e "DROP DATABASE $LIBKI_DB_DATABASE; CREATE DATABASE $LIBKI_DB_DATABASE"

    # Run the installer to generate a fresh db schema
    $DIR/../../installer/update_db.pl

    # Save a copy of the current database schema
    mysqldump --no-data -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE | sed 's/ AUTO_INCREMENT=[0-9]*//g' > $DIR/../../installer/schema.sql

    # Compare the two new schema files
    DIFF=$(diff -I "^-- Dump completed on" $DIR/../../installer/schema.sql /tmp/libki_current_schema.sql)
    if [ "$DIFF" == "" ]
    then
        # Save a copy of the updated default database data
        mysqldump --no-create-info -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE | sed 's/ AUTO_INCREMENT=[0-9]*//g' > $DIR/../../installer/data.sql
    else
        echo "WARNING: The schema from a fresh install does not match the current schema. Did you forget to add a database update?"
    fi

    # Save a copy of the updated default database data
    mysqldump --no-create-info --skip-extended-insert -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE | sed 's/ AUTO_INCREMENT=[0-9]*//g' > $DIR/../../installer/data.sql

    # Drop and recreate the empty database again
    mysql -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE -e "DROP DATABASE $LIBKI_DB_DATABASE; CREATE DATABASE $LIBKI_DB_DATABASE"

    # Restore the original database data and schame
    mysql -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE < /tmp/libki_current_schema.sql
    mysql -u $LIBKI_DB_USER -p$LIBKI_DB_PASSWORD -h $LIBKI_DB_HOST -P $LIBKI_DB_PORT $LIBKI_DB_DATABASE < /tmp/libki_current_data.sql

    rm /tmp/libki_current_data.sql
    rm /tmp/libki_current_schema.sql
else
    echo "update_schema.sh database host port username password"
fi
