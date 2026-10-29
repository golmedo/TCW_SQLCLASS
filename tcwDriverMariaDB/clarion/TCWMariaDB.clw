  MEMBER
!==============================================================================
! TCWMariaDB - implementacion (ver TCWMariaDB.inc). API publica de MariaDB Connector/C.
!==============================================================================
  MAP
    MODULE('libmariadb')
      tcwm_init(LONG),LONG,PASCAL,DLL(1),NAME('mysql_init')
      tcwm_options(LONG,LONG,LONG),LONG,PASCAL,PROC,DLL(1),NAME('mysql_options')
      tcwm_real_connect(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,ULONG),LONG,PASCAL,DLL(1),NAME('mysql_real_connect')
      tcwm_close(LONG),PASCAL,DLL(1),NAME('mysql_close')
      tcwm_real_query(LONG,LONG,ULONG),LONG,PASCAL,DLL(1),NAME('mysql_real_query')
      tcwm_store_result(LONG),LONG,PASCAL,DLL(1),NAME('mysql_store_result')
      tcwm_field_count(LONG),ULONG,PASCAL,DLL(1),NAME('mysql_field_count')
      tcwm_num_fields(LONG),ULONG,PASCAL,DLL(1),NAME('mysql_num_fields')
      tcwm_num_rows(LONG),ULONG,PASCAL,DLL(1),NAME('mysql_num_rows')
      tcwm_fetch_row(LONG),LONG,PASCAL,DLL(1),NAME('mysql_fetch_row')
      tcwm_fetch_lengths(LONG),LONG,PASCAL,DLL(1),NAME('mysql_fetch_lengths')
      tcwm_fetch_field_direct(LONG,ULONG),LONG,PASCAL,DLL(1),NAME('mysql_fetch_field_direct')
      tcwm_free_result(LONG),PASCAL,DLL(1),NAME('mysql_free_result')
      tcwm_more_results(LONG),BYTE,PASCAL,DLL(1),NAME('mysql_more_results')
      tcwm_next_result(LONG),LONG,PASCAL,DLL(1),NAME('mysql_next_result')
      tcwm_errno(LONG),ULONG,PASCAL,DLL(1),NAME('mysql_errno')
      tcwm_error(LONG),LONG,PASCAL,DLL(1),NAME('mysql_error')
      tcwm_affected_rows(LONG),LONG,PASCAL,DLL(1),NAME('mysql_affected_rows')
      tcwm_insert_id(LONG),LONG,PASCAL,DLL(1),NAME('mysql_insert_id')
      tcwm_real_escape_string(LONG,LONG,LONG,ULONG),ULONG,PASCAL,DLL(1),NAME('mysql_real_escape_string')
      tcwm_set_character_set(LONG,LONG),LONG,PASCAL,DLL(1),NAME('mysql_set_character_set')
      tcwm_ping(LONG),LONG,PASCAL,DLL(1),NAME('mysql_ping')
      tcwm_get_server_info(LONG),LONG,PASCAL,DLL(1),NAME('mysql_get_server_info')
      tcwm_get_client_info(),LONG,PASCAL,DLL(1),NAME('mysql_get_client_info')
    END
    MODULE('kernel32')
      tcwm_MoveMemory(LONG,LONG,LONG),PASCAL,NAME('RtlMoveMemory')
      tcwm_lstrlen(LONG),LONG,PASCAL,NAME('lstrlenA')
    END
  END

  INCLUDE('aberror.inc'),ONCE
  INCLUDE('TCWMariaDB.inc'),ONCE

TCWM:OptConnectTimeout  EQUATE(0)
TCWM:OptSslVerify       EQUATE(21)          ! MYSQL_OPT_SSL_VERIFY_SERVER_CERT
TCWM:OptSslEnforce      EQUATE(38)          ! MYSQL_OPT_SSL_ENFORCE (Connector/C 3.4 lo exige por defecto)
TCWM:ClientMultiResults EQUATE(131072)      ! CLIENT_MULTI_RESULTS: necesario para leer resultados de CALL
TCWM:ClientMultiStatements EQUATE(65536)    ! CLIENT_MULTI_STATEMENTS: 'SELECT ...; SELECT ...' en una consulta (NextResult)
TCWM:ServerGone         EQUATE(2006)
TCWM:ServerLost         EQUATE(2013)

!------------------------------------------------------------------------------
TCWMariaDB.Construct PROCEDURE()
  CODE
  SELF.Port = 3306
  SELF.Charset = 'latin1'
  SELF.ConnectTimeout = 10
  SELF.AutoReconnect = 1
  SELF.Params &= NEW TCWMariaDB_Params
  SELF.Campos &= NEW TCWMariaDB_Campos
  SELF.PrepSql &= NEW CSTRING(20480)
  SELF.BatchHead &= NEW CSTRING(20480)
  SELF.BatchTpl &= NEW CSTRING(4096)
  SELF.BatchSize = 500
  SELF.MaxBatchBytes = 524288

TCWMariaDB.Destruct PROCEDURE()
  CODE
  SELF.Disconnect()
  SELF.ClearParams()
  DISPOSE(SELF.Params)
  DISPOSE(SELF.Campos)
  DISPOSE(SELF.PrepSql)
  DISPOSE(SELF.BatchHead)
  DISPOSE(SELF.BatchTpl)
  IF NOT SELF.Batch &= NULL THEN DISPOSE(SELF.Batch).
  IF NOT SELF.ValBuf &= NULL THEN DISPOSE(SELF.ValBuf).

!------------------------------------------------------------------------------
! 'Server=host;Port=3306;Database=base;User=usuario;Password=clave;Charset=latin1;Timeout=10'
! (tambien acepta Host, Data Source, Uid, User Id, Pwd, Initial Catalog, Db, Connect Timeout)
TCWMariaDB.SetConnection PROCEDURE(STRING pConnection)
Txt     CSTRING(4096)
Part    CSTRING(1024)
Key     CSTRING(64)
Val     CSTRING(1024)
P       LONG,AUTO
E       LONG,AUTO
  CODE
  Txt = CLIP(pConnection) & ';'
  LOOP
    P = INSTRING(';',Txt,1,1)
    IF P = 0 THEN BREAK.
    Part = SUB(Txt,1,P-1)
    Txt = SUB(Txt,P+1,LEN(Txt)-P)
    E = INSTRING('=',Part,1,1)
    IF E = 0 THEN CYCLE.
    Key = UPPER(CLIP(LEFT(SUB(Part,1,E-1))))
    Val = CLIP(LEFT(SUB(Part,E+1,LEN(Part)-E)))
    CASE Key
    OF 'SERVER' OROF 'HOST' OROF 'DATA SOURCE' OROF 'ADDRESS'
      SELF.Host = Val
    OF 'PORT'
      SELF.Port = Val
    OF 'DATABASE' OROF 'DB' OROF 'INITIAL CATALOG'
      SELF.Database = Val
    OF 'USER' OROF 'UID' OROF 'USER ID' OROF 'USERNAME'
      SELF.User = Val
    OF 'PASSWORD' OROF 'PWD'
      SELF.Password = Val
    OF 'CHARSET' OROF 'CHARACTER SET'
      SELF.Charset = Val
    OF 'TIMEOUT' OROF 'CONNECT TIMEOUT' OROF 'CONNECTION TIMEOUT'
      SELF.ConnectTimeout = Val
    OF 'SSL' OROF 'SSLMODE' OROF 'SSL MODE'
      SELF.SSL = CHOOSE(INLIST(UPPER(Val),'1','TRUE','REQUIRED','VERIFY_CA','VERIFY_FULL') > 0)
    END
  END

TCWMariaDB.Connect PROCEDURE(<STRING pConnection>)
H       CSTRING(256)
U       CSTRING(128)
Pw      CSTRING(256)
D       CSTRING(128)
Cs      CSTRING(32)
T       ULONG
B       BYTE
  CODE
  SELF.Disconnect()
  IF NOT OMITTED(pConnection) THEN SELF.SetConnection(pConnection).
  SELF.hConn = tcwm_init(0)
  IF SELF.hConn = 0 THEN RETURN SELF.SetError('No se pudo inicializar libmariadb (mysql_init)').
  T = SELF.ConnectTimeout
  IF T THEN tcwm_options(SELF.hConn,TCWM:OptConnectTimeout,ADDRESS(T)).
  B = CHOOSE(SELF.SSL <> 0)
  tcwm_options(SELF.hConn,TCWM:OptSslEnforce,ADDRESS(B))
  tcwm_options(SELF.hConn,TCWM:OptSslVerify,ADDRESS(B))
  H = CHOOSE(SELF.Host = '','127.0.0.1',SELF.Host)
  U = SELF.User
  Pw = SELF.Password
  D = SELF.Database
  IF tcwm_real_connect(SELF.hConn,ADDRESS(H),ADDRESS(U),ADDRESS(Pw),CHOOSE(D = '',0,ADDRESS(D)), |
                       CHOOSE(SELF.Port > 0,SELF.Port,3306),0,TCWM:ClientMultiResults + TCWM:ClientMultiStatements) = 0
    SELF.TakeError('No se pudo conectar a ' & H & ':' & SELF.Port)
    tcwm_close(SELF.hConn)
    SELF.hConn = 0
    RETURN Level:Notify
  END
  IF SELF.Charset <> ''
    Cs = SELF.Charset
    IF tcwm_set_character_set(SELF.hConn,ADDRESS(Cs)) THEN RETURN SELF.TakeError('Juego de caracteres ' & Cs).
  END
  SELF.LastError = ''
  SELF.LastErrno = 0
  RETURN Level:Benign

TCWMariaDB.Disconnect PROCEDURE()
  CODE
  SELF.FreeResult()
  SELF.ClearBatch()
  SELF.PrepSql = ''
  FREE(SELF.Campos)
  IF SELF.hConn
    tcwm_close(SELF.hConn)
    SELF.hConn = 0
  END

TCWMariaDB.Connected PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.hConn <> 0)

TCWMariaDB.Ping PROCEDURE()
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion').
  IF tcwm_ping(SELF.hConn) THEN RETURN SELF.TakeError('Ping').
  RETURN Level:Benign

!------------------------------------------------------------------------------
! con parametros (AddParam) reemplaza cada '?' por el valor escapado; despues los borra
TCWMariaDB.Query PROCEDURE(STRING pSql)
  CODE
  IF RECORDS(SELF.Params) = 0 THEN RETURN SELF.SendQuery(pSql).
  IF NOT SELF.hConn THEN SELF.ClearParams() ; RETURN SELF.SetError('No hay conexion con el servidor (llame a Connect)').
  RETURN SELF.SendQuery(SELF.Interpolate(pSql))

TCWMariaDB.SendQuery PROCEDURE(STRING pSql)
L       LONG,AUTO
R       LONG,AUTO
  CODE
  SELF.FreeResult()
  SELF.AffectedRows = 0
  SELF.InsertId = 0
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion con el servidor (llame a Connect)').
  L = LEN(CLIP(pSql))
  R = tcwm_real_query(SELF.hConn,ADDRESS(pSql),L)
  IF R AND SELF.AutoReconnect
    SELF.LastErrno = tcwm_errno(SELF.hConn)
    IF SELF.LastErrno = TCWM:ServerGone OR SELF.LastErrno = TCWM:ServerLost
      IF SELF.Connect() = Level:Benign THEN R = tcwm_real_query(SELF.hConn,ADDRESS(pSql),L).
      IF NOT SELF.hConn THEN RETURN Level:Notify.
    END
  END
  IF R THEN RETURN SELF.TakeError('Error en la consulta').
  SELF.hRes = tcwm_store_result(SELF.hConn)
  IF SELF.hRes = 0
    IF tcwm_field_count(SELF.hConn) THEN RETURN SELF.TakeError('Error al leer el resultado').
    SELF.AffectedRows = tcwm_affected_rows(SELF.hConn)
    SELF.InsertId = tcwm_insert_id(SELF.hConn)
    ! varias sentencias ('UPDATE ...; SELECT ...'): como en SQL Server, pasa al primer resultado con columnas
    IF tcwm_more_results(SELF.hConn) THEN SELF.NextResult().
  ELSE
    SELF.NumFields = tcwm_num_fields(SELF.hRes)
    SELF.AffectedRows = tcwm_num_rows(SELF.hRes)
  END
  SELF.LastError = ''
  SELF.LastErrno = 0
  RETURN Level:Benign

! libera el resultado y descarta los que queden pendientes (un CALL devuelve un resultado extra de estado)
TCWMariaDB.FreeResult PROCEDURE()
R       LONG,AUTO
  CODE
  IF SELF.hRes
    tcwm_free_result(SELF.hRes)
    SELF.hRes = 0
  END
  SELF.Row = 0
  SELF.Lengths = 0
  SELF.NumFields = 0
  IF SELF.hConn
    LOOP WHILE tcwm_more_results(SELF.hConn)
      IF tcwm_next_result(SELF.hConn) <> 0 THEN BREAK.
      R = tcwm_store_result(SELF.hConn)
      IF R THEN tcwm_free_result(R).
    END
  END

! siguiente resultado con columnas (un CALL devuelve ademas uno de estado, sin columnas, que se saltea)
TCWMariaDB.NextResult PROCEDURE()
R       LONG,AUTO
  CODE
  IF NOT SELF.hConn THEN RETURN Level:Notify.
  IF SELF.hRes
    tcwm_free_result(SELF.hRes)                         ! solo el actual: los pendientes siguen
    SELF.hRes = 0
  END
  SELF.Row = 0
  SELF.Lengths = 0
  SELF.NumFields = 0
  LOOP WHILE tcwm_more_results(SELF.hConn)
    R = tcwm_next_result(SELF.hConn)
    IF R > 0 THEN RETURN SELF.TakeError('Error en el resultado siguiente').
    IF R < 0 THEN BREAK.
    SELF.hRes = tcwm_store_result(SELF.hConn)
    IF SELF.hRes
      SELF.NumFields = tcwm_num_fields(SELF.hRes)
      SELF.AffectedRows = tcwm_num_rows(SELF.hRes)
      RETURN Level:Benign
    END
    IF tcwm_field_count(SELF.hConn) THEN RETURN SELF.TakeError('Error al leer el resultado siguiente').
  END
  RETURN Level:Notify

!------------------------------------------------------------------------------ parametros '?'
TCWMariaDB.AddParam PROCEDURE(STRING pValue)
L       LONG,AUTO
  CODE
  L = LEN(CLIP(pValue))
  SELF.Params.Val &= NEW STRING(CHOOSE(L > 0,L,1))
  IF L THEN SELF.Params.Val = pValue[1 : L].
  SELF.Params.Len = L
  ADD(SELF.Params)

TCWMariaDB.AddNullParam PROCEDURE()
  CODE
  SELF.Params.Val &= NEW STRING(1)
  SELF.Params.Len = -1
  ADD(SELF.Params)

TCWMariaDB.ClearParams PROCEDURE()
I       LONG,AUTO
  CODE
  LOOP I = 1 TO RECORDS(SELF.Params)
    GET(SELF.Params,I)
    DISPOSE(SELF.Params.Val)
  END
  FREE(SELF.Params)

TCWMariaDB.ParamCount PROCEDURE()
  CODE
  RETURN RECORDS(SELF.Params)

! reemplaza cada '?' que no este entre comillas ('...', "..." o `...`) por el parametro siguiente: 'valor' escapado
! o NULL. Consume los parametros. Si no alcanzan, el '?' queda y el servidor da el error.
TCWMariaDB.Interpolate PROCEDURE(STRING pSql)
L       LONG,AUTO
Need    LONG,AUTO
I       LONG,AUTO
K       LONG,AUTO
Pos     LONG,AUTO
Q       STRING(1)
Buf     &STRING
Piece   ANY
Res     ANY
  CODE
  L = LEN(CLIP(pSql))
  Need = L + 1
  LOOP I = 1 TO RECORDS(SELF.Params)
    GET(SELF.Params,I)
    Need += CHOOSE(SELF.Params.Len > 0,SELF.Params.Len * 2,0) + 6
  END
  Buf &= NEW STRING(Need)
  Pos = 0
  K = 0
  Q = ''
  LOOP I = 1 TO L
    IF Q <> ''
      IF pSql[I] = Q THEN Q = ''.
      IF pSql[I] = '\' AND Q <> '`' AND I < L                 ! caracter escapado dentro de comillas
        Pos += 1 ; Buf[Pos] = pSql[I]
        I += 1
      END
    ELSIF pSql[I] = '''' OR pSql[I] = '"' OR pSql[I] = '`'
      Q = pSql[I]
    ELSIF pSql[I] = '?' AND K < RECORDS(SELF.Params)
      K += 1
      GET(SELF.Params,K)
      IF SELF.Params.Len < 0
        Piece = 'NULL'
      ELSIF SELF.Params.Len = 0
        Piece = ''''''
      ELSE
        Piece = SELF.Quote(SELF.Params.Val[1 : SELF.Params.Len])
      END
      Buf[Pos + 1 : Pos + LEN(Piece)] = Piece
      Pos += LEN(Piece)
      CYCLE
    END
    Pos += 1
    Buf[Pos] = pSql[I]
  END
  SELF.ClearParams()
  Res = Buf[1 : CHOOSE(Pos > 0,Pos,1)]
  IF Pos = 0 THEN Res = ''.
  DISPOSE(Buf)
  RETURN Res

!------------------------------------------------------------------------------ sentencias preparadas
! MySQL 5.0 no tiene arreglos de parametros: Prepare guarda la sentencia y los '?' se reemplazan al ejecutar.
! Si es un INSERT ... VALUES (...), AddRow arma un INSERT de varias filas (la forma rapida de MySQL).
TCWMariaDB.Prepare PROCEDURE(STRING pSql)
P       LONG,AUTO
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion con el servidor (llame a Connect)').
  SELF.ClearBatch()
  SELF.PrepSql = CLIP(pSql)
  SELF.BatchHead = ''
  SELF.BatchTpl = ''
  P = INSTRING(' VALUES',UPPER(SELF.PrepSql),1,1)
  IF UPPER(SUB(LEFT(SELF.PrepSql),1,7)) = 'INSERT ' AND P > 0
    SELF.BatchHead = SUB(SELF.PrepSql,1,P + 6)
    SELF.BatchTpl = SUB(SELF.PrepSql,P + 7,LEN(SELF.PrepSql) - P - 6)
  END
  RETURN Level:Benign

TCWMariaDB.PrepareIfNew PROCEDURE(STRING pSql)
  CODE
  IF SELF.PrepSql <> '' AND SELF.PrepSql = CLIP(pSql) THEN RETURN Level:Benign.
  IF SELF.BatchRows THEN SELF.EnviarLote().            ! las filas pendientes son de la sentencia anterior
  RETURN SELF.Prepare(pSql)

TCWMariaDB.ExecPrepared PROCEDURE()
R       BYTE,AUTO
  CODE
  IF SELF.PrepSql = '' THEN SELF.ClearParams() ; RETURN SELF.SetError('No hay sentencia preparada (llame a Prepare)').
  IF SELF.BatchRows = 0 THEN RETURN SELF.Query(SELF.PrepSql).
  R = SELF.SendQuery(SELF.Batch[1 : SELF.BatchLen])
  SELF.ClearBatch()
  RETURN R

TCWMariaDB.AddRow PROCEDURE()
  CODE
  IF SELF.PrepSql = '' THEN SELF.ClearParams() ; RETURN SELF.SetError('No hay sentencia preparada (llame a Prepare)').
  IF SELF.BatchTpl = '' THEN RETURN SELF.Query(SELF.PrepSql).   ! no es INSERT ... VALUES: va fila por fila
  IF SELF.BatchRows = 0
    SELF.AppendBatch(SELF.BatchHead & SELF.Interpolate(SELF.BatchTpl))
  ELSE
    SELF.AppendBatch(',' & SELF.Interpolate(SELF.BatchTpl))
  END
  SELF.BatchRows += 1
  IF (SELF.BatchSize AND SELF.BatchRows >= SELF.BatchSize) OR (SELF.MaxBatchBytes AND SELF.BatchLen >= SELF.MaxBatchBytes)
    RETURN SELF.ExecPrepared()
  END
  RETURN Level:Benign

TCWMariaDB.PendingRows PROCEDURE()
  CODE
  RETURN SELF.BatchRows

TCWMariaDB.EnviarLote PROCEDURE()
  CODE
  IF SELF.BatchRows = 0 THEN RETURN Level:Benign.
  RETURN SELF.ExecPrepared()

TCWMariaDB.AppendBatch PROCEDURE(STRING pText)
L       LONG,AUTO
NewBuf  &STRING
  CODE
  L = LEN(pText)
  IF SELF.Batch &= NULL OR SELF.BatchLen + L > SIZE(SELF.Batch)
    NewBuf &= NEW STRING(CHOOSE(SELF.BatchLen + L > 65536,(SELF.BatchLen + L) * 2,65536))
    IF SELF.BatchLen THEN NewBuf[1 : SELF.BatchLen] = SELF.Batch[1 : SELF.BatchLen].
    IF NOT SELF.Batch &= NULL THEN DISPOSE(SELF.Batch).
    SELF.Batch &= NewBuf
  END
  IF L THEN SELF.Batch[SELF.BatchLen + 1 : SELF.BatchLen + L] = pText.
  SELF.BatchLen += L

TCWMariaDB.ClearBatch PROCEDURE()
  CODE
  SELF.BatchLen = 0
  SELF.BatchRows = 0

!------------------------------------------------------------------------------ INSERT por nombre de campo
TCWMariaDB.Campo PROCEDURE(STRING pNombre,STRING pValor)
  CODE
  SELF.Campos.Nombre = CLIP(pNombre)
  ADD(SELF.Campos)
  SELF.AddParam(pValor)

TCWMariaDB.CampoNulo PROCEDURE(STRING pNombre)
  CODE
  SELF.Campos.Nombre = CLIP(pNombre)
  ADD(SELF.Campos)
  SELF.AddNullParam()

TCWMariaDB.CampoFecha PROCEDURE(STRING pNombre,LONG pFecha)
  CODE
  IF pFecha = 0
    SELF.CampoNulo(pNombre)
  ELSE
    SELF.Campo(pNombre,FORMAT(pFecha,@d10-))
  END

TCWMariaDB.CampoFechaHora PROCEDURE(STRING pNombre,LONG pFecha,LONG pHora)
  CODE
  IF pFecha = 0
    SELF.CampoNulo(pNombre)
  ELSE
    SELF.Campo(pNombre,FORMAT(pFecha,@d10-) & ' ' & CHOOSE(pHora > 0,FORMAT(pHora,@t04),'00:00:00'))
  END

! 'INSERT INTO tabla (c1,c2,...) VALUES (?,?,...)' con los campos agregados (y los borra)
TCWMariaDB.InsertSql PROCEDURE(STRING pTabla)
Cols    CSTRING(16384)
Marks   CSTRING(4096)
I       LONG,AUTO
  CODE
  LOOP I = 1 TO RECORDS(SELF.Campos)
    GET(SELF.Campos,I)
    Cols = Cols & CHOOSE(I > 1,',','') & SELF.Campos.Nombre
    Marks = Marks & CHOOSE(I > 1,',?','?')
  END
  FREE(SELF.Campos)
  RETURN 'INSERT INTO ' & CLIP(pTabla) & ' (' & Cols & ') VALUES (' & Marks & ')'

TCWMariaDB.Insertar PROCEDURE(STRING pTabla)
Sql     CSTRING(20480)
  CODE
  Sql = SELF.InsertSql(pTabla)
  IF SELF.PrepareIfNew(Sql) THEN SELF.ClearParams() ; RETURN Level:Notify.
  RETURN SELF.ExecPrepared()

TCWMariaDB.InsertarLote PROCEDURE(STRING pTabla)
Sql     CSTRING(20480)
  CODE
  Sql = SELF.InsertSql(pTabla)
  IF SELF.PrepareIfNew(Sql) THEN SELF.ClearParams() ; RETURN Level:Notify.
  RETURN SELF.AddRow()

TCWMariaDB.HasResult PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.hRes <> 0)

TCWMariaDB.Next PROCEDURE()
  CODE
  IF NOT SELF.hRes THEN RETURN Level:Notify.
  SELF.Row = tcwm_fetch_row(SELF.hRes)
  IF SELF.Row = 0
    SELF.Lengths = 0
    RETURN Level:Notify
  END
  SELF.Lengths = tcwm_fetch_lengths(SELF.hRes)
  RETURN Level:Benign

TCWMariaDB.Columns PROCEDURE()
  CODE
  RETURN SELF.NumFields

TCWMariaDB.RowCount PROCEDURE()
  CODE
  IF NOT SELF.hRes THEN RETURN 0.
  RETURN tcwm_num_rows(SELF.hRes)

TCWMariaDB.Col PROCEDURE(LONG pCol)
P       LONG,AUTO
L       LONG,AUTO
  CODE
  IF NOT SELF.Row OR pCol < 1 OR pCol > SELF.NumFields THEN RETURN ''.
  PEEK(SELF.Row + (pCol - 1) * 4,P)
  IF P = 0 THEN RETURN ''.                              ! NULL
  PEEK(SELF.Lengths + (pCol - 1) * 4,L)
  IF L <= 0 THEN RETURN ''.
  IF SELF.ValBuf &= NULL OR SIZE(SELF.ValBuf) < L
    IF NOT SELF.ValBuf &= NULL THEN DISPOSE(SELF.ValBuf).
    SELF.ValBuf &= NEW STRING(CHOOSE(L < 4096,4096,L))
  END
  tcwm_MoveMemory(ADDRESS(SELF.ValBuf),P,L)
  RETURN SELF.ValBuf[1 : L]

TCWMariaDB.IsNull PROCEDURE(LONG pCol)
P       LONG,AUTO
  CODE
  IF NOT SELF.Row OR pCol < 1 OR pCol > SELF.NumFields THEN RETURN 1.
  PEEK(SELF.Row + (pCol - 1) * 4,P)
  RETURN CHOOSE(P = 0)

TCWMariaDB.ColName PROCEDURE(LONG pCol)
F       LONG,AUTO
P       LONG,AUTO
  CODE
  IF NOT SELF.hRes OR pCol < 1 OR pCol > SELF.NumFields THEN RETURN ''.
  F = tcwm_fetch_field_direct(SELF.hRes,pCol - 1)
  IF F = 0 THEN RETURN ''.
  PEEK(F,P)                                             ! MYSQL_FIELD.name es el primer miembro
  RETURN SELF.PtrToString(P)

TCWMariaDB.ColIndex PROCEDURE(STRING pName)
I       LONG,AUTO
  CODE
  LOOP I = 1 TO SELF.NumFields
    IF UPPER(SELF.ColName(I)) = UPPER(CLIP(pName)) THEN RETURN I.
  END
  RETURN 0

!------------------------------------------------------------------------------
! escapa un valor para usarlo entre comillas en un SQL (comillas, barra invertida, NUL, saltos de linea)
TCWMariaDB.Escape PROCEDURE(STRING pText)
L       LONG,AUTO
N       LONG,AUTO
I       LONG,AUTO
Buf     &STRING
Res     ANY
  CODE
  L = LEN(CLIP(pText))
  IF L = 0 THEN RETURN ''.
  Buf &= NEW STRING(L * 2 + 1)
  IF SELF.hConn
    N = tcwm_real_escape_string(SELF.hConn,ADDRESS(Buf),ADDRESS(pText),L)
  ELSE                                                  ! sin conexion: escape basico
    N = 0
    LOOP I = 1 TO L
      CASE VAL(pText[I])
      OF 39 OROF 92 OROF 34
        N += 1; Buf[N] = '\'
      OF 0
        N += 1; Buf[N] = '\'; N += 1; Buf[N] = '0'; CYCLE
      OF 10
        N += 1; Buf[N] = '\'; N += 1; Buf[N] = 'n'; CYCLE
      OF 13
        N += 1; Buf[N] = '\'; N += 1; Buf[N] = 'r'; CYCLE
      END
      N += 1; Buf[N] = pText[I]
    END
  END
  Res = Buf[1 : N]
  DISPOSE(Buf)
  RETURN Res

TCWMariaDB.Quote PROCEDURE(STRING pText)
  CODE
  RETURN '''' & SELF.Escape(pText) & ''''

TCWMariaDB.BeginTransaction PROCEDURE()
  CODE
  RETURN SELF.Query('START TRANSACTION')

TCWMariaDB.Commit PROCEDURE()
  CODE
  RETURN SELF.Query('COMMIT')

TCWMariaDB.Rollback PROCEDURE()
  CODE
  RETURN SELF.Query('ROLLBACK')

TCWMariaDB.ServerVersion PROCEDURE()
  CODE
  IF NOT SELF.hConn THEN RETURN ''.
  RETURN SELF.PtrToString(tcwm_get_server_info(SELF.hConn))

TCWMariaDB.ClientVersion PROCEDURE()
  CODE
  RETURN SELF.PtrToString(tcwm_get_client_info())

!------------------------------------------------------------------------------ internos
TCWMariaDB.SetError PROCEDURE(STRING pText,LONG pErrno=0)
  CODE
  SELF.LastError = pText
  SELF.LastErrno = pErrno
  RETURN Level:Notify

TCWMariaDB.TakeError PROCEDURE(STRING pWhat)
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError(pWhat).
  SELF.LastErrno = tcwm_errno(SELF.hConn)
  SELF.LastError = CLIP(pWhat) & ': ' & SELF.PtrToString(tcwm_error(SELF.hConn)) & ' (' & SELF.LastErrno & ')'
  RETURN Level:Notify

TCWMariaDB.PtrToString PROCEDURE(LONG pPtr)
L       LONG,AUTO
  CODE
  IF pPtr = 0 THEN RETURN ''.
  L = tcwm_lstrlen(pPtr)
  IF L <= 0 THEN RETURN ''.
  IF SELF.ValBuf &= NULL OR SIZE(SELF.ValBuf) < L
    IF NOT SELF.ValBuf &= NULL THEN DISPOSE(SELF.ValBuf).
    SELF.ValBuf &= NEW STRING(CHOOSE(L < 4096,4096,L))
  END
  tcwm_MoveMemory(ADDRESS(SELF.ValBuf),pPtr,L)
  RETURN SELF.ValBuf[1 : L]

