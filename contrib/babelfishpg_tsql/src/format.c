/*
 * String-related functions for T-SQL
 */

#include "postgres.h"
#include "c.h"

#include "catalog/pg_type.h"
#include "parser/parse_coerce.h"
#include "utils/builtins.h"
#include "utils/elog.h"
#include "utils/lsyscache.h"
#include "utils/varlena.h"
#include "regex/regex.h"

#include "collation.h"
#include "format.h"
#include "pltsql.h"
#include "pltsql-2.h"

#include <string.h>
#include <strings.h>
#include <time.h>

#include "utils/syscache.h"
#include "funcapi.h"
#include "fmgr.h"
#include "utils/date.h"
#include "utils/datetime.h"
#include "catalog/pg_type_d.h"
#include "utils/guc.h"
#include "utils/pg_locale.h"

#include "catalog/pg_collation.h"

size_t		CULTURE_COUNT = sizeof(datetimeformats) / sizeof(datetimeformat);

PG_FUNCTION_INFO_V1(format_datetime);
PG_FUNCTION_INFO_V1(format_numeric);

/*
 *	Formats date, time related datatypes to char
 */
Datum
format_datetime(PG_FUNCTION_ARGS)
{
	Datum		arg_value;
	Oid			arg_type_oid;
	const char *format_pattern;
	const char *culture;
	const char *data_type;
	int			fmt_res = 0;
	const char *data_str;
	StringInfo	buf;
	VarChar    *result;

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	culture = text_to_cstring(PG_GETARG_TEXT_P(2));

	(void) format_validate_and_culture(culture, "LC_TIME");

	buf = makeStringInfo();

	arg_type_oid = get_fn_expr_argtype(fcinfo->flinfo, 0);

	if (PG_ARGISNULL(1))
	{
		PG_RETURN_NULL();
	}
	else
	{
		format_pattern = text_to_cstring(PG_GETARG_TEXT_P(1));
	}

	if (!PG_ARGISNULL(3))
	{
		data_type = text_to_cstring(PG_GETARG_TEXT_P(3));
	}
	else
	{
		data_type = "";
	}

	if (strlen(format_pattern) <= 1)
	{
		if (arg_type_oid == TIMEOID)
		{
			data_str = DatumGetCString(DirectFunctionCall1(time_out, PG_GETARG_DATUM(0)));
		}
		else
		{
			data_str = "";
		}

		fmt_res = format_datetimeformats(buf, format_pattern, culture, data_type, data_str);
	}
	else
	{
		fmt_res = process_format_pattern(buf, format_pattern, data_type);
	}

	if (fmt_res <= 0)
	{
		pfree(buf->data);
		pfree(buf);

		if (fmt_res == 0)
		{
			PG_RETURN_NULL();
		}
		else if (fmt_res == -1)
		{
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("Format %s is not supported currently! Please try again with another format", format_pattern),
					 errhint("Unsupported format pattern")));
		}
		else
		{
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("The culture parameter \"%s\" provided in the function call is invalid.", culture),
					 errhint("Invalid culture value.")));
		}
	}

	arg_value = PG_GETARG_DATUM(0);

	switch (arg_type_oid)
	{
		case TIMEOID:
			data_to_char(DirectFunctionCall1(time_interval, arg_value), TIMEOID, buf);
			break;
		case TIMESTAMPOID:
			data_to_char(arg_value, TIMESTAMPOID, buf);
			break;
		default:
			pfree(buf);
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("The data type of the first argument is invalid/currently not supported."),
					 errhint("Convert it to other datatype and try again.")));
			break;
	}

	result = (*common_utility_plugin_ptr->tsql_varchar_input) (buf->data, buf->len, -1);

	pfree(buf->data);
	pfree(buf);

	PG_RETURN_VARCHAR_P(result);
}

/*
 *	Formats Numeric datatypes to char
 */
Datum
format_numeric(PG_FUNCTION_ARGS)
{
	Datum		datum_val = PG_GETARG_DATUM(0);
	char	   *format_pattern;
	char	   *data_type;
	StringInfo	format_res = makeStringInfo();
	Numeric		numeric_val;
	Oid			arg_type_oid;
	char	   *culture;
	char	   *valid_culture;
	char		pattern;
	char	   *precision_string;
	int			sig_len;
	char	   *temp_pattern;
	char		real_pattern[120];
	char		upper_pattern;
	const char *format_re = "^[cdefgnprxCDEFGNPRX]{1}[0-9]*$";
	bool		is_custom = false;
	VarChar    *result;

	if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	culture = text_to_cstring(PG_GETARG_TEXT_P(2));

	valid_culture = format_validate_and_culture(culture, "LC_NUMERIC");

	format_pattern = text_to_cstring(PG_GETARG_TEXT_P(1));

	/* without a format string the number is formatted like with "G" */
	if (format_pattern[0] == '\0')
		format_pattern = pstrdup("G");

	/*
	 * A letter followed by up to two digits is a standard format string,
	 * everything else is a custom one like "00" or "#,##0.00".
	 */
	if (match(format_pattern, format_re) == 0)
		is_custom = (match(format_pattern, "^[a-zA-Z][0-9]{0,2}$") == 0);

	if (match(format_pattern, format_re) == 0 && !is_custom)
	{
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("%s is not supported/invalid format when converting from NUMERIC to a character string.", format_pattern),
				 errdetail("Use of incorrect \"format\" parameter value during conversion process."),
				 errhint("Change \"format\" parameter value and try again.")));
	}

	/* a custom format string has no format specifier, also if it starts with a letter */
	pattern = is_custom ? '\0' : format_pattern[0];
	upper_pattern = toupper(pattern);
	precision_string = TextDatumGetCString(DirectFunctionCall2(text_substr_no_len, CStringGetTextDatum(format_pattern), Int32GetDatum((int32) 2)));

	data_type = text_to_cstring(PG_GETARG_TEXT_P(3));
	arg_type_oid = get_fn_expr_argtype(fcinfo->flinfo, 0);

	switch (arg_type_oid)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
			numeric_val = int64_to_numeric(PG_GETARG_INT64(0));
			break;
		case NUMERICOID:
			numeric_val = PG_GETARG_NUMERIC(0);
			break;
		case FLOAT4OID:
			set_config_option("extra_float_digits", "1", PGC_USERSET, PGC_S_SESSION, GUC_ACTION_LOCAL, true, 0, false);

			if (upper_pattern == 'R')
			{
				sig_len = PG_GETARG_INT32(4);

				if (sig_len <= 0)
				{
					snprintf(real_pattern, sizeof(real_pattern), "%.*g", 8, DatumGetFloat4(datum_val));
					numeric_val = cstring_to_numeric(real_pattern);
				}
				else
				{
					if (sig_len > 6)
					{
						temp_pattern = "9D99999999EEEE";
					}
					else
					{
						temp_pattern = "9D999999EEEE";
					}

					resetStringInfo(format_res);
					appendStringInfoString(format_res, temp_pattern);

					float4_data_to_char(format_res, datum_val);

					if (format_res->len > 0)
					{
						if (isupper(pattern))
						{
							regexp_replace(format_res->data, "[.]{0,1}0*[eE]", "E", "i");
						}

						result = (*common_utility_plugin_ptr->tsql_varchar_input) (format_res->data, format_res->len, -1);

						pfree(format_res->data);
						pfree(format_res);
						PG_RETURN_VARCHAR_P(result);
					}
					pfree(format_res->data);
					pfree(format_res);
					PG_RETURN_NULL();
				}
			}
			else
			{
				if (upper_pattern == 'E' || upper_pattern == 'G')
				{
					temp_pattern = "9D99999999EEEE";
				}
				else
				{
					temp_pattern = "9D999999EEEE";
				}

				appendStringInfoString(format_res, temp_pattern);

				float4_data_to_char(format_res, datum_val);

				numeric_val = cstring_to_numeric(format_res->data);
			}
			break;
		case FLOAT8OID:
			set_config_option("extra_float_digits", "1", PGC_USERSET, PGC_S_SESSION, GUC_ACTION_LOCAL, true, 0, false);

			if (upper_pattern == 'R')
			{
				pfree(format_res->data);
				pfree(format_res);

				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("Format \"R\" is currently not supported for FLOAT datatype")));
			}
			else if (upper_pattern == 'E' || upper_pattern == 'G')
			{
				appendStringInfoString(format_res, "9D9999999999999999EEEE");
				float8_data_to_char(format_res, datum_val);
				numeric_val = cstring_to_numeric(format_res->data);
			}
			else
			{
				numeric_val = DatumGetNumeric(DirectFunctionCall1(float8_numeric, datum_val));
			}
			break;
		default:
			pfree(format_res->data);
			pfree(format_res);
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("The data type of the first argument is invalid."),
					 errdetail("Use of invalid value parameter."),
					 errhint("Convert it to valid datatype and try again.")));
			break;
	}

	if (is_custom)
	{
		/* the result can be an empty string, like for FORMAT(0, '#') */
		format_custom_numeric(numeric_val, format_res, format_pattern);
		result = (*common_utility_plugin_ptr->tsql_varchar_input) (format_res->data, format_res->len, -1);

		pfree(format_res->data);
		pfree(format_res);
		PG_RETURN_VARCHAR_P(result);
	}

	format_numeric_handler(datum_val, numeric_val, format_res, pattern, precision_string, arg_type_oid, culture, valid_culture, data_type);

	if (format_res->len > 0)
	{
		result = (*common_utility_plugin_ptr->tsql_varchar_input) (format_res->data, format_res->len, -1);

		pfree(format_res->data);
		pfree(format_res);
		PG_RETURN_VARCHAR_P(result);
	}

	pfree(format_res->data);
	pfree(format_res);
	PG_RETURN_NULL();
}

/*
 * Custom numeric format strings ("00", "#,##0.00", "0.0%", "0.00E+0",
 * "pos;neg;zero"), as opposed to the standard ones that consist of a letter
 * and a precision. The rules are those of .NET, which SQL Server uses for
 * FORMAT():
 *
 *   0       digit, or 0 if the number has no digit at this position
 *   #       digit, or nothing
 *   .       the first one is the decimal separator of the culture
 *   ,       between digit placeholders: group separator of the culture;
 *           directly before the decimal point: divides the number by 1000
 *   %       multiplies by 100, per mille sign multiplies by 1000
 *   E+0     exponential notation (E0, E+0, E-0, e0, e+0, e-0)
 *   \c      the character c as it is
 *   'abc'   the text as it is, also with double quotes
 *   ;       separates the sections for positive, negative and zero values
 *
 * Every other character is copied to the result.
 */

/* the per mille sign U+2030 in UTF-8 */
#define IS_PER_MILLE(s) ((unsigned char) (s)[0] == 0xE2 && \
						 (unsigned char) (s)[1] == 0x80 && \
						 (unsigned char) (s)[2] == 0xB0)

/*
 * Start of the given section (0 positive, 1 negative, 2 zero) of a custom
 * numeric format string. A section that is missing or empty is replaced by
 * the first one.
 */
static int
custom_numeric_find_section(const char *format, int section)
{
	int			src = 0;
	char		ch;

	if (section == 0)
		return 0;

	while ((ch = format[src]) != '\0')
	{
		src++;
		switch (ch)
		{
			case '\'':
			case '"':
				while (format[src] != '\0' && format[src++] != ch)
					;
				break;
			case '\\':
				if (format[src] != '\0')
					src++;
				break;
			case ';':
				if (--section != 0)
					break;
				if (format[src] != '\0' && format[src] != ';')
					return src;
				return 0;
			default:
				break;
		}
	}

	return 0;
}

/*
 * Round the digits of a number to pos digits, half away from zero. digits is
 * a string of decimal digits without leading and trailing zeros, *scale the
 * number of digits before the decimal point.
 */
static void
custom_numeric_round(char *digits, int *scale, int pos)
{
	int			len = strlen(digits);
	int			i;

	if (pos >= len)
		return;

	if (pos < 0 || digits[pos] < '5')
	{
		/* round down */
		i = (pos < 0) ? 0 : pos;
	}
	else
	{
		/* round up, with carry */
		i = pos;
		while (i > 0 && digits[i - 1] == '9')
			i--;

		if (i > 0)
			digits[i - 1]++;
		else
		{
			digits[0] = '1';
			i = 1;
			(*scale)++;
		}
	}

	while (i > 0 && digits[i - 1] == '0')
		i--;
	digits[i] = '\0';

	if (i == 0)
		*scale = 0;
}

static void
format_custom_numeric(Numeric numeric_val, StringInfo format_res, const char *format)
{
	struct lconv *lconv = PGLC_localeconv();
	const char *decimal_sep = ".";
	const char *group_sep = ",";
	char	   *numstr = numeric_text(numeric_val);
	char	   *digits;
	char	   *cur;
	char	   *p;
	bool		negative = false;
	int			scale = 0;
	int			ndigits = 0;
	int			section;
	int			src;
	char		ch;

	/* results of scanning the section */
	int			digit_count;
	int			decimal_pos;
	int			first_digit;
	int			last_digit;
	int			scale_adjust;
	bool		thousand_seps;
	bool		scientific;

	int			dig_pos;
	int			adjust;
	bool		decimal_written = false;

	resetStringInfo(format_res);

	/* same choice of separators as numeric_to_char() */
	if (lconv->decimal_point && *lconv->decimal_point)
		decimal_sep = lconv->decimal_point;
	if (lconv->thousands_sep && *lconv->thousands_sep)
		group_sep = lconv->thousands_sep;
	else if (strcmp(decimal_sep, ",") == 0)
		group_sep = ".";

	if (*numstr == '-')
	{
		negative = true;
		numstr++;
	}

	/* NaN and Infinity */
	if (!isdigit((unsigned char) *numstr) && *numstr != '.')
	{
		if (negative)
			appendStringInfoChar(format_res, '-');
		appendStringInfoString(format_res, numstr);
		return;
	}

	/* the digits without decimal point, leading and trailing zeros */
	digits = palloc(strlen(numstr) + 2);
	for (p = numstr; *p; p++)
	{
		if (*p == '.')
			break;
		if (ndigits > 0 || *p != '0')
		{
			digits[ndigits++] = *p;
			scale++;
		}
	}
	if (*p == '.')
	{
		for (p++; *p; p++)
		{
			if (ndigits > 0 || *p != '0')
				digits[ndigits++] = *p;
			else
				scale--;
		}
	}
	while (ndigits > 0 && digits[ndigits - 1] == '0')
		ndigits--;
	digits[ndigits] = '\0';
	if (ndigits == 0)
	{
		scale = 0;
		negative = false;
	}

	section = custom_numeric_find_section(format, ndigits == 0 ? 2 : (negative ? 1 : 0));

	for (;;)
	{
		int			thousand_pos = -1;
		int			thousand_count = 0;

		digit_count = 0;
		decimal_pos = -1;
		first_digit = INT_MAX;
		last_digit = 0;
		scale_adjust = 0;
		thousand_seps = false;
		scientific = false;

		src = section;
		while ((ch = format[src]) != '\0' && ch != ';')
		{
			src++;
			switch (ch)
			{
				case '#':
					digit_count++;
					break;
				case '0':
					if (first_digit == INT_MAX)
						first_digit = digit_count;
					digit_count++;
					last_digit = digit_count;
					break;
				case '.':
					if (decimal_pos < 0)
						decimal_pos = digit_count;
					break;
				case ',':
					if (digit_count > 0 && decimal_pos < 0)
					{
						if (thousand_pos >= 0)
						{
							if (thousand_pos == digit_count)
							{
								thousand_count++;
								break;
							}
							thousand_seps = true;
						}
						thousand_pos = digit_count;
						thousand_count = 1;
					}
					break;
				case '%':
					scale_adjust += 2;
					break;
				case '\'':
				case '"':
					while (format[src] != '\0' && format[src++] != ch)
						;
					break;
				case '\\':
					if (format[src] != '\0')
						src++;
					break;
				case 'E':
				case 'e':
					if (format[src] == '0' ||
						((format[src] == '+' || format[src] == '-') && format[src + 1] == '0'))
					{
						while (format[++src] == '0')
							;
						scientific = true;
					}
					break;
				default:
					if (IS_PER_MILLE(&format[src - 1]))
					{
						scale_adjust += 3;
						src += 2;
					}
					break;
			}
		}

		if (decimal_pos < 0)
			decimal_pos = digit_count;

		if (thousand_pos >= 0)
		{
			if (thousand_pos == decimal_pos)
				scale_adjust -= thousand_count * 3;
			else
				thousand_seps = true;
		}

		if (ndigits > 0)
		{
			scale += scale_adjust;
			custom_numeric_round(digits, &scale,
								 scientific ? digit_count : scale + digit_count - decimal_pos);
			ndigits = strlen(digits);

			if (ndigits == 0)
			{
				/* rounded to zero: use the section for zero, if there is one */
				int			zero_section = custom_numeric_find_section(format, 2);

				negative = false;
				if (zero_section != section)
				{
					section = zero_section;
					continue;
				}
			}
		}
		break;
	}

	/* number of digits 0 has to produce before and after the decimal point */
	first_digit = (first_digit < decimal_pos) ? decimal_pos - first_digit : 0;
	last_digit = (last_digit > decimal_pos) ? decimal_pos - last_digit : 0;

	if (scientific)
	{
		dig_pos = decimal_pos;
		adjust = 0;
	}
	else
	{
		dig_pos = (scale > decimal_pos) ? scale : decimal_pos;
		adjust = scale - decimal_pos;
	}

	/* a negative number formatted with the first section gets its sign */
	if (negative && section == 0)
		appendStringInfoChar(format_res, '-');

	cur = digits;
	src = section;
	while ((ch = format[src]) != '\0' && ch != ';')
	{
		src++;

		/* digits the placeholders before the decimal point have no room for */
		if (adjust > 0 && (ch == '#' || ch == '0' || ch == '.'))
		{
			while (adjust > 0)
			{
				appendStringInfoChar(format_res, *cur ? *cur++ : '0');
				if (thousand_seps && dig_pos > 1 && (dig_pos - 1) % 3 == 0)
					appendStringInfoString(format_res, group_sep);
				dig_pos--;
				adjust--;
			}
		}

		switch (ch)
		{
			case '#':
			case '0':
				{
					char		digit;

					if (adjust < 0)
					{
						adjust++;
						digit = (dig_pos <= first_digit) ? '0' : '\0';
					}
					else
						digit = *cur ? *cur++ : ((dig_pos > last_digit) ? '0' : '\0');

					if (digit != '\0')
					{
						appendStringInfoChar(format_res, digit);
						if (thousand_seps && dig_pos > 1 && (dig_pos - 1) % 3 == 0)
							appendStringInfoString(format_res, group_sep);
					}
					dig_pos--;
					break;
				}
			case '.':
				if (dig_pos != 0 || decimal_written)
					break;
				if (last_digit < 0 || (decimal_pos < digit_count && *cur))
				{
					appendStringInfoString(format_res, decimal_sep);
					decimal_written = true;
				}
				break;
			case ',':
				break;
			case '\'':
			case '"':
				while (format[src] != '\0' && format[src] != ch)
					appendStringInfoChar(format_res, format[src++]);
				if (format[src] != '\0')
					src++;
				break;
			case '\\':
				if (format[src] != '\0')
					appendStringInfoChar(format_res, format[src++]);
				break;
			case 'E':
			case 'e':
				if (scientific)
				{
					bool		positive_sign = false;
					int			min_digits = 0;
					int			exponent = (ndigits == 0) ? 0 : scale - decimal_pos;

					if (format[src] == '0')
						min_digits++;
					else if (format[src] == '+' && format[src + 1] == '0')
						positive_sign = true;
					else if (!(format[src] == '-' && format[src + 1] == '0'))
					{
						appendStringInfoChar(format_res, ch);
						break;
					}

					while (format[++src] == '0')
						min_digits++;
					if (min_digits > 10)
						min_digits = 10;

					appendStringInfoChar(format_res, ch);
					if (exponent < 0)
					{
						appendStringInfoChar(format_res, '-');
						exponent = -exponent;
					}
					else if (positive_sign)
						appendStringInfoChar(format_res, '+');
					appendStringInfo(format_res, "%0*d", min_digits, exponent);

					scientific = false;
				}
				else
				{
					appendStringInfoChar(format_res, ch);
					if (format[src] == '+' || format[src] == '-')
						appendStringInfoChar(format_res, format[src++]);
					while (format[src] == '0')
						appendStringInfoChar(format_res, format[src++]);
				}
				break;
			default:
				appendStringInfoChar(format_res, ch);
				break;
		}
	}

	pfree(digits);
}

static void
format_numeric_handler(Datum value, Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string,
					   Oid arg_type_oid, char *culture, char *valid_culture, char *data_type)
{
	char		upper_pattern = toupper(pattern);

	resetStringInfo(format_res);

	switch (upper_pattern)
	{
		case 'C':
			if (set_culture(valid_culture, "LC_MONETARY", culture) == 1)
				format_currency(numeric_val, format_res, upper_pattern, precision_string, culture);
			break;
		case 'D':
			format_decimal(numeric_val, format_res, upper_pattern, precision_string, arg_type_oid);
			break;
		case 'F':
			format_fixed_point(numeric_val, format_res, upper_pattern, precision_string);
			break;
		case 'N':
			format_number(numeric_val, format_res, upper_pattern, precision_string);
			break;
		case 'P':
			format_percent(numeric_val, format_res, upper_pattern, precision_string);
			break;
		case 'X':
			format_hexadecimal(value, format_res, pattern, precision_string, arg_type_oid);
			break;
		case 'E':
			format_exponential(numeric_val, format_res, pattern, precision_string);
			break;
		case 'G':
			format_compact(numeric_val, format_res, pattern, precision_string, data_type, arg_type_oid);
			break;
		case 'R':
			format_roundtrip(value, numeric_val, format_res, pattern, data_type, arg_type_oid);
			break;
		default:
			break;
	}
}


/*
 * Function for setting validated input locales for LC_TIME, LC_NUMERIC, LC_MONETARY
 */
static int
set_culture(char *valid_culture, const char *config_name, const char *culture)
{
	if (valid_culture != NULL && strlen(valid_culture) > 0)
	{
		if (pg_strcasecmp(config_name, "LC_MONETARY") != 0)
		{
			strncat(valid_culture, ".UTF-8", 7);
		}

		set_config_option(config_name, valid_culture,
						  PGC_USERSET, PGC_S_SESSION,
						  GUC_ACTION_LOCAL, true, 0, false);
	}
	else
	{
		return 0;
	}
	return 1;
}

/*
 * format the given input locale to supported locale format and set it accordingly
 */
static char *
format_validate_and_culture(const char *culture, const char *config_name)
{
	int			culture_len = 0;
	char	   *token;
	char	   *temp_res;
	int			locale_pos = -1;
	char	   *culture_temp;

	if (culture != NULL)
		culture_len = strlen(culture);

	if (culture_len > 0)
	{
		culture_temp = palloc(sizeof(char) * culture_len + 1);
		memcpy(culture_temp, culture, culture_len);
		culture_temp[culture_len] = '\0';

		temp_res = palloc0(sizeof(char) * culture_len + 10);

		if (strchr(culture_temp, '-') != NULL)
		{
			token = strtok(culture_temp, "-");
			for (char *c = token; *c; ++c)
				*c = tolower(*c);
			memcpy(temp_res, token, strlen(token));
			strncat(temp_res, "_", 2);

			if (token != NULL)
			{
				token = strtok(NULL, "-");
				for (char *c = token; *c; ++c)
					*c = toupper(*c);
				strncat(temp_res, token, culture_len);
				temp_res[culture_len] = '\0';
			}
			else
			{
				pfree(temp_res);
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("The culture parameter \"%s\" provided in the function call is not supported.", culture),
						 errhint("Invalid/Unsupported culture value.")));;
			}
		}
		else
		{
			pfree(temp_res);
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg("The culture parameter \"%s\" provided in the function call is not supported.", culture),
					 errhint("Invalid/Unsupported culture value.")));;
		}

		pfree(culture_temp);

		locale_pos = tsql_find_locale((const char *) temp_res);

		if (locale_pos >= 0 && set_culture(temp_res, config_name, culture) == 1)
		{
			return temp_res;
		}

		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("The culture parameter \"%s\" provided in the function call is not supported.", culture),
				 errhint("Invalid/Unsupported culture value.")));;
	}
	else
	{
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("The culture parameter \"%s\" provided in the function call is not supported.", culture),
				 errhint("Invalid/Unsupported culture value.")));;
	}
}

/*
 * Compile and match a regular expression pattern to a const string
 */
static int
match(const char *string, const char *pattern)
{
	int			status;
	text	   *regex = cstring_to_text(pattern);

	status = RE_compile_and_execute(regex, (char *) string, strlen(string), REG_ADVANCED, DEFAULT_COLLATION_OID, 0, NULL);

	pfree(regex);
	return status;
}

/*
 * Base function for getting the standard format mask for date and time data types
 * Returns  0 if the format is invalid
 * Returns -1 if the format is not supported
 * Returns -2 if the culture couldn't be found to get the format
 */
static int
format_datetimeformats(StringInfo buf, const char *format_pattern, const char *culture, const char *data_type, const char *data_val)
{
	int			j = 0;
	int			flag = 0;
	char	   *pattern;
	int			milli_time_res;
	int			time_res;
	const char *milli_time_re = "^[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}.[0-9]{1,7}$";
	const char *time_re = "^[0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}$";

	if (pg_strcasecmp(format_pattern, "O") == 0)
	{
		return -1;
	}

	if (strcmp(data_type, "time") == 0)
	{
		milli_time_res = match(data_val, milli_time_re);
		time_res = match(data_val, time_re);

		switch (format_pattern[0])
		{
			case 'c':
			case 't':
			case 'T':
				if (milli_time_res == 1)
				{
					appendStringInfoString(buf, "HH24\":\"MI\":\"ss\".\"FF6");
				}
				else if (time_res == 1)
				{
					appendStringInfoString(buf, "HH24\":\"MI\":\"ss");
				}
				else
				{
					return 0;
				}
				break;
			case 'g':
				if (milli_time_res == 1)
				{
					return -1;
				}
				else if (time_res == 1)
				{
					appendStringInfoString(buf, "HH24\":\"MI\":\"ss");
				}
				else
				{
					return 0;
				}
				break;
			case 'G':
				appendStringInfoString(buf, "HH24\":\"MI\":\"ss\".\"FF6");
				break;
			default:
				return 0;
				break;
		}
		return 1;
	}
	else
	{
		for (j = 0; j < CULTURE_COUNT && flag == 0; j++)
		{
			if (pg_strcasecmp(datetimeformats[j].sql_culture, culture) == 0)
			{
				flag = 1;
				switch (format_pattern[0])
				{
					case 'd':
						pattern = datetimeformats[j].pg_shortdatepattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'D':
						pattern = datetimeformats[j].pg_longdatepattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'f':
						pattern = datetimeformats[j].pg_longdatepattern;
						appendStringInfoString(buf, pattern);
						appendStringInfoString(buf, " ");
						appendStringInfoString(buf, datetimeformats[j].pg_shorttimepattern);
						break;
					case 'F':
						pattern = datetimeformats[j].pg_fulldatetimepattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'g':
						pattern = datetimeformats[j].pg_shortdatepattern;
						appendStringInfoString(buf, pattern);
						appendStringInfoString(buf, " ");
						appendStringInfoString(buf, datetimeformats[j].pg_shorttimepattern);
						break;
					case '\0':
					case 'G':
						pattern = datetimeformats[j].pg_shortdatepattern;
						appendStringInfoString(buf, pattern);
						appendStringInfoString(buf, " ");
						appendStringInfoString(buf, datetimeformats[j].pg_longtimepattern);
						break;
					case 't':
						pattern = datetimeformats[j].pg_shorttimepattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'T':
						pattern = datetimeformats[j].pg_longtimepattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'm':
					case 'M':
						pattern = datetimeformats[j].pg_monthdaypattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'y':
					case 'Y':
						pattern = datetimeformats[j].pg_yearmonthpattern;
						appendStringInfoString(buf, pattern);
						break;
					case 'r':
					case 'R':
						pattern = "Dy, dd Mon yyyy HH24\":\"MI\":\"ss \"GMT\"";
						appendStringInfoString(buf, pattern);
						break;
					case 's':
						pattern = "yyyy\"-\"MM\"-\"dd\"T\"HH24\":\"MI\":\"ss";
						appendStringInfoString(buf, pattern);
						break;
					case 'u':
						pattern = "yyyy\"-\"MM\"-\"dd HH24\":\"MI\":\"ss\"Z\"";
						appendStringInfoString(buf, pattern);
						break;
					case 'U':
						pattern = datetimeformats[j].pg_fulldatetimepattern;
						appendStringInfoString(buf, pattern);
						break;
					default:
						return 0;
						break;
				}
			}
		}
		if (flag == 0)
		{
			return -2;
		}
	}
	return 1;
}

/*
 * Base function for converting T-SQL format patterns to PostgreSQL understandable format
 * Returns 0 if the format is invalid
 * Parsing the custom format string by checking for quotes, percentile and escape character
 * Examples:
 * 1. For "ddd" it should be shown exactly as it is in the result, so we are parsing it to "d""d""d"
 * to be shown exactly as ddd in the formatted result
 * 2. %ddd  for this, %d and dd should be taken as a separate format specifiers where %d represents
 * day of the month and dd represents day of the month padded with zero if it's a single digit day,
 * and result should be 808 (taking the day is 8), so we are replacing d with postgres understandable format FMdd
 * 3. \d The character after the escape character should be shown as it is in the result string,
 * so we are parsing it to "d"
 * More information on the postgres understantable formats can be found at
 * https://www.postgresql.org/docs/current/functions-formatting.html
 */
static int
process_format_pattern(StringInfo buf, const char *msg_string, const char *data_type)
{
	int			i = 0;
	int			bc = 0;
	int			quotes_found = 0;
	int			percentile_found = 0;
	int			escape_found = 0;
	int			is_time = 0;
	int			count = 0;

	StringInfo	str = makeStringInfo();

	if (msg_string == NULL)
	{
		return 0;
	}

	if (strcmp(data_type, "time") == 0)
	{
		is_time = 1;
	}

	for (bc = 0; bc < strlen(msg_string); bc++)
	{
		if (msg_string[bc] == '\"')
		{
			if (!escape_found)
			{
				quotes_found = !quotes_found;
			}
			else
			{
				escape_found = 0;
				appendStringInfoChar(str, '\\');
			}

			appendStringInfoChar(str, msg_string[bc]);
		}
		else
		{
			if (quotes_found == 0)
			{
				if (msg_string[bc] == '\\')
				{
					if (escape_found == 0)
					{
						escape_found = 1;
					}
					else
					{
						escape_found = 0;
						appendStringInfoChar(str, msg_string[bc]);
					}
				}
				else if (msg_string[bc] == '%')
				{
					if (escape_found == 0)
					{
						percentile_found = 1;
					}
					else
					{
						escape_found = 0;
						percentile_found = 0;
						appendStringInfoChar(str, msg_string[bc]);
					}
				}
				else if (msg_string[bc] == 'd')
				{
					if (escape_found)
					{
						escape_found = 0;

						appendStringInfo(str, "\"d\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'd')
					{
						percentile_found = 0;

						if (is_time == 1)
						{
							appendStringInfoChar(str, '0');
						}
						else
						{
							appendStringInfo(str, "FMdd");
						}
					}
					else
					{
						if (msg_string[bc + 2] == 'd')
						{
							if (msg_string[bc + 3] == 'd')
							{
								if (is_time == 1)
								{
									appendStringInfo(str, "0000");
								}
								else
								{
									appendStringInfo(str, "TMDay");
								}

								count = 4;
								i = bc + 4;
								bc = bc + 3;

								while (msg_string[i] == 'd')
								{
									if (is_time == 1)
									{
										if (count > 8)
										{
											return 0;
										}
										else
										{
											appendStringInfoChar(str, '0');
										}
									}
									i++;
									bc++;
									count++;
								}
							}
							else
							{
								if (is_time == 1)
								{
									appendStringInfo(str, "000");
								}
								else
								{
									appendStringInfo(str, "TMDy");
								}
								bc = bc + 2;
							}
						}
						else
						{
							if (is_time == 1)
							{
								appendStringInfo(str, "00");
							}
							else
							{
								appendStringInfo(str, "dd");
							}
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'M')
				{
					if (is_time == 1)
						return 0;

					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"M\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'M')
					{
						percentile_found = 0;
						appendStringInfo(str, "FMMM");
					}
					else
					{
						if (msg_string[bc + 2] == 'M')
						{
							if (msg_string[bc + 3] == 'M')
							{
								appendStringInfo(str, "TMMonth");
								i = bc + 4;
								bc = bc + 3;

								while (msg_string[i] == 'M')
								{
									i++;
									bc++;
								}
							}
							else
							{
								appendStringInfo(str, "TMMon");
								bc = bc + 2;
							}
						}
						else
						{
							appendStringInfo(str, "MM");
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'h')
				{
					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"h\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'h')
					{
						percentile_found = 0;

						if (is_time == 1)
						{
							appendStringInfo(str, "FMHH24");
						}
						else
						{
							appendStringInfo(str, "FMhh12");
						}
					}
					else
					{
						if (is_time == 1)
						{
							appendStringInfo(str, "HH24");
						}
						else
						{
							appendStringInfo(str, "hh12");
						}

						if (msg_string[bc + 2] == 'h' && is_time == 1)
						{
							return 0;
						}

						i = bc + 2;
						bc = bc + 1;

						while (msg_string[i] == 'h')
						{
							i++;
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'H')
				{

					if (is_time == 1)
						return 0;

					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"H\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'H')
					{
						percentile_found = 0;
						appendStringInfo(str, "FMHH24");
					}
					else
					{
						appendStringInfo(str, "HH24");

						i = bc + 2;
						bc = bc + 1;

						while (msg_string[i] == 'H')
						{
							i++;
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'm')
				{
					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"m\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'm')
					{
						percentile_found = 0;
						appendStringInfo(str, "FMMI");
					}
					else
					{
						appendStringInfo(str, "MI");

						if (msg_string[bc + 2] == 'm' && is_time == 1)
							return 0;

						i = bc + 2;
						bc = bc + 1;

						while (msg_string[i] == 'm')
						{
							i++;
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 's')
				{
					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"s\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 's')
					{
						percentile_found = 0;
						appendStringInfo(str, "FMss");
					}
					else
					{
						appendStringInfo(str, "ss");

						if (msg_string[bc + 2] == 's' && is_time == 1)
							return 0;

						i = bc + 2;
						bc = bc + 1;

						while (msg_string[i] == 's')
						{
							i++;
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'y')
				{

					if (is_time == 1)
						return 0;

					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"y\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'y')
					{
						percentile_found = 0;
						appendStringInfo(str, "FMyy");
					}
					else
					{
						if (msg_string[bc + 2] == 'y')
						{
							if (msg_string[bc + 3] == 'y')
							{
								if (msg_string[bc + 4] == 'y')
								{
									appendStringInfo(str, "FM0yyyy");
									i = bc + 5;
									bc = bc + 4;

									while (msg_string[i] == 'y')
									{
										i++;
										bc++;
									}
								}
								else
								{
									appendStringInfo(str, "yyyy");
									bc = bc + 3;
								}
							}
							else
							{
								appendStringInfo(str, "yyy");
								bc = bc + 2;
							}
						}
						else
						{
							appendStringInfo(str, "yy");
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'g')
				{
					if (is_time == 1)
						return 0;

					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"g\"");
					}
					else if (percentile_found)
					{
						percentile_found = 0;
						appendStringInfo(str, "B.C.");
					}
					else
					{
						appendStringInfo(str, "B.C.");
						i = bc + 2;
						bc = bc + 1;

						while (msg_string[i] == 'g')
						{
							i++;
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 'f')
				{
					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"f\"");
					}
					else if (percentile_found || msg_string[bc + 1] != 'f')
					{
						percentile_found = 0;
						appendStringInfo(str, "FF1");
					}
					else
					{
						if (msg_string[bc + 2] == 'f')
						{
							if (msg_string[bc + 3] == 'f')
							{
								if (msg_string[bc + 4] == 'f')
								{
									if (msg_string[bc + 5] == 'f')
									{
										appendStringInfo(str, "FF6");
										count = 6;
										i = bc + 6;
										bc = bc + 5;

										while (msg_string[i] == 'f')
										{
											if (is_time == 1 && count > 7)
											{
												return 0;
											}
											i++;
											bc++;
											count++;
										}
									}
									else
									{
										appendStringInfo(str, "FF5");
										bc = bc + 4;
									}
								}
								else
								{
									appendStringInfo(str, "FF4");
									bc = bc + 3;
								}
							}
							else
							{
								appendStringInfo(str, "FF3");
								bc = bc + 2;
							}
						}
						else
						{
							appendStringInfo(str, "FF2");
							bc++;
						}
					}
				}
				else if (msg_string[bc] == 't')
				{
					if (is_time == 1)
						return 0;

					if (escape_found)
					{
						escape_found = 0;
						appendStringInfo(str, "\"t\"");
					}
					else if (percentile_found)
					{
						percentile_found = 0;
						appendStringInfo(str, "AM");
					}
					else
					{
						/*
						 * Case for one letter meridian - A, P instead of
						 * AM/PM
						 */
						/* is not supported by to_char in postgres, so we'll */
						/*
						 * return the 2 letter case until an efficient
						 * workaround
						 */
						appendStringInfo(str, "AM");
						i = bc + 1;

						/* Anything longer than 'tt' is skipped. */
						while (msg_string[i] == 't')
						{
							i++;
							bc++;
						}
					}
				}
				else
				{
					if (is_time == 1)
					{
						if (msg_string[bc] == '.' || msg_string[bc] == ':')
						{
							if (escape_found == 0)
								return 0;
							else
							{
								escape_found = 0;
								appendStringInfo(str, "\"%c\"", msg_string[bc]);
							}
						}
						else
						{
							return 0;
						}
					}
					else
					{
						if (escape_found)
							escape_found = 0;

						if (percentile_found)
							percentile_found = 0;

						appendStringInfo(str, "\"%c\"", msg_string[bc]);
					}
				}
			}
			else if (quotes_found == 1)
			{
				appendStringInfoChar(str, msg_string[bc]);
			}
		}
	}

	resetStringInfo(buf);
	appendStringInfoString(buf, str->data);

	return 1;
}

/*
 *	Converting the date, time values to char
 */
static void
data_to_char(Datum data, Oid data_type, StringInfo buf)
{
	char	   *result;

	switch (data_type)
	{
		case TIMEOID:
			result = TextDatumGetCString(DirectFunctionCall2Coll(interval_to_char, C_COLLATION_OID, data,
																 PointerGetDatum(cstring_to_text((const char *) buf->data))));

			break;
		case TIMESTAMPOID:
			result = TextDatumGetCString(DirectFunctionCall2Coll(timestamp_to_char, C_COLLATION_OID, data,
																 PointerGetDatum(cstring_to_text((const char *) buf->data))));

			break;
		default:
			break;
	}

	resetStringInfo(buf);
	appendStringInfoString(buf, result);
}

/*
 * Base function for getting the culture-wise standard format mask for Currency formatting
 */
static char *
get_currency_sign_format(const char *culture, int positive)
{
	for (int j = 0; j < CULTURE_COUNT; j++)
	{
		if (pg_strcasecmp(currencyformats[j].sql_culture, culture) == 0)
		{
			if (positive)
			{
				return currencyformats[j].positive_pattern;
			}
			else
			{
				return currencyformats[j].negative_pattern;
			}
		}
	}
	return "";
}

/*
 * Get the scale/decimal digits for "Currency" format specifier.
 * Returns 2 as default
 */
static int
get_currency_decimal_digits(const char *culture)
{
	for (int j = 0; j < CULTURE_COUNT; j++)
	{
		if (pg_strcasecmp(currencyformats[j].sql_culture, culture) == 0)
		{
			return currencyformats[j].decimal_digits;
		}
	}
	return 2;
}

/*
 * Get the scale/decimal digits for "General" format specifier.
 * Returns 7 as default
 */
static int
get_compact_decimal_digits(const char *data_type)
{
	if (strcasecmp(data_type, "smallint") == 0)
	{
		return 5;
	}
	else if (strcasecmp(data_type, "integer") == 0)
	{
		return 10;
	}
	else if (strcasecmp(data_type, "bigint") == 0)
	{
		return 19;
	}
	else if (strcasecmp(data_type, "numeric") == 0)
	{
		return 29;
	}
	else if (strcasecmp(data_type, "real") == 0)
	{
		return 7;
	}
	else if (strcasecmp(data_type, "float") == 0)
	{
		return 15;
	}
	/* default precision */
	return 7;
}

/*
 * Get the sign for the input numeric
 * returns -1 if the input is less than 0,
 * 0 if the input is equal to 0,
 * and 1 if the input is greater than zero.
 */
static int
get_numeric_sign(Numeric num)
{
	Numeric		sign = DatumGetNumeric(DirectFunctionCall1(numeric_sign,
														   NumericGetDatum(num)));

	return DatumGetInt32(DirectFunctionCall1(numeric_int4,
											 NumericGetDatum(sign)));
}

/*
 * Removes the trailing zeroes and reduces the scale of the input numeric
 */
static Numeric
trim_scale_numeric(Numeric num)
{
	return DatumGetNumeric(DirectFunctionCall1(numeric_trim_scale,
											   NumericGetDatum(num)));
}

/*
 * Outputs cstring for the input numeric
 */
static char *
numeric_text(Numeric num)
{
	return DatumGetCString(DirectFunctionCall1(numeric_out,
											   NumericGetDatum(num)));
}

/*
 * Returns the absolute value of the input numeric
 */
static Numeric
get_numeric_abs(Numeric num)
{
	return DatumGetNumeric(DirectFunctionCall1(numeric_abs,
											   NumericGetDatum(num)));
}

/*
 * Returns the string length of the input numeric
 */
static Datum
get_numeric_digit_count(Numeric num)
{
	return strlen(numeric_text(num));
}

/*
 * Returns the scale/number of decimal digits of the input numeric
 */
static int
get_numeric_scale(Numeric num)
{
	return DatumGetInt32(DirectFunctionCall1(numeric_scale,
											 NumericGetDatum(num)));
}

/*
 * Returns the integral digits of the input numeric
 */
static int
get_integral_digits(int total_digits, int scale)
{
	if (scale > 0)
	{
		return total_digits - scale - 1;
	}
	else
	{
		return total_digits;
	}
}

/*
 * Rounds the numeric to given scale
 */
static Numeric
round_num(Numeric num, int scale)
{
	return DatumGetNumeric(DirectFunctionCall2(numeric_round,
											   NumericGetDatum(num),
											   Int32GetDatum(scale)));
}

/*
 * Multiply numeric value by 100
 */
static Numeric
multiply_numeric_by_100(Numeric num1)
{
	return DatumGetNumeric(DirectFunctionCall2(numeric_mul,
											   NumericGetDatum(num1),
											   DirectFunctionCall1(int2_numeric, 100)));
}

/*
 * Repeat the given string "val" for "count" number of times
 */
static char *
repeat_string(char *val, int count)
{
	return TextDatumGetCString(DirectFunctionCall2(repeat,
												   CStringGetTextDatum(val),
												   Int32GetDatum(count)));
}

/*
 * Set the format pattern for currency formatting by replacing the skeleton 'n' by the generated currency format mask
 */
static void
replace_currency_format(char *currency_format_mask, StringInfo format_res)
{

	const char *fmt = (const char *) format_res->data;
	char	   *result;

	result = TextDatumGetCString(DirectFunctionCall3Coll(replace_text,
														 C_COLLATION_OID,
														 CStringGetTextDatum(currency_format_mask),
														 CStringGetTextDatum("n"),
														 CStringGetTextDatum(fmt)));

	resetStringInfo(format_res);
	appendStringInfoString(format_res, result);
}

/*
 * Left padding the input string with "count" number of "0" literals
 */
static char *
zero_left_padding(char *num_string, int count)
{
	return TextDatumGetCString(DirectFunctionCall3(lpad,
												   CStringGetTextDatum(num_string),
												   Int32GetDatum(count),
												   CStringGetTextDatum("0")));
}

/*
 * Outputs numeric from the input cstring
 */
static Numeric
cstring_to_numeric(char *val_string)
{
	return DatumGetNumeric(DirectFunctionCall3(numeric_in, CStringGetDatum(val_string), 0, -1));
}

/*
 * Set the result for formatting float4 to char
 */
static void
float4_data_to_char(StringInfo format_res, Datum num)
{

	const char *fmt = (const char *) format_res->data;
	char	   *result;

	result = TextDatumGetCString(DirectFunctionCall2(float4_to_char, num,
													 CStringGetTextDatum(fmt)));

	resetStringInfo(format_res);
	appendStringInfoString(format_res, result);
}

/*
 * Set the result for formatting float8 to char
 */
static void
float8_data_to_char(StringInfo format_res, Datum num)
{

	const char *fmt = (const char *) format_res->data;
	char	   *result;

	result = TextDatumGetCString(DirectFunctionCall2(float8_to_char,
													 num,
													 CStringGetTextDatum(fmt)));

	resetStringInfo(format_res);
	appendStringInfoString(format_res, result);
}

/*
 * Replace the string matched by regular expression "match_with"
 * with "replace_with" and set it to the format result
 */
static void
regexp_replace(char *format_res, char *match_with, const char *replace_with, char *flag)
{
	text	   *s = cstring_to_text(format_res);
	text	   *p = cstring_to_text(match_with);
	text	   *r = cstring_to_text(replace_with);
	char	   *result;

	result = text_to_cstring(replace_text_regexp(s, p, r, REG_ADVANCED, C_COLLATION_OID, 0, 1));

	strncpy(format_res, result, strlen(format_res));
}

/*
 * Generates a format with group separators
 */
static void
get_group_separator(StringInfo format_res, int integral_digits, int decimal_digits)
{
	int			group;
	char	   *temp;

	resetStringInfo(format_res);

	if (integral_digits > 3)
	{
		if (integral_digits % 3 == 0)
		{
			appendStringInfoString(format_res, "FM999");
			group = (integral_digits / 3) - 1;
		}
		else if (integral_digits % 3 == 2)
		{
			appendStringInfoString(format_res, "FM99");
			group = integral_digits / 3;
		}
		else
		{
			appendStringInfoString(format_res, "FM9");
			group = integral_digits / 3;
		}
		temp = repeat_string("G999", group);
		appendStringInfoString(format_res, temp);
	}
	else
	{
		appendStringInfoString(format_res, "FM");
		temp = repeat_string("0", integral_digits);
		appendStringInfoString(format_res, temp);
	}

	if (decimal_digits > 0)
	{
		appendStringInfoChar(format_res, 'D');
		temp = repeat_string("0", decimal_digits);
		appendStringInfoString(format_res, temp);
	}
}

/*
 * Convert numeric type to string.
 */
static void
numeric_to_string(StringInfo format_res, Numeric num)
{
	const char *fmt = (const char *) format_res->data;
	char	   *result;

	/*
	 * This essentially is just a wrapper to allow us to call C
	 * implementations of PG functions directly - in this case,
	 * numeric_to_char()
	 */
	result = TextDatumGetCString(DirectFunctionCall2(numeric_to_char,
													 NumericGetDatum(num),
													 CStringGetTextDatum(fmt)));

	resetStringInfo(format_res);
	appendStringInfoString(format_res, result);
}

/*
 * Generates an exponential format with given precision
 */
static void
get_exponential_format(StringInfo format_res, int precision)
{
	char	   *temp;

	resetStringInfo(format_res);

	if (precision > 0)
	{
		appendStringInfoString(format_res, "9D");
		temp = repeat_string("9", precision);
		appendStringInfoString(format_res, temp);
	}
	else
	{
		appendStringInfoChar(format_res, '9');
	}

	appendStringInfoString(format_res, "EEEE");
}

/*
 * Returns the format precisions for different specifiers
 */
static int
get_precision(char pattern, char *precision_string, char *data_type, int integral_digits, char *culture)
{
	int			precision;

	if (pattern == 'R')
	{
		if (pg_strcasecmp(data_type, "real") == 0)
		{
			precision = 9 - integral_digits;
			if (precision <= 0)
				precision = 9;
		}
		else
		{
			precision = -1;
		}

		return precision;
	}
	else if (strlen(precision_string) == 0)
	{

		switch (pattern)
		{
			case 'C':
				precision = get_currency_decimal_digits(culture);
				break;
			case 'F':
			case 'N':
			case 'P':
				precision = 2;
				break;
			case 'E':
				precision = 6;
				break;
			case 'D':
				precision = integral_digits;
				break;
			case 'G':
				precision = get_compact_decimal_digits(data_type);
				break;
			default:
				precision = -1;
				break;
		}
		return precision;
	}
	else
	{
		precision = atoi(precision_string);

		if (pattern == 'D' && (precision == 0 || precision < integral_digits))
		{
			precision = integral_digits;
		}
		else if (pattern == 'G' && precision == 0)
		{
			precision = get_compact_decimal_digits(data_type);
		}

		return precision;
	}
}

/*
 * Formatting with Currency format specifier
 */
static void
format_currency(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string, char *culture)
{

	Numeric		numeric_abs_val;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			positive = 0;
	char	   *currency_format;
	int			precision = get_precision(pattern, precision_string, "", 0, culture);

	numeric_val = round_num(numeric_val, precision);
	numeric_abs_val = get_numeric_abs(numeric_val);
	scale = get_numeric_scale(numeric_abs_val);
	total_digits = get_numeric_digit_count(numeric_abs_val);
	integral_digits = get_integral_digits(total_digits, scale);

	if (get_numeric_sign(numeric_val) >= 0)
	{
		positive = 1;
	}

	get_group_separator(format_res, integral_digits, scale);

	/* Get the currency format for the culture and sign */
	currency_format = get_currency_sign_format(culture, positive);

	/* Change the current format by replacing "n" with group separator format */
	replace_currency_format(currency_format, format_res);

	numeric_to_string(format_res, numeric_abs_val);
}

/*
 * Formatting with Decimal format specifier
 */
static void
format_decimal(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string, Oid arg_type_oid)
{

	Numeric		numeric_abs_val;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			num_sign;
	char	   *padding_format;
	int			precision;

	switch (arg_type_oid)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
			numeric_abs_val = get_numeric_abs(numeric_val);
			scale = get_numeric_scale(numeric_abs_val);
			total_digits = get_numeric_digit_count(numeric_abs_val);
			integral_digits = get_integral_digits(total_digits, scale);
			num_sign = get_numeric_sign(numeric_val);

			precision = get_precision(pattern, precision_string, "", integral_digits, "");

			padding_format = zero_left_padding(numeric_text(numeric_abs_val), precision);

			resetStringInfo(format_res);
			if (num_sign < 0)
			{
				appendStringInfoChar(format_res, '-');
			}
			appendStringInfoString(format_res, padding_format);
			break;
		default:
			break;
	}
}

/*
 * Formatting with Fixed-point format specifier
 */
static void
format_fixed_point(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string)
{

	Numeric		numeric_abs_val;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			precision = get_precision(pattern, precision_string, "", 0, "");
	char	   *temp;

	numeric_val = round_num(numeric_val, precision);
	numeric_abs_val = get_numeric_abs(numeric_val);
	scale = precision;
	total_digits = get_numeric_digit_count(numeric_abs_val);
	integral_digits = get_integral_digits(total_digits, scale);

	resetStringInfo(format_res);
	appendStringInfoString(format_res, "FM");
	temp = repeat_string("0", integral_digits);
	appendStringInfoString(format_res, temp);

	if (scale > 0)
	{
		appendStringInfoChar(format_res, 'D');
		temp = repeat_string("0", precision);
		appendStringInfoString(format_res, temp);
	}

	numeric_to_string(format_res, numeric_val);
}

/*
 * Formatting with Number format specifier
 */
static void
format_number(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string)
{
	Numeric		numeric_abs_val;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			precision = get_precision(pattern, precision_string, "", 0, "");

	numeric_val = round_num(numeric_val, precision);

	numeric_abs_val = get_numeric_abs(numeric_val);
	scale = get_numeric_scale(numeric_abs_val);
	total_digits = get_numeric_digit_count(numeric_abs_val);
	integral_digits = get_integral_digits(total_digits, scale);

	get_group_separator(format_res, integral_digits, scale);
	numeric_to_string(format_res, numeric_val);
}

/*
 * Formatting with Percent format specifier
 */
static void
format_percent(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string)
{
	Numeric		numeric_abs_val;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			precision = get_precision(pattern, precision_string, "", 0, "");

	numeric_val = round_num(multiply_numeric_by_100(numeric_val), precision);

	numeric_abs_val = get_numeric_abs(numeric_val);
	scale = precision;
	total_digits = get_numeric_digit_count(numeric_abs_val);
	integral_digits = get_integral_digits(total_digits, scale);

	get_group_separator(format_res, integral_digits, scale);
	appendStringInfoString(format_res, " \"%\"");
	numeric_to_string(format_res, numeric_val);
}

/*
 * Formatting with Hexadecimal format specifier
 */
static void
format_hexadecimal(Datum value, StringInfo format_res, char pattern, char *precision_string, Oid arg_type_oid)
{

	char	   *hexadecimal_pattern;
	int			precision;
	int			len;

	switch (arg_type_oid)
	{
		case INT2OID:
		case INT4OID:
			hexadecimal_pattern = TextDatumGetCString(DirectFunctionCall1(to_hex32, value));
			break;
		case INT8OID:
			hexadecimal_pattern = TextDatumGetCString(DirectFunctionCall1(to_hex64, value));
			break;
		default:
			hexadecimal_pattern = "";
			break;
	}

	len = strlen(hexadecimal_pattern);
	resetStringInfo(format_res);

	if (len > 0)
	{
		if (strlen(precision_string) == 0)
		{
			precision = len;
		}
		else
		{
			precision = atoi(precision_string);
			precision = Max(len, precision);
		}
		hexadecimal_pattern = zero_left_padding(hexadecimal_pattern, precision);
		appendStringInfoString(format_res, hexadecimal_pattern);

		if (isupper(pattern))
		{
			for (char *c = format_res->data; *c; ++c)
				*c = toupper(*c);
		}
	}
}

/*
 * Formatting with Exponential format specifier
 */
static void
format_exponential(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string)
{

	int			len;
	int			temp;
	char	   *buf;
	int			precision = get_precision(toupper(pattern), precision_string, "", 0, "");

	get_exponential_format(format_res, precision);
	numeric_to_string(format_res, numeric_val);

	buf = palloc(sizeof(char) * (format_res->len + 3));
	memset(buf, 0, format_res->len + 3);
	strncpy(buf, format_res->data, format_res->len);

	if (isupper(pattern))
	{
		for (char *c = buf; *c; ++c)
			*c = toupper(*c);
	}
	len = format_res->len;

	/* The last 4 characters are EEEE, appended in numeric_to_string */
	if (len >= 5 && buf[len - 5] != 'E' && buf[len - 5] != 'e')
	{
		temp = len - 2;
		/* Copy the last 3 characters over one. */
		for (; len >= temp; len--)
		{
			buf[len + 1] = buf[len];
		}
		buf[temp] = '0';
		buf[temp + 3] = '\0';
	}

	resetStringInfo(format_res);
	appendStringInfoString(format_res, buf);
	pfree(buf);
}

/*
 * Formatting with General format specifier to get compact of fixed point or scientific notation
 */
static void
format_compact(Numeric numeric_val, StringInfo format_res, char pattern, char *precision_string, char *data_type, Oid arg_type_oid)
{
	Numeric		numeric_abs_val;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			precision;
	char	   *temp;

	numeric_abs_val = get_numeric_abs(numeric_val);
	scale = get_numeric_scale(numeric_abs_val);
	total_digits = get_numeric_digit_count(numeric_abs_val);
	integral_digits = get_integral_digits(total_digits, scale);

	precision = get_precision(toupper(pattern), precision_string, data_type, 0, "");

	if (precision >= integral_digits)
	{
		numeric_val = trim_scale_numeric(round_num(numeric_val, precision - integral_digits));

		numeric_abs_val = get_numeric_abs(numeric_val);
		scale = get_numeric_scale(numeric_abs_val);
		total_digits = get_numeric_digit_count(numeric_abs_val);
		integral_digits = get_integral_digits(total_digits, scale);

		resetStringInfo(format_res);
		appendStringInfoString(format_res, "FM");
		temp = repeat_string("0", integral_digits);
		appendStringInfoString(format_res, temp);
		appendStringInfoChar(format_res, 'D');
		temp = repeat_string("0", scale);
		appendStringInfoString(format_res, temp);

		numeric_to_string(format_res, numeric_val);
	}
	else
	{
		get_exponential_format(format_res, precision - 1);
		numeric_to_string(format_res, numeric_val);

		if (isupper(pattern))
		{
			regexp_replace(format_res->data, "[.]{0,1}0*[eE]", "E", "i");
		}
	}
}

/*
 * Formatting with Round-trip format specifier
 */
static void
format_roundtrip(Datum value, Numeric numeric_val, StringInfo format_res, char pattern, char *data_type, Oid arg_type_oid)
{
	char	   *temp;
	int			scale;
	int			total_digits;
	int			integral_digits;
	int			precision;
	Numeric		numeric_abs_val;

	switch (arg_type_oid)
	{
		case FLOAT4OID:
			numeric_abs_val = get_numeric_abs(numeric_val);
			scale = get_numeric_scale(numeric_abs_val);
			total_digits = get_numeric_digit_count(numeric_abs_val);
			integral_digits = get_integral_digits(total_digits, scale);

			precision = get_precision(toupper(pattern), "", data_type, integral_digits, "");

			if ((arg_type_oid == FLOAT4OID) && (scale > 0 || integral_digits <= 6))
			{
				if ((integral_digits + scale) > 6)
				{
					appendStringInfoString(format_res, "9D99999999EEEE");
				}
				else
				{
					appendStringInfoString(format_res, "9D999999EEEE");
				}

				float4_data_to_char(format_res, value);
				numeric_val = cstring_to_numeric(format_res->data);
				numeric_val = trim_scale_numeric(round_num(numeric_val, precision));

				numeric_abs_val = get_numeric_abs(numeric_val);
				scale = get_numeric_scale(numeric_abs_val);
				total_digits = get_numeric_digit_count(numeric_abs_val);
				integral_digits = get_integral_digits(total_digits, scale);

				appendStringInfoString(format_res, "FM");
				temp = repeat_string("0", integral_digits);
				appendStringInfoString(format_res, temp);
				appendStringInfoChar(format_res, 'D');
				temp = repeat_string("0", scale);
				appendStringInfoString(format_res, temp);

				numeric_to_string(format_res, numeric_val);
			}
			else
			{
				get_exponential_format(format_res, precision - 1);
				float4_data_to_char(format_res, value);

				if (isupper(pattern))
				{
					regexp_replace(format_res->data, "[.]{0,1}0*[eE]", "E", "i");
				}
			}
			break;
		default:
			break;
	}
}
