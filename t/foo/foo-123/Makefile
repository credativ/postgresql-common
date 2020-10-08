MODULE_big = foo
OBJS = foo.o
EXTENSION = foo
DATA = foo--100.sql foo--100--123.sql foo--123.sql
REGRESS = foo upgrade

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

