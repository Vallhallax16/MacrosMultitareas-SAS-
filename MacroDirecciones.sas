/*DECLARACION DE VARIABLES GLOBALES*/
%LET tipo = "";
%LET COLUMNA = "";

%MACRO DETECCION_DATO(TablaOrigen=, ColumnaEvaluar=);
DATA _NULL_;
SET &TablaOrigen;
	CALL SYMPUTX("tipo", VTYPE(&ColumnaEvaluar));
	STOP;
RUN;
%MEND DETECCION_DATO;

%MACRO CAMPO_ESPECIFICO(Libreria=, Tabla=, EquivalenciaBuscada=);
	PROC SQL NOPRINT;
		SELECT
			name
		INTO
			:COLUMNA
		FROM
			DICTIONARY.COLUMNS
		WHERE
			libname EQ "&Libreria"									AND
			memname	EQ "&Tabla"										AND
			UPCASE(name) LIKE CAT("%","&EquivalenciaBuscada","%");
	QUIT;
%MEND CAMPO_ESPECIFICO;

%MACRO TAB_CCI_CCID(TablaOrigen= /*Donde se extraen los datos*/, TablaDestino= /*Tabla pre resultados, sin fechas, la D si las tendr�*/, TablaActualizable=/*Tabla donde se actualizaran las fechas de inicio*/);
	%DETECCION_DATO(TablaOrigen = &TablaOrigen, ColumnaEvaluar = PERIODO_ANUAL);
	%CAMPO_ESPECIFICO(Libreria = %scan(&TablaOrigen, 1, .),Tabla = %scan(&TablaOrigen, 2, .), EquivalenciaBuscada = TIPO_NOM);

	%LET COL_NOMINA = &COLUMNA;

	%IF "&tipo" EQ "N" %THEN
	%DO;
		%LET VAR_NUM_PERIODO = 		T1.NUM_PERIODO;
		%LET VAR_PERIODO_ANUAL = 	T1.PERIODO_ANUAL;
	%END;
	%ELSE
	%DO;
		%LET VAR_NUM_PERIODO = 		INPUT(T1.NUM_PERIODO, BEST8.);
		%LET VAR_PERIODO_ANUAL = 	INPUT(T1.PERIODO_ANUAL, BEST8.);
	%END;

	PROC SQL NOPRINT;
	CREATE TABLE &TablaDestino AS
		SELECT DISTINCT
			T1.CCOSTO						AS CCOSTO,
			T1.&COL_NOMINA 					AS TIPO_NOM,
			MIN(&VAR_NUM_PERIODO) 			AS NUM_PERIODO,
			MIN(&VAR_PERIODO_ANUAL) 		AS PERIODO_ANUAL
		FROM
			&TablaOrigen T1
		GROUP BY
			T1.CCOSTO,
			&VAR_NUM_PERIODO,
			&VAR_PERIODO_ANUAL
		ORDER BY
			T1.CCOSTO,
			&VAR_NUM_PERIODO,
			&VAR_PERIODO_ANUAL ASC;
	QUIT;

	PROC SORT DATA = &TablaDestino OUT = &TablaDestino NODUPKEY;
	BY CCOSTO;

	RUN;

	%LET TablaDestinoD = &TablaDestino.D;

	PROC SQL NOPRINT;
	CREATE TABLE &TablaDestinoD AS
		SELECT
			T.*,
			input(T2.FECHA_DESDE,YYMMDD8.) AS FE_DESDE FORMAT = DATE9.
		FROM
			&TablaDestino T
		LEFT JOIN
			ORAOPEN.AN_CAL_PERIODOS T2 ON T.TIPO_NOM EQ T2.TIPO_NOM
		WHERE
			T.PERIODO_ANUAL EQ T2.PERIODO_ANUAL	AND
			T.NUM_PERIODO EQ T2.NUM_PERIODO;
	QUIT;

	PROC SQL;
	UPDATE 
		&TablaActualizable
	SET
		FE_INICIO = (SELECT 
						ST1.FE_DESDE
					FROM
						&TablaDestinoD ST1
					WHERE
						NB_CCOSTOS EQ INPUT(ST1.CCOSTO, BEST.))
	WHERE
		FE_INICIO IS NULL;
	QUIT;
%MEND TAB_CCI_CCID;

%MACRO TAB_CCF_CCFD(TablaOrigen= /*Donde se extraen los datos*/, TablaDestino= /*Tabla pre resultados, sin fechas, la D si las tendr�*/, TablaActualizable=/*Tabla donde se actualizaran las fechas de inicio*/);
	%DETECCION_DATO(TablaOrigen = &TablaOrigen, ColumnaEvaluar = PERIODO_ANUAL);
	%CAMPO_ESPECIFICO(Libreria = %scan(&TablaOrigen, 1, .),Tabla = %scan(&TablaOrigen, 2, .), EquivalenciaBuscada = TIPO_NOM);

	%LET COL_NOMINA = &COLUMNA;

	%IF "&tipo" EQ "N" %THEN
	%DO;
		%LET VAR_NUM_PERIODO = 		T1.NUM_PERIODO;
		%LET VAR_PERIODO_ANUAL = 	T1.PERIODO_ANUAL;
	%END;
	%ELSE
	%DO;
		%LET VAR_NUM_PERIODO = 		INPUT(T1.NUM_PERIODO, BEST8.);
		%LET VAR_PERIODO_ANUAL = 	INPUT(T1.PERIODO_ANUAL, BEST8.);
	%END;

	PROC SQL NOPRINT;
	CREATE TABLE &TablaDestino AS
		SELECT DISTINCT
			T1.CCOSTO						AS CCOSTO,
			T1.&COL_NOMINA					AS TIPO_NOM,
			MAX(&VAR_NUM_PERIODO) 			AS NUM_PERIODO,
			MAX(&VAR_PERIODO_ANUAL) 		AS PERIODO_ANUAL
		FROM
			&TablaOrigen T1		
		GROUP BY
			T1.CCOSTO,
			&VAR_NUM_PERIODO,
			&VAR_PERIODO_ANUAL
		/*HAVING
			MAX(&VAR_PERIODO_ANUAL) NE YEAR(TODAY())*/
		ORDER BY
			&VAR_PERIODO_ANUAL DESC,
			&VAR_NUM_PERIODO DESC;
	QUIT;

	PROC SORT DATA = &TablaDestino OUT = &TablaDestino NODUPKEY;
	BY CCOSTO;

	RUN;

	PROC SQL;
	DELETE FROM
		&TablaDestino
	WHERE
		PERIODO_ANUAL EQ YEAR(TODAY());
	QUIT;

	%LET TablaDestinoD = &TablaDestino.D;

	PROC SQL NOPRINT;
	CREATE TABLE &TablaDestinoD AS
		SELECT
			T.*,
			input(T2.FECHA_HASTA,YYMMDD8.) AS FE_HASTA FORMAT = DATE9.
		FROM
			&TablaDestino T
		LEFT JOIN
			ORAOPEN.AN_CAL_PERIODOS T2 ON T.TIPO_NOM EQ T2.TIPO_NOM
		WHERE
			T.PERIODO_ANUAL EQ T2.PERIODO_ANUAL	AND
			T.NUM_PERIODO EQ T2.NUM_PERIODO;
	QUIT;

	PROC SQL;
	UPDATE 
		&TablaActualizable
	SET
		FE_FIN = (SELECT 
						ST1.FE_HASTA
					FROM
						&TablaDestinoD ST1
					WHERE
						PUT(NB_CCOSTOS, BEST.) EQ ST1.CCOSTO);
	QUIT;
%MEND TAB_CCF_CCFD;

%MACRO CORRECCION_VIGENCIA(TablaOrigen=/*Tabla donde se corregir� la vigencia*/);
	DATA &TablaOrigen;
	SET &TablaOrigen;
		IF MISSING(FE_FIN) 		AND
			NOT MISSING(FE_INICIO) 
		THEN
			SN_VIG = "1";
		ELSE
			SN_VIG = "0";
	RUN;
%MEND CORRECCION_VIGENCIA;