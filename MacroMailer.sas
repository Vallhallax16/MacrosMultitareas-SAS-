LIBNAME LIBBITAC "/data/DirTecNeg/Bitacoras/Tablas";

%MACRO ENVIO_MAIL(DESTINO           =/*Cada valor CON comillas y separado por espacio*/,
                    Remitente       =/*Quien envía el email, CON comillas*/"DEDA@PROFUTURO.COM.MX",
                    CC_DESTINO      =/*Cada valor CON comillas y separados por espacio ' '*/"NULO",
                    Asunto          =/*CON comillas*/,
                    MSG             =/*CON comillas*/,
                    Adjunto         =/*Ruta del archivo, CON comillas, por defecto esta opción no se contempla*/"NULO",
                    ContenidoHTML   =/*Solo se indica con 1 si lo es, por defecto es 0 (no lo contiene) */0);
                        
    %LET hostMail                   =%STR();
    %LET puerto                     =%STR();

    %LET asuntoAdjunto              =%STR();

    %IF &Adjunto EQ "NULO" %THEN
        %LET asuntoAdjunto          =%STR(SUBJECT =)   &Asunto;
    %ELSE
        %LET asuntoAdjunto          =%STR(SUBJECT =)   &Asunto %STR(ATTACH =) &Adjunto;

    %IF &ContenidoHTML EQ 1 %THEN
    %DO;
        %LET esHTML                      =CONTENT_TYPE %STR(=) "text/html; charset=UTF-8";
    %END;
    %ELSE
    %DO;
        %LET esHTML                      =%STR();
    %END;
    
    DATA _NULL_;
    SET LIBBITAC.INFO_MAIL;
    CALL SYMPUTX('hostMail', HOST_MAIL);
    CALL SYMPUTX('puerto', PORT);
    RUN;
    
    OPTIONS EMAILSYS=SMTP;
    OPTIONS EMAILHOST="&hostMail.";
    OPTIONS EMAILPORT=&puerto.;
    OPTIONS EMAILAUTHPROTOCOL=NONE;
    OPTIONS EMAILID="&hostMail.";

    FILENAME MYEMAIL EMAIL DEBUG

    FROM        =   &Remitente.
    TO          =   (&DESTINO.)
    %IF %SCAN(&CC_DESTINO, 1, %STR( )) NE "NULO" %THEN
        %STR(CC=)   (&CC_DESTINO.);
    &asuntoAdjunto
    &esHTML;

    DATA _NULL_;
    FILE MYEMAIL LRECL=32767;
    PUT &MSG.;
    RUN;

    FILENAME MYEMAIL CLEAR;
%MEND;