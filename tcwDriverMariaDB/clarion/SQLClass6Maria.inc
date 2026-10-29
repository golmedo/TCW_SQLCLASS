!==============================================================================
! SQLMariaClass - la SQLClass (SQLClass6) yendo directo a MariaDB / MySQL (Templates Clarion)
! Hereda de SQLOdbcClass y reimplementa todos sus metodos con las mismas firmas y los mismos codigos de
! retorno, pero sin archivo de trabajo ni driver de Clarion: usa TCWMariaDB (libmariadb.dll).
! SQLClass6.INC / .clw NO se modifican: las apps que usan SQLMsClass siguen igual.
!
! Uso (igual que SQLClass):
!   CLASSQ  &SQLMariaClass                     ! el tipo tiene que ser SQLMariaClass (no SQLMsClass)
!   CLASSQ &= NEW SQLMariaClass
!   IF CLASSQ.InitMaria('Server=srv;Port=3306;Database=base;User=u;Password=p') THEN ...error...
!   (o CLASSQ.Init(Archivo,Registro,'Server=...') : el archivo se ignora, se mantiene por compatibilidad)
!   IF CLASSQ.Exec('SELECT codigo, nombre FROM articulos') THEN RETURN.
!   LOOP UNTIL CLASSQ.Next()
!     Q:Codigo = CLASSQ.Col(1) ; Q:Nombre = CLASSQ.Col(2) ; ADD(Q)
!   END
! Diferencias a favor: sin limite de columnas ni de largo de cada valor, Records() exacto (cuenta el
! resultado ya leido, sirve con GROUP BY/DISTINCT), Field(n) devuelve el nombre real de la columna.
!==============================================================================
 OMIT('_EndOfInclude_',_SQLClass6MariaPresente_)
_SQLClass6MariaPresente_ EQUATE(1)

  INCLUDE('SQLClass6.INC'),ONCE
  INCLUDE('TCWMariaDB.inc'),ONCE

SQLMariaClass       CLASS(SQLOdbcClass),TYPE,MODULE('SQLClass6Maria.clw'),LINK('SQLClass6Maria.clw')
Db                    &TCWMariaDB           ! conexion directa (se puede usar tambien: Escape, Quote, InsertId...)
KeepCase              BYTE                  ! 1 = Exec() no pasa la consulta a minusculas (MariaDB en Linux distingue mayusculas en los nombres de tabla)
! avance en la propia ventana: una barra (PROGRESS) y un texto (STRING/PROMPT) de la ventana; 0 = sin avance
ProgressFeq           LONG                  ! PROGRESS: 0..100 durante LoadQueue
ProgressTextFeq       LONG                  ! texto: 'Ejecutando consulta...', 'Cargando n de m filas', resumen final
ProgressDelay         LONG                  ! centesimas entre refrescos durante la carga (por defecto 10 = 100 ms)
ProgLast              LONG,PRIVATE
ProgMsQuery           LONG,PRIVATE
Construct             PROCEDURE()
Destruct              PROCEDURE()
! --- mismos metodos que SQLClass6
Init                  PROCEDURE(*File Archivo,*Group Registro,String Conexion),Byte,VIRTUAL
Kill                  PROCEDURE()
Exec                  PROCEDURE(String Query),Byte
ExecEx                PROCEDURE(String Query,<Byte OmitLower>),Byte
ServerExecEx          PROCEDURE(),Byte
SP                    PROCEDURE(Short NoCols,String Query),Byte
ExecSP                PROCEDURE(String Query,<Short NoCols>),Byte
Parse                 PROCEDURE(),Byte
Col                   PROCEDURE(Short NroCol),String
ServerExec            PROCEDURE(),Byte
Fetch                 PROCEDURE(Short NroCol,String Query),String
Fetch                 PROCEDURE(Short NroCol,String Query,*String Result),Byte
Next                  PROCEDURE(),Byte,PROC
Records               PROCEDURE(),LONG
UpdateBuffer          PROCEDURE(),Byte,PROC
LoadQueue             PROCEDURE(*Queue MyQ,Byte WithCount,Byte ShowWin),BYTE
! --- nuevos
InitMaria             PROCEDURE(String Conexion),Byte             ! conecta sin archivo de trabajo
AddParam              PROCEDURE(String Valor)                     ! valor para el proximo '?' de Exec/ExecEx (va escapado; lo consume la consulta)
AddNullParam          PROCEDURE()
NextResult            PROCEDURE(),Byte,PROC                       ! siguiente resultado de un CALL o de 'SELECT ...; SELECT ...' (Notify = no hay mas)
! sentencias preparadas y lotes (MySQL 5.0 no tiene arreglos de parametros: un lote es un INSERT de varias filas)
Prepare               PROCEDURE(String Query),Byte,PROC           ! 'UPDATE t SET a = ? WHERE id = ?'
ExecPrepared          PROCEDURE(),Byte,PROC                       ! con los AddParam actuales (o las filas pendientes de AddRow)
AddRow                PROCEDURE(),Byte,PROC                       ! los AddParam actuales son una fila del lote (se manda cada Db.BatchSize)
! INSERT por nombre de campo, sin comillas, Clip ni escape: Campo(...) por columna y despues Insertar / InsertarLote
Campo                 PROCEDURE(String Nombre,String Valor)
CampoNulo             PROCEDURE(String Nombre)
CampoFecha            PROCEDURE(String Nombre,Long Fecha)         ! fecha de Clarion; 0 = NULL
CampoFechaHora        PROCEDURE(String Nombre,Long Fecha,Long Hora)
Insertar              PROCEDURE(String Tabla),Byte,PROC           ! una fila ya
InsertarLote          PROCEDURE(String Tabla),Byte,PROC           ! junta filas en un INSERT de varias filas (de a Db.BatchSize, 500)
EnviarLote            PROCEDURE(),Byte,PROC                       ! manda las que queden: llamar al terminar
TakeDbResult          PROCEDURE(Byte Res,String Que),Byte,PROTECTED
ColByName             PROCEDURE(String Nombre),String             ! valor de la columna por nombre
IsNull                PROCEDURE(Short NroCol),Byte
Escape                PROCEDURE(String Texto),String              ! escapa un valor para ponerlo entre comillas
Quote                 PROCEDURE(String Texto),String              ! 'valor' escapado y entre comillas
InsertId              PROCEDURE(),LONG                            ! id autoincremental del ultimo INSERT
AffectedRows          PROCEDURE(),LONG                            ! filas afectadas por el ultimo INSERT/UPDATE/DELETE
ErrorText             PROCEDURE(),String
ErrorCode             PROCEDURE(),LONG
ServerVersion         PROCEDURE(),String
BeginTransaction      PROCEDURE(),Byte,PROC
Commit                PROCEDURE(),Byte,PROC
Rollback              PROCEDURE(),Byte,PROC
SetProgress           PROCEDURE(Long Porc,String Texto)          ! pone la barra (-1 = no tocarla) y el texto, y repinta ya
RunQuery              PROCEDURE(String pSql,String pMethod),Byte,PROTECTED
TakeResult            PROCEDURE(),PROTECTED
                    END

 _EndOfInclude_
