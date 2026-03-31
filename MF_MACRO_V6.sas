/*==============================================================================
  MACRO: BITACORA - VERSI�N NUEVA Y SIMPLIFICADA
  Prop�sito: Registrar autom�ticamente informaci�n de operaciones en tabla BITACORA
  Uso: %bitacora(concepto=Tu descripcion, tabla=NOMBRE.TABLA);
==============================================================================*/

%macro bitacora(concepto=, tabla=, bitacora=MDCAPIT.BITACORA);

    /* ===== VALIDACIONES B�SICAS ===== */
    %if %length(&concepto) = 0 %then %do;
        %put ERROR: Debes especificar el CONCEPTO de la operacion;
        %return;
    %end;
    
    %if %length(&tabla) = 0 %then %do;
        %put ERROR: Debes especificar la TABLA afectada;
        %return;
    %end;

    %if not %sysfunc(exist(&tabla)) %then %do;
        %put ERROR: La tabla &tabla no existe;
        %return;
    %end;

    %if not %sysfunc(exist(&bitacora)) %then %do;
        %put ERROR: La tabla BITACORA &bitacora no existe;
        %return;
    %end;

    /* ===== VARIABLES LOCALES ===== */
    %local concepto_clean tabla_clean fecha_ejec usuario;
    %local registros_actuales columnas_actuales;
    %local registros_anteriores registros_cargados;
    %local columnas_originales id_siguiente;
    
    /* Limpiar y preparar variables */
    %let concepto_clean = %sysfunc(compress(&concepto, '"'));
    %let tabla_clean = %upcase(&tabla);
    %let fecha_ejec = %sysfunc(datetime());
    %let usuario = &sysuserid;

    /* ===== OBTENER INFO DE LA TABLA ACTUAL ===== */
    /* M�todo simple: usar PROC CONTENTS */
    proc contents data=&tabla noprint out=work._temp_contents;
    run;

    /* Contar registros de la tabla actual */
    %let registros_actuales = 0;
    data _null_;
        if 0 then set &tabla nobs=count;
        call symputx('registros_actuales', count);
        stop;
    run;

    /* Contar columnas (excluyendo campos de control) */
    proc sql noprint;
        select count(*) - sum(case when upcase(name) in ('SN_VIGENCIA', 'NB_USU_CAR', 'FE_CARGA') then 1 else 0 end)
        into :columnas_actuales
        from work._temp_contents;
    quit;

    /* Limpiar tabla temporal */
    proc datasets library=work nolist;
        delete _temp_contents;
    quit;

    /* ===== OBTENER INFO DE REGISTROS ANTERIORES ===== */
    /* Buscar �ltimo registro de esta tabla en la bit�cora */
    proc sql noprint;
        select 
            coalesce(max(REGISTRO_FIN), 0),
            coalesce(max(COLUMNAS_ORIGEN), &columnas_actuales)
        into 
            :registros_anteriores,
            :columnas_originales
        from &bitacora
        where upcase(strip(TABLA_AFECTADA)) = strip("&tabla_clean");
    quit;

    /* ===== OBTENER PR�XIMO ID ===== */
    proc sql noprint;
        select coalesce(max(ID_BITACORA), 0) + 1
        into :id_siguiente
        from &bitacora;
    quit;

    /* ===== VALIDAR Y CONVERTIR VALORES ===== */
    /* Asegurar que tenemos n�meros v�lidos */
    %if &registros_actuales = %then %let registros_actuales = 0;
    %if &columnas_actuales = %then %let columnas_actuales = 0;
    %if &registros_anteriores = %then %let registros_anteriores = 0;
    %if &columnas_originales = %then %let columnas_originales = &columnas_actuales;
    %if &id_siguiente = %then %let id_siguiente = 1;

    /* Calcular registros cargados */
    data _null_;
        registros_cargados = max(0, &registros_actuales - &registros_anteriores);
        call symputx('registros_cargados', registros_cargados);
    run;

    /* ===== INSERTAR EN BIT�CORA ===== */
    data work._temp_insert;
        ID_BITACORA = &id_siguiente;
        CONCEPTO_OP = "&concepto_clean";
        TABLA_AFECTADA = "&tabla_clean";
        REGISTRO_CARGADO = &registros_cargados;
        COLUMNAS_ORIGEN = &columnas_originales;
        REGISTRO_FIN = &registros_actuales;
        COLUMNAS_FIN = &columnas_actuales;
        USUARIO_CARGA = "&usuario";
        FECHA_EJEC = &fecha_ejec;
        format FECHA_EJEC datetime20.;
        output;
    run;

    /* Agregar a la bit�cora */
    proc append base=&bitacora data=work._temp_insert force;
    run;

    /* Limpiar tabla temporal */
    proc datasets library=work nolist;
        delete _temp_insert;
    quit;

    /* ===== MOSTRAR CONFIRMACI�N ===== */
    %put ;
    %put ==============================================;
    %put REGISTRO GUARDADO EN BITACORA;
    %put ==============================================;
    %put ID Bit�cora: &id_siguiente;
    %put Fecha Ejecuci�n: %sysfunc(putn(&fecha_ejec, datetime20.));
    %put Concepto: &concepto_clean;
    %put Tabla Afectada: &tabla_clean;
    %put Registros Cargados: &registros_cargados;
    %put Registros Totales: &registros_actuales;
    %put Columnas Actuales: &columnas_actuales;
    %put Usuario: &usuario;
    %put ==============================================;
    %put ;

    /* Mostrar �ltimos registros */
    /*proc print data=&bitacora(obs=5) noobs;
        var ID_BITACORA FECHA_EJEC CONCEPTO_OP TABLA_AFECTADA REGISTRO_CARGADO REGISTRO_FIN;
        format FECHA_EJEC datetime20.;
        title3 "�ltimos 5 registros en &bitacora";
    run;
    title3;*/

%mend bitacora;

/*==============================================================================
  EJEMPLOS DE USO:
  
  %bitacora(concepto=Carga inicial de datos, tabla=WORK.CLIENTES);
  
  %bitacora(concepto=Actualizaci�n mensual, tabla=MYLIB.VENTAS_2024, 
                  bitacora=MDCAPIT0.BITACORA);
  
==============================================================================*/