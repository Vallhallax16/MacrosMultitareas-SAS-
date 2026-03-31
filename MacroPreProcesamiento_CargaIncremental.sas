Option Fullstimer;

OPTIONS SET = NLS_LANG="SPANISH_SPAIN.WE8ISO8859P1";

/* INICIO - Inclusión de Macros necesarios*/
%INCLUDE '/data/Macros necesarios/MacroMailer.sas';
/* FIN - Inclusión de Macros necesarios*/

%LET tablasErrores	      =%STR();
%LET codigoErrores	      =%STR();

%LET timestInicial	= 0;
%LET timestFinal	   = 0;
%LET bloqueos        = 0;
%LET ultTabResp      =%STR();

/* INICIO - VARIABLES CONTROL PARA MACROS */
%LET errorTotal		       = 0;
/* FIN - VARIABLES CONTROL PARA MACROS */

%MACRO ASIGNAR_FUENTES(FuenteParticular      = /*Especificar una en particular, de lo contrario se asignarán todas con 0*/0);
   %LET asignaciones =MDCAPIT "/data/MD Capital Humano/"|PEOPLE_A "/data/MD Capital Humano/";

   %IF &FuenteParticular EQ 0 %THEN
   %DO;
      %DO iAF = 1 %TO %SYSFUNC(COUNTW(&asignaciones,%STR(|)));
	      LIBNAME %SCAN(&asignaciones, &iAF, %STR(|)); 
      %END;
   %END;
   %ELSE %IF &FuenteParticular EQ 1 %THEN
   %DO;
      LIBNAME %SCAN(&asignaciones, 1, %STR(|)); 
   %END;
   %ELSE %IF &FuenteParticular EQ 2 %THEN
   %DO;
      LIBNAME %SCAN(&asignaciones, 2, %STR(|)); 
   %END;
%MEND %ASIGNAR_FUENTES;

/*Env�o de tablas origen no disponibles*/
%macro NotificacionSinDisponibilidad(Tabla);
   %LET argEvalTabla          =%SYSFUNC(COMPRESS(&Tabla,'"'));

   %IF %INDEX(&argEvalTabla,%STR(/)) > 0 %THEN
   %DO;
      %LET Tabla                    =&argEvalTabla;

      %LET tablasErrores            =&tablasErrores%STR(|)&Tabla;

      %LET codigoErrores            =&codigoErrores%STR(|)-2;
   %END;
   %ELSE
   %DO;
      %LET tablasErrores          =&tablasErrores%STR(|)&Tabla;

      %LET codigoErrores          =&codigoErrores%STR(|)-3;
   %END;   
%mend NotificacionSinDisponibilidad;

%MACRO NotificacionBloqueo(TablaOrigen    =);
   %LET tablasErrores          =&tablasErrores%STR(|)&TablaOrigen;

   %LET codigoErrores          =&codigoErrores%STR(|)-4;
%MEND NotificacionBloqueo;

/*Env�o de tablas origen no disponibles*/
%macro NotificacionSinDatos(Tabla);
   %LET tablasErrores          =&tablasErrores%STR(|)&Tabla;

   %LET codigoErrores          =&codigoErrores%STR(|)-1;
%mend NotificacionSinDatos;

%MACRO ErrorTotal();
   %LET errorTotal = %EVAL(&errorTotal + 1);
%MEND ErrorTotal;

/*Validaci�n de Insumos*/
%macro etls_ValidaOrigenes(TablaOrigen); 
	/*Valida existencia de la tabla*/
	%let etls_tableExist = %eval(%sysfunc(exist(&TablaOrigen, DATA)) or 
         %sysfunc(exist(&TablaOrigen, VIEW))); 

	/*Si la tabla no existe genera error*/
	%if (&etls_tableExist eq 0) %then %do;
      %ErrorTotal();

		%NotificacionSinDisponibilidad(&TablaOrigen);

      %RETURN;
	%end; /*Si la tabla no existe genera error*/

   LOCK &TablaOrigen;

    %IF &SYSLCKRC NE 0 %THEN
    %DO;
        %ErrorTotal();

        %LET bloqueos      =%EVAL(&bloqueos + 1);

        %NotificacionBloqueo(TablaOrigen = &TablaOrigen);

        %RETURN;
    %END;

   LOCK &TablaOrigen CLEAR;

   %if (&etls_tableExist ne 0) %then %do;
      proc sql noprint;
         select count(*) into :etls_recnt from &TablaOrigen;
      quit;

	  /*Valida registros*/
	  %if (&etls_recnt eq 0) %then %do;
      %ErrorTotal();

	  	%NotificacionSinDatos(&TablaOrigen);

      %RETURN;
	  %end;	/*Valida registros*/
	%end;

%mend etls_ValidaOrigenes;

/*Valida si el archivo existe*/
%macro check_file_existence(filepath);
  %if %sysfunc(fileexist(&filepath)) %then %do;
    %put The file &filepath exists.;
    /* Add your code here to process the existing file */
  %end;
  %else %do;
    %ErrorTotal();

    %NotificacionSinDisponibilidad(&filepath);

    %RETURN;
  %end;
%mend check_file_existence;

%MACRO INICIO_LOG(RutaLogs          =/*Para una ruta particular por defecto es /data/Macros necesarios/Logs*/%STR(/data/Macros necesarios/Logs/),
                  DistintivoExtra   =/*Para identificar mejor el archivo*/%STR(),
                  Colector          =/*Variable que recibirá el valor*/);
   %LET &Colector       = %SYSFUNC(DATETIME());
   %LET patronTabla 		= %SYSFUNC(PRXPARSE(s/^.*\.//));
   %LET soloTabla       = %SYSFUNC(PRXCHANGE(&patronTabla, -1, &tablaBase));

   %LET ruta         =&RutaLogs&soloTabla.&DistintivoExtra..log;
   
   PROC PRINTTO LOG  = "&ruta" NEW;
   RUN;
%MEND INICIO_LOG;

%MACRO FIN_LOG(Colector             =/*Variable que recibirá el valor*/);
   %LET &Colector       = %SYSFUNC(DATETIME());

   PROC PRINTTO;
   RUN;
%MEND FIN_LOG;