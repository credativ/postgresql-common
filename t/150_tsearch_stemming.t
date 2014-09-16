# Check tsearch, and stemming with dynamic creation of .affix/.dict files

use strict;

use lib 't';
use TestLib;
use PgCommon;

my $version = $MAJORS[-1];

use Test::More tests => $PgCommon::rpm ? 1 : 39;
if ($PgCommon::rpm) {
    pass 'tsearch dictionaries not handled by postgresql-common on RedHat';
    exit;
}

# test pg_updatedicts
unlink '/var/cache/postgresql/dicts/en_us.affix';
unlink '/var/cache/postgresql/dicts/en_us.dict';
unlink "/usr/share/postgresql/$version/tsearch_data/en_us.affix";
unlink "/usr/share/postgresql/$version/tsearch_data/en_us.dict";
is ((exec_as 0, 'pg_updatedicts'), 0, 'pg_updatedicts succeeded');
ok -f '/var/cache/postgresql/dicts/en_us.affix',
    'pg_updatedicts created en_us.affix';
ok -f '/var/cache/postgresql/dicts/en_us.dict',
    'pg_updatedicts created en_us.dict';
ok -l "/usr/share/postgresql/$version/tsearch_data/en_us.affix",
    "pg_updatedicts created $version en_us.affix symlink";
ok -l "/usr/share/postgresql/$version/tsearch_data/en_us.dict",
    "pg_updatedicts created $version en_us.dict symlink";

# create cluster
is ((system "pg_createcluster $version main --start >/dev/null"), 0, "pg_createcluster $version main");

# create DB with en_US text search configuration
is_program_out 'postgres', 'createdb fts', 0, '';

my $outref;

is ((exec_as 'postgres', 'psql -qd fts -c "
  CREATE TEXT SEARCH CONFIGURATION public.sc_english ( COPY = pg_catalog.english );
  CREATE TEXT SEARCH DICTIONARY english_ispell (TEMPLATE = ispell, DictFile = en_US,
              AffFile = en_US, StopWords = english);
  SET default_text_search_config = \'public.sc_english\';
  ALTER TEXT SEARCH CONFIGURATION public.sc_english
     ALTER MAPPING FOR asciiword WITH english_ispell, english_stem;"', $outref),
    0, 'creating en_US full text search configuration ' . $$outref);

# create test table and index
my $outref;
is ((exec_as 'postgres', 'psql -qd fts -c "
  CREATE TABLE stuff (id SERIAL PRIMARY KEY, text TEXT, textsearch tsvector);
  UPDATE stuff SET textsearch = to_tsvector(\'public.sc_english\', coalesce(text, \'\'));
  CREATE INDEX textsearch_idx ON stuff USING gin(textsearch);
  CREATE TRIGGER textsearch_update_trigger BEFORE INSERT OR UPDATE
    ON stuff FOR EACH ROW EXECUTE PROCEDURE
      tsvector_update_trigger(textsearch, \'public.sc_english\', text);
  INSERT INTO stuff (text) VALUES (\'PostgreSQL rocks\');
  INSERT INTO stuff (text) VALUES (\'Linux rocks\');
  INSERT INTO stuff (text) VALUES (\'I am your father\'\'s nephew\'\'s former roommate\');
  INSERT INTO stuff (text) VALUES (\'3 cafés\');
  "'), 0, 'creating data table and search index');

# test stemming
is_program_out 'postgres',
    'psql -Atd fts -c "SELECT dictionary, lexemes FROM ts_debug(\'public.sc_english\', \'friendliest\')"',
    0, "english_ispell|{friendly}\n", 'stem search of correct word';
is_program_out 'postgres',
    'psql -Atd fts -c "SELECT dictionary, lexemes FROM ts_debug(\'public.sc_english\', \'father\'\'s\')"',
    0, "english_ispell|{father}\n|\nenglish_ispell|{}\n", 'stem search of correct word';
is_program_out 'postgres',
    'psql -Atd fts -c "SELECT dictionary, lexemes FROM ts_debug(\'public.sc_english\', \'duffles\')"',
    0, "english_stem|{duffl}\n", 'stem search of unknown word';

# test searching
is_program_out 'postgres',
    'psql -Atd fts -c "SELECT text FROM stuff, to_tsquery(\'rocks\') query WHERE query @@ to_tsvector(text)"',
    0, "PostgreSQL rocks\nLinux rocks\n", 'full text search, exact word';

is_program_out 'postgres',
    'psql -Atd fts -c "SELECT text FROM stuff, to_tsquery(\'rock\') query WHERE query @@ to_tsvector(text)"',
    0, "PostgreSQL rocks\nLinux rocks\n", 'full text search for word stem';

is_program_out 'postgres',
    'psql -Atd fts -c "SELECT text FROM stuff, to_tsquery(\'roc\') query WHERE query @@ to_tsvector(text)"',
    0, '', 'full text search for word substring fails';

is_program_out 'postgres',
    'psql -Atd fts -c "SELECT text FROM stuff, to_tsquery(\'cafés\') query WHERE query @@ to_tsvector(text)"',
    0, "3 cafés\n", 'full text search, exact unicode word';

is_program_out 'postgres',
    'psql -Atd fts -c "SELECT text FROM stuff, to_tsquery(\'café\') query WHERE query @@ to_tsvector(text)"',
    0, "3 cafés\n", 'full text search for unicode word stem';

is_program_out 'postgres',
    'psql -Atd fts -c "SELECT text FROM stuff, to_tsquery(\'afé\') query WHERE query @@ to_tsvector(text)"',
    0, '', 'full text search for unicode word substring fails';

# clean up
is ((system "pg_dropcluster $version main --stop"), 0);
check_clean;

# vim: filetype=perl
