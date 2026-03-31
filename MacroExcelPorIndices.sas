%MACRO PRIMEROS_CALCULOS(LibreriaOrigen 	= ,
							TablaOrigen 	= ,
							TipoDato		= ,
							VariableConteo	= ,
							Separador		= %STR(' '),
							Cobertor		= 0,
							CondicionExtra	= %STR( ));
								
	%EFECTUAR_CONTEOS(LibreriaOrigen 		= &LibreriaOrigen,
							TablaOrigen 	= &TablaOrigen,
							TipoDato		= &TipoDato,
							Variable		= &VariableConteo);

	%CALCULAR_VARIABLES(LibreriaOrigen 		= &LibreriaOrigen,
							TablaOrigen 	= &TablaOrigen,
							TipoDato		= &TipoDato,
							VariableConteo	= &VariableConteo,
							Separador		= &Separador,
							Cobertor		= &Cobertor,
							CondicionExtra	= &CondicionExtra);
%MEND PRIMEROS_CALCULOS;

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
		/*&CondicionExtra;*/ %STR(;);
	QUIT;
%MEND CALCULAR_VARIABLES;

%MACRO CONOCER_COL_INDEX(LibreriaOrigen 	= /*Donde se deberá buscar la tabla*/,
							TablaOrigen 	= /*Donde se contaran las columnas*/,
							TipoDato		= /*Tipo de dato a leer, CHAR o NUM*/);
								
	%GLOBAL tempConteo;

	%LET Separador		= %STR("|");
								
	%PRIMEROS_CALCULOS(LibreriaOrigen 		= &LibreriaOrigen,
							TablaOrigen 	= &TablaOrigen,
							TipoDato		= &TipoDato,
							VariableConteo	= tempConteo,
							Separador		= &Separador,
							Cobertor		= 0);

	%IF &TipoDato EQ %STR(NUM) %THEN 
		%LET linea = %STR(columnas = ) "&LISTA_VARIABLES_NUM";
	%ELSE
		%LET linea = %STR(columnas = ) "&LISTA_VARIABLES_CHAR";

	DATA WORK.INFO_&TablaOrigen._&TipoDato (DROP = i columnas);
		&linea %STR(;);

		DO i = 1 TO &tempConteo;
			Encabezado 	= SCAN(columnas,i,&Separador);
			Indice		= i;
			OUTPUT;
		END;
	RUN;
%MEND CONOCER_COL_INDEX;

%MACRO EXTRAER_VAL_UNIC(TablaOrigen 		= /*Tabla a leer*/,
						TablaDestino		= /*Tabla donde se dejaran los valores*/,
						ColumnaEscogidaStr 	= /*Indice de la tabla, diferenciando las CHAR de las NUM, separados por espacio. Debe ser la misma cantidad que los AliasColumna*/,
						AliasColumnaStr		= /*SOLO COLs TEXTO Nombre con el que se quedará la columna, separados por espacio. Debe ser la misma cantidad que los indice ColumnaEscogida*/,
						ConteoColumnasStr	= /*SOLO COLs TEXTO Conteo de columnas*/,
						ColumnaEscogidaNum 	= /*SOLO COLs NUM Indice de la tabla, diferenciando las CHAR de las NUM, separados por espacio. Debe ser la misma cantidad que los AliasColumna*/,
						AliasColumnaNum		= /*SOLO COLs NUM Nombre con el que se quedará la columna, separados por espacio. Debe ser la misma cantidad que los indice ColumnaEscogida*/,
						ConteoColumnasNum	= /*SOLO COLs NUM Conteo de columnas*/,
						ColumnasEje			= /*Usadas para depurar la tabla resultante, separados por espacio*/);

	%GLOBAL CONTEOS_CHAR;
	%GLOBAL CONTEOS_NUM;

	%LET patronLibreria = %SYSFUNC(PRXPARSE(s/\..*$//));
	%LET patronTabla 	= %SYSFUNC(PRXPARSE(s/^.*\.//));

	%PRIMEROS_CALCULOS(LibreriaOrigen 		= %SYSFUNC(PRXCHANGE(&patronLibreria, -1,&TablaOrigen)),
							TablaOrigen 	= %SYSFUNC(PRXCHANGE(&patronTabla, -1,&TablaOrigen)),
							TipoDato		= NUM,
							VariableConteo	= CONTEOS_NUM);

	%PRIMEROS_CALCULOS(LibreriaOrigen 		= %SYSFUNC(PRXCHANGE(&patronLibreria, -1,&TablaOrigen)),
							TablaOrigen 	= %SYSFUNC(PRXCHANGE(&patronTabla, -1,&TablaOrigen)),
							TipoDato		= CHAR,
							VariableConteo	= CONTEOS_CHAR);

	%CREAR_RENOMBRADA(TablaOrigen 			= &TablaOrigen,
						TablaDestino		= &TablaDestino,
						ColumnaEscogidaStr 	= &ColumnaEscogidaStr,
						AliasColumnaStr		= &AliasColumnaStr,
						ConteoColumnasStr	= &ConteoColumnasStr,
						ColumnaEscogidaNum 	= &ColumnaEscogidaNum,
						AliasColumnaNum		= &AliasColumnaNum,
						ConteoColumnasNum	= &ConteoColumnasNum);

	PROC SORT DATA = &TablaDestino OUT = &TablaDestino NODUPKEY;
	BY &ColumnasEje;
	RUN;
%MEND EXTRAER_VAL_UNIC;

%MACRO VALIDAR_EXISTENCIA(Candidato			= /*Valor a evaluar si existe*/,
							Listado			= /*Donde se evaluará la existencia del candidato*/);
	%LET limite				= %SYSFUNC(COUNTW(&Listado));

	%DO i = 1 %TO &limite;
		%LET valorEnTurno	= %SCAN(&Listado, &i, %STR( ));

		%IF &valorEnTurno EQ &Candidato %THEN
			%RETURN;
	%END;

	%LET encontrado = 0;
%MEND VALIDAR_EXISTENCIA;

%MACRO CREAR_RENOMBRADA(TablaOrigen 		= /*CON libreria, tabla a leer*/,
						TablaDestino		= /*CON libreria, tabla donde se dejaran los valores*/,
						ColumnaEscogidaStr 	= /*Indice de la tabla, diferenciando las CHAR de las NUM, separados por espacio. Debe ser la misma cantidad que los AliasColumna. Para usar todos los índices poner -1*/%STR( ),
						AliasColumnaStr		= /*SOLO COLs de tipo TEXTO, SIN COMILLAS Nombre con el que se quedará la columna, separados por espacio. Debe ser la misma cantidad que los indice ColumnaEscogida*/%STR( ),
						ConteoColumnasStr	= /*EN DESUSO - NO INCLUIR*/0,
						ColumnaEscogidaNum 	= /*SOLO COLs NUM Indice de la tabla, diferenciando las CHAR de las NUM, separados por espacio. Debe ser la misma cantidad que los AliasColumna. Para usar todos los índices poner -1*/%STR( ),
						AliasColumnaNum		= /*SOLO COLs de tipo NUM, SIN COMILLAS Nombre con el que se quedará la columna, separados por espacio. Debe ser la misma cantidad que los indice ColumnaEscogida*/%STR( ),
						ConteoColumnasNum	= /*EN DESUSO - NO INCLUIR*/0,
						Cobertor			= 0
						);
							
	%GLOBAL CONTEOS_CHAR;
	%GLOBAL CONTEOS_NUM;

	%LET patronLibreria = %SYSFUNC(PRXPARSE(s/\..*$//));
	%LET patronTabla 	= %SYSFUNC(PRXPARSE(s/^.*\.//));

	%PRIMEROS_CALCULOS(LibreriaOrigen 		= %SYSFUNC(PRXCHANGE(&patronLibreria, -1,&TablaOrigen)),
							TablaOrigen 	= %SYSFUNC(PRXCHANGE(&patronTabla, -1,&TablaOrigen)),
							TipoDato		= NUM,
							VariableConteo	= CONTEOS_NUM,
							Cobertor		= &Cobertor);

	%PRIMEROS_CALCULOS(LibreriaOrigen 		= %SYSFUNC(PRXCHANGE(&patronLibreria, -1,&TablaOrigen)),
							TablaOrigen 	= %SYSFUNC(PRXCHANGE(&patronTabla, -1,&TablaOrigen)),
							TipoDato		= CHAR,
							VariableConteo	= CONTEOS_CHAR,
							Cobertor		= &Cobertor);

	/*CREACION DE ARGUMENTOS STR*/
	%IF &ColumnaEscogidaStr EQ -1 %THEN
	%DO;
		%LET ColumnasStr		= %STR( );

		%DO i = 1 %TO &CONTEOS_CHAR;
			%LET ColumnasStr 	= &ColumnasStr %SYSFUNC(SCAN(&AliasColumnaStr, &i, " ")) %STR(=) columnasTablaStr[&i] %STR(;);
		%END;
	%END;
	/*%IF &conteo EQ 3 AND &obtenidoPosDos EQ %STR(-) %THEN
	%DO;
		%PUT >>>> Se detecto rango;
		%LET limiteInferior		= %SCAN(&ColumnaEscogidaStr,1,-);
		%LET limiteSuperior		= %SCAN(&ColumnaEscogidaStr,2,-);
		%LET j					= 1;

		%LET ColumnasStr		= %STR( );

		%DO i = &limiteInferior %TO &limiteSuperior;
			%LET ColumnasStr 	= &ColumnasStr %SYSFUNC(SCAN(&AliasColumnaStr, &j, " ")) %STR(=) columnasTablaStr[&i] %STR(;);
			%LET j				= %EVAL(&j + 1);
		%END;

		%PUT >>>> ColumnasStr &ColumnasStr;
	%END;*/
	%ELSE
	%DO;
		%LET ColumnasStr		= %STR( );

		%DO i = 1 %TO %SYSFUNC(COUNTW(&ColumnaEscogidaStr));
				%LET ColumnasStr = &ColumnasStr %SYSFUNC(SCAN(&AliasColumnaStr, &i, " ")) %STR(=) columnasTablaStr[%SYSFUNC(SCAN(&ColumnaEscogidaStr, &i, " "))] %STR(;);
		%END;
	%END;

	/*CREACION DE ARGUMENTOS NUM*/
	%IF &ColumnaEscogidaNum EQ -1 %THEN
	%DO;
		%LET ColumnasNum		= %STR( );

		%DO i = 1 %TO &CONTEOS_NUM;
			%LET ColumnasNum 	= &ColumnasNum %SYSFUNC(SCAN(&AliasColumnaNum, &i, " ")) %STR(=) columnasTablaNum[&i] %STR(;);
		%END;
	%END;
	%ELSE
	%DO;
		%LET ColumnasNum		= %STR( );

		%DO i = 1 %TO %SYSFUNC(COUNTW(&ColumnaEscogidaNum));
				%LET ColumnasNum = &ColumnasNum %SYSFUNC(SCAN(&AliasColumnaNum, &i, " ")) %STR(=) columnasTablaNum[%SYSFUNC(SCAN(&ColumnaEscogidaNum, &i, " "))] %STR(;);
		%END;
	%END;

	DATA 	&TablaDestino (KEEP = &AliasColumnaStr &AliasColumnaNum);
	SET		&TablaOrigen;
		%IF &ColumnaEscogidaStr NE %STR( ) %THEN
			array columnasTablaStr [&CONTEOS_CHAR] &LISTA_VARIABLES_CHAR %STR(;);

		%IF &ColumnaEscogidaNum NE %STR( ) %THEN
			array columnasTablaNum [&CONTEOS_NUM] &LISTA_VARIABLES_NUM %STR(;);

		%IF &ColumnaEscogidaStr NE %STR( ) %THEN
			&ColumnasStr %STR(;);
		
		%IF &ColumnaEscogidaNum NE %STR( ) %THEN
			&ColumnasNum %STR(;);
		OUTPUT;	
	RUN;
%MEND CREAR_RENOMBRADA;