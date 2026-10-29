!ABCIncludeFile

 OMIT('_EndOfInclude_',_Sqlclass6Presente_)
_Sqlclass6Presente_ EQUATE(1)

   INCLUDE('aberror.inc'),ONCE ! los equates de EventAction:Foward, etc.
   INCLUDE('abbrowse.inc'),ONCE
   INCLUDE('abwindow.inc'),ONCE

SQLClass6_QFields  QUEUE,TYPE
QFieldName   STRING(40)     ! Nombre del Campo (o expresion)
QFieldLabel  STRING(40)     ! Label (texto) del Campo (o expresion)
QFieldNo     SHORT      ! Numero del Campo dentro del Select
         END!QUEUE

SQLClass6_QFormat  QUEUE,TYPE
QFormatNo     SHORT         ! Numero del Campo dentro del Select
QFormatPic    STRING(40)    ! Formato (Picture)
         END!QUEUE

! -- Valid States
SQL:Ready   EQUATE(1)
SQL:NotReady    EQUATE(0)

! --------------- Declaración de las Clases ------------
! Version 1.1
! * Se corrigio un Bug en el Fetch que asumia tipo de dato LONG de retorno y entonces no devolvia decimales. 
!   Se paso a STRING para que sea generico.
!
!
SQLOdbcClass CLASS(),MODULE('SQLCLASS6.CLW'),LINK('SQLCLASS6.CLW',_ABCLinkMode_),DLL(_ABCDllMode_)
SQLFile         &FILE
SQLFileRecord   &GROUP
State           BYTE        ! Indicates if the SQLClass objects are in a valid State
Query           CSTRING(20480) ! Contains the QUERY
SQL_Select      CSTRING(10240) ! Contains the SELECT   Clause
SQL_From        CSTRING(10240) ! Contains the FROM     Clause
SQL_Where       CSTRING(10240) ! Contains the WHERE    Clause
SQL_OrderBy     CSTRING(10240) ! Contains the ORDER BY Clause
SQL_GroupBy     CSTRING(10240) ! Contains the GROUP BY Clause
PropOwner       CSTRING(10240) !
MiString        &StringClass   ! Reference a StringClass Object
Fields          &SQLClass6_QFields
Format          &SQLClass6_QFormat
PK_Col          SHORT       ! Columns Number that contains the value of the Primary Key (Files that want AutoUpdate need 1 PK with 1 Field only!)
Records         LONG        ! How many records will satisfy the query? USE METHOD TO UPDATE this prop.
Records_Done    LONG        ! How many records i have processed so far (next +1 , previous -1)
Cols            SHORT,PROTECTED ! How many columns does the Parser detected 
Primary_FM      &FileManager
Primary_Key     &KEY
Primary_Field   ANY
AutoUpdate      BYTE 
SilentMode      BYTE ! Equivalent to the "Try" concept but without duplicating the methods.
MaxReads        LONG ! Maximum amount of records enabled to read. When reached this number LoadQueue should stop and warn the user (if >0)      
Debug       BYTE ! Sets Debug True/False for long querys
Debug_Limit TIME ! Configure the threshold to WARN the user about a long Query (Long Query Detection)
Field_Valor     CSTRING(100) ! Gustavo 11/10
Funcion_Valor	CSTRING(100) ! Gustavo 11/10
FreeQueue   BYTE ! Frees the queue when a LoadQueue is done?
LogFile         CSTRING(260)  ! Si tiene un nombre, cada query que se envia al servidor se anota en ese archivo (usa StringTheory). Vacio = sin log
ShowProgress    BYTE          ! 1 = muestra una ventana de proceso mientras se ejecuta cada query
ProgressTitle   CSTRING(80)   ! Titulo de la ventana de proceso (vacio = 'Procesando consulta')
ProgressText    CSTRING(120)  ! Texto de la ventana de proceso (vacio = 'Esperando la respuesta del servidor...')
Construct       PROCEDURE()
Destruct        PROCEDURE()
Init            PROCEDURE(*File Archivo,*Group Registro,String Conexion),Byte,VIRTUAL
Kill            PROCEDURE()
Exec            PROCEDURE(String Query),Byte
ExecEx          PROCEDURE(String Query,<Byte OmitLower>),Byte   ! Como Exec (pasa a minusculas) pero cuenta bien las columnas (AS, TOP, funciones). OmitLower=1 respeta mayusculas
ServerExecEx    PROCEDURE(),Byte
CountCols       PROCEDURE(),Short
SP              PROCEDURE(Short NoCols, String Query),Byte  ! CALL A STORE PROCEDURE
ExecSP          PROCEDURE(String Query,<Short NoCols>),Byte  ! Store Procedure con resultado: 'EXEC dbo.sp p1,p2' se envia como CALL dbo.sp(p1,p2). No pasa por Parse ni por Lower
WriteLog       PROCEDURE(String Text)  ! Anota una linea (fecha, hora y texto) en LogFile con StringTheory. Si LogFile esta vacio no hace nada
Parse           PROCEDURE(),Byte
Col             PROCEDURE(Short NroCol),String  ! Devuelve el contenido de la columna "n"
Col_Format      PROCEDURE(Short NroCol,String Formato)  ! Define el formato (picture) de la columna "n"
Columns         PROCEDURE(),Short        ! Devuelve la cantidad de Columnas del Query
Field           PROCEDURE(Short FieldNo),String  ! Returns the name of the field no "x"
ServerExec      PROCEDURE(),Byte
Fetch           PROCEDURE(Short NroCol,String Query),String
Fetch           PROCEDURE(Short NroCol,String Query,*String Result),Byte
Next            PROCEDURE(),Byte,PROC
Records         PROCEDURE(),LONG
RegisterUpdate  PROCEDURE(*FileManager MyFm ,*Key MyKey,*? MyField),VIRTUAL
UpdateBuffer    PROCEDURE(),Byte,PROC
LoadQueue       PROCEDURE(*Queue MyQ,Byte WithCount,Byte ShowWin),BYTE
TakeRecord      PROCEDURE(),BYTE,VIRTUAL
TakeInsert      PROCEDURE(),BYTE,VIRTUAL ! Metodos para Detectar Tipos de Querys
TakeDelete      PROCEDURE(),BYTE,VIRTUAL
TakeSelect      PROCEDURE(),BYTE,VIRTUAL
TakeDrop        PROCEDURE(),BYTE,VIRTUAL
TakeUpdate      PROCEDURE(),BYTE,VIRTUAL
       END

SQLIfxClass CLASS(SQLOdbcClass),MODULE('SQLCLASS6.CLW'),LINK('SQLCLASS6.CLW',_ABCLinkMode_),DLL(_ABCDllMode_)
TakeRecord    PROCEDURE(),BYTE,VIRTUAL
    END

SQLMsClass CLASS(SQLOdbcClass),MODULE('SQLCLASS6.CLW'),LINK('SQLCLASS6.CLW',_ABCLinkMode_),DLL(_ABCDllMode_)
TakeRecord    PROCEDURE(),BYTE,VIRTUAL
    END

SQLOraClass CLASS(SQLOdbcClass),MODULE('SQLCLASS6.CLW'),LINK('SQLCLASS6.CLW',_ABCLinkMode_),DLL(_ABCDllMode_)
TakeRecord    PROCEDURE(),BYTE,VIRTUAL
    END



_EndOfInclude_