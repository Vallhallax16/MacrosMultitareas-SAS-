%MACRO DECLARAR_FUNCIONES(Libreria   =/*Donde se va a depositar la tabla de funciones*/);
	PROC FCMP OUTLIB = &Libreria..FUNC.FECHAS;
		/*SENTIDO 0: YYYYDDMM*/
		/*SENTIDO 1: DDMMYYYY*/
		/*SENTIDO 2: MMDDYYYY*/
		FUNCTION ArmarMDY(cadena $, sentido);
			IF 		sentido EQ 0 THEN
			DO;
				annioPos 	= 1;
				mesPos		= 5;
				diaPos		= 7;
			END;
			ELSE IF sentido EQ 1 THEN
			DO;
				annioPos 	= 5;
				mesPos		= 3;
				diaPos		= 1;
			END;
			ELSE IF sentido EQ 2 THEN
			DO;
				annioPos 	= 5;
				mesPos		= 1;
				diaPos		= 3;
			END;

			annio 	= INPUT(SUBSTR(cadena,annioPos,4),BEST8.);
			mes		= INPUT(SUBSTR(cadena,mesPos,2),BEST8.);
			dia		= INPUT(SUBSTR(cadena,diaPos,2),BEST8.);

			RETURN (mdy(mes, dia, annio));
		ENDSUB;

		FUNCTION CadenaAnnioCorrecto(cadena $, annioBase);
			annioParcial = INPUT(SCAN(cadena,3,"/"),BEST8.);
							annioParcial = annioBase + annioParcial;

			cadena = TRANWRD(cadena,
							CATS("/",SCAN(cadena,3,"/")),
							STRIP(PUT(annioParcial,Best32.)));

			RETURN (cadena);
		ENDSUB;

		FUNCTION EquivalenciaMes(mesTxt $);
			LENGTH Equivlencia $2;

			SELECT (strip(upcase(mesTxt)));
				WHEN ("ENERO")        Equivalencia = "01";
				WHEN ("FEBRERO")      Equivalencia = "02";
				WHEN ("MARZO")        Equivalencia = "03";
				WHEN ("ABRIL")        Equivalencia = "04";
				WHEN ("MAYO")         Equivalencia = "05";
				WHEN ("JUNIO")        Equivalencia = "06";
				WHEN ("JULIO")        Equivalencia = "07";
				WHEN ("AGOSTO")       Equivalencia = "08";
				WHEN ("SEPTIEMBRE")   Equivalencia = "09";
				WHEN ("OCTUBRE")      Equivalencia = "10";
				WHEN ("NOVIEMBRE")    Equivalencia = "11";
				WHEN ("DICIEMBRE")    Equivalencia = "12";
			END;

			RETURN (Equivalencia);
		ENDSUB;

		/*1F. INVOCABLE: Convierte una fecha en su equivalente numerico formateada en DATE9.*/
		FUNCTION StringAFecha(cadena $);
			/*TODO LO CONTENIDO EN LA STRING ES NUMERO DEL TIPO YYYYMMDD*/
			IF NOTDIGIT(cadena) EQ 0 THEN
			DO;
				fecha = ArmarMDY(cadena, 0);
			END;
			ELSE
			DO;
				/*LA STRING ES DEL TIPO DD-MM-YYYY*/
				IF 		FIND(cadena,"-") > 0 THEN
				DO;
					fecha = ArmarMDY(PRXCHANGE("s/-//",-1,cadena), 1);
				END;
				/*LA STRING ES DEL TIPO DD/MM/YYYY*/
				ELSE IF FIND(cadena,"/") > 0 THEN
				DO;
					/*LA STRING ES DEL TIPO DD/MESTXT/YYYY*/
					IF NOTDIGIT(SCAN(cadena,2,"/")) NE 0 THEN
					DO;
						mesTxt 	= SCAN(cadena,2,"/");
						mes		= EquivalenciaMes(mesTxt);

						cadena = PRXCHANGE(CATS("s/",mesTxt,"/",mes,"/"), -1, cadena);

						fecha = ArmarMDY(PRXCHANGE("s/\///",-1,cadena), 1);
					END;
					/*LA STRING ES DEL TIPO DD/MM/YYYY O DD/MM/YY*/
					ELSE
					DO;
						/*LA STRING ES DEL TIPO DD/MM/YYYY*/
						IF LENGTH(SCAN(cadena,3,"/")) EQ 4 				THEN
						DO;
							fecha = ArmarMDY(PRXCHANGE("s/\///",-1,cadena), 1);
						END;
						/*EL ANNIO ESTA COMPRENDIDO ENTRE 1970 y 1999*/
						ELSE IF INPUT(SCAN(cadena,3,"/"),BEST8.) >= 70 	AND
							INPUT(SCAN(cadena,3,"/"),BEST8.) >= 99 		THEN
						DO;
							cadena = CadenaAnnioCorrecto(cadena, 1900);

							fecha = ArmarMDY(PRXCHANGE("s/\///",-1,cadena), 1);
						END;
						ELSE
						DO;
							cadena = CadenaAnnioCorrecto(cadena, 2000);

							fecha = ArmarMDY(PRXCHANGE("s/\///",-1,cadena), 1);
						END;
					END;
				END;
				/*LA STRING ES DEL TIPO DD DE MESTXT DE YYYY*/
				ELSE
				DO;
					LENGTH mes2 $3;

					dia 	= SCAN(cadena,1," ");
					mes 	= EquivalenciaMes(SCAN(cadena,3," "));
					annio	= SCAN(cadena,5," ");
				
					IF mes < 10 THEN
						mes2 = CATS("0",mes);
					ELSE
						mes2 = STRIP(PUT(mes,BEST32.));

					fecha = ArmarMDY(CATS(dia,mes2,annio), 1);
				END;
			END;

			RETURN(fecha);
		ENDSUB;
	RUN;
%MEND ;