%MACRO EXPORT_GENERAL(TablaEntrante = /*Objeto SAS a exportar*/,
                      Ruta          = /*CON COMILLAS, Ruta del archivo saliente*/,
                      Motor         = /*SIN COMILLAS, CSV, XLSX, XLS o TXT*/,
                      Hoja          = /*Nombre de la hoja, solo XLSX o XLS*/,
                      Encabezados   = /*SIN COMILLAS, Emplear solo YES o NO*/,
                      Delimitador   = %STR()/*CON comilla simple, necesario para TXT*/);

    %LOCAL motorAct dbmsAct argSheet argDelim;

    %LET motorAct = %SYSFUNC(UPCASE(&Motor));

    %IF %SYSFUNC(EXIST(&TablaEntrante)) %THEN
    %DO;
        %IF "&motorAct" EQ "TXT" %THEN
        %DO;
            %LET dbmsAct = DLM;
        %END;
        %ELSE
        %DO;
            %LET dbmsAct = &motorAct;
        %END;

        %IF "&motorAct" EQ "XLSX" OR "&motorAct" EQ "XLS" %THEN
        %DO;
            %IF %LENGTH(&Hoja) GT 0 %THEN
            %DO;
                %LET argSheet = %STR(SHEET=)&Hoja%STR(;);
            %END;
            %ELSE
            %DO;
                %LET argSheet = %STR( );
            %END;
        %END;
        %ELSE
        %DO;
            %LET argSheet = %STR( );
        %END;

        %IF %LENGTH(&Delimitador) GT 0 %THEN
        %DO;
            %LET argDelim = %STR(DELIMITER=)&Delimitador%STR(;);
        %END;
        %ELSE
        %DO;
            %LET argDelim = %STR( );
        %END;

        PROC EXPORT
            DATA     = &TablaEntrante
            OUTFILE  = &Ruta
            DBMS     = &dbmsAct
            REPLACE;
            &argSheet;
            PUTNAMES = &Encabezados;
            &argDelim;
        RUN;
    %END;
%MEND EXPORT_GENERAL;