#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1 (foo);

Datum
foo (PG_FUNCTION_ARGS)
{
    PG_RETURN_TEXT_P(cstring_to_text("bar"));
}
