  MEMBER

  MAP
    COMPILE('_SinST_',SQLClass6SinStringTheory=1)
    MODULE('kernel32')                                 ! WriteLog sin StringTheory
      SQLC6_CreateFile(*CSTRING,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,RAW,NAME('CreateFileA')
      SQLC6_WriteFile(LONG,LONG,ULONG,*ULONG,LONG),LONG,PASCAL,PROC,NAME('WriteFile')
      SQLC6_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
    END
    _SinST_
  END!MAP
  OMIT('_SinST_',SQLClass6SinStringTheory=1)
  INCLUDE('StringTheory.Inc'),ONCE
  _SinST_
  !
  ! 28 de Octubre 2026 : StringTheory opcional. Con SQLClass6SinStringTheory=>1 en el proyecto (check 'Usar StringTheory' del
  !                   template global destildado) no se incluye StringTheory y WriteLog escribe con la API de Windows.
  !
  ! 19 de Octubre 2026 : Nuevo metodo ExecSP(Query,<NoCols>) para Store Procedures que devuelven resultado: 'EXEC dbo.sp param,param'.
  !                   Lo envia como CALL sp(param,param) (el driver MSSQL solo lee resultados de SELECT / CALL; con EXEC el
  !                   NEXT da error 33). No pasa por Parse() ni por Lower(). Se lee igual que un SELECT (Next / Col).
  !                   Exec() y ExecEx() NO se modificaron.
  !                   El template TCW_Display lo usa con el prompt 'La consulta es un Store Procedure' (%TCWIsSP).
  !                   ETAPA 2: propiedades LogFile (log con StringTheory), ShowProgress / ProgressTitle / ProgressText (ventana de proceso) y
  !                   metodo WriteLog(Text). Se aplican en ServerExec() y ServerExecEx(), asi que valen para Exec, ExecEx y ExecSP.
  !                   Por defecto estan apagadas. Cambia el tamano del objeto: recompilar TODAS las apps que incluyen SQLClass6.INC.
  !                   StringTheory es requisito de la app que compila esta clase (opcional desde el 28/10/2026).
  ! 13 de Octubre 2026 : Nuevos metodos ExecEx(Query,<OmitLower>), ServerExecEx() y CountCols(): cuentan bien las columnas
  !                   del SELECT (AS, TOP, DISTINCT, funciones) y OmitLower=1 respeta mayusculas/minusculas.
  ! 16 de Marzo      : Se agregó soporte a la instrucción SAVEPOINT en el PARSER (Oracle) - Leo -
  ! 16 de Enero      : Se agrego soporte a la instrucción ALTER en el PARSER. (Oracle)
  ! 2002/01/12      : Se le quitó el UPPER de los métodos EXEC y PARSE (en este último solo del
  !                   que hace un UPPER del query completo, no el de los Tokens)
  ! 2001/08/24      : Soporte para comando TRUNCATE (MsSQL)
  ! 2001/08/09      : CursorWait en init()
  !                 : Setea correctamente la propiedad State. Creates para valores posibles SQL:NotReady , SQL:Ready
  ! 23 de Enero     : Mejora del Error del ServerExec()
  ! 21 de Noviembre : Compatiblidad c55
  !                   Sacar abcdllmode equates
  !                 : Nueva Propiedad FreeQueue para poder configurar si el metodo Loadqueue debe o no hacer un FREE(QUEUE)
  ! 02 de Agosto    : Se multiplicó por 10 el tamaño máximo de todas las cláusulas
  ! 28 de Febrero   : Nuevo método Col_Format para especificar un formato especial en caso de usar LoadQueue
  ! 08 de Febrero   : Soporte para CREATE en Metodo PARSE.
  ! 28 de Diciembre : Incorporamos LQD : Long Query Detection
  ! 14 de Diciembre : Stella's Bug. En algunos casos extraños sucesivos SQl.EXEC no estaban andando
  !                   la conclusion del tema es que quedaban los cursores abiertos. Para solucinarlo ahora siempre hace
  !                   un CLOSE() en el ServerExec()
  ! 14 de Diciembre : El metodo SP todavia estaba con la logica vieja de manejo de errores (srt)
  ! 18 de Octub : LoadQueue : Return Level
  ! 30 de Abril : Re-ingenieria completa de las clases. No mas compatible con versiones anteriores. (por devcon)
  ! 03 de Abril : Corregido el serio problema que hacia que si la SQLClass daba un error sintactico dejaba de funcionar para querys posteriores.
  ! 03 de Abril : La SQL Class SP estaba andando mal para SP que tengan + de 1 columna de retorno.
  ! 01 de Abril : Soporte para SELECT DISTINCT
  ! 17 de Marzo : SET tambien es valido (ej. set isolation level)
  ! 16 de Marzo : Comandos SQL Transaccionales son validos (Begin work,commit,rollback)
  ! 08 de Marzo : Drop es válido sintacticamante.
  ! 24 de Julio : SetClipboard() del Query en caso de Error

  INCLUDE('aberror.inc'),ONCE ! Este archivo tiene los equate de los errores . Ejemplo : LEVEL:Fatal
  INCLUDE('abbrowse.inc'),ONCE ! Este Archivo tiene los equates de EventAction:Foward, etc.
  INCLUDE('SQLClass6.INC'),ONCE
  INCLUDE('StringClass.INC'),ONCE

SQLParsed   EQUATE(2)

SQLOdbcClass.Construct PROCEDURE()
 CODE
 Self.Fields   &= NEW(SQLClass6_QFields)
 Self.Format   &= NEW(SQLClass6_QFormat)
 Self.MiString &= NEW(StringClass)


SQLOdbcClass.Destruct PROCEDURE()
 CODE
 DISPOSE(Self.MiString)
 FREE(Self.Fields)
 DISPOSE(Self.Fields)
 FREE(Self.Format)
 DISPOSE(Self.Format)


SQLOdbcClass.Init PROCEDURE(*File SQLFile, *Group SQLFileRecord , String OwnerName)
 CODE
 SETCURSOR(Cursor:Wait)
 Self.SQLFile       &= SQLFile
 Self.SQLFileRecord &= SQLFileRecord

 Self.PropOwner = OwnerName
 Self.SQLFile{Prop:Owner} = Self.PropOwner

 Self.FreeQueue = True ! By Default queue is freed.

 SHARE(Self.SQLFile)
 !MESSAGE(' EL ERRORCODE DEVUELTO ES:'& errorcode() & ' error()='& error())
 CASE ERRORCODE()
   OF 0 OROF 52 ! File Already Open
      ! IGNORAR ESTE ERROR
   OF 2 ! File Not Found
      CREATE(Self.SQLFile)
      IF ERRORCODE() THEN STOP('NO PUDO CREAR LA TABLA! HACERLO MANUALMENTE CON HERRAMIENTAS DE LA BASE. ERROR='&FILEERRORCODE()&FILEERROR()).
      SHARE(Self.SQLFile)
 ELSE
     STOP('SQLClass Failed. ' & ERROR())
     Self.State = SQL:NotReady
     SETCURSOR()
     RETURN Level:Notify
 END!CASE
 Self.State = SQL:Ready
 SETCURSOR()
 RETURN Level:Benign

SQLOdbcClass.RegisterUpdate PROCEDURE(*FileManager Fm , *Key Clave , *? Campo)
 CODE
 Self.primary_fm    &= Fm
 Self.Primary_Key   &= Clave
 Self.Primary_field &= Campo

SQLOdbcClass.Kill PROCEDURE()
 CODE
 FREE(Self.Fields)
 FREE(Self.Format)
 CLOSE (Self.SQLFile)

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.SP()
!          This manages the calls to Store Procedures. Because the Number of Columns that
! the SP will return is not know by looking at the SP name then the No of Columns needs to
! be passed as a parameter in order to SET the Correct view.
! Of course this class reuses all the code in SQL method.
! --------------------------------------------------------------------------------------

SQLOdbcClass.SP PROCEDURE(Short NoCols , String SP_Name)
   CODE
   IF NoCols
    Self.Cols = NoCols ! Set the Number of Returning Columns
    !MESSAGE('SQLOdbcClass.SP EL Self.Cols VALE='&Self.Cols & ' AHORA VOY A LLAMAR AL METODO SQL' )
    IF Self.Exec('CALL ' & SP_Name ) THEN RETURN Level:Notify.
   ELSE
    Self.Cols = 1 ! Set the Number of Returning Columns
    IF Self.Exec('NORESULTCALL ' & SP_Name ) THEN RETURN Level:Notify.
   END!IF
   RETURN Level:Benign

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.Exec()
! --------------------------------------------------------------------------------------
SQLOdbcClass.Exec PROCEDURE(String Query)
Loc:Start   TIME
Loc:Duration    TIME
    CODE
    ! Validate that Class has being initialized
    IF Self.SQLFile &= NULL THEN MESSAGE('SQLClass object has not been initialized. You should call the .init method','Error',ICON:Exclamation);RETURN Level:Notify.
    Self.Records_Done = 0
    Self.Records      = 0
    !Self.Query        = CLIP(UPPER(Query))
    Self.Query        = Lower(CLIP(Query))
    IF NOT Self.Parse() = Level:Benign
       IF NOT Self.SilentMode THEN MESSAGE(' SQL : THE PARSE OF THE QUERY FAILED').
       SETCLIPBOARD(Self.Query)
       RETURN Level:Notify
    END!IF
    Loc:Start = CLOCK()
    IF NOT Self.ServerExec() = Level:Benign
       IF NOT Self.SilentMode THEN MESSAGE(' SQL : THE EXECUTION OF THE QUERY FAILED').
       SETCLIPBOARD(Self.Query)
       RETURN Level:Notify
    END!IF
    Loc:Duration = CLOCK() - Loc:Start
    IF Self.Debug AND Loc:Duration > Self.Debug_Limit
       MESSAGE('SQL Class (Long Query Detection).| El Query:|' & CLIP(Self.Query) & '| Duración: ' & FORMAT(Loc:Duration,@t4),'LONG QUERY',ICON:EXCLAMATION)
       SETCLIPBOARD(Self.Query)
    END!IF
    RETURN Level:Benign

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.Parse()
! This Method is the core of the Class. Here the SQL is parsed and the Number of Columns
! are detected. Furthermore, the SQL is broke down into the different Clauses (select,from,..)
! This allows the method Records() to work.
! This Class need the StringClass.
!
! --------------------------------------------------------------------------------------
SQLOdbcClass.Parse PROCEDURE()
PosFrom     LONG
PosWhere    LONG
Pos_OrderBy  LONG
Pos_GroupBy  LONG
Loc:Query    CSTRING(20480)
!MiString     StringClass
    CODE
    ! Initialise the Props that this Method assignes.
    Self.SQL_Select  = ''
    Self.SQL_From    = ''
    Self.SQL_Where   = ''
    Self.SQL_OrderBy = ''
    Self.SQL_GroupBy = ''

    ! Configure the String Class
    Self.MiString.Delimiters =' ,|' ! Only use this separators to detect token changes
    !Self.MiString.Text = CLIP(UPPER(Self.Query))
    Self.MiString.Text = CLIP(Self.Query)
    Self.MiString.SelEnd = 0 !Start from the beginning of String
    CASE CLIP(UPPER(Self.MiString.NextToken()))
      OF 'SELECT'
         IF Self.TakeSelect() <> Level:Benign
            RETURN Level:Benign
         END!IF

      OF 'INSERT'
         !MESSAGE('SQLCLASS: DETECTO UN INSERT!')
         Self.Cols = 1
         IF Self.TakeInsert() <> Level:Benign
            RETURN Level:Notify
         ELSE
            RETURN Level:Benign
         END!IF
      OF 'DELETE'
         !MESSAGE('SQLCLASS: DETECTO UN DELETE!')
         Self.Cols = 1
         IF Self.TakeDelete() <> Level:Benign
            RETURN Level:Notify
         ELSE
            RETURN Level:Benign
         END!IF
      OF 'UPDATE'
         !MESSAGE('SQLCLASS: DETECTO UN UPDATE!')
         Self.Cols = 1
         IF Self.TakeUpdate() <> Level:Benign
            RETURN Level:Notify
         ELSE
            RETURN Level:Benign
         END!IF
      OF 'EXECUTE' OROF 'BEGIN' OROF 'COMMIT' OROF 'ROLLBACK' OROF 'SET' OROF 'CREATE' OROF 'TRUNCATE' OROF 'ALTER' OROF 'SAVEPOINT' OROF 'START TRANSACTION'
         Self.Cols = 1
         RETURN Level:Benign
      OF 'DROP'
         Self.Cols = 1
         IF Self.TakeDrop() <> Level:Benign
            RETURN Level:Notify
         ELSE
            RETURN Level:Benign
         END!IF

      OF 'CALL' OROF 'NORESULTCALL'
         ! The Cols must be set by the SP Method.
         !MESSAGE('DETECTE UNA LLAMADA A CALL/NORESULTCALL Y ESTOY VOLVIENDO CON TRUE. VALOR DE Self.Cols ='&Self.Cols )
         RETURN Level:Benign
      ELSE
       MESSAGE('LA SQL CLASS DETECTO UN ERROR DE SINTAXIS EN:|'&Clip(Self.Query),'SYNTAX ERROR',ICON:EXCLAMATION)
       SETCLIPBOARD(Self.Query)
       RETURN self.Init(Self.SQLFile,Self.SQLFileRecord,Self.PropOwner)
    END!IF

    ! Find Position of the KEYWORDS inside the query
    Upp# = Self.MiString.ForceUpper
    Self.MiString.ForceUpper = True

    PosFrom       = Self.MiString.Find('FROM')
    PosWhere      = Self.MiString.Find('WHERE')
    Pos_OrderBy   = Self.MiString.Find('ORDER BY')
    Pos_GroupBy   = Self.MiString.Find('GROUP BY')

    Self.MiString.ForceUpper = Upp#

    IF PosFrom
       Self.SQL_Select = Self.MiString.SubLeft(PosFrom)
    ELSE
     !  MESSAGE('FROM WAS NOT FOUND!')
       RETURN Level:Notify ! Not Valid
    END!IF

    IF PosWhere
       Self.SQL_From = Self.MiString.Text [ PosFrom : PosWhere-1 ]
    END!IF

    IF Pos_GroupBy
       !MESSAGE('GROUP BY WAS FOUND!')
       IF PosWhere
          Self.SQL_Where = Self.MiString.Text[ PosWhere : Pos_GroupBy-1 ]
       ELSE
          Self.SQL_From  = Self.MiString.Text[ PosFrom : Pos_GroupBy-1 ]
       END!IF

       IF Pos_OrderBy
          !MESSAGE('ORDER BY WAS FOUND!')
          Self.SQL_GroupBy = Self.MiString.Text[Pos_GroupBy : Pos_OrderBy-1 ]
          Self.SQL_OrderBy = Self.MiString.SubRight(Pos_OrderBy)
       ELSE
          Self.SQL_GroupBy = Self.MiString.SubRight(Pos_GroupBy)
          Self.SQL_OrderBy = ''
       END!IF
    ELSE
       IF Pos_OrderBy
          !MESSAGE('ORDER BY WAS FOUND!')
          Self.SQL_OrderBy = Self.MiString.SubRight(Pos_Orderby)
          IF PosWhere
             Self.SQL_Where = Self.MiString.Text[ PosWhere : Pos_OrderBy-1 ]
          ELSE
             Self.SQL_From  = Self.MiString.Text[ PosFrom : Pos_OrderBy-1 ]
          END!IF
       ELSE
          IF PosWhere
             !MESSAGE('NO GROUP BY , NO ORDER BY , WHERE=YES')
             Self.SQL_Where = Self.MiString.SubRight(PosWhere)
          ELSE
             !MESSAGE('NO GROUP BY , NO ORDER BY , WHERE=NO')
             Self.SQL_From  = Self.MiString.SubRight(PosFrom)
          END!IF
       END!IF
    END!IF

    ! Now i parse the fields
    Self.MiString.Text = Self.SQL_Select
    !MESSAGE('EL TOKEN TRAIDO COMO COMANDO ES:' & Self.MiString.NextToken() )! this to retrieve the token select.
    Self.Cols = 0
    FREE(Self.Fields)

    LOOP ! for each col of the select
      Self.Fields.QFieldName = Self.MiString.NextToken()
      IF NOT LEN(CLIP(Self.Fields.QFieldName)) THEN BREAK.
      IF CLIP(UPPER(Self.Fields.QFieldName))='DISTINCT' THEN CYCLE.
      Self.Cols += 1 ! increment by 1
      Self.Fields.QFieldNo   = Self.Cols
      ADD(Self.Fields)
      !MESSAGE(Self.Cols &','& Self.Fields.QFieldNo &','& Self.Fields.QFieldName)
      IF ERRORCODE() THEN STOP('THERE IS AN ERROR WHEN TRYING TO ADD TO THE FIELDS QUEUE').
    END!LOOP
    !MESSAGE('no of cols:' & Self.Cols)
    RETURN Level:Benign

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.ServerExec()
! --------------------------------------------------------------------------------------
SQLOdbcClass.ServerExec PROCEDURE
ErrC        LONG
ErrN        LONG
ErrT        CSTRING(300)
ErrE        CSTRING(300)
LogStart    LONG
ProgWin     WINDOW,AT(,,300,64),CENTER,COLOR(COLOR:White),FONT('Segoe UI',9,,FONT:regular)
                BOX,AT(0,0,300,3),USE(?PgTop),COLOR(0D77800H),FILL(0D77800H)
                STRING('Procesando consulta'),AT(14,9,272,14),USE(?PgTitle),FONT(,11,0404040H,FONT:bold)
                STRING(''),AT(14,26,272,10),USE(?PgText),FONT(,9,0808080H,FONT:regular)
                BOX,AT(14,42,272,5),USE(?PgBar0),COLOR(0EBEBEBH),FILL(0EBEBEBH)
                BOX,AT(14,42,90,5),USE(?PgBar),COLOR(0D77800H),FILL(0D77800H)
            END
    CODE
    CLOSE(Self.SQLFile) ! srt 14 de Diciembre
    OPEN(Self.SQLFile)
    IF Self.ShowProgress THEN DO ProgOpen.
    IF LEN(Self.LogFile) THEN LogStart = CLOCK() ; Self.WriteLog('SQL> ' & CLIP(Self.Query)).
    Self.SQLFile{Prop:SQL} = Lower(CLIP(Self.Query))
    ErrC = FILEERRORCODE()                              ! se guardan antes de cerrar la ventana y de escribir el log
    ErrT = CLIP(FILEERROR())
    ErrN = ERRORCODE()
    ErrE = CLIP(ERROR())
    IF Self.ShowProgress THEN DO ProgClose.
    IF LEN(Self.LogFile) THEN Self.WriteLog('    -> ' & CHOOSE(ErrC = 0,'OK','ERROR ' & ErrC & ' ' & ErrT) & '  (' & ABS(CLOCK() - LogStart) & ' cs)').
    IF ErrC
       IF NOT Self.SilentMode
          STOP('Error en QueryClass. Metodo ServerExec()<13,10>FileError()=' & ErrT & '<13,10>FileErrorCode()=' & ErrC & '<13,10>Error()='& ErrE & '<13,10>ErrorCode=' & ErrN &'<13,10>Query Enviado:' & Clip(Self.Query))
       END!IF
       I#=self.Init(Self.SQLFile,Self.SQLFileRecord,Self.PropOwner) ! Resetear el SQLClass despues de un error asi
       RETURN Level:Notify
    END!IF
    RETURN Level:Benign

ProgOpen ROUTINE
  OPEN(ProgWin)
  IF LEN(Self.ProgressTitle) THEN ?PgTitle{PROP:Text} = Self.ProgressTitle.
  ?PgText{PROP:Text} = CHOOSE(LEN(Self.ProgressText) > 0,Self.ProgressText,'Esperando la respuesta del servidor...')
  SETCURSOR(CURSOR:WAIT)
  DISPLAY

ProgClose ROUTINE
  SETCURSOR()
  CLOSE(ProgWin)


! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.ExecSP()      (Templates Clarion, 19/10/2026)
! Ejecuta un Store Procedure que devuelve un resultado: ExecSP('EXEC dbo.sp_Algo ''20261019'', 10')
! - El driver MSSQL de Clarion solo lee resultados de sentencias SELECT o CALL (con EXEC / EXECUTE el NEXT
!   da error 33), asi que "EXEC nombre param1, param2" se envia como "CALL nombre(param1, param2)".
!   Tambien acepta "EXECUTE nombre ..." o directamente "CALL nombre(...)".
! - No pasa por Parse() ni por Lower(): respeta el nombre del SP y los parametros.
! - Despues se lee igual que un SELECT: LOOP UNTIL SQL.Next() ... SQL.Col(n).
! - El registro de SQLFile tiene que tener al menos tantos campos como columnas devuelve el SP.
! NoCols es opcional (solo lo usa LoadQueue); Col(n) no depende de el.
! --------------------------------------------------------------------------------------
SQLOdbcClass.ExecSP PROCEDURE(String Query,<Short NoCols>)
Args        CSTRING(20480)
Nm          CSTRING(200)
Ar          CSTRING(20480)
P           LONG
    CODE
    IF Self.SQLFile &= NULL THEN MESSAGE('SQLClass object has not been initialized. You should call the .init method','Error',ICON:Exclamation);RETURN Level:Notify.
    Self.Records_Done = 0
    Self.Records      = 0
    Args              = CLIP(LEFT(Query))
    CASE UPPER(SUB(Args,1,8))                           ! se saca la palabra EXECUTE / EXEC / CALL
    OF 'EXECUTE '
       Args = CLIP(LEFT(SUB(Args,9,LEN(Args))))
    ELSE
       IF UPPER(SUB(Args,1,5)) = 'EXEC ' OR UPPER(SUB(Args,1,5)) = 'CALL '
          Args = CLIP(LEFT(SUB(Args,6,LEN(Args))))
       END!IF
    END!CASE
    P = INSTRING(' ',Args,1,1)                          ! nombre del SP y parametros
    IF P = 0 OR (INSTRING('(',Args,1,1) > 0 AND INSTRING('(',Args,1,1) < P)
       Self.Query = 'CALL ' & Args                      ! sin parametros, o ya vienen entre parentesis
    ELSE
       Nm = SUB(Args,1,P - 1)
       Ar = CLIP(LEFT(SUB(Args,P + 1,LEN(Args))))
       Self.Query = 'CALL ' & Nm & '(' & Ar & ')'
    END!IF
    FREE(Self.Fields)
    IF OMITTED(3) OR NOT NoCols THEN Self.Cols = 1 ELSE Self.Cols = NoCols.
    IF NOT Self.ServerExecEx() = Level:Benign
       IF NOT Self.SilentMode THEN MESSAGE(' SQL : THE EXECUTION OF THE STORE PROCEDURE FAILED|' & CLIP(Self.Query)).
       SETCLIPBOARD(Self.Query)
       RETURN Level:Notify
    END!IF
    RETURN Level:Benign

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.WriteLog()      (Templates Clarion, 19/10/2026)
! Agrega al final de Self.LogFile una linea "aaaammdd hh:mm:ss.cc texto" usando StringTheory.
! Si LogFile esta vacio no hace nada. Nunca da error ni cambia el estado de la clase.
! --------------------------------------------------------------------------------------
  OMIT('_SinST_',SQLClass6SinStringTheory=1)
SQLOdbcClass.WriteLog PROCEDURE(String Text)
ST          StringTheory
    CODE
    IF LEN(Self.LogFile) = 0 THEN RETURN.
    ST.SetValue(FORMAT(TODAY(),@d12) & ' ' & FORMAT(CLOCK(),@t4) & ' ' & CLIP(Text) & '<13,10>')
    ST.SaveFile(CLIP(Self.LogFile),True)
    RETURN
  _SinST_
  COMPILE('_SinST_',SQLClass6SinStringTheory=1)
SQLOdbcClass.WriteLog PROCEDURE(String Text)       ! sin StringTheory: misma linea, agregada al final con la API de Windows
FileName    CSTRING(261)
Prefix      CSTRING(40)
CrLf        STRING('<13,10>')
hFile       LONG
Written     ULONG
    CODE
    IF LEN(Self.LogFile) = 0 THEN RETURN.
    FileName = CLIP(Self.LogFile)
    hFile = SQLC6_CreateFile(FileName,4,1,0,4,80h,0)    ! FILE_APPEND_DATA, FILE_SHARE_READ, OPEN_ALWAYS, NORMAL
    IF hFile = -1 THEN RETURN.
    Prefix = FORMAT(TODAY(),@d12) & ' ' & FORMAT(CLOCK(),@t4) & ' '
    SQLC6_WriteFile(hFile,ADDRESS(Prefix),LEN(Prefix),Written,0)
    IF LEN(CLIP(Text)) THEN SQLC6_WriteFile(hFile,ADDRESS(Text),LEN(CLIP(Text)),Written,0).
    SQLC6_WriteFile(hFile,ADDRESS(CrLf),2,Written,0)
    SQLC6_CloseHandle(hFile)
    RETURN
  _SinST_

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.ExecEx()      (Templates Clarion / Project Manager, 13/10/2026)
! Igual que Exec(), pero cuenta las columnas del SELECT con CountCols(): respeta parentesis y
! comillas y salta DISTINCT y TOP n. Alias (AS), funciones con espacios y nombres como "Fecha1"
! ya no descuadran Col(n) / LoadQueue.
! Parametro opcional OmitLower: por defecto (omitido o 0) la consulta se pasa a minusculas igual
! que en Exec() (necesario en servidores que distinguen mayusculas, por ejemplo Linux).
! Con OmitLower = 1 la consulta viaja tal cual, sin cambiar mayusculas y minusculas.
! Exec() no se modifico: las llamadas existentes se comportan igual que siempre.
! --------------------------------------------------------------------------------------
SQLOdbcClass.ExecEx PROCEDURE(String Query,<Byte OmitLower>)
Loc:Start   TIME
Loc:Duration    TIME
    CODE
    IF Self.SQLFile &= NULL THEN MESSAGE('SQLClass object has not been initialized. You should call the .init method','Error',ICON:Exclamation);RETURN Level:Notify.
    Self.Records_Done = 0
    Self.Records      = 0
    IF OMITTED(2) OR NOT OmitLower
       Self.Query     = Lower(CLIP(Query))
    ELSE
       Self.Query     = CLIP(Query)
    END!IF
    IF NOT Self.Parse() = Level:Benign
       IF NOT Self.SilentMode THEN MESSAGE(' SQL : THE PARSE OF THE QUERY FAILED').
       SETCLIPBOARD(Self.Query)
       RETURN Level:Notify
    END!IF
    Self.CountCols()
    Loc:Start = CLOCK()
    IF NOT Self.ServerExecEx() = Level:Benign
       IF NOT Self.SilentMode THEN MESSAGE(' SQL : THE EXECUTION OF THE QUERY FAILED').
       SETCLIPBOARD(Self.Query)
       RETURN Level:Notify
    END!IF
    Loc:Duration = CLOCK() - Loc:Start
    IF Self.Debug AND Loc:Duration > Self.Debug_Limit
       MESSAGE('SQL Class (Long Query Detection).| El Query:|' & CLIP(Self.Query) & '| Duracion: ' & FORMAT(Loc:Duration,@t4),'LONG QUERY',ICON:EXCLAMATION)
       SETCLIPBOARD(Self.Query)
    END!IF
    RETURN Level:Benign

! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.ServerExecEx()  -  como ServerExec pero envia Self.Query tal como lo dejo ExecEx
! (ya en minusculas, salvo que se haya pedido OmitLower)
! --------------------------------------------------------------------------------------
SQLOdbcClass.ServerExecEx PROCEDURE
ErrC        LONG
ErrN        LONG
ErrT        CSTRING(300)
ErrE        CSTRING(300)
LogStart    LONG
ProgWin     WINDOW,AT(,,300,64),CENTER,COLOR(COLOR:White),FONT('Segoe UI',9,,FONT:regular)
                BOX,AT(0,0,300,3),USE(?PgTop),COLOR(0D77800H),FILL(0D77800H)
                STRING('Procesando consulta'),AT(14,9,272,14),USE(?PgTitle),FONT(,11,0404040H,FONT:bold)
                STRING(''),AT(14,26,272,10),USE(?PgText),FONT(,9,0808080H,FONT:regular)
                BOX,AT(14,42,272,5),USE(?PgBar0),COLOR(0EBEBEBH),FILL(0EBEBEBH)
                BOX,AT(14,42,90,5),USE(?PgBar),COLOR(0D77800H),FILL(0D77800H)
            END
    CODE
    CLOSE(Self.SQLFile) ! srt 14 de Diciembre
    OPEN(Self.SQLFile)
    IF Self.ShowProgress THEN DO ProgOpen.
    IF LEN(Self.LogFile) THEN LogStart = CLOCK() ; Self.WriteLog('SQL> ' & CLIP(Self.Query)).
    Self.SQLFile{Prop:SQL} = CLIP(Self.Query)
    ErrC = FILEERRORCODE()                              ! se guardan antes de cerrar la ventana y de escribir el log
    ErrT = CLIP(FILEERROR())
    ErrN = ERRORCODE()
    ErrE = CLIP(ERROR())
    IF Self.ShowProgress THEN DO ProgClose.
    IF LEN(Self.LogFile) THEN Self.WriteLog('    -> ' & CHOOSE(ErrC = 0,'OK','ERROR ' & ErrC & ' ' & ErrT) & '  (' & ABS(CLOCK() - LogStart) & ' cs)').
    IF ErrC
       IF NOT Self.SilentMode
          STOP('Error en QueryClass. Metodo ServerExecEx()<13,10>FileError()=' & ErrT & '<13,10>FileErrorCode()=' & ErrC & '<13,10>Error()='& ErrE & '<13,10>ErrorCode=' & ErrN &'<13,10>Query Enviado:' & Clip(Self.Query))
       END!IF
       I#=self.Init(Self.SQLFile,Self.SQLFileRecord,Self.PropOwner) ! Resetear el SQLClass despues de un error asi
       RETURN Level:Notify
    END!IF
    RETURN Level:Benign

ProgOpen ROUTINE
  OPEN(ProgWin)
  IF LEN(Self.ProgressTitle) THEN ?PgTitle{PROP:Text} = Self.ProgressTitle.
  ?PgText{PROP:Text} = CHOOSE(LEN(Self.ProgressText) > 0,Self.ProgressText,'Esperando la respuesta del servidor...')
  SETCURSOR(CURSOR:WAIT)
  DISPLAY

ProgClose ROUTINE
  SETCURSOR()
  CLOSE(ProgWin)


! --------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.CountCols()
! Cuenta las columnas del SELECT que hay en Self.Query (separadas por coma de primer nivel: no cuenta las comas
! dentro de parentesis ni de comillas; salta DISTINCT y TOP n; termina en el FROM de primer nivel) y deja el
! resultado en Self.Cols y los nombres en Self.Fields. Si la consulta no es un SELECT no cambia nada.
! --------------------------------------------------------------------------------------
SQLOdbcClass.CountCols PROCEDURE()
Q         CSTRING(20481)
L         LONG
P         LONG
Start     LONG
Depth     SHORT
InStr     BYTE
N         SHORT
Ch        STRING(1)
    CODE
    Q = Self.Query
    L = LEN(Q)
    P = 1
    LOOP WHILE P <= L AND SUB(Q,P,1) = ' '
       P += 1
    END!LOOP
    IF UPPER(SUB(Q,P,6)) <> 'SELECT' THEN RETURN Self.Cols.
    P += 6
    LOOP WHILE P <= L AND SUB(Q,P,1) = ' '
       P += 1
    END!LOOP
    IF UPPER(SUB(Q,P,9)) = 'DISTINCT '
       P += 9
       LOOP WHILE P <= L AND SUB(Q,P,1) = ' '
          P += 1
       END!LOOP
    END!IF
    IF UPPER(SUB(Q,P,4)) = 'TOP '
       P += 4
       LOOP WHILE P <= L AND SUB(Q,P,1) <> ' '
          P += 1
       END!LOOP
       LOOP WHILE P <= L AND SUB(Q,P,1) = ' '
          P += 1
       END!LOOP
    END!IF
    FREE(Self.Fields)
    N = 0
    Start = P
    LOOP WHILE P <= L
       Ch = SUB(Q,P,1)
       IF InStr
          IF Ch = ''''
             IF SUB(Q,P+1,1) = ''''
                P += 1
             ELSE
                InStr = 0
             END!IF
          END!IF
       ELSE
          CASE Ch
          OF ''''
             InStr = 1
          OF '('
             Depth += 1
          OF ')'
             Depth -= 1
          OF ','
             IF Depth = 0
                DO AddColumn
                Start = P + 1
             END!IF
          ELSE
             IF Depth = 0 AND UPPER(SUB(Q,P,5)) = 'FROM ' AND INSTRING(SUB(Q,P-1,1),' ),<9><13><10>',1,1) THEN BREAK.
          END!CASE
       END!IF
       P += 1
    END!LOOP
    DO AddColumn
    Self.Cols = N
    RETURN N

AddColumn ROUTINE
  DATA
Seg   CSTRING(10241)
  CODE
  Seg = CLIP(LEFT(SUB(Q,Start,P-Start)))
  IF LEN(Seg)
     N += 1
     Self.Fields.QFieldName = Seg
     Self.Fields.QFieldNo   = N
     ADD(Self.Fields)
  END!IF

SQLOdbcClass.Next PROCEDURE
    CODE
    NEXT(Self.SQLFile)
    IF ERRORCODE()
       Self.State = False ! The Class has no valid value to give.
       !IF NOT Self.SilentMode THEN MESSAGE('ERROR IN NEXT!' & ERROR()).
       CLOSE(Self.SQLFile   )
       RETURN Level:Notify
    END!IF
    Self.State      = True ! The Class has value to give.
    Self.Records_Done + = 1
    RETURN Self.TakeRecord()
   ! RETURN Level:Benign

! -------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.RECORDS()
! This Method will change the Query in order to Count(*) how many records match the criteria
! Afterwards it will replace the Original Query
! -------------------------------------------------------------------------------------
SQLOdbcClass.Records PROCEDURE()
Loc:SQL_Backup CSTRING(20480)
Loc:SQL CSTRING(20480)

MySQLLocal  SqlOdbcClass

  CODE
  MySqlLocal.SQLFile       &= Self.SQLFile ! Necesito pasarle al objeto los parametros de self
  MySqlLocal.SQLFileRecord &= Self.SQLFileRecord
  MySqlLocal.PropOwner      = Self.PropOwner
 ! MySQLLocal.Init()

  Loc:SQL_Backup   = Self.Query ! Backups the Original Query

  Loc:SQL = 'SELECT COUNT(*) ' & Lower(CLIP(Self.SQL_From))

  IF LEN(CLIP(Self.SQL_Where))
     Loc:SQL = Loc:SQL &' '& CLIP(Self.SQL_Where)
  END!IF

  Err#=Self.Exec(Loc:SQL)

  IF Self.Next()
    Self.Records = 0
  ELSE
    Self.Records = Self.Col(1)
  END!IF
  !Self.Records  = MySQLLocal.Fetch(1,Loc:SQL)
!  MySqlLocal.SQLFile{Prop:SQL}=Loc:SQL
!  NEXT(MySQLLocal.SQLFile)
!  Self.Records = WHAT(MySqlLocal.SQLFileRecord,1)

  Self.Query      = Loc:SQL_Backup ! Return to the Original Query
  RETURN( Self.Records )

! -------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.Fetch( Short FieldNo , String Query )
! This Method is used when you know that the Query Returns only 1 col.
! Return Value : The Value of the Column that was passed as 1st Parameter.
! You can use NEXT() afterwards.
! -------------------------------------------------------------------------------------
SQLOdbcClass.Fetch PROCEDURE( Short FieldNo , String Query )
 CODE
 Self.Pk_Col = FieldNo
 IF NOT Self.Exec(Query)= Level:Benign THEN RETURN Level:Notify.
 IF NOT Self.Next()= Level:Benign
    CLOSE(Self.SQLFile)
    RETURN Level:Benign
 END!IF
 RETURN ( Self.Col (Self.Pk_col) )

! -------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.Fetch( Short FieldNo , String Query , *String Data)
! This Method is used when you know that the Query Returns only 1 col.
! Return Value : The Value of the Column that was passed as 1st Parameter.
! You can use NEXT() afterwards.
! -------------------------------------------------------------------------------------
SQLOdbcClass.Fetch PROCEDURE( Short FieldNo , String Query , *String Result)
 CODE
 Self.Pk_Col = FieldNo
 IF Self.Exec(Query) THEN RETURN Level:Notify.
 IF Self.Next()
    CLOSE(Self.SQLFile)
    RETURN Level:Notify
 END!IF
 Result = Self.Col (Self.Pk_col)
 RETURN Level:Benign

! -------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.Col( Short Column )
! This Method will return the value of the column. This is equivalent to say the column
! of the SELECT statement or the Column of the Data Returned by a Store Procedure.
! -------------------------------------------------------------------------------------
SQLOdbcClass.Col PROCEDURE(Short Column)
 CODE
 RETURN( WHAT ( Self.SQLFileRecord , Column ) )

! -------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.Cols(), Short
! Este es un buen ejemplo de como poder leer desde el programa el valor de una propiedad
! protegida y/o privada. Teniendo estos atributos el usuario no puede ni asignar ni consultar
! el valore de la propiedad. Pero esta simple tecnica consiste en tener un método que devuelva
! el valor de la propiedad.
! -------------------------------------------------------------------------------------
SQLOdbcClass.Columns PROCEDURE()
 CODE
 RETURN(Self.Cols)

! -------------------------------------------------------------------------------------
! METHOD : SQLOdbcClass.UpdateBuffer()
!
! -------------------------------------------------------------------------------------

SQLOdbcClass.UpdateBuffer PROCEDURE()
 CODE
 Self.Primary_Field = Self.Col ( Self.Pk_Col ) ! Example : CusIdCustomer = 4
 IF Self.Primary_fm.Fetch(Self.Primary_Key)! Example : Access:Customers.Fetch(Cus:ById)
    RETURN True
 ELSE
    RETURN False
 END!IF

! LOAD QUEUE. Hay una sabida limitacion que es la sig. : Como no se cuentos campos
! tiene el queue de referencia entonces puede pasar que si el queue tiene mas campos
! que el query entonces en el queue quede basura de un query anterior.
! Esto tiene que ser detectado por el programador y siempre pasar un queue que corresponda
! con el query.
SQLOdbcClass.LoadQueue   PROCEDURE(*Queue MyQueue,Byte WithCount, Byte ShowProgress)
MyField      ANY
Title        STRING(100)
Percentage   BYTE

WProgress WINDOW('SQL Class : Avance del Query'),AT(,,211,37),CENTER,IMM, |
         SYSTEM,GRAY,DOUBLE,AUTO
       STRING(@s100),AT(9,3,169,10),USE(Title),TRN
       PROGRESS,USE(Percentage),AT(8,16,172,8),RANGE(0,100)
       STRING(@s100),AT(8,25,169,10),USE(MyField),TRN
       BUTTON,AT(184,5,27,23),USE(?Cancel),FLAT,LEFT,ICON(ICON:Cross)
     END

 CODE
 SETCURSOR(CURSOR:WAIT)
 IF Self.FreeQueue
    FREE(MyQueue)
 END!IF
 IF WithCount THEN i#=Self.Records().
 Self.Records_Done = 0
 IF ShowProgress THEN OPEN(WProgress).
 LOOP ! UNTIL THERE ARE NO MORE RECORDS
   IF NOT Self.Next()=Level:Benign THEN BREAK.
   LOOP i#= 1  TO Self.Cols
     MyField &= WHAT( MyQueue,i#) ! Reference to the Field No i of the Queue
     Self.Format.QFormatNo = i#
     GET(Self.Format,Self.Format.QFormatNo)
     IF ERRORCODE()
        MyField  = Self.Col(i#)
     ELSE
        MyField  = DEFORMAT(Self.Col(i#),Self.Format.QFormatPic)
     END!IF
   END!LOOP
   ADD(MyQueue)
   IF ERRORCODE() THEN STOP(ERROR());SETCURSOR();RETURN Level:Notify.
   Self.Records_Done  += 1
   Percentage  = Self.Records / Self.Records_Done * 100
   ! Stop if query is too long...
   IF Self.MaxReads AND Self.Records_Done >Self.MaxReads
      MESSAGE('EL QUERY ES DEMASIADO LARGO. LOS PARAMETROS INDICAN QUE NO SE LEAN MAS DE '& Self.MaxReads & ' registros.','SQL Class',icon:exclamation)
      BREAK
   END!IF
   IF ShowProgress
      UPDATE
      DISPLAY
      YIELD() ! SRT : Esto conviene que sea configurable por propiedad tipo Self.Yield = 4 (cada 4 registros hago un yield)
   END!IF
 END!LOOP
 IF ShowProgress THEN CLOSE(WProgress).
 Self.Records = RECORDS(MyQueue)
 SETCURSOR()
 FREE(Self.Format)
 RETURN Level:Benign

SQLOdbcClass.Field PROCEDURE(Short NoCol)
 CODE
 GET(Self.Fields,NoCol)
 IF ERRORCODE() THEN RETURN('').
 RETURN(Self.Fields.QFieldName)

SQLOdbcClass.TakeSelect PROCEDURE()
 CODE
 RETURN Level:Benign

SQLOdbcClass.TakeInsert PROCEDURE()
 CODE
 RETURN Level:Benign

SQLOdbcClass.TakeUpdate PROCEDURE()
 CODE
 RETURN Level:Benign

SQLOdbcClass.TakeDrop PROCEDURE()
 CODE
 RETURN Level:Benign

SQLOdbcClass.TakeDelete PROCEDURE()
 CODE
 RETURN Level:Benign

SQLOdbcClass.TakeRecord PROCEDURE()
 CODE
 RETURN Level:Benign

SQLOdbcClass.Col_Format PROCEDURE(Short FieldNo, String Picture)
 CODE
 Self.Format.QFormatNo = FieldNo
 GET(Self.Format,Self.Format.QFormatNo)
 IF ERRORCODE()
    Self.Format.QFormatPic = CLIP(Picture)
    ADD(Self.Format)
 ELSE
    Self.Format.QFormatPic = CLIP(Picture)
    PUT(Self.Format)
 END!IF

! --------------------------------------------------------------------------------------
! CLASE  : SQLIfxClass
! --------------------------------------------------------------------------------------

SQLIfxClass.TakeRecord PROCEDURE()
RetVal BYTE
Aviso  BYTE,STATIC
 CODE
 IF NOT Aviso
!    MESSAGE('ESTOY EN TAKERECORD PARA INFORMIX! (antes del parent takerecord())','IFX CLASS',ICON:EXCLAMATION)
    Aviso = True
 END!IF
 RetVal = Parent.TakeRecord()
 RETURN RetVal

! --------------------------------------------------------------------------------------
! CLASE  : SQLMsClass
! --------------------------------------------------------------------------------------

SQLMsClass.TakeRecord PROCEDURE()
RetVal BYTE
Aviso  BYTE,STATIC
 CODE
 IF NOT Aviso
!    MESSAGE('ESTOY EN TAKERECORD PARA Ms SQL Server! (antes del parent takerecord())','MS SQL CLASS',ICON:EXCLAMATION)
    Aviso = True
 END!IF
 RetVal = Parent.TakeRecord()
 RETURN RetVal

! --------------------------------------------------------------------------------------
! CLASE  : SQLOraClass
! --------------------------------------------------------------------------------------

SQLOraClass.TakeRecord PROCEDURE()
RetVal BYTE
Aviso  BYTE,STATIC
 CODE
 IF NOT Aviso
!    MESSAGE('ESTOY EN TAKERECORD PARA Ms SQL Server! (antes del parent takerecord())','MS SQL CLASS',ICON:EXCLAMATION)
    Aviso = True
 END!IF
 RetVal = Parent.TakeRecord()
 RETURN RetVal

