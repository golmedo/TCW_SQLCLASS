  PROGRAM
!==============================================================================
! Prueba de velocidad: SQL Server directo por ODBC (tcwodbc.c) contra el driver MSSQL de Clarion.
!   BenchMSSQL.exe            lee bench.ini ([Conexion] Odbc= / Clarion=, [Bench] Corridas= Motores= Escritura=)
! Lectura: misma consulta sobre dbo.Cbtes con 10 motores (directo, SQLClass, driver MSSQL con y sin BUFFER); cada uno
! carga una cola con las mismas 9 columnas (con DEFORMAT de la fecha, como LoadQueue). Control: mismas filas y misma
! suma de importes. Escritura (Escritura=n): n INSERT en tempdb.dbo.tcw_bench (se crea y se borra) de 6 formas (driver con
! y sin LOGOUT, SQLMsClass, clase directa sin y con transaccion, y de a 500 filas por sentencia).
! Resultado en resultados.txt.
!==============================================================================
  INCLUDE('SQLClass6.INC'),ONCE
  INCLUDE('SQLClass6MsDirect.inc'),ONCE
  PRAGMA('compile(tcwodbc.c)')
QPCGroup        GROUP,TYPE
Lo                ULONG
Hi                ULONG
                END
  MAP
    MODULE('tcwodbc.c')
tco_connect     PROCEDURE(*CSTRING pConn,*CSTRING pErr,LONG pErrLen),LONG,RAW,NAME('_tco_connect')
tco_disconnect  PROCEDURE(LONG pDbc),NAME('_tco_disconnect')
tco_exec        PROCEDURE(LONG pDbc,*CSTRING pSql,LONG pBlock,*CSTRING pErr,LONG pErrLen),LONG,RAW,NAME('_tco_exec')
tco_fetch       PROCEDURE(LONG pRes,*CSTRING pErr,LONG pErrLen),LONG,RAW,NAME('_tco_fetch')
tco_get         PROCEDURE(LONG pRes,LONG pRow,LONG pCol,*CSTRING pOut,LONG pOutLen),LONG,RAW,PROC,NAME('_tco_get')
tco_close       PROCEDURE(LONG pRes),NAME('_tco_close')
    END
    MODULE('kernel32')
QPC             PROCEDURE(*QPCGroup pCounter),LONG,PASCAL,RAW,PROC,NAME('QueryPerformanceCounter')
QPF             PROCEDURE(*QPCGroup pFreq),LONG,PASCAL,RAW,PROC,NAME('QueryPerformanceFrequency')
    END
Log             PROCEDURE(STRING pText)
Ms              PROCEDURE(),REAL
Correr          PROCEDURE(LONG pMotor),LONG          ! carga la cola con la consulta del escenario; 0 = bien
CargarDirecto   PROCEDURE(LONG pBlock),LONG
SumarCola       PROCEDURE()
Escribir        PROCEDURE()
DirectoExec     PROCEDURE(STRING pSql),LONG,PROC         ! sentencia sin resultado por la conexion directa; 0 = bien
DirectoValor    PROCEDURE(STRING pSql),STRING            ! primer valor de una consulta por la conexion directa
  END

LogFile         FILE,DRIVER('ASCII'),NAME('resultados.txt'),CREATE
Rec               RECORD
Line                STRING(2048)
                  END
                END

! tabla de trabajo de la SQLClass (ya existe en la base: 20 campos varchar(49))
SQLClassF       FILE,DRIVER('MSSQL'),NAME('SQLClass'),PRE(uSQL),CREATE
Record            RECORD,PRE()
f1                  CSTRING(50)
f2                  CSTRING(50)
f3                  CSTRING(50)
f4                  CSTRING(50)
f5                  CSTRING(50)
f6                  CSTRING(50)
f7                  CSTRING(50)
f8                  CSTRING(50)
f9                  CSTRING(50)
f10                 CSTRING(50)
f11                 CSTRING(50)
f12                 CSTRING(50)
f13                 CSTRING(50)
f14                 CSTRING(50)
f15                 CSTRING(50)
f16                 CSTRING(50)
f17                 CSTRING(50)
f18                 CSTRING(50)
f19                 CSTRING(50)
f20                 CSTRING(50)
                  END
                END

! dbo.Cbtes con solo las 9 columnas de la prueba (los drivers SQL no exigen todas)
Cbtes           FILE,DRIVER('MSSQL'),NAME('dbo.Cbtes'),PRE(CBT)
PkCbtes           KEY(CBT:IdTransaccion),PRIMARY,NAME('PkCbtes')
Record            RECORD,PRE()
IdTransaccion       LONG
Fecha               DATE
TipoCbte            STRING(3)
Letra_Cbte          STRING(1)
NroCbte             DECIMAL(18)
IdCliente           LONG
Descripcion         STRING(50)
ImporteTotal        DECIMAL(17,2)
Saldo               DECIMAL(13,2)
                  END
                END

! la misma tabla para FILE + PROP:SQL con BUFFER (el BUFFER queda puesto en el archivo)
Cbtes2          FILE,DRIVER('MSSQL'),NAME('dbo.Cbtes'),PRE(CB2)
PkCbtes2          KEY(CB2:IdTransaccion),PRIMARY,NAME('PkCbtes')
Record            RECORD,PRE()
IdTransaccion       LONG
Fecha               DATE
TipoCbte            STRING(3)
Letra_Cbte          STRING(1)
NroCbte             DECIMAL(18)
IdCliente           LONG
Descripcion         STRING(50)
ImporteTotal        DECIMAL(17,2)
Saldo               DECIMAL(13,2)
                  END
                END

! tabla de trabajo de la SQLClass para el motor 'como SQLMsClass con BUFFER' (SQLClass6 cierra y abre su archivo
! en cada consulta, asi que un BUFFER puesto desde afuera se pierde: aca se hace lo mismo que ella pero con BUFFER)
SQLClassF2      FILE,DRIVER('MSSQL'),NAME('SQLClass'),PRE(uSQ2)
Record            RECORD,PRE()
f1                 CSTRING(50)
f2                 CSTRING(50)
f3                 CSTRING(50)
f4                 CSTRING(50)
f5                 CSTRING(50)
f6                 CSTRING(50)
f7                 CSTRING(50)
f8                 CSTRING(50)
f9                 CSTRING(50)
f10                CSTRING(50)
f11                CSTRING(50)
f12                CSTRING(50)
f13                CSTRING(50)
f14                CSTRING(50)
f15                CSTRING(50)
f16                CSTRING(50)
f17                CSTRING(50)
f18                CSTRING(50)
f19                CSTRING(50)
f20                CSTRING(50)
                  END
                END

! prueba de escritura: tabla comun en tempdb (el driver de Clarion no abre una ##temporal: la busca en el catalogo);
! se crea y se borra en la prueba y no toca la base de la aplicacion. El owner del archivo apunta a tempdb.
BenchF          FILE,DRIVER('MSSQL'),NAME('dbo.tcw_bench'),PRE(BF)
PkBench           KEY(BF:Id),PRIMARY
Record            RECORD,PRE()
Id                  LONG
Nombre              STRING(50)
Importe             DECIMAL(12,2)
Fecha               DATE
                  END
                END

CbtV            VIEW(Cbtes)
                  PROJECT(CBT:IdTransaccion)
                  PROJECT(CBT:Fecha)
                  PROJECT(CBT:TipoCbte)
                  PROJECT(CBT:Letra_Cbte)
                  PROJECT(CBT:NroCbte)
                  PROJECT(CBT:IdCliente)
                  PROJECT(CBT:Descripcion)
                  PROJECT(CBT:ImporteTotal)
                  PROJECT(CBT:Saldo)
                END

Q               QUEUE,PRE(Q)
IdTransaccion     LONG
Fecha             LONG
TipoCbte          STRING(3)
Letra             STRING(1)
NroCbte           LONG
IdCliente         LONG
Cliente           STRING(50)
Total             DECIMAL(17,2)
Saldo             DECIMAL(13,2)
                END

N_MOT           EQUATE(10)
N_ESC           EQUATE(6)
MotNombre       STRING(34),DIM(N_MOT)
EscNombre       STRING(32),DIM(N_ESC)
EscWhere        CSTRING(200),DIM(N_ESC)
EscTop          LONG,DIM(N_ESC)
SQL             &SQLMsClass
SQLD            &SQLMsDirectClass
OdbcConn        CSTRING(1024)
Owner           CSTRING(512)
Dbc             LONG
Err             CSTRING(2048)
Query           CSTRING(4000)
Buf             CSTRING(8001)
Freq            REAL
Rep             LONG
Detalle         BYTE
Motores         CSTRING(80)
Activo          BYTE,DIM(N_MOT)
RefM            LONG
NEsc            LONG
Fld             ANY
R               LONG
M               LONG
E               LONG
T0              REAL
Tiempo          REAL,DIM(N_MOT)
Filas           LONG,DIM(N_MOT)
Suma            DECIMAL(19,2),DIM(N_MOT)
Total           DECIMAL(19,2)
Falla           STRING(200),DIM(N_MOT)
Mejor           REAL
Linea           STRING(300)
G               LIKE(QPCGroup)
AnyField        ANY

  CODE
  CREATE(LogFile)
  OPEN(LogFile)
  QPF(G)
  Freq = G.Hi * 4294967296 + G.Lo
  OdbcConn = GETINI('Conexion','Odbc','',LONGPATH() & '\bench.ini')
  Owner    = GETINI('Conexion','Clarion','',LONGPATH() & '\bench.ini')
  Rep      = GETINI('Bench','Corridas',3,LONGPATH() & '\bench.ini')
  Detalle  = GETINI('Bench','Detalle',0,LONGPATH() & '\bench.ini')     ! 1 = una linea por corrida
  Motores  = GETINI('Bench','Motores','1,2,3,4,5,6,7,8,9,10',LONGPATH() & '\bench.ini')
  NEsc     = GETINI('Bench','Escritura',0,LONGPATH() & '\bench.ini')   ! filas a insertar (0 = sin prueba de escritura)
  LOOP M = 1 TO N_MOT
    Activo[M] = CHOOSE(INSTRING(',' & M & ',',',' & Motores & ',',1,1) > 0)
    IF Activo[M] AND RefM = 0 THEN RefM = M.
  END
  IF OdbcConn = '' OR Owner = '' THEN Log('Falta bench.ini ([Conexion] Odbc= y Clarion=)'); CLOSE(LogFile); RETURN.

  MotNombre[1] = 'Directo ODBC, bloques de 500'
  MotNombre[2] = 'Directo ODBC, fila por fila'
  MotNombre[3] = 'SQLMsClass (driver MSSQL)'
  MotNombre[4] = 'Driver MSSQL: FILE + PROP:SQL'
  MotNombre[5] = 'Driver MSSQL: VIEW + SET/NEXT'
  MotNombre[6] = 'SQLMsDirectClass (clase nueva)'
  MotNombre[7] = 'Driver MSSQL: VIEW + BUFFER(100)'
  MotNombre[8] = 'Driver MSSQL: VIEW + BUFFER(500)'
  MotNombre[9] = 'Driver: FILE+PROP:SQL+BUFFER(500)'
  MotNombre[10] = 'Como SQLMsClass + BUFFER(500)'

  ! --- conexiones
  Dbc = tco_connect(OdbcConn,Err,SIZE(Err))
  IF NOT Dbc THEN Log('Directo: no conecta: ' & Err); CLOSE(LogFile); RETURN.
  SQL &= NEW SQLMsClass
  SQL.SilentMode = True
  IF SQL.Init(SQLClassF,uSQL:Record,Owner) THEN Log('SQLMsClass: no conecta: ' & ERROR() & ' ' & FILEERROR()); CLOSE(LogFile); RETURN.
  SQLD &= NEW SQLMsDirectClass
  SQLD.SilentMode = True
  IF SQLD.InitDirect(Owner) THEN Log('SQLMsDirectClass: no conecta: ' & SQLD.ErrorText()); CLOSE(LogFile); RETURN.
  Log('SQLMsDirectClass con el mismo owner: ' & SQLD.Db.ClientVersion())
  Cbtes{PROP:Owner} = Owner
  OPEN(Cbtes,42h)
  IF ERRORCODE() THEN Log('Driver MSSQL: OPEN(Cbtes) ' & ERROR() & ' ' & FILEERROR()); CLOSE(LogFile); RETURN.
  Cbtes2{PROP:Owner} = Owner
  OPEN(Cbtes2,42h)
  BUFFER(Cbtes2,500)
  SQLClassF2{PROP:Owner} = Owner

  ! --- con que cliente habla cada uno (version de TDS y nombre del driver)
  Query = 'SELECT CONVERT(varchar(10), CONVERT(varbinary(4), c.protocol_version), 2), s.client_interface_name, s.program_name' & |
          ' FROM sys.dm_exec_connections c JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id WHERE c.session_id = @@SPID'
  E = tco_exec(Dbc,Query,1,Err,SIZE(Err))
  IF E AND tco_fetch(E,Err,SIZE(Err)) > 0
    tco_get(E,1,1,Buf,SIZE(Buf)) ; Linea = 'Directo:      TDS ' & Buf
    tco_get(E,1,2,Buf,SIZE(Buf)) ; Linea = CLIP(Linea) & '  ' & Buf
    Log(Linea)
  ELSE
    Log('Directo: no se pudo leer la sesion: ' & Err)
  END
  tco_close(E)
  IF NOT SQL.ExecEx(Query,1) AND NOT SQL.Next()
    Log('Driver MSSQL: TDS ' & SQL.Col(1) & '  ' & SQL.Col(2) & '  ' & SQL.Col(3))
  END
  ! un comprobante cualquiera para el escenario 'uno por Id'
  Query = 'SELECT TOP 1 IdTransaccion FROM dbo.Cbtes ORDER BY Fecha DESC, IdTransaccion DESC'
  E = tco_exec(Dbc,Query,1,Err,SIZE(Err))
  IF E AND tco_fetch(E,Err,SIZE(Err)) > 0 THEN tco_get(E,1,1,Buf,SIZE(Buf)).
  tco_close(E)

  EscNombre[1] = 'Toda la tabla'             ; EscWhere[1] = ''                                                ; EscTop[1] = 0
  EscNombre[2] = 'Ultimos 30000'             ; EscWhere[2] = ''                                                ; EscTop[2] = 30000
  EscNombre[3] = 'Fecha: anio 2025'          ; EscWhere[3] = 'Fecha BETWEEN ''2025-01-01'' AND ''2025-12-31''' ; EscTop[3] = 0
  EscNombre[4] = 'Razon social LIKE %SRL%'   ; EscWhere[4] = 'Descripcion LIKE ''%SRL%'''                      ; EscTop[4] = 0
  EscNombre[5] = 'Un cliente (20006)'        ; EscWhere[5] = 'IdCliente = 20006'                               ; EscTop[5] = 0
  EscNombre[6] = 'Un comprobante por Id'     ; EscWhere[6] = 'IdTransaccion = ' & Buf                          ; EscTop[6] = 0

  Log('Promedio de ' & Rep & ' corridas (mas 1 de calentamiento). Tiempo = consulta + carga de la cola, en ms.')
  LOOP E = 1 TO N_ESC
    Query = 'SELECT ' & CHOOSE(EscTop[E] > 0,'TOP ' & EscTop[E] & ' ','') & |
            'IdTransaccion, Fecha, TipoCbte, Letra_Cbte, NroCbte, IdCliente, Descripcion, ImporteTotal, Saldo FROM dbo.Cbtes' & |
            CHOOSE(EscWhere[E] <> '',' WHERE ' & EscWhere[E],'') & ' ORDER BY Fecha DESC, IdTransaccion DESC'
    LOOP M = 1 TO N_MOT
      Tiempo[M] = 0
      Falla[M] = ''
    END
    LOOP R = 0 TO Rep                                   ! la corrida 0 calienta la cache y no se cuenta
      LOOP M = 1 TO N_MOT
        ! se rota quien empieza en cada corrida
        IF NOT Activo[(M + R - 1) % N_MOT + 1] THEN CYCLE.
        IF Correr((M + R - 1) % N_MOT + 1) THEN CYCLE.
      END
    END
    Log('')
    Log(CLIP(EscNombre[E]) & ':  ' & Query)
    Mejor = 0
    LOOP M = 1 TO N_MOT
      IF Activo[M] AND Falla[M] = '' AND (Mejor = 0 OR Tiempo[M] < Mejor) THEN Mejor = Tiempo[M].
    END
    LOOP M = 1 TO N_MOT
      IF NOT Activo[M] THEN CYCLE.
      IF Falla[M] <> ''
        Log('  ' & MotNombre[M] & '  ' & CLIP(Falla[M]))
        CYCLE
      END
      Log('  ' & MotNombre[M] & FORMAT(Filas[M],@n9) & ' filas ' & FORMAT(Tiempo[M] / Rep,@n9.1) & ' ms' & |
          CHOOSE(Mejor > 0 AND Tiempo[M] > Mejor,'  x ' & CLIP(LEFT(FORMAT(Tiempo[M] / Mejor,@n6.2))),'  (el mas rapido)') & |
          CHOOSE(Filas[M] = Filas[RefM] AND Suma[M] = Suma[RefM],'','  DISTINTO: ' & Filas[M] & ' filas, suma ' & Suma[M] & |
          ' contra ' & Filas[RefM] & ' / ' & Suma[RefM]))
    END
  END
  IF NEsc > 0 THEN Escribir().
  CLOSE(Cbtes)
  CLOSE(Cbtes2)
  SQL.Kill()
  SQLD.Kill()
  tco_disconnect(Dbc)
  CLOSE(LogFile)

!------------------------------------------------------------------------------
Correr PROCEDURE(LONG pMotor)
Res     LONG
  CODE
  FREE(Q)
  T0 = Ms()
  CASE pMotor
  OF 1
    Res = CargarDirecto(500)
  OF 2
    Res = CargarDirecto(1)
  OF 3
    IF SQL.ExecEx(Query,1)
      Falla[3] = 'error en la consulta'
      Res = 1
    ELSE
      SQL.Col_Format(2,'@d10-')
      SQL.LoadQueue(Q,0,0)
    END
  OF 4
    Cbtes{PROP:SQL} = Query
    IF ERRORCODE()
      Falla[4] = 'PROP:SQL: ' & FILEERROR()
      Res = 1
    ELSE
      LOOP
        NEXT(Cbtes)
        IF ERRORCODE() THEN BREAK.
        Q:IdTransaccion = CBT:IdTransaccion ; Q:Fecha = CBT:Fecha ; Q:TipoCbte = CBT:TipoCbte ; Q:Letra = CBT:Letra_Cbte
        Q:NroCbte = CBT:NroCbte ; Q:IdCliente = CBT:IdCliente ; Q:Cliente = CBT:Descripcion ; Q:Total = CBT:ImporteTotal
        Q:Saldo = CBT:Saldo
        ADD(Q)
      END
    END
  OF 5
    OPEN(CbtV)
    CbtV{PROP:Order} = '-CBT:Fecha,-CBT:IdTransaccion'
    CbtV{PROP:SQLFilter} = EscWhere[E]
    SET(CbtV)
    LOOP
      NEXT(CbtV)
      IF ERRORCODE() THEN BREAK.
      Q:IdTransaccion = CBT:IdTransaccion ; Q:Fecha = CBT:Fecha ; Q:TipoCbte = CBT:TipoCbte ; Q:Letra = CBT:Letra_Cbte
      Q:NroCbte = CBT:NroCbte ; Q:IdCliente = CBT:IdCliente ; Q:Cliente = CBT:Descripcion ; Q:Total = CBT:ImporteTotal
      Q:Saldo = CBT:Saldo
      ADD(Q)
      IF EscTop[E] AND RECORDS(Q) >= EscTop[E] THEN BREAK.     ! el VIEW no tiene TOP: corta al llegar
    END
    CLOSE(CbtV)
  OF 7 OROF 8
    OPEN(CbtV)
    BUFFER(CbtV,CHOOSE(pMotor = 7,100,500))
    CbtV{PROP:Order} = '-CBT:Fecha,-CBT:IdTransaccion'
    CbtV{PROP:SQLFilter} = EscWhere[E]
    SET(CbtV)
    LOOP
      NEXT(CbtV)
      IF ERRORCODE() THEN BREAK.
      Q:IdTransaccion = CBT:IdTransaccion ; Q:Fecha = CBT:Fecha ; Q:TipoCbte = CBT:TipoCbte ; Q:Letra = CBT:Letra_Cbte
      Q:NroCbte = CBT:NroCbte ; Q:IdCliente = CBT:IdCliente ; Q:Cliente = CBT:Descripcion ; Q:Total = CBT:ImporteTotal
      Q:Saldo = CBT:Saldo
      ADD(Q)
      IF EscTop[E] AND RECORDS(Q) >= EscTop[E] THEN BREAK.
    END
    CLOSE(CbtV)
  OF 9
    Cbtes2{PROP:SQL} = Query
    IF ERRORCODE()
      Falla[9] = 'PROP:SQL: ' & FILEERROR()
      Res = 1
    ELSE
      LOOP
        NEXT(Cbtes2)
        IF ERRORCODE() THEN BREAK.
        Q:IdTransaccion = CB2:IdTransaccion ; Q:Fecha = CB2:Fecha ; Q:TipoCbte = CB2:TipoCbte ; Q:Letra = CB2:Letra_Cbte
        Q:NroCbte = CB2:NroCbte ; Q:IdCliente = CB2:IdCliente ; Q:Cliente = CB2:Descripcion ; Q:Total = CB2:ImporteTotal
        Q:Saldo = CB2:Saldo
        ADD(Q)
      END
    END
  OF 10                                                 ! lo mismo que SQLMsClass.ExecEx + LoadQueue, con BUFFER despues del OPEN
    CLOSE(SQLClassF2)
    OPEN(SQLClassF2,42h)
    BUFFER(SQLClassF2,500)
    SQLClassF2{PROP:SQL} = Query
    IF ERRORCODE()
      Falla[10] = 'PROP:SQL: ' & FILEERROR()
      Res = 1
    ELSE
      LOOP
        NEXT(SQLClassF2)
        IF ERRORCODE() THEN BREAK.
        LOOP C# = 1 TO 9
          AnyField &= WHAT(Q,C#)
          Fld &= WHAT(uSQ2:Record,C#)
          IF C# = 2
            AnyField = DEFORMAT(Fld,@d10-)
          ELSE
            AnyField = Fld
          END
        END
        ADD(Q)
      END
    END
  OF 6
    IF SQLD.ExecEx(Query,1)
      Falla[6] = SQLD.ErrorText()
      Res = 1
    ELSE
      SQLD.Col_Format(2,'@d10-')
      SQLD.LoadQueue(Q,0,0)
    END
  END
  IF R > 0 THEN Tiempo[pMotor] += Ms() - T0.
  IF Detalle THEN Log('    esc ' & E & ' corrida ' & R & ' motor ' & pMotor & ': ' & RECORDS(Q) & ' filas ' & INT(Ms() - T0) & ' ms').
  SumarCola()
  Filas[pMotor] = RECORDS(Q)
  Suma[pMotor] = Total
  RETURN Res

! igual que LoadQueue: campo por campo con WHAT y la fecha con DEFORMAT
CargarDirecto PROCEDURE(LONG pBlock)
H       LONG
N       LONG
I       LONG
C       LONG
  CODE
  H = tco_exec(Dbc,Query,pBlock,Err,SIZE(Err))
  IF NOT H THEN Falla[CHOOSE(pBlock > 1,1,2)] = Err ; RETURN 1.
  LOOP
    N = tco_fetch(H,Err,SIZE(Err))
    IF N <= 0 THEN BREAK.
    LOOP I = 1 TO N
      LOOP C = 1 TO 9
        tco_get(H,I,C,Buf,SIZE(Buf))
        AnyField &= WHAT(Q,C)
        IF C = 2
          AnyField = DEFORMAT(Buf,@d10-)
        ELSE
          AnyField = Buf
        END
      END
      ADD(Q)
    END
  END
  tco_close(H)
  IF N < 0 THEN Falla[CHOOSE(pBlock > 1,1,2)] = Err ; RETURN 1.
  RETURN 0

!------------------------------------------------------------------------------ escritura
! NEsc filas en tempdb.dbo.tcw_bench de seis formas; antes de cada una se vacia la tabla; control: cantidad y suma de importes
Escribir PROCEDURE()
NW          EQUATE(8)
W           LONG
I           LONG
WNombre     STRING(40),DIM(NW)
WTiempo     REAL,DIM(NW)
WCtrl       STRING(120),DIM(NW)
Ins         CSTRING(300)
Lote        &CSTRING
EnLote      LONG
Esperado    DECIMAL(19,2)
Control     CSTRING(80)
CtrlN       LONG
CtrlSuma    DECIMAL(19,2)
  CODE
  WNombre[1] = 'Driver MSSQL: ADD sin LOGOUT'
  WNombre[2] = 'Driver MSSQL: LOGOUT + ADD + COMMIT'
  WNombre[3] = 'SQLMsClass: un INSERT por fila'
  WNombre[4] = 'SQLMsDirectClass: un INSERT por fila'
  WNombre[5] = 'SQLMsDirectClass: con transaccion'
  WNombre[6] = 'SQLMsDirectClass: transaccion, 250/INSERT'
  WNombre[7] = 'SQLMsDirectClass: Insertar (preparado)'
  WNombre[8] = 'SQLMsDirectClass: InsertarLote (500/viaje)'
  Log('')
  Log('Escritura: ' & NEsc & ' filas en tempdb.dbo.tcw_bench (Id, Nombre, Importe, Fecha), una corrida por forma')
  IF DirectoExec('IF OBJECT_ID(''tempdb.dbo.tcw_bench'') IS NOT NULL DROP TABLE tempdb.dbo.tcw_bench; ' & |
                 'CREATE TABLE tempdb.dbo.tcw_bench (Id INT PRIMARY KEY, Nombre VARCHAR(50), Importe DECIMAL(12,2), Fecha DATE)')
    Log('  no se pudo crear tempdb.dbo.tcw_bench: ' & Err)
    RETURN
  END
  ! mismo owner pero con la base tempdb (servidor,base,usuario,clave)
  I = INSTRING(',',Owner,1,1)
  Ins = SUB(Owner,1,I) & 'tempdb' & SUB(Owner,INSTRING(',',Owner,1,I + 1),LEN(Owner))
  BenchF{PROP:Owner} = Ins
  OPEN(BenchF,42h)
  IF ERRORCODE() THEN Log('  Driver MSSQL: OPEN(tempdb.dbo.tcw_bench) ' & ERROR() & ' ' & FILEERROR()).
  SQLD.Db.IdentityAfterInsert = False                   ! sin IDENTITY: no hace falta el SCOPE_IDENTITY de cada INSERT
  Esperado = 0
  LOOP I = 1 TO NEsc
    Esperado += I * 1.25
  END
  Lote &= NEW CSTRING(80000)
  LOOP W = 1 TO NW
    DirectoExec('DELETE FROM tempdb.dbo.tcw_bench')
    T0 = Ms()
    CASE W
    OF 1 OROF 2
      IF W = 2 THEN LOGOUT(5,BenchF).
      LOOP I = 1 TO NEsc
        BF:Id = I
        BF:Nombre = 'Cliente ' & I
        BF:Importe = I * 1.25
        BF:Fecha = DATE(1,1,2026) + I % 365
        ADD(BenchF)
        IF ERRORCODE() THEN WCtrl[W] = '  ADD: ' & ERROR() & ' ' & FILEERROR() ; BREAK.
      END
      IF W = 2 THEN COMMIT.
    OF 3 OROF 4 OROF 5
      IF W = 5 THEN SQLD.BeginTransaction().
      LOOP I = 1 TO NEsc
        Ins = 'INSERT INTO tempdb.dbo.tcw_bench (Id, Nombre, Importe, Fecha) VALUES (' & I & ', ''Cliente ' & I & ''', ' & I * 1.25 & |
              ', ''' & FORMAT(DATE(1,1,2026) + I % 365,@d10-) & ''')'
        IF W = 3
          IF SQL.ExecEx(Ins,1) THEN WCtrl[W] = '  INSERT con error' ; BREAK.
        ELSE
          IF SQLD.ExecEx(Ins,1) THEN WCtrl[W] = '  ' & SQLD.ErrorText() ; BREAK.
        END
      END
      IF W = 5 THEN SQLD.Commit().
    OF 6
      SQLD.BeginTransaction()
      EnLote = 0
      LOOP I = 1 TO NEsc
        IF EnLote = 0
          Lote = 'INSERT INTO tempdb.dbo.tcw_bench (Id, Nombre, Importe, Fecha) VALUES '
        ELSE
          Lote = Lote & ', '
        END
        Lote = Lote & '(' & I & ', ''Cliente ' & I & ''', ' & I * 1.25 & ', ''' & FORMAT(DATE(1,1,2026) + I % 365,@d10-) & ''')'
        EnLote += 1
        IF EnLote = 250 OR I = NEsc                    ! la SQLClass guarda la consulta en CSTRING(20480)
          IF SQLD.ExecEx(Lote,1) THEN WCtrl[W] = '  ' & SQLD.ErrorText() ; BREAK.
          EnLote = 0
        END
      END
      SQLD.Commit()
    OF 7 OROF 8                                       ! INSERT por nombre de campo: preparado una vez; 8 = de a 500 filas por viaje
      LOOP I = 1 TO NEsc
        SQLD.Campo('Id',I)
        SQLD.Campo('Nombre','Cliente ' & I)
        SQLD.Campo('Importe',I * 1.25)
        SQLD.CampoFecha('Fecha',DATE(1,1,2026) + I % 365)
        IF W = 7
          IF SQLD.Insertar('tempdb.dbo.tcw_bench') THEN WCtrl[W] = '  ' & SQLD.ErrorText() ; BREAK.
        ELSE
          IF SQLD.InsertarLote('tempdb.dbo.tcw_bench') THEN WCtrl[W] = '  ' & SQLD.ErrorText() ; BREAK.
        END
      END
      IF W = 8 AND SQLD.EnviarLote() THEN WCtrl[W] = '  ' & SQLD.ErrorText().
    END
    WTiempo[W] = Ms() - T0
    Control = DirectoValor('SELECT CAST(COUNT(*) AS varchar(20)) + ''/'' + CAST(ISNULL(SUM(Importe),0) AS varchar(30)) FROM tempdb.dbo.tcw_bench')
    CtrlN = SUB(Control,1,INSTRING('/',Control,1,1) - 1)
    CtrlSuma = SUB(Control,INSTRING('/',Control,1,1) + 1,30)
    IF WCtrl[W] = '' AND (CtrlN <> NEsc OR CtrlSuma <> Esperado)
      WCtrl[W] = '  CONTROL: ' & Control & ' (esperado ' & NEsc & '/' & Esperado & ')'
    END
    Log('  ' & WNombre[W] & FORMAT(WTiempo[W],@n10.1) & ' ms' & FORMAT(NEsc * 1000 / WTiempo[W],@n9) & ' filas/s' & CLIP(WCtrl[W]))
  END
  DISPOSE(Lote)
  CLOSE(BenchF)
  DirectoExec('DROP TABLE tempdb.dbo.tcw_bench')

DirectoExec PROCEDURE(STRING pSql)
H       LONG
  CODE
  Query = CLIP(pSql)
  H = tco_exec(Dbc,Query,1,Err,SIZE(Err))
  IF NOT H THEN RETURN 1.
  tco_close(H)
  RETURN 0

DirectoValor PROCEDURE(STRING pSql)
H       LONG
  CODE
  Query = CLIP(pSql)
  Buf = ''
  H = tco_exec(Dbc,Query,1,Err,SIZE(Err))
  IF H AND tco_fetch(H,Err,SIZE(Err)) > 0 THEN tco_get(H,1,1,Buf,SIZE(Buf)).
  tco_close(H)
  RETURN Buf

SumarCola PROCEDURE()
I       LONG
  CODE
  Total = 0
  LOOP I = 1 TO RECORDS(Q)
    GET(Q,I)
    Total += Q:Total
  END

Ms PROCEDURE()
C       LIKE(QPCGroup)
  CODE
  QPC(C)
  RETURN (C.Hi * 4294967296 + C.Lo) * 1000 / Freq

Log PROCEDURE(STRING pText)
  CODE
  LogFile.Line = pText
  ADD(LogFile)
  CLOSE(LogFile)                                        ! grabado ya: si el proceso se corta, queda hasta donde llego
  OPEN(LogFile)
