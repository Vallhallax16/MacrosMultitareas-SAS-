/* ------------------------------------------------------------------ *
 * Bundle: t002_dictionary_columnindex
 * Source: MacroExcelPorIndices.sas
 *         (%EFECTUAR_CONTEOS + %CALCULAR_VARIABLES, verbatim)
 *
 * These two macros read DICTIONARY.COLUMNS to (1) count how many columns
 * of a given TYPE a table has, and (2) build a single delimited string of
 * those column names, each wrapped as a SAS name literal ('name'n). Both
 * macros are copied unchanged from the repo. The added code is a small
 * caller: it builds a sample WORK table and invokes both macros over its
 * CHAR columns, then PUTs the results.
 * ------------------------------------------------------------------ */

%MACRO EFECTUAR_CONTEOS(LibreriaOrigen 	= /*Donde se aloja la tabla*/,
							TablaOrigen = /*Donde se contaran las columnas*/,
							TipoDato	= /*Tipo de dato a leer, CHAR o NUM*/,
							Variable	= /*Donde se guardara el conteo*/);
	PROC SQL NOPRINT;
	SELECT
		COUNT(*)
	INTO
		:&Variable trimmed
	FROM
		DICTIONARY.COLUMNS T
	WHERE
		T.LIBNAME 		EQ "&LibreriaOrigen"		AND
		T.MEMNAME		EQ "&TablaOrigen"			AND
		UPPER(TYPE)		EQ UPPER("&TipoDato");
	QUIT;
%MEND EFECTUAR_CONTEOS;

%MACRO CALCULAR_VARIABLES(LibreriaOrigen 	= /*Donde se deberá buscar la tabla*/,
							TablaOrigen 	= /*Donde se contaran las columnas*/,
							TipoDato		= /*SIN COMILLAS, Tipo de dato a leer, CHAR o NUM o TODAS*/,
							VariableConteo	= /*EN DESUSO - NO INCLUIR*/0,
							Separador		= /*ENTRE COMILLAS, Separador entre etiquetas, por defecto es espacio*/%STR(' '),
							Cobertor		= 0,
							CondicionExtra	= /*Aplicable al SELECT de variables*/%STR( ));

	%IF &Cobertor EQ 0 %THEN
	%DO;
		%LET PreCobertor		=%NRSTR("'");
		%LET PosCobertor		=%NRSTR("'n");
	%END;
	%ELSE
	%DO;
		%LET PreCobertor		=%NRSTR('"');
		%LET PosCobertor		=%NRSTR('"n');
	%END;

	%GLOBAL LISTA_VARIABLES_CHAR;
	%GLOBAL LISTA_VARIABLES_NUM;
	%GLOBAL LISTA_VARIABLES_TODAS;

	%IF "&TipoDato" NE "TODAS" %THEN
	%DO;
		%LET condicionTipoDato	=AND UPPER(TYPE) %STR(=) UPPER("&TipoDato");
	%END;
	%ELSE
	%DO;
		%LET condicionTipoDato	=%STR( );
	%END;

	PROC SQL NOPRINT;
	SELECT
		CATS(&PreCobertor, TRANWRD(TRANWRD(NAME, '0A'x, ''), '0D'x, ''), &PosCobertor)
	INTO
		:LISTA_VARIABLES_&TipoDato separated by &Separador
	FROM
		DICTIONARY.COLUMNS
	WHERE
		LIBNAME = "&LibreriaOrigen"			AND
		MEMNAME	= "&TablaOrigen"
		&condicionTipoDato;
	QUIT;
%MEND CALCULAR_VARIABLES;

/* ---- caller: build a sample table, then count + list its CHAR columns ---- */
DATA WORK.CLIENTES;
	LENGTH NOMBRE $30 CIUDAD $20 EMAIL $40;
	INPUT NOMBRE $ CIUDAD $ EMAIL $ EDAD SALDO;
DATALINES;
Ana CDMX ana@correo.mx 34 1200.50
Luis Puebla luis@correo.mx 28 980.00
Marta Leon marta@correo.mx 41 3050.75
;
RUN;

%EFECTUAR_CONTEOS(LibreriaOrigen = WORK,
					TablaOrigen  = CLIENTES,
					TipoDato     = CHAR,
					Variable     = CONTEO_CHAR);

%CALCULAR_VARIABLES(LibreriaOrigen = WORK,
					TablaOrigen  = CLIENTES,
					TipoDato     = CHAR,
					Separador    = %STR("|"));

DATA _NULL_;
	PUT ">>>> Columnas CHAR en WORK.CLIENTES: &CONTEO_CHAR";
	PUT ">>>> Lista (name literals): &LISTA_VARIABLES_CHAR";
RUN;
