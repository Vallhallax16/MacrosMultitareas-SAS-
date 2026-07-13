/* ------------------------------------------------------------------ *
 * Bundle: t003_data_import
 * Source: MacroImport.sas  (%DATA_IMPORT, verbatim)
 *
 * %DATA_IMPORT builds a DATA-step reader from a "Campos" spec (a list of
 * "name length" pairs separated by |) and imports a delimited file with a
 * dynamically constructed LENGTH / INFILE DSD / INPUT. The macro is copied
 * unchanged from the repo. To keep the bundle self-contained, the added
 * code writes a small pipe-delimited file inline (FILENAME TEMP) and then
 * feeds that fileref to %DATA_IMPORT.
 * ------------------------------------------------------------------ */

/* ---- write a small pipe-delimited source inline ---- */
FILENAME tmpin TEMP;
DATA _NULL_;
	FILE tmpin;
	PUT "NOMBRE|EDAD|CIUDAD";
	PUT "Ana|34|CDMX";
	PUT "Luis|28|Puebla";
	PUT "Marta|41|Leon";
RUN;

/* ------------------------------------------------------------------ *
 * %DATA_IMPORT (copied verbatim from MacroImport.sas)
 * ------------------------------------------------------------------ */
%MACRO DATA_IMPORT(TablaDestino	=/*Tabla destino CON librería, SIN comillas*/,
					RutaArchivo	=/*Ruta completa del archivo, CON comillas*/,
					Delimitador	=/*Carácter delimitador, SIN comillas*/,
					Campos		=/*Lista de campos con longitud separados por |, SIN comillas*/,
					Encoding	=/*Codificación del archivo*/UTF-8,
					Lrecl		=/*Longitud máxima de línea*/32767,
					FirstObs	=/*Fila donde inician los datos*/2,
					Missover	=/*1 para activar, 0 para desactivar*/0,
					Truncover	=/*1 para activar, 0 para desactivar*/0,
					Informats	=/*Lista de informats separados por |, SIN comillas*/%STR(),
					Formatos	=/*Lista de formatos separados por |, SIN comillas*/);
	%LOCAL conteo campoActual nombreCampo longitudCampo;
	%LOCAL listaLength listaInput listaFormat;
	%LOCAL opcionesMissover opcionesTruncover;
	%LOCAL conteoFormatos formatoActual nombreFormato valorFormato;
	%LOCAL conteoInformats informatActual nombreInformat valorInformat;
	%LOCAL delimitadorFinal informatEncontrado;

	%IF %UPCASE(&Delimitador) EQ TAB OR &Delimitador EQ 09 %THEN
		%LET delimitadorFinal = "09"X;
	%ELSE
		%LET delimitadorFinal = "&Delimitador";

	%LET listaLength	= %STR();
	%LET listaInput		= %STR();
	%LET conteo			= %SYSFUNC(COUNTW(%SUPERQ(Campos), %STR(|)));

	%DO iDI = 1 %TO &conteo;
		%LET campoActual	= %SCAN(%SUPERQ(Campos), &iDI, %STR(|));
		%LET nombreCampo	= %SCAN(&campoActual, 1, %STR( ));
		%LET longitudCampo	= %SCAN(&campoActual, 2, %STR( ));

		%LET listaLength	= &listaLength &nombreCampo &longitudCampo;

		/* Buscar si este campo tiene un informat asociado */
		%LET informatEncontrado = %STR();

		%IF %LENGTH(%SUPERQ(Informats)) GT 0 %THEN
		%DO;
			%LET conteoInformats = %SYSFUNC(COUNTW(%SUPERQ(Informats), %STR(|)));

			%DO iIF = 1 %TO &conteoInformats;
				%LET informatActual		= %SCAN(%SUPERQ(Informats), &iIF, %STR(|));
				%LET nombreInformat		= %SCAN(&informatActual, 1, %STR( ));
				%LET valorInformat		= %SCAN(&informatActual, 2, %STR( ));

				%IF %UPCASE(&nombreCampo) EQ %UPCASE(&nombreInformat) %THEN
				%DO;
					%LET informatEncontrado = :&valorInformat;
				%END;
			%END;
		%END;

		/* Agregar campo al INPUT con o sin informat */
		%LET listaInput = &listaInput &nombreCampo &informatEncontrado;
	%END;

	%LET listaFormat = %STR();

	%IF %LENGTH(%SUPERQ(Formatos)) GT 0 %THEN
	%DO;
		%LET conteoFormatos = %SYSFUNC(COUNTW(%SUPERQ(Formatos), %STR(|)));

		%DO iDI = 1 %TO &conteoFormatos;
			%LET formatoActual	= %SCAN(%SUPERQ(Formatos), &iDI, %STR(|));
			%LET nombreFormato	= %SCAN(&formatoActual, 1, %STR( ));
			%LET valorFormato	= %SCAN(&formatoActual, 2, %STR( ));

			%LET listaFormat	= &listaFormat &nombreFormato &valorFormato;
		%END;
	%END;

	%IF &Missover EQ 1 %THEN
		%LET opcionesMissover = MISSOVER;
	%ELSE
		%LET opcionesMissover = %STR();

	%IF &Truncover EQ 1 %THEN
		%LET opcionesTruncover = TRUNCOVER;
	%ELSE
		%LET opcionesTruncover = %STR();

	DATA &TablaDestino;
		LENGTH
			&listaLength;

		INFILE &RutaArchivo
			DLM			= &delimitadorFinal
			FIRSTOBS	= &FirstObs
			LRECL		= &Lrecl
			ENCODING	= "&Encoding"
			DSD
			&opcionesMissover
			&opcionesTruncover;

		INPUT
			&listaInput;

		%IF %LENGTH(&listaFormat) GT 0 %THEN
		%DO;
			FORMAT
				&listaFormat;
		%END;
	RUN;

	%PUT >>>> Tabla &TablaDestino creada exitosamente desde &RutaArchivo;
%MEND DATA_IMPORT;

/* ---- caller ---- */
%DATA_IMPORT(TablaDestino = WORK.PERSONAS,
			RutaArchivo  = tmpin,
			Delimitador  = |,
			Campos       = NOMBRE $30 | EDAD 8 | CIUDAD $20,
			Truncover    = 1);

PROC PRINT DATA = WORK.PERSONAS NOOBS;
	TITLE "WORK.PERSONAS importada con DATA_IMPORT";
RUN;
TITLE;
