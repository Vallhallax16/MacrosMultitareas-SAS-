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

	%PUT >>>> argDelim &argDelim;
	
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