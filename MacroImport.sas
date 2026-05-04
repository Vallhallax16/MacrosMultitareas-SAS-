/*Esta funcion se crea una tabla a partir de un archivo específico XLSX o CSV*/
/*TIPO: Publica*/
/*REQUIERE: Nada*/
/*RESULTADO: Tabla con funciones puntuales desde un archivo*/
%MACRO IMPORT_GENERAL(TablaSaliente = /*Objeto a crear en SAS*/,
						Ruta		= /*Del archivo*/,
						Motor		= /*De dónde se extraerá el archivo, */XLSX,
						Hoja		= /*Nombre de la hoja*/,
						Encabezados = /*Emplear solo YES o NO*/,
						Rango		= "A1:"/*Por defecto es A1:*/,
						Delimitador	= %STR()/*CON comilla simple, necesario para TXT*/);
								
	%IF %SYSFUNC(UPCASE(&Motor))	EQ XLSX OR
		%SYSFUNC(UPCASE(&Motor))	EQ XLS		%THEN
	%DO;
		%LET	argSheet	=	%STR(SHEET=)&Hoja%STR(;);
		%LET	argRange	=	%STR(RANGE=)&Rango%STR(;);
	%END;
	%ELSE
	%DO;
		%LET	argSheet	=	%STR( );
		%LET	argRange	=	%STR( );
	%END;

	%IF %LENGTH(&Delimitador) GT 0 %THEN
	%DO;
		%LET 	argDelim	=	%STR(DELIMITER=)&Delimitador;
	%END;
	%ELSE
	%DO;
		%LET 	argDelim	=	%STR( );
	%END;
	
	PROC IMPORT 
		OUT 		=&TablaSaliente
		DATAFILE 	=&Ruta
		DBMS 		=&Motor
		REPLACE;
		&argDelim;
		&argSheet;
		GETNAMES 	=&Encabezados;
		&argRange;
	RUN;
%MEND IMPORT_GENERAL;

/*Esta función importa un archivo según requerimientos particulares de columnas (Hecha con IA)*/
/*TIPO: Publica*/
/*REQUIERE: Archivo especificiado en una ruta*/
/*RESULTADO: Tabla importada con requerimientos puntuales*/
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