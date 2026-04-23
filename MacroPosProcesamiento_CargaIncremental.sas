Option Fullstimer;

OPTIONS SET = NLS_LANG="SPANISH_SPAIN.WE8ISO8859P1";

%INCLUDE '/data/Macros necesarios/MacroMailer.sas';
%INCLUDE '/data/Macros necesarios/MacroDirectorios.sas';

%MACRO REPORTAR_EJECUCION(RutaLogs      =/*Para una ruta particular, por defecto es /data/Macros necesarios/Logs*/%STR(/data/Macros necesarios/Logs/),
							Archivo		=/*SIN comillas, nombre del archivo Log a leer, soporta LIBRERIA.NOMBRE*/,
							NivelDebug	=/*Soporta NOTE, WARNING, ERROR o TODOS, por defecto es ERROR, de ser varios separar por espacio y SIN comillas*/ERROR,
							TituloRep	=/*Titulo que llevará el reporte*/%STR(),
							FuenteBit	=/*Donde se tomará la cifra inicial de registros*/%STR(),
							CampoBit	=/*Campo que se tomará para la cifra inicial de registros*/%STR(),
							RutaArch	=/*Ruta donde se revisarán los archivos creados, CON comillas*/%STR(),
							Destinos	=/*Por defecto es solo a david.velazquez@profuturo.com.mx*/"david.velazquez@profuturo.com.mx");
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
		%IF %LENGTH(%SUPERQ(TituloRep)) GT 0 %THEN
		%DO;
			SELECT
				T.&CampoBit
			INTO
				:CANTIDAD_PREVIOS
			FROM
				&FuenteBit T;

			%BORRAR_TABLA_DE_PASO(NombreTabla	= TODAS);
		%END;
		%ELSE
		%DO;
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
		%END;
	QUIT;

	PROC SQL NOPRINT;
		SELECT
			COUNT(*)
		INTO
			:CANTIDAD_POSTERIORES
		FROM
			&tablaBase T;
	QUIT;

	%IF %LENGTH(%SUPERQ(TituloRep)) EQ 0 %THEN
	%DO;
		%REDACTAR_CORREO(TextosRecuperados		= %SUPERQ(informacionDebugSas),
							TextosDebug			= %SUPERQ(informacionCapturada),
							CantPrev           	= &CANTIDAD_PREVIOS,
							CantPost           	= &CANTIDAD_POSTERIORES,
							PatronReemplazo    	= &esqueletoPatronRem,
							TimestIni          	= &timestInicial,
							TimestFin          	= &timestFinal,
							RutaLog				= &rutaCompleta,
							CorreoDestinos		= &Destinos);
	%END;
	%ELSE
	%DO;
		%REDACTAR_CORREO(TextosRecuperados		= %SUPERQ(informacionDebugSas),
							TextosDebug			= %SUPERQ(informacionCapturada),
							CantPrev           	= &CANTIDAD_PREVIOS,
							CantPost           	= &CANTIDAD_POSTERIORES,
							PatronReemplazo    	= &esqueletoPatronRem,
							TimestIni          	= &timestInicial,
							TimestFin          	= &timestFinal,
							RutaLog				= &rutaCompleta,
							TituloReporte		= &TituloRep,
							DirectorioArch		= &RutaArch,
							CorreoDestinos		= &Destinos);
	%END;
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
						RutaLog				=/*Ruta del archivo Log analizado, para adjuntarlo al correo*/,
						TituloReporte		=/*Título del reporte*/%STR(),
						DirectorioArch		=/*Donde se revisarán los archivos creados*/%STR(),
						CorreoDestinos		=/*Destinatarios del correo, por defecto es solo a david.velazquez*/);	
	%LET listado				=%STR();

	%LET estado					=%STR();

	%LET timestIniTxt			=%SYSFUNC(PUTN(&TimestIni,DATETIME20.));

	%LET timestFinTxt			=%SYSFUNC(PUTN(&TimestFin,DATETIME20.));

	%LET horasEjec				=%SYSEVALF(&TimestFin - &TimestIni);
	%LET horasEjec				=%SYSFUNC(FLOOR(&horasEjec));

	%LET colorTabFondo			=%STR();
	%LET colorTxtTd				=%STR();
	%LET colorFndTd				=%STR();

	%LET tituloTabla			=%STR();

	%LET remitenteDEDA			=%STR();

	%LET asuntoCorreo			=%STR();	

	%LET estadisRespaldo		=%STR();	

	%IF %SYMEXIST(CANTIDAD_POSTERIORES) EQ 0 %THEN
		%LET CANTIDAD_POSTERIORES=Sin datos;
	
	%IF %SYMEXIST(CANTIDAD_PREVIOS) EQ 0 %THEN
		%LET CANTIDAD_PREVIOS	=Sin datos;

	%IF %SYMEXIST(ultTabResp) EQ 0 %THEN
		%LET ultTabResp		=Sin respaldos;

	%LET unidad					="";

	%CALCULO_TIEMPO_EJEC(HorasEjec				=&horasEjec,
							ContenedorHorEje	=horasEjec,
							ContenedorUnidad	=unidad);

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
				%LET codigoDeBloqueo	= %QSYSFUNC(PRXPOSN(&patronProceso, 1, %SUPERQ(textoActual)));
				%LET listadoBloqueos	=&listadoBloqueos%STR(|)&codigoDeBloqueo;
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
	%LET seccionArchivos		=%STR();

	%IF %LENGTH(%SUPERQ(listado)) GT 0 %THEN
	%DO;
		%CREAR_SECCION(ColorEncabezado		=%STR(#b80b19),
							TituloEncab		=ERRORES,
							ListaOpciones	=&listado,
							Colector		=seccionErrores);
	%END;

	%IF %LENGTH(%SUPERQ(TituloReporte)) GT 0 %THEN
	%DO;
		%LET colorTabFondo		=%STR(#fdffdb);
		%LET colorTxtTd			=%STR(#FFFFFF);
		%LET colorFndTd			=%STR(#717121);

		%LET tituloTabla		=&TituloReporte;

		%LET remitenteDEDA		="DEDA@REPORTES.CAWN";

		%LET asuntoCorreo		="Resumen &TituloReporte";

		%IF %LENGTH(%SUPERQ(DirectorioArch)) GT 0 %THEN
		%DO;
			%LEER_RUTA(Ruta			=&DirectorioArch);

			PROC SQL NOPRINT;
				SELECT
					COUNT(*)
				INTO
					:CONTEO_ARCHIVOS
				FROM
					WORK.ARCHIVOS_EN_DIR;
			QUIT;

			%IF &CONTEO_ARCHIVOS NE 0 %THEN
			%DO;
				PROC SQL NOPRINT;
					SELECT
						T.Archivo
					INTO
						:LISTADO_ARCH_FIS SEPARATED BY %STR(|)
					FROM
						WORK.ARCHIVOS_EN_DIR T;
				QUIT

				PROC SQL NOPRINT;
					SELECT 
						T.Tamanio
					INTO
						:LISTADO_TAM_ARCH SEPARATED BY %STR(|)
					FROM
						WORK.ARCHIVOS_EN_DIR T;
				QUIT;

				%DO iRC = 1 %TO &CONTEO_ARCHIVOS;
					%LET archivoActual	=%QSCAN(%SUPERQ(LISTADO_ARCH_FIS), &iRC, %STR(|));
					%LET tamArchivoAct	=%SCAN(&LISTADO_TAM_ARCH, &iRC, %STR(|));

					%LET listado	=&listado<li>&archivoActual - &tamArchivoAct.B</li>;
				%END;

				%CREAR_SECCION(ColorEncabezado		=%STR(#0bb87b),
								TituloEncab		=%STR(ARCHIVOS CREADOS:),
								ListaOpciones	=&listado,
								Colector		=seccionArchivos);
			%END;
		%END;
	%END;
	%ELSE
	%DO;
		%LET colorTabFondo		=%STR(#DBF2FF);
		%LET colorTxtTd			=%STR(#FFFFFF);
		%LET colorFndTd			=%STR(#213A71);

		%LET tituloTabla		=&tablaBase;

		%LET remitenteDEDA		="DEDA@CRONTABS.CAWN";

		%LET asuntoCorreo		="Carga en tabla &tablaBase";

		%LET estadisRespaldo	=%STR(<tr><td style='padding:5px 10px;'><strong>Version respaldo:</strong> )&ultTabResp%STR(</td></tr>);
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

	%LET estado								=%STR();

	%CALCULO_ESTADO(TimestIni				=&TimestIni,
						errorTotal			=&errorTotal,
						bloqueos			=&bloqueos,
						ColectorEdo			=estado);

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

	%LET cuerpoHTML = "<html><body><table width='600' cellpadding='0' cellspacing='0' border='0' style=%STR(%')font-family: Arial, sans-serif; font-size:14px; color:#000000; background-color:&colorTabFondo;%STR(%')><tr><td align='center' style=%STR(%')font-size:24px; font-weight:bold; padding:20px 0; background-color:&colorFndTd; color:#FFFFFF;%STR(%')>&tituloTabla</td></tr><tr><td style='padding:5px 10px;'><strong>Hora de inicio:</strong> &timestIniTxt</td></tr><tr><td style='padding:5px 10px;'><strong>Hora final:</strong> &timestFinTxt</td></tr><tr><td style='padding:5px 10px;'><strong>Tiempo total de ejecucion: </strong> &horasEjec &unidad</td></tr>%SUPERQ(estadisRespaldo)<tr><td style='padding:5px 10px;'><strong>Estado:</strong> &estado</td></tr><tr><td style='padding-bottom:20px;'><br></td></tr><tr><td style='padding:5px 10px;'>Servidor &SYSTCPIPHOSTNAME y proceso &SYSJOBID</td></tr><tr><td style='padding-bottom:20px;'><br></td></tr><tr><td style='padding:5px 10px;'>Renglones previos a insercion: &CantPrev</td></tr><tr><td style='padding:5px 10px;'>Renglones posteriores a insercion: &CantPost</td></tr><tr><td style='padding-bottom:30px;'><br></td></tr>%SUPERQ(seccionErrores)%SUPERQ(seccionBloqueos)%SUPERQ(seccionUsuarioD)%SUPERQ(seccionArchivos)</table></body></html>";

	%IF &bloqueos NE 0 %THEN
	%DO;
		%SYSCALL PRXFREE(patronTabla);
		%SYSCALL PRXFREE(patronProceso);
	%END;

	/* Determinar si se adjunta el log */
	%IF %LENGTH(%SUPERQ(RutaLog)) GT 0 AND %SYSFUNC(FILEEXIST(%SUPERQ(RutaLog))) %THEN
		%ENVIO_MAIL(DESTINO         =&CorreoDestinos,
					Remitente       =&remitenteDEDA,
                    Asunto          =&asuntoCorreo,
                    MSG             =&cuerpoHTML,
                    Adjunto         ="&RutaLog",
                    ContenidoHTML   =1);
	%ELSE
		%ENVIO_MAIL(DESTINO         =&CorreoDestinos,
					Remitente       =&remitenteDEDA,
                    Asunto          =&asuntoCorreo,
                    MSG             =&cuerpoHTML,
                    ContenidoHTML   =1);
%MEND REDACTAR_CORREO;

/*Esta funcion se utiliza para calcular el tiempo del correo y sus unidades*/
/*TIPO: Privada*/
/*REQUIERE: Nada*/
/*RESULTADO:  variables con unidad y tiempo total*/
%MACRO CALCULO_ESTADO(TimestIni		=/*Datetime de cuando inicia el proceso*/,
						errorTotal	=/*Cantidad total de errores en el proceso*/,
						bloqueos	=/*Cantidad total de bloqueos*/,
						ColectorEdo	=/*Variable donde se pondrá el estado resultante*/);
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
%MEND CALCULO_ESTADO;

/*Esta funcion se utiliza para calcular el tiempo del correo y sus unidades/
/*TIPO: Privada*/
/*REQUIERE: Nada*/
/*RESULTADO:  variables con unidad y tiempo total*/
%MACRO CALCULO_TIEMPO_EJEC(HorasEjec			=/*Tiempo total de ejecucion (VALOR)*/,
							ContenedorHorEje	=/*Donde se depositará el valor de horas*/,
							ContenedorUnidad	=/*Donde se depositará la unidad*/);							
	%IF &HorasEjec GE 3600 %THEN
	%DO;
		%LET &ContenedorUnidad	=horas;
		%LET &ContenedorHorEje	=%SYSEVALF(&HorasEjec / 3600);
	%END;
	%ELSE %IF &HorasEjec GE 60 %THEN
	%DO;
		%LET &ContenedorUnidad	=minutos;
		%LET &ContenedorHorEje	=%SYSEVALF(&HorasEjec / 60);
	%END;
	%ELSE
	%DO;
		%LET &ContenedorUnidad	=segundos;
		%LET &ContenedorHorEje	=&HorasEjec;
	%END;
%MEND CALCULO_TIEMPO_EJEC;

/*Esta funcion se utiliza para armar secciones HTML del correo*/
/*TIPO: Privada*/
/*REQUIERE: Nada*/
/*RESULTADO:  seccion HTML con formato*/
%MACRO CREAR_SECCION(ColorEncabezado	=/*Por defecto es color negro, enviado con %STR*/%STR(#000000),
						TituloEncab		=/*Como se llamará la sección*/,
						ListaOpciones	=/*Contenido de la sección, YA con etiquetas <li>*/,
						Colector		=/*Donde se pondrá el contenido HMTL*/);

	%LET secHtml	=%STR(<tr><td style=%'color:)&ColorEncabezado%STR(; font-weight:bold; font-size:18px; padding:5px 10px;%'>)&TituloEncab%STR(:</td></tr>);
	%LET secHtml	=%SUPERQ(secHtml)%STR(<tr><td><ul style=%'margin-top:0; margin-bottom:0; padding-left:30px;%'>)%SUPERQ(ListaOpciones)%STR(</ul></td></tr>);

	%LET &Colector	=%SUPERQ(secHtml);
%MEND CREAR_SECCION;

%MACRO REPORTE_PERSONALIZADO(TituloReporte	=/*Título principal del reporte, SIN comillas*/,
							ListaSecciones	=/*Lista de títulos de secciones separados por &Separador, SIN comillas*/,
							ListaValores	=/*Lista de valores correspondientes separados por &Separador, SIN comillas*/,
							Destinos		=/*Destinatario(s) del correo, CON comillas*/,
							Separador		=/*Separador de listas, por defecto |*/%STR(|),
							Remitente		=/*Remitente del correo, CON comillas*/"DEDA@REPORTES.CAWN");
	%LOCAL listadoItems conteoSecciones conteoValores seccionActual valorActual iRP;
	%LOCAL colorTabFondo colorFndEncab colorTxtEncab colorSeccion;
	%LOCAL cuerpoHTML asuntoCorreo seccionContenido timestActual;

	/* Definición de colores en tonos verdes */
	%LET colorTabFondo	= %STR(#d4f5e0);	/* Verde claro - fondo de tabla */
	%LET colorFndEncab	= %STR(#0b7d3e);	/* Verde oscuro - fondo encabezado */
	%LET colorTxtEncab	= %STR(#FFFFFF);	/* Blanco - texto encabezado */
	%LET colorSeccion	= %STR(#0b7d3e);	/* Verde oscuro - título de sección */

	/* Validar que las listas tengan la misma cantidad de elementos */
	%LET conteoSecciones	= %SYSFUNC(COUNTW(%SUPERQ(ListaSecciones), %SUPERQ(Separador)));
	%LET conteoValores		= %SYSFUNC(COUNTW(%SUPERQ(ListaValores), %SUPERQ(Separador)));

	%IF &conteoSecciones NE &conteoValores %THEN
	%DO;
		%PUT ERROR: La cantidad de secciones (&conteoSecciones) no coincide con la cantidad de valores (&conteoValores).;
		%PUT ERROR: Verifique que ambas listas tengan el mismo número de elementos.;
		%RETURN;
	%END;

	%IF &conteoSecciones EQ 0 %THEN
	%DO;
		%PUT ERROR: Las listas de secciones y valores están vacías.;
		%RETURN;
	%END;

	/* Construir la lista de items HTML */
	%LET listadoItems = %STR();

	%DO iRP = 1 %TO &conteoSecciones;
		%LET seccionActual	= %QSCAN(%SUPERQ(ListaSecciones), &iRP, %SUPERQ(Separador));
		%LET valorActual	= %QSCAN(%SUPERQ(ListaValores), &iRP, %SUPERQ(Separador));

		%LET listadoItems	= &listadoItems<li><strong>&seccionActual:</strong> &valorActual</li>;
	%END;

	/* Crear la sección de contenido usando el macro existente */
	%LET seccionContenido = %STR();

	%CREAR_SECCION(ColorEncabezado	= &colorSeccion,
					TituloEncab		= %STR(DETALLE DEL REPORTE),
					ListaOpciones	= &listadoItems,
					Colector		= seccionContenido);

	/* Obtener timestamp actual */
	%LET timestActual = %SYSFUNC(PUTN(%SYSFUNC(DATETIME()), DATETIME20.));

	/* Construir el asunto del correo */
	%LET asuntoCorreo = "Resumen &TituloReporte";

	/* Construir el cuerpo HTML del correo */
	%LET cuerpoHTML = "<html><body><table width='600' cellpadding='0' cellspacing='0' border='0' style=%STR(%')font-family: Arial, sans-serif; font-size:14px; color:#000000; background-color:&colorTabFondo;%STR(%')><tr><td align='center' style=%STR(%')font-size:24px; font-weight:bold; padding:20px 0; background-color:&colorFndEncab; color:&colorTxtEncab;%STR(%')>&TituloReporte</td></tr><tr><td style='padding:5px 10px;'><strong>Fecha de generacion:</strong> &timestActual</td></tr><tr><td style='padding:5px 10px;'><strong>Servidor:</strong> &SYSTCPIPHOSTNAME</td></tr><tr><td style='padding:5px 10px;'><strong>Proceso:</strong> &SYSJOBID</td></tr><tr><td style='padding-bottom:20px;'><br></td></tr>%SUPERQ(seccionContenido)<tr><td style='padding-bottom:20px;'><br></td></tr></table></body></html>";

	/* Enviar el correo */
	%ENVIO_MAIL(DESTINO			= &Destinos,
				Remitente		= &Remitente,
				Asunto			= &asuntoCorreo,
				MSG				= &cuerpoHTML,
				ContenidoHTML	= 1);

	%PUT NOTE: Reporte "&TituloReporte" enviado exitosamente a &Destinos;
%MEND REPORTE_PERSONALIZADO;