Option Fullstimer;

OPTIONS SET = NLS_LANG="SPANISH_SPAIN.WE8ISO8859P1";

%INCLUDE '/data/Macros necesarios/MacroMailer.sas';

%MACRO REPORTAR_EJECUCION(RutaLogs      =/*Para una ruta particular, por defecto es /data/Macros necesarios/Logs*/%STR(/data/Macros necesarios/Logs/),
							Archivo		=/*SIN comillas, nombre del archivo Log a leer, soporta LIBRERIA.NOMBRE*/,
							NivelDebug	=/*Soporta NOTE, WARNING, ERROR o TODOS, por defecto es ERROR, de ser varios separar por espacio y SIN comillas*/ERROR,
							TimestIni	=/*Timestamp inicial del proceso*/,
							TimestFin	=/*Timestamp final del proceso*/);
	%LET patronTabla 				= %SYSFUNC(PRXPARSE(s/^.*\.//));
	%LET Archivo					= %SYSFUNC(PRXCHANGE(&patronTabla, -1, &Archivo));

	%SYSCALL PRXFREE(patronTabla);

	%LET rutaCompleta				=&RutaLogs&Archivo..log;

	%IF "&NivelDebug" EQ "TODOS" %THEN
	%DO;
		%LET esqueletoPatron		=%STR(/^(NOTE|WARNING|ERROR)/i);
		%LET esqueletoPatronRem		=%STR(s/^(NOTE:\s+|WARNING:\s+|ERROR:\s+)//i);
	%END;
	%ELSE
	%DO;
		%LET esqueletoPatron		=%STR(/^%();
		%LET esqueletoPatronRem		=%STR(s/^%();

		%LET limite					=%SYSFUNC(COUNTW(&NivelDebug,%STR( )));

		%DO iRE = 1 %TO &limite;
			%LET esqueletoPatron	=&esqueletoPatron%SCAN(&NivelDebug, &iRE, %STR( ));
			%LET esqueletoPatronRem	=&esqueletoPatronRem%SCAN(&NivelDebug, &iRE, %STR( ));

			%IF &iRE NE &limite %THEN
			%DO;
				%LET esqueletoPatron=&esqueletoPatron%STR(|);
				%LET esqueletoPatronRem	=&esqueletoPatronRem%STR(:\s+|);
			%END;
		%END;

		%LET esqueletoPatron		=&esqueletoPatron%STR(%)/i);
		%LET esqueletoPatronRem		=&esqueletoPatronRem%STR(:\s+%)//i);
	%END;

	%LET informacionCapturada		=%STR();

	%LEER_LOG(RutaLogs				=&rutaCompleta,
				PatronBusquedas		=&esqueletoPatron,
				Colector			=informacionCapturada);

	%LET informacionDebugSas		=%SUPERQ(informacionCapturada);
	%LET informacionCapturada		=%STR();

	%LEER_LOG(RutaLogs				=&rutaCompleta,
				PatronBusquedas		=%STR(/^>>>>/),
				Colector			=informacionCapturada);

	PROC SQL NOPRINT;
		SELECT
			T.REGISTRO_FIN
		INTO
			:CANTIDAD_PREVIOS
		FROM
			MDCAPIT.BITACORA_INCREMENTAL T
		WHERE
			UPPER(T.CONCEPTO_OP) LIKE "ANTES%"		AND
			T.TABLA_AFECTADA EQ "&tablaBase"		AND
			T.FECHA_EJEC BETWEEN &timestInicial		AND
				&timestFinal;
	QUIT;

	PROC SQL NOPRINT;
		SELECT
			COUNT(*)
		INTO
			:CANTIDAD_POSTERIORES
		FROM
			&tablaBase T;
	QUIT;

	%REDACTAR_CORREO(TextosRecuperados		= %SUPERQ(informacionDebugSas),
						TextosDebug			= %SUPERQ(informacionCapturada),
						CantPrev           	= &CANTIDAD_PREVIOS,
						CantPost           	= &CANTIDAD_POSTERIORES,
						PatronReemplazo    	= &esqueletoPatronRem,
						TimestIni          	= &timestInicial,
						TimestFin          	= &timestFinal,
						RutaLog				= &rutaCompleta);
%MEND REPORTAR_EJECUCION;

%MACRO LEER_LOG(RutaLogs			=/*Se pasa de una función previa*/,
				PatronBusquedas		=/*Regex SIN parsear*/,
				Colector			=/*Variable donde se guardarán las búsquedas*/);
	DATA _NULL_;
		RETAIN patronDeBusquedas colectorTxt;

		LENGTH renglon $1000;
		INFILE "&RutaLogs" TRUNCOVER LRECL=1000; 
		INPUT renglon $CHAR1000.;

		IF _N_ EQ 1 THEN 
		DO;
			patronDeBusquedas 	= PRXPARSE("&PatronBusquedas");
			LENGTH colectorTxt $1000;
		END;

		IF PRXMATCH(patronDeBusquedas, renglon) THEN 
		DO;
			colectorTxt			=CATX("|", colectorTxt, renglon);

			CALL SYMPUT("&Colector",colectorTxt);
		END;
	RUN;
%MEND LEER_LOG;

%MACRO REDACTAR_CORREO(TextosRecuperados	=/*Lo que se recuperó del Log*/,
						TextosDebug			=/*Lo que se recuperó y el usuario pidio imprimir*/,
						DebugUsuario		=/*Los textos debugueados por el usuario*/%STR(),
						CantPrev			=,
						CantPost			=,
						PatronReemplazo		=/*SIN PARSEAR*/,
						TimestIni			=/*Timestamp inicial del proceso*/,
						TimestFin			=/*Timestamp final del proceso*/,
						RutaLog				=/*Ruta del archivo Log analizado, para adjuntarlo al correo*/);
	%LET listado				=%STR();

	%LET estado					=%STR();

	%LET timestIniTxt			=%SYSFUNC(PUTN(&TimestIni,DATETIME20.));

	%LET timestFinTxt			=%SYSFUNC(PUTN(&TimestFin,DATETIME20.));

	%LET horasEjec				=%SYSEVALF(&TimestFin - &TimestIni);
	%LET horasEjec				=%SYSFUNC(FLOOR(&horasEjec));

	%IF %SYMEXIST(CANTIDAD_POSTERIORES) EQ 0 %THEN
		%LET CANTIDAD_POSTERIORES=Sin datos;
	
	%IF %SYMEXIST(CANTIDAD_PREVIOS) EQ 0 %THEN
		%LET CANTIDAD_PREVIOS	=Sin datos;

	%IF %SYMEXIST(ultTabResp) EQ 0 %THEN
		%LET ultTabResp		=Sin respaldos;

	%IF &horasEjec GE 3600 %THEN
	%DO;
		%LET unidad				=horas;
		%LET horasEjec			=%SYSEVALF(&horasEjec / 3600);
	%END;
	%ELSE %IF &horasEjec GE 60 %THEN
	%DO;
		%LET unidad				=minutos;
		%LET horasEjec			=%SYSEVALF(&horasEjec / 60);
	%END;
	%ELSE
	%DO;
		%LET unidad				=segundos;
	%END;

	%IF &bloqueos NE 0 %THEN
	%DO;
		%LET listadoBloqueos	=%STR();

		%LET listadoTablas		=%STR();

		%LET patronTabla 		=%SYSFUNC(PRXPARSE(/for (\w+\.\w+)\.DATA/i));
		
		%LET patronProceso 		=%SYSFUNC(PRXPARSE(/process (\d+)/i)); 
	%END;

	%LET patronEtiqueta			=%SYSFUNC(PRXPARSE(&PatronReemplazo));

	%DO iRC = 1 %TO %SYSFUNC(COUNTW(%SUPERQ(TextosRecuperados), %STR(|)));
		%LET textoActual		=%QSCAN(%SUPERQ(TextosRecuperados), &iRC, %STR(|));

		%IF &bloqueos NE 0 %THEN
		%DO;
			%IF %SYSFUNC(PRXMATCH(&patronTabla, %SUPERQ(textoActual))) %THEN
			%DO;
				%LET tablaEnBloqueo = %QSYSFUNC(PRXPOSN(&patronTabla, 1, %SUPERQ(textoActual)));
				%LET listadoTablas=&listadoTablas%STR(|)&tablaEnBloqueo;
			%END;

			%IF %SYSFUNC(PRXMATCH(&patronProceso, %SUPERQ(textoActual))) %THEN
			%DO;
				%LET codigoDeBloqueo = %QSYSFUNC(PRXPOSN(&patronProceso, 1, %SUPERQ(textoActual)));
				%LET listadoBloqueos	 =&listadoBloqueos%STR(|)&codigoDeBloqueo;
			%END;
		%END;
		%ELSE
		%DO;
			%LET listado			=&listado<li>%QSYSFUNC(PRXCHANGE(&patronEtiqueta, -1, %SUPERQ(textoActual)))</li>;
		%END;
	%END;

	%LET seccionErrores			=%STR();
	%LET seccionBloqueos		=%STR();
	%LET seccionUsuarioD		=%STR();

	%IF %LENGTH(%SUPERQ(listado)) GT 0 %THEN
	%DO;
		%CREAR_SECCION(ColorEncabezado		=%STR(#b80b19),
							TituloEncab		=ERRORES,
							ListaOpciones	=&listado,
							Colector		=seccionErrores);
	%END;

	%IF %LENGTH(%SUPERQ(TextosDebug)) GT 0 %THEN
	%DO;
		%LET listado					=%STR();

		%LET patronUsuarioD				=%SYSFUNC(PRXPARSE(s/^>>>>//));

		%DO iRC = 1 %TO %SYSFUNC(COUNTW(%SUPERQ(TextosDebug), %STR(|)));
			%LET textoActual		=%QSCAN(%SUPERQ(TextosDebug), &iRC, %STR(|));

			%LET listado			=&listado<li>%QSYSFUNC(PRXCHANGE(&patronUsuarioD, 1, %SUPERQ(textoActual)))</li>;
		%END;

		%SYSCALL PRXFREE(patronUsuarioD);

		%CREAR_SECCION(ColorEncabezado		=%STR(#640bb8),
						TituloEncab			=%STR(DEBUG DEL USUARIO),
						ListaOpciones		=&listado,
						Colector			=seccionUsuarioD);
	%END;

	%IF &TimestIni EQ . 	OR
		(&errorTotal NE 0	AND
		&bloqueos	EQ 0)	%THEN
	%DO;
		%LET estado				=ABORTADO;
	%END;
	%ELSE %IF (&TimestIni NE . AND &TimestFin EQ .) 	OR
		&bloqueos 	NE 0							%THEN
	%DO;
		%LET estado				=INTERRUMPIDO;
	%END;
	%ELSE
	%DO;
		%LET estado				=TERMINADO;
	%END;

	%IF &errorTotal NE 0 %THEN
	%DO;
		%LET listado	=%STR();

		%DO iRC = 1 %TO %SYSFUNC(COUNTW(&tablasErrores, %STR(|)));
			%LET edoErrAct		= %SCAN(&codigoErrores, &iRC, %STR(|));

			%IF &edoErrAct EQ -1 %THEN
				%LET edoDesc	=%STR(Tabla VACIA: );
			%ELSE %IF &edoErrAct EQ -2 %THEN
				%LET edoDesc	=%STR(Archivo NO encontrado: );
			%ELSE %IF &edoErrAct EQ -4 %THEN
				%LET edoDesc	=%STR(Tabla BLOQUEADA: );
			%ELSE
				%LET edoDesc	=%STR(Tabla NO existe: );

			%LET tablaErrorAct	=%SCAN(&tablasErrores, &iRC, %STR(|));

			%IF &bloqueos NE 0 %THEN
			%DO;
				%DO iRCsub = 1 %TO %SYSFUNC(COUNTW(&listadoTablas, %STR(|)));
					%IF %SCAN(&listadoTablas, &iRCsub, %STR(|)) EQ &tablaErrorAct %THEN
					%DO;
						%LET tablaErrorAct =&tablaErrorAct (Por PID: %SCAN(&listadoBloqueos, &iRCsub, %STR(|)));
					%END;
				%END;
			%END;

			%LET listado		=&listado<li>&edoDesc &tablaErrorAct</li>;
		%END;

		%LET tablasErrores		=%STR();
		%LET codigoErrores		=%STR();

		%CREAR_SECCION(ColorEncabezado		=%STR(#b80b19),
						TituloEncab		=%STR(ERRORES POR TABLA/ARCHIVO),
						ListaOpciones	=&listado,
						Colector		=seccionBloqueos);
	%END;

	%LET cuerpoHTML = "<html><body><table width='600' cellpadding='0' cellspacing='0' border='0' style='font-family: Arial, sans-serif; font-size:14px; color:#000000; background-color:#DBF2FF;'><tr><td align='center' style='font-size:24px; font-weight:bold; padding:20px 0; background-color:#213A71; color:#FFFFFF;'>&tablaBase</td></tr><tr><td style='padding:5px 10px;'><strong>Hora de inicio:</strong> &timestIniTxt</td></tr><tr><td style='padding:5px 10px;'><strong>Hora final:</strong> &timestFinTxt</td></tr><tr><td style='padding:5px 10px;'><strong>Tiempo total de ejecucion: </strong> &horasEjec &unidad</td></tr><tr><td style='padding:5px 10px;'><strong>Version respaldo:</strong> &ultTabResp</td></tr><tr><td style='padding:5px 10px;'><strong>Estado:</strong> &estado</td></tr><tr><td style='padding-bottom:20px;'><br></td></tr><tr><td style='padding:5px 10px;'>Servidor &SYSTCPIPHOSTNAME y proceso &SYSJOBID</td></tr><tr><td style='padding-bottom:20px;'><br></td></tr><tr><td style='padding:5px 10px;'>Renglones previos a insercion: &CantPrev</td></tr><tr><td style='padding:5px 10px;'>Renglones posteriores a insercion: &CantPost</td></tr><tr><td style='padding-bottom:30px;'><br></td></tr>%SUPERQ(seccionErrores)%SUPERQ(seccionBloqueos)%SUPERQ(seccionUsuarioD)</table></body></html>";

	%IF &bloqueos NE 0 %THEN
	%DO;
		%SYSCALL PRXFREE(patronTabla);
		%SYSCALL PRXFREE(patronProceso);
	%END;

	/* Determinar si se adjunta el log */
	%IF %LENGTH(%SUPERQ(RutaLog)) GT 0 AND %SYSFUNC(FILEEXIST(%SUPERQ(RutaLog))) %THEN
		%ENVIO_MAIL(DESTINO         ="david.velazquez@profuturo.com.mx",
					Remitente       ="DEDA@CRONTABS.CAWN",
                    Asunto          ="Carga en tabla &tablaBase",
                    MSG             =&cuerpoHTML,
                    Adjunto         ="&RutaLog",
                    ContenidoHTML   =1);
	%ELSE
		%ENVIO_MAIL(DESTINO         ="david.velazquez@profuturo.com.mx",
					Remitente       ="DEDA@CRONTABS.CAWN",
                    Asunto          ="Carga en tabla &tablaBase",
                    MSG             =&cuerpoHTML,
                    ContenidoHTML   =1);
%MEND REDACTAR_CORREO;

/*Esta funcion se utiliza para armar listas HTML del correo*/
/*TIPO: Privada*/
/*REQUIERE: Nada*/
/*RESULTADO:  listado HTML*/
%MACRO LISTA_HTML();
	
%MEND LISTA_HTML;

/*Esta funcion se utiliza para armar secciones HTML del correo*/
/*TIPO: Privada*/
/*REQUIERE: Nada*/
/*RESULTADO:  seccion HTML con formato*/
%MACRO CREAR_SECCION(ColorEncabezado	=/*Por defecto es color negro, enviado con %STR*/%STR(#000000),
						TituloEncab		=/*Como se llamará la sección*/,
						ListaOpciones	=/*Contenido de la sección*/,
						Colector		=/*Donde se pondrá el contenido HMTL*/);

	%LET secHtml	=%STR(<tr><td style=%'color:)&ColorEncabezado%STR(; font-weight:bold; font-size:18px; padding:5px 10px;%'>)&TituloEncab%STR(:</td></tr>);
	%LET secHtml	=%SUPERQ(secHtml)%STR(<tr><td><ul style=%'margin-top:0; margin-bottom:0; padding-left:30px;%'>)%SUPERQ(ListaOpciones)%STR(</ul></td></tr>);

	%LET &Colector	=%SUPERQ(secHtml);
%MEND CREAR_SECCION;