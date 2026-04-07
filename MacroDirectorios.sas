
/*Esta funcion se utiliza para leer un directorio y sus archivos*/
/*TIPO: Privada*/
/*REQUIERE: Nada*/
/*RESULTADO:  Tabla de archivo*/
%MACRO LEER_RUTA(Ruta			=/*CON COMILLAS DOBLES, donde se leeran los archivos*/,
					FechaVerif	=/*Date despues de la cual se debieron crear los archivos, formato DATE con comillas dobles, por ejemplo "01JAN2024"d concatenada con el operador | seguida de un operador lógico*/%STR(),
					PropVerif	=/*SIN COMILLAS, si se desea que pertenezcan a un propietario específico, concatenada con | y un operador logico*/%STR());
	%LET Ruta		=%SYSFUNC(TRANSLATE(&Ruta,%STR(%'),%STR(%")));

	%LET condFecha	=%STR();
	%LET condProp	=%STR();

	%LET opLogAnd	=%STR();

	PROC FORMAT;
		VALUE $MESES_NUM
			"jan" = "01"
			"feb" = "02"
			"mar" = "03"
			"apr" = "04"
			"may" = "05"
			"jun" = "06"
			"jul" = "07"
			"aug" = "08"
			"sep" = "09"
			"oct" = "10"
			"nov" = "11"
			"dec" = "12";
	RUN;

	FILENAME dirlist PIPE "ls -lh &Ruta";

	DATA WORK.ARCHIVOS_EN_DIR (DROP = linea);
		LENGTH linea $500;

		INFILE dirlist TRUNCOVER;
		INPUT linea $CHAR500.;

		IF NOT PRXMATCH("/^total\s+\d+/i", linea) THEN
		DO;
			/*IA: El formato del comando ls -l es:
			Permisos | Cantidad de links | Propietario | Grupo | Tamaño | Fecha y hora de última modificación | Nombre del archivo*/

			Permisos		= SCAN(linea, 1, ' ');
			Links			= SCAN(linea, 2, ' ');
			Propietario		= SCAN(linea, 3, ' ');
			Grupo     		= SCAN(linea, 4, ' ');
			Tamanio    		= SCAN(linea, 5, ' ');

			IF PRXMATCH("/\d{2}:\d{2}/", SCAN(linea, 8, ' ')) THEN
			DO;
				Fecha 		= INPUT(CATX(" ", SCAN(linea, 7, ' '), PUT(LOWCASE(SCAN(linea, 6, ' ')), $MESES_NUM.), YEAR(TODAY())), ANYDTDTE.);
				FORMAT Fecha DATE9.;
			END;
			ELSE
			DO;
				Fecha 		= INPUT(CATX(" ", SCAN(linea, 7, ' '), PUT(LOWCASE(SCAN(linea, 6, ' ')), $MESES_NUM.), SCAN(linea, 8, ' ')), ANYDTDTE.);
				FORMAT Fecha DATE9.;
			END;

			Archivo   			= SCAN(linea, 9, ' ');

			%IF %LENGTH(&FechaVerif) GT 0 %THEN
			%DO;
				%LET condFecha	 =%STR(FECHA) %SCAN(&FechaVerif, 2, %STR(|)) %SCAN(&FechaVerif, 1, %STR(|));
			%END;

			%IF %LENGTH(&PropVerif) GT 0 %THEN
			%DO;
				%LET condProp	 =%STR(PROPIETARIO) %SCAN(&PropVerif, 2, %STR(|)) "%SCAN(&PropVerif, 1, %STR(|))";
			%END;

			%IF (%LENGTH(%SCAN(&FechaVerif, 2, %STR(|))) GT 0 AND %LENGTH(&condProp) GT 0) %THEN
			%DO;
				%LET opLogAnd = %STR(AND);
			%END;

			%IF %LENGTH(&condFecha) GT 0 OR %LENGTH(&condProp) GT 0 %THEN
			%DO;
				IF &condFecha &opLogAnd &condProp THEN
				DO;
					OUTPUT;
				END;
			%END;
			%ELSE
			%DO;
				OUTPUT;
			%END;
		END;
	RUN;
%MEND LEER_RUTA;

/*Esta funcion se utiliza para crear un directorio*/
/*TIPO: Publica*/
/*REQUIERE: Nada*/
/*RESULTADO:  Directorio en la ruta especificada*/
%MACRO CREAR_DIRECTORIO(Ruta		=/*CON COMILLAS DOBLES, donde se creara el directorio, por defecto es /data/Macros necesarios/Resultados*/"/data/Macros necesarios/Resultados/",
						Folder		=/*CON COMILLAS DOBLES, como se llamará el folder*/,
						Colector	=/*Donde se depositara el resultado*/);
	
	DATA _NULL_;
		LENGTH rutaBase folder $300;

		rutaBase		=&Ruta;
		folder			=&Folder;

		resultCreacion	=dcreate(folder,rutaBase);

		PUT resultCreacion=;

		IF NOT MISSING(resultCreacion) THEN
		DO;
			CALL SYMPUT("&Colector","1");
		END;
		ELSE
		DO;
			CALL SYMPUT("&Colector","0");
		END;
	RUN;
%MEND CREAR_DIRECTORIO;

/*Esta funcion se verifica la existencia de un directorio*/
/*TIPO: Publica*/
/*REQUIERE: Nada*/
/*RESULTADO:  0 si la carpeta no existe y 1 si existe*/
%MACRO VERIFICAR_EXISTENCIA(Ruta			=/*CON COMILLAS DOBLES, ruta completa con todo y directorio*/,
							ColectorExis	=/*Donde se depositara el resultado*/);
	DATA _NULL_;
		/*NOTA: El alias (direc) en este caso no debe pasar los 8 caracteres*/
		ptr			=FILENAME('direc', &Ruta);
		existe		=DOPEN('direc');

		PUT existe=;

		IF existe GT 0 THEN
		DO;
			CALL SYMPUT("&ColectorExis","1");
			ptr	=DCLOSE(existe);
		END;
		ELSE
		DO;
			CALL SYMPUT("&ColectorExis","0");
		END;

		ptr = filename('direc');
	RUN;
%MEND VERIFICAR_EXISTENCIA;

/*Esta funcion se elimina un directorio del sistema*/
/*TIPO: Publica*/
/*REQUIERE: Nada*/
/*RESULTADO: Borra el directorio especificado*/
%MACRO BORRAR_DIRECTORIO(Ruta 		=/*CON COMILLAS DOBLES, ruta completa con todo y directorio*/);
	%LET Ruta	=%SYSFUNC(TRANSLATE(&Ruta,%STR(%'),%STR(%")));

	X "rm -rf &Ruta";
%MEND BORRAR_DIRECTORIO;